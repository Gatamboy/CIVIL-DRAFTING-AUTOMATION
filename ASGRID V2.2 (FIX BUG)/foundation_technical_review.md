# FOUNDATION TECHNICAL REVIEW — ASGRID V2.2 (Phase 1)

- **Baseline:** `ASGRID_V2_1_2.lsp` & `ASGRID_V2_1_2.dcl`
- **Target File:** `ASGRID V2.2/ASGRID_V2_2.lsp` & `ASGRID V2.2/ASGRID_V2_2.dcl`
- **Status Pengujian:** Verifikasi statis lulus penuh; eksekusi langsung di AutoCAD 2021 belum dilakukan dan perlu dijalankan mengikuti `foundation_testing_checklist.md`.

## 1. Inventaris Shared Stateless Services (`asgrid:*`)

Total terdapat **38 definisi top-level** di `ASGRID_V2_2.lsp`: **36 fungsi murni `asgrid:*`** dan **2 perintah (`c:ASGRID`, `c:ASGRIDCHECK`)**, dengan **0 variabel global data/state**.

| Kategori | Fungsi Shared (`asgrid:*`) | Kontrak Return Value |
| :--- | :--- | :--- |
| Konstanta & Parser | `dict-name`, `xdata-app`, `schema-ver`, `valid-bubble-positions`, `tol`, `trim`, `parse-pos-int`, `parse-pos-real` | String / real / integer positif atau `nil` |
| Utilitas Geometri & Waktu | `index-to-alpha`, `compute-cumulative`, `get-timestamp`, `check-insunits-warning` | Label huruf / list koordinat / timestamp string |
| Font Arial | `find-arial-ttf`, `ensure-arial-style` | Path file atau `T`/`nil` |
| Metadata & XRecord | `make-obj-xdata`, `get-anno-ext-len`, `meta-get-root-dict`, `meta-list-nod-ids`, `parse-entity-xdata`, `meta-list-all-ids`, `meta-build-xrecord-payload`, `meta-read-group`, `meta-get-xrecord-snapshot`, `meta-restore-xrecord`, `meta-update-group`, `calc-expected-counts`, `meta-validate-spec`, `meta-compare-specs` | Spec assoc list / snapshot DXF / `T`/`nil` / list error |
| Annotation Engine | `draw-circle`, `draw-text-mc`, `annotation-engine` | `ename`/`nil` dan `(list createdEnts cntBubble cntText)` |
| Live Preview | `prev-draw-circle`, `prev-draw-char`, `prev-draw-string`, `prev-render-grid` | `(list numH numV totalX totalY denseMode)` |
| Group Audit (READ-ONLY) | `audit-group-entities` | Assoc list berisi `LINE_ENTS`, `BUBBLE_ENTS`, `TEXT_ENTS`, `ANNO_ENTS`, hitungan aktual/ekspektasi, dan flag anomali |

## 2. Verifikasi Integritas Transaksi & Rollback Pasca-Ekstraksi

- **Pelacakan `ename` tetap utuh:** Di `c:ASGRID`, `fn-draw-line` tetap mencatat `ename` garis ke `txCreatedEnts`, sementara `asgrid:annotation-engine` mengembalikan `annoEnts` yang langsung digabung melalui `(setq txCreatedEnts (append annoEnts txCreatedEnts))`.
- **Rollback terisolasi:** `fn-rollback-transaction` tetap menghapus hanya `txCreatedEnts` (LIFO) dan `txSavedGroupId`/`txSavedXrec` tanpa menyentuh grup lain atau shared resources (`AS-GRID`, `AS-BUBBLE`, `AS-TEXT`, `ASGRID-ARIAL`, `ASGRID_OBJ`, `CENTER`).
- **XRecord Update Safety (Siap Phase 2):** `asgrid:meta-update-group` hanya mengganti pasangan payload setelah header asli `(-1, 0, 5, 102, 330, 100, 280)` via `entmod`, sehingga *Object Handle* dan *Dictionary Ownership* di NOD tetap utuh. Jika verifikasi baca-balik gagal pada Phase 2, `asgrid:meta-restore-xrecord` langsung mengembalikan snapshot asli.

