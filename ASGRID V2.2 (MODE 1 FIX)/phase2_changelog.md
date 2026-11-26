# PHASE 2 CHANGELOG — ASGRID V2.2 (`ASGRIDEDIT` Mode 1: Annotation Editor)

- **Tanggal Rilis:** 2026-11-26
- **Baseline:** ASGRID V2.2 Phase 1 (`ASGRID V2.2/ASGRID_V2_2.lsp` & `ASGRID_V2_2.dcl` — dipertahankan utuh bersama V2.1.2)
- **Target Lingkungan:** AutoCAD 2021 (AutoLISP standar + DCL, Model Space, WCS, satuan milimeter)
- **Perintah Tersedia:** `ASGRID` (generator), `ASGRIDEDIT` (editor anotasi Mode 1), dan `ASGRIDCHECK` (diagnostik READ-ONLY).
- **Status Pengujian:** Verifikasi statis lulus penuh (0 error sintaks, 0 tile hilang, 0 mutasi pada `ASGRIDCHECK`); belum dijalankan langsung di instalasi AutoCAD 2021 lokal.

## Perubahan dari V2.2 Phase 1 ke Phase 2

### 1. Perintah Baru: `ASGRIDEDIT` (Mode 1 — Annotation Editing)
- Mengedit anotasi grid eksisting tanpa mengubah geometri garis grid (`LINE`), koordinat, jumlah sumbu, spacing, `SCALE_DENOM`, maupun `EXT_LEN`.
- **5 Parameter yang dapat diedit:**
  1. `BUBBLE_DIA_PRINT` (Printed Bubble Diameter, mm)
  2. `TEXT_H_PRINT` (Printed Text Height, mm)
  3. `TEXT_STYLE` (daftar Text Style non-Xref dari tabel `STYLE` drawing)
  4. `BUBBLE_POS` (`Both Ends` / `Start` / `End`)
  5. `ANNO_EXT_LEN` (Annotation Extension Length, mm Model Space — terpisah dari `EXT_LEN` geometri)
- **Pre-Edit Integrity Gate:** Memvalidasi XData `ASGRID_OBJ`, keberadaan metadata di NOD `ASGRID_GROUPS`, integritas `asgrid:meta-validate-spec`, serta kesehatan grup via `asgrid:audit-group-entities` sebelum membuka dialog.

### 2. Dialog DCL Baru (`asgrid_edit_v2_2` di `ASGRID_V2_2.dcl`)
- Dialog generator `asgrid_v2_2` dipertahankan 100% utuh.
- Ditambahkan dialog **`asgrid_edit_v2_2`** (*ASGRID V2.2 - Annotation Editor*) dengan 4 bagian:
  - *A. Grid Information (Read-Only):* Group ID, jumlah sumbu H/V, Drawing Scale (terkunci), `EXT_LEN` geometri (terkunci), dan `ANNO_EXT_LEN` saat ini (menampilkan info fallback untuk grid lama).
  - *B. Annotation Settings (Editable):* 5 parameter anotasi, pratinjau ukuran Model Space + peringatan non-blocking bubble sempit / `ANNO_EXT_LEN < EXT_LEN`, serta status validasi Text Style secara live.
  - *C. Live Preview:* Memakai `asgrid:prev-render-grid` dengan `geomExtLen = EXT_LEN` (tetap) dan `annoExtLen` dinamis mengikuti input baru.
  - *D. Action:* `errtile` + `OK` / `Cancel`.

### 3. Validasi Text Style Ketat (`asgrid:validate-text-style`)
- Ditambahkan helper shared: `asgrid:find-font-file`, `asgrid:list-drawing-styles`, `asgrid:style-is-annotative`, dan `asgrid:validate-text-style`.
- Menolak Xref-dependent style (`|`), shape file, style dengan `Fixed Height > 0`, style bersifat `Annotative` (via XData `AcadAnnotative`), dan style yang file font-nya tidak tersedia—tanpa mengubah definisi Text Style, `TEXTSTYLE` global, maupun `DIMSTYLE`.

### 4. Transaksi 6-Langkah dengan Temporary Transaction Identity
- Ditambahkan `asgrid:xdata-tmp-app` (`"ASGRID_TX_TMP"`), `asgrid:ensure-regapp`, `asgrid:make-obj-xdata-for-app`, `asgrid:parse-entity-xdata-for-app`, dan dukungan opsional `_XDATA_APP_OVERRIDE` pada `asgrid:annotation-engine`.
- Alur **A. Snapshot → B. Create (RegApp sementara `ASGRID_TX_TMP`) → C. Verify (berbasis daftar ename eksplisit) → D. Swap (Hapus lama + Promosi XData `ASGRID_TX_TMP` → `ASGRID_OBJ`) → E. Update Metadata & Read-Back → F. Final Audit & Commit**.
- Rollback penuh: menghapus anotasi baru, memulihkan anotasi lama via *undelete* `entdel` (dengan fallback `entmakex` dari snapshot DXF), memulihkan XRecord via `asgrid:meta-restore-xrecord`, dan memverifikasi keutuhan `LINE` serta kondisi grup pasca-rollback.


## Bug Fix — Penggantian Mekanisme XRecord Update & Rollback (2026-11-26)
- **Root Cause:** Pada AutoCAD 2021, `(entmod ...)` terhadap objek `AcDbXrecord` tidak menimpa payload lama melainkan meng-*append* resbuf baru ke resbuf lama, menyebabkan duplikasi seluruh pasangan key-value (misal `DIST_H_COUNT (3)` vs `DIST_H (6)`).
- **Perbaikan `asgrid:meta-update-group`:** Menghapus penggunaan `entmod` dan menggantinya dengan pola **Replace-in-Dictionary** 11-langkah (`entmakex` XRecord baru bersih → validasi ename → `dictremove` entry lama → `dictadd` entry baru → baca balik via `asgrid:meta-read-group` + validasi + deep compare → hanya hapus `oldXrecEname` jika masih hidup setelah seluruh verifikasi lulus). Jika `dictadd` atau verifikasi gagal, dictionary dipulihkan via `fn-reattach-old` (undelete `oldXrecEname` dengan fallback `entmakex` dari `oldSnap`).
- **Perbaikan `asgrid:meta-restore-xrecord`:** Diubah ke signature `(asgrid:meta-restore-xrecord groupId snapshotData)` tanpa `entmod`, dilengkapi helper baru `asgrid:meta-extract-raw-payload` untuk mempertahankan 100% seluruh DXF pair asli dari snapshot (termasuk key yang tidak dikenal program), memasangnya kembali via `entmakex` + `dictremove` + `dictadd`, serta memverifikasi payload baca-balik sebelum menghapus XRecord yang gagal.
- **Pembaruan Pemanggil:** Pemanggilan pada `c:ASGRIDEDIT → fn-edit-rollback` diperbarui konsisten menjadi `(asgrid:meta-restore-xrecord groupId oldXrecSnap)`.
- **Tanpa Perubahan Lain:** `ASGRID_V2_2.dcl`, generator `ASGRID`, `ASGRIDCHECK`, geometri `LINE`, Schema `1.0`, dan folder versi sebelumnya (`ASGRID V2.2` Phase 1 & `ASGRID V2.1.2`) tidak diubah.
