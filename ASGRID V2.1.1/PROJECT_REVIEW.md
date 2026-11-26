# PROJECT REVIEW — ASGRID Toolkit (AutoLISP / AutoCAD 2021)

- **Tanggal Review:** 2026-11-26
- **Lokasi Project:** `d:/Taufik/File/CAD-ASGRID TAUFIK/ASGRID TAUFIK/`
- **Versi Terbaru:** `ASGRID V2.1.1` (Stability & Metadata Hardening)
- **Target Lingkungan:** Autodesk AutoCAD 2021 (AutoLISP standar + DCL, Model Space, WCS, satuan milimeter)

---

## 1. Ringkasan Project

**ASGRID** adalah toolkit AutoLISP untuk **AutoCAD 2021** yang berfungsi mengotomatisasi pembuatan garis as (grid) bangunan beserta bubble dan label penomoran secara presisi pada Model Space (WCS, satuan milimeter).

Secara fungsional, ASGRID menghasilkan:
- **Garis as horizontal** sejajar sumbu X dengan penomoran angka (`1, 2, 3, ...`) pada jarak antar-as individual sepanjang sumbu Y.
- **Garis as vertikal** sejajar sumbu Y dengan penomoran huruf berlanjut (`A, B, C, ..., Z, AA, AB, ...`) pada jarak antar-as individual sepanjang sumbu X.
- **Bubble & teks anotasi** di ujung awal, ujung akhir, atau kedua ujung garis as dengan ukuran Model Space yang dihitung otomatis dari skala cetak (`1:N`), tinggi teks cetak, dan diameter bubble cetak.
- **Standarisasi layer & font terisolasi:** layer `AS-GRID` (linetype `CENTER`, warna `8`), `AS-BUBBLE` (warna `2`), `AS-TEXT` (warna `7`), serta Text Style khusus `ASGRID-ARIAL` (`arial.ttf`) tanpa mengubah `CLAYER`, `TEXTSTYLE`, `DIMSTYLE`, atau `UCS` aktif pengguna.
- **Fondasi metadata DWG & diagnostik:** sejak V2.1 dan diperkeras pada V2.1.1, setiap grup grid disimpan dalam `Named Object Dictionary` (`ASGRID_GROUPS`) sebagai `XRecord` per Group ID unik (`ASG-0001`, `ASG-0002`, ...) dan setiap entitas diberi identitas `XData` (`ASGRID_OBJ`) sebagai fondasi fitur `ASGRID EDIT` di masa mendatang.

Evolusi pengembangan project sejauh ini berlangsung dalam 4 rilis berurutan:
1. **V1.0** — Generator berbasis command-line interaktif (10 tahap prompt).
2. **V2.0** — Migrasi antarmuka ke dialog DCL dengan tabel spacing terpaginasi (8 baris/halaman), validasi terpusat, dan isolasi Text Style `ASGRID-ARIAL`.
3. **V2.1** — Layout DCL 2-kolom dengan **Live Preview** berbasis `image` tile, fondasi metadata DWG (NOD/XRecord + XData), serta pemisahan `Geometry Engine` dan `Annotation Engine`.
4. **V2.1.1** — Penguatan stabilitas & metadata (*Hard Gate* tulis → baca balik → *deep compare*), *transaction safety* dengan *isolated rollback* berbasis `entmakex`, validasi jumlah entitas & XData eksak, pustaka bersama stateless (`asgrid:*`), serta perintah diagnostik read-only `ASGRIDCHECK`.

---

## 2. Struktur Folder dan File

Project berada di dalam folder workspace `CAD-ASGRID TAUFIK/ASGRID TAUFIK/` dan diorganisasikan berdasarkan folder rilis versi. Per 26 November 2026, salinan duplikat di root `ASGRID TAUFIK/` telah dibersihkan sehingga seluruh file tersusun di dalam 4 folder versi (total **14 file**: 4 `.lsp`, 3 `.dcl`, 4 `.png`, dan 3 `.md`). Tidak terdapat repositori Git (`.git`).

```text
CAD-ASGRID TAUFIK/
└── ASGRID TAUFIK/
    ├── PROJECT_REVIEW.md                         (Laporan review project ini)
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
    └── ASGRID V2.1.1/
        ├── ASGRID_V2_1_1.dcl                     (10.304 B |   271 baris)
        ├── ASGRID_V2_1_1.lsp                     (86.836 B | 2.315 baris)
        ├── changelog_v2_1_1.md                   ( 4.934 B |    46 baris)
        ├── technical_review_v2_1_1.md            ( 7.189 B |    88 baris)
        └── testing_checklist_v2_1_1.md           ( 5.527 B |    49 baris)
```

