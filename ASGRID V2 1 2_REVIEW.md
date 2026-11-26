# PROJECT REVIEW — ASGRID V2.1.2 (AutoLISP / AutoCAD 2021)

- **Tanggal Review:** 2026-11-26
- **Lokasi Project:** `d:/Taufik/File/CAD-ASGRID TAUFIK/ASGRID TAUFIK/`
- **Versi Terbaru yang Diaudit:** `ASGRID V2.1.2` (Quick Fix & Diagnostic Improvement)
- **Baseline Sebelumnya:** `ASGRID V2.1.1` (Stability & Metadata Hardening)
- **Target Lingkungan:** Autodesk AutoCAD 2021 (AutoLISP standar + DCL, Model Space, WCS, satuan milimeter)

---

## 1. Ringkasan Project

**ASGRID** adalah toolkit AutoLISP untuk **AutoCAD 2021** yang mengotomatisasi pembuatan garis as (grid) bangunan beserta bubble dan label penomoran pada Model Space (WCS, satuan milimeter), lengkap dengan fondasi metadata DWG dan alat diagnostik integritas data.

Kapabilitas utama toolkit saat ini mencakup:
- **Pembuatan Grid Otomatis (`ASGRID`):**
  - Garis as horizontal sejajar sumbu X dengan label angka (`1, 2, 3, ...`) berdasarkan daftar jarak individual sumbu Y.
  - Garis as vertikal sejajar sumbu Y dengan label huruf berlanjut (`A, B, C, ..., Z, AA, AB, ...`) berdasarkan daftar jarak individual sumbu X.
  - Skala anotasi dinamis (`1:N`) yang mengonversi tinggi teks cetak dan diameter bubble cetak (mm kertas) ke ukuran Model Space.
  - Antarmuka DCL 2-kolom dengan tabel interval terpaginasi (8 baris/halaman), peringatan proporsi bubble non-blocking di dialog, serta **Live Preview** skematis non-permanen (`image` tile + *Dense Mode* adaptif).
  - Isolasi standar gambar: layer `AS-GRID` (`CENTER`, warna `8`), `AS-BUBBLE` (warna `2`), `AS-TEXT` (warna `7`), dan Text Style khusus `ASGRID-ARIAL` (`arial.ttf`) tanpa mengubah `CLAYER`, `TEXTSTYLE`, `DIMSTYLE`, `UCS`, `INSUNITS`, maupun `LTSCALE` pengguna.
- **Metadata DWG Terverifikasi & Keamanan Transaksi:**
  - Penyimpanan Group Metadata pada `Named Object Dictionary` (`ASGRID_GROUPS`) sebagai `XRecord` per Group ID unik (`ASG-0001`, `ASG-0002`, ...) dengan `SCHEMA_VER = "1.0"`.
  - Penyimpanan identitas objek via `XData` (`ASGRID_OBJ`) pada setiap `LINE`, `CIRCLE`, dan `TEXT`.
  - *Hard Gate* pra-geometri (tulis → baca balik → validasi 24 key & konsistensi → *deep compare* `1e-6`) serta *isolated rollback* berbasis `entmakex` apabila terjadi kegagalan atau pembatalan (`ESC`).
- **Diagnostik Mendalam Read-Only (`ASGRIDCHECK`):**
  - Memeriksa integritas XRecord (tahan terhadap XRecord korup tanpa crash), kecocokan jumlah entitas aktual vs ekspektasi, kesesuaian tipe DXF vs XData `Role`, validitas rentang `AxisIdx`, validitas `EndTag` terhadap `BUBBLE_POS`, duplikasi slot identitas (`Role|AxisDir|AxisIdx|EndTag`), entitas yatim, metadata yatim, dan XData korup secara **100% READ-ONLY**.

Evolusi pengembangan project hingga saat ini terdiri dari **5 rilis berurutan**:
1. **V1.0** — Generator command-line interaktif (10 tahap prompt).
2. **V2.0** — Antarmuka dialog DCL + tabel pagination + Text Style terisolasi `ASGRID-ARIAL`.
3. **V2.1** — Dialog 2-kolom + Live Preview + fondasi metadata DWG + pemisahan `Geometry Engine` & `Annotation Engine`.
4. **V2.1.1** — *Hard Gate* metadata, *transaction safety* (`entmakex` + rollback terisolasi), validasi jumlah entitas & XData, pustaka stateless `asgrid:*`, dan `ASGRIDCHECK` versi awal.
5. **V2.1.2** — Pengerasan reader XRecord anti-crash (`numberp` + `_READ_ERRORS`), validasi konsistensi 24 key (`DIST_H_COUNT`/`DIST_V_COUNT`, `ELEVATION` vs `Z`), *deep diagnostics* pada `ASGRIDCHECK`, perbaikan UX DCL (`C. Scale && Annotation`, konsistensi default spacing `5000`, peringatan bubble kecil), serta info non-blocking `INSUNITS`.

