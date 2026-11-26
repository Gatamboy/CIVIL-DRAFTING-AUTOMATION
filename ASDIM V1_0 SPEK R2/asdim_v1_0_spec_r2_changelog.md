# Changelog Revisi — Spesifikasi Teknis ASDIM V1.0 (R1 → R2)

**Baseline Sebelumnya:** `ASDIM V1_0 SPEK/asdim_v1_0_technical_specification_R1.md` *(dipertahankan utuh tanpa perubahan)*

**Dokumen Baru:** `ASDIM V1_0 SPEK R2/asdim_v1_0_technical_specification_r2.md`

**Referensi Sumber ASGRID:** `ASGRID V2.2.1 R3/ASGRID_V2_2_1_R3.lsp` (commit referensi `3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15`, belum diverifikasi terhadap remote GitHub karena lingkungan offline)

**Tanggal:** 26 November 2026

## Ringkasan Perubahan (R1 → R2)

| No | Area Perbaikan | Section Terdampak | Penjelasan Perubahan | 
| ----- | ----- | ----- | ----- | 
| **1** | **Drawing Unit Confirmation** | Section 2, 7, 11, 14, 17 (`T-20`), 19, 20 | Memperketat aturan konfirmasi satuan: `INSUNITS` hanya sebagai informasi dan rekomendasi nilai awal (bukan bukti satuan aktual gambar) dan tidak pernah diubah. Pengguna **wajib mengonfirmasi satuan aktual gambar pada setiap eksekusi, termasuk saat `INSUNITS = 4`**. Proses generasi dimensi diblokir sampai konfirmasi diberikan, dan berhenti bersih tanpa membuat dimensi jika satuan tidak dapat dipastikan. Rumus `size_DU = size_print_mm × SCALE_DENOM × unitFactor` (`mm = 1.0`, `cm = 0.1`, `m = 0.001`) dipertahankan konsisten di seluruh dokumen. | 
| **2** | **Duplicate Slot Identity** | Section 2, 7, 12, 13, 14, 17 (`T-16`), 19, 20 | Menetapkan identitas slot dimensi kanonik 5-tupel `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)` secara eksplisit di XData, discovery, validasi duplikat, transaksi, dan test matrix. `CHAIN` menggunakan `SlotIdx = 1..(N-1)` sesuai interval dan `OVERALL` menggunakan `SlotIdx = 0`. Dimensi pada interval berbeda tidak dianggap duplikat, sedangkan tabrakan 5-tupel yang sama ditolak pada mode `Add New Set`. `Replace Existing` tetap dibatasi hanya pada dimensi milik `GROUP_ID` terpilih. | 
| **3** | **Klarifikasi `UNDO` & Resource Lifecycle** | Section 13, 17 (`T-17`), 18, 20 | Menghapus jaminan bahwa satu kali `UNDO` pasti menghapus seluruh resource baru (`STYLE`/`DIMSTYLE`/`LAYER`/`APPID`) sebelum dibuktikan pada pengujian AutoCAD 2021 (ditandai **UNVERIFIED** pada `T-17` dan Section 18). Memisahkan secara tegas **programmatic rollback** (penghapusan `txCreatedEnts` & undelete `txDeletedOldEnts` terverifikasi) dari pemulihan manual via `UNDO`, serta menegaskan bahwa resource baru yang tertinggal bersifat *inert* dan tidak memengaruhi ASGRID maupun objek gambar lainnya. | 

## Bagian yang Tidak Diubah

* Dokumen R1 (`asdim_v1_0_technical_specification_R1.md` & `asdim_v1_0_spec_R1_changelog.md`) tidak diubah maupun dihapus.

* Tidak ada file `.lsp` maupun `.dcl` yang dibuat atau diubah (sumber `ASGRID_V2_2_1_R3.lsp` dan `ASGRID_V2_2_1_R3.dcl` utuh).

* Seluruh temuan audit ASGRID R3 (Section 4), arsitektur metadata (Section 5), penyaringan Model Space (Section 6), perhitungan clearance bubble (Section 9), strategi `ASDIM-ARIAL`/`ASDIM-STYLE` (Section 10), dan penempatan uji UCS di Phase 2 (Section 6, 17, 19) dipertahankan utuh.

* Tidak ada pengujian runtime maupun operasi `git commit`/`push` yang dilakukan.