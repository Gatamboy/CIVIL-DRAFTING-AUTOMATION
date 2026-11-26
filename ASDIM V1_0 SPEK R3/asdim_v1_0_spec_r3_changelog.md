# Changelog Revisi — Spesifikasi Teknis ASDIM V1.0 (R2 → R3)

**Baseline Sebelumnya:** `ASDIM V1_0 SPEK R2/asdim_v1_0_technical_specification_r2.md` (commit referensi `c88ecff9ac28d9e11edad31036e8629c48d81c8e`, belum diverifikasi terhadap remote GitHub karena lingkungan offline; dokumen R1 dan R2 tetap dipertahankan utuh)  
**Dokumen Baru:** `ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md`  
**Referensi Sumber ASGRID:** `ASGRID V2.2.1 R3/ASGRID_V2_2_1_R3.lsp` (commit referensi `3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15`, baseline lokal diaudit langsung)  
**Tanggal:** 26 November 2026

## Ringkasan 4 Klarifikasi Wajib (R2 → R3)

| No | Area Klarifikasi | Section Terdampak | Penjelasan Perubahan |
| :--- | :--- | :--- | :--- |
| **1** | **Batasan Kompatibilitas ASGRID** | Section 1, 15, 18, 19, 20 | Membatasi klaim kompatibilitas terverifikasi hanya pada **ASGRID V2.2.1 R3** (satu-satunya versi yang diaudit pada Section 4). Versi lama (`V2.2–V2.2.1 R2` dan `V2.1–V2.1.2`) dicatat sebagai target kompatibilitas berikutnya dengan status **UNVERIFIED** tanpa mengklaim kompatibilitas penuh sebelum audit kode sumber masing-masing versi dilakukan. |
| **2** | **Penyelarasan Kontrol Offset DCL** | Section 2, 7, 9, 11, 17 (`T-07`, `T-08`), 19, 20 | Menyelaraskan nama kontrol DCL menjadi `ed_chain_off` (offset dimensi Chain, sekaligus `d1` jika hanya Overall dipilih) dan `ed_row_gap` (jarak antarbaris Chain dan Overall, menggantikan `ed_overall_off`). Mempertahankan rumus `d1 = chainOffsetPrint_mm * SCALE_DENOM * unitFactor`, `rowGap = rowSpacingPrint_mm * SCALE_DENOM * unitFactor`, dan `d2 = d1 + rowGap` secara konsisten di Section 9 dan 11. |
| **3** | **Aturan Pengukuran Dimensi & Konversi Satuan** | Section 2, 3, 7, 8, 13, 17 (`T-20`), 19, 20 | Menambahkan aturan eksplisit bahwa nilai pengukuran dimensi mengikuti jarak aktual antargrid dalam `DU`; `unitFactor` **hanya** mengonversi ukuran cetak (tinggi teks, ukuran panah, `ed_chain_off`, `ed_row_gap`) menjadi `DU` dan tidak pernah mengalikan/membagi nilai pengukuran jarak grid (`LinearScaleFactor = 1.0`, tanpa suffix satuan tambahan). Menambahkan contoh eksplisit: jarak `400 DU` pada gambar yang dikonfirmasi `cm` tetap terbaca `400`, bukan `40`. |
| **4** | **Klarifikasi Kegagalan Provisioning Resource di Tengah STEP A** | Section 13, 17 (`T-17`), 20 | Menjelaskan secara tegas bahwa jika provisioning resource gagal di tengah STEP A, sebagian resource baru yang sempat berhasil dibuat dapat tertinggal dalam gambar sebagai *inert shared definition* tanpa memengaruhi objek gambar, ASGRID, atau pengaturan global; resource pra-eksisting tidak pernah diubah/dihapus; dan tidak ada janji bahwa seluruh resource baru pasti terhapus oleh rollback programatik maupun satu kali `UNDO`. |

## Bagian yang Dipertahankan Utuh

- Seluruh 23 test case (`T-01` s.d. `T-23`) dipertahankan lengkap dengan status **Not Run** (belum ada implementasi maupun pengujian runtime AutoCAD 2021).
- Dokumen R1 (`ASDIM V1_0 SPEK/`) dan R2 (`ASDIM V1_0 SPEK R2/`) dipertahankan utuh sebagai riwayat revisi.
- Tidak ada file `.lsp` maupun `.dcl` yang dibuat atau dimodifikasi; kode ASGRID V2.2.1 R3 tetap utuh.
- Tidak ada `git commit` maupun `git push` yang dijalankan.
