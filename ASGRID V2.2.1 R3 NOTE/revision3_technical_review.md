# Technical Review — ASGRID V2.2.1 Revision 3

**Baseline Perbandingan:** `ASGRID V2.2.1 REVISION 2`  
**Target (Baseline Resmi Saat Ini):** `ASGRID V2.2.1 R3`  
**Ruang Lingkup:** Perbaikan bug pemuatan DCL (`bad argument type: stringp T`) pada `c:ASGRID` dan `c:ASGRIDEDIT`, serta konsolidasi dokumentasi R3.

## 1. Akar Masalah & Solusi yang Diterapkan

Pada AutoLISP (AutoCAD 2021), operator `or` selalu mengembalikan nilai boolean (`T` atau `nil`), bukan nilai string non-nil pertama. Pola lama:

```lisp
(setq dclFile (or (findfile "ASGRID_V2_2_1_R2.dcl") (findfile "ASGRID_V2_2_1.dcl") (findfile "ASGRID_V2_2.dcl")))
```

menghasilkan `dclFile = T` ketika salah satu file ditemukan, sehingga `(load_dialog dclFile)` mengeksekusi `(load_dialog T)` dan memicu `bad argument type: stringp T`.

Pada Revision 3, pola tersebut diganti di kedua perintah (`c:ASGRID` dan `c:ASGRIDEDIT`) menggunakan pencarian berurutan `setq` dan `if`:

```lisp
(setq dclFile (findfile "ASGRID_V2_2_1_R3.dcl"))
(if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1_R2.dcl")))
(if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1.dcl")))
(if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2.dcl")))
```

Dengan pola ini:
- Setiap pemanggilan `(findfile ...)` mengembalikan string path lengkap (jika ditemukan) atau `nil` (jika tidak ditemukan).
- Begitu salah satu file ditemukan, `(null dclFile)` bernilai `nil` sehingga pencarian berikutnya tidak dijalankan.
- Ketika masuk ke cabang `else` dari `(if (null dclFile) ...)`, variabel `dclFile` dijamin berupa string path valid sebelum diteruskan ke `(load_dialog dclFile)` maupun `(strcat ...)` pada pesan error.

## 2. Hasil Pemeriksaan Statis (Static Verification)

Seluruh pemeriksaan berikut dilakukan secara statis terhadap file hasil build di lingkungan sandbox (**terpisah dari pengujian runtime AutoCAD 2021**):

| No | Kriteria Validasi Statis | Hasil | Bukti Teknis |
| :--- | :--- | :--- | :--- |
| 1 | Zero pola `(or (findfile ...))` | **LULUS** | 0 kemunculan regex `\(\s*or\s+\(\s*findfile` di seluruh `ASGRID_V2_2_1_R3.lsp`. |
| 2 | Kedua perintah (`c:ASGRID` & `c:ASGRIDEDIT`) diperbaiki | **LULUS** | 2 blok pencarian `setq` + `if` ditemukan pada baris 2969–2972 (`c:ASGRID`) dan baris 4113–4116 (`c:ASGRIDEDIT`). |
| 3 | `load_dialog` hanya menerima path string valid | **LULUS** | Kedua panggilan `(load_dialog dclFile)` (baris 2986 dan 4123) berada di cabang `else` dari `(if (null dclFile) ...)`. |
| 4 | Fallback nama file lama dipertahankan | **LULUS** | Urutan eksplisit: `R3.dcl` → `R2.dcl` → `V2_2_1.dcl` → `V2_2.dcl`. |
| 5 | DCL R3 identik *byte-per-byte* dengan DCL R2 | **LULUS** | Ukuran 12.745 byte; SHA-256 R2 dan R3 identik: `e0e5013365adb7990f9b83b851da80cc658797e05d7a5ef03651d571574f05d3`. |
| 6 | Nol perubahan pada metadata, XRecord, generator, transaksi, & `ASGRIDCHECK` | **LULUS** | Total 89 `defun` identik; unified diff mengonfirmasi tidak ada satu baris pun berubah di luar header L5 serta blok DCL `c:ASGRID` dan `c:ASGRIDEDIT`. |
| 7 | Keseimbangan tanda kurung & string literal AutoLISP | **LULUS** | Seimbang penuh (`depth = 0`, `max_depth = 20`, 4.202 baris, 0 string tidak tertutup). |
| 8 | Integritas file `.lsp` & `.dcl` pasca-konsolidasi dokumentasi | **LULUS** | SHA-256 `ASGRID_V2_2_1_R3.lsp` (`c97af3f59dbece69f7caab4dcd2d94af2e8f05d1f72743eaa04c120ff685570b`) dan `ASGRID_V2_2_1_R3.dcl` tidak berubah selama konsolidasi dokumentasi. |