---

## 2. Struktur Folder dan File

Project tersimpan di `d:/Taufik/File/CAD-ASGRID TAUFIK/ASGRID TAUFIK/` dan dikelompokkan dalam **5 folder rilis versi** dengan total **20 file eksisting** (5 `.lsp`, 4 `.dcl`, 4 `.png`, 7 `.md`) sebelum penambahan dokumen review ini. Tidak terdapat repositori Git (`.git`).

```text
CAD-ASGRID TAUFIK/
└── ASGRID TAUFIK/
    ├── ASGRID V2 1 2_REVIEW.md                   (Dokumen laporan review ini)
    ├── ASGRID V1.0/
    │   └── ASGRID_V1.lsp                         (17.223 B |   502 baris)
    ├── ASGRID V2.0/
    │   ├── ASGRID_V2.dcl                         ( 7.841 B |   213 baris)
    │   ├── ASGRID_V2.lsp                         (35.423 B |   983 baris)
    │   ├── DOKUMENTASI HASIL.png                 (99.368 B)
    │   └── DOKUMENTASI HASIL (2).png             (82.478 B)
    ├── ASGRID V2.1/
    │   ├── ASGRID_V2_1.dcl                       (10.242 B |   270 baris)
    │   ├── ASGRID_V2_1.lsp                       (65.252 B | 1.737 baris)
    │   ├── Dokumentasi asgrid v2.1.png           (160.191 B)
    │   └── Dokumentasi asgrid v2.1 (2).png       (145.171 B)
    ├── ASGRID V2.1.1/
    │   ├── ASGRID_V2_1_1.dcl                     (10.304 B |   271 baris)
    │   ├── ASGRID_V2_1_1.lsp                     (86.836 B | 2.315 baris)
    │   ├── PROJECT_REVIEW.md                     (27.980 B)
    │   ├── changelog_v2_1_1.md                   ( 4.934 B |    46 baris)
    │   ├── technical_review_v2_1_1.md            ( 7.189 B |    88 baris)
    │   └── testing_checklist_v2_1_1.md           ( 5.527 B |    49 baris)
    └── ASGRID V2.1.2/
        ├── ASGRID_V2_1_2.dcl                     (10.356 B |   271 baris)
        ├── ASGRID_V2_1_2.lsp                     (98.558 B | 2.563 baris)
        ├── changelog_v2_1_2.md                   ( 3.901 B |    39 baris)
        ├── technical_review_v2_1_2.md            ( 6.070 B |    52 baris)
        └── testing_checklist_v2_1_2.md           ( 5.230 B |    37 baris)
```

---

## 3. Fungsi Masing-Masing File

### A. Arsip Versi Terdahulu (`V1.0`, `V2.0`, `V2.1`, `V2.1.1`)
| Folder / File | Ukuran / Baris | Fungsi |
| :--- | :---: | :--- |
| `ASGRID V1.0/ASGRID_V1.lsp` | 17 KB / 502 baris | Baseline V1.0 berbasis command-line interaktif (tanpa DCL). Membuat grid, bubble, teks, linetype `CENTER`, dan 3 layer standar via `entmake`. |
| `ASGRID V2.0/ASGRID_V2.dcl` & `ASGRID_V2.lsp` | 7,8 KB / 213 B & 35 KB / 983 B | Rilis V2.0 dengan antarmuka DCL 1-kolom, tabel spacing terpaginasi, validasi terpusat, dan Text Style terisolasi `ASGRID-ARIAL`. |
| `ASGRID V2.0/DOKUMENTASI HASIL*.png` (2 file) | 99 KB & 82 KB | Bukti visual pengujian V2.0 di AutoCAD 2021 (dialog DCL & hasil render 4×4). |
| `ASGRID V2.1/ASGRID_V2_1.dcl` & `ASGRID_V2_1.lsp` | 10 KB / 270 B & 65 KB / 1.737 B | Rilis V2.1 dengan DCL 2-kolom + Live Preview (`vector_image`), fondasi metadata DWG (`ASGRID_GROUPS` + `ASGRID_OBJ`), dan pemisahan Geometry/Annotation Engine. |
| `ASGRID V2.1/Dokumentasi asgrid v2.1*.png` (2 file) | 160 KB & 145 KB | Bukti visual pengujian V2.1 di AutoCAD 2021 (dialog 2-kolom dengan Live Preview, `Next Group ID: ASG-0002`, dan hasil Model Space). |
| `ASGRID V2.1.1/ASGRID_V2_1_1.dcl` & `ASGRID_V2_1_1.lsp` | 10 KB / 271 B & 86 KB / 2.315 B | Baseline V2.1.1 (dipertahankan sebagai backup) yang memperkenalkan *Hard Gate* metadata, transaksi `entmakex` + rollback terisolasi, library `asgrid:*`, dan `ASGRIDCHECK` V1. |
| `ASGRID V2.1.1/PROJECT_REVIEW.md`, `changelog_v2_1_1.md`, `technical_review_v2_1_1.md`, `testing_checklist_v2_1_1.md` | 4 file `.md` | Dokumentasi review, changelog, audit teknis, dan daftar uji manual untuk rilis V2.1.1. |

