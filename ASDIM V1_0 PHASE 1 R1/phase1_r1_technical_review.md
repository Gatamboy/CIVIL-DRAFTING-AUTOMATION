# Technical Review — ASDIM V1.0 Phase 1 Revision 1 (Narrow Validation Hardening)

**File Diulas:** `ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp` (SHA-256: `ad4add162aded6a5887117245ab37441a0a3d9380cfdf5406d6188642897eabf`)  
**Baseline:** `ASDIM V1_0 PHASE 1/ASDIM_V1_0_PHASE1.lsp` (SHA-256 utuh: `35c17e8c9f3c3443309ad0bf4fc74d353e5d558d34fe80664b9139eaee11e977`)  
**Acuan ASGRID R3:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` (SHA-256 utuh: `c97af3f59dbece69f7caab4dcd2d94af2e8f05d1f72743eaa04c120ff685570b`)

## 1. Dua Celah Validasi yang Diperbaiki

### A. Konsistensi `SCHEMA_VER` XData vs. Metadata XRecord
Pada Phase 1 awal, `asdim:parse-asgrid-xdata` mengekstrak `SCHEMA_VER` dari XData `ASGRID_OBJ`, tetapi nilai tersebut belum diteruskan ke `asdim:meta-validate-spec`. Pada Revision 1:
1. `c:ASDIM` mengekstrak `xSchemaVer` dari hasil `asdim:parse-asgrid-xdata` (L1119–L1120) dan meneruskannya ke `(asdim:meta-validate-spec spec groupId xSchemaVer)` (L1128).
2. `asdim:meta-validate-spec` (L443–L460) memverifikasi secara eksplisit:
   - `xdataSchemaVer` bertipe string (`(= (type xdataSchemaVer) 'STR)`).
   - `xdataSchemaVer` sama dengan `"1.0"` (`(asdim:schema-ver)`).
   - `SCHEMA_VER` metadata XRecord sama dengan `"1.0"`.
   - `xdataSchemaVer` sama dengan `SCHEMA_VER` metadata XRecord.
3. Kegagalan salah satu syarat langsung menambahkan pesan error spesifik ke `errs`, menyebabkan `VALID = nil`, menampilkan laporan audit kegagalan, dan menghentikan proses sebelum audit geometri dijalankan.

### B. Validasi Kontrak Nilai `AXIS_DIR_H` dan `AXIS_DIR_V`
Berdasarkan audit langsung `ASGRID_V2_2_1_R3.lsp` (`fn-meta-build-spec`, L2219–L2220):
- `AXIS_DIR_H` ditetapkan tepat `"X"` (garis horizontal sejajar sumbu X).
- `AXIS_DIR_V` ditetapkan tepat `"Y"` (garis vertikal sejajar sumbu Y).

Pada Phase 1 awal, `asdim:meta-validate-spec` hanya mengecek bahwa kedua key berupa string tidak kosong. Pada Revision 1 (L463–L469), `asdim:meta-validate-spec` menolak metadata bila `AXIS_DIR_H /= "X"` atau `AXIS_DIR_V /= "Y"`, sehingga audit geometri tidak dilanjutkan dan kalkulator koordinat WCS tetap utuh tanpa perubahan.

## 2. Hasil Pemeriksaan Statis (Static Verification)

| No | Kriteria Pemeriksaan Statis | Hasil | Bukti |
| :--- | :--- | :--- | :--- |
| 1 | Keseimbangan tanda kurung & string literal | **LULUS** | `depth = 0`, `max_depth = 19`, 1.154 baris, 0 string tidak tertutup. |
| 2 | Duplikasi nama fungsi | **LULUS** | 31 `defun` identik dengan Phase 1, 0 duplikasi. |
| 3 | Scope local variable | **LULUS** | Variabel baru `axH`, `axV` (pada `asdim:meta-validate-spec`) dan `xSchemaVer` (pada `c:ASDIM`) seluruhnya dideklarasikan lokal; 0 variabel global. |
| 4 | **Keamanan 100% READ-ONLY** | **LULUS** | **0 panggilan** pada fungsi mutasi/DCL (`entmake`, `entmakex`, `entmod`, `entupd`, `entdel`, `dictadd`, `dictremove`, `dictrename`, `regapp`, `setvar`, `command`, `command-s`, `vla-add`, `vla-delete`, `vla-put-`, `load_dialog`, `new_dialog`, `start_dialog`, `findfile`). |
| 5 | Keutuhan baseline Phase 1 & ASGRID R3 | **LULUS** | SHA-256 `ASDIM_V1_0_PHASE1.lsp`, `ASGRID_V2_2_1_R3.lsp`, dan `ASGRID_V2_2_1_R3.dcl` 100% tidak berubah. |

## 3. Unified Diff (`ASDIM_V1_0_PHASE1.lsp` → `ASDIM_V1_0_PHASE1_R1.lsp`)

```diff
--- ASDIM V1_0 PHASE 1/ASDIM_V1_0_PHASE1.lsp
+++ ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp
@@ -1,4 +1,4 @@
 ;;; ============================================================================
-;;; PROGRAM     : ASDIM V1.0 — PHASE 1 (FOUNDATION & READ-ONLY AUDIT)
+;;; PROGRAM     : ASDIM V1.0 — PHASE 1 REVISION 1 (NARROW VALIDATION HARDENING)
 ;;; PROYEK      : CIVIL DRAFTING AUTOMATION
 ;;; TARGET      : AutoCAD 2021 (AutoLISP Standar — 100% READ-ONLY)
@@ -18,5 +18,5 @@
 ;;; ============================================================================
 
-(defun asdim:version-label () "ASDIM V1.0-Phase1")
+(defun asdim:version-label () "ASDIM V1.0-Phase1-R1")
 (defun asdim:dict-name () "ASGRID_GROUPS")
 (defun asdim:xdata-app () "ASGRID_OBJ")
@@ -397,9 +397,9 @@
 ;;   (("VALID" . T|nil) ("ERRORS" . (...)) ("WARNINGS" . (...))
 ;;    ("CAN_DIM_H" . T|nil) ("CAN_DIM_V" . T|nil))
-(defun asdim:meta-validate-spec (spec expectedGroupId /
+(defun asdim:meta-validate-spec (spec expectedGroupId xdataSchemaVer /
                                   errs warns readErrs reqKeys k v
                                   nH nV cntH cntV dH dV bp elev
                                   sc th bd ex aExt bPos sver gid
-                                  canDimH canDimV tol)
+                                  axH axV canDimH canDimV tol)
   (setq errs    '()
         warns   '()
@@ -440,12 +440,30 @@
       )
 
-      ;; 2. Validasi SCHEMA_VER = "1.0" & kecocokan GROUP_ID
+      ;; 2. Validasi konsistensi SCHEMA_VER (XData & Metadata = "1.0") & kecocokan GROUP_ID
       (setq sver (cdr (assoc "SCHEMA_VER" spec))
-            gid  (cdr (assoc "GROUP_ID" spec)))
+            gid  (cdr (assoc "GROUP_ID" spec))
+            axH  (cdr (assoc "AXIS_DIR_H" spec))
+            axV  (cdr (assoc "AXIS_DIR_V" spec)))
+      (if (not (= (type xdataSchemaVer) 'STR))
+        (setq errs (append errs (list "SCHEMA_VER pada XData ASGRID_OBJ bukan string valid.")))
+        (if (/= xdataSchemaVer (asdim:schema-ver))
+          (setq errs (append errs (list (strcat "SCHEMA_VER XData tidak didukung: '" xdataSchemaVer "' (diharapkan '" (asdim:schema-ver) "')."))))
+        )
+      )
       (if (and (= (type sver) 'STR) (/= sver (asdim:schema-ver)))
-        (setq errs (append errs (list (strcat "SCHEMA_VER tidak didukung: '" sver "' (diharapkan '" (asdim:schema-ver) "')."))))
+        (setq errs (append errs (list (strcat "SCHEMA_VER metadata XRecord tidak didukung: '" sver "' (diharapkan '" (asdim:schema-ver) "')."))))
+      )
+      (if (and (= (type xdataSchemaVer) 'STR) (= (type sver) 'STR) (/= xdataSchemaVer sver))
+        (setq errs (append errs (list (strcat "SCHEMA_VER XData ('" xdataSchemaVer "') tidak sama dengan SCHEMA_VER metadata ('" sver "')."))))
       )
       (if (and (= (type expectedGroupId) 'STR) (= (type gid) 'STR) (/= gid expectedGroupId))
         (setq errs (append errs (list (strcat "GROUP_ID metadata ('" gid "') tidak cocok dengan XData ('" expectedGroupId "')."))))
+      )
+      ;; 2b. Validasi kontrak AXIS_DIR_H = "X" dan AXIS_DIR_V = "Y" (ASGRID R3 L2219-L2220)
+      (if (and (= (type axH) 'STR) (/= axH "X"))
+        (setq errs (append errs (list (strcat "AXIS_DIR_H tidak valid: '" axH "' (harus tepat 'X')."))))
+      )
+      (if (and (= (type axV) 'STR) (/= axV "Y"))
+        (setq errs (append errs (list (strcat "AXIS_DIR_V tidak valid: '" axV "' (harus tepat 'Y')."))))
       )
 
@@ -1061,5 +1079,5 @@
 ;;; ============================================================================
 
-(defun c:ASDIM ( / *error* sel ename xRes xStatus groupId
+(defun c:ASDIM ( / *error* sel ename xRes xStatus groupId xSchemaVer
                    readRes spec metaRes coords disc geomRes)
 
@@ -1098,5 +1116,6 @@
            (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" xRes))))
            (progn
-             (setq groupId (cdr (assoc "GROUP_ID" xRes)))
+             (setq groupId    (cdr (assoc "GROUP_ID" xRes))
+                   xSchemaVer (cdr (assoc "SCHEMA_VER" xRes)))
              ;; Langkah 4: Baca metadata grup dari NOD ASGRID_GROUPS (read-only)
              (setq readRes (asdim:meta-read-group groupId))
@@ -1105,6 +1124,6 @@
                (progn
                  (setq spec    (cdr (assoc "SPEC" readRes))
-                       ;; Langkah 5: Validasi kelengkapan & konsistensi metadata
-                       metaRes (asdim:meta-validate-spec spec groupId))
+                       ;; Langkah 5: Validasi kelengkapan & konsistensi metadata (termasuk SCHEMA_VER XData)
+                       metaRes (asdim:meta-validate-spec spec groupId xSchemaVer))
                  (if (not (cdr (assoc "VALID" metaRes)))
                    (asdim:print-audit-report groupId spec metaRes nil nil nil)
@@ -1131,4 +1150,4 @@
 
 ;; Pesan muat saat APPLOAD (100% read-only)
-(princ "\n[ASDIM V1.0-Phase1] Berhasil dimuat (100% READ-ONLY Audit). Perintah: ASDIM.")
+(princ "\n[ASDIM V1.0-Phase1-R1] Berhasil dimuat (100% READ-ONLY Audit). Perintah: ASDIM.")
 (princ)
```

## 4. Status Pengujian Runtime

- **Status:** **NOT RUN** — belum diuji langsung di AutoCAD 2021. Seluruh 26 skenario pada `phase1_r1_testing_checklist.md` menunggu eksekusi langsung oleh pengguna.
