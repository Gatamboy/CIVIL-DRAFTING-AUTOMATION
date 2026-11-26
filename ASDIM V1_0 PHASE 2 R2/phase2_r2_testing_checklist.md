# Testing Checklist — ASDIM V1.0 Phase 2 Revision 2 (Independent Review Hardening)

**Target Runtime:** AutoCAD 2021  
**File Uji:** `ASDIM V1_0 PHASE 2 R2/ASDIM_V1_0_PHASE2_R2.lsp`  
**Status Pengujian Runtime Saat Ini:** **NOT RUN** (Seluruh 26 skenario wajib dieksekusi langsung oleh pengguna pada AutoCAD 2021.)

## Daftar Skenario Pengujian Runtime AutoCAD 2021

| No | ID | Skenario Uji | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| 1 | R2-01 | Pembuatan dimensi normal | Dimensi H/V Chain & Overall native `DIMENSION` berhasil dibuat, terverifikasi, dan tercatat di `AS-DIM` dengan `ASDIM-STYLE`. | NOT RUN |
| 2 | R2-02 | Kegagalan `vla-AddDimRotated` (simulasi) | Error dilaporkan jelas tanpa substitusi manual; tidak ada entitas yatim; batch dihentikan aman. | NOT RUN |
| 3 | R2-03 | Kegagalan konversi ActiveX object menjadi `ename` (simulasi) | Konfigurasi dihentikan seketika; tidak melanjutkan setter properti maupun XData. | NOT RUN |
| 4 | R2-04 | Penghapusan langsung melalui `vla-Delete` (simulasi R2-03) | `vla-Delete` + `vlax-erased-p` dijalankan dan diagnostik melaporkan hasil penghapusan objek ActiveX yatim. | NOT RUN |
| 5 | R2-05 | Kegagalan penghapusan entity baru (`vla-Delete` / `entdel` gagal, simulasi) | Pesan **KRITIS** tampil jelas dengan instruksi pemeriksaan manual/`UNDO`. | NOT RUN |
| 6 | R2-06 | Cleanup setelah kegagalan pengaturan properti | Karena `ename` sudah masuk `createdEnts` segera via `trackFn`, entitas baru terhapus bersih; dimensi lama utuh. | NOT RUN |
| 7 | R2-07 | Cleanup setelah kegagalan XData | Entitas baru terhapus bersih melalui `asdim:cleanup-batch-entities`; dimensi lama & ASGRID utuh. | NOT RUN |
| 8 | R2-08 | `DIMZIN = 0` (**UNVERIFIED DXF retention**) | `asdim:verify-dim-style` membaca DXF `78 = 0` (integer) dan lulus verifikasi. | NOT RUN |
| 9 | R2-09 | `DIMZIN` bukan `0` (mis. `DIMZIN = 8`) | Verifikasi gagal dengan pesan konflik `DIMZIN (DXF 78) wajib integer 0`; style eksisting tidak diubah. | NOT RUN |
| 10 | R2-10 | `DIMZIN` tidak tersedia pada record `ASDIM-STYLE` | Verifikasi gagal dengan pesan `DIMZIN (DXF 78) <tidak tersedia/tidak valid>`; style eksisting tidak diubah. | NOT RUN |
| 11 | R2-11 | `ASDIM-STYLE` baru (**UNVERIFIED**) | Dibuat dengan DXF `340`, `40 = 1.0`, `277 = 2`, `271 = dimDec`, `144 = 1.0`, `78 = 0` dan lulus readback penuh. | NOT RUN |
| 12 | R2-12 | `ASDIM-STYLE` eksisting yang valid | Lulus seluruh 6 pemeriksaan parameter wajib tanpa modifikasi. | NOT RUN |
| 13 | R2-13 | `ASDIM-STYLE` eksisting dengan `DIMZIN` salah | Proses berhenti dengan pesan konflik jelas; style eksisting tetap utuh. | NOT RUN |
| 14 | R2-14 | XData `ASDIM_OBJ` dengan `SCHEMA_VER = "1.0"` | `asdim:parse-dim-xdata` mengembalikan alist valid; masuk daftar `EXISTING_SLOTS`. | NOT RUN |
| 15 | R2-15 | XData `ASDIM_OBJ` dengan `SCHEMA_VER` berbeda (mis. `"2.0"`) | `asdim:parse-dim-xdata` mengembalikan `nil`; muncul `[PERINGATAN XDATA]` di command line; entitas tidak dihapus/diubah. | NOT RUN |
| 16 | R2-16 | XData `ASDIM_OBJ` dengan `SCHEMA_VER` kosong (`""`) | `asdim:parse-dim-xdata` mengembalikan `nil`; muncul `[PERINGATAN XDATA]`; entitas tidak dihapus/diubah. | NOT RUN |
| 17 | R2-17 | XData `ASDIM_OBJ` tidak valid tidak masuk `SlotKey` | Entitas dengan XData korup / schema tidak didukung tidak memblokir `SlotKey` valid dan tidak disentuh. | NOT RUN |
| 18 | R2-18 | `SlotKey` bentrok lintas batch | Proses dibatalkan sebelum satu pun dimensi baru dibuat; laporan menampilkan slot bentrok; batch lama utuh. | NOT RUN |
| 19 | R2-19 | `SlotKey` tidak bentrok (mis. placement berbeda pada grup sama) | Batch dimensi tambahan berhasil dibuat dengan Batch ID unik baru. | NOT RUN |
| 20 | R2-20 | `PrimaryUnitsPrecision` readback (**UNVERIFIED**) | `vla-get-PrimaryUnitsPrecision` cocok dengan `dimDec` (`0`–`4`); mismatch/error memicu cleanup. | NOT RUN |
| 21 | R2-21 | Unit `mm`, `cm`, dan `m` (`1.0`, `0.1`, `0.001`) | Konfirmasi satuan wajib setiap proses (termasuk `INSUNITS = 4`); format Decimal; `INSUNITS` tidak berubah. | NOT RUN |
| 22 | R2-22 | Pengukuran tetap dalam `DU` | Jarak grid `400 DU` pada gambar `cm` tetap terbaca `400` (bukan `40`) tanpa suffix satuan. | NOT RUN |
| 23 | R2-23 | Global `DIMSTYLE` tidak berubah | `(getvar "DIMSTYLE")` identik sebelum dan sesudah `ASDIM`. | NOT RUN |
| 24 | R2-24 | Global `TEXTSTYLE` tidak berubah | `(getvar "TEXTSTYLE")` identik sebelum dan sesudah `ASDIM`. | NOT RUN |
| 25 | R2-25 | ASGRID tidak berubah | `ASGRIDCHECK` lulus identik sebelum dan sesudah `ASDIM`; metadata & entitas ASGRID utuh. | NOT RUN |
| 26 | R2-26 | Seluruh audit Phase 1 R1 tetap berfungsi | Audit metadata, `SCHEMA_VER` XData vs. metadata, `AXIS_DIR_H="X"`, `AXIS_DIR_V="Y"`, Model Space filter, dan audit geometri tetap berjalan penuh. | NOT RUN |

## Catatan Penguji

- **Tanggal Uji:** ___________________________
- **Versi AutoCAD:** AutoCAD 2021
- **Hasil Akhir:** `[ ] LULUS SEMUA` / `[ ] SEBAGIAN` / `[ ] GAGAL (lampirkan output command line)`
