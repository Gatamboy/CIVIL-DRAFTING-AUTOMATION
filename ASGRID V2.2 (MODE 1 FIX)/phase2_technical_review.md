# PHASE 2 TECHNICAL REVIEW — ASGRID V2.2 (`ASGRIDEDIT` Mode 1)

- **Baseline:** `ASGRID V2.2/ASGRID_V2_2.lsp` & `ASGRID_V2_2.dcl` (Phase 1 teruji di AutoCAD 2021)
- **Target Rilis:** `ASGRID V2.2 Phase 2/ASGRID_V2_2.lsp` & `ASGRID_V2_2.dcl`
- **Status Pengujian:** Verifikasi statis lulus penuh; eksekusi langsung di AutoCAD 2021 belum dilakukan dan perlu dijalankan mengikuti `phase2_testing_checklist.md`.

## 1. Pemakaian Ulang Shared Services Phase 1 & Penambahan Minimal

`c:ASGRIDEDIT` memakai ulang 100% shared services Phase 1 tanpa duplikasi logika:
- `asgrid:meta-read-group`, `asgrid:meta-validate-spec`, `asgrid:meta-compare-specs`, `asgrid:meta-get-xrecord-snapshot`, `asgrid:meta-update-group`, `asgrid:meta-restore-xrecord`
- `asgrid:annotation-engine`, `asgrid:get-anno-ext-len`, `asgrid:calc-expected-counts`
- `asgrid:audit-group-entities`, `asgrid:prev-render-grid`, `asgrid:check-insunits-warning`

Tambahan minimal pada `asgrid:*` di Phase 2:
- `asgrid:xdata-tmp-app` (`"ASGRID_TX_TMP"`) & `asgrid:ensure-regapp` (berbasis `tblsearch "APPID"`).
- `asgrid:make-obj-xdata-for-app` & `asgrid:parse-entity-xdata-for-app` + dukungan key internal opsional `"_XDATA_APP_OVERRIDE"` di `asgrid:annotation-engine` (generator `c:ASGRID` tidak menyetel key ini sehingga perilaku Create 100% tidak berubah).
- `asgrid:find-font-file`, `asgrid:list-drawing-styles`, `asgrid:style-is-annotative`, `asgrid:validate-text-style`.

## 2. Mekanisme Temporary Transaction Identity (`ASGRID_TX_TMP`)

Untuk memastikan anotasi sementara pada **STEP B–C** tidak pernah dianggap sebagai duplikasi slot oleh `ASGRIDCHECK` maupun `ssget "_X" '((-3 ("ASGRID_OBJ")))`:
1. Pada **STEP B**, `c:ASGRIDEDIT` memanggil `(asgrid:annotation-engine tempSpec)` dengan `("_XDATA_APP_OVERRIDE" . "ASGRID_TX_TMP")`. Seluruh ename baru dilacak langsung dari return value `(nth 0 annRes)` ke `txNewAnnoEnts` (tanpa pencarian global).
2. Pada **STEP C**, `fn-edit-verify-temp-annos` memverifikasi setiap ename di `txNewAnnoEnts` menggunakan `asgrid:parse-entity-xdata-for-app` untuk `"ASGRID_TX_TMP"` (cek jumlah bubble/text, DXF type `CIRCLE`/`TEXT`, `TEXT_STYLE`, `AxisIdx`, `EndTag`, dan 0 duplikasi slot internal).
3. Pada **STEP D**, setelah seluruh `oldAnnoEnts` dihapus via `entdel`, `fn-edit-promote-temp-to-final` menjalankan satu operasi `entmod` per entitas dengan `(-3 ("ASGRID_TX_TMP") ("ASGRID_OBJ" ...))` yang secara atomik menghapus XData sementara sekaligus memasang XData final `ASGRID_OBJ`.

## 3. Strategi Rollback & Batasan Atomisitas AutoLISP

- **Snapshot pra-swap (STEP A):** Sebelum menyentuh entitas, sistem menyimpan `oldXrecSnap`, `oldAnnoSnapshots` (DXF lengkap + XData `ASGRID_OBJ` tiap anotasi lama), dan `oldLineSnapCoords` (`ename`, titik `10`, titik `11` tiap `LINE`).
- **Pemulihan pasca-swap (STEP D/E/F gagal):**
  1. Seluruh `txNewAnnoEnts` dihapus via `entdel`.
  2. Seluruh `txDeletedOldEnts` dipulihkan via *undelete* native `(entdel e)`; apabila `(entget e)` masih `nil`, sistem otomatis membuat ulang entitas dari `oldAnnoSnapshots` via `entmakex` (membuang `-1`, `5`, `330`, `102`).
  3. Bila metadata sudah sempat diperbarui (`txMetaUpdated = T`), XRecord dipulihkan via `(asgrid:meta-restore-xrecord oldXrecSnap)`.
  4. Sistem menjalankan verifikasi ulang pasca-rollback (`fn-edit-verify-lines-intact` + `asgrid:audit-group-entities`). Jika rollback tidak 100% pulih, pengguna menerima peringatan jelas yang menyebut tahap gagal dan instruksi menjalankan `UNDO` (`Ctrl+Z`).
