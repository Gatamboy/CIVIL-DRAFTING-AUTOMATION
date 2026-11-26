# CHANGELOG — ASGRID V2.2.1 REVISION 1

- **Tanggal Rilis:** 2026-11-26
- **Baseline:** ASGRID V2.2.1 (`ASGRID V2.2.1 (RELIABILITY HARDENING)/ASGRID_V2_2_1.lsp` & `ASGRID_V2_2_1.dcl` — dipertahankan utuh bersama V2.2 MODE 1 FIX)
- **Target Lingkungan:** AutoCAD 2021 (AutoLISP standar + DCL, WCS, milimeter)
- **Ruang Lingkup:** Perbaikan 4 temuan *independent code review* pada ekstraksi raw payload dan mekanisme restore XRecord (MODE 2 tidak dikerjakan).
- **Status Pengujian:** Verifikasi statis lulus penuh; **belum dijalankan langsung di AutoCAD 2021**.

## Perubahan dari V2.2.1 ke V2.2.1 Revision 1

### 1. Raw Payload Extraction (`asgrid:meta-extract-raw-payload`)
- Memperketat pengenalan header *Duplicate Record Cloning Flag* pada `state = 1`: hanya melewati `(280 . val)` tepat satu elemen pertama setelah `(100 . "AcDbXrecord")` apabila `val` berupa integer pada rentang resmi DXF `0..5`.
- Jika `(280 . val)` pertama bernilai di luar `0..5` (atau bukan integer), pasangan tersebut dipertahankan sebagai payload. Seluruh pasangan `(280 . val)` pada `state = 2` (di dalam payload) tetap dipertahankan utuh.
- Mendokumentasikan secara eksplisit batasan ambiguitas inheren format DXF `AcDbXrecord` bila sebuah XRecord non-standar tidak memiliki header `280` dan payload pertamanya kebetulan berupa `(280 . 0..5)`.

### 2. Validasi Snapshot Ketat Pra-Restore (`asgrid:meta-restore-xrecord` + `asgrid:meta-parse-xrecord-dxf`)
- Mengekstrak inti parsing DXF XRecord dari `asgrid:meta-read-group` menjadi helper murni `asgrid:meta-parse-xrecord-dxf` (dipakai bersama tanpa duplikasi parser; perilaku `asgrid:meta-read-group` tetap identik).
- Menambahkan 6 gerbang pra-validasi di awal `asgrid:meta-restore-xrecord` **sebelum** `entmakex` maupun `dictremove`:
  1. `rootDict`, `groupId`, dan `snapshotData` valid (non-nil, tipe benar).
  2. `snapshotData` adalah entitas DXF `XRECORD` (`(0 . "XRECORD")`).
  3. Memiliki subclass marker `(100 . "AcDbXrecord")`.
  4. Dapat diparsing oleh `asgrid:meta-parse-xrecord-dxf`.
  5. Lolos validasi penuh `asgrid:meta-validate-spec`.
  6. `GROUP_ID` di dalam snapshot cocok tepat dengan parameter `groupId`.
- Snapshot tidak valid langsung ditolak tanpa menyentuh dictionary.

### 3. Verifikasi Payload Penuh pada `fn-reattach-cur` (Termasuk Jalur Fallback)
- Baik jalur utama (*undelete* + `dictadd curEname`) maupun jalur fallback (`entmakex fbEname` dari `curSnap` + `dictadd`) kini wajib memverifikasi `dictsearch` → `entget` → `(0 . "XRECORD")` → **`(equal chkPayload curPayload (asgrid:tol))`** sebelum mengembalikan `T`.
- Jika jalur utama gagal verifikasi payload, entry dilepas agar fallback dari `curSnap` dapat dijalankan; jika fallback juga gagal, `fbEname` dibersihkan tanpa menghapus salinan yang masih dapat dipulihkan.

### 4. Penanganan Eksplisit `curEname` `nil` (Status 3-Keadaan)
- Mengganti pola `(if curEname (fn-reattach-cur) T)` yang menyesatkan dengan simbol status eksplisit `reattachStatus`:
  - `'RESTORED` — entry lama memang ada dan berhasil dipulihkan + diverifikasi payload-nya.
  - `'NO_PREV_ENTRY` — `curEname` memang `nil` (sebelumnya tidak ada entry untuk key ini; pesan jelas tanpa mengklaim entry lama berhasil dipulihkan).
  - `'RESTORE_FAILED` — entry lama ada tetapi gagal dipulihkan; `restEname` tidak dihapus dan pesan `CRITICAL` (`UNDO Ctrl+Z`) ditampilkan.

## Komponen yang Tidak Diubah (Byte-Identik dengan Baseline V2.2.1)
- `c:ASGRID`, `c:ASGRIDEDIT`, `c:ASGRIDCHECK`, `asgrid:meta-update-group`, `ASGRID_V2_2_1.dcl`, Schema `1.0`, NOD `ASGRID_GROUPS`, RegApp `ASGRID_OBJ` & `ASGRID_TX_TMP`.
