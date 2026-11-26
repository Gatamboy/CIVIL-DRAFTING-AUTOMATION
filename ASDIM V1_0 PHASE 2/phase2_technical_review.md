# Technical Review — ASDIM V1.0 Phase 2 (Style Engine & Dimension Generator)

**File Diulas:** `ASDIM V1_0 PHASE 2/ASDIM_V1_0_PHASE2.lsp` (2.237 baris, 57 `defun`, SHA-256: `635b00b15441182b51727a3e6a4acc9fcc5d8984a308e74ee2d69ac22535da41`)  
**Baseline Phase 1 R1:** `ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp` (SHA-256 utuh: `ad4add162aded6a5887117245ab37441a0a3d9380cfdf5406d6188642897eabf`)  
**Acuan ASGRID R3:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` (SHA-256 utuh: `c97af3f59dbece69f7caab4dcd2d94af2e8f05d1f72743eaa04c120ff685570b`)

## 1. Perbandingan Phase 1 R1 vs. Phase 2

- **Seluruh 31/31 fungsi Phase 1 R1 dipertahankan** tanpa refactor arsitektur audit.
- **26 fungsi baru** ditambahkan pada Section 10–15 untuk ActiveX, Style Engine, XData `ASDIM_OBJ`, perencanaan dimensi WCS, generator `vla-AddDimRotated`, safe cleanup batch, dan CLI sementara.
- Tidak ada file `.dcl` dibuat pada Phase 2.

## 2. Arsitektur Style Engine (Section 11)

1. **`ASDIM-ARIAL` (`asdim:ensure-arial-style`):**
   - Mencari `arial.ttf` via `findfile`, `%WINDIR%\Fonts\`, `%SystemRoot%\Fonts\`, dan `C:\Windows\Fonts\`. Jika tidak ditemukan → hentikan proses tanpa fallback font diam-diam.
   - Jika `ASDIM-ARIAL` sudah ada → diverifikasi ketat (`font = arial.ttf`, `Fixed Height = 0.0`, `Width Factor = 1.0`, `Oblique = 0.0`, non-annotative, flag shape/vertical = 0). Jika konflik → hentikan tanpa menimpa.
   - Jika belum ada → dibuat via `entmake` `STYLE` dengan XData `ACAD` `(1000 . "Arial") (1071 . 34)` (pola teruji ASGRID R3 L330–L353), lalu diverifikasi ulang.
2. **`ASDIM-STYLE` (`asdim:ensure-dim-style`):**
   - Tidak mengubah `DIMSTYLE` global/aktif.
   - Jika sudah ada → verifikasi DXF `340` mengarah ke `ASDIM-ARIAL` dan `DIMSCALE` (DXF `40`) = `1.0` (atau default nil = `1.0`). Konflik → hentikan tanpa menimpa.
   - Jika belum ada → Jalur 1: `vla-Add` pada `DimStyles` + `entmod` DXF `340`/`40`/`140`/`41`/`271`; Jalur 2 (fallback bila Jalur 1 gagal): `entmake` tabel `DIMSTYLE` langsung; dilanjutkan verifikasi pasca-pembuatan. *(Status: **UNVERIFIED** secara runtime di AutoCAD 2021 hingga diuji.)*
3. **Layer `AS-DIM` (`asdim:ensure-dim-layer`):**
   - Jika belum ada → dibuat via `entmake` `LAYER` (warna 3, `CONTINUOUS`) tanpa mengubah `CLAYER`.
   - Jika sudah ada → diperiksa tidak `FROZEN` (bit 1) dan tidak `LOCKED` (bit 4).

## 3. Arsitektur Dimension Generator & Metode ActiveX (Section 13–14)

- **Pemetaan Koordinat (WCS):**
  - Horizontal dimensions mengukur sepanjang X menggunakan `cumX` (`DIST_V`), `RotationAngle = 0.0` rad.
  - Vertical dimensions mengukur sepanjang Y menggunakan `cumY` (`DIST_H`), `RotationAngle = (/ pi 2.0)` rad.
- **Konversi Satuan:** `size_DU = size_print_mm * SCALE_DENOM * unitFactor` (`mm=1.0`, `cm=0.1`, `m=0.001`) **hanya** untuk `TextHeight`, `ArrowheadSize`, `Chain Offset`, dan `Row Spacing`. Nilai jarak grid (`Measurement`) tetap dalam `DU` asli tanpa dikali/dibagi `unitFactor` dan tanpa suffix satuan.
- **ActiveX API yang Digunakan (seluruhnya dibungkus `vl-catch-all-apply`):**
  - `vl-load-com`, `vlax-get-acad-object`, `vla-get-ActiveDocument`, `vla-get-ModelSpace`, `vla-get-DimStyles`, `vla-Add`
  - `vla-AddDimRotated`, `vlax-3d-point`, `vlax-vla-object->ename`, `vla-Update`
  - Setter/Getter: `vla-put-Layer`, `vla-put-StyleName`/`vla-get-StyleName`, `vla-put-TextHeight`/`vla-get-TextHeight`, `vla-put-ArrowheadSize`/`vla-get-ArrowheadSize`, `vla-put-PrimaryUnitsPrecision`, `vla-get-Measurement`.
- **Verifikasi Pasca-Pembuatan (`asdim:create-single-dim`):** Memverifikasi tipe `"DIMENSION"`, Model Space, layer `"AS-DIM"`, `StyleName = "ASDIM-STYLE"`, `TextHeight` & `ArrowheadSize` dalam toleransi `1e-3`, `Measurement` cocok dengan jarak grid `DU`, serta baca-balik 7 field XData `ASDIM_OBJ`.

## 4. Strategi Error Handling & Safe Batch Cleanup (Section 14 & 16)

- Seluruh validasi Phase 1 R1, konfirmasi satuan, ActiveX, RegApp, style, dan layer dijalankan **sebelum** satu pun `DIMENSION` dibuat.
- Setiap `DIMENSION` baru dicatat pada `createdEnts`. Jika pembuatan/verifikasi gagal di tengah batch atau diinterupsi (`*error*`), `asdim:cleanup-batch-entities` menghapus **hanya** entitas baru pada batch berjalan (`(if (entget e) (entdel e))`), menghitung jumlah berhasil/gagal dihapus, tidak pernah menghapus dimensi lama, entitas ASGRID, atau resource pra-eksisting, dan melaporkan secara eksplisit jika ada kegagalan cleanup.
- Resource baru (`ASDIM-ARIAL`, `ASDIM-STYLE`, `AS-DIM`, `ASDIM_OBJ`) yang sempat terbuat sebelum kegagalan dimensi dibiarkan sebagai *inert shared definition*. **Phase 2 tidak mengklaim transaksi atomik penuh.**

## 5. Hasil Validasi Statis 14 Butir

| No | Pemeriksaan Statis | Hasil | Bukti |
| :--- | :--- | :--- | :--- |
| 1–2 | Parentheses & String balance | **LULUS** | `depth = 0`, `max_depth = 27`, 2.237 baris, 0 string tidak tertutup. |
| 3–4 | Duplicate function & command | **LULUS** | 57 `defun`, 0 duplikasi, tepat 1 command `c:ASDIM`. |
| 5 | Global variable audit | **LULUS** | 0 variabel global; seluruh state lokal di dalam `defun`. |
| 6 | Unintended sysvar / DCL / dict-write audit | **LULUS** | **0 panggilan** `setvar`, `command`, `command-s`, `dictadd`, `dictremove`, `dictrename`, `load_dialog`, `new_dialog`, `start_dialog`, maupun `(or (findfile ...))`. |
| 7–8 | ASGRID R3 & Phase 1 R1 preservation | **LULUS** | SHA-256 ASGRID R3 dan Phase 1 R1 tidak berubah; 31/31 fungsi Phase 1 R1 utuh. |
| 9 | XData `ASDIM_OBJ` structure | **LULUS** | 7 field terurut (`SourceGroupID`, `DimBatchID`, `Orientation`, `DimType`, `SlotIdx`, `Placement`, `SchemaVer`) terpisah dari `ASGRID_OBJ`, registrasi via `tblsearch "APPID"`. |
| 10 | ActiveX method/property audit | **LULUS** | Seluruh panggilan ActiveX dibungkus `vl-catch-all-apply` dengan penolakan eksplisit bila error. |
| 11–12 | Coordinate & WCS/Model Space audit | **LULUS** | Horizontal→X (`cumX`/`DIST_V`), Vertical→Y (`cumY`/`DIST_H`); kedua `ssget "_X"` menyertakan `'(410 . "Model")` + cek `asdim:is-model-space-entity`. |
| 13–14 | Resource ownership & failure cleanup | **LULUS** | Cleanup hanya menghapus `createdEnts` batch aktif; tidak menyentuh dimensi lama, ASGRID, maupun tabel resource. |

## 6. Risiko & Fitur yang Belum Terverifikasi Runtime (`UNVERIFIED`)

1. **`vla-AddDimRotated` di bawah Rotated UCS:** Perilaku frame sudut `RotationAngle` (`0.0` / `pi/2`) saat UCS terputar aktif di AutoCAD 2021 (**UNVERIFIED** — uji `P2-D18`).
2. **Pembuatan `ASDIM-STYLE` & Referensi DXF `340`:** Perilaku `vla-Add` + `entmod` DXF `340` (dan fallback `entmake` `DIMSTYLE`) tanpa mengubah `DIMSTYLE` global di AutoCAD 2021 (**UNVERIFIED** — uji `P2-S06`).
3. **Writability Properti `AcadDimRotated`:** Kemampuan tulis langsung `StyleName`, `TextHeight`, `ArrowheadSize`, `PrimaryUnitsPrecision`, serta konsistensi font `ASDIM-ARIAL` pasca-override pada AutoCAD 2021 (**UNVERIFIED** — uji `P2-D01`, `P2-D14`).
4. **Status Runtime:** **NOT RUN** — seluruh skenario pada `phase2_testing_checklist.md` belum dijalankan di AutoCAD 2021.
