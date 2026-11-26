# PROJECT REVIEW — ASGRID V2.2 (Phase 1 Foundation & Phase 2 `ASGRIDEDIT` Mode 1)

- **Tanggal Review:** 2026-11-26
- **Lokasi Project:** `d:/Taufik/File/CAD-ASGRID TAUFIK/ASGRID TAUFIK/`
- **Versi Terbaru yang Diaudit:** `ASGRID V2.2 (MODE 1)` (Phase 2 — Generator + `ASGRIDEDIT` Mode 1 + `ASGRIDCHECK`)
- **Baseline Terkait:** `ASGRID V2.2 (FIX BUG)` (Phase 1 Shared Services + Bug Fix RegApp `APPID`) dan `ASGRID V2.1.2`
- **Target Lingkungan:** Autodesk AutoCAD 2021 (AutoLISP + DCL, Model Space, WCS, satuan milimeter)

---

## 1. Ringkasan Project

**ASGRID** adalah toolkit AutoLISP untuk **AutoCAD 2021** yang mengotomatisasi pembuatan, pemeriksaan integritas, dan penyuntingan anotasi garis as (grid) bangunan pada Model Space (WCS, satuan milimeter) berbasis metadata DWG terstruktur.

Pada rilis **ASGRID V2.2**, project mengalami lompatan arsitektural penting dari sekadar *grid generator* menjadi **toolkit 3-perintah** yang berbagi satu pustaka layanan stateless (`asgrid:*`):
1. **`ASGRID` (Grid Generator):** Membuat garis as horizontal (`1, 2, 3, ...`) dan vertikal (`A, B, C, ..., AA, AB, ...`) beserta bubble & teks pada layer standar (`AS-GRID`, `AS-BUBBLE`, `AS-TEXT`), Text Style terisolasi `ASGRID-ARIAL` (`arial.ttf`), dialog DCL 2-kolom berpaginasi dengan Live Preview, penyimpanan metadata DWG (`ASGRID_GROUPS` NOD/XRecord + `ASGRID_OBJ` XData) dengan *Hard Gate* baca-balik, serta *isolated rollback* berbasis `entmakex`.
2. **`ASGRIDEDIT` (Baru — Mode 1 Annotation Editor):** Menyunting 5 parameter anotasi grid eksisting (`BUBBLE_DIA_PRINT`, `TEXT_H_PRINT`, `TEXT_STYLE`, `BUBBLE_POS`, dan `ANNO_EXT_LEN`) secara transaksional (6 langkah dengan *Temporary Transaction Identity* `ASGRID_TX_TMP`) **tanpa mengubah geometri garis as (`LINE`)**, koordinat, jumlah sumbu, spacing, `SCALE_DENOM`, maupun `EXT_LEN`.
3. **`ASGRIDCHECK` (Deep Diagnostics — 100% READ-ONLY):** Mengaudit kesehatan metadata XRecord dan entitas seluruh grup grid di dalam DWG (jumlah entitas, DXF type vs Role, rentang `AxisIdx`, kesesuaian `EndTag` vs `BUBBLE_POS`, duplikasi slot, entitas yatim, metadata yatim, dan XData korup) tanpa melakukan modifikasi apa pun.

Evolusi lengkap project hingga 26 November 2026 mencakup **7 iterasi folder**:
- **V1.0** → Command-line generator dasar.
- **V2.0** → Dialog DCL + pagination + Text Style `ASGRID-ARIAL`.
- **V2.1** → Dialog 2-kolom + Live Preview + fondasi metadata DWG + pemisahan Geometry/Annotation Engine.
- **V2.1.1** → *Hard Gate* metadata, transaksi `entmakex` + rollback terisolasi, library `asgrid:*` awal, dan `ASGRIDCHECK`.
- **V2.1.2** → Pengerasan reader XRecord anti-crash (`numberp` + `_READ_ERRORS`), validasi 24 key (`DIST_*_COUNT`, `ELEVATION` vs `Z`), *deep diagnostics* `ASGRIDCHECK`, dan perbaikan DCL/UX.
- **V2.2 (FIX BUG) / Phase 1** → Refaktorisasi **36 shared stateless services (`asgrid:*`)**, *decoupled Annotation Engine*, dukungan field opsional `ANNO_EXT_LEN` & `meta-update-group`/snapshot, *dual-extension Live Preview*, *Shared Group Audit Service*, serta **perbaikan bug nyata AutoCAD 2021** pada registrasi RegApp `ASGRID_OBJ` (`tblsearch "APPID"`).
- **V2.2 (MODE 1) / Phase 2** → Penambahan perintah **`c:ASGRIDEDIT`** (Mode 1), dialog **`asgrid_edit_v2_2`**, validasi ketat Text Style (`asgrid:validate-text-style`), serta transaksi 6-langkah menggunakan RegApp sementara `ASGRID_TX_TMP` dengan rollback & recovery penuh (total **44 fungsi `asgrid:*`** + **3 command**).

---

## 2. Struktur Folder dan File

Project tersimpan di `d:/Taufik/File/CAD-ASGRID TAUFIK/ASGRID TAUFIK/` dan terdiri dari **7 subfolder rilis** dengan total **31 file eksisting** (7 `.lsp`, 6 `.dcl`, 4 `.png`, 14 `.md`) sebelum pembuatan dokumen laporan ini. Tidak terdapat repositori Git (`.git`).