---

## 3. Fungsi Masing-Masing File

### A. Paket V1.0 (Baseline Command-Line)
| File | Ukuran / Baris | Fungsi |
| :--- | :---: | :--- |
| `ASGRID V1.0/ASGRID_V1.lsp` | 17 KB / 502 baris | Implementasi awal command `ASGRID` berbasis 10 prompt command-line. Membuat garis as, bubble, dan teks via `entmake` di WCS (mm), otomatis menyiapkan linetype `CENTER` dan 3 layer standar dalam satu grup `UNDO`. Tidak membutuhkan file DCL. |

### B. Paket V2.0 (DCL Edition & Isolated Arial Font)
| File | Ukuran / Baris | Fungsi |
| :--- | :---: | :--- |
| `ASGRID V2.0/ASGRID_V2.dcl` | 7,8 KB / 213 baris | Definisi dialog `asgrid_v2` 1-kolom: konfigurasi jumlah grid, tabel jarak interval H/V dengan pagination 8 baris/halaman, parameter skala & anotasi, pratinjau ukuran Model Space, status font Arial, `errtile`, dan tombol `ok_cancel`. |
| `ASGRID V2.0/ASGRID_V2.lsp` | 35 KB / 983 baris | Implementasi command `ASGRID` dengan antarmuka DCL, parser angka ketat, validasi terpusat sebelum dialog ditutup, dan pembuatan/pengecekan Text Style khusus `ASGRID-ARIAL` (`arial.ttf`). |
| `ASGRID V2.0/DOKUMENTASI HASIL.png` | 99 KB | Tangkapan layar dialog `ASGRID V2.0` saat uji coba di AutoCAD 2021 (grid 4×4, skala 1:100). |
| `ASGRID V2.0/DOKUMENTASI HASIL (2).png` | 82 KB | Tangkapan layar hasil gambar grid 4×4 (8 garis as, 16 bubble, 16 teks) di Model Space AutoCAD 2021. |

### C. Paket V2.1 (Live Preview & Metadata Foundation)
| File | Ukuran / Baris | Fungsi |
| :--- | :---: | :--- |
| `ASGRID V2.1/ASGRID_V2_1.dcl` | 10 KB / 270 baris | Definisi dialog `asgrid_v2_1` 2-kolom: kolom kiri mempertahankan seluruh panel input V2.0 (A–D), kolom kanan menambahkan panel **E. Live Preview** (`image` tile `46×24`, info dimensi total, status mode preview, `Next Group ID`, tombol `Refresh Preview`). |
| `ASGRID V2.1/ASGRID_V2_1.lsp` | 65 KB / 1.737 baris | Implementasi command `ASGRID` V2.1 dengan Live Preview berbasis `vector_image` + mini stroke-font 4×6 piksel + *dense sampling*, penyimpanan metadata DWG (`ASGRID_GROUPS` NOD/XRecord & `ASGRID_OBJ` XData), serta pemisahan `fn-geometry-engine` dan `fn-annotation-engine`. |
| `ASGRID V2.1/Dokumentasi asgrid v2.1.png` | 160 KB | Tangkapan layar dialog 2-kolom `ASGRID V2.1` dengan Live Preview aktif dan `Next Group ID: ASG-0002`. |
| `ASGRID V2.1/Dokumentasi asgrid v2.1 (2).png` | 145 KB | Tangkapan layar hasil grid 4×4 `ASGRID V2.1` di Model Space AutoCAD 2021. |

### D. Paket V2.1.1 (Versi Aktif Terbaru — Stability & Metadata Hardening)
| File | Ukuran / Baris | Fungsi |
| :--- | :---: | :--- |
| `ASGRID V2.1.1/ASGRID_V2_1_1.dcl` | 10 KB / 271 baris | Definisi dialog `asgrid_v2_1_1` yang mempertahankan penuh layout 2-kolom V2.1 dengan judul dan dialog ID terpisah agar aman berdampingan dengan V2.1. |
| `ASGRID V2.1.1/ASGRID_V2_1_1.lsp` | 86 KB / 2.315 baris | **File kode utama terbaru.** Mendefinisikan 14 fungsi pustaka stateless `asgrid:*`, command utama `c:ASGRID` (dengan Hard Gate metadata, transaksi `entmakex` + rollback terisolasi, verifikasi jumlah & XData eksak), serta command diagnostik read-only `c:ASGRIDCHECK`. |
| `ASGRID V2.1.1/changelog_v2_1_1.md` | 4,9 KB / 46 baris | Catatan perubahan terstruktur dari V2.1 ke V2.1.1 beserta daftar fitur yang dipertahankan. |
| `ASGRID V2.1.1/technical_review_v2_1_1.md` | 7,2 KB / 88 baris | Laporan audit teknis V2.1, desain alur transaksi V2.1.1, rumus eksak *expected entity count*, dan hasil verifikasi statis kode. |
| `ASGRID V2.1.1/testing_checklist_v2_1_1.md` | 5,5 KB / 49 baris | Daftar uji manual (6 skenario utama) yang disiapkan untuk verifikasi langsung di AutoCAD 2021. |