### B. Paket Aktif Terbaru (`ASGRID V2.1.2/`)
| File | Ukuran / Baris | Fungsi |
| :--- | :---: | :--- |
| `ASGRID V2.1.2/ASGRID_V2_1_2.lsp` | 98 KB / 2.563 baris | **File program utama terbaru.** Berisi 15 fungsi pustaka stateless `asgrid:*`, command `c:ASGRID` (generator grid transaksional + Live Preview + Hard Gate 24 key + peringatan `INSUNITS` & proporsi bubble), serta command `c:ASGRIDCHECK` (*deep diagnostics* 100% read-only). |
| `ASGRID V2.1.2/ASGRID_V2_1_2.dcl` | 10 KB / 271 baris | **File UI dialog utama terbaru.** Definisi dialog `asgrid_v2_1_2` 2-kolom (Panel A–D input & pagination di kiri, Panel E Live Preview di kanan), dengan perbaikan escape `"C. Scale && Annotation"`. |
| `ASGRID V2.1.2/changelog_v2_1_2.md` | 3,9 KB / 39 baris | Ringkasan perubahan teknis dari V2.1.1 ke V2.1.2 (kategori A–E) dan jaminan kompatibilitas Schema `1.0`. |
| `ASGRID V2.1.2/technical_review_v2_1_2.md` | 6,0 KB / 52 baris | Hasil audit celah V2.1.1, evaluasi transaksi/rollback (*shared drawing resources*), dokumentasi keterbatasan `ssget "_X"`, dan tabel verifikasi statis V2.1.2. |
| `ASGRID V2.1.2/testing_checklist_v2_1_2.md` | 5,2 KB / 37 baris | Daftar skenario pengujian manual di AutoCAD 2021 mencakup DCL, spacing, `INSUNITS`, `ASGRIDCHECK` (termasuk simulasi `COPY` & XRecord korup), rollback, dan kompatibilitas lintas versi V2.1.1 → V2.1.2. |

---

## 4. Arsitektur Program

### A. Struktur 3 Lapisan pada `ASGRID_V2_1_2.lsp`
File `ASGRID_V2_1_2.lsp` bersifat **standalone monolitik** (tidak memanggil `(load ...)` terhadap file `.lsp` lain, hanya memuat `ASGRID_V2_1_2.dcl` via `findfile`), dengan pemisahan logika internal menjadi **3 lapisan tanpa variabel data global**:

1. **Lapisan 1 — Shared Stateless Library (`asgrid:*`, L31–L527):**  
   15 fungsi murni tanpa state global yang dipakai bersama oleh `c:ASGRID` dan `c:ASGRIDCHECK` (serta disiapkan sebagai API pembaca/validator untuk `ASGRID EDIT`).
2. **Lapisan 2 — Generator Transaksional (`c:ASGRID`, L534–L2217):**  
   Berisi 9 modul lokal (error handler/rollback, utilitas + cek `INSUNITS`, layer/linetype/font Arial, metadata Hard Gate, primitif `entmakex`, Geometry Engine & Annotation Engine, Live Preview Engine, pengelola DCL/pagination, dan validasi input terpusat).
3. **Lapisan 3 — Deep Diagnostics Read-Only (`c:ASGRIDCHECK`, L2234–L2559):**  
   Perintah audit independen tanpa satu pun operasi mutasi DWG, membaca seluruh XData *top-level* dan seluruh XRecord di NOD `ASGRID_GROUPS`.

### B. Diagram Alur Transaksi & Diagnostik (`V2.1.2`)