```text
CAD-ASGRID TAUFIK/
└── ASGRID TAUFIK/
    ├── ASGRID V2_2_REVIEW.md                             (Dokumen laporan review ini)
    ├── ASGRID V1.0/
    │   └── ASGRID_V1.lsp                                 ( 17.223 B |   502 baris)
    ├── ASGRID V2.0/
    │   ├── ASGRID_V2.dcl                                 (  7.841 B |   213 baris)
    │   ├── ASGRID_V2.lsp                                 ( 35.423 B |   983 baris)
    │   ├── DOKUMENTASI HASIL.png                         ( 99.368 B)
    │   └── DOKUMENTASI HASIL (2).png                     ( 82.478 B)
    ├── ASGRID V2.1/
    │   ├── ASGRID_V2_1.dcl                               ( 10.242 B |   270 baris)
    │   ├── ASGRID_V2_1.lsp                               ( 65.252 B | 1.737 baris)
    │   ├── Dokumentasi asgrid v2.1.png                   (160.191 B)
    │   └── Dokumentasi asgrid v2.1 (2).png               (145.171 B)
    ├── ASGRID V2.1.1/
    │   ├── ASGRID_V2_1_1.dcl                             ( 10.304 B |   271 baris)
    │   ├── ASGRID_V2_1_1.lsp                             ( 86.836 B | 2.315 baris)
    │   ├── PROJECT_REVIEW.md                             ( 27.980 B)
    │   ├── changelog_v2_1_1.md                           (  4.934 B |    46 baris)
    │   ├── technical_review_v2_1_1.md                    (  7.189 B |    88 baris)
    │   └── testing_checklist_v2_1_1.md                   (  5.527 B |    49 baris)
    ├── ASGRID V2.1.2/
    │   ├── ASGRID V2 1 2_REVIEW.md                       ( 28.091 B)
    │   ├── ASGRID_V2_1_2.dcl                             ( 10.356 B |   271 baris)
    │   ├── ASGRID_V2_1_2.lsp                             ( 98.558 B | 2.563 baris)
    │   ├── changelog_v2_1_2.md                           (  3.901 B |    39 baris)
    │   ├── technical_review_v2_1_2.md                    (  6.070 B |    52 baris)
    │   └── testing_checklist_v2_1_2.md                   (  5.230 B |    37 baris)
    ├── ASGRID V2.2 (FIX BUG)/
    │   ├── ASGRID_V2_2.dcl                               ( 10.292 B |   270 baris)
    │   ├── ASGRID_V2_2.lsp                               (103.503 B | 2.690 baris)
    │   ├── foundation_changelog.md                       (  5.338 B |    50 baris)
    │   ├── foundation_technical_review.md                (  5.472 B |    50 baris)
    │   └── foundation_testing_checklist.md               (  4.709 B |    73 baris)
    └── ASGRID V2.2 (MODE 1)/
        ├── ASGRID_V2_2.dcl                               ( 12.745 B |   360 baris)
        ├── ASGRID_V2_2.lsp                               (145.772 B | 3.694 baris)
        ├── phase2_changelog.md                           (  3.585 B |    36 baris)
        ├── phase2_technical_review.md                    (  4.601 B |    47 baris)
        └── phase2_testing_checklist.md                   (  5.133 B |    44 baris)
```

---

## 3. Fungsi Masing-Masing File

### A. Arsip Versi Baseline (`V1.0`, `V2.0`, `V2.1`, `V2.1.1`, `V2.1.2`)
| Folder | File Utama | Peran Historis |
| :--- | :--- | :--- |
| `ASGRID V1.0/` | `ASGRID_V1.lsp` (502 B) | Generator command-line murni (10 prompt, tanpa DCL). |
| `ASGRID V2.0/` | `ASGRID_V2.lsp` (983 B), `ASGRID_V2.dcl`, 2 `.png` | DCL 1-kolom + pagination + Text Style `ASGRID-ARIAL` + bukti uji AutoCAD 2021. |
| `ASGRID V2.1/` | `ASGRID_V2_1.lsp` (1.737 B), `ASGRID_V2_1.dcl`, 2 `.png` | DCL 2-kolom + Live Preview + fondasi metadata DWG (`ASGRID_GROUPS`, `ASGRID_OBJ`) + bukti uji AutoCAD 2021. |
| `ASGRID V2.1.1/` | `ASGRID_V2_1_1.lsp` (2.315 B), `.dcl`, 4 `.md` | Penguatan *Hard Gate* metadata, `entmakex` rollback terisolasi, `ASGRIDCHECK` awal, dan dokumen review V2.1.1. |
| `ASGRID V2.1.2/` | `ASGRID_V2_1_2.lsp` (2.563 B), `.dcl`, 4 `.md` | Pengerasan reader XRecord (`numberp`), validasi 24 key, *deep diagnostics* `ASGRIDCHECK`, perbaikan DCL/UX, dan laporan `ASGRID V2 1 2_REVIEW.md`. |

### B. Paket V2.2 Phase 1 (`ASGRID V2.2 (FIX BUG)/`)
| File | Ukuran / Baris | Fungsi |
| :--- | :---: | :--- |
| `ASGRID_V2_2.lsp` | 103 KB / 2.690 baris | Refaktorisasi Phase 1 menjadi 36 fungsi *Shared Stateless Services* (`asgrid:*`) + `c:ASGRID` + `c:ASGRIDCHECK` (belum ada `c:ASGRIDEDIT`), dilengkapi **perbaikan bug RegApp `APPID`** (`tblsearch "APPID"` sebelum `regapp`) agar generate grid ke-2 dst. pada DWG yang sama berhasil di AutoCAD 2021. |
| `ASGRID_V2_2.dcl` | 10 KB / 270 baris | Definisi tunggal dialog generator `asgrid_v2_2` (sudah menghapus `&` di title bar dan mempertahankan `"C. Scale && Annotation"`). |
| `foundation_changelog.md` | 5,3 KB / 50 baris | Catatan ekstraksi shared services Phase 1, field `ANNO_EXT_LEN`, dan dokumentasi bug fix RegApp `ASGRID_OBJ`. |
| `foundation_technical_review.md` | 5,5 KB / 50 baris | Inventaris 36 shared services, evaluasi keamanan rollback & `entmod` XRecord, hasil audit statis, dan analisis teknis bug `regapp`. |
| `foundation_testing_checklist.md` | 4,7 KB / 73 baris | Checklist uji regresi Phase 1 dan tabel 6 skenario regresi bug fix RegApp `ASGRID_OBJ`. |