---

## 4. Arsitektur Program

### A. Pola Arsitektur Umum
Setiap rilis ASGRID dirancang sebagai **paket monolitik mandiri** (1 file `.lsp` + 1 file `.dcl`, tanpa `(load ...)` antar file LISP). Mulai **V2.1.1**, struktur internal di dalam `ASGRID_V2_1_1.lsp` ditingkatkan menjadi **3 lapisan utama** tanpa variabel global data (*zero global state*):

1. **Shared Stateless Library (`asgrid:*`)** — 14 fungsi utilitas murni untuk parsing input, akses NOD `ASGRID_GROUPS`, pembacaan `XRecord`, parsing `XData` (`ASGRID_OBJ`), validasi skema metadata, *deep compare* spesifikasi (`1e-6`), dan kalkulasi *expected entity count*.
2. **Command Utama (`c:ASGRID`)** — Mengelola sesi dialog DCL + Live Preview, koordinasi transaksi pembuatan grid, *Hard Gate* metadata, *Geometry Engine*, *Annotation Engine*, dan *isolated rollback* dengan seluruh state disimpan lokal.
3. **Command Diagnostik (`c:ASGRIDCHECK`)** — Perintah audit **100% READ-ONLY** yang mengonsumsi langsung pustaka `asgrid:*` untuk memverifikasi kesehatan seluruh grup grid di dalam DWG.

### B. Alur Eksekusi & Siklus Transaksi (`ASGRID V2.1.1`)

```text
[c:ASGRID]
   │
   ├── (1) Muat DCL via (findfile "ASGRID_V2_1_1.dcl") -> new_dialog "asgrid_v2_1_1"
   ├── (2) Loop Interaktif DCL (Modul 8) <──> Live Preview Non-Permanen (Modul 7)
   ├── (3) Validasi Terpusat fn-validate-all (Modul 9) -> OK menutup dialog
   ├── (4) Input Titik Awal WCS (getpoint + trans 1 0)
   └── (5) fn-execute-grid-creation (Transaksi Terisolasi):
             ├── Mulai UNDO _Begin & txActive = T
             ├── Pre-checks: Text Style ASGRID-ARIAL, regapp ASGRID_OBJ, Linetype CENTER, 3 Layer
             ├── Generate Unique Group ID (scan NOD + XData) -> Build Spec -> Validate Spec
             ├── [HARD GATE A] Tulis XRecord ke NOD "ASGRID_GROUPS" (tolak duplikat)
             ├── [HARD GATE B] Baca balik XRecord -> Validate Spec -> Deep Compare (1e-6)
             │      └── Gagal? -> fn-rollback-transaction & ABORT (0 geometri dibuat)
             ├── [GEOMETRY ENGINE] fn-geometry-engine(readBack) via entmakex -> Cek cntLine == expL
             ├── [ANNOTATION ENGINE] fn-annotation-engine(readBack) via entmakex -> Cek cntB/cntT
             ├── [FINAL VERIFY] fn-verify-tx-entities: cek XData & Group ID semua txCreatedEnts
             │      └── Ada mismatch / error / ESC? -> fn-rollback-transaction (hapus hanya txCreatedEnts & txSavedXrec)
             └── [COMMIT] Reset txActive, tutup UNDO _End, pulihkan CMDECHO, cetak ringkasan
```

### C. Skema Metadata DWG (`SCHEMA_VER = "1.0"`)
- **Level Grup — Named Object Dictionary (`ASGRID_GROUPS`):**
  - Setiap grup grid disimpan sebagai 1 objek `XRecord` dengan kunci Group ID unik (`ASG-0001`, `ASG-0002`, ...).
  - Menyimpan pasangan kode DXF `300` (nama key) + nilai (`1` string, `10` 3D point, `40` real, `90` int) meliputi: `SCHEMA_VER`, `GROUP_ID`, `MODULE`, `GENERATOR_VER`, `CREATED_AT`, `NUM_H`, `NUM_V`, `BASE_PT_WCS`, `ELEVATION`, `AXIS_DIR_H`, `AXIS_DIR_V`, `DIST_H_COUNT`, `DIST_H_ITEM` (berulang), `DIST_V_COUNT`, `DIST_V_ITEM` (berulang), `SCALE_DENOM`, `TEXT_H_PRINT`, `BUBBLE_DIA_PRINT`, `EXT_LEN`, `BUBBLE_POS`, `TEXT_STYLE`, `FONT_FILE`, `LAYER_GRID`, `LAYER_BUBBLE`, `LAYER_TEXT`.