**Catatan Komentar Header DCL:** Baris 2 pada `ASGRID_V2_2_1_R3.dcl` masih memuat komentar `// FILE : ASGRID_V2_2.dcl`. File `.dcl` sengaja dibiarkan utuh tanpa modifikasi untuk mempertahankan kesamaan *byte-per-byte* dengan baseline R2 serta mematuhi aturan tidak mengubah file `.lsp` maupun `.dcl`; komentar tersebut tidak memengaruhi perilaku runtime AutoCAD 2021.

## 3. Status Pengujian Runtime (AutoCAD 2021)

- **Dikonfirmasi Pengguna:** Pengguna mengonfirmasi bahwa **ASGRID V2.2.1 R3 berhasil dijalankan kembali di AutoCAD 2021** setelah perbaikan pencarian file DCL.
- **Belum Dikonfirmasi Secara Individual:** Eksekusi dan hasil masing-masing skenario checklist pada `revision3_testing_checklist.md` (T-01 s.d. T-10), termasuk uji fallback DCL (T-08) dan skenario rollback/error-path XRecord R1/R2 secara langsung di AutoCAD 2021, **belum dikonfirmasi pelaksanaannya satu per satu**.

## 4. Unified Diff (R2 → R3) & Penjelasan Tiap Perubahan

```diff
--- ASGRID V2.2.1 REVISION 2/ASGRID_V2_2_1_R2.lsp
+++ ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp
@@ -3,5 +3,5 @@
 ;;; TARGET      : AutoCAD 2021 (AutoLISP Standar + DCL)
 ;;; BASELINE    : ASGRID_V2_1_2.lsp (V2.1.2 tetap dipertahankan sebagai backup)
-;;; FILE TERKAIT: ASGRID_V2_2.dcl (harus tersedia di Support File Search Path)
+;;; FILE TERKAIT: ASGRID_V2_2_1_R3.dcl (harus tersedia di Support File Search Path)
 ;;; UNIT        : Millimeter (mm) pada Model Space (WCS)
 ;;; COMMANDS    :
@@ -2967,15 +2967,18 @@
   ;; ALUR UTAMA PROGRAM ASGRID V2.2
   ;; --------------------------------------------------------------------------
-  (setq dclFile (or (findfile "ASGRID_V2_2_1_R2.dcl") (findfile "ASGRID_V2_2_1.dcl") (findfile "ASGRID_V2_2.dcl")))
+  (setq dclFile (findfile "ASGRID_V2_2_1_R3.dcl"))
+  (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1_R2.dcl")))
+  (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1.dcl")))
+  (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2.dcl")))
   (if (null dclFile)
     (progn
       (alert
         (strcat
-          "File dialog 'ASGRID_V2_2_1_R2.dcl' tidak ditemukan!\n\n"
-          "Pastikan 'ASGRID_V2_2_1_R2.dcl' disimpan pada folder yang terdaftar di\n"
+          "File dialog 'ASGRID_V2_2_1_R3.dcl' tidak ditemukan!\n\n"
+          "Pastikan 'ASGRID_V2_2_1_R3.dcl' disimpan pada folder yang terdaftar di\n"
           "AutoCAD Options -> Files -> Support File Search Path."
         )
       )
-      (princ (strcat "\n[" VER_LABEL " ERROR] File 'ASGRID_V2_2_1_R2.dcl' tidak ditemukan."))
+      (princ (strcat "\n[" VER_LABEL " ERROR] File 'ASGRID_V2_2_1_R3.dcl' tidak ditemukan."))
       (princ)
     )
@@ -2984,6 +2987,6 @@
       (if (or (null dclId) (< dclId 0))
         (progn
-          (alert "Gagal memuat file dialog 'ASGRID_V2_2.dcl'.")
-          (princ (strcat "\n[" VER_LABEL " ERROR] load_dialog gagal untuk 'ASGRID_V2_2_1_R2.dcl'."))
+          (alert (strcat "Gagal memuat file dialog '" dclFile "'."))
+          (princ (strcat "\n[" VER_LABEL " ERROR] load_dialog gagal untuk '" dclFile "'."))
           (princ)
         )
@@ -2992,5 +2995,5 @@
             (unload_dialog dclId)
             (setq dclId nil)
-            (alert "Definisi dialog 'asgrid_v2_2' tidak ditemukan di dalam 'ASGRID_V2_2_1_R2.dcl'.")
+            (alert (strcat "Definisi dialog 'asgrid_v2_2' tidak ditemukan di dalam '" dclFile "'."))
             (princ (strcat "\n[" VER_LABEL " ERROR] new_dialog gagal untuk 'asgrid_v2_2'."))
             (princ)
@@ -4108,9 +4111,12 @@
       )
 
-      (setq dclFile (or (findfile "ASGRID_V2_2_1_R2.dcl") (findfile "ASGRID_V2_2_1.dcl") (findfile "ASGRID_V2_2.dcl")))
+      (setq dclFile (findfile "ASGRID_V2_2_1_R3.dcl"))
+      (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1_R2.dcl")))
+      (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1.dcl")))
+      (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2.dcl")))
       (if (null dclFile)
         (progn
-          (alert "File dialog 'ASGRID_V2_2_1_R2.dcl' tidak ditemukan pada Support File Search Path.")
-          (princ (strcat "\n[" VER_LABEL " ERROR] File 'ASGRID_V2_2_1_R2.dcl' tidak ditemukan."))
+          (alert "File dialog 'ASGRID_V2_2_1_R3.dcl' tidak ditemukan pada Support File Search Path.")
+          (princ (strcat "\n[" VER_LABEL " ERROR] File 'ASGRID_V2_2_1_R3.dcl' tidak ditemukan."))
         )
         (progn
@@ -4118,6 +4124,6 @@
           (if (or (null dclId) (< dclId 0))
             (progn
-              (alert "Gagal memuat file dialog 'ASGRID_V2_2.dcl'.")
-              (princ (strcat "\n[" VER_LABEL " ERROR] load_dialog gagal."))
+              (alert (strcat "Gagal memuat file dialog '" dclFile "'."))
+              (princ (strcat "\n[" VER_LABEL " ERROR] load_dialog gagal untuk '" dclFile "'."))
             )
             (if (not (new_dialog "asgrid_edit_v2_2" dclId))
@@ -4125,5 +4131,5 @@
                 (unload_dialog dclId)
                 (setq dclId nil)
-                (alert "Definisi dialog 'asgrid_edit_v2_2' tidak ditemukan di dalam 'ASGRID_V2_2_1_R2.dcl'.")
+                (alert (strcat "Definisi dialog 'asgrid_edit_v2_2' tidak ditemukan di dalam '" dclFile "'."))
                 (princ (strcat "\n[" VER_LABEL " ERROR] new_dialog gagal untuk 'asgrid_edit_v2_2'."))
               )
```

