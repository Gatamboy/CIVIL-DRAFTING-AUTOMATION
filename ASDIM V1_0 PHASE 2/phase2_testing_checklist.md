# Testing Checklist — ASDIM V1.0 Phase 2 (Style Engine & Dimension Generator)

**Target Runtime:** AutoCAD 2021  
**File Uji:** `ASDIM V1_0 PHASE 2/ASDIM_V1_0_PHASE2.lsp`  
**Status Pengujian Runtime Saat Ini:** **NOT RUN** (Seluruh skenario di bawah ini wajib dieksekusi langsung oleh pengguna pada AutoCAD 2021.)

## Bagian A — Style Engine (`P2-S01` s.d. `P2-S10`)

| ID | Skenario Uji | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- |
| P2-S01 | Font Arial (`arial.ttf`) tersedia | `asdim:find-arial-ttf` menemukan path valid dan proses berlanjut. | NOT RUN |
| P2-S02 | Font Arial tidak tersedia (simulasi) | Proses berhenti dengan pesan error jelas; tidak ada substitusi font diam-diam. | NOT RUN |
| P2-S03 | `ASDIM-ARIAL` belum ada | Dibuat otomatis (`arial.ttf`, Fixed Height `0`, Width `1.0`, Oblique `0`, non-annotative) tanpa mengubah `Standard`, `ASGRID-ARIAL`, atau `TEXTSTYLE`. | NOT RUN |
| P2-S04 | `ASDIM-ARIAL` sudah ada dan benar | Lolos verifikasi dan digunakan tanpa modifikasi. | NOT RUN |
| P2-S05 | `ASDIM-ARIAL` sudah ada tetapi salah konfigurasi (font bukan Arial / Fixed Height != 0 / Annotative) | Proses berhenti dengan pesan konflik; style eksisting tidak ditimpa. | NOT RUN |
| P2-S06 | `ASDIM-STYLE` belum ada (**UNVERIFIED API**) | Dibuat dengan DXF `340` → `ASDIM-ARIAL` dan `DIMSCALE = 1.0` tanpa mengubah `DIMSTYLE` global/aktif. | NOT RUN |
| P2-S07 | `ASDIM-STYLE` sudah ada dan benar | Lolos verifikasi DXF `340` dan `DIMSCALE = 1.0`. | NOT RUN |
| P2-S08 | `ASDIM-STYLE` sudah ada tetapi merujuk Text Style lain / `DIMSCALE != 1.0` | Proses berhenti dengan pesan konflik; style eksisting tidak ditimpa. | NOT RUN |
| P2-S09 | Layer `AS-DIM` belum ada | Dibuat otomatis (`CONTINUOUS`, warna 3) tanpa mengubah `CLAYER`. | NOT RUN |
| P2-S10 | Layer `AS-DIM` sudah ada (normal vs. Frozen/Locked) | Normal: dipakai langsung; Frozen/Locked: ditolak dengan pesan jelas. | NOT RUN |

## Bagian B — Dimension Generator (`P2-D01` s.d. `P2-D21`)

