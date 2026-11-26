# CHANGELOG — ASGRID V2.2.1 (XRecord Reliability Hardening)

- **Tanggal Rilis:** 2026-11-26
- **Baseline:** ASGRID V2.2 (MODE 1 FIX) — folder `ASGRID V2.2 Phase 2` tetap utuh tanpa ditimpa
- **Target Lingkungan:** AutoCAD 2021 (AutoLISP standar + DCL, WCS, milimeter)
- **Ruang Lingkup:** Hardening terbatas pada `asgrid:meta-extract-raw-payload` dan `asgrid:meta-restore-xrecord` (MODE 2 tidak dikerjakan).
- **Status Pengujian:** Verifikasi statis lulus penuh; **belum dijalankan langsung di AutoCAD 2021**.

## Perubahan dari V2.2 (MODE 1 FIX) ke V2.2.1

### 1. Hardening `asgrid:meta-extract-raw-payload`
- **Sebelumnya:** Menggunakan flag boolean `inPayload` dan membuang **seluruh** DXF group code `280` setelah `(100 . "AcDbXrecord")`, sehingga pasangan `(280 . val)` yang merupakan data payload ikut terhapus.
- **Sesudah (V2.2.1):** Menggunakan *state machine* 3-tahap (`state = 0` sebelum `(100 . "AcDbXrecord")`, `state = 1` tepat satu elemen pertama setelah marker, `state = 2` di dalam payload):
  - Melewati **hanya satu** pasangan `(280 . flag)` header Duplicate Record Cloning Flag yang muncul tepat setelah `(100 . "AcDbXrecord")`.
  - Mempertahankan **seluruh** pasangan DXF payload setelahnya—termasuk group code `280` yang muncul sebagai payload—dengan urutan, nilai, dan tipe data asli 100% utuh.
  - Menangani input `nil`, bukan list, atau elemen pasangan tidak valid secara aman tanpa error.

### 2. Hardening `asgrid:meta-restore-xrecord`
- **Ekstraksi Header Clone Flag Presisi (`fn-get-header-280`):** Mengambil nilai header `280` hanya jika tepat berada setelah `(100 . "AcDbXrecord")` (fallback `1`), tidak tertukar dengan payload `280`.
- **Validasi `dictremove` Eksplisit:** Memeriksa nilai return `(dictremove rootDict groupId)`. Jika gagal, proses dihentikan, `dictadd` tidak dipanggil, dan XRecord sementara `restEname` dibersihkan.
- **Pemulihan Berlapis Saat `dictadd` atau Verifikasi Gagal (`fn-reattach-cur`):**
  - Mencoba *undelete* `curEname` via `entdel` bila `dictremove` menandainya *erased*, memasang kembali ke dictionary, dan memverifikasi bahwa dictionary benar-benar menunjuk ke XRecord valid.
  - Bila *reattach* `curEname` gagal, membangun fallback XRecord bersih dari snapshot mentah `curSnap` via `entmakex` + `dictadd` + verifikasi.
  - Tidak menghapus satu-satunya salinan metadata yang masih bisa dipulihkan, serta mencetak pesan **`CRITICAL`** yang mengarahkan pengguna menjalankan `UNDO (Ctrl+Z)` bila pemulihan gagal total.
- **Verifikasi Read-Back Ketat & Cleanup Anti Double-`entdel`:** Memverifikasi keberadaan key `groupId`, entity type `"XRECORD"`, dan kesamaan payload mentah `(equal readPayload origPayload (asgrid:tol))` sebelum menghapus `curEname` (hanya bila `(entget curEname)` masih non-nil).

### 3. Kompatibilitas Pemuatan File DCL
- `ASGRID_V2_2_1.dcl` adalah salinan **byte-identik** dari `ASGRID_V2_2.dcl`.
- Pemuatan DCL memakai `(or (findfile "ASGRID_V2_2_1.dcl") (findfile "ASGRID_V2_2.dcl"))` agar folder V2.2.1 dapat berdiri sendiri tanpa mengubah struktur DCL maupun alur dialog.

## Komponen yang Tidak Diubah
- `c:ASGRID` (generator), `c:ASGRIDEDIT` (alur transaksi & dialog), `c:ASGRIDCHECK` (byte-identik), `asgrid:meta-update-group` (byte-identik), `ASGRID_V2_2_1.dcl` (byte-identik), Schema `1.0`, NOD `ASGRID_GROUPS`, RegApp `ASGRID_OBJ` & `ASGRID_TX_TMP`, serta seluruh geometri dan anotasi.