### C. Paket Aktif Terbaru — V2.2 Phase 2 (`ASGRID V2.2 (MODE 1)/`)
| File | Ukuran / Baris | Fungsi |
| :--- | :---: | :--- |
| `ASGRID_V2_2.lsp` | 145 KB / 3.694 baris | **File kode utama terbaru.** Menggabungkan seluruh fondasi Phase 1 + bug fix RegApp dengan 8 shared service baru (total **44 fungsi `asgrid:*`**) dan **3 perintah**: `c:ASGRID`, `c:ASGRIDCHECK`, dan **`c:ASGRIDEDIT` (Mode 1 — Annotation Editor)**. |
| `ASGRID_V2_2.dcl` | 12,7 KB / 360 baris | **File DCL utama terbaru.** Memuat 2 definisi dialog: `asgrid_v2_2` (generator) dan **`asgrid_edit_v2_2`** (*ASGRID V2.2 - Annotation Editor* dengan Panel A Read-Only, Panel B 5 parameter editable, Panel C Live Preview dual-extension, serta `errtile` + `ok_cancel`). |
| `phase2_changelog.md` | 3,6 KB / 36 baris | Ringkasan perubahan Phase 2: `ASGRIDEDIT` Mode 1, dialog `asgrid_edit_v2_2`, validasi Text Style ketat, dan transaksi 6-langkah `ASGRID_TX_TMP`. |
| `phase2_technical_review.md` | 4,6 KB / 47 baris | Analisis pemakaian ulang shared services, mekanisme *Temporary Transaction Identity* (`ASGRID_TX_TMP`), strategi rollback + recovery, dan tabel audit statis. |
| `phase2_testing_checklist.md` | 5,1 KB / 44 baris | Daftar uji manual 5 kategori (A–E) untuk `ASGRIDEDIT` Mode 1 di AutoCAD 2021 (seleksi, edit 5 parameter, *geometry preservation* `LINE`, rollback/UNDO, dan kompatibilitas grid V2.1.2 → V2.2). |

---

## 4. Arsitektur Program

### A. Pola Arsitektur 4 Lapisan pada `ASGRID V2.2 (MODE 1)/ASGRID_V2_2.lsp`
Meskipun seluruh kode masih dikemas dalam 1 file `.lsp` standalone (3.694 baris) + 1 file `.dcl` (360 baris), desain internalnya telah dipisahkan secara tegas menjadi **4 blok fungsional tanpa variabel data global (*zero global state*)**:

1. **Shared Stateless Service Layer (`asgrid:*` — 44 fungsi, L27–L1465):**
   - Section 1: Konstanta, RegApp helper (`asgrid:ensure-regapp`), parser ketat, penomoran `A..AA`, koordinat kumulatif, timestamp, dan cek `INSUNITS`.
   - Section 2: Font & Text Style Service (`asgrid:find-font-file`, `asgrid:list-drawing-styles`, `asgrid:style-is-annotative`, `asgrid:validate-text-style`, `asgrid:find-arial-ttf`, `asgrid:ensure-arial-style`).
   - Section 3: Metadata, XData & XRecord Service (mendukung `ASGRID_OBJ` & `ASGRID_TX_TMP`, `ANNO_EXT_LEN` opsional dengan fallback `EXT_LEN`, `meta-build-xrecord-payload`, `meta-read-group`, `meta-get-xrecord-snapshot`, `meta-update-group` via `entmod`, `meta-restore-xrecord`, validator 24+ key, dan *deep compare* `1e-6`).
   - Section 4: Decoupled Annotation Engine (`asgrid:draw-circle`, `asgrid:draw-text-mc`, `asgrid:annotation-engine` dengan dukungan `_XDATA_APP_OVERRIDE` dan return eksplisit `(list createdEnts cntBubble cntText)`).
   - Section 5: Dual-Extension Live Preview Service (`asgrid:prev-render-grid` dengan `geomExtLen` dan `annoExtLen` terpisah).
   - Section 6: Shared Group Audit Service (`asgrid:audit-group-entities`, 100% READ-ONLY).
2. **Command `c:ASGRID` (L1472–L2588):** Generator grid transaksional yang menggunakan shared services untuk font, metadata, anotasi, dan preview, sementara *Geometry Engine* (`fn-geometry-engine`), `fn-meta-save-group`, dan controller dialog pagination tetap lokal.
3. **Command `c:ASGRIDCHECK` (L2595–L2821):** Diagnostik 100% READ-ONLY yang memanggil `asgrid:audit-group-entities` untuk setiap grup di NOD `ASGRID_GROUPS` dan melaporkan entitas yatim / XData korup.
4. **Command `c:ASGRIDEDIT` (L2835–L3689):** Editor anotasi Mode 1 berbasis transaksi 6-langkah dengan *Pre-Edit Integrity Gate* dan *Temporary Transaction Identity* (`ASGRID_TX_TMP`).

### B. Alur Transaksi 6-Langkah pada `ASGRIDEDIT` (Mode 1)