| ID | Skenario Uji | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- |
| P2-D01 | Horizontal Chain Dimension (**UNVERIFIED ActiveX props**) | Native `DIMENSION` sejajar X mengukur tiap interval `DIST_V`; `StyleName`, `TextHeight`, `ArrowheadSize`, `PrimaryUnitsPrecision` sesuai. | NOT RUN |
| P2-D02 | Horizontal Overall Dimension | 1 dimensi total sepanjang X (`SlotIdx = 0`) mengukur total `DIST_V`. | NOT RUN |
| P2-D03 | Vertical Chain Dimension | Native `DIMENSION` sejajar Y mengukur tiap interval `DIST_H`. | NOT RUN |
| P2-D04 | Vertical Overall Dimension | 1 dimensi total sepanjang Y (`SlotIdx = 0`) mengukur total `DIST_H`. | NOT RUN |
| P2-D05 | Placement Horizontal Top | Dimensi ditempatkan di atas grid (`yMax + ext + d1/d2`). | NOT RUN |
| P2-D06 | Placement Horizontal Bottom | Dimensi ditempatkan di bawah grid (`yMin - ext - d1/d2`). | NOT RUN |
| P2-D07 | Placement Vertical Left | Dimensi ditempatkan di kiri grid (`xMin - ext - d1/d2`). | NOT RUN |
| P2-D08 | Placement Vertical Right | Dimensi ditempatkan di kanan grid (`xMax + ext + d1/d2`). | NOT RUN |
| P2-D09 | Nonuniform grid spacing (`DIST_V = 4000,5000,3000`; `DIST_H = 3000,4500`) | Chain tepat `4000, 5000, 3000` (H) & `3000, 4500` (V); Overall `12000` (H) & `7500` (V). | NOT RUN |
| P2-D10 | Grid dengan satu interval (2×2) | Chain = 1 entitas & Overall = 1 entitas per arah, nilai identik tanpa error. | NOT RUN |
| P2-D11 | Grid dengan satu axis (`NUM_H = 1` atau `NUM_V = 1`) | Arah yang hanya punya 1 sumbu otomatis dilewati dengan `[INFO]`; arah lain tetap dibuat. | NOT RUN |
| P2-D12 | Elevation nonzero (`Z = 3500.0`) | Seluruh `ExtPt1`, `ExtPt2`, `DimLineLocation` berada pada elevasi `Z = 3500.0`. | NOT RUN |
| P2-D13 | Offset & Row Spacing (`d2 = d1 + rowGap`) + Bubble Clearance Warning | Baris Overall terpisah `rowGap` dari Chain; peringatan muncul bila `d1 <= d_clear`; Overall-only memakai `d1`. | NOT RUN |
| P2-D14 | Precision (`0`, `1`, `2`, `3`, `4`) | Jumlah desimal dimensi sesuai pilihan pengguna. | NOT RUN |
| P2-D15 | Unit `MM` (`unitFactor = 1.0`, termasuk `INSUNITS = 4`) | Konfirmasi satuan tetap wajib; ukuran cetak × `SCALE_DENOM` × `1.0`; `INSUNITS` tidak berubah. | NOT RUN |
| P2-D16 | Unit `CM` (`unitFactor = 0.1`) | Ukuran cetak dikonversi × `0.1`, sedangkan jarak grid `400 DU` tetap terbaca `400` (bukan `40`). | NOT RUN |
| P2-D17 | Unit `M` (`unitFactor = 0.001`) | Ukuran cetak dikonversi × `0.001`, sedangkan jarak grid `DU` tetap terbaca apa adanya tanpa suffix. | NOT RUN |
| P2-D18 | Rotated / Shifted UCS (**UNVERIFIED**) | Verifikasi apakah `vla-AddDimRotated` sejajar sumbu WCS grid tanpa mengubah UCS pengguna. | NOT RUN |
| P2-D19 | Dimensi pada Model Space | Seluruh `DIMENSION` berada di Model Space (`410 = "Model"`, `67 = 0/nil`). | NOT RUN |
| P2-D20 | XData Identity (`ASDIM_OBJ`) | Baca-balik 7 field (`SourceGroupID`, `DimBatchID`, `Orientation`, `DimType`, `SlotIdx`, `Placement`, `SchemaVer`) valid & terpisah dari `ASGRID_OBJ`. | NOT RUN |
| P2-D21 | Batch ID Uniqueness & Re-run Warning | Eksekusi ulang pada grup sama menampilkan peringatan (tidak menghapus dimensi lama) dan menghasilkan `ASDIM-0002` unik. | NOT RUN |

## Bagian C — Failure Handling & Safe Cleanup (`P2-F01` s.d. `P2-F09`)

| ID | Skenario Uji | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- |
| P2-F01 | Metadata tidak valid | Audit Phase 1 gagal; proses berhenti tanpa membuat dimensi maupun resource. | NOT RUN |
| P2-F02 | Geometri grid berubah (garis dipindah/dihapus) | Audit geometri gagal; proses berhenti tanpa membuat dimensi. | NOT RUN |
| P2-F03 | Font tidak ditemukan | Berhenti sebelum pembuatan dimensi dengan pesan error jelas. | NOT RUN |
| P2-F04 | Style (`ASDIM-ARIAL`/`ASDIM-STYLE`) gagal diverifikasi | Berhenti sebelum pembuatan dimensi; style eksisting utuh. | NOT RUN |
| P2-F05 | ActiveX gagal membuat dimensi (simulasi) | Error dilaporkan tanpa substitusi manual; batch dihentikan aman. | NOT RUN |
| P2-F06 | XData gagal dibuat (simulasi) | Dimensi gagal diverifikasi; cleanup menghapus entitas baru batch berjalan. | NOT RUN |
| P2-F07 | Dimensi gagal diverifikasi pasca-buat (simulasi) | Cleanup menghapus entitas baru batch berjalan; dimensi lama & ASGRID utuh. | NOT RUN |
| P2-F08 | Pembuatan batch gagal / `Esc` di tengah proses | `asdim:cleanup-batch-entities` menghapus hanya dimensi baru batch berjalan; resource baru inert tetap aman; dimensi lama utuh. | NOT RUN |
| P2-F09 | Cleanup entity baru gagal (simulasi) | Program melaporkan jumlah gagal hapus dan peringatan pemeriksaan manual secara jelas. | NOT RUN |

## Catatan Penguji

- **Tanggal Uji:** ___________________________
- **Versi AutoCAD:** AutoCAD 2021
- **Hasil Akhir:** `[ ] LULUS SEMUA` / `[ ] SEBAGIAN` / `[ ] GAGAL (lampirkan output command line)`