## 3. Hasil Audit Statis Phase 1

| Kriteria Validasi | Hasil |
| :--- | :--- |
| Keseimbangan tanda kurung `()` & string `""` (`ASGRID_V2_2.lsp`) | **LULUS** (0 error) |
| Keseimbangan kurung kurawal `{}` & string `""` (`ASGRID_V2_2.dcl`) | **LULUS** (0 error) |
| Sisa referensi ke fungsi lokal lama (`fn-index-to-alpha`, `fn-draw-circle`, dll.) | **LULUS** (0 stale reference) |
| Kelengkapan seluruh 19 shared services prioritas & update helpers | **LULUS** (0 hilang) |
| Namespace top-level (`asgrid:*` & `c:*` saja, 0 global state) | **LULUS** |
| Kepatuhan Phase 1 (`c:ASGRIDEDIT` belum dibuat) | **LULUS** (`False`) |
| Kecocokan Dialog ID (`asgrid_v2_2`) & seluruh tile key DCL | **LULUS** (0 tile hilang) |
| Deklarasi lokal fungsi internal `c:ASGRID` & `c:ASGRIDCHECK` | **LULUS** (0 fungsi bocor) |
| Kepatuhan READ-ONLY pada `asgrid:audit-group-entities` & `c:ASGRIDCHECK` | **LULUS** (0 operasi mutasi) |
| Keutuhan baseline `ASGRID V2.1.2` | **LULUS** (tidak dimodifikasi) |

## 4. Kesiapan untuk Phase 2 (`ASGRIDEDIT` Mode 1)
Seluruh blok bangunan Phase 2—`asgrid:annotation-engine`, `asgrid:get-anno-ext-len`, `asgrid:meta-get-xrecord-snapshot`, `asgrid:meta-update-group`, `asgrid:meta-restore-xrecord`, `asgrid:prev-render-grid` (dual extension), `asgrid:audit-group-entities`, dan `asgrid:ensure-arial-style`—kini sudah tersedia sebagai *Shared Stateless Service* terisolasi. Phase 2 hanya perlu menambahkan dialog `asgrid_edit_v2_2` di `ASGRID_V2_2.dcl` dan perintah `c:ASGRIDEDIT` di `ASGRID_V2_2.lsp` tanpa mengubah arsitektur inti.


## 5. Technical Review — Bug Fix RegApp `APPID` (2026-11-26)
- **Lokasi Perbaikan:** `c:ASGRID` → `fn-execute-grid-creation` → Pre-check #2 (`Daftarkan RegApp XData`).
- **Analisis Perilaku AutoCAD 2021:** Fungsi standar `(regapp appname)` mengembalikan string `appname` **hanya** ketika registrasi baru berhasil; apabila `appname` sudah ada di symbol table `"APPID"`, `regapp` mengembalikan `nil`. Karena itu, `tblsearch "APPID"` adalah sumber kebenaran (*source of truth*) untuk memeriksa ketersediaan RegApp.
- **Pola Perbaikan Minimal:** `(if (not (tblsearch "APPID" XDATA_APP)) (progn (regapp XDATA_APP) (if (not (tblsearch "APPID" XDATA_APP)) ...)))`.
- **Verifikasi Statis Pasca-Perbaikan:** Keseimbangan tanda kurung `()` dan string `""` pada `ASGRID_V2_2.lsp` lulus (0 error); tidak ada perubahan pada fungsi `asgrid:*`, DCL `ASGRID_V2_2.dcl`, maupun struktur metadata/XData. Pengujian langsung di AutoCAD 2021 tetap diperlukan untuk memvalidasi seluruh skenario regresi.