```text
[c:ASGRIDEDIT]
   ├── (1) Pre-Edit Gate (READ-ONLY): entsel -> parse ASGRID_OBJ -> baca & validasi NOD XRecord
   │       -> asgrid:audit-group-entities (wajib IS_HEALTHY = T; gagal -> abort sebelum dialog)
   ├── (2) Dialog asgrid_edit_v2_2: isi 5 parameter dari oldSpec (bukan default generator)
   │       <──> Live Preview (geomExtLen = EXT_LEN terkunci, annoExtLen dinamis)
   │       <──> Live validasi Text Style (asgrid:validate-text-style) & peringatan bubble/extension
   └── (3) fn-edit-execute-transaction (dalam 1 UNDO Group):
             ├── Pastikan RegApp ASGRID_OBJ & ASGRID_TX_TMP via asgrid:ensure-regapp
             ├── [STEP A - SNAPSHOT]  Rekam oldXrecSnap, oldAnnoSnapshots (DXF+XData), oldLineSnapCoords (10/11)
             ├── [STEP B - CREATE]    asgrid:annotation-engine(tempSpec) dengan _XDATA_APP_OVERRIDE="ASGRID_TX_TMP"
             │                        -> Lacak eksplisit ke txNewAnnoEnts; cek cntB == expB & cntT == expT
             ├── [STEP C - VERIFY]    fn-edit-verify-temp-annos pada txNewAnnoEnts (DXF, Style, AxisIdx, EndTag, 0 dup)
             ├── [STEP D - SWAP]      D1: entdel seluruh oldAnnoEnts (catat ke txDeletedOldEnts)
             │                        D2: fn-edit-promote-temp-to-final via 1 entmod per entitas:
             │                            hapus XData ASGRID_TX_TMP + pasang XData final ASGRID_OBJ
             ├── [STEP E - METADATA]  asgrid:meta-update-group (entmod XRecord, pertahankan Handle & Ownership)
             │                        -> baca balik -> validate-spec -> meta-compare-specs (1e-6)
             ├── [STEP F - AUDIT]     asgrid:audit-group-entities + fn-edit-verify-lines-intact (10/11 tol 1e-6)
             │                        (GAGAL di tahap mana pun -> fn-edit-rollback: hapus baru, undelete/recreate lama,
             │                         restore XRecord, audit ulang pasca-rollback, beri warning UNDO bila parsial)
             └── [COMMIT]             Reset txActive, tutup UNDO _End, pulihkan CMDECHO, cetak ringkasan before -> after
```

### C. Evolusi Skema Metadata DWG (`SCHEMA_VER = "1.0"`, Retro-Compatible)
- **Key wajib (24 key — sama dengan V2.1.2):** `SCHEMA_VER`, `GROUP_ID`, `MODULE`, `GENERATOR_VER`, `CREATED_AT`, `NUM_H`, `NUM_V`, `DIST_H_COUNT`, `DIST_V_COUNT`, `DIST_H`, `DIST_V`, `BASE_PT_WCS`, `ELEVATION`, `AXIS_DIR_H`, `AXIS_DIR_V`, `SCALE_DENOM`, `TEXT_H_PRINT`, `BUBBLE_DIA_PRINT`, `EXT_LEN`, `BUBBLE_POS`, `TEXT_STYLE`, `FONT_FILE`, `LAYER_GRID`, `LAYER_BUBBLE`, `LAYER_TEXT`.
- **Key opsional baru V2.2:**
  - `ANNO_EXT_LEN` (DXF `40`): panjang perpanjangan khusus anotasi (mm Model Space); pada grid baru `ASGRID` V2.2 diinisialisasi sama dengan `EXT_LEN`, sedangkan grid lama V2.1/V2.1.1/V2.1.2 otomatis fallback ke `EXT_LEN` via `asgrid:get-anno-ext-len`.
  - `UPDATED_AT` (DXF `1`): timestamp pembaruan terakhir oleh `ASGRIDEDIT`.
- **RegApp XData:**
  - `ASGRID_OBJ` — identitas permanen 6-field `(GroupID, Role, AxisDir, AxisIdx, EndTag, SchemaVer)`.
  - `ASGRID_TX_TMP` — identitas transaksi sementara selama STEP B–D1 pada `ASGRIDEDIT` agar tidak terdeteksi sebagai duplikasi slot selama fase transisi.

---

## 5. Modul yang Sudah Tersedia

### A. Inventaris Lengkap Modul pada `ASGRID V2.2 (MODE 1)/ASGRID_V2_2.lsp`

| Bagian / Modul | Baris | Daftar Fungsi Utama | Scope |
| :--- | :---: | :--- | :---: |
| **Section 1 — Core Constants & Utilities** | L27–L144 | `dict-name`, `xdata-app`, `xdata-tmp-app`, `ensure-regapp`, `schema-ver`, `valid-bubble-positions`, `tol`, `trim`, `parse-pos-int`, `parse-pos-real`, `index-to-alpha`, `compute-cumulative`, `get-timestamp`, `check-insunits-warning` (14 fungsi) | Global (`asgrid:*`) |
| **Section 2 — Font & Text Style Service** | L152–L368 | `find-font-file`, `list-drawing-styles`, `style-is-annotative`, `validate-text-style`, `find-arial-ttf`, `ensure-arial-style` (6 fungsi) | Global (`asgrid:*`) |
| **Section 3 — Metadata & XRecord Service** | L376–L944 | `make-obj-xdata-for-app`, `make-obj-xdata`, `get-anno-ext-len`, `meta-get-root-dict`, `meta-list-nod-ids`, `parse-entity-xdata-for-app`, `parse-entity-xdata`, `meta-list-all-ids`, `meta-build-xrecord-payload`, `meta-read-group`, `meta-get-xrecord-snapshot`, `meta-restore-xrecord`, `meta-update-group`, `calc-expected-counts`, `meta-validate-spec`, `meta-compare-specs` (16 fungsi) | Global (`asgrid:*`) |
| **Section 4 — Shared Annotation Engine** | L952–L1092 | `draw-circle`, `draw-text-mc`, `annotation-engine` (3 fungsi) | Global (`asgrid:*`) |
| **Section 5 — Shared Live Preview** | L1099–L1316 | `prev-draw-circle`, `prev-draw-char`, `prev-draw-string`, `prev-render-grid` (4 fungsi) | Global (`asgrid:*`) |
| **Section 6 — Shared Group Audit** | L1325–L1465 | `audit-group-entities` (1 fungsi, READ-ONLY) | Global (`asgrid:*`) |
| **Command `c:ASGRID`** | L1472–L2588 | `*error*`, `fn-replace-nth`, `fn-resize-str-list`, `fn-pad-4`, `fn-ensure-linetype-center`, `fn-ensure-layer`, `fn-meta-generate-next-id`, `fn-meta-build-spec`, `fn-meta-save-group`, `fn-rollback-transaction`, `fn-verify-tx-entities`, `fn-draw-line`, `fn-geometry-engine`, `fn-execute-grid-creation`, `fn-update-live-preview`, `fn-refresh-h/v-table`, `fn-save-h/v-slot`, `fn-flush-active-page`, `fn-sync-grid-counts`, `fn-update-scale-preview`, `fn-validate-all` | Global (`c:ASGRID`) + 22 helper lokal |
| **Command `c:ASGRIDCHECK`** | L2595–L2821 | `*error*`, `fn-inc-orphan-role` + laporan deep diagnostics berbasis `asgrid:audit-group-entities` | Global (`c:ASGRIDCHECK`) + 2 helper lokal |
| **Command `c:ASGRIDEDIT`** | L2835–L3689 | `*error*`, `fn-edit-select-and-validate`, `fn-edit-update-preview`, `fn-edit-validate-dialog`, `fn-edit-capture-line-coords`, `fn-edit-verify-lines-intact`, `fn-edit-verify-temp-annos`, `fn-edit-promote-temp-to-final`, `fn-edit-recreate-from-dxf`, `fn-edit-rollback`, `fn-edit-build-new-spec`, `fn-edit-execute-transaction` | Global (`c:ASGRIDEDIT`) + 12 helper lokal |
| **UI DCL (`ASGRID_V2_2.dcl`)** | L1–L360 | Dialog 1: `asgrid_v2_2` (Generator) & Dialog 2: `asgrid_edit_v2_2` (Annotation Editor Mode 1) | DCL |