- **Level Entitas — XData (`ASGRID_OBJ`):**
  - Melekat pada setiap `LINE`, `CIRCLE`, dan `TEXT` hasil generate dalam urutan 6 field:
    1. `(1000 . GroupID)` — contoh `"ASG-0001"`
    2. `(1000 . Role)` — `"LINE"` | `"BUBBLE"` | `"TEXT"`
    3. `(1000 . AxisDir)` — `"H"` | `"V"`
    4. `(1070 . AxisIdx)` — indeks berbasis-1 (`1, 2, 3, ...`)
    5. `(1000 . EndTag)` — `"NONE"` | `"START"` | `"END"`
    6. `(1000 . SchemaVer)` — `"1.0"`

### D. Rumus Eksak Jumlah Entitas (`asgrid:calc-expected-counts`)
- `expLines = NUM_H + NUM_V`
- `endsMult = 2` (jika `"Both Ends"`) atau `1` (jika `"Start"` / `"End"`)
- `expBubbles = (NUM_H + NUM_V) × endsMult`
- `expTexts = (NUM_H + NUM_V) × endsMult`
- `expTotal = expLines + expBubbles + expTexts`

---

## 5. Modul yang Sudah Tersedia

### A. Inventaris Modul pada `ASGRID_V2_1_1.lsp`

| Kelompok / Modul | Lokasi Baris | Komponen Utama | Scope |
| :--- | :---: | :--- | :---: |
| **Shared Stateless Library** | L21–L426 | `asgrid:dict-name`, `asgrid:xdata-app`, `asgrid:valid-bubble-positions`, `asgrid:trim`, `asgrid:parse-pos-int`, `asgrid:parse-pos-real`, `asgrid:meta-get-root-dict`, `asgrid:meta-list-nod-ids`, `asgrid:parse-entity-xdata`, `asgrid:meta-list-all-ids`, `asgrid:meta-read-group`, `asgrid:calc-expected-counts`, `asgrid:meta-validate-spec`, `asgrid:meta-compare-specs` | Global (`asgrid:*`) |
| **Modul 1 — Error Handler & Rollback** | L520–L565 | `*error*` (tutup DCL, rollback transaksi aktif, tutup `UNDO`, pulihkan `CMDECHO`, bedakan cancel vs abort vs error) | Lokal `c:ASGRID` |
| **Modul 2 — Utilitas & Penomoran** | L567–L624 | `fn-index-to-alpha`, `fn-replace-nth`, `fn-resize-str-list`, `fn-pad-4`, `fn-get-timestamp` | Lokal `c:ASGRID` |
| **Modul 3 — Linetype, Layer & Font Arial** | L626–L782 | `fn-ensure-linetype-center`, `fn-ensure-layer`, `fn-find-arial-ttf`, `fn-ensure-arial-style` | Lokal `c:ASGRID` |
| **Modul 4 — Metadata Hard Gate & Rollback** | L784–L993 | `fn-make-obj-xdata`, `fn-meta-generate-next-id`, `fn-meta-build-spec`, `fn-meta-save-group`, `fn-rollback-transaction`, `fn-verify-tx-entities` | Lokal `c:ASGRID` |
| **Modul 5 — Primitif Entitas (`entmakex`)** | L995–L1057 | `fn-draw-line`, `fn-draw-circle`, `fn-draw-text-mc` (melacak `ename` ke `txCreatedEnts`) | Lokal `c:ASGRID` |
| **Modul 6 — Engines & Transaction Coordinator** | L1059–L1456 | `fn-compute-cumulative`, `fn-geometry-engine`, `fn-annotation-engine`, `fn-execute-grid-creation` | Lokal `c:ASGRID` |
| **Modul 7 — Live Preview Engine** | L1458–L1709 | `fn-prev-draw-circle`, `fn-prev-draw-char` (mini stroke-font 4×6), `fn-prev-draw-string`, `fn-update-live-preview` (dengan mode *dense sampling*) | Lokal `c:ASGRID` |
| **Modul 8 — DCL UI & Pagination** | L1711–L1848 | `fn-refresh-h-table`, `fn-refresh-v-table`, `fn-save-h-slot`, `fn-save-v-slot`, `fn-flush-active-page`, `fn-sync-grid-counts`, `fn-update-scale-preview` | Lokal `c:ASGRID` |
| **Modul 9 — Validasi Input Terpusat** | L1850–L1991 | `fn-validate-all` | Lokal `c:ASGRID` |
| **Diagnostik Read-Only** | L2121–L2311 | `c:ASGRIDCHECK` + helper lokal `fn-inc-group-role` | Global (`c:*`) |