### Penjelasan Tiap Hunk Perubahan

1. **Hunk 1 (Baris 5):** Memperbarui komentar header `FILE TERKAIT` dari `ASGRID_V2_2.dcl` menjadi `ASGRID_V2_2_1_R3.dcl` agar selaras dengan file DCL R3.
2. **Hunk 2 (Baris 2969–2982, `c:ASGRID`):** Mengganti `(or (findfile ...))` dengan 4 baris pencarian berurutan `setq` + `if` (`R3` → `R2` → `V2_2_1` → `V2_2`), serta menyelaraskan pesan error file tidak ditemukan ke `'ASGRID_V2_2_1_R3.dcl'`.
3. **Hunk 3 & 4 (Baris 2987–2998, `c:ASGRID`):** Memperbarui pesan kegagalan `load_dialog` (yang sebelumnya masih menyebut `'ASGRID_V2_2.dcl'`) dan `new_dialog` agar menampilkan `dclFile` aktual yang benar-benar dicoba dimuat.
4. **Hunk 5 (Baris 4111–4121, `c:ASGRIDEDIT`):** Menerapkan perbaikan pencarian berurutan `setq` + `if` yang sama pada `c:ASGRIDEDIT` untuk menutup bug laten identik, serta memperbarui pesan file tidak ditemukan ke `'ASGRID_V2_2_1_R3.dcl'`.
5. **Hunk 6 & 7 (Baris 4124–4134, `c:ASGRIDEDIT`):** Memperbarui pesan kegagalan `load_dialog` (sebelumnya `'ASGRID_V2_2.dcl'`) dan `new_dialog` agar menampilkan `dclFile` aktual.
