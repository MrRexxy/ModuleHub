# ModuleHub (aplikasi root)

Aplikasi Android yang meminta akses root (Magisk / KernelSU / APatch) dan menampilkan WebUI Game Boost.
Mesinnya (skrip di `app/src/main/assets/engine/`) mengubah CPU, GPU, memori, dan resolusi hanya saat game
pilihanmu terbuka, lalu mengembalikannya saat game ditutup.

## Build tanpa memasang apa pun di PC
1. Buat repositori GitHub baru, unggah seluruh isi folder ini (termasuk `.github/`).
2. Buka tab **Actions**, jalankan workflow **Build APK** (atau cukup push).
3. Unduh artefak **ModuleHub-debug-apk**, pasang `app-debug.apk` di HP.

## Build di Android Studio
Buka folder ini, tunggu sinkronisasi Gradle, lalu **Build > Build APK(s)**.
Butuh JDK 17 (bawaan Android Studio sudah cukup).

## Pemakaian
1. Buka aplikasi, beri izin root saat diminta.
2. Tab **Boost**: pilih game, atur opsi, tekan **Simpan & terapkan**.
3. Tab **Rekam** dan **Sesi**: rekam FPS dan suhu untuk membuktikan efeknya (A/B).

## Catatan
- Pakai SALAH SATU: aplikasi ini ATAU modul Magisk `ModuleHub Game Boost`. Keduanya memakai file konfigurasi yang sama.
- WebView hanya memuat halaman dari aset aplikasi. Perintah root dibatasi ke skrip mesin dan pembacaan config.
- APK debug ditandatangani kunci debug otomatis dan bisa langsung dipasang. Untuk rilis, tambahkan keystore sendiri.
- Proyek ini belum pernah dikompilasi oleh pembuatnya (tanpa Android SDK). Jika build gagal, kirim log error-nya.