### B. Matriks Perbandingan Fitur Antar Versi

| Fitur / Kapabilitas | V1.0 | V2.0 | V2.1 | V2.1.1 |
| :--- | :---: | :---: | :---: | :---: |
| Grid H (`1..N`) & V (`A..AA`), WCS mm, `UNDO` Group | Ya | Ya | Ya | Ya |
| Dialog DCL + Tabel Pagination (8 baris/halaman) | Tidak | Ya | Ya | Ya |
| Isolasi Text Style `ASGRID-ARIAL` (`arial.ttf`) | Tidak | Ya | Ya | Ya |
| Live Preview DCL (`image` tile + *dense mode*) | Tidak | Tidak | Ya | Ya |
| Metadata DWG (NOD `ASGRID_GROUPS` + XData `ASGRID_OBJ`) | Tidak | Tidak | Ya | Ya |
| Pemisahan Geometry Engine & Annotation Engine | Tidak | Tidak | Ya | Ya |
| Metadata Hard Gate (Read-back + Deep Compare `1e-6`) | Tidak | Tidak | Tidak | Ya |
| Transaction Safety (`entmakex` + Isolated Rollback) | Tidak | Tidak | Tidak | Ya |
| Validasi Exact Entity Count & Verifikasi XData | Tidak | Tidak | Tidak | Ya |
| Shared Stateless Library (`asgrid:*`) | Tidak | Tidak | Tidak | Ya |
| Perintah Diagnostik Read-Only (`ASGRIDCHECK`) | Tidak | Tidak | Tidak | Ya |
| Fitur Modifikasi Grid (`ASGRID EDIT`) | Tidak | Tidak | Tidak | Belum |

---

## 6. Kondisi Implementasi Saat Ini

- **Fitur inti pembuatan grid sudah matang secara arsitektural:** Alur pembuatan grid dari UI DCL, Live Preview proporsional, validasi ketat, isolasi font Arial, hingga penyimpanan metadata DWG terverifikasi sudah terimplementasi lengkap pada `ASGRID V2.1.1`.
- **Verifikasi runtime terakhir berada di V2.1:** Versi `V2.0` dan `V2.1` sudah diuji langsung pada AutoCAD 2021 (dibuktikan oleh 4 screenshot dokumentasi visual).
- **Status V2.1.1 masih di tahap pasca-verifikasi statis:** Berdasarkan `changelog_v2_1_1.md`, `technical_review_v2_1_1.md`, dan `testing_checklist_v2_1_1.md`, seluruh perubahan hardening V2.1.1 baru lolos audit statis dan **belum dijalankan langsung di AutoCAD 2021** (seluruh item checklist uji masih belum dicentang).
- **Kesiapan untuk `ASGRID EDIT`:** Fondasi data (`ASGRID_GROUPS` XRecord + `ASGRID_OBJ` XData) dan API pembaca/validator (`asgrid:*`) sudah tersedia, namun engine pembangun geometri/anotasi dan utilitas layer/style masih berada di dalam scope lokal `c:ASGRID` sehingga belum bisa dipanggil langsung oleh command lain.

---

## 7. Potensi Masalah dan Bug

### A. Bug & Celah Teknis pada Kode (AutoLISP & DCL)

1. **Bug tampilan karakter `&` pada label DCL (`ASGRID_V2_1_1.dcl`, `ASGRID_V2_1.dcl`, `ASGRID_V2.dcl`)**
   - Pada `ASGRID_V2_1_1.dcl` baris `12` (`"(Hardened Metadata & Preview)"`) dan baris `156` (`"C. Scale & Annotation"`), tanda `&` tunggal diperlakukan oleh DCL AutoCAD sebagai karakter mnemonic/accelerator.
   - Dampaknya sudah terbukti pada tangkapan layar V2.0 dan V2.1 di mana label tercetak sebagai `C._Scale Annotation` dan `(Live Preview Metadata)`. Perlu diganti menjadi `&&` untuk menampilkan simbol `&` secara literal.