### B. Perbandingan Progres Fitur (`V2.1.2` → `V2.2 Phase 1` → `V2.2 Phase 2`)

| Kapabilitas | V2.1.2 | V2.2 Phase 1 (`FIX BUG`) | V2.2 Phase 2 (`MODE 1`) |
| :--- | :---: | :---: | :---: |
| Jumlah Shared Services (`asgrid:*`) | 15 | 36 | **44** |
| Jumlah Perintah AutoCAD | 2 (`ASGRID`, `ASGRIDCHECK`) | 2 (`ASGRID`, `ASGRIDCHECK`) | **3 (`ASGRID`, `ASGRIDEDIT`, `ASGRIDCHECK`)** |
| Fix Bug RegApp `APPID` saat Generate ke-2+ | Belum (bug) | **Sudah** | **Sudah** |
| Escape `&` Bersih di Seluruh DCL (termasuk title bar) | Sebagian (L12 terlewat) | **Ya** | **Ya** |
| Field Opsional `ANNO_EXT_LEN` & `meta-update-group` | Tidak | **Ya** | **Ya** |
| Live Preview Dual Extension (`geomExtLen` vs `annoExtLen`) | Tidak | **Ya** | **Ya** |
| `ASGRIDEDIT` Mode 1 (Edit 5 Parameter Anotasi, `LINE` Utuh) | Tidak | Tidak | **Ya** |
| Validasi Text Style Ketat (Height=0, Non-Annotative, Non-Xref) | Tidak | Tidak | **Ya** |
| Transaksi 6-Langkah `ASGRID_TX_TMP` + Rollback/Recovery | Tidak | Tidak | **Ya** |
| `ASGRIDEDIT` Mode 2 (Edit Geometri/Spacing/Jumlah Sumbu) | Tidak | Tidak | Belum |

---

## 6. Kondisi Implementasi Saat Ini

- **Phase 1 (`ASGRID V2.2 (FIX BUG)`) sudah melalui uji lapangan di AutoCAD 2021** — Hal ini dibuktikan oleh ditemukannya bug nyata `regapp` di AutoCAD 2021 saat generate grid ke-2 pada DWG yang sama (yang kemudian diperbaiki di `FIX BUG` dan dibawa ke `MODE 1`) serta catatan di `phase2_technical_review.md` L3.
- **Phase 2 (`ASGRID V2.2 (MODE 1)`) sudah selesai diimplementasikan dan lulus audit statis, namun belum dijalankan langsung di AutoCAD 2021:** Seluruh item uji pada `phase2_testing_checklist.md` (Kategori A–E) masih belum dicentang (`[ ]`).
- **Arsitektur layanan bersama telah terbentuk sangat baik:** 44 fungsi `asgrid:*` sudah memisahkan kontrak data, validasi, anotasi, preview, dan audit grup, meskipun semuanya masih berada di dalam satu file tunggal (3.694 baris) dan `fn-geometry-engine` belum diekstrak ke `asgrid:*` (baru akan dibutuhkan saat masuk Mode 2 Geometry Edit).
- **Perbaikan bug dari review V2.1.2 yang sudah beres di V2.2:**
  - Bug `&` pada title bar DCL sudah hilang (karena judul diubah menjadi `"ASGRID V2.2 - Automatic Building Grid Generator"` dan panel C memakai `"C. Scale && Annotation"`).
  - *Dead variables* `pH`/`pV` pada `fn-update-live-preview` sudah dihapus.
  - Bug RegApp `ASGRID_OBJ` pada generate ke-2+ (yang sebelumnya tersembunyi di V2.1.1/V2.1.2 karena belum diuji runtime) sudah teridentifikasi dan diperbaiki.

---

## 7. Potensi Masalah dan Bug

### A. Bug Kritis & Celah Teknis Nyata pada `ASGRID V2.2 (MODE 1)`

1. **BUG KRITIS — False Positive pada `asgrid:style-is-annotative` (`ASGRID_V2_2.lsp` L204–L221)**
   - Kode saat ini menandai Text Style sebagai *Annotative* bila menemukan **pasangan `(1070 . 1)` mana pun** pada XData `"AcadAnnotative"` (L212–L215):
     ```lisp
     (foreach pair (cdr xdata)
       (if (and (= (car pair) 1070) (= (cdr pair) 1))
         (setq found T)
       )
     )
     ```
   - **Fakta struktur DXF AutoCAD:** XData `"AcadAnnotative"` pada tabel `STYLE` berformat `("AcadAnnotative" (1000 . "AnnotativeData") (1002 . "{") (1070 . 1) (1070 . <flag>) (1002 . "}"))`, di mana `1070` **pertama** adalah *version number* yang **selalu bernilai `1`**, sedangkan `1070` **kedua** barulah flag annotative (`1` = Annotative, `0` = Non-Annotative).
   - **Dampak:** Jika pengguna pernah mencentang lalu **mematikan kembali** opsi *Annotative* pada sebuah Text Style di AutoCAD, XData `AcadAnnotative` tetap tertinggal dengan `(1070 . 1)` (versi) diikuti `(1070 . 0)` (off). `asgrid:style-is-annotative` akan **keliru menolak** style non-annotative tersebut secara permanen. Solusinya adalah membaca nilai `1070` **kedua** (setelah tag versi), bukan sembarang `1070 = 1`.

