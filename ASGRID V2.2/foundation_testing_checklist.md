# FOUNDATION TESTING CHECKLIST — ASGRID V2.2 (Phase 1 Regression & Compatibility)

*Catatan: Kode Phase 1 telah lolos verifikasi statis menyeluruh, tetapi **belum dijalankan langsung di AutoCAD 2021**. Jalankan checklist ini di AutoCAD 2021 untuk memastikan regresi nol sebelum melanjutkan ke Phase 2 (`ASGRIDEDIT`).*

## 0. Persiapan Lingkungan Uji
- [ ] Simpan folder `ASGRID V2.2` (`ASGRID_V2_2.lsp` & `ASGRID_V2_2.dcl`) pada direktori yang terdaftar di `OPTIONS` → *Files* → *Support File Search Path* dan *Trusted Locations*.
- [ ] Pastikan file V2.1.2 tidak dimuat bersamaan pada sesi AutoCAD yang sama.
- [ ] Muat `ASGRID_V2_2.lsp` via `APPLOAD`; pastikan command line menampilkan `[ASGRID V2.2 Foundation] Berhasil dimuat. Perintah: ASGRID | ASGRIDCHECK (Phase 1).`
- [ ] Pastikan perintah `ASGRIDEDIT` belum ada pada Phase 1 (mengetik `ASGRIDEDIT` menghasilkan *Unknown command*).

## 1. Uji Regresi Generator `ASGRID` (Pasca-Ekstraksi Shared Service)
- [ ] Jalankan `ASGRID`, pastikan dialog `asgrid_v2_2` terbuka normal dengan label `C. Scale & Annotation` rapi, default Horizontal `4000`, default Vertical `5000`, dan Live Preview langsung tampil.
- [ ] Ubah jumlah grid menjadi `4 × 4` dengan spacing bervariasi (Horizontal `4000, 3500, 4000`; Vertical `5000, 6000, 5000`), skala `1:100`, teks `2.5`, bubble `8.0`, extension `1500`, posisi `Both Ends`. Verifikasi Live Preview berubah real-time.
- [ ] Klik `OK` dan pilih titik awal `(0,0)`. Verifikasi:
  - `Hard Gate Metadata : LOLOS (Tulis -> Baca Balik -> Deep Compare OK)`
  - `Validasi Entitas : Lines 8/8 | Bubbles 16/16 | Texts 16/16 (Total 40/40 OK)`
  - `Perpanjangan (G / A) : 1500.00 mm / 1500.00 mm`
  - Jarak antar garis as dan posisi bubble identik 100% dengan V2.1.2 (cek via `DIST` & `PROPERTIES`).
- [ ] Uji variasi posisi bubble (`Start` dan `End`), pagination (`12 × 28` dengan penomoran hingga `AA, AB`), dan `Dense Mode` pada Live Preview.
- [ ] Uji Text Style `ASGRID-ARIAL` (`arial.ttf`), layer `AS-GRID`/`AS-BUBBLE`/`AS-TEXT`, serta pastikan `TEXTSTYLE`, `DIMSTYLE`, `INSUNITS`, `LTSCALE`, dan `UCS` aktif tidak berubah.

## 2. Uji Metadata `ANNO_EXT_LEN` & Kompatibilitas Grid Lama
- [ ] Periksa XRecord grup baru buatan V2.2 dengan `(asgrid:meta-read-group "ASG-0001")`; pastikan kedua key `EXT_LEN` (`1500.0`) dan `ANNO_EXT_LEN` (`1500.0`) tersimpan.
- [ ] Buka file DWG berisi grid buatan **V2.1.2** (tanpa `ANNO_EXT_LEN`), muat `ASGRID_V2_2.lsp`, lalu jalankan `ASGRIDCHECK`.
- [ ] Pastikan grid V2.1.2 lulus 100% (`0 MASALAH`) dan baris `Extension` menampilkan `(fallback EXT_LEN)`.

## 3. Uji Shared Audit Service (`ASGRIDCHECK` — 100% READ-ONLY)
- [ ] Jalankan `ASGRIDCHECK` pada grid normal → `0 MASALAH` dan status `OK (Lengkap, DXF/Role/AxisIdx/EndTag valid, 0 duplikat)`.
- [ ] Hapus 1 bubble (`ERASE`) → `ASGRIDCHECK` mendeteksi kekurangan entitas tanpa mengubah DWG → `UNDO`.
- [ ] Duplikasi 1 bubble (`COPY`) → `ASGRIDCHECK` mendeteksi `Duplikasi Slot` tanpa menghapus objek → `UNDO`.

## 4. Uji Transaction Safety, Pembatalan & UNDO
- [ ] Klik `Cancel` di dialog → 0 objek/metadata baru.
- [ ] Klik `OK` lalu tekan `ESC` saat pilih titik awal → `CMDECHO` pulih, 0 objek/metadata parsial.
- [ ] Tekan `UNDO` (`Ctrl+Z`) 1 kali setelah membuat grid → seluruh entitas & metadata grup baru terbatalkan, grup lama tetap utuh (verifikasi via `ASGRIDCHECK`).
- [ ] Simpan DWG, tutup dan buka kembali AutoCAD 2021, muat `ASGRID_V2_2.lsp`, jalankan `ASGRIDCHECK` → semua grup tetap terbaca utuh (`0 MASALAH`).