2. **Potensi runtime crash di `asgrid:meta-read-group` saat XRecord korup (`ASGRID_V2_1_1.lsp` L223–L224)**
   - Kode memanggil `(float val)` secara langsung pada pasangan `DIST_H_ITEM` dan `DIST_V_ITEM` tanpa memeriksa `(numberp val)` terlebih dahulu.
   - Karena baris `221` mengizinkan kode DXF `1` (string), jika sebuah XRecord korup menyimpan string pada item jarak, `asgrid:meta-read-group` akan melempar error runtime AutoLISP (`bad argument type: numberp`) alih-alih mengembalikan data untuk ditangkap oleh `asgrid:meta-validate-spec`.

3. **Celah validasi field `ELEVATION` dan `DIST_*_COUNT` (`ASGRID_V2_1_1.lsp` L256–L356)**
   - `ELEVATION` dicek keberadaannya di `reqKeys` (baris `260`), tetapi tidak divalidasi apakah bertipe numerik (`numberp`) maupun apakah konsisten dengan komponen Z pada `BASE_PT_WCS`.
   - `DIST_H_COUNT` dan `DIST_V_COUNT` ditulis oleh `fn-meta-save-group` (baris `881`, `889`), tetapi tidak diperiksa konsistensinya terhadap panjang aktual `DIST_H`/`DIST_V` saat pembacaan/validasi.

4. **Side effect pre-check tidak ikut dibatalkan saat Hard Gate gagal (`ASGRID_V2_1_1.lsp` L1251–L1340)**
   - `fn-ensure-arial-style`, `regapp`, `fn-ensure-linetype-center`, dan `fn-ensure-layer` dieksekusi di dalam `UNDO _Begin` sebelum Hard Gate metadata. Jika Hard Gate gagal dan memanggil `fn-rollback-transaction`, entitas grid dan XRecord memang dibersihkan, tetapi Text Style, Linetype, RegApp, dan Layer baru tetap tertinggal di DWG.
   - Selain itu, bila pre-check `fn-ensure-arial-style` atau `regapp` gagal (baris `1254`, `1265`), `txAbortedByCode` di-set `T` sehingga `*error*` mencetak `"dengan rollback penuh"` padahal belum ada transaksi yang di-rollback (pesan sedikit menyesatkan).

5. **Pola `dictremove` diikuti `entdel` pada `fn-rollback-transaction` (`ASGRID_V2_1_1.lsp` L944–L952)**
   - Di AutoCAD AutoLISP, `dictremove` sudah menghapus objek XRecord dari dictionary/database, sedangkan `entdel` bersifat *toggle* (memanggil `entdel` pada entitas yang sudah *erased* justru melakukan *undelete*). Saat ini terlindungi oleh pemeriksaan `(entget txSavedXrec)` (yang mengembalikan `nil` untuk entitas erased), namun secara defensif lebih aman menjadikan `entdel` sebagai cabang `else` jika entry tidak ditemukan di `rootDict`.

6. **Celah pada Live Preview Engine (`ASGRID_V2_1_1.lsp` L1555–L1709)**
   - **Dead variables:** `pH` dan `pV` dibaca dari `get_tile` (baris `1572–1573`), tetapi tidak pernah digunakan karena preview merender dari `strListH`/`strListV`. Jika user mengetik jumlah grid baru tanpa memicu sinkronisasi, preview belum mencerminkannya hingga `Update Table` / pindah fokus.
   - **Keterbacaan label multi-karakter di preview:** `fn-prev-draw-string` tidak membatasi lebar total string terhadap diameter `bubRadPx`, sehingga label 2+ karakter (`10`, `AA`) berpotensi keluar dari lingkaran bubble saat `bubRadPx` kecil (`5–6` px).

7. **Keterbatasan deteksi anomali pada `c:ASGRIDCHECK` (`ASGRID_V2_1_1.lsp` L2127–L2311)**
   - Validasi integritas entitas saat ini hanya mencocokkan total jumlah per `Role` (`actL == expL`, `actB == expB`, `actT == expT`). `ASGRIDCHECK` belum memverifikasi:
     - Kesesuaian tipe entitas DXF (`LINE`/`CIRCLE`/`TEXT`) terhadap `Role` di XData.
     - Rentang `AxisIdx` (`1..NUM_H` / `1..NUM_V`) dan `EndTag` terhadap `BUBBLE_POS`.
     - Duplikasi slot `(Role, AxisDir, AxisIdx, EndTag)` (misal 1 bubble terhapus dan 1 bubble lain terduplikasi akibat `COPY`, total tetap sama sehingga tetap dilaporkan `OK`).
   - Karena menggunakan `ssget "_X"`, entitas ASGRID yang dimasukkan pengguna ke dalam `BLOCK` tidak terdeteksi dan grup terkait akan tampak sebagai metadata yatim.