```text
[c:ASGRID]
   ├── Muat ASGRID_V2_1_2.dcl ("asgrid_v2_1_2") -> Init DEF_SPACING_H="4000", DEF_SPACING_V="5000"
   ├── Loop UI DCL (Modul 8) <──> Live Preview Non-Permanen (Modul 7) + Scale/Bubble Warning
   ├── Validasi Terpusat fn-validate-all (Modul 9) -> OK & getpoint WCS
   └── fn-execute-grid-creation:
         ├── fn-check-insunits-warning (info non-blocking bila INSUNITS != 4)
         ├── Mulai UNDO _Begin & txActive = T
         ├── Pre-checks (shared resources): ASGRID-ARIAL, regapp ASGRID_OBJ, CENTER, 3 Layer
         ├── Generate Unique Group ID -> fn-meta-build-spec (24 key) -> asgrid:meta-validate-spec
         ├── [HARD GATE A] fn-meta-save-group -> XRecord di NOD "ASGRID_GROUPS"
         ├── [HARD GATE B] asgrid:meta-read-group (safe type check + _READ_ERRORS)
         │                 -> asgrid:meta-validate-spec (24 key, COUNT, ELEVATION vs Z)
         │                 -> asgrid:meta-compare-specs (toleransi 1e-6)
         │                 (GAGAL -> fn-rollback-transaction & ABORT sebelum geometri dibuat)
         ├── [GEOMETRY ENGINE]   fn-geometry-engine(readBack)   via entmakex -> cek cntLine == expL
         ├── [ANNOTATION ENGINE] fn-annotation-engine(readBack) via entmakex -> cek cntB/cntT
         ├── [FINAL VERIFY]      fn-verify-tx-entities(groupId) -> cek XData & GroupID tiap ename
         │                       (GAGAL/ESC -> fn-rollback-transaction LIFO & hapus XRecord grup ini saja)
         └── [COMMIT] Reset state transaksi, UNDO _End, pulihkan CMDECHO, cetak ringkasan

[c:ASGRIDCHECK] (100% READ-ONLY)
   ├── Pindai top-level XData ASGRID_OBJ via ssget "_X" (kumpulkan dxfType, role, axisDir, axisIdx, endTag)
   ├── Untuk setiap Group ID di NOD "ASGRID_GROUPS":
   │     ├── asgrid:meta-read-group (tahan korup via _READ_ERRORS) -> asgrid:meta-validate-spec (24 key)
   │     ├── Audit entitas grup: count vs expected, DXF vs Role, AxisIdx vs NUM_H/NUM_V,
   │     │                       EndTag vs Role & BUBBLE_POS, duplikasi slot (Role|AxisDir|AxisIdx|EndTag)
   │     └── Deteksi metadata yatim (0 entitas)
   └── Laporkan entitas yatim (tanpa XRecord di NOD) & XData korup
```

### C. Skema Metadata DWG (`SCHEMA_VER = "1.0"`)
- **NOD `ASGRID_GROUPS` → XRecord per Group ID (`ASG-0001`, ...):** 24 key tervalidasi mencakup identitas (`SCHEMA_VER`, `GROUP_ID`, `MODULE`, `GENERATOR_VER`, `CREATED_AT`), geometri (`NUM_H`, `NUM_V`, `DIST_H_COUNT`, `DIST_V_COUNT`, `DIST_H_ITEM`..., `DIST_V_ITEM`..., `BASE_PT_WCS`, `ELEVATION`, `AXIS_DIR_H`, `AXIS_DIR_V`), serta anotasi & layer (`SCALE_DENOM`, `TEXT_H_PRINT`, `BUBBLE_DIA_PRINT`, `EXT_LEN`, `BUBBLE_POS`, `TEXT_STYLE`, `FONT_FILE`, `LAYER_GRID`, `LAYER_BUBBLE`, `LAYER_TEXT`).
- **XData `ASGRID_OBJ` per Entitas:** 6 field berurutan `(1000 GroupID)`, `(1000 Role)`, `(1000 AxisDir)`, `(1070 AxisIdx)`, `(1000 EndTag)`, `(1000 SchemaVer)`.

---

## 5. Modul yang Sudah Tersedia

### A. Inventaris Modul pada `ASGRID_V2_1_2.lsp`

