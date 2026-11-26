;;; ============================================================================
;;; PROGRAM     : ASDIM V1.0 — PHASE 1 REVISION 1 (NARROW VALIDATION HARDENING)
;;; PROYEK      : CIVIL DRAFTING AUTOMATION
;;; TARGET      : AutoCAD 2021 (AutoLISP Standar — 100% READ-ONLY)
;;; ACUAN SPEK  : ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md
;;; ACUAN ASGRID: ASGRID V2.2.1 R3/ASGRID_V2_2_1_R3.lsp (Schema 1.0)
;;; COMMAND     : ASDIM
;;; KEAMANAN    :
;;;   - 100% READ-ONLY: Nol mutasi entitas, XData, XRecord, NOD, RegApp, Layer,
;;;     Text Style, Dimension Style, maupun system variable AutoCAD.
;;;   - Phase 1 hanya membaca metadata ASGRID R3, memvalidasi konsistensi
;;;     metadata & geometri garis grid pada Model Space, lalu menampilkan
;;;     laporan audit pada command line. Belum membuat DIMENSION maupun DCL.
;;; ============================================================================

;;; ============================================================================
;;; SECTION 1: UTILITY FUNCTIONS (STATELESS, PREFIX: asdim:*)
;;; ============================================================================

(defun asdim:version-label () "ASDIM V1.0-Phase1-R1")
(defun asdim:dict-name () "ASGRID_GROUPS")
(defun asdim:xdata-app () "ASGRID_OBJ")
(defun asdim:schema-ver () "1.0")
(defun asdim:valid-bubble-positions () '("Both Ends" "Start" "End"))
(defun asdim:tol-meta () 1e-6)
(defun asdim:tol-geom () 1e-4)

;; Hapus spasi dan tab di awal/akhir string
(defun asdim:trim (s / res)
  (if (not (= (type s) 'STR))
    ""
    (progn
      (setq res s)
      (while (and (> (strlen res) 0)
                  (member (substr res 1 1) '(" " "\t")))
        (setq res (substr res 2))
      )
      (while (and (> (strlen res) 0)
                  (member (substr res (strlen res) 1) '(" " "\t")))
        (setq res (substr res 1 (1- (strlen res))))
      )
      res
    )
  )
)

;; Konversi indeks 1-based menjadi label alfabet (1->A, 26->Z, 27->AA)
(defun asdim:index-to-alpha (idx / n remVal res)
  (setq n   idx
        res "")
  (while (> n 0)
    (setq remVal (rem (1- n) 26)
          res    (strcat (chr (+ 65 remVal)) res)
          n      (/ (1- n) 26))
  )
  res
)

;; Format angka real untuk laporan command line (tanpa mengubah system variable)
(defun asdim:format-real (val / )
  (if (numberp val)
    (rtos (float val) 2 4)
    "<non-numeric>"
  )
)

;; Format titik 3D WCS untuk laporan command line
(defun asdim:format-pt (pt / )
  (if (and (listp pt) (= (length pt) 3)
           (numberp (nth 0 pt)) (numberp (nth 1 pt)) (numberp (nth 2 pt)))
    (strcat "("
            (asdim:format-real (nth 0 pt)) ", "
            (asdim:format-real (nth 1 pt)) ", "
            (asdim:format-real (nth 2 pt)) ")")
    "<titik-tidak-valid>"
  )
)

;; Bandingkan dua titik 3D WCS dalam toleransi numerik
(defun asdim:pt-equal-p (p1 p2 tol / )
  (and (listp p1) (= (length p1) 3)
       (listp p2) (= (length p2) 3)
       (<= (abs (- (float (nth 0 p1)) (float (nth 0 p2)))) tol)
       (<= (abs (- (float (nth 1 p1)) (float (nth 1 p2)))) tol)
       (<= (abs (- (float (nth 2 p1)) (float (nth 2 p2)))) tol))
)

;; Hitung jarak Euclidean 3D antara dua titik
(defun asdim:pt-dist-3d (p1 p2 / dx dy dz)
  (setq dx (- (float (nth 0 p1)) (float (nth 0 p2)))
        dy (- (float (nth 1 p1)) (float (nth 1 p2)))
        dz (- (float (nth 2 p1)) (float (nth 2 p2))))
  (sqrt (+ (* dx dx) (* dy dy) (* dz dz)))
)

;; Cek apakah sebuah entity valid dan berada di Model Space (DXF 410 & 67)
(defun asdim:is-model-space-entity (ename / ed tabName c67)
  (if (and ename (= (type ename) 'ENAME))
    (progn
      (setq ed (entget ename))
      (if ed
        (progn
          (setq tabName (cdr (assoc 410 ed))
                c67     (cdr (assoc 67 ed)))
          (and (= (type tabName) 'STR)
               (= (strcase tabName) "MODEL")
               (or (null c67) (= c67 0)))
        )
        nil
      )
    )
    nil
  )
)

;; Resolver ANNO_EXT_LEN dengan fallback otomatis ke EXT_LEN (identik ASGRID R3 L395)
(defun asdim:get-anno-ext-len (spec / aExt gExt)
  (setq aExt (cdr (assoc "ANNO_EXT_LEN" spec))
        gExt (cdr (assoc "EXT_LEN" spec)))
  (cond
    ((and (numberp aExt) (> aExt 0.0)) (float aExt))
    ((and (numberp gExt) (> gExt 0.0)) (float gExt))
    (t nil)
  )
)

;; Format daftar interval numerik menjadi string ringkas
(defun asdim:format-real-list (lst / res item firstFlag)
  (if (or (null lst) (not (listp lst)))
    "-"
    (progn
      (setq res       ""
            firstFlag T)
      (foreach item lst
        (if firstFlag
          (setq res       (asdim:format-real item)
                firstFlag nil)
          (setq res (strcat res ", " (asdim:format-real item)))
        )
      )
      res
    )
  )
)

;;; ============================================================================
;;; SECTION 2: XDATA READER (ASGRID_OBJ — 100% READ-ONLY)
;;; Acuan: asgrid:parse-entity-xdata-for-app (ASGRID_V2_2_1_R3.lsp L456-L489)
;;; Struktur aktual 6 field:
;;;   (1000 . GroupID) (1000 . Role) (1000 . AxisDir)
;;;   (1070 . AxisIdx) (1000 . EndTag) (1000 . SchemaVer)
;;; ============================================================================

;; Mengembalikan asosiasi status:
;;   (("STATUS" . "OK") ("GROUP_ID" . ...) ("ROLE" . ...) ("AXIS_DIR" . ...)
;;    ("AXIS_IDX" . ...) ("END_TAG" . ...) ("SCHEMA_VER" . ...))
;; atau (("STATUS" . "NO_XDATA"|"CORRUPT"|"INVALID_ENAME") ("ERROR" . "..."))
(defun asdim:parse-asgrid-xdata (ename / entData xrec vals gid role dir idx etag sver)
  (if (or (null ename) (not (= (type ename) 'ENAME)) (null (entget ename)))
    (list (cons "STATUS" "INVALID_ENAME")
          (cons "ERROR" "Entity tidak valid atau sudah terhapus."))
    (progn
      (setq entData (entget ename (list (asdim:xdata-app)))
            xrec    (cadr (assoc -3 entData)))
      (cond
        ((null xrec)
         (list (cons "STATUS" "NO_XDATA")
               (cons "ERROR" (strcat "Entity tidak memiliki XData RegApp '" (asdim:xdata-app) "'."))))
        ((< (length (cdr xrec)) 6)
         (list (cons "STATUS" "CORRUPT")
               (cons "ERROR" "Struktur XData ASGRID_OBJ tidak lengkap (< 6 field).")))
        (t
         (setq vals (cdr xrec)
               gid  (if (= (car (nth 0 vals)) 1000) (cdr (nth 0 vals)) nil)
               role (if (= (car (nth 1 vals)) 1000) (cdr (nth 1 vals)) nil)
               dir  (if (= (car (nth 2 vals)) 1000) (cdr (nth 2 vals)) nil)
               idx  (if (= (car (nth 3 vals)) 1070) (cdr (nth 3 vals)) nil)
               etag (if (= (car (nth 4 vals)) 1000) (cdr (nth 4 vals)) nil)
               sver (if (= (car (nth 5 vals)) 1000) (cdr (nth 5 vals)) nil))
         (if (and (= (type gid) 'STR) (> (strlen (asdim:trim gid)) 0)
                  (member role '("LINE" "BUBBLE" "TEXT"))
                  (member dir '("H" "V"))
                  (= (type idx) 'INT) (> idx 0)
                  (member etag '("NONE" "START" "END"))
                  (= (type sver) 'STR) (> (strlen (asdim:trim sver)) 0))
           (list (cons "STATUS"     "OK")
                 (cons "GROUP_ID"   gid)
                 (cons "ROLE"       role)
                 (cons "AXIS_DIR"   dir)
                 (cons "AXIS_IDX"   idx)
                 (cons "END_TAG"    etag)
                 (cons "SCHEMA_VER" sver))
           (list (cons "STATUS" "CORRUPT")
                 (cons "ERROR" "Nilai atau tipe data field XData ASGRID_OBJ tidak valid."))
         ))
      )
    )
  )
)

;;; ============================================================================
;;; SECTION 3: NOD DICTIONARY READER (ASGRID_GROUPS — 100% READ-ONLY)
;;; Acuan: asgrid:meta-get-root-dict (L406-L435) & asgrid:meta-read-group (L659)
;;; ============================================================================

;; Ambil ename dictionary ASGRID_GROUPS di NOD tanpa pernah membuatnya
(defun asdim:nod-get-asgrid-dict ( / nod dictRec dictEname)
  (setq nod (namedobjdict))
  (if nod
    (progn
      (setq dictRec (dictsearch nod (asdim:dict-name)))
      (if dictRec
        (progn
          (setq dictEname (cdr (assoc -1 dictRec)))
          (if (and dictEname (= (cdr (assoc 0 (entget dictEname))) "DICTIONARY"))
            dictEname
            nil
          )
        )
        nil
      )
    )
    nil
  )
)

;; Cari entri XRecord untuk GROUP_ID tertentu di dalam dictionary ASGRID_GROUPS
;; Mengembalikan asosiasi:
;;   (("STATUS" . "OK") ("XREC_ENAME" . ename))
;; atau status "NO_DICT" | "INVALID_GROUP_ID" | "GROUP_NOT_FOUND" | "INVALID_XRECORD"
(defun asdim:nod-find-group-xrecord (groupId / rootDict rec xrecEname dList)
  (cond
    ((or (not (= (type groupId) 'STR)) (= (strlen (asdim:trim groupId)) 0))
     (list (cons "STATUS" "INVALID_GROUP_ID")
           (cons "ERROR" "GROUP_ID kosong atau bukan string valid.")))
    ((null (setq rootDict (asdim:nod-get-asgrid-dict)))
     (list (cons "STATUS" "NO_DICT")
           (cons "ERROR" (strcat "Named Object Dictionary '" (asdim:dict-name) "' tidak ditemukan pada gambar."))))
    ((null (setq rec (dictsearch rootDict groupId)))
     (list (cons "STATUS" "GROUP_NOT_FOUND")
           (cons "ERROR" (strcat "GROUP_ID '" groupId "' tidak ditemukan di dalam dictionary '" (asdim:dict-name) "'."))))
    (t
     (setq xrecEname (cdr (assoc -1 rec))
           dList     (if xrecEname (entget xrecEname) nil))
     (if (and xrecEname
              dList
              (= (cdr (assoc 0 dList)) "XRECORD")
              (member '(100 . "AcDbXrecord") dList))
       (list (cons "STATUS" "OK")
             (cons "XREC_ENAME" xrecEname)
             (cons "XREC_DXF" dList))
       (list (cons "STATUS" "INVALID_XRECORD")
             (cons "ERROR" (strcat "Entri NOD untuk '" groupId "' bukan objek XRECORD (AcDbXrecord) yang valid.")))
     ))
  )
)

;;; ============================================================================
;;; SECTION 4: XRECORD READER (100% READ-ONLY)
;;; Acuan: asgrid:meta-parse-xrecord-dxf (ASGRID_V2_2_1_R3.lsp L577-L656)
;;; ============================================================================

(defun asdim:xrec-parse-dxf (dList / res dH dV readErrs curKey pair code val seenMarker)
  (if (or (null dList)
          (not (listp dList))
          (/= (cdr (assoc 0 dList)) "XRECORD")
          (not (member '(100 . "AcDbXrecord") dList)))
    nil
    (progn
      (setq res        '()
            dH         '()
            dV         '()
            readErrs   '()
            curKey     nil
            seenMarker nil)
      (foreach pair dList
        (if (and (listp pair) (numberp (car pair)))
          (progn
            (setq code (car pair)
                  val  (cdr pair))
            (if (not seenMarker)
              (if (and (= code 100) (= val "AcDbXrecord"))
                (setq seenMarker T)
              )
              (cond
                ((= code 300)
                 (if curKey
                   (setq readErrs (append readErrs
                     (list (strcat "Key XRecord tanpa nilai: " curKey))))
                 )
                 (setq curKey (if (= (type val) 'STR) val nil))
                 (if (null curKey)
                   (setq readErrs (append readErrs
                     (list "Terdapat pasangan DXF 300 non-string pada XRecord.")))
                 ))
                ((and curKey (member code '(1 10 40 70 90)))
                 (cond
                   ((= curKey "DIST_H_ITEM")
                    (if (numberp val)
                      (setq dH (append dH (list (float val))))
                      (setq readErrs (append readErrs
                        (list "Nilai DIST_H_ITEM pada XRecord bukan numerik.")))
                    ))
                   ((= curKey "DIST_V_ITEM")
                    (if (numberp val)
                      (setq dV (append dV (list (float val))))
                      (setq readErrs (append readErrs
                        (list "Nilai DIST_V_ITEM pada XRecord bukan numerik.")))
                    ))
                   ((member curKey '("ELEVATION" "SCALE_DENOM" "TEXT_H_PRINT"
                                     "BUBBLE_DIA_PRINT" "EXT_LEN" "ANNO_EXT_LEN"))
                    (if (assoc curKey res)
                      (setq readErrs (append readErrs
                        (list (strcat "Key skalar duplikat pada XRecord: " curKey))))
                    )
                    (if (numberp val)
                      (setq res (append res (list (cons curKey (float val)))))
                      (setq readErrs (append readErrs
                        (list (strcat "Nilai " curKey " pada XRecord bukan numerik."))))
                    ))
                   ((member curKey '("NUM_H" "NUM_V" "DIST_H_COUNT" "DIST_V_COUNT"))
                    (if (assoc curKey res)
                      (setq readErrs (append readErrs
                        (list (strcat "Key skalar duplikat pada XRecord: " curKey))))
                    )
                    (if (= (type val) 'INT)
                      (setq res (append res (list (cons curKey val))))
                      (setq readErrs (append readErrs
                        (list (strcat "Nilai " curKey " pada XRecord bukan integer."))))
                    ))
                   ((= curKey "BASE_PT_WCS")
                    (if (assoc curKey res)
                      (setq readErrs (append readErrs
                        (list "Key skalar duplikat pada XRecord: BASE_PT_WCS")))
                    )
                    (if (and (listp val) (= (length val) 3)
                             (numberp (nth 0 val)) (numberp (nth 1 val)) (numberp (nth 2 val)))
                      (setq res (append res (list (cons curKey
                                    (list (float (nth 0 val))
                                          (float (nth 1 val))
                                          (float (nth 2 val)))))))
                      (setq readErrs (append readErrs
                        (list "Nilai BASE_PT_WCS pada XRecord bukan titik 3D numerik.")))
                    ))
                   (t
                    (if (assoc curKey res)
                      (setq readErrs (append readErrs
                        (list (strcat "Key skalar duplikat pada XRecord: " curKey))))
                    )
                    (setq res (append res (list (cons curKey val)))))
                 )
                 (setq curKey nil))
              )
            )
          )
        )
      )
      (if curKey
        (setq readErrs (append readErrs
          (list (strcat "Key XRecord terakhir tanpa nilai: " curKey))))
      )
      (setq res (append res (list (cons "DIST_H" dH) (cons "DIST_V" dV))))
      (if readErrs
        (setq res (append res (list (cons "_READ_ERRORS" readErrs))))
      )
      res
    )
  )
)

;; Wrapper baca metadata lengkap untuk GROUP_ID (read-only)
;; Mengembalikan: (("STATUS" . "OK") ("SPEC" . specAlist)) atau status error
(defun asdim:meta-read-group (groupId / findRes dList spec)
  (setq findRes (asdim:nod-find-group-xrecord groupId))
  (if (/= (cdr (assoc "STATUS" findRes)) "OK")
    findRes
    (progn
      (setq dList (cdr (assoc "XREC_DXF" findRes))
            spec  (asdim:xrec-parse-dxf dList))
      (if (null spec)
        (list (cons "STATUS" "INVALID_XRECORD")
              (cons "ERROR" (strcat "Gagal mem-parsing payload XRecord untuk grup '" groupId "'.")))
        (list (cons "STATUS" "OK")
              (cons "SPEC" spec))
      )
    )
  )
)

;;; ============================================================================
;;; SECTION 5: METADATA VALIDATOR
;;; Acuan: asgrid:meta-validate-spec (ASGRID_V2_2_1_R3.lsp L1226-L1370)
;;; ============================================================================

;; Memvalidasi kelengkapan, tipe data, konsistensi interval, elevasi, dan skema
;; Mengembalikan:
;;   (("VALID" . T|nil) ("ERRORS" . (...)) ("WARNINGS" . (...))
;;    ("CAN_DIM_H" . T|nil) ("CAN_DIM_V" . T|nil))
(defun asdim:meta-validate-spec (spec expectedGroupId xdataSchemaVer /
                                  errs warns readErrs reqKeys k v
                                  nH nV cntH cntV dH dV bp elev
                                  sc th bd ex aExt bPos sver gid
                                  axH axV canDimH canDimV tol)
  (setq errs    '()
        warns   '()
        tol     (asdim:tol-meta)
        reqKeys '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER"
                  "NUM_H" "NUM_V" "DIST_H" "DIST_V"
                  "DIST_H_COUNT" "DIST_V_COUNT"
                  "BASE_PT_WCS" "ELEVATION" "AXIS_DIR_H" "AXIS_DIR_V"
                  "SCALE_DENOM" "TEXT_H_PRINT" "BUBBLE_DIA_PRINT"
                  "EXT_LEN" "BUBBLE_POS" "TEXT_STYLE" "FONT_FILE"
                  "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT"))

  (if (or (null spec) (not (listp spec)))
    (setq errs (list "Struktur metadata kosong atau bukan list valid."))
    (progn
      (setq readErrs (cdr (assoc "_READ_ERRORS" spec)))
      (if readErrs
        (setq errs (append errs readErrs))
      )
      (foreach k reqKeys
        (if (null (assoc k spec))
          (setq errs (append errs (list (strcat "Key metadata wajib hilang: " k))))
        )
      )
    )
  )

  (if (null errs)
    (progn
      ;; 1. Validasi string wajib tidak kosong
      (foreach k '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER"
                   "AXIS_DIR_H" "AXIS_DIR_V" "TEXT_STYLE" "FONT_FILE"
                   "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT")
        (setq v (cdr (assoc k spec)))
        (if (or (not (= (type v) 'STR)) (= (strlen (asdim:trim v)) 0))
          (setq errs (append errs (list (strcat "Nilai string tidak valid/kosong pada key: " k))))
        )
      )

      ;; 2. Validasi konsistensi SCHEMA_VER (XData & Metadata = "1.0") & kecocokan GROUP_ID
      (setq sver (cdr (assoc "SCHEMA_VER" spec))
            gid  (cdr (assoc "GROUP_ID" spec))
            axH  (cdr (assoc "AXIS_DIR_H" spec))
            axV  (cdr (assoc "AXIS_DIR_V" spec)))
      (if (not (= (type xdataSchemaVer) 'STR))
        (setq errs (append errs (list "SCHEMA_VER pada XData ASGRID_OBJ bukan string valid.")))
        (if (/= xdataSchemaVer (asdim:schema-ver))
          (setq errs (append errs (list (strcat "SCHEMA_VER XData tidak didukung: '" xdataSchemaVer "' (diharapkan '" (asdim:schema-ver) "')."))))
        )
      )
      (if (and (= (type sver) 'STR) (/= sver (asdim:schema-ver)))
        (setq errs (append errs (list (strcat "SCHEMA_VER metadata XRecord tidak didukung: '" sver "' (diharapkan '" (asdim:schema-ver) "')."))))
      )
      (if (and (= (type xdataSchemaVer) 'STR) (= (type sver) 'STR) (/= xdataSchemaVer sver))
        (setq errs (append errs (list (strcat "SCHEMA_VER XData ('" xdataSchemaVer "') tidak sama dengan SCHEMA_VER metadata ('" sver "')."))))
      )
      (if (and (= (type expectedGroupId) 'STR) (= (type gid) 'STR) (/= gid expectedGroupId))
        (setq errs (append errs (list (strcat "GROUP_ID metadata ('" gid "') tidak cocok dengan XData ('" expectedGroupId "')."))))
      )
      ;; 2b. Validasi kontrak AXIS_DIR_H = "X" dan AXIS_DIR_V = "Y" (ASGRID R3 L2219-L2220)
      (if (and (= (type axH) 'STR) (/= axH "X"))
        (setq errs (append errs (list (strcat "AXIS_DIR_H tidak valid: '" axH "' (harus tepat 'X')."))))
      )
      (if (and (= (type axV) 'STR) (/= axV "Y"))
        (setq errs (append errs (list (strcat "AXIS_DIR_V tidak valid: '" axV "' (harus tepat 'Y')."))))
      )

      ;; 3. Validasi NUM_H, NUM_V, DIST_H_COUNT, DIST_V_COUNT, DIST_H, DIST_V
      (setq nH   (cdr (assoc "NUM_H" spec))
            nV   (cdr (assoc "NUM_V" spec))
            cntH (cdr (assoc "DIST_H_COUNT" spec))
            cntV (cdr (assoc "DIST_V_COUNT" spec))
            dH   (cdr (assoc "DIST_H" spec))
            dV   (cdr (assoc "DIST_V" spec)))

      (if (or (not (= (type nH) 'INT)) (<= nH 0))
        (setq errs (append errs (list "NUM_H harus bilangan bulat > 0.")))
      )
      (if (or (not (= (type nV) 'INT)) (<= nV 0))
        (setq errs (append errs (list "NUM_V harus bilangan bulat > 0.")))
      )

      (if (or (not (= (type cntH) 'INT)) (< cntH 0))
        (setq errs (append errs (list "DIST_H_COUNT harus bilangan bulat >= 0.")))
      )
      (if (not (listp dH))
        (setq errs (append errs (list "DIST_H bukan list valid.")))
        (progn
          (if (and (= (type cntH) 'INT) (/= cntH (length dH)))
            (setq errs (append errs (list (strcat "DIST_H_COUNT (" (itoa cntH)
                                                  ") tidak sama dengan jumlah item DIST_H (" (itoa (length dH)) ")."))))
          )
          (if (and (= (type nH) 'INT) (> nH 0) (/= (length dH) (max 0 (1- nH))))
            (setq errs (append errs (list (strcat "Jumlah DIST_H (" (itoa (length dH))
                                                  ") tidak sama dengan NUM_H - 1 (" (itoa (max 0 (1- nH))) ")."))))
          )
          (foreach v dH
            (if (or (not (numberp v)) (<= v 0.0))
              (setq errs (append errs (list "Terdapat nilai DIST_H non-numerik atau <= 0.")))
            )
          )
        )
      )

      (if (or (not (= (type cntV) 'INT)) (< cntV 0))
        (setq errs (append errs (list "DIST_V_COUNT harus bilangan bulat >= 0.")))
      )
      (if (not (listp dV))
        (setq errs (append errs (list "DIST_V bukan list valid.")))
        (progn
          (if (and (= (type cntV) 'INT) (/= cntV (length dV)))
            (setq errs (append errs (list (strcat "DIST_V_COUNT (" (itoa cntV)
                                                  ") tidak sama dengan jumlah item DIST_V (" (itoa (length dV)) ")."))))
          )
          (if (and (= (type nV) 'INT) (> nV 0) (/= (length dV) (max 0 (1- nV))))
            (setq errs (append errs (list (strcat "Jumlah DIST_V (" (itoa (length dV))
                                                  ") tidak sama dengan NUM_V - 1 (" (itoa (max 0 (1- nV))) ")."))))
          )
          (foreach v dV
            (if (or (not (numberp v)) (<= v 0.0))
              (setq errs (append errs (list "Terdapat nilai DIST_V non-numerik atau <= 0.")))
            )
          )
        )
      )

      ;; 4. Validasi BASE_PT_WCS dan ELEVATION
      (setq bp   (cdr (assoc "BASE_PT_WCS" spec))
            elev (cdr (assoc "ELEVATION" spec)))
      (if (not (numberp elev))
        (setq errs (append errs (list "ELEVATION bukan numerik.")))
      )
      (if (or (not (listp bp)) (/= (length bp) 3)
              (not (numberp (nth 0 bp))) (not (numberp (nth 1 bp))) (not (numberp (nth 2 bp))))
        (setq errs (append errs (list "BASE_PT_WCS bukan titik 3D numerik.")))
        (if (and (numberp elev) (> (abs (- (float (nth 2 bp)) (float elev))) tol))
          (setq errs (append errs (list (strcat "ELEVATION (" (asdim:format-real elev)
                                                ") tidak konsisten dengan Z BASE_PT_WCS (" (asdim:format-real (nth 2 bp)) ")."))))
        )
      )

      ;; 5. Validasi parameter skala, anotasi, ekstensi, dan BUBBLE_POS
      (setq sc   (cdr (assoc "SCALE_DENOM" spec))
            th   (cdr (assoc "TEXT_H_PRINT" spec))
            bd   (cdr (assoc "BUBBLE_DIA_PRINT" spec))
            ex   (cdr (assoc "EXT_LEN" spec))
            bPos (cdr (assoc "BUBBLE_POS" spec)))
      (if (or (not (numberp sc)) (<= sc 0.0))
        (setq errs (append errs (list "SCALE_DENOM harus numerik > 0.")))
      )
      (if (or (not (numberp th)) (<= th 0.0))
        (setq errs (append errs (list "TEXT_H_PRINT harus numerik > 0.")))
      )
      (if (or (not (numberp bd)) (<= bd 0.0))
        (setq errs (append errs (list "BUBBLE_DIA_PRINT harus numerik > 0.")))
      )
      (if (or (not (numberp ex)) (<= ex 0.0))
        (setq errs (append errs (list "EXT_LEN harus numerik > 0.")))
      )
      (if (not (member bPos (asdim:valid-bubble-positions)))
        (setq errs (append errs (list "BUBBLE_POS tidak valid (harus Both Ends / Start / End).")))
      )
      (if (assoc "ANNO_EXT_LEN" spec)
        (progn
          (setq aExt (cdr (assoc "ANNO_EXT_LEN" spec)))
          (if (or (not (numberp aExt)) (<= aExt 0.0))
            (setq errs (append errs (list "ANNO_EXT_LEN harus numerik > 0.")))
          )
        )
        (setq warns (append warns (list "Field opsional ANNO_EXT_LEN tidak ditemukan; fallback ke EXT_LEN.")))
      )

      ;; 6. Evaluasi ketersediaan arah dimensi (kasus tepi NUM_H = 1 / NUM_V = 1)
      (setq canDimH (and (= (type nV) 'INT) (>= nV 2))
            canDimV (and (= (type nH) 'INT) (>= nH 2)))
      (if (not canDimH)
        (setq warns (append warns (list "NUM_V < 2: Dimensi horizontal (arah X) tidak tersedia untuk grup ini.")))
      )
      (if (not canDimV)
        (setq warns (append warns (list "NUM_H < 2: Dimensi vertikal (arah Y) tidak tersedia untuk grup ini.")))
      )
      (if (and (not canDimH) (not canDimV))
        (setq errs (append errs (list "Grup hanya memiliki 1 sumbu horizontal dan 1 sumbu vertikal; tidak ada interval untuk didimensi.")))
      )
    )
  )

  (list (cons "VALID"     (null errs))
        (cons "ERRORS"    errs)
        (cons "WARNINGS"  warns)
        (cons "CAN_DIM_H" canDimH)
        (cons "CAN_DIM_V" canDimV))
)

;;; ============================================================================
;;; SECTION 6: COORDINATE CALCULATOR (WCS)
;;; Acuan: asgrid:compute-cumulative (L117) & fn-geometry-engine (L2353-L2397)
;;; Konvensi aktual ASGRID R3:
;;;   - Horizontal grid (1, 2, 3...) -> posisi Y = Y0 + Sigma DIST_H
;;;   - Vertical grid   (A, B, C...) -> posisi X = X0 + Sigma DIST_V
;;;   - Titik perpotongan P_ji       -> (X_j, Y_i, Z0) dalam WCS
;;; ============================================================================

(defun asdim:compute-cumulative (startCoord distList / acc res val)
  (setq acc (float startCoord)
        res (list acc))
  (foreach val distList
    (setq acc (+ acc (float val))
          res (append res (list acc)))
  )
  res
)

;; Hitung seluruh koordinat kumulatif & garis ekspektasi WCS dari metadata spec
(defun asdim:calc-grid-coords (spec / basePt x0 y0 z0 dH dV ext
                                      cumY cumX totalY totalX
                                      expLinesH expLinesV i curY curX)
  (setq basePt    (cdr (assoc "BASE_PT_WCS" spec))
        x0        (float (nth 0 basePt))
        y0        (float (nth 1 basePt))
        z0        (float (nth 2 basePt))
        dH        (cdr (assoc "DIST_H" spec))
        dV        (cdr (assoc "DIST_V" spec))
        ext       (float (cdr (assoc "EXT_LEN" spec)))
        cumY      (asdim:compute-cumulative y0 dH)
        cumX      (asdim:compute-cumulative x0 dV)
        totalY    (- (last cumY) y0)
        totalX    (- (last cumX) x0)
        expLinesH '()
        expLinesV '())

  ;; Garis horizontal (AxisDir = "H", AxisIdx = 1..NUM_H, sejajar X pada Y = curY)
  (setq i 1)
  (foreach curY cumY
    (setq expLinesH
      (append expLinesH
        (list (list i
                    (itoa i)
                    (list (- x0 ext) curY z0)
                    (list (+ x0 totalX ext) curY z0)
                    curY)))
    )
    (setq i (1+ i))
  )

  ;; Garis vertikal (AxisDir = "V", AxisIdx = 1..NUM_V, sejajar Y pada X = curX)
  (setq i 1)
  (foreach curX cumX
    (setq expLinesV
      (append expLinesV
        (list (list i
                    (asdim:index-to-alpha i)
                    (list curX (- y0 ext) z0)
                    (list curX (+ y0 totalY ext) z0)
                    curX)))
    )
    (setq i (1+ i))
  )

  (list (cons "BASE_PT_WCS" basePt)
        (cons "X0"          x0)
        (cons "Y0"          y0)
        (cons "Z0"          z0)
        (cons "EXT_LEN"     ext)
        (cons "CUM_X"       cumX)
        (cons "CUM_Y"       cumY)
        (cons "TOTAL_X"     totalX)
        (cons "TOTAL_Y"     totalY)
        (cons "EXP_LINES_H" expLinesH)
        (cons "EXP_LINES_V" expLinesV))
)

;;; ============================================================================
;;; SECTION 7: ENTITY DISCOVERY (MODEL SPACE ONLY — 100% READ-ONLY)
;;; Filter ganda: (410 . "Model") pada ssget "_X" + validasi DXF 410 & 67 per entity
;;; ============================================================================

(defun asdim:discover-group-entities (groupId /
                                      ss i ename ed dxfType parsed status gid role
                                      lineEnts bubbleEnts textEnts
                                      wrongTypeEnts skippedNonModel)
  (setq lineEnts        '()
        bubbleEnts      '()
        textEnts        '()
        wrongTypeEnts   '()
        skippedNonModel 0)

  ;; Filter tingkat selection set: hanya entitas Model Space dengan XData ASGRID_OBJ
  (setq ss (ssget "_X" (list '(410 . "Model") (list -3 (list (asdim:xdata-app))))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename (ssname ss i))
        ;; Validasi ulang tingkat entitas aktual (DXF 410 = "Model" dan DXF 67 = 0/nil)
        (if (not (asdim:is-model-space-entity ename))
          (setq skippedNonModel (1+ skippedNonModel))
          (progn
            (setq parsed (asdim:parse-asgrid-xdata ename)
                  status (cdr (assoc "STATUS" parsed)))
            (if (and (= status "OK")
                     (= (cdr (assoc "GROUP_ID" parsed)) groupId))
              (progn
                (setq ed      (entget ename)
                      dxfType (cdr (assoc 0 ed))
                      role    (cdr (assoc "ROLE" parsed)))
                (cond
                  ((and (= role "LINE") (= dxfType "LINE"))
                   (setq lineEnts (append lineEnts (list (list ename parsed ed)))))
                  ((and (= role "BUBBLE") (= dxfType "CIRCLE"))
                   (setq bubbleEnts (append bubbleEnts (list (list ename parsed ed)))))
                  ((and (= role "TEXT") (= dxfType "TEXT"))
                   (setq textEnts (append textEnts (list (list ename parsed ed)))))
                  (t
                   (setq wrongTypeEnts
                     (append wrongTypeEnts
                       (list (list ename role dxfType
                                   (cdr (assoc "AXIS_DIR" parsed))
                                   (cdr (assoc "AXIS_IDX" parsed))
                                   (cdr (assoc "END_TAG" parsed)))))))
                )
              )
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )

  (list (cons "LINE_ENTS"         lineEnts)
        (cons "BUBBLE_ENTS"       bubbleEnts)
        (cons "TEXT_ENTS"         textEnts)
        (cons "WRONG_TYPE_ENTS"   wrongTypeEnts)
        (cons "SKIPPED_NON_MODEL" skippedNonModel))
)

;;; ============================================================================
;;; SECTION 8: GEOMETRY VALIDATOR (100% READ-ONLY)
;;; Memvalidasi garis grid aktual terhadap metadata & koordinat WCS, serta
;;; memisahkan entitas anotasi (BUBBLE/TEXT) agar tidak salah dianggap LINE.
;;; ============================================================================

;; Hitung jumlah ekspektasi entitas (identik asgrid:calc-expected-counts L1210)
(defun asdim:calc-expected-counts (spec / nH nV bPos endsMult expL expB expT)
  (setq nH       (cdr (assoc "NUM_H" spec))
        nV       (cdr (assoc "NUM_V" spec))
        bPos     (cdr (assoc "BUBBLE_POS" spec))
        endsMult (if (= bPos "Both Ends") 2 1)
        expL     (+ nH nV)
        expB     (* (+ nH nV) endsMult)
        expT     (* (+ nH nV) endsMult))
  (list (cons "EXP_LINE_H" nH)
        (cons "EXP_LINE_V" nV)
        (cons "EXP_LINE"   expL)
        (cons "EXP_BUBBLE" expB)
        (cons "EXP_TEXT"   expT))
)

;; Validasi satu entitas LINE aktual terhadap ekspektasi titik start/end WCS
(defun asdim:check-single-line-geom (axisDir axisLabel expP1 expP2 actualEd tol /
                                     p10 p11 z0 dz1 dz2 isParallel dFwd dRev dMin errs)
  (setq p10  (cdr (assoc 10 actualEd))
        p11  (cdr (assoc 11 actualEd))
        z0   (nth 2 expP1)
        errs '())

  (if (or (null p10) (null p11) (/= (length p10) 3) (/= (length p11) 3))
    (setq errs (list (strcat "Garis " axisDir "-" axisLabel " tidak memiliki titik DXF 10/11 3D yang valid.")))
    (progn
      ;; 1. Cek elevasi Z
      (setq dz1 (abs (- (float (nth 2 p10)) (float z0)))
            dz2 (abs (- (float (nth 2 p11)) (float z0))))
      (if (or (> dz1 tol) (> dz2 tol))
        (setq errs (append errs
          (list (strcat "Elevasi garis " axisDir "-" axisLabel " bergeser dari Z="
                        (asdim:format-real z0) " (aktual Z1=" (asdim:format-real (nth 2 p10))
                        ", Z2=" (asdim:format-real (nth 2 p11)) ")."))))
      )

      ;; 2. Cek orientasi garis (H sejajar X -> Y1==Y2; V sejajar Y -> X1==X2)
      (setq isParallel
        (if (= axisDir "H")
          (<= (abs (- (float (nth 1 p10)) (float (nth 1 p11)))) tol)
          (<= (abs (- (float (nth 0 p10)) (float (nth 0 p11)))) tol)
        ))
      (if (not isParallel)
        (setq errs (append errs
          (list (strcat "Orientasi garis " axisDir "-" axisLabel " tidak ortogonal terhadap sumbu WCS."))))
      )

      ;; 3. Cek posisi & panjang garis (terima urutan ujung normal maupun terbalik)
      (if (not (or (and (asdim:pt-equal-p p10 expP1 tol) (asdim:pt-equal-p p11 expP2 tol))
                   (and (asdim:pt-equal-p p10 expP2 tol) (asdim:pt-equal-p p11 expP1 tol))))
        (progn
          (setq dFwd (max (asdim:pt-dist-3d p10 expP1) (asdim:pt-dist-3d p11 expP2))
                dRev (max (asdim:pt-dist-3d p10 expP2) (asdim:pt-dist-3d p11 expP1))
                dMin (min dFwd dRev))
          (setq errs (append errs
            (list (strcat "Koordinat garis " axisDir "-" axisLabel " bergeser/berubah panjang sebesar "
                          (asdim:format-real dMin) " DU dari metadata."))))
        )
      )
    )
  )
  errs
)

;; Audit geometri menyeluruh untuk 1 grup ASGRID
(defun asdim:validate-grid-geometry (spec coords disc /
                                     tol errs warns expCnts
                                     nH nV bPos drawStart drawEnd
                                     lineEnts bubbleEnts textEnts wrongTypeEnts
                                     seenSlots slotKey
                                     hMap vMap foundH foundV
                                     item ename parsed ed role dir idx etag
                                     expItem axisLbl expP1 expP2 lineErrs
                                     cntLineH cntLineV cntBubble cntText
                                     expLineH expLineV expBub expTxt)
  (setq tol           (asdim:tol-geom)
        errs          '()
        warns         '()
        expCnts       (asdim:calc-expected-counts spec)
        nH            (cdr (assoc "NUM_H" spec))
        nV            (cdr (assoc "NUM_V" spec))
        bPos          (cdr (assoc "BUBBLE_POS" spec))
        drawStart     (or (= bPos "Both Ends") (= bPos "Start"))
        drawEnd       (or (= bPos "Both Ends") (= bPos "End"))
        lineEnts      (cdr (assoc "LINE_ENTS" disc))
        bubbleEnts    (cdr (assoc "BUBBLE_ENTS" disc))
        textEnts      (cdr (assoc "TEXT_ENTS" disc))
        wrongTypeEnts (cdr (assoc "WRONG_TYPE_ENTS" disc))
        seenSlots     '()
        hMap          '()
        vMap          '()
        cntLineH      0
        cntLineV      0
        cntBubble     (length bubbleEnts)
        cntText       (length textEnts)
        expLineH      (cdr (assoc "EXP_LINE_H" expCnts))
        expLineV      (cdr (assoc "EXP_LINE_V" expCnts))
        expBub        (cdr (assoc "EXP_BUBBLE" expCnts))
        expTxt        (cdr (assoc "EXP_TEXT" expCnts)))

  ;; 1. Laporkan entitas dengan tipe DXF tidak sesuai Role XData
  (foreach item wrongTypeEnts
    (setq errs (append errs
      (list (strcat "Tipe entitas tidak sesuai Role XData: Role=" (nth 1 item)
                    ", DXF aktual=" (nth 2 item)
                    " (" (nth 3 item) "-" (itoa (nth 4 item)) ", EndTag=" (nth 5 item) ")."))))
  )

  ;; 2. Audit seluruh entitas Role = LINE (identitas slot, indeks, EndTag, duplikat)
  (foreach item lineEnts
    (setq ename  (nth 0 item)
          parsed (nth 1 item)
          ed     (nth 2 item)
          dir    (cdr (assoc "AXIS_DIR" parsed))
          idx    (cdr (assoc "AXIS_IDX" parsed))
          etag   (cdr (assoc "END_TAG" parsed)))
    (if (/= etag "NONE")
      (setq errs (append errs
        (list (strcat "Entitas LINE " dir "-" (itoa idx) " memiliki EndTag tidak valid: '" etag "' (diharapkan 'NONE')."))))
    )
    (cond
      ((= dir "H")
       (setq cntLineH (1+ cntLineH))
       (if (or (< idx 1) (> idx nH))
         (setq errs (append errs
           (list (strcat "Entitas LINE horizontal tambahan di luar rentang NUM_H (1.." (itoa nH) "): indeks " (itoa idx) "."))))
         (progn
           (setq slotKey (strcat "LINE|H|" (itoa idx) "|NONE"))
           (if (member slotKey seenSlots)
             (setq errs (append errs
               (list (strcat "Duplikat entitas garis horizontal H-" (itoa idx) "."))))
             (setq seenSlots (cons slotKey seenSlots)
                   hMap      (cons (cons idx ed) hMap))
           )
         )
       ))
      ((= dir "V")
       (setq cntLineV (1+ cntLineV))
       (if (or (< idx 1) (> idx nV))
         (setq errs (append errs
           (list (strcat "Entitas LINE vertikal tambahan di luar rentang NUM_V (1.." (itoa nV) "): indeks " (itoa idx) "."))))
         (progn
           (setq slotKey (strcat "LINE|V|" (itoa idx) "|NONE"))
           (if (member slotKey seenSlots)
             (setq errs (append errs
               (list (strcat "Duplikat entitas garis vertikal V-" (asdim:index-to-alpha idx) " (indeks " (itoa idx) ")."))))
             (setq seenSlots (cons slotKey seenSlots)
                   vMap      (cons (cons idx ed) vMap))
           )
         )
       ))
    )
  )

  ;; 3. Verifikasi setiap garis horizontal ekspektasi (hilang / posisi / orientasi / elevasi)
  (foreach expItem (cdr (assoc "EXP_LINES_H" coords))
    (setq idx     (nth 0 expItem)
          axisLbl (nth 1 expItem)
          expP1   (nth 2 expItem)
          expP2   (nth 3 expItem)
          foundH  (assoc idx hMap))
    (if (null foundH)
      (setq errs (append errs
        (list (strcat "Garis grid horizontal H-" axisLbl " hilang di Model Space."))))
      (progn
        (setq lineErrs (asdim:check-single-line-geom "H" axisLbl expP1 expP2 (cdr foundH) tol))
        (if lineErrs (setq errs (append errs lineErrs)))
      )
    )
  )

  ;; 4. Verifikasi setiap garis vertikal ekspektasi (hilang / posisi / orientasi / elevasi)
  (foreach expItem (cdr (assoc "EXP_LINES_V" coords))
    (setq idx     (nth 0 expItem)
          axisLbl (nth 1 expItem)
          expP1   (nth 2 expItem)
          expP2   (nth 3 expItem)
          foundV  (assoc idx vMap))
    (if (null foundV)
      (setq errs (append errs
        (list (strcat "Garis grid vertikal V-" axisLbl " hilang di Model Space."))))
      (progn
        (setq lineErrs (asdim:check-single-line-geom "V" axisLbl expP1 expP2 (cdr foundV) tol))
        (if lineErrs (setq errs (append errs lineErrs)))
      )
    )
  )

  ;; 5. Cek jumlah total garis H & V
  (if (/= cntLineH expLineH)
    (setq errs (append errs
      (list (strcat "Jumlah garis horizontal tidak sesuai: aktual=" (itoa cntLineH)
                    ", ekspektasi=" (itoa expLineH) "."))))
  )
  (if (/= cntLineV expLineV)
    (setq errs (append errs
      (list (strcat "Jumlah garis vertikal tidak sesuai: aktual=" (itoa cntLineV)
                    ", ekspektasi=" (itoa expLineV) "."))))
  )

  ;; 6. Audit anotasi (BUBBLE & TEXT) terpisah dari garis grid — tidak dianggap LINE
  (foreach item (append bubbleEnts textEnts)
    (setq parsed (nth 1 item)
          role   (cdr (assoc "ROLE" parsed))
          dir    (cdr (assoc "AXIS_DIR" parsed))
          idx    (cdr (assoc "AXIS_IDX" parsed))
          etag   (cdr (assoc "END_TAG" parsed)))
    (if (or (and (= dir "H") (or (< idx 1) (> idx nH)))
            (and (= dir "V") (or (< idx 1) (> idx nV))))
      (setq warns (append warns
        (list (strcat "Anotasi " role " " dir "-" (itoa idx) " berada di luar rentang sumbu metadata."))))
    )
    (if (not (or (and (= etag "START") drawStart)
                 (and (= etag "END")   drawEnd)))
      (setq warns (append warns
        (list (strcat "Anotasi " role " " dir "-" (itoa idx) " memiliki EndTag '" etag "' yang tidak sesuai BUBBLE_POS ('" bPos "')."))))
    )
    (setq slotKey (strcat role "|" dir "|" (itoa idx) "|" etag))
    (if (member slotKey seenSlots)
      (setq warns (append warns
        (list (strcat "Duplikat slot anotasi terdeteksi: " slotKey "."))))
      (setq seenSlots (cons slotKey seenSlots))
    )
  )
  (if (or (/= cntBubble expBub) (/= cntText expTxt))
    (setq warns (append warns
      (list (strcat "Jumlah anotasi tidak sama dengan ekspektasi metadata (BUBBLE aktual="
                    (itoa cntBubble) "/" (itoa expBub) ", TEXT aktual="
                    (itoa cntText) "/" (itoa expTxt) ")."))))
  )

  (list (cons "VALID"        (null errs))
        (cons "ERRORS"       errs)
        (cons "WARNINGS"     warns)
        (cons "CNT_LINE_H"   cntLineH)
        (cons "CNT_LINE_V"   cntLineV)
        (cons "EXP_LINE_H"   expLineH)
        (cons "EXP_LINE_V"   expLineV)
        (cons "CNT_BUBBLE"   cntBubble)
        (cons "EXP_BUBBLE"   expBub)
        (cons "CNT_TEXT"     cntText)
        (cons "EXP_TEXT"     expTxt))
)

;;; ============================================================================
;;; SECTION 9: AUDIT REPORT (COMMAND-LINE OUTPUT)
;;; ============================================================================

(defun asdim:print-audit-report (groupId spec metaRes coords disc geomRes /
                                 insUnits msg okMeta okGeom)
  (setq insUnits (getvar "INSUNITS")
        okMeta   (cdr (assoc "VALID" metaRes))
        okGeom   (if geomRes (cdr (assoc "VALID" geomRes)) nil))

  (princ "\n======================================================================")
  (princ (strcat "\n  " (asdim:version-label) " — LAPORAN AUDIT READ-ONLY"))
  (princ "\n======================================================================")
  (princ (strcat "\n  Group ID          : " groupId))
  (if spec
    (progn
      (princ (strcat "\n  Schema Version    : " (if (cdr (assoc "SCHEMA_VER" spec)) (cdr (assoc "SCHEMA_VER" spec)) "<kosong>")))
      (princ (strcat "\n  Generator Version : " (if (cdr (assoc "GENERATOR_VER" spec)) (cdr (assoc "GENERATOR_VER" spec)) "<kosong>")))
      (princ (strcat "\n  INSUNITS (Info)   : " (if (= (type insUnits) 'INT) (itoa insUnits) "<unknown>") " (informasional, tidak diubah)"))
      (princ (strcat "\n  BASE_PT_WCS       : " (asdim:format-pt (cdr (assoc "BASE_PT_WCS" spec)))))
      (princ (strcat "\n  ELEVATION (Z)     : " (asdim:format-real (cdr (assoc "ELEVATION" spec))) " DU"))
      (princ (strcat "\n  SCALE_DENOM       : 1:" (asdim:format-real (cdr (assoc "SCALE_DENOM" spec)))))
      (princ (strcat "\n  Grid Size         : "
                     (if (= (type (cdr (assoc "NUM_H" spec))) 'INT) (itoa (cdr (assoc "NUM_H" spec))) "?")
                     " Horizontal (Y) x "
                     (if (= (type (cdr (assoc "NUM_V" spec))) 'INT) (itoa (cdr (assoc "NUM_V" spec))) "?")
                     " Vertical (X)"))
      (princ (strcat "\n  DIST_H (arah Y)   : " (asdim:format-real-list (cdr (assoc "DIST_H" spec))) " DU"))
      (princ (strcat "\n  DIST_V (arah X)   : " (asdim:format-real-list (cdr (assoc "DIST_V" spec))) " DU"))
      (princ (strcat "\n  EXT_LEN / ANNO_EXT: " (asdim:format-real (cdr (assoc "EXT_LEN" spec)))
                     " / " (asdim:format-real (asdim:get-anno-ext-len spec)) " DU"))
    )
  )
  (if coords
    (progn
      (princ (strcat "\n  Total Span X (V)  : " (asdim:format-real (cdr (assoc "TOTAL_X" coords))) " DU"))
      (princ (strcat "\n  Total Span Y (H)  : " (asdim:format-real (cdr (assoc "TOTAL_Y" coords))) " DU"))
    )
  )

  (princ "\n----------------------------------------------------------------------")
  (princ (strcat "\n  [1] VALIDASI METADATA : " (if okMeta "LULUS" "GAGAL")))
  (foreach msg (cdr (assoc "ERRORS" metaRes))
    (princ (strcat "\n      [ERROR] " msg))
  )
  (foreach msg (cdr (assoc "WARNINGS" metaRes))
    (princ (strcat "\n      [INFO]  " msg))
  )

  (if geomRes
    (progn
      (princ "\n----------------------------------------------------------------------")
      (princ (strcat "\n  [2] AUDIT GEOMETRI MODEL SPACE : " (if okGeom "LULUS" "GAGAL")))
      (princ (strcat "\n      Garis Horizontal (LINE H)  : "
                     (itoa (cdr (assoc "CNT_LINE_H" geomRes))) " / "
                     (itoa (cdr (assoc "EXP_LINE_H" geomRes)))))
      (princ (strcat "\n      Garis Vertikal   (LINE V)  : "
                     (itoa (cdr (assoc "CNT_LINE_V" geomRes))) " / "
                     (itoa (cdr (assoc "EXP_LINE_V" geomRes)))))
      (princ (strcat "\n      Anotasi Terpisah (BUBBLE)  : "
                     (itoa (cdr (assoc "CNT_BUBBLE" geomRes))) " / "
                     (itoa (cdr (assoc "EXP_BUBBLE" geomRes))) " (tidak dianggap garis grid)"))
      (princ (strcat "\n      Anotasi Terpisah (TEXT)    : "
                     (itoa (cdr (assoc "CNT_TEXT" geomRes))) " / "
                     (itoa (cdr (assoc "EXP_TEXT" geomRes))) " (tidak dianggap garis grid)"))
      (if (> (cdr (assoc "SKIPPED_NON_MODEL" disc)) 0)
        (princ (strcat "\n      Entitas Non-Model Diabaikan: " (itoa (cdr (assoc "SKIPPED_NON_MODEL" disc)))))
      )
      (foreach msg (cdr (assoc "ERRORS" geomRes))
        (princ (strcat "\n      [ERROR] " msg))
      )
      (foreach msg (cdr (assoc "WARNINGS" geomRes))
        (princ (strcat "\n      [WARN]  " msg))
      )
    )
  )

  (princ "\n======================================================================")
  (if (and okMeta okGeom)
    (princ "\n  HASIL AKHIR: [LULUS] Grup ASGRID valid dan siap untuk ASDIM Phase 2.")
    (princ "\n  HASIL AKHIR: [GAGAL] Grup ASGRID tidak memenuhi syarat audit.")
  )
  (princ "\n  Mode: 100% READ-ONLY (tidak ada perubahan pada gambar maupun metadata).")
  (princ "\n======================================================================\n")
)

;;; ============================================================================
;;; SECTION 10: MAIN COMMAND (c:ASDIM — PHASE 1 READ-ONLY AUDIT)
;;; ============================================================================

(defun c:ASDIM ( / *error* sel ename xRes xStatus groupId xSchemaVer
                   readRes spec metaRes coords disc geomRes)

  ;; Error handler lokal (100% read-only; tidak memanggil setvar/command)
  (defun *error* (msg / isCancel)
    (setq isCancel (member msg '("Function cancelled"
                                 "quit / exit abort"
                                 "console break")))
    (cond
      ((or (null msg) isCancel)
       (princ (strcat "\n[" (asdim:version-label) "] Dibatalkan oleh pengguna. Tidak ada perubahan pada gambar.")))
      (t
       (princ (strcat "\n[" (asdim:version-label) " ERROR] " msg
                      "\n  Mode READ-ONLY: tidak ada entitas atau metadata yang diubah.")))
    )
    (princ)
  )

  (princ (strcat "\n[" (asdim:version-label) "] Audit Read-Only Grup ASGRID (Model Space)."))

  ;; Langkah 1: Pilih satu entitas milik grup ASGRID
  (setq sel (entsel "\nPilih salah satu objek grid milik ASGRID (LINE / BUBBLE / TEXT): "))
  (cond
    ((null sel)
     (princ (strcat "\n[" (asdim:version-label) "] Tidak ada objek yang dipilih. Proses dihentikan.")))
    (t
     (setq ename (car sel))
     ;; Langkah 2: Validasi Model Space pada objek yang dipilih
     (if (not (asdim:is-model-space-entity ename))
       (princ (strcat "\n[" (asdim:version-label) " GAGAL] Objek yang dipilih bukan berasal dari Model Space (Paper Space/Layout tidak didukung)."))
       (progn
         ;; Langkah 3: Baca XData ASGRID_OBJ untuk mendapatkan GROUP_ID
         (setq xRes    (asdim:parse-asgrid-xdata ename)
               xStatus (cdr (assoc "STATUS" xRes)))
         (if (/= xStatus "OK")
           (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" xRes))))
           (progn
             (setq groupId    (cdr (assoc "GROUP_ID" xRes))
                   xSchemaVer (cdr (assoc "SCHEMA_VER" xRes)))
             ;; Langkah 4: Baca metadata grup dari NOD ASGRID_GROUPS (read-only)
             (setq readRes (asdim:meta-read-group groupId))
             (if (/= (cdr (assoc "STATUS" readRes)) "OK")
               (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" readRes))))
               (progn
                 (setq spec    (cdr (assoc "SPEC" readRes))
                       ;; Langkah 5: Validasi kelengkapan & konsistensi metadata (termasuk SCHEMA_VER XData)
                       metaRes (asdim:meta-validate-spec spec groupId xSchemaVer))
                 (if (not (cdr (assoc "VALID" metaRes)))
                   (asdim:print-audit-report groupId spec metaRes nil nil nil)
                   (progn
                     ;; Langkah 6: Hitung ulang koordinat WCS dari metadata
                     (setq coords  (asdim:calc-grid-coords spec)
                           ;; Langkah 7: Temukan entitas Model Space milik grup
                           disc    (asdim:discover-group-entities groupId)
                           ;; Langkah 8: Audit geometri aktual vs metadata
                           geomRes (asdim:validate-grid-geometry spec coords disc))
                     ;; Langkah 9: Tampilkan laporan audit
                     (asdim:print-audit-report groupId spec metaRes coords disc geomRes)
                   )
                 )
               )
             )
           )
         )
       )
     ))
  )
  (princ)
)

;; Pesan muat saat APPLOAD (100% read-only)
(princ "\n[ASDIM V1.0-Phase1-R1] Berhasil dimuat (100% READ-ONLY Audit). Perintah: ASDIM.")
(princ)