2. **BUG NYATA — `STEP D` pada `c:ASGRIDEDIT` Tidak Memverifikasi Keberhasilan `(entdel e)` & Tidak Memeriksa Layer Terkunci (`ASGRID_V2_2.lsp` L3481–L3500)**
   - Pada STEP D1 (L3482–L3489):
     ```lisp
     (foreach e oldAnnoEnts
       (if (and e (entget e))
         (progn
           (entdel e)
           (setq txDeletedOldEnts (cons e txDeletedOldEnts))
         )
       )
     )
     ```
     Nilai balik `(entdel e)` maupun pemeriksaan `(null (entget e))` setelahnya **tidak pernah dicek**; `e` langsung dimasukkan ke `txDeletedOldEnts` secara tak bersyarat. Akibatnya, pengecekan `(/= (length txDeletedOldEnts) (length oldAnnoEnts))` di L3490 **tidak mampu mendeteksi kegagalan `entdel`**.
   - Selain itu, `c:ASGRIDEDIT` tidak melakukan pre-check apakah layer `LAYER_BUBBLE` (`AS-BUBBLE`) atau `LAYER_TEXT` (`AS-TEXT`) dalam kondisi **Locked** (`logand flag 4`) sebelum menjalankan STEP B–D.

3. **BUG NYATA — Potensi Rekursi Tak Terbatas (*Infinite Recursion*) pada `*error*` Saat Rollback Gagal (`ASGRID_V2_2.lsp` L1769–L1801 & L3261–L3310)**
   - Baik pada `fn-rollback-transaction` (`c:ASGRID`, L1800) maupun `fn-edit-rollback` (`c:ASGRIDEDIT`, L3309), flag `txActive` baru di-reset menjadi `nil` **di akhir fungsi rollback**, bukan di awal.
   - Jika terjadi runtime error di tengah proses rollback (misal saat `entdel`, `entmod`, atau `audit-group-entities`), `*error*` akan terpanggil kembali, melihat `txActive` masih `T`, lalu memanggil fungsi rollback secara rekursif tanpa henti. Flag `txActive` wajib di-set `nil` **sebelum** baris pertama operasi rollback.

4. **BUG NYATA — Pemotongan Teks pada Tile DCL `ed_scale_prev` & `ed_style_info` (`ASGRID_V2_2.dcl` L306–L317)**
   - Kedua tile didefinisikan dengan `width = 44; fixed_width = true;`.
   - Namun pada `fn-edit-update-preview` (L2999–L3008):
     - `ed_scale_prev` dapat menerima string sepanjang ~70 karakter, misalnya `"Model -> Text: 250.0 mm | Bubble: 800.0 mm [Note: Anno EXT < Geom EXT]"` → **terpotong** di tile lebar 44.
     - `ed_style_info` ketika `INVALID` menerima string hingga ~130+ karakter (misal pesan lengkap Fixed Height atau Annotative) → **terpotong** cukup parah di kanan.

5. **BUG NYATA — Sensitivitas Huruf Besar/Kecil (*Case-Sensitivity*) pada Daftar Text Style (`ASGRID_V2_2.lsp` L3603–L3606 & L3648–L3650)**
   - Tabel `STYLE` di AutoCAD bersifat *case-insensitive*, sedangkan `(member ...)` (L3604) dan `(vl-position ...)` (L3648) di AutoLISP bersifat *case-sensitive*.
   - Jika `TEXT_STYLE` pada metadata berbeda kapitalisasi dengan nama yang dikembalikan `tblnext` (misal `"STANDARD"` vs `"Standard"`), style tersebut akan **terduplikasi** di dropdown `ed_txt_style`.

