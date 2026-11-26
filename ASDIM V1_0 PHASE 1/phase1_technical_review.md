# Technical Review — ASDIM V1.0 Phase 1 (Foundation & Read-Only Audit)

**Target Runtime:** AutoCAD 2021 (AutoLISP Standar)  
**File Diulas:** `ASDIM V1_0 PHASE 1/ASDIM_V1_0_PHASE1.lsp` (SHA-256: `35c17e8c9f3c3443309ad0bf4fc74d353e5d558d34fe80664b9139eaee11e977`)  
**Acuan Spesifikasi:** `ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md`  
**Acuan Sumber ASGRID:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` (SHA-256 utuh: `c97af3f59dbece69f7caab4dcd2d94af2e8f05d1f72743eaa04c120ff685570b`)

## 1. Pemetaan Audit Sumber ASGRID V2.2.1 R3 → ASDIM Phase 1

Seluruh logika pembacaan dan validasi diturunkan langsung dari implementasi aktual `ASGRID_V2_2_1_R3.lsp` tanpa menyalin ketergantungan sesi terhadap file ASGRID:

| Fungsi Acuan ASGRID R3 | Baris R3 | Padanan di `ASDIM_V1_0_PHASE1.lsp` | Penyesuaian Khusus Phase 1 |
| :--- | :--- | :--- | :--- |
| `asgrid:compute-cumulative` | L117–L125 | `asdim:compute-cumulative` | Identik secara matematis (`float` kumulatif). |
| `asgrid:get-anno-ext-len` | L395–L403 | `asdim:get-anno-ext-len` | Identik (fallback `ANNO_EXT_LEN` → `EXT_LEN`). |
| `asgrid:meta-get-root-dict` | L406–L435 | `asdim:nod-get-asgrid-dict` | Selalu *read-only* (menghapus cabang pembuatan dictionary). |
| `asgrid:parse-entity-xdata-for-app` | L456–L489 | `asdim:parse-asgrid-xdata` | Mengembalikan status terstruktur (`OK` / `NO_XDATA` / `CORRUPT` / `INVALID_ENAME`) untuk pesan diagnostik spesifik. |
| `asgrid:meta-parse-xrecord-dxf` | L577–L656 | `asdim:xrec-parse-dxf` | Menambah validasi wajib `(100 . "AcDbXrecord")` dan deteksi key skalar duplikat pada XRecord korup. |
| `asgrid:meta-read-group` | L659–L675 | `asdim:meta-read-group` + `asdim:nod-find-group-xrecord` | Membedakan error `NO_DICT`, `GROUP_NOT_FOUND`, dan `INVALID_XRECORD`. |
| `asgrid:meta-validate-spec` | L1226–L1370 | `asdim:meta-validate-spec` | Menambah cek kecocokan `GROUP_ID` XData vs metadata, cek `SCHEMA_VER = "1.0"`, serta evaluasi arah dimensi `NUM_H = 1` / `NUM_V = 1`. |
| `fn-geometry-engine` | L2353–L2397 | `asdim:calc-grid-coords` | Menghitung koordinat ekspektasi garis H (sejajar X pada `cumY`) dan V (sejajar Y pada `cumX`) dalam WCS pada elevasi `Z0`. |
| `asgrid:audit-group-entities` | L1827–L1968 | `asdim:discover-group-entities` + `asdim:validate-grid-geometry` | **Diperkuat:** menambah filter ganda Model Space (`410="Model"`, `67=0/nil`) dan verifikasi koordinat aktual DXF `(10)`/`(11)` garis `LINE` terhadap metadata (celah yang tidak dicek di ASGRID R3). |

## 2. Arsitektur 10 Section (`ASDIM_V1_0_PHASE1.lsp`)

1. **Section 1 — Utility Functions:** Konstanta (`asdim:dict-name`, `asdim:xdata-app`, `asdim:schema-ver`, `asdim:tol-meta = 1e-6`, `asdim:tol-geom = 1e-4`), `asdim:trim`, `asdim:index-to-alpha`, formatter, perbandingan titik 3D, dan `asdim:is-model-space-entity`.
2. **Section 2 — XData Reader:** `asdim:parse-asgrid-xdata`.
3. **Section 3 — NOD Dictionary Reader:** `asdim:nod-get-asgrid-dict`, `asdim:nod-find-group-xrecord`.
4. **Section 4 — XRecord Reader:** `asdim:xrec-parse-dxf`, `asdim:meta-read-group`.
5. **Section 5 — Metadata Validator:** `asdim:meta-validate-spec`.
6. **Section 6 — Coordinate Calculator:** `asdim:compute-cumulative`, `asdim:calc-grid-coords`.
7. **Section 7 — Entity Discovery:** `asdim:discover-group-entities`.
8. **Section 8 — Geometry Validator:** `asdim:calc-expected-counts`, `asdim:check-single-line-geom`, `asdim:validate-grid-geometry`.
9. **Section 9 — Audit Report:** `asdim:print-audit-report`.
10. **Section 10 — Main Command:** `c:ASDIM` dengan `*error*` lokal *read-only*.

## 3. Hasil Pemeriksaan Statis & Keamanan Read-Only

| No | Pemeriksaan Statis | Hasil | Bukti |
| :--- | :--- | :--- | :--- |
| 1 | Keseimbangan tanda kurung & string literal | **LULUS** | `depth = 0`, `max_depth = 19`, 1.135 baris, 0 string tidak tertutup. |
| 2 | Duplikasi nama fungsi & konvensi prefix | **LULUS** | 31 `defun`, 0 duplikasi; seluruh helper berawalan `asdim:*` + `c:ASDIM` + `*error*` lokal. |
| 3 | **Audit Keamanan 100% Read-Only** | **LULUS** | **0 panggilan** pada seluruh simbol terlarang: `entmake`, `entmakex`, `entmod`, `entupd`, `entdel`, `dictadd`, `dictremove`, `dictrename`, `regapp`, `setvar`, `command`, `command-s`, `vla-add`, `vla-delete`, `vla-put-`, `load_dialog`, `new_dialog`, `start_dialog`, `findfile`. |
| 4 | Filter Model Space | **LULUS** | Satu-satunya `ssget "_X"` (baris 673) memuat `'(410 . "Model")`, ditambah validasi per-entitas `asdim:is-model-space-entity` pada `entsel` dan setiap hasil `ssget`. |
| 5 | Isolasi ASGRID V2.2.1 R3 | **LULUS** | SHA-256 `ASGRID_V2_2_1_R3.lsp` dan `ASGRID_V2_2_1_R3.dcl` 100% tidak berubah. |
| 6 | Ruang lingkup Phase 1 | **LULUS** | Tidak ada kode pembuatan `DIMENSION`, tidak ada DCL, tidak ada Live Preview. |

## 4. Potensi Keterbatasan Phase 1

1. **Entitas Top-Level Model Space Saja:** `ssget "_X"` dengan `'(410 . "Model")` tidak memindai entitas ASGRID yang berada di dalam definisi `BLOCK` (`INSERT`).
2. **Toleransi Geometri Tetap (`1e-4` DU):** Garis yang bergeser lebih dari `1e-4` DU dari metadata akan ditolak; toleransi ini disengaja agar tidak ada dimensi yang lahir dari garis bergeser, namun dapat dievaluasi lagi jika ada skenario gambar berkoordinat sangat besar (*large world coordinates*).
3. **Kompatibilitas Terverifikasi Terbatas pada ASGRID V2.2.1 R3:** Versi ASGRID lebih lama (`V2.1`–`V2.2.1 R2`) belum diaudit secara individual.
4. **Pengujian Runtime Belum Dilakukan:** Seluruh verifikasi di atas bersifat **statis**; perilaku runtime nyata di AutoCAD 2021 **belum diuji** (`NOT RUN`).
