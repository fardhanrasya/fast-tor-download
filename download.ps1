<#
.SYNOPSIS
    Fast Tor Browser Downloader (Multi-Connection Accelerated)
    Created by: Fardhan Rasya (github.com/fardhanrasya/fast-tor-download)
.DESCRIPTION
    Downloads official Tor Browser for Windows using 16 concurrent HTTP Range streams
    to bypass ISP / single-stream TCP throughput throttling.
    Verifies official Tor Project SHA-256 checksum automatically.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

Write-Host @"
================================================================
   🚀 FAST TOR BROWSER DOWNLOADER (Multi-Connection Streams)
   Created by: Fardhan Rasya | github.com/fardhanrasya
================================================================
"@ -ForegroundColor Cyan

# 1. Determine target file & version
$defaultVersion = "15.0.24"
$defaultFilename = "tor-browser-windows-x86_64-portable-15.0.24.exe"
$defaultSha256 = "a549824c31dd9ee8143ecc6bc97b8f2d5fd5cba8b13f528f1444a0b769758c6c"

$downloadsDir = Join-Path $HOME "Downloads"
if (-not (Test-Path $downloadsDir)) {
    $downloadsDir = $HOME
}

Write-Host "[*] Mendapatkan info versi resmi Tor Browser..." -ForegroundColor Yellow

$version = $defaultVersion
$filename = $defaultFilename
$expectedHash = $defaultSha256

try {
    $metaUrl = "https://aus1.torproject.org/torbrowser/update_3/release/downloads.json"
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
    $jsonRaw = $webClient.DownloadString($metaUrl)
    $meta = $jsonRaw | ConvertFrom-Json
    if ($meta.version) {
        $version = $meta.version
        $win64 = $meta.downloads.win64.ALL.binary
        if ($win64) {
            $filename = [System.IO.Path]::GetFileName($win64)
        }
    }
} catch {
    Write-Host "[!] Menggunakan preset versi stabil: v$version" -ForegroundColor DarkGray
}

# Fetch SHA256 sums from official repo if available
try {
    $sumsUrl = "https://dist.torproject.org/torbrowser/$version/sha256sums-signed-build.txt"
    $sumsContent = (New-Object System.Net.WebClient).DownloadString($sumsUrl)
    $match = [regex]::Match($sumsContent, "([a-fA-F0-9]{64})\s+$([regex]::Escape($filename))")
    if ($match.Success) {
        $expectedHash = $match.Groups[1].Value.ToLower()
    }
} catch {
    # Keep fallback expectedHash
}

$destPath = Join-Path $downloadsDir $filename

# Source Mirrors
$mirrors = @(
    "https://archive.torproject.org/tor-package-archive/torbrowser/$version/$filename",
    "https://dist.torproject.org/torbrowser/$version/$filename",
    "https://tor.eff.org/dist/torbrowser/$version/$filename"
)

Write-Host "[+] Target File : $filename" -ForegroundColor Green
Write-Host "[+] Simpan ke   : $destPath" -ForegroundColor Green
Write-Host "[+] SHA256 Resmi: $expectedHash" -ForegroundColor Green

# 2. Inject Fast Multi-threaded Downloader Class (C# in-memory)
$csharpCode = @"
using System;
using System.IO;
using System.Net;
using System.Threading.Tasks;

