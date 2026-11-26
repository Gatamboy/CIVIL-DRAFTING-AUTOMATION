# Changelog — ASDIM V1.0 Phase 1 Revision 1 (Narrow Validation Hardening)

**Baseline Sebelumnya:** `ASDIM V1_0 PHASE 1/ASDIM_V1_0_PHASE1.lsp` *(dipertahankan utuh tanpa perubahan)*  
**Target Runtime:** AutoCAD 2021 (AutoLISP Standar — 100% READ-ONLY)  
**Acuan Spesifikasi:** `ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md`  
**Acuan ASGRID:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` *(utuh tanpa perubahan)*  
**Tanggal:** 26 November 2026

## Ringkasan Perubahan (Phase 1 → Phase 1 R1)

| No | Fungsi / Lokasi (R1) | Perubahan |
| :--- | :--- | :--- |
| **1** | Header & `asdim:version-label` (L2, L20) + Banner muat (L1152) | Memperbarui label versi dari `"ASDIM V1.0-Phase1"` menjadi `"ASDIM V1.0-Phase1-R1"`. |
| **2** | `asdim:meta-validate-spec` (L399–L470) | Menambahkan parameter `xdataSchemaVer` serta variabel lokal `axH` dan `axV`. Menegakkan 4 syarat konsistensi `SCHEMA_VER`: (1) `xdataSchemaVer` harus bertipe string, (2) `xdataSchemaVer` harus sama dengan `"1.0"`, (3) `SCHEMA_VER` metadata XRecord harus sama dengan `"1.0"`, dan (4) `xdataSchemaVer` harus sama dengan `SCHEMA_VER` metadata. Menambahkan validasi ketat `AXIS_DIR_H = "X"` dan `AXIS_DIR_V = "Y"` sesuai kontrak ASGRID R3 (`fn-meta-build-spec` L2219–L2220). |
| **3** | `c:ASDIM` (L1081–L1130) | Menambahkan variabel lokal `xSchemaVer`, mengekstrak `SCHEMA_VER` dari hasil `asdim:parse-asgrid-xdata`, dan meneruskannya ke `(asdim:meta-validate-spec spec groupId xSchemaVer)`. Jika validasi gagal, audit berhenti dan audit geometri tidak dilanjutkan. |

## Bagian yang Tidak Diubah

- Kalkulator koordinat WCS (`asdim:compute-cumulative`, `asdim:calc-grid-coords`) tidak diubah.
- Pembacaan XData (`asdim:parse-asgrid-xdata`), NOD (`asdim:nod-get-asgrid-dict`, `asdim:nod-find-group-xrecord`), dan XRecord (`asdim:xrec-parse-dxf`, `asdim:meta-read-group`) tidak diubah.
- Filter Model Space (`asdim:is-model-space-entity`, `asdim:discover-group-entities`) dan validator geometri garis (`asdim:check-single-line-geom`, `asdim:validate-grid-geometry`) tidak diubah.
- Prinsip 100% READ-ONLY dipertahankan penuh (0 fungsi mutasi, 0 fitur Phase 2/Phase 3, 0 perubahan pada ASGRID R3).

## Status Verifikasi

- **Pemeriksaan Statis:** LULUS seluruh validasi statis (lihat `phase1_r1_technical_review.md`).
- **Pengujian Runtime AutoCAD 2021:** **NOT RUN** — seluruh 26 skenario (`P1-01`–`P1-20` dan `P1-R1-01`–`P1-R1-06`) belum dijalankan di AutoCAD 2021.