- **Jaminan Geometri `LINE`:** Daftar `oldLineEnts` tidak pernah dimasukkan ke daftar penghapusan. Pada STEP F, `fn-edit-verify-lines-intact` memverifikasi bahwa setiap `LINE` asli masih eksis dengan koordinat `(10)` dan `(11)` identik hingga toleransi `1e-6`.

## 4. Hasil Audit Statis Phase 2

| Kriteria Validasi | Hasil |
| :--- | :--- |
| Keseimbangan tanda kurung `()` & string `""` (`ASGRID_V2_2.lsp`) | **LULUS** (0 error) |
| Keseimbangan kurung kurawal `{}` & string `""` (`ASGRID_V2_2.dcl`) | **LULUS** (0 error) |
| Kecocokan Dialog ID (`asgrid_v2_2` & `asgrid_edit_v2_2`) & seluruh tile key | **LULUS** (0 tile hilang) |
| Command terdaftar (tepat 1 masing-masing, 0 bentrok) | `c:ASGRID`, `c:ASGRIDCHECK`, `c:ASGRIDEDIT` |
| Deklarasi lokal inner `defun` di semua 3 command | **LULUS** (0 bocor) |
| Namespace top-level (`asgrid:*` & `c:*` saja, 0 global data state) | **LULUS** |
| Kepatuhan READ-ONLY pada `asgrid:audit-group-entities` & `c:ASGRIDCHECK` | **LULUS** (0 operasi mutasi) |
| Keutuhan baseline Phase 1 (`ASGRID V2.2`) & `ASGRID V2.1.2` | **LULUS** (tidak dimodifikasi) |


## 5. Technical Review — Fix XRecord Update & Rollback (2026-11-26)

### A. Root Cause & Perubahan Metode
- **Root Cause:** `entmod` pada `XRECORD` di AutoCAD 2021 meng-*append* resbuf baru ke belakang resbuf lama.
- **Metode Baru (`asgrid:meta-update-group` & `asgrid:meta-restore-xrecord`):** 100% menggunakan **Replace-in-Dictionary** (`entmakex` + `dictremove` + `dictadd` + `entdel`), dengan **0 pemanggilan `entmod`** pada kedua fungsi tersebut.
- **Preservasi Snapshot Penuh (`asgrid:meta-extract-raw-payload`):** Rollback mengekstrak seluruh DXF pair mentah setelah `(100 . "AcDbXrecord")` (membuang `(280 . ...)` yang dipasang di header), sehingga field kustom atau field masa depan tetap dipertahankan utuh.

### B. Strategi Pemulihan Dictionary & Asumsi Teknis AutoCAD 2021
- **Perilaku `dictremove` pada AutoCAD 2021 (Asumsi Teknis Eksplisit):** Di AutoCAD, `(dictremove rootDict groupId)` tidak hanya melepas tautan dictionary tetapi pada umumnya juga menandai entitas `oldXrecEname` sebagai *erased* di database.
  - **Mitigasi saat sukses:** `entdel` pada `oldXrecEname` hanya dipanggil bila `(entget oldXrecEname)` masih non-nil, mencegah *double-`entdel`* (yang justru dapat meng-undelete XRecord lama menjadi yatim).
  - **Mitigasi saat gagal (`fn-reattach-old`):** Sebelum memanggil `(dictadd rootDict groupId oldXrecEname)`, kode mengecek `(if (null (entget oldXrecEname)) (entdel oldXrecEname))` untuk meng-undelete `oldXrecEname`, dan apabila `dictadd` tetap gagal, otomatis memakai fallback `entmakex` bersih dari `oldSnap`.
- **Risiko yang Masih Tersisa:**
  1. Jika AutoCAD mengalami *hard crash* tepat di antara `dictremove` dan `dictadd` sebelum pemulihan sempat dieksekusi, pemulihan penuh tetap memerlukan `UNDO` (`Ctrl+Z`).
  2. Object Handle XRecord berubah setiap kali update berhasil (tidak berdampak pada ASGRID karena seluruh entitas merujuk ke string `GROUP_ID`, bukan Handle XRecord, namun perlu diketahui bila ada integrasi eksternal berbasis Handle).

### C. Hasil Pemeriksaan Kode Statis Pasca-Fix
- Keseimbangan tanda kurung `()` & string `""`: **LULUS (0 error)**.
- Jumlah pemanggilan `entmod` di `asgrid:meta-update-group` & `asgrid:meta-restore-xrecord`: **0**.
- Pemanggil `asgrid:meta-restore-xrecord` diperbarui konsisten (`1/1` di `fn-edit-rollback`).
- `c:ASGRIDCHECK` tetap **100% READ-ONLY** (0 operasi mutasi).
- Baseline `ASGRID V2.2` (Phase 1) & `ASGRID V2.1.2` tetap utuh.
- **Status Pengujian Runtime:** Belum dijalankan langsung di AutoCAD 2021 pasca-fix; wajib diuji menggunakan skenario Test A–F di `phase2_testing_checklist.md`.
