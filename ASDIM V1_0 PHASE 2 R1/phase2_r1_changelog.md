# Changelog — ASDIM V1.0 Phase 2 Revision 1 (Audit Hardening)

**Baseline Sebelumnya:** `ASDIM V1_0 PHASE 2/ASDIM_V1_0_PHASE2.lsp` *(dipertahankan utuh tanpa perubahan)*  
**Baseline Audit:** `ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp` *(utuh)*  
**Acuan Spesifikasi:** `ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md`  
**Acuan ASGRID:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` *(utuh)*  
**Tanggal:** 26 November 2026

## Ringkasan Empat Perbaikan Audit (Phase 2 → Phase 2 R1)

| Fix | Temuan Audit Sebelumnya | Perbaikan pada Phase 2 R1 | Fungsi yang Diubah / Ditambah |
| :--- | :--- | :--- | :--- |
| **FIX 1** | Duplikasi `SlotKey` hanya dicek di dalam rencana batch baru, belum dibandingkan terhadap dimensi `ASDIM_OBJ` dari batch sebelumnya. | Memindai seluruh `DIMENSION` Model Space ber-XData `ASDIM_OBJ` valid milik `SourceGroupID` terpilih, membangun daftar 5-tupel `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)`, lalu memblokir proses **sebelum** membuat dimensi bila ada benturan (dengan laporan slot bentrok). Placement berbeda tetap diizinkan; Group ID lain & dimensi non-ASDIM diabaikan; dimensi lama tidak dihapus/diubah. | `asdim:make-slot-key` *(baru)*, `asdim:scan-existing-dim-batches` *(diperluas)*, `asdim:check-slot-collisions` *(baru)*, `c:ASDIM` *(gerbang pra-generasi)* |
| **FIX 2** | `ename` entitas baru baru dimasukkan ke `createdEnts` setelah `asdim:create-single-dim` selesai, berisiko terlewat dari cleanup jika gagal di tengah fungsi. | Menambahkan callback lokal `fn-track-created-ent` (tanpa variabel global) yang langsung mendaftarkan `ename` segera setelah `vla-AddDimRotated` & `vlax-vla-object->ename` berhasil, **sebelum** pengaturan `Layer`, `StyleName`, `TextHeight`, `ArrowheadSize`, `PrimaryUnitsPrecision`, XData, maupun readback. | `asdim:create-single-dim`, `c:ASDIM` (`fn-track-created-ent` lokal) |
| **FIX 3** | `PrimaryUnitsPrecision` sudah di-set via ActiveX tetapi belum diverifikasi readback. | Menambahkan readback eksplisit melalui `(vl-catch-all-apply 'vla-get-PrimaryUnitsPrecision (list dimObj))`; error getter atau ketidaksamaan nilai terhadap `dimDec` diperlakukan sebagai kegagalan pembuatan sehingga entitas langsung masuk cleanup. | `asdim:create-single-dim` |
| **FIX 4** | Validasi `ASDIM-STYLE` belum memeriksa format linear (`DIMLUNIT`), presisi (`DIMDEC`), faktor pengukuran (`DIMLFAC`), dan zero suppression (`DIMZIN`). | Memperkuat `asdim:verify-dim-style` & `asdim:ensure-dim-style` untuk memverifikasi secara eksplisit: nama `ASDIM-STYLE`, DXF `340` → `ASDIM-ARIAL`, DXF `40` (`DIMSCALE = 1.0`), DXF `277` (`DIMLUNIT = 2` / Decimal untuk `mm`, `cm`, `m`), DXF `271` (`DIMDEC = dimDec`), DXF `144` (`DIMLFAC = 1.0`), serta menulis DXF `78` (`DIMZIN = 0`) pada pembuatan baru tanpa mengubah style eksisting maupun `DIMSTYLE`/`TEXTSTYLE` global. | `asdim:verify-dim-style`, `asdim:ensure-dim-style`, `c:ASDIM` |

## Perubahan Perilaku

- Pada eksekusi ulang terhadap `GROUP_ID` yang sama: apabila pengguna memilih orientasi/tipe/placement yang menghasilkan `SlotKey` 5-tupel yang sudah ada pada batch sebelumnya, program kini **membatalkan proses sebelum membuat satu pun dimensi baru** dan menampilkan daftar `SlotKey` yang bentrok (pada Phase 2 awal, batch tambahan masih dibuat meskipun slotnya bertabrakan).
- Jika `ASDIM-STYLE` sudah ada dengan `DIMDEC` (DXF `271`) berbeda dari `precision` yang diminta pengguna, program kini **berhenti dengan pesan konflik jelas** alih-alih melanjutkan atau menimpa style eksisting.

## Bagian yang Dipertahankan Utuh

- Seluruh 31/31 fungsi audit Phase 1 R1, perhitungan koordinat WCS, 4 placement, bubble clearance, konfirmasi satuan wajib (`mm = 1.0`, `cm = 0.1`, `m = 0.001`), pengukuran tetap dalam `DU`, `ASDIM-ARIAL` (`arial.ttf`), Layer `AS-DIM`, XData `ASDIM_OBJ`, Batch ID unik, dan perintah `ASDIM` dipertahankan utuh.
- Tidak ada DCL, tidak ada Live Preview, tidak ada fitur Phase 3 (Replace otomatis), dan tidak ada perubahan pada ASGRID maupun Phase 1 R1.