8. **Tidak ada pemeriksaan `INSUNITS` dan skala Linetype (`LTSCALE`)**
   - Program mengasumsikan gambar dalam satuan milimeter (`mm`), tetapi tidak memberi peringatan jika `INSUNITS` aktif bernilai non-milimeter (misal inci pada template `acad.dwt`).
   - Garis `AS-GRID` menggunakan linetype `CENTER` dengan panjang pola ISO default `50.8` mm tanpa memperhitungkan `scaleDenom` / `LTSCALE`. Pada screenshot V2.0 dan V2.1 (skala `1:100`, bentang 15.000 mm), pola putus-putus `CENTER` tampak nyaris solid/menerus.

9. **Inkonsistensi UX & performa minor**
   - Nilai default spacing vertikal saat dialog dibuka adalah `"5000"`, namun ketika jumlah grid vertikal ditambah lewat `fn-sync-grid-counts` / `fn-validate-all` (baris `1826`, `1872`), interval baru diisi `"4000"`.
   - Peringatan `bubbleDiaPrint <= textHPrint` hanya dicetak ke command line setelah dialog ditutup (baris `1984–1986`), tidak ditampilkan pada area status/error dialog DCL.
   - Beberapa loop memakai pola `(setq lst (append lst (list x)))` yang ber kompleksitas `O(N²)`; aman untuk grid kecil-menengah, namun kurang optimal pada DWG dengan banyak grup grid saat menjalankan `ASGRIDCHECK`.

### B. Masalah Struktur Project & Operasional

1. **Pengujian runtime V2.1.1 belum dijalankan di AutoCAD 2021** — Risiko regresi atau perilaku spesifik AutoCAD 2021 (terutama pada alur `dictremove`, `entmakex` dengan XData, dan `UNDO` Group) belum terkonfirmasi di lapangan.
2. **Engine inti masih terkunci di dalam scope lokal `c:ASGRID`** — Meskipun 14 fungsi metadata sudah dipindah ke `asgrid:*`, fungsi inti seperti `fn-geometry-engine`, `fn-annotation-engine`, `fn-ensure-arial-style`, `fn-ensure-layer`, `fn-meta-save-group`, dan `fn-index-to-alpha` masih lokal di `c:ASGRID` (2.315 baris dalam satu file). Fitur `ASGRID EDIT` tidak dapat memanggilnya tanpa ekstraksi ulang.
3. **Tabrakan nama command `c:ASGRID` antar versi** — Keempat versi (`V1.0`, `V2.0`, `V2.1`, `V2.1.1`) mendaftarkan nama command yang sama (`c:ASGRID`), sehingga rawan saling menimpa jika pengguna salah memuat file melalui `APPLOAD` atau *Startup Suite*.
4. **Ketergantungan manual pada AutoCAD *Support File Search Path*** — Pemuatan DCL hanya mengandalkan `(findfile "ASGRID_V2_1_1.dcl")`. Jika pengguna memindahkan atau memuat `.lsp` dari folder yang belum didaftarkan di *Options → Support File Search Path*, dialog gagal dibuka.
5. **Struktur direktori belum siap untuk toolkit multi-modul** — Folder bersarang ganda dengan spasi (`CAD-ASGRID TAUFIK/ASGRID TAUFIK/`), tidak ada pemisahan folder kerja aktif (`src/`, `dcl/`, `docs/`) dengan arsip versi lama (`archive/`), serta belum menggunakan sistem Version Control (`Git`).
6. **Inkonsistensi penamaan file dokumentasi** — Penamaan screenshot berbeda gaya antara V2.0 (`DOKUMENTASI HASIL.png`) dan V2.1 (`Dokumentasi asgrid v2.1.png`), serta rujukan `TESTING_CHECKLIST_V2_1_1.md` di `technical_review_v2_1_1.md` (baris 6) berbeda kapitalisasi dengan nama file aktual `testing_checklist_v2_1_1.md`.

---

## 8. Rekomendasi Pengembangan Berikutnya

