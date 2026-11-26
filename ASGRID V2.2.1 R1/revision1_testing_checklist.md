# TESTING CHECKLIST — ASGRID V2.2.1 REVISION 1 (AutoCAD 2021)

*Catatan: Seluruh pemeriksaan statis telah lulus, tetapi **pengujian runtime pada AutoCAD 2021 belum dilakukan**. Jalankan checklist ini di AutoCAD 2021 setelah review kode.*

## 0. Persiapan Lingkungan Uji
- [ ] Tempatkan folder `ASGRID V2.2.1 REVISION 1` (`ASGRID_V2_2_1_R1.lsp` & `ASGRID_V2_2_1.dcl`) pada urutan teratas *Support File Search Path* dan *Trusted Locations*.
- [ ] Muat `ASGRID_V2_2_1_R1.lsp` melalui `APPLOAD` (jangan memuat file LSP versi lain pada sesi yang sama).

## 1. Uji `asgrid:meta-extract-raw-payload` (Termasuk Kondisi Ambigu DXF)
Jalankan di command line AutoCAD 2021 (read-only):
- [ ] **XRecord standar dengan header `280=1` dan payload `280=0` & `280=1`:**
  `(asgrid:meta-extract-raw-payload '((-1 . "e") (0 . "XRECORD") (100 . "AcDbXrecord") (280 . 1) (300 . "SCHEMA_VER") (1 . "1.0") (300 . "CUSTOM_280") (280 . 0) (300 . "CUSTOM_280B") (280 . 1)))`
  → Mengembalikan `'((300 . "SCHEMA_VER") (1 . "1.0") (300 . "CUSTOM_280") (280 . 0) (300 . "CUSTOM_280B") (280 . 1))`.
- [ ] **Tanpa header `280`, payload pertama `300`:**
  `(asgrid:meta-extract-raw-payload '((100 . "AcDbXrecord") (300 . "SCHEMA_VER") (1 . "1.0") (280 . 1)))`
  → Mengembalikan `'((300 . "SCHEMA_VER") (1 . "1.0") (280 . 1))`.
- [ ] **Tanpa header `280`, payload pertama `(280 . 99)` (di luar rentang flag DXF `0..5`):**
  `(asgrid:meta-extract-raw-payload '((100 . "AcDbXrecord") (280 . 99) (300 . "A")))`
  → Mengembalikan `'((280 . 99) (300 . "A"))` (dipertahankan sebagai payload).
- [ ] **Kasus ambigu terdokumentasi (tanpa header `280`, payload pertama `(280 . 1)` dalam rentang `0..5`):**
  `(asgrid:meta-extract-raw-payload '((100 . "AcDbXrecord") (280 . 1) (300 . "A")))`
  → Mengembalikan `'((300 . "A"))` (perilaku sesuai batasan DXF yang didokumentasikan).
- [ ] **Input invalid:** `(asgrid:meta-extract-raw-payload nil)` dan `(asgrid:meta-extract-raw-payload 123)` → mengembalikan `nil` tanpa error.

## 2. Uji Pra-Validasi Snapshot pada `asgrid:meta-restore-xrecord` (Dictionary Tidak Disentuh)
Pada DWG salinan uji yang memiliki grup `"ASG-0001"` (`(setq snap1 (asgrid:meta-get-xrecord-snapshot "ASG-0001"))`):
- [ ] **Snapshot bukan XRECORD:** `(asgrid:meta-restore-xrecord "ASG-0001" '((0 . "LINE") (100 . "AcDbLine")))` → mengembalikan `nil`, pesan `"Dictionary tidak disentuh."`, `"ASG-0001"` utuh.
- [ ] **Snapshot tanpa marker `AcDbXrecord`:** `(asgrid:meta-restore-xrecord "ASG-0001" '((0 . "XRECORD") (300 . "GROUP_ID") (1 . "ASG-0001")))` → mengembalikan `nil`, `"ASG-0001"` utuh.
- [ ] **Snapshot metadata korup/tidak lengkap:** `(asgrid:meta-restore-xrecord "ASG-0001" '((0 . "XRECORD") (100 . "AcDbXrecord") (280 . 1) (300 . "GROUP_ID") (1 . "ASG-0001")))` → ditolak oleh `asgrid:meta-validate-spec`, `"ASG-0001"` utuh.
- [ ] **Mismatch `GROUP_ID`:** `(asgrid:meta-restore-xrecord "ASG-0002" snap1)` (snapshot milik `"ASG-0001"` dipakai untuk `"ASG-0002"`) → mengembalikan `nil` dengan pesan mismatch `GROUP_ID`, `"ASG-0002"` tidak disentuh.

## 3. Uji Restore Normal, Fallback & Status `curEname` `nil`
- [ ] **Restore normal:** Edit `"ASG-0001"` lewat `ASGRIDEDIT` (`Bubble Diameter 8.0 → 10.0`), lalu panggil `(asgrid:meta-restore-xrecord "ASG-0001" snap1)` → mengembalikan `T`, `BUBBLE_DIA_PRINT` kembali `8.0`, `ASGRIDCHECK` → `0 MASALAH`.
- [ ] **Restore saat `curEname` `nil` (entry dictionary sebelumnya dihapus manual pada DWG uji):** Hapus entry `"ASG-0001"` dari NOD via `(dictremove (asgrid:meta-get-root-dict nil) "ASG-0001")`, lalu panggil `(asgrid:meta-restore-xrecord "ASG-0001" snap1)` → mengembalikan `T` dan `"ASG-0001"` kembali terbaca utuh di `ASGRIDCHECK`.

## 4. Uji Regresi Penuh (`ASGRID`, `ASGRIDEDIT`, `ASGRIDCHECK`)
- [ ] Buat 2+ grid berulang dengan `ASGRID`, edit berulang 3× dengan `ASGRIDEDIT` (cek `LINE` & `EXT_LEN` tidak berubah, payload XRecord tidak menumpuk), uji `Cancel` & `UNDO`, simpan-tutup-buka DWG, lalu jalankan `ASGRIDCHECK` → `0 MASALAH`.
