# FOUNDATION CHANGELOG — ASGRID V2.2 (Phase 1: Shared Service Refactoring)

- **Tanggal Rilis:** 2026-11-26
- **Baseline:** ASGRID V2.1.2 (`ASGRID V2.1.2/ASGRID_V2_1_2.lsp` & `ASGRID_V2_1_2.dcl` — dipertahankan utuh)
- **Target Lingkungan:** AutoCAD 2021 (AutoLISP standar + DCL, Model Space, WCS, satuan milimeter)
- **Ruang Lingkup Phase 1:** Ekstraksi *Shared Stateless Services* (`asgrid:*`), pemisahan *Annotation Engine*, dukungan metadata opsional `ANNO_EXT_LEN` + `meta-update-group`/snapshot, *Live Preview* dual-extension, dan *Shared Group Audit Service* (`READ-ONLY`). Perintah `ASGRIDEDIT` **belum** diimplementasikan pada tahap ini (disiapkan untuk Phase 2).
- **Status Pengujian:** Verifikasi statis selesai (0 error sintaks/tile/stale reference/mutasi); belum dijalankan langsung di AutoCAD 2021 lokal.

## Perubahan dari V2.1.2 ke V2.2 Phase 1

### 1. Ekstraksi Shared Stateless Services (`asgrid:*`)
Seluruh fungsi utilitas, font, metadata, anotasi, live preview, dan audit grup yang dibutuhkan bersama telah diekstrak ke top-level `asgrid:*` dengan parameter & return value eksplisit (nol variabel global state):
- **Core Utilities:** `asgrid:index-to-alpha`, `asgrid:compute-cumulative`, `asgrid:get-timestamp`, `asgrid:check-insunits-warning`.
- **Font Service:** `asgrid:find-arial-ttf`, `asgrid:ensure-arial-style`.
- **Metadata & XRecord Service:** `asgrid:make-obj-xdata`, `asgrid:get-anno-ext-len`, `asgrid:meta-build-xrecord-payload`, `asgrid:meta-get-xrecord-snapshot`, `asgrid:meta-update-group`, `asgrid:meta-restore-xrecord` (melengkapi fungsi `asgrid:meta-*` yang sudah ada sejak V2.1.1/V2.1.2).
- **Annotation Service:** `asgrid:draw-circle`, `asgrid:draw-text-mc`, `asgrid:annotation-engine`.
- **Live Preview Service:** `asgrid:prev-draw-circle`, `asgrid:prev-draw-char`, `asgrid:prev-draw-string`, `asgrid:prev-render-grid`.
- **Group Audit Service (READ-ONLY):** `asgrid:audit-group-entities`.

### 2. Decoupled Annotation Engine
- `asgrid:draw-circle` dan `asgrid:draw-text-mc` kini murni mengembalikan `ename` hasil `entmakex` (atau `nil`) tanpa memutasi `txCreatedEnts` secara implisit.
- `asgrid:annotation-engine` membaca `spec` (menggunakan `asgrid:get-anno-ext-len`) dan mengembalikan `(list createdEnts cntBubble cntText)`.
- `c:ASGRID` menggabungkan `createdEnts` ke `txCreatedEnts` secara eksplisit sehingga pelacakan transaksi, entity count validation, dan rollback tetap bekerja identik dengan V2.1.2.

### 3. Metadata Opsional `ANNO_EXT_LEN` & XRecord Update Service
- Grid baru buatan `ASGRID` V2.2 menyimpan `EXT_LEN` dan `ANNO_EXT_LEN` dengan nilai awal yang sama.
- Grid lama buatan V2.1, V2.1.1, dan V2.1.2 (tanpa `ANNO_EXT_LEN`) tetap lolos validasi Schema `1.0` dan otomatis menggunakan `EXT_LEN` sebagai fallback melalui `asgrid:get-anno-ext-len`.
- `asgrid:meta-read-group`, `asgrid:meta-validate-spec`, dan `asgrid:meta-compare-specs` diperluas untuk mendukung `ANNO_EXT_LEN` (dengan pemeriksaan `numberp` dan `> 0.0` bila hadir).
- Ditambahkan `asgrid:meta-get-xrecord-snapshot`, `asgrid:meta-update-group` (menggunakan `entmod` yang mempertahankan `-1`, Handle `5`, dan Dictionary Ownership `330`), serta `asgrid:meta-restore-xrecord` untuk rollback.

### 4. Dual-Extension Live Preview (`asgrid:prev-render-grid`)
- `asgrid:prev-render-grid` kini menerima parameter terpisah `geomExtLen` (untuk panjang garis grid) dan `annoExtLen` (untuk posisi bubble & teks).
- Pada generator `c:ASGRID`, kedua parameter diisi nilai yang sama (`EXT_LEN`) sehingga tampilan preview V2.1.2 tidak berubah.

### 5. Shared Group Audit Service & `ASGRIDCHECK`
- Logika audit integritas entitas per grup (`LINE`/`BUBBLE`/`TEXT` counts, DXF vs Role, `AxisIdx`, `EndTag` vs `BUBBLE_POS`, duplikasi slot, XData korup) diekstrak menjadi `asgrid:audit-group-entities` (100% READ-ONLY).
- `c:ASGRIDCHECK` kini memanggil `asgrid:audit-group-entities` dan menampilkan informasi `Extension: Geom ... | Anno ...` (serta keterangan `(fallback EXT_LEN)` untuk grid lama).

### 6. File DCL (`ASGRID_V2_2.dcl`)
- Definisi dialog generator `asgrid_v2_2` mempertahankan 100% struktur, tile key, pagination, escape mnemonic `&&`, dan Live Preview dari `ASGRID_V2_1_2.dcl`.
