# Changelog — ASDIM V1.0 Phase 1 (Foundation & Read-Only Audit)

**Proyek:** CIVIL DRAFTING AUTOMATION — Modul ASDIM  
**Target Runtime:** AutoCAD 2021 (AutoLISP Standar — 100% READ-ONLY)  
**Acuan Spesifikasi:** `ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md`  
**Acuan Sumber ASGRID:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` (tetap utuh tanpa modifikasi)  
**Tanggal:** 26 November 2026

## Ringkasan Implementasi Phase 1

- **File Sumber Baru (`ASDIM_V1_0_PHASE1.lsp`):**
  - 10 section terstruktur dengan prefix `asdim:*` (31 `defun` total termasuk `c:ASDIM` dan `*error*` lokal; 0 duplikasi nama fungsi; 0 variabel global).
  - **Pembacaan XData `ASGRID_OBJ` (read-only):** `asdim:parse-asgrid-xdata` memvalidasi tepat 6 field identitas aktual ASGRID R3 (`GroupID`, `Role`, `AxisDir`, `AxisIdx`, `EndTag`, `SchemaVer`).
  - **Pembacaan NOD `ASGRID_GROUPS` & `XRECORD` (read-only):** `asdim:nod-get-asgrid-dict`, `asdim:nod-find-group-xrecord`, `asdim:xrec-parse-dxf`, dan `asdim:meta-read-group` membaca seluruh payload `(300 . <KEY>)` + kode DXF native tanpa pernah membuat dictionary atau mengubah entitas.
  - **Validator Metadata (`asdim:meta-validate-spec`):** Memeriksa 24 key wajib, `SCHEMA_VER = "1.0"`, kecocokan `GROUP_ID`, konsistensi `DIST_H_COUNT`/`DIST_V_COUNT` terhadap `NUM_H - 1`/`NUM_V - 1`, interval `> 0`, `BASE_PT_WCS` & `ELEVATION`, fallback opsional `ANNO_EXT_LEN` → `EXT_LEN`, serta kasus tepi `NUM_H = 1` / `NUM_V = 1`.
  - **Kalkulator Koordinat WCS (`asdim:compute-cumulative`, `asdim:calc-grid-coords`):** Menghitung `cumX` dari `(X0, DIST_V)`, `cumY` dari `(Y0, DIST_H)`, serta titik ujung garis horizontal dan vertikal WCS pada elevasi `Z0`.
  - **Entity Discovery Khusus Model Space (`asdim:discover-group-entities`):** Filter ganda `'(410 . "Model")` pada `ssget "_X"` dan pemeriksaan DXF `410`/`67` per entitas (`asdim:is-model-space-entity`), memisahkan `LINE`, `BUBBLE`, `TEXT`, dan tipe DXF tidak cocok.
  - **Validator Geometri Aktual (`asdim:validate-grid-geometry`, `asdim:check-single-line-geom`):** Memeriksa jumlah garis H/V, posisi & panjang (termasuk urutan titik ujung normal/terbalik), orientasi ortogonal WCS, elevasi Z, garis hilang, duplikat slot, serta memisahkan entitas anotasi (`BUBBLE`/`TEXT`) agar tidak salah dianggap garis grid.
  - **Laporan & Perintah CLI (`asdim:print-audit-report`, `c:ASDIM`):** Antarmuka command-line murni tanpa DCL dan tanpa pembuatan `DIMENSION`.

## Ruang Lingkup yang Sengaja Tidak Diimplementasikan di Phase 1

- Pembuatan entitas native `DIMENSION` (masuk Phase 2).
- Pembuatan `ASDIM-ARIAL`, `ASDIM-STYLE`, layer `AS-DIM`, RegApp `ASDIM_OBJ`/`ASDIM_TX_TMP` (masuk Phase 2).
- Antarmuka dialog DCL, konfirmasi satuan interaktif, dan transaksi/rollback (masuk Phase 3).
- Live Preview dan perubahan kode ASGRID R3.

## Status Verifikasi

- **Validasi Statis:** LULUS seluruh pemeriksaan statis (keseimbangan kurung/string, 0 panggilan mutasi, filter Model Space, SHA-256 ASGRID R3 utuh).
- **Pengujian Runtime AutoCAD 2021:** **NOT RUN** — belum diuji langsung di AutoCAD 2021.
