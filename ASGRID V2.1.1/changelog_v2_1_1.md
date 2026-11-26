# CHANGELOG — ASGRID V2.1.1 (Stability & Metadata Hardening)

- **Tanggal Rilis:** 2026-11-26
- **Baseline:** ASGRID V2.1 (`ASGRID_V2_1.lsp` & `ASGRID_V2_1.dcl` — dipertahankan utuh tanpa ditimpa)
- **Target Lingkungan:** AutoCAD 2021 (AutoLISP standar + DCL, Model Space, WCS, satuan milimeter)
- **Status Pengujian:** Verifikasi statis selesai (0 error sintaks/tile/namespace); belum dijalankan langsung di instalasi AutoCAD 2021 lokal.

## Ringkasan Perubahan (V2.1 → V2.1.1)

### 1. Metadata Verification sebagai Hard Gate (Prioritas A)
- **Penulisan pra-geometri wajib:** `fn-execute-grid-creation` menulis XRecord grup ke Named Object Dictionary `ASGRID_GROUPS` **sebelum** `fn-geometry-engine` atau `fn-annotation-engine` berjalan.
- **Pembacaan balik & Deep Compare:** Setelah penulisan XRecord, sistem wajib membaca ulang lewat `asgrid:meta-read-group`, memvalidasi integritas dengan `asgrid:meta-validate-spec`, lalu membandingkan setiap field terhadap spesifikasi asal menggunakan `asgrid:meta-compare-specs` (toleransi floating-point `1e-6`).
- **Pembatalan otomatis (Hard Gate):** Jika penulisan gagal, pembacaan balik gagal, integritas gagal, atau terdapat satu pun mismatch field, transaksi langsung dibatalkan (*abort*) dan di-rollback sebelum satu pun garis grid dibuat.
- **Anti-duplikasi Group ID:** `fn-meta-save-group` memeriksa baik `dictsearch` di NOD maupun `asgrid:meta-list-all-ids` (NOD + XData) sehingga Group ID duplikat ditolak.

### 2. Transaction Safety & Isolated Rollback (Prioritas B)
- **Pelacakan entitas transaksi via `entmakex`:** `fn-draw-line`, `fn-draw-circle`, dan `fn-draw-text-mc` ditingkatkan dari `entmake` ke `entmakex` sehingga setiap `ename` yang dibuat dalam transaksi dicatat di daftar lokal `txCreatedEnts`.
- **Rollback terisolasi (`fn-rollback-transaction`):** Saat terjadi kegagalan verifikasi, kegagalan pembuatan entitas, error program, atau pembatalan pengguna (`ESC`), sistem hanya menghapus `ename` di `txCreatedEnts` dan hanya menghapus entry `txSavedGroupId` (`dictremove` + `entdel`) milik transaksi aktif. Entitas dan metadata milik grup lain tidak pernah disentuh.
- **Error handler terstruktur (`*error*`):** Membedakan dengan jelas antara pembatalan pengguna (`Function cancelled` / `ESC`), abort terkendali (`txAbortedByCode`), dan error program; selalu menutup DCL, melakukan rollback bila transaksi aktif, menutup `UNDO` Group, dan memulihkan `CMDECHO`.

### 3. Entity Count Validation & XData Verification (Prioritas C)
- **Rumus eksak (`asgrid:calc-expected-counts`):** Menghitung jumlah entitas eksak berdasarkan metadata terverifikasi (`readBack`):
  - `expLines = NUM_H + NUM_V`
  - `endsMult = 2` untuk `"Both Ends"`, `1` untuk `"Start"` atau `"End"`
  - `expBubbles = (NUM_H + NUM_V) * endsMult`
  - `expTexts = (NUM_H + NUM_V) * endsMult`
  - `expTotal = expLines + expBubbles + expTexts`
- **Verifikasi per entitas (`fn-verify-tx-entities`):** Memastikan setiap entitas dalam `txCreatedEnts` memiliki XData `ASGRID_OBJ` yang utuh, Role valid (`LINE`/`BUBBLE`/`TEXT`), dan `Group ID` tepat sama dengan grup aktif. Ketidakcocokan sekecil apa pun memicu rollback penuh.

### 4. Strict Metadata Integrity Validation (Prioritas D)
- `asgrid:meta-validate-spec` diperluas untuk memeriksa: keberadaan 22 key wajib, string wajib non-kosong, tipe integer positif untuk `NUM_H`/`NUM_V`, kecocokan panjang & elemen numerik positif pada `DIST_H`/`DIST_V`, validitas 3D point numerik `BASE_PT_WCS`, nilai positif pada parameter skala/anotasi, serta validitas enum `BUBBLE_POS`.

### 5. Perintah Diagnostik READ-ONLY `ASGRIDCHECK` (Prioritas E)
- Ditambahkan perintah baru **`ASGRIDCHECK`** di dalam `ASGRID_V2_1_1.lsp` yang 100% **READ-ONLY** (tidak memanggil operasi mutasi DWG apa pun).
- Memeriksa daftar grup di NOD `ASGRID_GROUPS`, validitas XRecord tiap grup, kesesuaian jumlah entitas aktual vs ekspektasi per grup, metadata yatim (0 entitas), entitas yatim (XData tanpa XRecord di NOD), dan XData korup.

### 6. Perubahan pada File DCL (`ASGRID_V2_1_1.dcl`)
- Nama definisi dialog diperbarui dari `asgrid_v2_1` menjadi `asgrid_v2_1_1` dan judul diperbarui ke `ASGRID V2.1.1` agar dapat berdampingan aman dengan file V2.1 di folder yang sama.
- Seluruh tata letak 2-kolom, tabel spacing dengan pagination, dan panel Live Preview (`grid_preview`) dipertahankan 100% identik.

## Fitur yang Tidak Diubah (Dipertahankan Utuh dari V2.1)
- Antarmuka DCL 2-kolom & Live Preview (`start_image`, `fill_image`, `vector_image`, `end_image`, mode padat adaptif).
- Tabel spacing individual dengan pagination 8 baris/halaman.
- Penomoran horizontal (`1, 2, 3, ...`) dan vertikal (`A..Z, AA, AB, ...`).
- Perhitungan skala cetak dinamis, Text Style terisolasi `ASGRID-ARIAL` (`arial.ttf`), layer otomatis (`AS-GRID`, `AS-BUBBLE`, `AS-TEXT`), WCS, dan satuan milimeter.
- Batasan ruang lingkup tetap dijaga: fitur `ASGRID EDIT` belum diimplementasikan pada versi ini.