| Kelompok / Modul | Baris | Fungsi / Komponen | Scope |
| :--- | :---: | :--- | :---: |
| **Shared Stateless Library** | L31–L527 | `asgrid:dict-name`, `asgrid:xdata-app`, `asgrid:valid-bubble-positions`, `asgrid:tol`, `asgrid:trim`, `asgrid:parse-pos-int`, `asgrid:parse-pos-real`, `asgrid:meta-get-root-dict`, `asgrid:meta-list-nod-ids`, `asgrid:parse-entity-xdata`, `asgrid:meta-list-all-ids`, `asgrid:meta-read-group` *(hardened)*, `asgrid:calc-expected-counts`, `asgrid:meta-validate-spec` *(24 key)*, `asgrid:meta-compare-specs` | Global (`asgrid:*`) |
| **Modul 1 — Error Handler & Rollback** | L625–L661 | `*error*` (tutup DCL, rollback transaksi aktif, tutup `UNDO`, pulihkan `CMDECHO`) | Lokal `c:ASGRID` |
| **Modul 2 — Utilitas & `INSUNITS`** | L663–L729 | `fn-index-to-alpha`, `fn-replace-nth`, `fn-resize-str-list`, `fn-pad-4`, `fn-get-timestamp`, `fn-check-insunits-warning` *(baru V2.1.2)* | Lokal `c:ASGRID` |
| **Modul 3 — Linetype, Layer & Arial** | L731–L887 | `fn-ensure-linetype-center`, `fn-ensure-layer`, `fn-find-arial-ttf`, `fn-ensure-arial-style` | Lokal `c:ASGRID` |
| **Modul 4 — Metadata & Rollback** | L889–L1095 | `fn-make-obj-xdata`, `fn-meta-generate-next-id`, `fn-meta-build-spec` *(+COUNT)*, `fn-meta-save-group`, `fn-rollback-transaction`, `fn-verify-tx-entities` | Lokal `c:ASGRID` |
| **Modul 5 — Primitif `entmakex`** | L1097–L1159 | `fn-draw-line`, `fn-draw-circle`, `fn-draw-text-mc` (pelacakan LIFO ke `txCreatedEnts`) | Lokal `c:ASGRID` |
| **Modul 6 — Engines & Coordinator** | L1161–L1549 | `fn-compute-cumulative`, `fn-geometry-engine`, `fn-annotation-engine`, `fn-execute-grid-creation` | Lokal `c:ASGRID` |
| **Modul 7 — Live Preview Engine** | L1551–L1802 | `fn-prev-draw-circle`, `fn-prev-draw-char`, `fn-prev-draw-string`, `fn-update-live-preview` | Lokal `c:ASGRID` |
| **Modul 8 — DCL UI & Pagination** | L1804–L1947 | `fn-refresh-h-table`, `fn-refresh-v-table`, `fn-save-h-slot`, `fn-save-v-slot`, `fn-flush-active-page`, `fn-sync-grid-counts` *(DEF_SPACING_V)*, `fn-update-scale-preview` *(+WARN bubble)* | Lokal `c:ASGRID` |
| **Modul 9 — Validasi Input** | L1949–L2090 | `fn-validate-all` | Lokal `c:ASGRID` |
| **Deep Diagnostics Read-Only** | L2220–L2559 | `c:ASGRIDCHECK` + helper lokal `fn-add-group-ent`, `fn-inc-orphan-role` | Global (`c:*`) |

### B. Ringkasan Perbandingan Kemampuan Antar Versi

| Kapabilitas | V1.0 | V2.0 | V2.1 | V2.1.1 | V2.1.2 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Grid H/V + Skala Cetak + Layer + `UNDO` | Ya | Ya | Ya | Ya | Ya |
| Dialog DCL + Pagination + Font `ASGRID-ARIAL` | Tidak | Ya | Ya | Ya | Ya |
| Live Preview 2-Kolom + Metadata DWG + Engine Terpisah | Tidak | Tidak | Ya | Ya | Ya |
| Hard Gate Metadata + `entmakex` Rollback + `asgrid:*` | Tidak | Tidak | Tidak | Ya | Ya |
| Anti-Crash XRecord Reader (`numberp` + `_READ_ERRORS`) | Tidak | Tidak | Tidak | Tidak | **Ya** |
| Validasi `DIST_*_COUNT` & `ELEVATION` vs `Z(BASE_PT_WCS)` | Tidak | Tidak | Tidak | Tidak | **Ya** |
| `ASGRIDCHECK` Deep Diagnostics (DXF, `AxisIdx`, `EndTag`, Duplikat Slot) | Tidak | Tidak | Tidak | Dasar | **Mendalam** |
| Perbaikan DCL `C. Scale && Annotation`, Default `5000`, Warning Bubble & `INSUNITS` | Tidak | Tidak | Tidak | Tidak | **Ya** |
| Fitur `ASGRID EDIT` | Tidak | Tidak | Tidak | Tidak | Belum |

---

## 6. Kondisi Implementasi Saat Ini

- **Perbaikan V2.1.2 sudah menyasar sebagian besar temuan audit V2.1.1:** Celah kritis pada `asgrid:meta-read-group` (konversi `float` tanpa `numberp`), validasi konsistensi `ELEVATION`/`DIST_*_COUNT`, kedalaman audit `ASGRIDCHECK` (DXF type, `AxisIdx`, `EndTag`, deteksi duplikasi `COPY`), konsistensi default spacing vertikal `"5000"`, peringatan proporsi bubble di dialog, dan info `INSUNITS` seluruhnya sudah terimplementasi dengan bersih dan retro-kompatibel dengan Schema `1.0`.
- **Kesenjangan utama saat ini adalah verifikasi runtime di AutoCAD 2021:** Baik **V2.1.1** maupun **V2.1.2** baru melewati pemeriksaan statis; bukti eksekusi langsung di AutoCAD 2021 terakhir kali tercatat pada **V2.1** (25 Nov 2026). Seluruh skenario pada `testing_checklist_v2_1_2.md` masih berstatus belum dijalankan (`[ ]`).
- **Modularisasi lintas-perintah baru selesai sebagian:** Lapisan pembaca/validator metadata (`asgrid:*`) sudah dapat dipakai lintas-command, namun engine pembangun (`fn-geometry-engine`, `fn-annotation-engine`, `fn-meta-save-group`, `fn-ensure-arial-style`, `fn-rollback-transaction`) masih berada di scope lokal `c:ASGRID`.

