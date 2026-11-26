# Dokumentasi Teknis — ASGRID V2.2.1 Revision 3

**Proyek:** CIVIL DRAFTING AUTOMATION — Modul ASGRID  
**Repository:** [CIVIL-DRAFTING-AUTOMATION](https://github.com/Gatamboy/CIVIL-DRAFTING-AUTOMATION)  
**Baseline Resmi:** ASGRID V2.2.1 R3 (`ASGRID_V2_2_1_R3.lsp` & `ASGRID_V2_2_1_R3.dcl`)  
**Target Runtime:** AutoCAD 2021 (AutoLISP Standar + DCL, Model Space WCS, satuan milimeter)  
**Tanggal Konsolidasi:** 26 November 2026

## A. Project Overview

### Tujuan ASGRID
ASGRID adalah modul otomasi AutoLISP + DCL untuk pembuatan, pemeriksaan integritas, dan penyuntingan anotasi grid struktur bangunan (*building grid*) secara terukur di AutoCAD 2021 pada Model Space (WCS, satuan milimeter). Program ini dirancang agar setiap grup grid memiliki identitas metadata yang terstruktur, terisolasi antar-grup, dan aman terhadap kegagalan transaksi.

### Fitur Utama
- **Generator Grid (`ASGRID`):** Membuat grid sumbu horizontal (`1, 2, 3...`, sejajar sumbu X) dan vertikal (`A..Z, AA, AB...`, sejajar sumbu Y) dengan jarak interval individual, paginasi tabel 8 baris per halaman di dialog DCL, penskalaan cetak dinamis (`ukuran_model = ukuran_cetak × scale_denom`), serta *Live Preview* real-time di dalam dialog.
- **Isolasi Style & Layer:** Membuat Text Style terisolasi `ASGRID-ARIAL` (`arial.ttf`, tanpa fallback diam-diam) dan layer otomatis `AS-GRID` (`CENTER`), `AS-BUBBLE` (`CONTINUOUS`), serta `AS-TEXT` (`CONTINUOUS`) tanpa memodifikasi `UCS`, `DIMSTYLE`, `TEXTSTYLE`, `INSUNITS`, atau `LTSCALE` secara global.
- **Editor Anotasi (`ASGRIDEDIT` Mode 1):** Memperbarui parameter anotasi (diameter bubble, tinggi teks, Text Style, posisi bubble, dan jarak ekstensi anotasi) pada grup grid yang sudah ada tanpa menggeser atau memodifikasi geometri garis grid (`LINE`).
- **Diagnostik Integritas (`ASGRIDCHECK`):** Melakukan audit menyeluruh 100% *read-only* terhadap konsistensi metadata di Named Object Dictionary (NOD) dan entitas aktual pada gambar.
- **Keamanan Transaksi & XRecord:** Menggunakan blok `UNDO` tunggal, pelacakan transaksi, mekanisme *Replace-in-Dictionary* (tanpa `entmod` pada `XRECORD`), serta validasi pra-pemulihan snapshot pada proses rollback.

### Versi AutoCAD yang Didukung
- **AutoCAD 2021** (AutoLISP standar + DCL).
- Kompatibilitas dengan versi AutoCAD selain 2021 **belum terverifikasi**.

### Status Versi R3
**ASGRID V2.2.1 R3** adalah **baseline resmi saat ini**. Versi ini menyempurnakan R2 dengan memperbaiki bug runtime `bad argument type: stringp T` pada pemuatan file dialog DCL di `c:ASGRID` dan `c:ASGRIDEDIT` tanpa mengubah logika generator, metadata, XRecord, transaksi, maupun isi fungsional DCL.

## B. System Architecture

### Struktur File (Baseline R3)
| File | Peran | Catatan Teknis |
| :--- | :--- | :--- |
| `ASGRID_V2_2_1_R3.lsp` | Program utama AutoLISP (4.202 baris, 89 `defun`) | Berisi 6 section layanan stateless `asgrid:*` serta perintah `c:ASGRID`, `c:ASGRIDCHECK`, dan `c:ASGRIDEDIT`. |
| `ASGRID_V2_2_1_R3.dcl` | Definisi antarmuka dialog DCL (361 baris, 12.745 byte) | Memuat dialog `asgrid_v2_2` dan `asgrid_edit_v2_2`; identik *byte-per-byte* dengan DCL R2. |
| `ASGRID_V2_2_1_R3_DOCUMENTATION.md` | Dokumentasi teknis terkonsolidasi | Referensi arsitektur, metadata, perintah, batasan, dan status pengujian R3. |
| `revision3_changelog.md` | Catatan perubahan R2 → R3 | Ringkasan perubahan terfokus pada perbaikan pemuatan DCL. |
| `revision3_technical_review.md` | Tinjauan teknis & unified diff R2 → R3 | Memuat bukti validasi statis dan penjelasan tiap hunk diff. |
| `revision3_testing_checklist.md` | Daftar uji runtime AutoCAD 2021 | Skenario uji fungsional dan fallback DCL. |

### Arsitektur Modular (`ASGRID_V2_2_1_R3.lsp`)
Kode sumber dipisahkan menjadi 6 layanan *stateless* berawalan `asgrid:*` (tanpa variabel state global) diikuti 3 perintah utama:
1. **Section 1 — Shared Stateless Constants & Core Utilities:** Konstanta (`asgrid:dict-name`, `asgrid:xdata-app`, `asgrid:xdata-tmp-app`, `asgrid:schema-ver`, `asgrid:tol`), registrasi RegApp aman (`asgrid:ensure-regapp`), parser angka ketat, konversi indeks alfabet (`asgrid:index-to-alpha`), dan koordinat kumulatif.
2. **Section 2 — Shared Font Arial Service:** Pencarian file font (`asgrid:find-font-file`, `asgrid:find-arial-ttf`), validasi Text Style non-annotative (`asgrid:validate-text-style`), dan penjaminan style `ASGRID-ARIAL` (`asgrid:ensure-arial-style`).
3. **Section 3 — Shared Metadata, XData & XRecord Service:** Pengelolaan NOD `ASGRID_GROUPS`, konstruksi/parsing payload XRecord, snapshot & ekstraksi payload mentah (`asgrid:meta-extract-raw-payload`), pemulihan dan pembaruan XRecord berbasis *Replace-in-Dictionary* (`asgrid:meta-restore-xrecord`, `asgrid:meta-update-group`), serta validasi & perbandingan spesifikasi.
4. **Section 4 — Shared Annotation Engine Service:** Pembuatan entitas `CIRCLE` dan `TEXT` (*Middle Center*) secara *decoupled* melalui `asgrid:annotation-engine`.
5. **Section 5 — Shared Live Preview Service:** Renderer vektor dialog DCL (`asgrid:prev-render-grid`) yang mendukung `geomExtLen` dan `annoExtLen` secara terpisah.
6. **Section 6 — Shared Group Audit Service:** Pemeriksaan integritas 100% *read-only* (`asgrid:audit-group-entities`).

### Alur Kerja Perintah `ASGRID`
1. Mencari file DCL secara berurutan menggunakan `setq` + `if`: `ASGRID_V2_2_1_R3.dcl` → `ASGRID_V2_2_1_R2.dcl` → `ASGRID_V2_2_1.dcl` → `ASGRID_V2_2.dcl`.
2. Memuat dialog `asgrid_v2_2` (`load_dialog` → `new_dialog`), mengisi nilai default, pratinjau `Group ID` berikutnya (`fn-meta-generate-next-id`), dan menampilkan *Live Preview*.
3. Pengguna mengatur jumlah sumbu, jarak interval, skala, ukuran anotasi, ekstensi, dan posisi bubble, lalu menekan `OK` (tervalidasi di dialog) dan memilih titik insersi WCS di Model Space.
4. Memulai blok `UNDO` tunggal dan transaksi: memastikan RegApp `ASGRID_OBJ` (via `tblsearch "APPID"`), Text Style `ASGRID-ARIAL`, dan layer `AS-GRID`/`AS-BUBBLE`/`AS-TEXT`.
5. Membuat entitas geometri garis grid (`LINE`) terlebih dahulu, lalu memanggil `asgrid:annotation-engine` untuk membuat seluruh `CIRCLE` dan `TEXT`.
6. Menyimpan metadata XRecord ke NOD `ASGRID_GROUPS`, memvalidasi jumlah entitas dan metadata (*Metadata Hard Gate*), lalu menutup transaksi; jika gagal di tahap mana pun, seluruh entitas dan metadata transaksi di-rollback.

### Alur Kerja Perintah `ASGRIDEDIT` (Mode 1)
1. Meminta pengguna memilih satu entitas grid (`fn-edit-select-and-validate`), membaca XData `ASGRID_OBJ`, mengambil metadata grup dari NOD `ASGRID_GROUPS`, memvalidasi spesifikasi, dan menjalankan audit awal *read-only*.
2. Memuat dialog `asgrid_edit_v2_2` menggunakan pencarian DCL berurutan `setq` + `if` yang sama dengan `ASGRID`.
3. Menampilkan informasi geometri terkunci (*read-only*) dan parameter anotasi yang dapat diubah beserta *Live Preview*.
4. Saat `OK`, menjalankan transaksi 6-langkah *Create-Verify-Swap-Commit* (`fn-edit-execute-transaction`) yang dijelaskan rinci pada Bagian E.

### Alur Kerja Perintah `ASGRIDCHECK`
1. Memindai seluruh entitas top-level pada gambar (`ssget "_X"`) yang memiliki XData `ASGRID_OBJ` untuk mendeteksi XData korup atau entitas yatim (*orphan*) tanpa entri NOD.
2. Membaca seluruh `Group ID` terdaftar pada NOD `ASGRID_GROUPS` dan memanggil `asgrid:audit-group-entities` untuk memverifikasi kelengkapan metadata, jumlah `LINE`/`BUBBLE`/`TEXT`, duplikasi slot, dan konsistensi layer/style.
3. Menampilkan laporan diagnostik dan ringkasan di command line tanpa melakukan satu pun operasi tulis (`entmake`/`entmakex`/`entmod`/`entdel`/`dictadd`/`dictremove`).

### Pemisahan Proses Geometri dan Anotasi
Geometri garis grid (`LINE`) dan anotasi (`CIRCLE` bubble + `TEXT` label) dipisahkan secara eksplisit:
- Garis grid dibuat langsung pada fase generator `c:ASGRID` menggunakan `EXT_LEN` sebagai ekstensi geometri dan tidak pernah disentuh ulang oleh `ASGRIDEDIT` Mode 1.
- Anotasi diproduksi sepenuhnya oleh layanan stateless `asgrid:annotation-engine`, yang menerima `spec`, menghitung posisi bubble dan teks berdasarkan `ANNO_EXT_LEN` (fallback ke `EXT_LEN` jika tidak ada), menyematkan XData sesuai `appName` target (`ASGRID_OBJ` atau `ASGRID_TX_TMP`), dan mengembalikan daftar `ename` beserta hitungan entitas secara eksplisit.

## C. Metadata Architecture

### Named Object Dictionary (`ASGRID_GROUPS`) & `XRECORD`
Seluruh metadata grup grid disimpan di dalam sub-dictionary bernama **`ASGRID_GROUPS`** pada Named Object Dictionary (`namedobjdict`). Setiap grup grid direpresentasikan oleh satu objek **`XRECORD`** dengan kunci dictionary berupa **`Group ID`** unik (`ASG-0001`, `ASG-0002`, dst.).

### XData Identitas Objek (`ASGRID_OBJ` & `ASGRID_TX_TMP`)
Setiap entitas grafis yang dibuat ASGRID membawa XData ringan pada RegApp **`ASGRID_OBJ`** (atau **`ASGRID_TX_TMP`** khusus untuk anotasi sementara selama transaksi `ASGRIDEDIT` sebelum tahap promosi). Registrasi RegApp selalu diperiksa terlebih dahulu menggunakan `(tblsearch "APPID" appName)` melalui `asgrid:ensure-regapp`.

Urutan field XData pada `asgrid:make-obj-xdata-for-app`:
| Urutan | DXF Code | Field | Nilai Valid |
| :--- | :--- | :--- | :--- |
| 1 | `1000` | `GroupID` | String, contoh `"ASG-0001"` |
| 2 | `1000` | `Role` | `"LINE"`, `"BUBBLE"`, atau `"TEXT"` |
| 3 | `1000` | `AxisDir` | `"H"` atau `"V"` |
| 4 | `1070` | `AxisIdx` | Integer indeks sumbu (`1..N`) |
| 5 | `1000` | `EndTag` | `"NONE"` (garis), `"START"`, atau `"END"` (anotasi) |
| 6 | `1000` | `SchemaVer` | `"1.0"` |

### Group ID & Schema Version
- **Group ID:** Format `ASG-XXXX` (contoh `ASG-0001`), digenerate secara inkremental berdasarkan daftar ID tertinggi yang ditemukan di NOD maupun XData gambar (`asgrid:meta-list-all-ids`).
- **Schema Version:** `"1.0"` (`asgrid:schema-ver`).

### Data yang Disimpan pada Payload `XRECORD`
Payload XRecord disusun oleh `asgrid:meta-build-xrecord-payload` sebagai pasangan `(300 . <KEY>)` diikuti nilai bertipe DXF native:

| Key (`300`) | DXF Code Nilai | Tipe | Status | Keterangan |
| :--- | :--- | :--- | :--- | :--- |
| `SCHEMA_VER` | `1` | String | Wajib | Versi skema (`"1.0"`) |
| `GROUP_ID` | `1` | String | Wajib | ID unik grup (`ASG-XXXX`) |
| `MODULE` | `1` | String | Wajib | Nama modul (`"ASGRID"`) |
| `GENERATOR_VER` | `1` | String | Wajib | Versi generator saat pembuatan |
| `CREATED_AT` | `1` | String | Wajib | Stempel waktu pembuatan |
| `NUM_H` / `NUM_V` | `90` | Int32 | Wajib | Jumlah sumbu horizontal & vertikal |
| `BASE_PT_WCS` | `10` | 3D Point | Wajib | Titik acuan WCS grup |
| `ELEVATION` | `40` | Real | Wajib | Elevasi Z grup |
| `AXIS_DIR_H` / `AXIS_DIR_V` | `1` | String | Wajib | Arah/label orientasi sumbu |
| `DIST_H_COUNT` / `DIST_V_COUNT` | `90` | Int32 | Wajib | Jumlah interval jarak H & V (`NUM - 1`) |
| `DIST_H_ITEM` / `DIST_V_ITEM` | `40` | Real (berulang) | Wajib | Daftar jarak antar-sumbu (mm) |
| `SCALE_DENOM` | `40` | Real | Wajib | Penyebut skala cetak (mis. `100.0` untuk 1:100) |
| `TEXT_H_PRINT` | `40` | Real | Wajib | Tinggi teks cetak (mm) |
| `BUBBLE_DIA_PRINT` | `40` | Real | Wajib | Diameter bubble cetak (mm) |
| `EXT_LEN` | `40` | Real | Wajib | Panjang ekstensi geometri garis grid (mm) |
| `BUBBLE_POS` | `1` | String | Wajib | `"Both Ends"`, `"Start"`, atau `"End"` |
| `TEXT_STYLE` | `1` | String | Wajib | Nama AutoCAD Text Style aktif grup |
| `FONT_FILE` | `1` | String | Wajib | Nama file font terkait |
| `LAYER_GRID` / `LAYER_BUBBLE` / `LAYER_TEXT` | `1` | String | Wajib | Nama layer untuk tiap peran entitas |
| `ANNO_EXT_LEN` | `40` | Real | Opsional (V2.2+) | Jarak ekstensi anotasi terpisah (mm); fallback ke `EXT_LEN` bila tidak ada |
| `UPDATED_AT` | `1` | String | Opsional (V2.2+) | Stempel waktu pembaruan terakhir oleh `ASGRIDEDIT` |

### Hubungan Metadata dengan Objek Grid
Setiap objek grafis (`LINE`, `CIRCLE`, `TEXT`) tertaut ke entri `XRECORD` melalui `GroupID` pada XData `ASGRID_OBJ`. Kombinasi `(GroupID, Role, AxisDir, AxisIdx, EndTag)` membentuk slot unik sehingga `asgrid:audit-group-entities` dapat memverifikasi jumlah ekspektasi (`asgrid:calc-expected-counts`), mendeteksi slot hilang/ganda, dan memastikan integritas grup secara independen tanpa mengganggu grup lain pada DWG yang sama.

### Mekanisme Update dan Restore XRecord (Replace-in-Dictionary)
Karena `(entmod ...)` pada `AcDbXrecord` di AutoCAD 2021 menggabungkan (*append*) resbuf alih-alih menimpa payload, pembaruan dan pemulihan XRecord dilakukan dengan pola **Replace-in-Dictionary** (tanpa `entmod`):
1. **Update (`asgrid:meta-update-group`):** Membangun payload baru → membuat objek `XRECORD` baru dengan `entmakex` → mencopot entri lama dengan `dictremove` (memeriksa return value) → mendaftarkan objek baru dengan `dictadd` → melakukan *read-back verification* (`asgrid:meta-read-group` + `asgrid:meta-validate-spec` + `asgrid:meta-compare-specs`) → menghapus objek lama secara aman dengan penjagaan `(if (entget oldEname) (entdel oldEname))`.
2. **Ekstraksi Payload Mentah (`asgrid:meta-extract-raw-payload`):** Menggunakan *state machine* 3-tahap setelah `(100 . "AcDbXrecord")` yang hanya melewati satu header `Duplicate Record Cloning Flag` `(280 . 0..5)` dan mempertahankan seluruh pasangan DXF payload termasuk kode `280` di dalam payload.
3. **Restore (`asgrid:meta-restore-xrecord`):** Menjalankan 6 gerbang validasi snapshot (tipe `XRECORD`, marker `AcDbXrecord`, payload dapat diparsing, `GROUP_ID` cocok, spesifikasi valid, dan payload non-kosong), membuat XRecord pemulihan via `entmakex`, memeriksa return value seluruh 4/4 pemanggilan `dictremove`, memverifikasi kesamaan payload baca-balik secara eksplisit (tidak menganggap `curPayload = nil` sebagai lulus), serta mengembalikan status 3-keadaan (`'RESTORED`, `'NO_PREV_ENTRY`, atau `'RESTORE_FAILED`) pada jalur reattach bila terjadi kegagalan.

## D. Command Reference

| Perintah | Fungsi Utama | Alur Penggunaan Singkat | Batasan Utama |
| :--- | :--- | :--- | :--- |
| `ASGRID` | Membuat grup grid baru beserta anotasi dan metadata XRecord. | Jalankan `ASGRID` → isi konfigurasi grid, spacing, skala, anotasi di dialog `asgrid_v2_2` → klik `OK` → pilih titik insersi WCS. | Hanya pada Model Space WCS (mm); membutuhkan `arial.ttf` untuk style `ASGRID-ARIAL` (tidak ada fallback font diam-diam); membutuhkan file DCL pada *Support File Search Path*. |
| `ASGRIDEDIT` | Menyunting anotasi grup grid eksisting (Mode 1). | Jalankan `ASGRIDEDIT` → klik salah satu entitas grid → ubah parameter anotasi di dialog `asgrid_edit_v2_2` → klik `OK`. | Hanya Mode 1 (anotasi); tidak dapat mengubah jumlah sumbu, spacing, skala, elevasi, titik dasar, atau geometri garis grid; menolak grup dengan audit awal rusak/tidak konsisten. |
| `ASGRIDCHECK` | Audit diagnostik integritas seluruh grup grid pada DWG. | Jalankan `ASGRIDCHECK` → tinjau laporan grup, jumlah entitas, XData korup, dan entitas yatim di command line. | 100% *read-only* (tidak melakukan perbaikan otomatis); pemindaian `ssget "_X"` hanya menjangkau entitas top-level, bukan entitas di dalam definisi `BLOCK`. |

## E. ASGRIDEDIT Mode 1

### Parameter yang Dapat Diedit
1. **Bubble Diameter (Print, mm)** — `BUBBLE_DIA_PRINT`
2. **Text Height (Print, mm)** — `TEXT_H_PRINT`
3. **Text Style** — `TEXT_STYLE` (serta `FONT_FILE` yang sesuai; divalidasi non-annotative dan fixed height = `0.0` melalui `asgrid:validate-text-style`)
4. **Bubble Position** — `BUBBLE_POS` (`"Both Ends"`, `"Start"`, `"End"`)
5. **Annotation Extension Length (mm)** — `ANNO_EXT_LEN`

*(Selain itu, `UPDATED_AT` diperbarui otomatis oleh sistem saat commit.)*

### Parameter yang Tidak Boleh Berubah (Terkunci)
- Identitas & struktur grid: `GROUP_ID`, `SCHEMA_VER`, `NUM_H`, `NUM_V`, `DIST_H`, `DIST_V`, `AXIS_DIR_H`, `AXIS_DIR_V`.
- Geometri & posisi: `BASE_PT_WCS`, `ELEVATION`, `EXT_LEN`, serta seluruh entitas `LINE` beserta koordinatnya.
- Skala & layer: `SCALE_DENOM`, `LAYER_GRID`, `LAYER_BUBBLE`, `LAYER_TEXT`.

### Mekanisme Preview
Setiap perubahan nilai pada field dialog `asgrid_edit_v2_2` memicu `fn-edit-update-preview`, yang memvalidasi input numerik secara langsung dan memanggil `asgrid:prev-render-grid` dengan parameter `geomExtLen` (terkunci dari `EXT_LEN`) dan `annoExtLen` (nilai baru) secara terpisah sehingga pengguna melihat posisi relatif bubble terhadap ujung garis grid secara akurat sebelum commit.

### Proses Transaksi 6-Langkah (`fn-edit-execute-transaction`)
- **STEP A — SNAPSHOT:** Membuka grup `UNDO` tunggal, mengambil snapshot mentah XRecord (`asgrid:meta-get-xrecord-snapshot`), merekam DXF seluruh anotasi lama (`BUBBLE` & `TEXT`), serta merekam koordinat seluruh garis `LINE` (`fn-edit-capture-line-coords`).
- **STEP B — CREATE:** Memastikan RegApp `ASGRID_TX_TMP` terdaftar, lalu menghasilkan anotasi baru menggunakan `asgrid:annotation-engine` dengan RegApp sementara `ASGRID_TX_TMP` agar tidak memicu konflik slot dengan anotasi lama.
- **STEP C — VERIFY:** Memverifikasi daftar `ename` anotasi sementara secara eksplisit (`fn-edit-verify-temp-annos`) terhadap jumlah ekspektasi `CIRCLE` dan `TEXT`, layer, style, serta slot unik.
- **STEP D — SWAP:** (D1) Menghapus anotasi lama; (D2) Mempromosikan XData anotasi baru dari `ASGRID_TX_TMP` menjadi `ASGRID_OBJ` (`fn-edit-promote-temp-to-final`).
- **STEP E — UPDATE METADATA & READ-BACK VERIFICATION:** Memperbarui XRecord grup via `asgrid:meta-update-group` (Replace-in-Dictionary), membaca ulang metadata, memvalidasi spesifikasi, dan membandingkan terhadap `newSpec`.
- **STEP F — FINAL VERIFY & COMMIT:** Memverifikasi bahwa seluruh koordinat garis `LINE` tetap utuh (`fn-edit-verify-lines-intact`) dan menjalankan audit penuh `asgrid:audit-group-entities`; jika lulus, transaksi di-commit dan grup `UNDO` ditutup.

### Mekanisme Rollback & Penanganan Kegagalan Transaksi
Jika terjadi kegagalan pada tahap mana pun (STEP B–F) atau interupsi pengguna/error runtime yang ditangkap `*error*`:
1. `fn-edit-rollback` menghapus seluruh anotasi baru/sementara yang sempat dibuat.
2. Jika anotasi lama sudah sempat dihapus (tahap D), anotasi lama direkonstruksi ulang dari snapshot DXF mentah (`fn-edit-recreate-from-dxf`).
3. Jika metadata sudah sempat diubah (tahap E), XRecord dipulihkan dari snapshot asli melalui `asgrid:meta-restore-xrecord`.
4. Blok `_.UNDO _End` ditutup dengan aman dan `CMDECHO` dikembalikan. Apabila terjadi kegagalan kritis pada pemulihan dictionary, program menampilkan peringatan eksplisit agar pengguna menjalankan `UNDO` (`Ctrl+Z`).

## F. Compatibility and Limitations

- **Kompatibilitas AutoCAD 2021:** Dikembangkan dan ditargetkan secara spesifik untuk AutoCAD 2021 (AutoLISP standar + DCL). Perilaku pada versi AutoCAD lain atau platform CAD pihak ketiga **belum terverifikasi**.
- **Schema V1.0 & Kompatibilitas Mundur (`ANNO_EXT_LEN`):** Metadata lama dari V2.1/V2.1.1/V2.1.2 yang belum memiliki field `ANNO_EXT_LEN` tetap didukung penuh; `asgrid:get-anno-ext-len` secara otomatis melakukan fallback ke `EXT_LEN`.
- **Batasan Mode 1:** `ASGRIDEDIT` hanya menyunting anotasi dan tidak mendukung penambahan/pengurangan sumbu, pengubahan spacing, pengubahan skala, atau pemindahan titik dasar grid.
- **Batasan Teknis AutoLISP yang Relevan:**
  - Operator `or` di AutoLISP mengembalikan boolean `T`/`nil`, bukan nilai string non-nil pertama — karena itu pencarian file DCL wajib menggunakan `setq` + `if` berurutan.
  - `(regapp appName)` mengembalikan `nil` apabila RegApp sudah terdaftar — selalu diperiksa via `(tblsearch "APPID" appName)`.
  - `(entmod ...)` pada `AcDbXrecord` menggabungkan resbuf — dihindari dengan *Replace-in-Dictionary*.
  - `(dictremove ...)` dapat menandai entitas lama sebagai *erased* — penghapusan dijaga dengan `(if (entget e) (entdel e))`.
  - `(ssget "_X" ...)` hanya memindai entitas top-level (tidak menembus definisi `BLOCK`).
- **Ambiguitas Ekstraksi Payload XRecord (Terdokumentasi):** Pada `asgrid:meta-extract-raw-payload`, jika sebuah XRecord non-standar tidak memiliki header `Duplicate Record Cloning Flag` dan elemen pertama payload-nya persis berupa `(280 . 0..5)`, struktur DXF tidak menyediakan pemisah eksplisit sehingga elemen tersebut akan diperlakukan sebagai header flag `280`. Untuk seluruh XRecord ASGRID (yang selalu diawali `(300 . "SCHEMA_VER")`) dan XRecord standar AutoCAD (yang selalu memiliki header `280`), ekstraksi bersifat deterministik.

## G. Testing Status

### 1. Pengujian yang Telah Dikonfirmasi Pengguna (AutoCAD 2021)
- **ASGRID V2.2.1 R3:** Pengguna mengonfirmasi bahwa **ASGRID V2.2.1 R3 berhasil dijalankan kembali di AutoCAD 2021** setelah perbaikan pencarian file DCL (mengatasi error runtime `bad argument type: stringp T` yang sebelumnya terjadi pada R2).
- **Baseline Terdahulu (Konteks Historis):** Pada fase sebelumnya, pengguna telah mengonfirmasi di AutoCAD 2021 bahwa `ASGRID` V2.2 Phase 1 (generate grid berulang) dan V2.2 Phase 2 `MODE 1 FIX` (`ASGRIDEDIT` Mode 1 pasca perbaikan XRecord Replace-in-Dictionary) berjalan dengan baik.

### 2. Pemeriksaan Statis yang Dilaporkan dalam Dokumen Teknis (R3)
Seluruh 8 pemeriksaan statis pada `revision3_technical_review.md` dinyatakan **LULUS**:
- 0 kemunculan pola `(or (findfile ...))` di seluruh `ASGRID_V2_2_1_R3.lsp`.
- 2 blok pencarian DCL berurutan (`setq` + `if`) terverifikasi pada `c:ASGRID` (baris 2969–2972) dan `c:ASGRIDEDIT` (baris 4113–4116) dengan urutan fallback `R3` → `R2` → `V2_2_1` → `V2_2`.
- Seluruh panggilan `load_dialog` (2 titik) terproteksi cabang `(if (null dclFile) ...)` sehingga hanya menerima path string valid.
- `ASGRID_V2_2_1_R3.dcl` identik *byte-per-byte* dengan DCL R2 (12.745 byte, SHA-256 `e0e5013365adb7990f9b83b851da80cc658797e05d7a5ef03651d571574f05d3`).
- Seluruh 89 `defun` identik; 0 perubahan pada metadata, XRecord, generator, transaksi, maupun `ASGRIDCHECK`.
- Keseimbangan tanda kurung dan string literal terverifikasi (`depth = 0`, `max_depth = 20`, 4.202 baris kode).

### 3. Skenario Checklist yang Belum Dikonfirmasi Pelaksanaannya
Meskipun pengguna telah mengonfirmasi R3 berhasil dijalankan kembali di AutoCAD 2021, **hasil eksekusi individual untuk seluruh skenario checklist R3 (T-01 s.d. T-10 pada `revision3_testing_checklist.md`) belum dilaporkan/dikonfirmasi satu per satu**, termasuk:
- Skenario fallback DCL saat `ASGRID_V2_2_1_R3.dcl` dipindahkan dan hanya DCL versi lama yang tersedia (T-08).
- Skenario error handling saat seluruh file DCL tidak tersedia (T-09) dan pembatalan dialog `Cancel` (T-10).
- Pengujian runtime skenario kegagalan/rollback spesifik hardening XRecord R1 & R2 secara langsung di AutoCAD 2021 (**belum terverifikasi secara runtime**).

## H. Version History

| Versi | Fokus & Alasan Revisi |
| :--- | :--- |
| **V2.2 (Phase 1 & Phase 2 MODE 1 FIX)** | Ekstraksi layanan stateless `asgrid:*`, perbaikan registrasi RegApp via `tblsearch "APPID"`, implementasi `ASGRIDEDIT` Mode 1, serta penggantian `entmod` pada XRecord dengan *Replace-in-Dictionary* setelah investigasi error `DIST_H_COUNT (3) != DIST_H (6)`. |
| **V2.2.1** | *Reliability hardening* terbatas pada `asgrid:meta-extract-raw-payload` (mempertahankan payload group code `280`) dan `asgrid:meta-restore-xrecord` (pengecekan `dictremove` dan jalur reattach). |
| **V2.2.1 R1** | Menindaklanjuti 4 temuan *independent code review*: pembatasan skip header `280` pada rentang `0..5` + dokumentasi ambiguitas DXF, 6 gerbang validasi snapshot pra-restore, verifikasi kesamaan payload pada reattach/fallback, dan status 3-keadaan (`'RESTORED`/`'NO_PREV_ENTRY`/`'RESTORE_FAILED`). |
| **V2.2.1 R2** | Menindaklanjuti 2 temuan review lanjutan pada `asgrid:meta-restore-xrecord`: menutup celah `curPayload = nil` yang sebelumnya dianggap lulus verifikasi, serta memeriksa return value pada seluruh 4/4 pemanggilan `dictremove`; diikuti sinkronisasi nama file `ASGRID_V2_2_1_R2.dcl`. |
| **V2.2.1 R3** | Memperbaiki bug runtime `bad argument type: stringp T` akibat penggunaan `(or (findfile ...))` pada `c:ASGRID` dan bug laten identik pada `c:ASGRIDEDIT` dengan menggantinya ke pencarian berurutan `setq` + `if`, menyelaraskan pesan error DCL, dan menyalin DCL R2 secara identik menjadi `ASGRID_V2_2_1_R3.dcl`. |

## I. Future Development

Rencana berikut dicatat sebagai arah pengembangan lanjutan dan **tidak diimplementasikan** pada rilis R3:
- **Penyempurnaan Diagnostik:** Peningkatan kedalaman pelaporan pada `ASGRIDCHECK` (tetap *read-only*) untuk membantu penelusuran anomali grup secara lebih cepat.
- **Peningkatan Dokumentasi:** Pemeliharaan konsistensi dokumen teknis, catatan rilis, dan hasil verifikasi runtime setiap kali pengujian checklist diselesaikan.
- **Evaluasi `ASGRIDEDIT` Mode 2 pada Fase Terpisah:** Evaluasi desain penyuntingan geometri grid (jumlah sumbu, spacing, dan ekstensi geometri) beserta strategi migrasi/kompatibilitasnya. **Mode 2 tetap ditunda dan berada di luar ruang lingkup R3.**