6. **BUG / CELAH VALIDASI — `asgrid:validate-text-style` & `asgrid:find-font-file` (`ASGRID_V2_2.lsp` L152–L182, L249–L263)**
   - **False positive font kosong:** Apabila `assoc 3` pada record `STYLE` kosong dan XData `"ACAD"` memiliki `(1000 . "NamaFont")`, L254–L255 langsung mengembalikan `(list T namaFont)` **tanpa memverifikasi** apakah file font TrueType tersebut benar-benar terpasang di sistem.
   - **Folder font Windows per-user terlewat:** Pada Windows 10/11 modern, font yang diinstal pengguna tersimpan di `%LOCALAPPDATA%\Microsoft\Windows\Fonts\`, yang belum diperiksa oleh `asgrid:find-font-file` / `asgrid:find-arial-ttf`.
   - **Duplikasi fungsi:** `asgrid:find-arial-ttf` (L268–L290) mengulang logika `asgrid:find-font-file` (L152–L182) dan `asgrid:find-font-file` memiliki variabel lokal tidak terpakai `ext` (L152).

7. **CELAH KEAMANAN TRANSAKSI — Verifikasi `ASGRID_TX_TMP` & Strip DXF pada Recovery (`ASGRID_V2_2.lsp` L3233–L3254, L688–L705)**
   - `fn-edit-promote-temp-to-final` (L3233–L3234) mengecek `(asgrid:parse-entity-xdata e)` (`ASGRID_OBJ` terpasang), tetapi **tidak memverifikasi** `(null (asgrid:parse-entity-xdata-for-app e tmpApp))` untuk memastikan `ASGRID_TX_TMP` benar-benar terhapus.
   - `c:ASGRIDCHECK` tidak memindai sisa entitas `ASGRID_TX_TMP`; bila pernah terjadi *hard crash* AutoCAD saat `ASGRIDEDIT`, entitas sementara yatim tidak akan terdeteksi oleh `ASGRIDCHECK`.
   - `fn-edit-recreate-from-dxf` (L3249) hanya membuang kode `'(-1 5 330 102)` tanpa membuang `360` (*hard-owner / Extension Dictionary*), dan `asgrid:meta-update-group` (L697) menyaring header XRecord berdasarkan whitelist kode `'(-1 0 5 102 330 100 280)` — bila XRecord memiliki `102 "{ACAD_XDICTIONARY"` berisi `360`, pasangan kurung `102` bisa menjadi kosong dan menggagalkan `entmod` (lebih aman menyalin seluruh elemen header sebelum kode `300` pertama).

8. **REGREDI PERFORMA & TEMUAN MINOR KODE**
   - **Regresi performa `c:ASGRIDCHECK` (`O(G × E)`):** Pada V2.1.2 `ASGRIDCHECK` memindai `ssget "_X"` hanya **1 kali**. Pada V2.2, `c:ASGRIDCHECK` memindai `ssget "_X"` 1 kali di L2664, lalu memanggil `asgrid:audit-group-entities` di dalam loop grup (L2708) yang kembali menjalankan `ssget "_X"` untuk **setiap grup** (`G + 1` scan penuh DWG).
   - **Variabel `foreach` belum dideklarasikan lokal & variabel lokal tak terpakai:**
     - `foreach` belum dideklarasikan di daftar lokal: `item` (`fn-replace-nth` L1588), `s` (`fn-update-live-preview` L2148/2155), `pair` (`fn-inc-orphan-role` L2629), dan `errItem` (`c:ASGRIDCHECK` L2702).
     - Variabel lokal tidak terpakai: `ext` (`asgrid:find-font-file` L152), `role` (`c:ASGRIDCHECK` L2597), `ok` (`fn-edit-validate-dialog` L3028), `expTot` (`fn-edit-execute-transaction` L3370).
   - **No-op edit tetap menulis ulang semua entitas & Handle:** Jika pengguna mengklik `OK` di `ASGRIDEDIT` tanpa mengubah satu pun dari 5 parameter, transaksi tetap menghapus seluruh bubble/teks lama dan membuat ulang semuanya (mengganti semua Entity Handle dan menulis `UPDATED_AT`).
   - **Inkonsistensi pemakaian helper:** `c:ASGRID` (L1930–L1944) masih menulis pengecekan `tblsearch "APPID"` + `regapp` secara inline alih-alih memakai shared service `(asgrid:ensure-regapp XDATA_APP)` yang sudah dibuat di L32.
   - **Celah tersisa dari V2.1.2:** Pola `dictremove` + `entdel` di `fn-rollback-transaction` (L1784–L1789), pesan `"dengan rollback penuh"` saat abort pre-check (L1572), tidak adanya cek duplikasi key pada `asgrid:meta-read-group`, teks multi-karakter preview pada bubble kecil, serta penggunaan `append` `O(N²)` dalam beberapa loop masih belum disentuh.

### B. Masalah Struktur Project & Risiko Deployment

1. **RISIKO TINGGI — Tabrakan Nama File Identik antara `ASGRID V2.2 (FIX BUG)` dan `ASGRID V2.2 (MODE 1)`**
   - Kedua folder sama-sama berisi `ASGRID_V2_2.lsp` dan `ASGRID_V2_2.dcl`. Jika folder `ASGRID V2.2 (FIX BUG)` masih terdaftar lebih dulu di *AutoCAD Support File Search Path*, `(findfile "ASGRID_V2_2.dcl")` akan memuat DCL Phase 1 (tanpa dialog `asgrid_edit_v2_2`) sehingga `ASGRIDEDIT` gagal dibuka.
2. **Pengujian runtime AutoCAD 2021 untuk Phase 2 (`ASGRIDEDIT` Mode 1) belum dilakukan** — Seluruh transaksi 6-langkah (`ASGRID_TX_TMP`, `entmod` XData swap, `entmod` XRecord update, *undelete* rollback) baru lolos audit statis.
3. **Ukuran file monolitik terus membengkak (3.694 baris di 1 file `.lsp`)** — Dengan rencana penambahan `ASGRIDEDIT` Mode 2 (edit geometri/spacing), satu file monolitik akan melampaui 5.000+ baris dan makin sulit dipelihara/diuji.
4. **Konflik nama command lintas 7 folder versi** (`c:ASGRID` di 7 file, `c:ASGRIDCHECK` di 4 file, `c:ASGRIDEDIT` di Phase 2) serta ketergantungan manual pada *Support File Search Path* untuk file `.dcl`.
5. **Belum ada Version Control (`Git`) & arsip folder kian bertumpuk** — 7 folder versi bercampur di level yang sama dengan penamaan folder berspasi dan tanda kurung (`ASGRID V2.2 (FIX BUG)`, `ASGRID V2.2 (MODE 1)`), serta dokumen review tersimpan tersebar di dalam masing-masing folder versi lama.

---

## 8. Rekomendasi Pengembangan Berikutnya

### Tahap 1 — Perbaikan Bug Kritis Phase 2 & Uji Runtime AutoCAD 2021 (Prioritas Tertinggi)
Sebelum melangkah ke `ASGRIDEDIT` Mode 2, perbaiki terlebih dahulu bug teknis nyata pada `ASGRID V2.2 (MODE 1)` lalu jalankan penuh `phase2_testing_checklist.md` di AutoCAD 2021:
1. **Perbaiki `asgrid:style-is-annotative`:** Parse pasangan `1070` kedua (flag annotative) di dalam `AnnotativeData`, bukan sembarang `(1070 . 1)` agar style yang pernah dimatikan status annotative-nya tidak tertolak.
2. **Perketat keamanan `STEP D` & Rollback:**
   - Verifikasi hasil `(entdel e)` (pastikan `(null (entget e))`) pada STEP D1 sebelum menambahkan ke `txDeletedOldEnts`.
   - Tambahkan pre-edit check terhadap layer terkunci (*locked*) untuk `LAYER_BUBBLE` dan `LAYER_TEXT` (serta `LAYER_GRID` nanti untuk Mode 2).
   - Set `(setq txActive nil)` di baris **pertama** `fn-edit-rollback` dan `fn-rollback-transaction` untuk mencegah rekursi tak terbatas di `*error*`.
   - Verifikasi `(null (asgrid:parse-entity-xdata-for-app e tmpApp))` di `fn-edit-promote-temp-to-final` dan tambahkan pengecekan sisa entitas `ASGRID_TX_TMP` pada `c:ASGRIDCHECK`.
3. **Perbaiki DCL & UX `ASGRIDEDIT`:**
   - Perlebar atau pecah baris peringatan pada `ed_scale_prev` dan `ed_style_info` (misal pisah menjadi 2 baris text tile atau ringkas teks status agar tidak terpotong di `width = 44`).
   - Gunakan perbandingan *case-insensitive* (`strcase`) untuk deduplikasi dan pencarian indeks `styleList`.
   - Tambahkan short-circuit *no-op* bila pengguna mengklik `OK` tanpa mengubah satu pun parameter anotasi.
4. **Rapikan detail pendukung:**
   - Ganti pemanggilan `tblsearch`/`regapp` inline di `c:ASGRID` dengan `(asgrid:ensure-regapp XDATA_APP)`.
   - Hapus duplikasi `asgrid:find-arial-ttf` (delegasikan ke `asgrid:find-font-file` + tambahkan path `%LOCALAPPDATA%\Microsoft\Windows\Fonts\`).
   - Perbaiki pemotongan header di `asgrid:meta-update-group` (ambil seluruh pasangan sebelum DXF `300` pertama) dan buang kode `360` di `fn-edit-recreate-from-dxf`.
   - Deklarasikan 4 variabel `foreach` yang terlewat (`item`, `s`, `pair`, `errItem`) dan bersihkan 4 variabel lokal tak terpakai.

### Tahap 2 — Modularisasi Multi-File & Inisialisasi Git (Sangat Disarankan Sebelum Mode 2)
Dengan ukuran kode yang sudah mencapai 3.694 baris, pecah project sebelum membangun `ASGRIDEDIT` Mode 2 agar terhindar dari file monolitik 5.000+ baris dan tabrakan nama file DCL antar folder:
```text
ASGRID/
├── asgrid_loader.lsp          (Entry loader tunggal + penyimpanan base path otomatis)
├── src/
│   ├── asgrid_core.lsp        (Section 1: konstanta, regapp, parser, utils O(N))
│   ├── asgrid_style.lsp       (Section 2: font, layer, linetype, validasi style)
│   ├── asgrid_meta.lsp        (Section 3: NOD/XRecord, XData, validasi 24+ key)
│   ├── asgrid_engine.lsp      (Section 4: Geometry Engine + Annotation Engine shared)
│   ├── asgrid_preview.lsp     (Section 5: Live Preview dual-extension)
│   ├── asgrid_audit.lsp       (Section 6: Audit Service single-pass O(E))
│   ├── asgrid_cmd_create.lsp  (Command c:ASGRID)
│   ├── asgrid_cmd_edit.lsp    (Command c:ASGRIDEDIT — Mode 1 & Mode 2)
│   └── asgrid_cmd_check.lsp   (Command c:ASGRIDCHECK)
├── dcl/
│   └── asgrid_v2_2.dcl        (Dialog generator & editor terpusat)
├── docs/
│   ├── README.md
│   ├── CHANGELOG.md
│   └── METADATA_SCHEMA.md
└── archive/                   (V1.0, V2.0, V2.1, V2.1.1, V2.1.2, V2.2-Phase1)
```
- Optimalkan `c:ASGRIDCHECK` kembali menjadi **single-pass scan** (`O(E)`) dengan opsi meneruskan daftar entitas hasil scan awal ke `asgrid:audit-group-entities` sehingga tidak mengulang `ssget "_X"` per grup.

### Tahap 3 — Pengembangan `ASGRIDEDIT` Mode 2 (Geometry & Spacing Editor)
1. **Ekstrak `asgrid:geometry-engine`** (dan `asgrid:draw-line`) ke shared service layer dengan dukungan `_XDATA_APP_OVERRIDE` seperti `asgrid:annotation-engine`.
2. **Perluas dialog editor** (atau tambahkan pilihan Mode 1 *Annotation Only* vs Mode 2 *Full Geometry & Spacing Edit*) untuk mengubah jumlah grid H/V, daftar interval spacing, `EXT_LEN`, atau `SCALE_DENOM` dengan Live Preview real-time dan transaksi 6-langkah `ASGRID_TX_TMP` yang mencakup `LINE` + `BUBBLE` + `TEXT`.
3. **Tambahkan validasi layer terkunci pada seluruh 3 layer** (`AS-GRID`, `AS-BUBBLE`, `AS-TEXT`) serta konfirmasi eksplisit kepada pengguna bahwa perubahan geometri akan memengaruhi posisi `LINE` eksisting.

### Tahap 4 — Ekspansi Utilitas Toolkit CAD
- **`ASGRIDDEL`:** Penghapusan 1 grup grid lengkap beserta XRecord-nya di NOD secara terisolasi dan aman (1 `UNDO` Group).
- **`ASGRIDDIM`:** Pembuatan dimensi otomatis antar-as dan dimensi total yang terikat pada metadata `Group ID`.
- **Opsi Linetype Scale per entitas (DXF `48`):** Memberi pilihan opsional agar pola garis putus-putus `CENTER` pada `AS-GRID` tampil proporsional pada skala `1:50`–`1:200` tanpa mengubah `LTSCALE` global pengguna.