---

## 7. Potensi Masalah dan Bug

### A. Bug & Celah Teknis Aktual pada `ASGRID V2.1.2`

1. **Bug Escape `&` yang Terlewat pada Judul Dialog (`ASGRID_V2_1_2.dcl` L12)**
   - Baris `156` sudah diperbaiki menjadi `"C. Scale && Annotation"`, **namun baris `12` masih memakai `&` tunggal:**
     ```dcl
     label = "ASGRID V2.1.2 - Automatic Building Grid Generator (Hardened Metadata & Preview)";
     ```
   - Seperti yang sudah terbukti pada screenshot AutoCAD 2021 di V2.1 (`(Live Preview & Metadata)` dirender sebagai `(Live Preview  Metadata)`), DCL AutoCAD memperlakukan `&` tunggal pada title bar sebagai mnemonic sehingga simbol `&` hilang. Catatan `0 & tidak di-escape` pada `technical_review_v2_1_2.md` L47 terlewat memeriksa baris 12.

2. **Variabel Loop `foreach` Belum Dideklarasikan di Daftar Lokal (`ASGRID_V2_1_2.lsp`)**
   - Enam variabel loop `foreach` belum tercantum pada daftar variabel lokal `/` fungsi pembungkusnya:
     - `item` pada `fn-replace-nth` (L679, L682)
     - `s` pada `fn-update-live-preview` (L1648, L1679, L1686)
     - `pair` pada `fn-add-group-ent` (L2259, L2265) dan `fn-inc-orphan-role` (L2278, L2293)
     - `errItem` dan `entInfo` pada `c:ASGRIDCHECK` (L2234, L2380, L2405)
   - Meskipun AutoLISP men-scope nilai `foreach` selama iterasi, tidak mencantumkannya melanggar konvensi lokalisasi ketat project dan dapat memicu peringatan pada *Visual LISP IDE Check* atau meninggalkan simbol `nil` di atomlist global.

3. ***Dead Variables* & Batas Keterbacaan pada Live Preview (`ASGRID_V2_1_2.lsp` L1648–L1802)**
   - Variabel `pH` dan `pV` (L1665–L1666) masih dibaca dari `get_tile`, tetapi tidak pernah digunakan sama sekali dalam perhitungan render preview.
   - `fn-prev-draw-string` (L1624–L1646) belum menyesuaikan skala huruf terhadap jumlah karakter (`len`), sehingga label 2+ karakter (`10`, `28`, `AA`) berpotensi melebar keluar lingkaran bubble saat `bubRadPx` kecil (`5–6` px).

4. **Potensi Pemotongan Teks pada Tile `scale_preview` (`ASGRID_V2_1_2.dcl` L195–L198 & `.lsp` L1934–L1941)**
   - Tile `scale_preview` tidak memiliki properti `width` tetap sehingga lebarnya dihitung AutoCAD berdasarkan label default di `.dcl` (~63 karakter). Saat nilai skala besar berkombinasi dengan tag `"[WARN: Bubble <= Text!]"` (total bisa mencapai ~62–68 karakter), teks berisiko terpotong di sisi kanan pada pengaturan DPI Windows tertentu (perlu diverifikasi langsung saat uji visual di AutoCAD 2021).

5. **Pola `dictremove` Diikuti `entdel` & Pesan Abort Pre-Check (`ASGRID_V2_1_2.lsp` L1048–L1056, L1345–L1365)**
   - Pada `fn-rollback-transaction` (L1051–L1056), `dictremove` tetap diikuti pengecekan `(if (and txSavedXrec (entget txSavedXrec)) (entdel txSavedXrec))`. Karena `dictremove` sudah melepaskan/menghapus XRecord dan `entdel` bersifat *toggle* (undelete jika terpanggil ulang pada entitas erased), pola lebih defensif adalah menjadikan `entdel` sebagai cabang `else` hanya jika entry tidak ditemukan di `rootDict`.
   - Jika pre-check Arial (L1347) atau `regapp` (L1358) gagal sebelum metadata ditulis, `txAbortedByCode = T` membuat `*error*` (L653) mencetak `"dengan rollback penuh"` padahal belum ada transaksi yang di-rollback.

