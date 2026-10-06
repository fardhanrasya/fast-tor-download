#!/usr/bin/env python3
"""
Fast Tor Browser Downloader (Multi-Connection Accelerated)
Created by: Fardhan Rasya (github.com/fardhanrasya/fast-tor-download)
"""

import os
import sys
import time
import hashlib
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

MIRRORS = [
    "https://archive.torproject.org/tor-package-archive/torbrowser/15.0.24/tor-browser-windows-x86_64-portable-15.0.24.exe",
    "https://dist.torproject.org/torbrowser/15.0.24/tor-browser-windows-x86_64-portable-15.0.24.exe",
    "https://tor.eff.org/dist/torbrowser/15.0.24/tor-browser-windows-x86_64-portable-15.0.24.exe",
]
EXPECTED_SHA256 = "a549824c31dd9ee8143ecc6bc97b8f2d5fd5cba8b13f528f1444a0b769758c6c"
NUM_THREADS = 16

def get_downloads_dir():
    home = os.path.expanduser("~")
    dl = os.path.join(home, "Downloads")
    return dl if os.path.exists(dl) else home

def get_file_info(mirrors):
    for url in mirrors:
        try:
            req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=10) as resp:
                length = int(resp.headers.get('Content-Length', 0))
                if length > 1000000:
                    filename = os.path.basename(url)
                    return url, length, filename
        except Exception:
            continue
    raise RuntimeError("All mirrors failed to respond.")

def download_chunk(url, start, end, idx, pattern):
    part_file = pattern.format(idx)
    headers = {'User-Agent': 'Mozilla/5.0', 'Range': f'bytes={start}-{end}'}
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as resp:
                with open(part_file, 'wb') as f:
                    while True:
                        buf = resp.read(65536)
                        if not buf:
                            break
                        f.write(buf)
            if os.path.getsize(part_file) == (end - start + 1):
                return idx, True
        except Exception:
            time.sleep(1 + attempt)
    return idx, False

def main():
    print("=" * 60)
    print("  FAST TOR BROWSER DOWNLOADER (Multi-Connection Streams)")
    print("  Created by: Fardhan Rasya | github.com/fardhanrasya")
    print("=" * 60)

    url, file_size, filename = get_file_info(MIRRORS)
    dest_path = os.path.join(get_downloads_dir(), filename)

    print(f"[*] Target File: {filename}")
    print(f"[*] Size: {file_size / (1024*1024):.2f} MB")
    print(f"[*] Destination: {dest_path}")
    print(f"[*] Downloading with {NUM_THREADS} parallel streams...")

    chunk_size = (file_size + NUM_THREADS - 1) // NUM_THREADS
    temp_pattern = dest_path + ".part_{:02d}"

    chunks = []
    for i in range(NUM_THREADS):
        start = i * chunk_size
        end = min((i + 1) * chunk_size - 1, file_size - 1)
        if start <= end:
            chunks.append((i, start, end))

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=NUM_THREADS) as pool:
        futures = {pool.submit(download_chunk, url, s, e, i, temp_pattern): i for i, s, e in chunks}
        done = 0
        for f in as_completed(futures):
            idx, ok = f.result()
            if not ok:
                raise RuntimeError(f"Chunk {idx} download failed.")
            done += 1
            print(f"  -> Stream {done}/{len(chunks)} completed ({(done/len(chunks))*100:.0f}%)")

    # Combine
    print("[*] Merging streams...")
    with open(dest_path, 'wb') as out_f:
        for i, _, _ in chunks:
            p = temp_pattern.format(i)
            with open(p, 'rb') as in_f:
                while True:
                    b = in_f.read(65536)
                    if not b:
                        break
                    out_f.write(b)
            os.remove(p)

    elapsed = time.time() - t0
    speed = (file_size / (1024*1024)) / elapsed if elapsed > 0 else 0
    print(f"[✓] Download finished in {elapsed:.2f}s ({speed:.2f} MB/s)!")

    # Verify SHA256
    print("[*] Verifying SHA-256 signature...")
    sha = hashlib.sha256()
    with open(dest_path, 'rb') as f:
        while True:
            b = f.read(65536)
            if not b:
                break
            sha.update(b)
    actual_hash = sha.hexdigest().lower()

    if actual_hash == EXPECTED_SHA256.lower():
        print("[✓] SHA-256 VERIFIED: Matches official Tor Project release signature!")
    else:
        print("[!] Warning: SHA-256 mismatch!")

if __name__ == "__main__":
    main()
