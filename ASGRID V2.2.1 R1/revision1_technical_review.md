# TECHNICAL REVIEW — ASGRID V2.2.1 REVISION 1

- **Baseline:** `ASGRID V2.2.1 (RELIABILITY HARDENING)/ASGRID_V2_2_1.lsp` & `ASGRID_V2_2_1.dcl`
- **Target:** `ASGRID V2.2.1 REVISION 1/ASGRID_V2_2_1_R1.lsp` & `ASGRID_V2_2_1.dcl`
- **Status Pengujian Runtime:** **Belum dilakukan di AutoCAD 2021** (hanya static validation dan simulasi kasus uji ekstraksi).

## 1. Analisis 4 Perbaikan Temuan Independent Code Review

### Temuan 1 — `asgrid:meta-extract-raw-payload` & Batasan Ambiguitas DXF `280`
- **Mekanisme Revision 1:** Pada `state = 1` (tepat elemen pertama setelah `(100 . "AcDbXrecord")`), kode hanya melewati `(280 . val)` apabila `val` adalah integer dalam rentang resmi *Duplicate Record Cloning Flag* DXF (`0..5`). Nilai `280` di luar `0..5` pada posisi pertama dan seluruh pasangan `(280 . val)` pada `state = 2` dipertahankan utuh sesuai urutan dan tipe datanya.
- **Batasan DXF yang Didokumentasikan Secara Eksplisit:** Menurut struktur DXF `AcDbXrecord`, tidak ada delimiter tambahan antara header flag `280` dan payload. Oleh karena itu, apabila suatu XRecord non-standar **tidak memiliki header flag `280`** dan **elemen pertama payload-nya persis `(280 . 0..5)`**, secara sintaksis DXF keduanya tidak dapat dibedakan dan elemen tersebut akan dianggap sebagai header flag `280`. Untuk seluruh XRecord ASGRID (yang selalu diawali `(300 . "SCHEMA_VER")`) dan XRecord standar AutoCAD (yang selalu menulis header `(280 . 1)`), ekstraksi bersifat 100% deterministik.

### Temuan 2 — Pra-Validasi Snapshot Sebelum Restore Tanpa Duplikasi Parser
- Logika parsing DXF `dList` dari `asgrid:meta-read-group` diekstrak menjadi `asgrid:meta-parse-xrecord-dxf` sehingga dipakai bersama oleh `asgrid:meta-read-group` dan `asgrid:meta-restore-xrecord`.
- Sebelum `entmakex` maupun `dictremove` dipanggil, `asgrid:meta-restore-xrecord` menolak snapshot bila: (a) bukan list/`XRECORD`, (b) tanpa `(100 . "AcDbXrecord")`, (c) gagal diparsing, (d) gagal `asgrid:meta-validate-spec`, atau (e) `GROUP_ID` snapshot `!= groupId`. Dictionary tidak tersentuh sama sekali saat validasi gagal.

### Temuan 3 — Verifikasi Payload Penuh pada `fn-reattach-cur` (Reattach & Fallback)
- Baik jalur reattach (`curEname`) maupun jalur fallback (`fbEname` dari `curSnap`) kini memverifikasi:
  `dictsearch` menemukan `groupId` → `entget` non-nil → `(0 . "XRECORD")` → `(equal chkPayload curPayload (asgrid:tol))`.
- `fn-reattach-cur` hanya mengembalikan `T` bila payload hasil baca-balik benar-benar cocok dengan `curSnap`.

### Temuan 4 — Penghapusan Return `T` Palsu Saat `curEname` `nil`
- Mengganti `(if curEname (fn-reattach-cur) T)` dengan 3 status eksplisit:
  - `'RESTORED`: `curEname` ada dan `fn-reattach-cur` mengembalikan `T` (terverifikasi payload) → bersihkan `restEname`, cetak pesan bahwa entry sebelumnya berhasil dipulihkan.
  - `'NO_PREV_ENTRY`: `curEname` memang `nil` → bersihkan `restEname`, cetak pesan jelas bahwa tidak ada entry sebelumnya untuk dipulihkan (tanpa klaim pemulihan palsu).
  - `'RESTORE_FAILED`: `curEname` ada tetapi `fn-reattach-cur` gagal → pertahankan `restEname` (jangan hapus salinan terakhir) dan cetak pesan `CRITICAL` (`UNDO Ctrl+Z`).

## 2. Hasil Static Validation Revision 1

| No | Kriteria Pemeriksaan | Hasil |
| :--- | :--- | :--- |
| 1 | Keseimbangan tanda kurung `()` & string `""` (`ASGRID_V2_2_1_R1.lsp`) | **LULUS** (`True`, 0 error) |
| 2 | Duplikasi fungsi top-level & command | **LULUS** (`NONE`; tepat 1 `c:ASGRID`, 1 `c:ASGRIDCHECK`, 1 `c:ASGRIDEDIT`) |
| 3 | Variabel global baru | **LULUS** (`NONE`; semua simbol top-level murni `asgrid:*` & `c:*`) |
| 4 | `asgrid:meta-update-group` identik dengan baseline | **LULUS** (byte-identik) |
| 5 | `c:ASGRIDCHECK` identik dengan baseline | **LULUS** (byte-identik, 100% READ-ONLY) |
| 6 | `c:ASGRID` & `c:ASGRIDEDIT` identik dengan baseline | **LULUS** (byte-identik) |
| 7 | `ASGRID_V2_2_1.dcl` identik dengan baseline | **LULUS** (byte-identik) |
| 8 | Zero `entmod` di `asgrid:meta-restore-xrecord` | **LULUS** (`0` pemanggilan) |
| 9 | Snapshot invalid ditolak sebelum `entmakex`/`dictremove` | **LULUS** (6 gerbang pra-validasi) |
| 10 | Payload restore & fallback diverifikasi terhadap snapshot (`1e-6`) | **LULUS** |
| 11 | XRecord lama tidak dihapus sebelum pengganti terverifikasi | **LULUS** |
| 12 | Simulasi 5 kasus `asgrid:meta-extract-raw-payload` (termasuk kasus ambigu DXF) | **LULUS** |
