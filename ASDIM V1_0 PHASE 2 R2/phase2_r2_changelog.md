# Changelog — ASDIM V1.0 Phase 2 Revision 2 (Independent Review Hardening)

**Baseline Sebelumnya:** `ASDIM V1_0 PHASE 2 R1/ASDIM_V1_0_PHASE2_R1.lsp` *(dipertahankan utuh tanpa perubahan)*  
**Baseline Audit Phase 1 R1:** `ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp` *(utuh)*  
**Acuan Spesifikasi:** `ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md`  
**Acuan ASGRID:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` *(utuh)*  
**Tanggal:** 26 November 2026

## Ringkasan Empat Perbaikan (Phase 2 R1 → Phase 2 R2)

| No | Area Perbaikan | Fungsi yang Diubah | Penjelasan Perubahan |
| :--- | :--- | :--- | :--- |
| **1** | **Hardening Cleanup ActiveX (`vla-Delete`)** | `asdim:create-single-dim` | Jika `vla-AddDimRotated` berhasil membuat `dimObj` tetapi konversi `vlax-vla-object->ename` gagal, program langsung menghentikan konfigurasi entitas, mencoba menghapus `dimObj` melalui `(vl-catch-all-apply 'vla-Delete (list dimObj))`, memeriksa status via `vlax-erased-p`, dan mengeluarkan pesan diagnostik eksplisit (termasuk peringatan **KRITIS** dengan instruksi pemeriksaan manual/`UNDO` bila penghapusan gagal atau tidak dapat dipastikan). |
| **2** | **Penghapusan `defun` Callback di Dalam `c:ASDIM`** | `c:ASDIM` | Menghapus definisi `(defun fn-track-created-ent ...)` dan menggantinya dengan lambda anonim lokal `(setq trackFn (function (lambda (newEname) ...)))` sehingga tidak ada definisi fungsi baru di namespace global AutoLISP dan tidak ada variabel global baru, sambil tetap mencatat `ename` segera ke `createdEnts` lokal. |
| **3** | **Verifikasi Wajib DXF `78` (`DIMZIN = 0`)** | `asdim:verify-dim-style` | Menambahkan pemeriksaan eksplisit DXF `78` pada record `ASDIM-STYLE` (wajib ada dan bernilai integer `0`). Jika tidak tersedia, bukan integer, atau berbeda dari `0`, verifikasi gagal tanpa memodifikasi style eksisting. Laporan verifikasi style kini mencakup 6 parameter: DXF `340`, `40`, `277`, `271`, `144`, dan `78`. |
| **4** | **Validasi Ketat `SCHEMA_VER = "1.0"` pada `ASDIM_OBJ`** | `asdim:parse-dim-xdata`, `asdim:scan-existing-dim-batches`, `c:ASDIM` | `asdim:parse-dim-xdata` kini mewajibkan `SCHEMA_VER` bertipe string dan tepat sama dengan `"1.0"` (`asdim:dim-schema-ver`); jika kosong/berbeda/tidak valid, mengembalikan `nil` sehingga entitas tidak masuk ke `EXISTING_SLOTS` dan tidak disentuh. `asdim:scan-existing-dim-batches` menghitung `INVALID_XDATA_CNT` dan `c:ASDIM` mencetak peringatan diagnostik non-destruktif bila ditemukan XData `ASDIM_OBJ` dengan schema tidak didukung. |

## Perilaku Baru pada Kondisi Error

- Kegagalan `vlax-vla-object->ename` tidak lagi meninggalkan objek ActiveX yatim tanpa upaya penghapusan langsung (`vla-Delete` + cek `vlax-erased-p`).
- `ASDIM-STYLE` eksisting atau baru tanpa DXF `78 = 0` kini ditolak secara eksplisit saat verifikasi style.
- Dimensi `ASDIM_OBJ` dengan `SCHEMA_VER` selain `"1.0"` diabaikan dari `SlotKey`, tidak dihapus/diubah, dan memunculkan peringatan diagnostik di command line.

## Fitur yang Tetap Dipertahankan

Seluruh fitur Phase 2 R1 (audit Phase 1 R1, koordinat WCS, 4 placement, bubble clearance, konfirmasi satuan wajib `mm`/`cm`/`m`, pengukuran tetap dalam `DU`, `ASDIM-ARIAL`, Layer `AS-DIM`, 7-field XData `ASDIM_OBJ`, Batch ID unik, validasi `SlotKey` lintas batch, readback `PrimaryUnitsPrecision`, dan cleanup hanya entitas baru) dipertahankan utuh. Tidak ada DCL, Live Preview, fitur Phase 3, maupun perubahan pada ASGRID/Phase 1 R1.
