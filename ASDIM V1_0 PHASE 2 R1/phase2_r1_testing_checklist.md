# Testing Checklist — ASDIM V1.0 Phase 2 Revision 1 (Audit Hardening)

**Target Runtime:** AutoCAD 2021  
**File Uji:** `ASDIM V1_0 PHASE 2 R1/ASDIM_V1_0_PHASE2_R1.lsp`  
**Status Pengujian Runtime Saat Ini:** **NOT RUN** (Seluruh 24 skenario di bawah ini wajib dieksekusi langsung oleh pengguna pada AutoCAD 2021.)

## Daftar Skenario Pengujian Runtime AutoCAD 2021

| No | ID | Skenario Uji | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| 1 | R1-01 | SlotKey baru tanpa benturan | Dimensi baru dibuat normal dengan 5-tupel `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)` unik. | NOT RUN |
| 2 | R1-02 | SlotKey bentrok dengan batch lama | Proses dibatalkan sebelum satu pun dimensi baru dibuat; laporan menampilkan seluruh SlotKey yang bentrok. | NOT RUN |
| 3 | R1-03 | SlotKey dari Group ID lain tidak memblokir | Dimensi `ASG-0001` dengan posisi `TOP` tidak memblokir pembuatan dimensi `TOP` pada `ASG-0002`. | NOT RUN |
| 4 | R1-04 | Dimensi lama tidak terhapus saat benturan | Jumlah dan properti dimensi `ASDIM_OBJ` dari batch sebelumnya tetap 100% utuh setelah benturan dibatalkan. | NOT RUN |
| 5 | R1-05 | Error setelah `vla-AddDimRotated` berhasil (simulasi) | `ename` sudah tercatat segera via `fn-track-created-ent` sebelum properti lanjutan dijalankan. | NOT RUN |
| 6 | R1-06 | Cleanup entity baru setelah kegagalan | Seluruh entitas baru pada batch gagal terhapus bersih; dimensi lama & ASGRID tidak tersentuh. | NOT RUN |
| 7 | R1-07 | `PrimaryUnitsPrecision` berhasil dibaca kembali (**UNVERIFIED**) | `vla-get-PrimaryUnitsPrecision` mengembalikan integer yang tepat sama dengan `dimDec` (`0`–`4`). | NOT RUN |
| 8 | R1-08 | `PrimaryUnitsPrecision` mismatch / getter error (simulasi) | Diperlakukan sebagai kegagalan verifikasi; entitas yang gagal masuk ke cleanup. | NOT RUN |
| 9 | R1-09 | `ASDIM-STYLE` baru berhasil dibuat dan diverifikasi (**UNVERIFIED**) | DXF `340` → `ASDIM-ARIAL`, `DIMSCALE = 1.0`, `DIMLUNIT = 2` (Decimal), `DIMDEC = dimDec`, `DIMLFAC = 1.0` lulus readback. | NOT RUN |
| 10 | R1-10 | `ASDIM-STYLE` sudah ada dengan konfigurasi benar | Lolos seluruh pemeriksaan wajib dan digunakan tanpa modifikasi. | NOT RUN |
| 11 | R1-11 | `ASDIM-STYLE` sudah ada dengan konfigurasi salah (font / `DIMLUNIT` / `DIMDEC` / `DIMSCALE` / `DIMLFAC`) | Proses berhenti dengan pesan error jelas; style eksisting tidak diubah secara otomatis. | NOT RUN |
| 12 | R1-12 | `ASDIM-ARIAL` tetap menggunakan Arial | Font `arial.ttf`, Fixed Height `0`, Width `1.0`, Oblique `0`, non-annotative; tidak mengubah `Standard`/`ASGRID-ARIAL`. | NOT RUN |
| 13 | R1-13 | Layer `AS-DIM` | Seluruh dimensi berada pada layer `AS-DIM`; layer Frozen/Locked ditolak; `CLAYER` global tidak berubah. | NOT RUN |
| 14 | R1-14 | Unit `mm` (`unitFactor = 1.0`, termasuk `INSUNITS = 4`) | Konfirmasi satuan tetap wajib; format Decimal; ukuran cetak × `SCALE_DENOM` × `1.0`; `INSUNITS` tidak berubah. | NOT RUN |
| 15 | R1-15 | Unit `cm` (`unitFactor = 0.1`) | Format Decimal; ukuran cetak × `SCALE_DENOM` × `0.1`; `INSUNITS` tidak berubah. | NOT RUN |
| 16 | R1-16 | Unit `m` (`unitFactor = 0.001`) | Format Decimal; ukuran cetak × `SCALE_DENOM` × `0.001`; `INSUNITS` tidak berubah. | NOT RUN |
| 17 | R1-17 | Pengukuran aktual tetap dalam Drawing Units (`DU`) | Jarak grid `400 DU` pada gambar yang dikonfirmasi `cm` tetap terbaca `400` (bukan `40`) tanpa suffix satuan tambahan. | NOT RUN |
| 18 | R1-18 | Global `DIMSTYLE` tidak berubah | Nilai `(getvar "DIMSTYLE")` sebelum dan sesudah `ASDIM` identik. | NOT RUN |
| 19 | R1-19 | Global `TEXTSTYLE` tidak berubah | Nilai `(getvar "TEXTSTYLE")` sebelum dan sesudah `ASDIM` identik. | NOT RUN |
| 20 | R1-20 | ASGRID tidak berubah | `ASGRIDCHECK` sebelum & sesudah `ASDIM` lulus identik; metadata `ASGRID_GROUPS` & XData `ASGRID_OBJ` utuh. | NOT RUN |
| 21 | R1-21 | Regenerasi dimensi pada Group ID sama dengan slot berbeda | Mis. batch 1 `TOP` + `LEFT`, batch 2 `BOTTOM` + `RIGHT`: diizinkan karena `Placement` berbeda dalam 5-tupel SlotKey. | NOT RUN |
| 22 | R1-22 | Pengujian koordinat WCS (termasuk elevasi `Z != 0`) | `ExtPt1`, `ExtPt2`, `DimLinePoint` sejajar WCS pada elevasi `Z0` sesuai `cumX`/`DIST_V` & `cumY`/`DIST_H`. | NOT RUN |
| 23 | R1-23 | Pengujian rotated UCS (**UNVERIFIED**) | Verifikasi orientasi `vla-AddDimRotated` di bawah UCS terputar tanpa mengubah UCS pengguna. | NOT RUN |
| 24 | R1-24 | Seluruh fitur Phase 1 R1 tetap berjalan | Audit metadata, `SCHEMA_VER` XData vs. metadata, `AXIS_DIR_H="X"`, `AXIS_DIR_V="Y"`, Model Space filter, dan audit geometri tetap bekerja penuh. | NOT RUN |

## Catatan Penguji

- **Tanggal Uji:** ___________________________
- **Versi AutoCAD:** AutoCAD 2021
- **Hasil Akhir:** `[ ] LULUS SEMUA` / `[ ] SEBAGIAN` / `[ ] GAGAL (lampirkan output command line)`
