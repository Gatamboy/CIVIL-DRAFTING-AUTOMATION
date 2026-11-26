# TESTING CHECKLIST — ASGRID V2.2.1 (XRecord Reliability Hardening, AutoCAD 2021)

*Catatan: Seluruh pemeriksaan statis telah lulus, tetapi **pengujian runtime pada AutoCAD 2021 belum dilakukan**. Jalankan checklist ini di AutoCAD 2021 dan konfirmasi hasilnya.*

## 0. Persiapan Lingkungan Uji
- [ ] Tempatkan folder `ASGRID V2.2.1 (RELIABILITY HARDENING)` pada urutan teratas *Support File Search Path* dan *Trusted Locations* (jangan memuat `ASGRID_V2_2.lsp` dari folder lain di sesi yang sama).
- [ ] Muat `ASGRID_V2_2_1.lsp` via `APPLOAD`; pastikan tidak ada error load dan perintah `ASGRID`, `ASGRIDEDIT`, `ASGRIDCHECK` tersedia.

## 1. Uji `asgrid:meta-extract-raw-payload` (Payload Group Code `280` & Edge Cases)
Jalankan ekspresi uji berikut langsung di command line AutoCAD 2021 (read-only):
- [ ] Uji payload dengan group code `280`:
  `(asgrid:meta-extract-raw-payload '((-1 . "e") (0 . "XRECORD") (100 . "AcDbXrecord") (280 . 1) (300 . "SCHEMA_VER") (1 . "1.0") (300 . "CUSTOM_280") (280 . 0)))`
  → Harus mengembalikan `'((300 . "SCHEMA_VER") (1 . "1.0") (300 . "CUSTOM_280") (280 . 0))` (header `(280 . 1)` dilewati, payload `(280 . 0)` dipertahankan!).
- [ ] Uji tanpa header `280`:
  `(asgrid:meta-extract-raw-payload '((100 . "AcDbXrecord") (300 . "A") (280 . 1)))`
  → Harus mengembalikan `'((300 . "A") (280 . 1))`.
- [ ] Uji input aman: `(asgrid:meta-extract-raw-payload nil)` dan `(asgrid:meta-extract-raw-payload "invalid")` → keduanya mengembalikan `nil` tanpa error.

## 2. Uji `asgrid:meta-restore-xrecord` (Restore & Verifikasi Read-Back)
Pada file DWG salinan uji yang memiliki grup `"ASG-0001"`:
- [ ] Ambil snapshot: `(setq snap1 (asgrid:meta-get-xrecord-snapshot "ASG-0001"))`.
- [ ] Edit `ASG-0001` lewat `ASGRIDEDIT` (ubah `Bubble Diameter` dari `8.0` → `10.0`).
- [ ] Panggil `(asgrid:meta-restore-xrecord "ASG-0001" snap1)` → harus mengembalikan `T`.
- [ ] Cek `(asgrid:meta-read-group "ASG-0001")` → `BUBBLE_DIA_PRINT` kembali `8.0`, `DIST_H_COUNT == (length DIST_H)`, tanpa penumpukan payload.
- [ ] Uji pemulihan dengan payload `280` buatan di snapshot (pada DWG uji): pastikan pasangan `(280 . 0)` di payload tetap terbaca utuh setelah restore via `entget`.
- [ ] Uji parameter tidak valid: `(asgrid:meta-restore-xrecord "" snap1)` dan `(asgrid:meta-restore-xrecord "ASG-0001" nil)` → mengembalikan `nil` dengan pesan error jelas dan tidak merusak entry `"ASG-0001"`.

## 3. Uji Regresi Penuh `ASGRID`, `ASGRIDEDIT` (Mode 1), dan `ASGRIDCHECK`
- [ ] **Generate berulang (`ASGRID`):** Buat `ASG-0001`, `ASG-0002`, `ASG-0003` pada DWG yang sama → seluruhnya berhasil tanpa error RegApp.
- [ ] **Edit berulang (`ASGRIDEDIT`):** Edit `ASG-0001` sebanyak 3 kali berturut-turut (ubah 5 parameter anotasi) → seluruhnya berhasil, `LINE` & `EXT_LEN` tidak berubah, payload XRecord tidak menumpuk.
- [ ] **Kompatibilitas grid lama:** Buka DWG buatan V2.1.2 / V2.2, jalankan `ASGRIDEDIT` dan `ASGRIDCHECK` → `0 MASALAH`.
- [ ] **Cancel & UNDO:** Uji `Cancel` di dialog `ASGRIDEDIT` dan `UNDO` tunggal pasca-edit → kondisi DWG & metadata tetap konsisten (`ASGRIDCHECK` → `0 MASALAH`).
- [ ] **DWG Persistence:** Simpan DWG, tutup dan buka kembali AutoCAD 2021, muat `ASGRID_V2_2_1.lsp`, jalankan `ASGRIDCHECK` → semua grup sehat (`0 MASALAH`).
