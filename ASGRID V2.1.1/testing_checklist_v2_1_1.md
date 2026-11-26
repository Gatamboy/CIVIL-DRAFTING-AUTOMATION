# TESTING CHECKLIST — ASGRID V2.1.1 (AutoCAD 2021)

*Catatan: Program ini telah lolos verifikasi statis, tetapi **belum dijalankan langsung di AutoCAD 2021**. Jalankan checklist di bawah ini secara berurutan pada AutoCAD 2021 (template metrik `acadiso.dwt`, satuan milimeter, WCS).*

## 0. Persiapan Lingkungan Uji
- [ ] Simpan `ASGRID_V2_1_1.lsp` dan `ASGRID_V2_1_1.dcl` di folder yang terdaftar pada `OPTIONS` → *Files* → *Support File Search Path* (serta *Trusted Locations*).
- [ ] Pastikan `ASGRID_V2_1.lsp` dan `ASGRID_V2_1.dcl` tetap tersimpan utuh sebagai backup dan **tidak** dimuat bersamaan pada sesi uji yang sama.
- [ ] Buka gambar baru (WCS, Millimeters), muat `ASGRID_V2_1_1.lsp` melalui `APPLOAD`, dan pastikan command line menampilkan: `[ASGRID V2.1.1] Berhasil dimuat. Perintah: ASGRID (buat grid) | ASGRIDCHECK (diagnostik read-only).`

## 1. Uji Hard Gate Metadata & Entity Count Validation
- [ ] Jalankan `ASGRID` dengan konfigurasi 4 × 4 (Horizontal: `4000, 3500, 4000`; Vertikal: `5000, 6000, 5000`; Scale `100`; Text `2.5`; Bubble `8.0`; Extension `1500`; Bubble Position `Both Ends`).
- [ ] Verifikasi ringkasan command line menampilkan:
  - `Group ID (DWG Meta) : ASG-0001`
  - `Validasi Entitas : Lines 8/8 | Bubbles 16/16 | Texts 16/16 (Total 40/40 OK)`
  - `Hard Gate Metadata : LOLOS (Tulis -> Baca Balik -> Deep Compare OK)`
  - `XData Identity : TERVERIFIKASI PADA SELURUH ENTITAS`
- [ ] Jalankan `ASGRID` kedua kali pada koordinat berbeda dengan konfigurasi 3 × 5 dan `Bubble Position = Start`.
- [ ] Verifikasi Group ID otomatis menjadi `ASG-0002` dan validasi entitas menampilkan `Lines 8/8 | Bubbles 8/8 | Texts 8/8 (Total 24/24 OK)`.

## 2. Uji Group Isolation (Multi-Grup dalam Satu DWG)
- [ ] Pastikan `ASG-0001` dan `ASG-0002` berada dalam satu file DWG yang sama dengan konfigurasi berbeda.
- [ ] Jalankan `ASGRIDCHECK` dan verifikasi kedua grup (`ASG-0001` dan `ASG-0002`) tampil terpisah dengan konfigurasi, skala, dan jumlah entitas masing-masing berstatus `OK`.
- [ ] Periksa XData satu objek dari `ASG-0001` dan satu objek dari `ASG-0002` dengan `(entget (car (entsel)) '("ASGRID_OBJ"))`; pastikan Group ID tidak tertukar.
- [ ] Buat grup ketiga `ASG-0003`; pastikan `ASG-0001` dan `ASG-0002` tidak mengalami perubahan posisi, layer, teks, maupun metadata.

## 3. Uji DWG Persistence (Simpan, Tutup, Buka Kembali)
- [ ] Setelah `ASG-0001` dan `ASG-0002` dibuat, simpan file DWG (`SAVEAS`, misal `test_asgrid_v211.dwg`).
- [ ] Tutup file DWG sepenuhnya (atau tutup dan buka ulang AutoCAD 2021 agar seluruh sesi AutoLISP bersih).
- [ ] Buka kembali `test_asgrid_v211.dwg` dan muat ulang `ASGRID_V2_1_1.lsp` via `APPLOAD`.
- [ ] Jalankan `ASGRIDCHECK` dan verifikasi:
  - `ASG-0001` dan `ASG-0002` tetap terdaftar di NOD `ASGRID_GROUPS`.
  - Seluruh parameter (skala, jumlah grid, posisi bubble) terbaca utuh tanpa error.
  - Seluruh entitas masih memiliki XData `ASGRID_OBJ` yang valid (`0 MASALAH`).
