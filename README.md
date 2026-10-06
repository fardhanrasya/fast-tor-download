# 🚀 Fast Tor Browser Downloader

> Download Tor Browser resmi untuk Windows dengan **kecepatan maksimal (multi-connection 16 streams)** dalam hitungan detik. Cukup **1 command** di PowerShell!

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg)](https://microsoft.com)

---

## ⚡ Cara Pakai (Cukup 1 Command!)

Teman kamu tidak perlu download tools tambahan atau install Python. Cukup buka **PowerShell** di Windows (bisa tekan `Win + X` lalu pilih **Terminal / PowerShell**), lalu copy-paste perintah ini dan tekan Enter:

```powershell
irm https://raw.githubusercontent.com/fardhanrasya/fast-tor-download/main/download.ps1 | iex
```

> **Atau via Run dialog (`Win + R`):**
> ```cmd
> powershell -c "irm https://raw.githubusercontent.com/fardhanrasya/fast-tor-download/main/download.ps1 | iex"
> ```

Script akan otomatis:
1. Mengambil installer Tor Browser 64-bit versi resmi terbaru.
2. Membagi file menjadi **16 koneksi paralel (HTTP Range streams)** sehingga kecepatan download bisa tembus **~10-20 MB/s** (selesai dalam 10-15 detik!).
3. Menyimpan file langsung ke folder `Downloads` Anda.
4. Memvalidasi tanda tangan checksum **SHA-256 resmi dari Tor Project** untuk menjamin keamanan dan keaslian file.
5. Menawarkan untuk langsung menjalankan installer.

---

## 🧐 Kenapa Download di Web Resmi Tor Sering Lambat Banget?

1. **Throttling ISP di Indonesia:** Banyak ISP di Indonesia melakukan pembatasan (throttling) atau inspeksi paket (DPI) terhadap domain dan server Tor Project.
2. **Keterbatasan Single-Stream TCP:** Download via browser standar hanya menggunakan 1 koneksi TCP tunggal ke server Eropa/AS yang memiliki latensi tinggi (RTT 200ms+), sehingga *bandwidth-delay product* membatasi kecepatan download menjadi hanya puluhan atau ratusan KB/s.
3. **Solusi Multi-Stream:** Script ini membuka 16 koneksi paralel ke mirror arsip resmi berkecepatan tinggi, memaksimalkan alokasi bandwidth internet kamu.

---

## 💡 Tips Penting: Tor Macet Saat "Establishing Connection"?

Jika setelah diinstall Tor Browser macet lama di layar *“Establishing a Connection”* (sering terjadi di Telkom, IndiHome, Telkomsel, Biznet, XL, dll.):

1. Klik tombol **Cancel** pada layar Tor.
2. Klik menu **Garis Tiga (☰)** di pojok kanan atas > pilih **Settings**.
3. Di panel kiri, klik **Connection**.
4. Di bagian **Bridges**, pilih **"Choose from one of Tor Browser's built-in bridges..."**.
5. Pilih **`Snowflake`** *(paling direkomendasikan untuk ISP Indonesia)* atau **`obfs4`**.
6. Kembali ke halaman utama dan klik **Connect**.

---

## 🐍 Alternatif (Python)

Bagi pengguna Python:

```bash
python download.py
```

---

## 🔒 Keamanan

Semua file diunduh langsung dari mirror resmi Tor Project (`archive.torproject.org` / `dist.torproject.org` / `tor.eff.org`). Checksum SHA-256 diverifikasi terhadap daftar `sha256sums-signed-build.txt` resmi sebelum digunakan.

## 📄 Lisensi
[MIT](LICENSE) © [Fardhan Rasya](https://github.com/fardhanrasya)
