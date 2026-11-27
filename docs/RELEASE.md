# Menerbitkan rilis MoneList

Pastikan commit yang akan dirilis sudah ada di GitHub dan berisi workflow [Release macOS DMG](../.github/workflows/release.yml). Buat tag pada commit tersebut dan push tag ke GitHub. Gunakan format `vMAJOR.MINOR.PATCH`, misalnya:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Pantau prosesnya di tab **Actions**. Workflow mengambil nomor versi dari tag, membuat aplikasi universal untuk Apple Silicon dan Intel, memeriksa tanda tangan aplikasi serta checksum DMG, lalu mengunggah `MoneList-<versi>.dmg` ke **Releases**.

Jika rilis dengan tag tersebut sudah ada, workflow menambahkan DMG selama belum ada aset dengan nama yang sama. Build rilis memakai tanda tangan ad-hoc dan belum dinotariskan.