- [ ] Jalankan `ASGRID` untuk membuat grup baru; pastikan `Next Group ID` pada dialog otomatis menunjukkan `ASG-0003` (tidak bentrok dengan `ASG-0001`/`ASG-0002`).

## 4. Uji Diagnostik READ-ONLY (`ASGRIDCHECK`) terhadap Anomali
- [ ] **Uji entitas parsial:** Hapus manual 1 lingkaran bubble dari `ASG-0001` menggunakan perintah `ERASE`, lalu jalankan `ASGRIDCHECK`. Pastikan `ASG-0001` melaporkan `PERINGATAN - Jumlah entitas tidak sesuai metadata` (`Bubbles 15/16`) dan `ASGRIDCHECK` **tidak** membuat/menghapus objek apa pun. Tekan `UNDO` untuk mengembalikan bubble.
- [ ] **Uji metadata yatim:** Hapus seluruh objek milik `ASG-0002` secara manual di Model Space, lalu jalankan `ASGRIDCHECK`. Pastikan `ASG-0002` melaporkan `PERINGATAN - Metadata yatim (0 entitas ditemukan di gambar)` dan XRecord tidak dihapus otomatis. Tekan `UNDO` untuk memulihkan.
- [ ] **Uji objek non-ASGRID:** Buat beberapa garis/teks biasa di layer `0` atau layer `AS-GRID` tanpa XData, lalu jalankan `ASGRIDCHECK`. Pastikan objek biasa tersebut tidak mengganggu hitungan grup `ASG-0001`/`ASG-0002` dan tidak tersentuh.

## 5. Uji Transaction Safety, Pembatalan & UNDO
- [ ] **Cancel di dialog:** Buka `ASGRID`, ubah beberapa parameter, lalu klik `Cancel`. Pastikan tidak ada objek baru, tidak ada XRecord baru, dan `ASGRIDCHECK` tetap bersih.
- [ ] **ESC saat pilih titik awal:** Klik `OK` di dialog, lalu tekan `ESC` saat diminta klik titik awal grid. Pastikan muncul pesan pembatalan pengguna, `CMDECHO` kembali ke nilai awal, dan tidak ada metadata/entitas parsial.
- [ ] **UNDO tunggal:** Buat grid baru (`ASG-0003`), lalu jalankan `UNDO` (`Ctrl+Z`) 1 kali. Pastikan seluruh entitas `ASG-0003` dan metadata XRecord `ASG-0003` ikut terbatalkan, sementara `ASG-0001` dan `ASG-0002` tetap utuh (verifikasi dengan `ASGRIDCHECK`).

## 6. Uji Regresi Fitur V2.1 (Live Preview, Pagination, Arial, Environment)
- [ ] **Live Preview:** Saat dialog terbuka, preview langsung muncul; mengubah jumlah grid, jarak individual, skala, extension, atau posisi bubble langsung memperbarui preview; berpindah halaman `< Prev` / `Next >` pada grid > 8 tidak menghilangkan data; grid besar (misal `15 × 28`) mengaktifkan *Dense Mode* dan tetap terbaca.
- [ ] **Penomoran > 26:** Uji grid dengan `Vertical Grids = 28` dan verifikasi label sumbu vertikal berlanjut `... Z, AA, AB`.
- [ ] **Isolasi Font Arial:** Verifikasi seluruh teks ASGRID memakai Text Style `ASGRID-ARIAL` (`arial.ttf`), sementara teks eksisting di gambar (`Standard`), `TEXTSTYLE` aktif, `DIMSTYLE` aktif, dan `UCS` pengguna tidak berubah.