public class FastTorDownloader {
    public static bool DownloadStreams(string[] urls, string destPath, int numThreads) {
        ServicePointManager.DefaultConnectionLimit = 64;
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12 | SecurityProtocolType.Tls13;

        string activeUrl = null;
        long totalSize = 0;

        foreach (var url in urls) {
            try {
                var req = (HttpWebRequest)WebRequest.Create(url);
                req.Method = "HEAD";
                req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";
                req.Timeout = 10000;
                using (var resp = req.GetResponse()) {
                    totalSize = resp.ContentLength;
                    if (totalSize > 1000000) {
                        activeUrl = url;
                        break;
                    }
                }
            } catch {
                continue;
            }
        }

        if (activeUrl == null || totalSize <= 0) {
            return false;
        }

        long chunkSize = (totalSize + numThreads - 1) / numThreads;
        string tempPattern = destPath + ".part_{0:D2}";

        Parallel.For(0, numThreads, i => {
            long start = i * chunkSize;
            long end = Math.Min((i + 1) * chunkSize - 1, totalSize - 1);
            if (start > end) return;
            string partFile = string.Format(tempPattern, i);

            for (int attempt = 0; attempt < 5; attempt++) {
                try {
                    var partReq = (HttpWebRequest)WebRequest.Create(activeUrl);
                    partReq.AddRange(start, end);
                    partReq.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";
                    partReq.Timeout = 35000;
                    partReq.ReadWriteTimeout = 35000;
                    using (var partResp = partReq.GetResponse())
                    using (var inStream = partResp.GetResponseStream())
                    using (var fs = File.Create(partFile)) {
                        inStream.CopyTo(fs);
                    }
                    if (new FileInfo(partFile).Length == (end - start + 1)) {
                        break;
                    }
                } catch {
                    System.Threading.Thread.Sleep(1000);
                }
            }
        });

        // Combine chunks
        using (var outStream = File.Create(destPath)) {
            for (int i = 0; i < numThreads; i++) {
                string partFile = string.Format(tempPattern, i);
                if (File.Exists(partFile)) {
                    using (var inStream = File.OpenRead(partFile)) {
                        inStream.CopyTo(outStream);
                    }
                    File.Delete(partFile);
                }
            }
        }

        return new FileInfo(destPath).Length == totalSize;
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'FastTorDownloader').Type) {
    Add-Type -TypeDefinition $csharpCode -Language CSharp
}

# 3. Start Download
Write-Host "`n[*] Memulai download dipercepat (16 streams paralel)..." -ForegroundColor Yellow
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$success = [FastTorDownloader]::DownloadStreams($mirrors, $destPath, 16)
$stopwatch.Stop()

if (-not $success -or -not (Test-Path $destPath)) {
    Write-Host "[X] Gagal mendownload dari mirror. Silakan periksa koneksi internet Anda." -ForegroundColor Red
    exit 1
}

$fileItem = Get-Item $destPath
$elapsedSec = [Math]::Max(0.1, $stopwatch.Elapsed.TotalSeconds)
$sizeMb = [Math]::Round($fileItem.Length / 1MB, 2)
$speedMbs = [Math]::Round($sizeMb / $elapsedSec, 2)

Write-Host "[✓] Download selesai dalam $([math]::Round($elapsedSec, 1)) detik! (Kecepatan rata-rata: $speedMbs MB/s)" -ForegroundColor Green

# 4. Hash Verification
Write-Host "[*] Memverifikasi integritas file SHA-256..." -ForegroundColor Yellow
$actualHash = (Get-FileHash -Path $destPath -Algorithm SHA256).Hash.ToLower()

if ($actualHash -eq $expectedHash.ToLower()) {
    Write-Host "[✓] HASH SHA-256 VALID & COCOK DENGAN TANDA TANGAN RESMI TOR PROJECT!" -ForegroundColor Green
} else {
    Write-Host "[!] Peringatan: Hash tidak cocok!" -ForegroundColor Red
    Write-Host "    Expected: $expectedHash" -ForegroundColor Red
    Write-Host "    Actual  : $actualHash" -ForegroundColor Red
}

# 5. Tips for Indonesian ISPs
Write-Host @"

----------------------------------------------------------------
💡 TIPS PENTING KETIKA MEMBUKA TOR DI INDONESIA:
Jika setelah dibuka koneksi Tor macet di 'Establishing Connection':
1. Klik tombol 'Cancel' pada layar Tor Browser.
2. Buka menu Settings ☰ (pojok kanan atas) > Connection.
3. Pada bagian Bridges, centang 'Built-in bridges' lalu pilih:
   👉 'Snowflake' (Sangat ampuh tembus blokir ISP di Indonesia!)
----------------------------------------------------------------
"@ -ForegroundColor Magenta

# 6. Prompt to run
$run = Read-Host "Apakah Anda ingin langsung membuka installer sekarang? (y/n)"
if ($run -eq "y" -or $run -eq "Y") {
    Start-Process -FilePath $destPath
}
