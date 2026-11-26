# Testing Checklist — ASGRID V2.2.1 Revision 3

**Target Runtime:** AutoCAD 2021  
**Status Pengujian Runtime Saat Ini:** **BELUM DIUJI** (seluruh item di bawah wajib dieksekusi langsung oleh pengguna pada AutoCAD 2021).

## Prasyarat Persiapan

- [ ] Salin `ASGRID_V2_2_1_R3.lsp` dan `ASGRID_V2_2_1_R3.dcl` ke folder yang terdaftar di `AutoCAD Options -> Files -> Support File Search Path`.
- [ ] Pastikan file `ASGRID_V2_2_1_R2.lsp` tidak sedang dimuat bersamaan agar definisi perintah `ASGRID`, `ASGRIDEDIT`, dan `ASGRIDCHECK` berasal dari R3.
- [ ] Buka drawing baru (*new DWG*) yang belum memiliki Text Style `ASGRID-ARIAL` maupun grup `ASGRID`.

## Bagian A — Pengujian Utama Bug `stringp T` (`ASGRID` & `ASGRIDEDIT`)

| ID | Skenario Uji | Langkah | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| T-01 | Muat program via `APPLOAD` | Muat `ASGRID_V2_2_1_R3.lsp` pada DWG baru. | Muncul pesan sukses di command line tanpa error sintaks/load. | [ ] Belum diuji |
| T-02 | Buka dialog `ASGRID` di DWG baru | Ketik `ASGRID` lalu tekan `Enter`. | Dialog `asgrid_v2_2` tampil normal. Tidak muncul `bad argument type: stringp T`. | [ ] Belum diuji |
| T-03 | Generate grid pertama (`ASG-0001`) | Isi parameter grid, klik `OK`, tentukan titik insersi. | Grid `ASG-0001`, Text Style `ASGRID-ARIAL`, layer `AS-GRID`/`AS-BUBBLE`/`AS-TEXT`, dan XRecord NOD berhasil dibuat. | [ ] Belum diuji |
| T-04 | Generate grid kedua (`ASG-0002`) | Jalankan `ASGRID` lagi pada DWG yang sama. | Dialog tampil normal; `ASG-0002` berhasil dibuat tanpa error RegApp `ASGRID_OBJ`. | [ ] Belum diuji |
| T-05 | Buka dialog `ASGRIDEDIT` | Ketik `ASGRIDEDIT`, pilih objek dari `ASG-0001`. | Dialog `asgrid_edit_v2_2` tampil normal tanpa error `stringp T`; panel read-only menampilkan metadata `ASG-0001`. | [ ] Belum diuji |
| T-06 | Simpan perubahan anotasi (`ASGRIDEDIT` Mode 1) | Ubah ukuran bubble/teks atau posisi bubble, klik `OK`. | Anotasi diperbarui bersih, verifikasi metadata pasca-update lulus, garis grid tidak bergeser. | [ ] Belum diuji |
| T-07 | Diagnostik `ASGRIDCHECK` | Jalankan `ASGRIDCHECK` pada DWG berisi `ASG-0001` dan `ASG-0002`. | Kedua grup berstatus valid/konsisten, tanpa perubahan pada DWG (100% read-only). | [ ] Belum diuji |

## Bagian B — Pengujian Fallback & Error Handling DCL

| ID | Skenario Uji | Langkah | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| T-08 | Fallback ke `ASGRID_V2_2_1_R2.dcl` | Pindahkan sementara `ASGRID_V2_2_1_R3.dcl` dari Support Path, sisakan `ASGRID_V2_2_1_R2.dcl`, lalu jalankan `ASGRID` dan `ASGRIDEDIT`. | Kedua dialog tetap tampil normal menggunakan file fallback tanpa error `stringp T`. | [ ] Belum diuji |
| T-09 | Semua file DCL tidak tersedia | Pindahkan sementara seluruh `ASGRID_V2_2*.dcl` dari Support Path, jalankan `ASGRID` dan `ASGRIDEDIT`. | Muncul pesan `alert` dan `princ` yang jelas menyebut `'ASGRID_V2_2_1_R3.dcl'` tidak ditemukan, tanpa crash program error. | [ ] Belum diuji |
| T-10 | Batal (`Cancel`) pada dialog | Buka `ASGRID` dan `ASGRIDEDIT`, klik `Cancel`. | Dialog tertutup bersih, tidak ada entitas parsial, tidak ada sisa UNDO terbuka. | [ ] Belum diuji |

## Catatan Penguji

- **Tanggal Uji:** ___________________________
- **Versi AutoCAD:** AutoCAD 2021
- **Hasil Akhir:** `[ ] LULUS` / `[ ] GAGAL (lampirkan output command line)`