6. **Edge Case pada `asgrid:meta-read-group` & Pelaporan `c:ASGRIDCHECK`**
   - **Key duplikat di XRecord korup:** Jika XRecord korup memiliki dua entry dengan key yang sama (misal dua `(300 . "NUM_H")`), `(assoc ...)` pada `asgrid:meta-read-group` (L258–L276) hanya mengambil yang pertama tanpa mencatat error duplikasi key di `_READ_ERRORS`.
   - **Cakupan audit `ASGRIDCHECK`:** Pemeriksaan mendalam V2.1.2 memvalidasi struktur XData/DXF/slot, tetapi belum memverifikasi konsistensi geometris (misal jika entitas di-`MOVE`/`STRETCH` manual atau berada di Paper Space) dan pada laporan duplikasi slot (L2510–L2511) hanya mencetak 1 contoh slot `(car dupSlots)` tanpa menyebutkan daftar lengkap bila ada banyak slot duplikat.
   - **Penghitungan `issuesCnt`:** Jika satu grup memiliki 3 error metadata di `valErrs`, `issuesCnt` bertambah `+1` (L2383), sedangkan jika satu grup memiliki 3 jenis anomali entitas, `issuesCnt` bertambah `+3` (L2481–L2514).

7. **Kompleksitas `O(N²)` pada Konstruksi List dalam Loop (`append`)**
   - Pola `(setq res (append res (list item)))` di dalam loop masih digunakan di `fn-add-group-ent` (L2265–L2270), `fn-inc-orphan-role` (L2293–L2298), `asgrid:meta-read-group` (L228–L279), `asgrid:meta-list-all-ids` (L193), dan `fn-meta-save-group` (L990–L1000). Masih cepat untuk grid kecil–menengah, namun berisiko lambat pada DWG kompleks dengan banyak grup grid.

8. **Visual Linetype `CENTER` pada Skala Cetak Besar**
   - Keputusan V2.1.2 untuk tidak mengubah `LTSCALE` global pengguna sudah tepat demi keamanan gambar. Namun karena garis `AS-GRID` belum diberi entity linetype scale (DXF `48`) opsional atau panduan `LTSCALE`, pada skala `1:100`/`1:200` dengan `LTSCALE = 1` garis `CENTER` (pola ISO `50.8` mm) tampak nyaris solid di Model Space.

### B. Masalah Struktur Project & Skalabilitas

1. **Belum ada uji runtime AutoCAD 2021 untuk V2.1.1 dan V2.1.2** — Dua iterasi besar (hardening transaksi + deep diagnostics) masih berstatus *untested* di AutoCAD 2021 aktual.
2. **File monolitik terus membesar (2.563 baris pada `ASGRID_V2_1_2.lsp`)** — Engine inti (`fn-geometry-engine`, `fn-annotation-engine`, `fn-meta-save-group`, `fn-ensure-arial-style`, `fn-rollback-transaction`) masih terkunci di scope lokal `c:ASGRID`, menjadi hambatan langsung ketika mulai mengimplementasikan `ASGRID EDIT`.
3. **Konflik nama command lintas folder versi** — Kelima versi (`V1.0`–`V2.1.2`) sama-sama mendefinisikan `c:ASGRID`, sementara `V2.1.1` dan `V2.1.2` sama-sama mendefinisikan `c:ASGRIDCHECK`.
4. **Ketergantungan manual pada *Support File Search Path*** — `(findfile "ASGRID_V2_1_2.dcl")` akan gagal jika pengguna memuat `.lsp` dari folder yang belum didaftarkan di *AutoCAD Options*.
5. **Belum ada Git & pemisahan `src/` vs `archive/` vs `docs/`** — Folder versi lama (`V1.0`–`V2.1.1`) masih sejajar dengan versi aktif (`V2.1.2`), folder root bersarang ganda berspasi (`CAD-ASGRID TAUFIK/ASGRID TAUFIK/`), dan laporan review lama (`PROJECT_REVIEW.md`) tersimpan di dalam subfolder `ASGRID V2.1.1/`.

---

## 8. Rekomendasi Pengembangan Berikutnya

