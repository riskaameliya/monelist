<p align="center">
  <img src="Sources/TodoPomo/Resources/PomoLogo.png" alt="Logo MoneList" width="128">
</p>

<h1 align="center">MoneList</h1>

<p align="center">Daftar tugas dan timer Pomodoro untuk macOS, ditemani maskot kucing.</p>

<p align="center">
  <a href="https://github.com/riskaameliya/monelist/releases">Unduh DMG</a> ·
  <a href="#build-dari-source">Build dari source</a> ·
  <a href="#struktur-folder">Struktur folder</a>
</p>

## Instal di macOS

MoneList membutuhkan **macOS 13 Ventura atau lebih baru**. DMG dari GitHub Releases mendukung **Apple Silicon dan Intel**.

1. Unduh `MoneList-<versi>.dmg` dari [GitHub Releases](https://github.com/riskaameliya/monelist/releases).
2. Buka DMG dan seret **MoneList** ke **Applications**.
3. Buka MoneList dari **Applications**.

> Build rilis memakai tanda tangan ad-hoc. Gatekeeper bisa memblokir aplikasi saat pertama dibuka karena build belum dinotariskan.

## Cara menggunakan

| Fitur | Cara pakai |
| --- | --- |
| **Daftar tugas** | Ketik di **Tambah tugas…** dan tekan Enter. Seret pegangan **☰** untuk mengubah urutan, centang tugas untuk memindahkannya ke **Selesai**, atau klik **Hapus yang selesai** untuk mengosongkan bagian itu. |
| **Timer Pomodoro** | Klik ikon target pada tugas untuk mencatat sesi fokusnya, atau jalankan timer secara mandiri. Gunakan kontrol timer untuk menjeda, mengatur ulang, atau melewati sesi. |
| **Panel mini** | Klik tombol kecilkan di kanan atas untuk melihat sisa waktu dan mengontrol timer dari Space lain. Seret ikon atau angka timer untuk memindahkan panel. |
| **Maskot kucing** | Ekspresinya berubah mengikuti fase timer. Bunyi meong menandai akhir sesi fokus atau istirahat. |

Durasi bawaan adalah **25 menit fokus**, **5 menit istirahat singkat**, dan **15 menit istirahat panjang** setelah empat sesi fokus. Ubah durasi fokus lewat ikon roda gigi. Untuk mengulang siklus hitungan, klik angka **sesi fokus** dan pilih **Reset hitungan sesi fokus**.

Daftar tugas, pengaturan timer, hitungan sesi, dan posisi panel disimpan secara lokal. MoneList dapat meminta izin untuk menampilkan notifikasi saat sesi berakhir.

## Build dari source

Siapkan **Xcode Command Line Tools** dan **FFmpeg**. Perintah kedua memakai Homebrew.

```bash
xcode-select --install
brew install ffmpeg
```

Jalankan dari folder proyek.

```bash
./build.sh
open build/MoneList.app
```

Build lokal mengikuti arsitektur Mac yang menjalankannya. Untuk membuat DMG universal dengan nomor versi yang sama pada aplikasi dan installer, jalankan:

```bash
ARCHS="arm64 x86_64" VERSION=1.0.0 ./build.sh
./scripts/make-dmg.sh 1.0.0
```

DMG tersedia di `build/MoneList-1.0.0.dmg`. FFmpeg mengonversi `cat-meow.ogg` ke CAF saat build. Pengguna DMG tidak perlu menginstal FFmpeg.

## Struktur folder

```text
MoneList/
├── .github/workflows/
│   └── release.yml          # Build universal dan unggah DMG ke GitHub Releases
├── Sources/TodoPomo/
│   ├── TodoPomoApp.swift     # Titik masuk aplikasi SwiftUI
│   ├── ContentView.swift     # Jendela utama dan panel mini
│   ├── TodoStore.swift       # Daftar tugas dan penyimpanan lokal
│   ├── PomodoroTimer.swift   # Timer, bunyi, dan notifikasi
│   └── Resources/           # Logo, maskot, dan cat-meow.ogg
├── scripts/
│   ├── create-app-icon.swift # Pembuatan ikon aplikasi
│   └── make-dmg.sh           # Pengemasan aplikasi ke DMG
├── docs/
│   └── RELEASE.md           # Panduan rilis untuk maintainer
├── Info.plist               # Metadata aplikasi macOS
└── build.sh                 # Kompilasi dan pembuatan bundle .app
```

Untuk menerbitkan versi baru, lihat [panduan rilis untuk maintainer](docs/RELEASE.md).