### Tahap 1 — Verifikasi Runtime V2.1.1 & Perbaikan Cepat (*Quick Fixes*)
1. **Jalankan penuh `testing_checklist_v2_1_1.md` di AutoCAD 2021** (uji multi-grup, persistensi simpan/tutup/buka DWG, anomali `ASGRIDCHECK`, cancel/ESC, dan `UNDO` tunggal) serta simpan tangkapan layar/log hasilnya.
2. **Perbaiki bug minor yang ditemukan pada audit:**
   - Ganti `&` menjadi `&&` pada seluruh string label di `ASGRID_V2_1_1.dcl`.
   - Tambahkan guard `(numberp val)` sebelum `(float val)` di `asgrid:meta-read-group`.
   - Tambahkan validasi tipe numerik `ELEVATION` (dan kecocokan terhadap Z `BASE_PT_WCS`) di `asgrid:meta-validate-spec`.
   - Rapikan alur `dictremove` vs `entdel` di `fn-rollback-transaction` dan bedakan pesan abort pre-check vs rollback transaksi.
   - Hapus variabel tidak terpakai (`pH`/`pV`) di `fn-update-live-preview` serta tampilkan peringatan `bubbleDiaPrint <= textHPrint` langsung pada UI dialog.
   - Tambahkan peringatan ringan (non-blocking) jika `INSUNITS` bukan milimeter (`4`) serta pertimbangkan opsi/saran `LTSCALE` atau entity linetype scale agar garis `CENTER` tampak proporsional pada skala cetak.

### Tahap 2 — Modularisasi & Penataan Struktur Project (Persiapan Toolkit)
1. **Inisialisasi Git** dan rapikan struktur folder menjadi standar toolkit, misalnya:
   ```text
   ASGRID/
   ├── asgrid_loader.lsp     (Entry loader tunggal + deteksi path otomatis)
   ├── src/
   │   ├── asgrid_utils.lsp  (Parser, penomoran A..AA, helper list O(N))
   │   ├── asgrid_style.lsp  (Layer, linetype CENTER, Text Style ASGRID-ARIAL)
   │   ├── asgrid_meta.lsp   (NOD/XRecord, XData, validasi & deep compare)
   │   ├── asgrid_engine.lsp (Geometry Engine, Annotation Engine, transaksi/rollback)
   │   ├── asgrid_preview.lsp(Live Preview Engine untuk Create & Edit)
   │   ├── asgrid_create.lsp (Command c:ASGRID + controller DCL)
   │   └── asgrid_check.lsp  (Command c:ASGRIDCHECK)
   ├── dcl/
   │   └── asgrid_main.dcl
   ├── docs/
   │   ├── README.md
   │   ├── CHANGELOG.md
   │   └── METADATA_SCHEMA.md
   └── archive/              (V1.0, V2.0, V2.1, V2.1.1 sebagai riwayat read-only)
   ```
2. **Ekstrak fungsi engine & style ke namespace `asgrid:*`** agar `c:ASGRID`, `c:ASGRIDCHECK`, dan `c:ASGRIDEDIT` berbagi satu sumber kebenaran (*single source of truth*) tanpa duplikasi kode.
3. **Kurangi ketergantungan *Support File Search Path*** dengan menyimpan direktori root saat `asgrid_loader.lsp` dimuat (atau fallback pencarian relatif terhadap path loader sebelum `(findfile ...)`).

### Tahap 3 — Implementasi Fitur `ASGRID EDIT` (V2.2 / V3.0)
1. **Seleksi grup yang aman:** Pilih salah satu entitas grid (membaca `Group ID` dari XData `ASGRID_OBJ`) atau pilih dari daftar grup yang terdaftar di NOD `ASGRID_GROUPS`.
2. **Reuse dialog DCL & Live Preview:** Muat spesifikasi existing dari `asgrid:meta-read-group` ke dalam form DCL 2-kolom sehingga pengguna dapat mengubah spacing, jumlah grid, skala, ekstensi, atau posisi bubble dengan pratinjau langsung.
3. **Pembaruan transaksional terkendali:** Periksa status layer terkunci (*locked*) sebelum modifikasi, bangun/perbarui entitas baru, verifikasi jumlah & XData, lalu lakukan swap/hapus entitas lama hanya setelah verifikasi lolos (rollback aman jika gagal).

### Tahap 4 — Penguatan Diagnostik & Ekspansi Fitur Toolkit
1. **Tingkatkan `ASGRIDCHECK` (Level 2):** Tambahkan validasi kesesuaian tipe DXF (`LINE`/`CIRCLE`/`TEXT`) terhadap `Role`, validasi rentang `AxisIdx`, deteksi duplikasi slot akibat `COPY`/`ARRAY`, serta optimasi list menggunakan `cons` + `reverse` (`O(N)`).
2. **Ekspansi fitur produktivitas CAD:** Pertimbangkan modul tambahan seperti dimensi otomatis antar-as & dimensi total (`ASGRIDDIM`), penghapusan grup bersih beserta metadata (`ASGRIDDEL`), opsi arah/rotasi grid, serta kustomisasi label awal (misal mulai dari angka/huruf tertentu).