### Tahap 1 — Validasi Runtime AutoCAD 2021 & Pembersihan Mini (Sebelum V2.2)
1. **Jalankan seluruh skenario pada `testing_checklist_v2_1_2.md` di AutoCAD 2021** (khususnya uji `ASGRIDCHECK` setelah `ERASE`/`COPY`, simulasi XRecord korup, rollback `ESC`/`UNDO`, dan kompatibilitas DWG V2.1.1 → V2.1.2) lalu simpan bukti tangkapan layar/log di folder uji.
2. **Tutup 4 temuan minor V2.1.2 (bisa disatukan ke patch kecil atau awal V2.2):**
   - Escape `&` → `&&` pada baris `12` `ASGRID_V2_1_2.dcl` dan tetapkan `width` aman pada tile `scale_preview`.
   - Tambahkan variabel `foreach` yang terlewat (`item`, `s`, `pair`, `errItem`, `entInfo`) ke daftar lokal fungsi masing-masing.
   - Hapus *dead variables* `pH`/`pV` di `fn-update-live-preview`, rapikan cabang `else` untuk `entdel` di `fn-rollback-transaction`, serta bedakan pesan abort pre-check vs rollback transaksi.
   - Tambahkan deteksi duplikasi key di `asgrid:meta-read-group` dan ubah konstruksi list dalam loop `ASGRIDCHECK` dari `append` ke `cons` + `reverse` (`O(N)`).

### Tahap 2 — Modularisasi Toolkit & Tata Kelola Repositori (Fondasi V2.2)
1. **Inisialisasi Git** dan rapikan struktur direktori agar siap menampung banyak command toolkit:
   ```text
   ASGRID/
   ├── asgrid_loader.lsp      (Loader tunggal + deteksi path folder otomatis)
   ├── src/
   │   ├── asgrid_utils.lsp   (Parser, penomoran A..AA, helper list O(N), cek INSUNITS)
   │   ├── asgrid_style.lsp   (Layer standar, linetype CENTER, Text Style ASGRID-ARIAL)
   │   ├── asgrid_meta.lsp    (NOD/XRecord, XData, validasi 24 key, deep compare)
   │   ├── asgrid_engine.lsp  (Geometry Engine, Annotation Engine, entmakex & rollback)
   │   ├── asgrid_preview.lsp (Live Preview Engine untuk Create & Edit)
   │   ├── asgrid_create.lsp  (Command c:ASGRID + controller DCL)
   │   ├── asgrid_edit.lsp    (Command c:ASGRIDEDIT — tahap 3)
   │   └── asgrid_check.lsp   (Command c:ASGRIDCHECK)
   ├── dcl/
   │   └── asgrid_main.dcl
   ├── docs/
   │   ├── README.md
   │   ├── CHANGELOG.md
   │   └── METADATA_SCHEMA.md
   └── archive/               (V1.0, V2.0, V2.1, V2.1.1, V2.1.2 sebagai arsip read-only)
   ```
2. **Ekspos engine inti ke namespace `asgrid:*`** (`asgrid:ensure-arial-style`, `asgrid:ensure-layers`, `asgrid:meta-save-group`, `asgrid:geometry-engine`, `asgrid:annotation-engine`) tanpa global data state agar dipakai bersama oleh `ASGRID` dan `ASGRIDEDIT`.
3. **Sederhanakan pencarian DCL** melalui variabel path loader atau fallback pencarian di folder yang sama dengan file `.lsp` sebelum bergantung penuh pada *Support File Search Path*.

### Tahap 3 — Implementasi `ASGRID EDIT` (Rilis V2.2 / V3.0)
1. **Pemilihan grup fleksibel:** Pengguna dapat mengklik salah satu entitas grid (membaca `Group ID` dari XData `ASGRID_OBJ`) atau memilih dari daftar grup yang terdaftar di NOD `ASGRID_GROUPS`.
2. **Reuse Dialog & Live Preview:** Isi otomatis form DCL 2-kolom dari hasil `asgrid:meta-read-group` sehingga pengguna dapat mengubah jumlah sumbu, spacing individual, skala, ekstensi, atau posisi bubble dengan pratinjau real-time.
3. **Update Transaksional Aman:**
   - Cek status layer terkunci (*locked*) sebelum mengubah/menghapus entitas lama.
   - Validasi & bangun entitas baru dengan Group ID yang sama, verifikasi jumlah & XData, lalu perbarui XRecord dan hapus entitas lama hanya setelah verifikasi lulus (dengan rollback penuh jika gagal atau dibatalkan).

### Tahap 4 — Ekspansi Fitur Toolkit Produktivitas CAD
1. **Perintah utilitas pelengkap:** `ASGRIDDEL` (hapus 1 grup grid beserta XRecord-nya secara bersih), `ASGRIDDIM` (dimensi otomatis antar-as & total), serta opsi `CELTSCALE`/entity linetype scale (DXF `48`) pada garis as agar pola `CENTER` terlihat proporsional pada skala cetak `1:50`–`1:200` tanpa mengubah `LTSCALE` global.
2. **Pengayaan `ASGRIDCHECK`:** Tampilkan daftar lengkap (atau ringkasan terkelompok) seluruh slot duplikat, deteksi ruang gambar (*Model Space* vs *Paper Space*), dan opsi ringkasan per grup untuk DWG berukuran besar.
