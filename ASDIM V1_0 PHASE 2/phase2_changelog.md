# Changelog — ASDIM V1.0 Phase 2 (Style Engine & Dimension Generator)

**Baseline:** `ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp` *(dipertahankan utuh tanpa perubahan)*  
**Target Runtime:** AutoCAD 2021 (AutoLISP + Visual LISP / ActiveX)  
**Acuan Spesifikasi:** `ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md`  
**Acuan ASGRID:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` *(utuh tanpa perubahan)*  
**Tanggal:** 26 November 2026

## Ringkasan Perubahan (Phase 1 R1 → Phase 2)

### A. Fungsi Phase 1 R1 yang Dipertahankan (31/31)
- Seluruh 29 fungsi helper audit read-only Phase 1 R1 (Section 1–9: utilitas, XData `ASGRID_OBJ`, NOD `ASGRID_GROUPS`, XRecord, validator metadata + `SCHEMA_VER` + `AXIS_DIR_H`/`AXIS_DIR_V`, kalkulator koordinat WCS, entity discovery Model Space, validator geometri garis, dan laporan audit) dipertahankan utuh tanpa refactor.
- Perubahan pada kode Phase 1 R1 hanya pada:
  1. `asdim:version-label`: `"ASDIM V1.0-Phase1-R1"` → `"ASDIM V1.0-Phase2"`.
  2. `asdim:print-audit-report`: pesan hasil akhir disesuaikan agar meneruskan ke konfigurasi dimensi Phase 2 bila audit lulus.
  3. `c:ASDIM`: tetap menjalankan seluruh audit wajib Phase 1 R1 terlebih dahulu, lalu bila lulus melanjutkan ke konfigurasi CLI, Style Engine, dan Dimension Generator Phase 2.

### B. Fungsi Baru Phase 2 (26 `defun` Baru pada Section 10–15)
- **ActiveX & RegApp (Section 10):** `asdim:dim-xdata-app`, `asdim:dim-schema-ver`, `asdim:text-style-name`, `asdim:font-file`, `asdim:dim-style-name`, `asdim:layer-name`, `asdim:ensure-activex`, `asdim:ensure-regapp`.
- **Style Engine (Section 11):** `asdim:find-arial-ttf`, `asdim:style-is-annotative`, `asdim:verify-arial-style`, `asdim:ensure-arial-style` (`ASDIM-ARIAL` / `arial.ttf`), `asdim:verify-dim-style`, `asdim:ensure-dim-style` (`ASDIM-STYLE` dengan DXF `340` → `ASDIM-ARIAL`, `DIMSCALE = 1.0`), `asdim:ensure-dim-layer` (`AS-DIM`).
- **XData Identity & Batch ID (Section 12):** `asdim:make-dim-xdata`, `asdim:parse-dim-xdata` (7 field `ASDIM_OBJ`), `asdim:pad4`, `asdim:scan-existing-dim-batches` (Batch ID unik `ASDIM-0001`, `ASDIM-0002`, ... + deteksi dimensi eksisting per grup).
- **Bubble Clearance & Dimension Plan (Section 13):** `asdim:calc-bubble-clearance` (rumus Spek R3 Section 9), `asdim:build-dim-plan` (Horizontal/Vertical Chain & Overall, `d1`, `rowGap`, `d2 = d1 + rowGap`, Top/Bottom/Left/Right, 5-tupel slot unik).
- **Dimension Generator & Safe Cleanup (Section 14):** `asdim:create-single-dim` (`vla-AddDimRotated` + properti ActiveX + XData `ASDIM_OBJ` + verifikasi baca-balik lengkap), `asdim:cleanup-batch-entities` (hapus hanya entitas baru pada batch berjalan bila gagal).
- **CLI Konfigurasi Sementara (Section 15):** `asdim:prompt-pos-real`, `asdim:prompt-yes-no`, `asdim:prompt-cli-config` (konfirmasi satuan wajib termasuk `INSUNITS = 4`, pilihan arah/tipe/posisi, offset, precision, peringatan bubble clearance & dimensi eksisting).

## Fitur yang Sengaja Ditunda ke Phase 3

- Dialog DCL (`ASDIM_V1_0.dcl`).
- Live Preview.
- Penghapusan/penggantian otomatis dimensi lama (*Replace Existing*), deteksi blokir duplikat lintas batch, dan full 6-step atomic transaction/rollback.

## Status Verifikasi

- **Validasi Statis 14 Butir:** LULUS (lihat `phase2_technical_review.md`).
- **Pengujian Runtime AutoCAD 2021:** **NOT RUN** — belum diuji langsung di AutoCAD 2021.
