# CHANGELOG — ASGRID V2.1.2 (Quick Fix & Diagnostic Improvement)

- **Tanggal Rilis:** 2026-11-26
- **Baseline:** ASGRID V2.1.1 (`ASGRID_V2_1_1.lsp` & `ASGRID_V2_1_1.dcl` — dipertahankan utuh sebagai backup)
- **Target Lingkungan:** AutoCAD 2021 (AutoLISP standar + DCL, Model Space, WCS, satuan milimeter)
- **Status Pengujian:** Verifikasi statis selesai (0 error sintaks, 0 tile hilang, 0 mutasi pada `ASGRIDCHECK`); belum dijalankan langsung di instalasi AutoCAD 2021 lokal.

## Perubahan dari V2.1.1 ke V2.1.2

### A. Metadata Hardening
- **`asgrid:meta-read-group`:** Ditambahkan pemeriksaan tipe data `(numberp val)` sebelum setiap konversi `(float val)` untuk `DIST_H_ITEM`, `DIST_V_ITEM`, `ELEVATION`, `SCALE_DENOM`, `TEXT_H_PRINT`, `BUBBLE_DIA_PRINT`, `EXT_LEN`, dan komponen 3D `BASE_PT_WCS`, serta pemeriksaan tipe integer pada `NUM_H`, `NUM_V`, `DIST_H_COUNT`, dan `DIST_V_COUNT`.
- **Proteksi anti-crash saat XRecord korup:** Anomali tipe data atau pasangan key-value XRecord yang putus dicatat ke key internal `"_READ_ERRORS"` tanpa menghentikan eksekusi `ASGRIDCHECK` secara tak terkendali.

### B. Metadata Consistency Validation
- **`asgrid:meta-validate-spec`:** Diperluas dari 22 menjadi 24 key wajib (menambahkan verifikasi eksplisit `DIST_H_COUNT` dan `DIST_V_COUNT`), ditambah validasi:
  - `DIST_H_COUNT == (length DIST_H)` dan `DIST_V_COUNT == (length DIST_V)`.
  - `(length DIST_H) == NUM_H - 1` dan `(length DIST_V) == NUM_V - 1`.
  - `ELEVATION` wajib berupa nilai numerik (`numberp`).
  - Nilai `Z` pada `BASE_PT_WCS` wajib konsisten dengan `ELEVATION` dalam toleransi `1e-6`.
  - Seluruh `_READ_ERRORS` dari pembaca XRecord diteruskan sebagai pesan error yang jelas tanpa mengubah metadata secara otomatis.
- **`fn-meta-build-spec` & `asgrid:meta-compare-specs`:** Memasukkan `DIST_H_COUNT` dan `DIST_V_COUNT` secara eksplisit dalam spec pra-tulis dan perbandingan baca-balik (*deep compare*).

### C. ASGRIDCHECK Deep Diagnostics (100% READ-ONLY)
- Selain membandingkan jumlah `LINE`, `BUBBLE`, dan `TEXT`, `c:ASGRIDCHECK` kini juga memeriksa:
  1. Kesesuaian DXF entity type (`LINE`, `CIRCLE`, `TEXT`) dengan XData `Role` (`LINE`, `BUBBLE`, `TEXT`).
  2. Validitas rentang `AxisIdx` terhadap `NUM_H` (untuk `AxisDir = "H"`) dan `NUM_V` (untuk `AxisDir = "V"`).
  3. Kesesuaian `EndTag` (`NONE`/`START`/`END`) terhadap `Role` dan `BUBBLE_POS` (`Both Ends`/`Start`/`End`).
  4. Duplikasi identitas slot objek berdasarkan kombinasi `Role|AxisDir|AxisIdx|EndTag`.
  5. Objek dengan XData `ASGRID_OBJ` tidak lengkap/tidak valid, entitas yatim (Group ID tanpa metadata di NOD), dan metadata yatim (0 entitas terkait).
- Menampilkan catatan eksplisit bahwa pemindaian memakai `ssget "_X"` (hanya entitas *top-level*, tidak mencakup *nested entities* di dalam `BLOCK`).

### D. DCL & Interaksi Dialog
- **`ASGRID_V2_1_2.dcl`:** Escape karakter `&` menjadi `&&` pada label `boxed_column` (`"C. Scale && Annotation"`) agar tidak ditafsirkan sebagai mnemonic shortcut, serta pembaruan dialog ID ke `asgrid_v2_1_2`.
- **Konsistensi default vertical spacing:** Menggunakan konstanta `DEF_SPACING_H = "4000"` dan `DEF_SPACING_V = "5000"` secara konsisten saat inisialisasi dialog, penambahan sumbu baru (`fn-sync-grid-counts`, `fn-validate-all`), dan fallback Live Preview.
- **Peringatan visual non-blocking:** `fn-update-scale-preview` menampilkan peringatan langsung pada baris `scale_preview` bila `bubble diameter <= text height` (`[WARN: Bubble <= Text!]`) atau sempit (`< 2 × text height`, `[Note: Bubble sempit]`).

### E. Kompatibilitas Lingkungan AutoCAD 2021
- Ditambahkan `fn-check-insunits-warning`: menampilkan info non-blocking di command line bila `INSUNITS` bukan `4` (Millimeters), tanpa mengubah `INSUNITS` maupun `LTSCALE`.
- Kompatibel 100% dengan metadata dan objek yang dibuat oleh V2.1 dan V2.1.1 (Schema `1.0`, NOD `ASGRID_GROUPS`, XData `ASGRID_OBJ`).
