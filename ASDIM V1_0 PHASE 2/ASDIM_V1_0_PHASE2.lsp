;;; ============================================================================
;;; PROGRAM     : ASDIM V1.0 — PHASE 2 (STYLE ENGINE & DIMENSION GENERATOR)
;;; PROYEK      : CIVIL DRAFTING AUTOMATION
;;; TARGET      : AutoCAD 2021 (AutoLISP + Visual LISP / ActiveX)
;;; BASELINE    : ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp (utuh)
;;; ACUAN SPEK  : ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md
;;; ACUAN ASGRID: ASGRID V2.2.1 R3/ASGRID_V2_2_1_R3.lsp (Schema 1.0, read-only)
;;; COMMAND     : ASDIM
;;; RUANG LINGKUP PHASE 2:
;;;   - Mempertahankan seluruh audit read-only Phase 1 R1 (Metadata + Geometri).
;;;   - Style Engine terisolasi: ASDIM-ARIAL (arial.ttf), ASDIM-STYLE (DXF 340),
;;;     dan Layer AS-DIM tanpa mengubah Standard, ASGRID-ARIAL, atau DIMSTYLE global.
;;;   - Dimension Generator native via ActiveX vla-AddDimRotated (WCS) dengan
;;;     XData identitas ASDIM_OBJ (7 field, Batch ID unik, 5-tupel slot unik).
;;;   - Input konfigurasi sementara melalui command line (tanpa DCL / Live Preview).
;;;   - Safe Generation dasar: cleanup hanya entitas baru pada batch aktif jika
;;;     gagal di tengah proses (bukan full atomic transaction / belum Replace mode).
;;; ============================================================================

;;; ============================================================================
;;; SECTION 1: UTILITY FUNCTIONS (DIPERTAHANKAN DARI PHASE 1 R1)
;;; ============================================================================

(defun asdim:version-label () "ASDIM V1.0-Phase2")
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
;;; SECTION 2: XDATA READER (ASGRID_OBJ — 100% READ-ONLY, PHASE 1 R1)
;;; ============================================================================

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
;;; SECTION 3: NOD DICTIONARY READER (ASGRID_GROUPS — 100% READ-ONLY, PHASE 1 R1)
;;; ============================================================================

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
;;; SECTION 4: XRECORD READER (100% READ-ONLY, PHASE 1 R1)
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
;;; SECTION 5: METADATA VALIDATOR (DIPERTAHANKAN DARI PHASE 1 R1)
;;; ============================================================================

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
      (foreach k '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER"
                   "AXIS_DIR_H" "AXIS_DIR_V" "TEXT_STYLE" "FONT_FILE"
                   "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT")
        (setq v (cdr (assoc k spec)))
        (if (or (not (= (type v) 'STR)) (= (strlen (asdim:trim v)) 0))
          (setq errs (append errs (list (strcat "Nilai string tidak valid/kosong pada key: " k))))
        )
      )

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
      (if (and (= (type axH) 'STR) (/= axH "X"))
        (setq errs (append errs (list (strcat "AXIS_DIR_H tidak valid: '" axH "' (harus tepat 'X')."))))
      )
      (if (and (= (type axV) 'STR) (/= axV "Y"))
        (setq errs (append errs (list (strcat "AXIS_DIR_V tidak valid: '" axV "' (harus tepat 'Y')."))))
      )

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
;;; SECTION 6: COORDINATE CALCULATOR (WCS, DIPERTAHANKAN DARI PHASE 1 R1)
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
;;; SECTION 7: ENTITY DISCOVERY (MODEL SPACE ONLY, DIPERTAHANKAN DARI PHASE 1 R1)
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

  (setq ss (ssget "_X" (list '(410 . "Model") (list -3 (list (asdim:xdata-app))))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename (ssname ss i))
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
;;; SECTION 8: GEOMETRY VALIDATOR (DIPERTAHANKAN DARI PHASE 1 R1)
;;; ============================================================================

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

(defun asdim:check-single-line-geom (axisDir axisLabel expP1 expP2 actualEd tol /
                                     p10 p11 z0 dz1 dz2 isParallel dFwd dRev dMin errs)
  (setq p10  (cdr (assoc 10 actualEd))
        p11  (cdr (assoc 11 actualEd))
        z0   (nth 2 expP1)
        errs '())

  (if (or (null p10) (null p11) (/= (length p10) 3) (/= (length p11) 3))
    (setq errs (list (strcat "Garis " axisDir "-" axisLabel " tidak memiliki titik DXF 10/11 3D yang valid.")))
    (progn
      (setq dz1 (abs (- (float (nth 2 p10)) (float z0)))
            dz2 (abs (- (float (nth 2 p11)) (float z0))))
      (if (or (> dz1 tol) (> dz2 tol))
        (setq errs (append errs
          (list (strcat "Elevasi garis " axisDir "-" axisLabel " bergeser dari Z="
                        (asdim:format-real z0) " (aktual Z1=" (asdim:format-real (nth 2 p10))
                        ", Z2=" (asdim:format-real (nth 2 p11)) ")."))))
      )

      (setq isParallel
        (if (= axisDir "H")
          (<= (abs (- (float (nth 1 p10)) (float (nth 1 p11)))) tol)
          (<= (abs (- (float (nth 0 p10)) (float (nth 0 p11)))) tol)
        ))
      (if (not isParallel)
        (setq errs (append errs
          (list (strcat "Orientasi garis " axisDir "-" axisLabel " tidak ortogonal terhadap sumbu WCS."))))
      )

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

  (foreach item wrongTypeEnts
    (setq errs (append errs
      (list (strcat "Tipe entitas tidak sesuai Role XData: Role=" (nth 1 item)
                    ", DXF aktual=" (nth 2 item)
                    " (" (nth 3 item) "-" (itoa (nth 4 item)) ", EndTag=" (nth 5 item) ")."))))
  )

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
;;; SECTION 9: AUDIT REPORT (DIPERTAHANKAN DARI PHASE 1 R1)
;;; ============================================================================

(defun asdim:print-audit-report (groupId spec metaRes coords disc geomRes /
                                 insUnits msg okMeta okGeom)
  (setq insUnits (getvar "INSUNITS")
        okMeta   (cdr (assoc "VALID" metaRes))
        okGeom   (if geomRes (cdr (assoc "VALID" geomRes)) nil))

  (princ "\n======================================================================")
  (princ (strcat "\n  " (asdim:version-label) " — LAPORAN AUDIT GRUP ASGRID"))
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
    (princ "\n  HASIL AUDIT: [LULUS] Melanjutkan ke konfigurasi dimensi Phase 2.")
    (princ "\n  HASIL AUDIT: [GAGAL] Proses dihentikan tanpa membuat dimensi.")
  )
  (princ "\n======================================================================\n")
)

;;; ============================================================================
;;; SECTION 10: PHASE 2 CONSTANTS, ACTIVEX CHECK & REGAPP HELPERS
;;; ============================================================================

(defun asdim:dim-xdata-app () "ASDIM_OBJ")
(defun asdim:dim-schema-ver () "1.0")
(defun asdim:text-style-name () "ASDIM-ARIAL")
(defun asdim:font-file () "arial.ttf")
(defun asdim:dim-style-name () "ASDIM-STYLE")
(defun asdim:layer-name () "AS-DIM")

;; Pastikan Visual LISP / ActiveX tersedia dan kembalikan (doc . modelSpace)
(defun asdim:ensure-activex ( / loadRes acadObj doc ms)
  (setq loadRes (vl-catch-all-apply 'vl-load-com nil))
  (if (vl-catch-all-error-p loadRes)
    (list (cons "STATUS" "ERROR")
          (cons "ERROR" (strcat "Gagal memuat Visual LISP ActiveX (vl-load-com): "
                                (vl-catch-all-error-message loadRes))))
    (progn
      (setq acadObj (vl-catch-all-apply 'vlax-get-acad-object nil))
      (if (or (vl-catch-all-error-p acadObj) (null acadObj))
        (list (cons "STATUS" "ERROR")
              (cons "ERROR" "Gagal memperoleh objek ActiveX AutoCAD (vlax-get-acad-object)."))
        (progn
          (setq doc (vl-catch-all-apply 'vla-get-ActiveDocument (list acadObj)))
          (if (or (vl-catch-all-error-p doc) (null doc))
            (list (cons "STATUS" "ERROR")
                  (cons "ERROR" "Gagal memperoleh ActiveDocument ActiveX."))
            (progn
              (setq ms (vl-catch-all-apply 'vla-get-ModelSpace (list doc)))
              (if (or (vl-catch-all-error-p ms) (null ms))
                (list (cons "STATUS" "ERROR")
                      (cons "ERROR" "Gagal memperoleh koleksi ModelSpace ActiveX."))
                (list (cons "STATUS" "OK")
                      (cons "DOC"    doc)
                      (cons "MS"     ms))
              )
            )
          )
        )
      )
    )
  )
)

;; Pastikan RegApp terdaftar di tabel APPID (pola aman tblsearch AutoCAD 2021)
(defun asdim:ensure-regapp (appName / )
  (if (not (tblsearch "APPID" appName))
    (regapp appName)
  )
  (not (null (tblsearch "APPID" appName)))
)

;;; ============================================================================
;;; SECTION 11: STYLE ENGINE (ASDIM-ARIAL, ASDIM-STYLE, LAYER AS-DIM)
;;; ============================================================================

;; Cari file arial.ttf secara deterministik (pola teruji ASGRID R3 L268-L290)
(defun asdim:find-arial-ttf (fontFile / p winDir sysRoot)
  (setq p (findfile fontFile))
  (if (null p)
    (progn
      (setq winDir (getenv "WINDIR"))
      (if winDir
        (setq p (findfile (strcat winDir "\\Fonts\\" fontFile)))
      )
    )
  )
  (if (null p)
    (progn
      (setq sysRoot (getenv "SystemRoot"))
      (if sysRoot
        (setq p (findfile (strcat sysRoot "\\Fonts\\" fontFile)))
      )
    )
  )
  (if (null p)
    (setq p (findfile (strcat "C:\\Windows\\Fonts\\" fontFile)))
  )
  p
)

;; Cek apakah Text Style bersifat Annotative (XData AcadAnnotative)
(defun asdim:style-is-annotative (styleName / ename edata xdata pair found)
  (setq ename (tblobjname "STYLE" styleName)
        found nil)
  (if ename
    (progn
      (setq edata (entget ename '("AcadAnnotative"))
            xdata (cadr (assoc -3 edata)))
      (if xdata
        (foreach pair (cdr xdata)
          (if (and (= (car pair) 1070) (= (cdr pair) 1))
            (setq found T)
          )
        )
      )
    )
  )
  found
)

;; Verifikasi Text Style ASDIM-ARIAL (font arial.ttf, height 0, width 1.0, oblique 0, non-annotative)
(defun asdim:verify-arial-style (styleName fontFile / tblRec flag fh wf ob existingFont tol errs)
  (setq tblRec (tblsearch "STYLE" styleName)
        tol    (asdim:tol-meta)
        errs   '())
  (if (null tblRec)
    (setq errs (list (strcat "Text Style '" styleName "' tidak ditemukan pada tabel STYLE.")))
    (progn
      (setq flag         (cdr (assoc 70 tblRec))
            fh           (cdr (assoc 40 tblRec))
            wf           (cdr (assoc 41 tblRec))
            ob           (cdr (assoc 50 tblRec))
            existingFont (if (cdr (assoc 3 tblRec)) (strcase (cdr (assoc 3 tblRec))) ""))
      (if (and (= (type flag) 'INT) (/= (logand flag 5) 0))
        (setq errs (append errs (list (strcat "Text Style '" styleName "' memiliki flag shape/vertical yang tidak didukung."))))
      )
      (if (/= existingFont (strcase fontFile))
        (setq errs (append errs (list (strcat "Text Style '" styleName "' menggunakan font '" existingFont "' (harus '" fontFile "')."))))
      )
      (if (or (not (numberp fh)) (> (abs (float fh)) tol))
        (setq errs (append errs (list (strcat "Text Style '" styleName "' memiliki Fixed Height=" (asdim:format-real fh) " (harus 0.0)."))))
      )
      (if (or (not (numberp wf)) (> (abs (- (float wf) 1.0)) tol))
        (setq errs (append errs (list (strcat "Text Style '" styleName "' memiliki Width Factor=" (asdim:format-real wf) " (harus 1.0)."))))
      )
      (if (or (not (numberp ob)) (> (abs (float ob)) tol))
        (setq errs (append errs (list (strcat "Text Style '" styleName "' memiliki Oblique Angle=" (asdim:format-real ob) " (harus 0.0)."))))
      )
      (if (asdim:style-is-annotative styleName)
        (setq errs (append errs (list (strcat "Text Style '" styleName "' bersifat Annotative (harus non-annotative)."))))
      )
    )
  )
  (list (cons "VALID"  (null errs))
        (cons "ERRORS" errs))
)

;; Provisioning & verifikasi ASDIM-ARIAL tanpa mengubah Standard, ASGRID-ARIAL, atau TEXTSTYLE global
(defun asdim:ensure-arial-style ( / styleName fontFile existed fontPath verRes okMake)
  (setq styleName (asdim:text-style-name)
        fontFile  (asdim:font-file)
        fontPath  (asdim:find-arial-ttf fontFile))
  (if (null fontPath)
    (list (cons "STATUS" "ERROR")
          (cons "ERROR" (strcat "File font Arial ('" fontFile "') tidak ditemukan. "
                                "ASDIM tidak akan mengganti font secara diam-diam.")))
    (progn
      (setq existed (not (null (tblsearch "STYLE" styleName))))
      (if existed
        (progn
          (setq verRes (asdim:verify-arial-style styleName fontFile))
          (if (cdr (assoc "VALID" verRes))
            (list (cons "STATUS"  "OK")
                  (cons "CREATED" nil)
                  (cons "ENAME"   (tblobjname "STYLE" styleName)))
            (list (cons "STATUS" "CONFLICT")
                  (cons "ERROR" (strcat "Text Style '" styleName "' sudah ada tetapi tidak sesuai standar ASDIM: "
                                        (car (cdr (assoc "ERRORS" verRes)))
                                        " ASDIM tidak menimpa style eksisting.")))
          )
        )
        (progn
          (asdim:ensure-regapp "ACAD")
          (setq okMake
            (not (null
              (entmake
                (list
                  (cons 0 "STYLE")
                  (cons 100 "AcDbSymbolTableRecord")
                  (cons 100 "AcDbTextStyleTableRecord")
                  (cons 2 styleName)
                  (cons 70 0)
                  (cons 40 0.0)
                  (cons 41 1.0)
                  (cons 50 0.0)
                  (cons 71 0)
                  (cons 42 2.5)
                  (cons 3 fontFile)
                  (cons 4 "")
                  (list -3
                    (list "ACAD"
                      (cons 1000 "Arial")
                      (cons 1071 34)
                    )
                  )
                )
              )
            ))
          )
          (if (not okMake)
            (list (cons "STATUS" "ERROR")
                  (cons "ERROR" (strcat "Gagal membuat Text Style '" styleName "' via entmake.")))
            (progn
              (setq verRes (asdim:verify-arial-style styleName fontFile))
              (if (cdr (assoc "VALID" verRes))
                (list (cons "STATUS"  "OK")
                      (cons "CREATED" T)
                      (cons "ENAME"   (tblobjname "STYLE" styleName)))
                (list (cons "STATUS" "ERROR")
                      (cons "ERROR" (strcat "Text Style '" styleName "' dibuat tetapi gagal verifikasi: "
                                            (car (cdr (assoc "ERRORS" verRes))))))
              )
            )
          )
        )
      )
    )
  )
)

;; Verifikasi Dimension Style ASDIM-STYLE (DXF 340 -> ASDIM-ARIAL, DIMSCALE = 1.0)
(defun asdim:verify-dim-style (dimStyleName expectedTextStyleName /
                               dsEname dsEd ref340 stEd stName dimScale tol errs)
  (setq dsEname (tblobjname "DIMSTYLE" dimStyleName)
        tol     (asdim:tol-meta)
        errs    '())
  (if (null dsEname)
    (setq errs (list (strcat "Dimension Style '" dimStyleName "' tidak ditemukan pada tabel DIMSTYLE.")))
    (progn
      (setq dsEd   (entget dsEname)
            ref340 (cdr (assoc 340 dsEd)))
      (if (or (null ref340) (not (= (type ref340) 'ENAME)))
        (setq errs (append errs (list (strcat "Dimension Style '" dimStyleName "' tidak memiliki referensi DXF 340 ke Text Style."))))
        (progn
          (setq stEd   (entget ref340)
                stName (if stEd (cdr (assoc 2 stEd)) nil))
          (if (or (null stName) (/= (strcase stName) (strcase expectedTextStyleName)))
            (setq errs (append errs (list (strcat "Dimension Style '" dimStyleName "' merujuk Text Style '"
                                                  (if stName stName "<kosong>") "' (harus '" expectedTextStyleName "')."))))
          )
        )
      )
      (setq dimScale (cdr (assoc 40 dsEd)))
      (if (and dimScale (or (not (numberp dimScale)) (> (abs (- (float dimScale) 1.0)) tol)))
        (setq errs (append errs (list (strcat "Dimension Style '" dimStyleName "' memiliki DIMSCALE="
                                              (asdim:format-real dimScale) " (harus 1.0)."))))
      )
    )
  )
  (list (cons "VALID"  (null errs))
        (cons "ERRORS" errs))
)

;; Provisioning & verifikasi ASDIM-STYLE tanpa mengubah DIMSTYLE global
;; Catatan AutoCAD 2021 (UNVERIFIED runtime hingga T-21):
;;   Jalur 1: vla-Add pada DimStyles (tanpa mengaktifkan) + entmod DXF 340 & 40
;;   Jalur 2 (fallback jika Jalur 1 gagal): entmake tabel DIMSTYLE langsung
(defun asdim:ensure-dim-style (doc textStyleEname textH_DU arrowSz_DU dimDec /
                               dimStyleName textStyleName existed verRes
                               dimStyles addRes dsEname dsEd newEd modOk makeOk)
  (setq dimStyleName  (asdim:dim-style-name)
        textStyleName (asdim:text-style-name)
        existed       (not (null (tblsearch "DIMSTYLE" dimStyleName))))
  (if existed
    (progn
      (setq verRes (asdim:verify-dim-style dimStyleName textStyleName))
      (if (cdr (assoc "VALID" verRes))
        (list (cons "STATUS"  "OK")
              (cons "CREATED" nil)
              (cons "ENAME"   (tblobjname "DIMSTYLE" dimStyleName)))
        (list (cons "STATUS" "CONFLICT")
              (cons "ERROR" (strcat "Dimension Style '" dimStyleName "' sudah ada tetapi tidak sesuai standar ASDIM: "
                                    (car (cdr (assoc "ERRORS" verRes)))
                                    " ASDIM tidak menimpa style eksisting.")))
      )
    )
    (progn
      ;; Jalur 1: vla-Add pada koleksi DimStyles + entmod DXF 340 & 40
      (setq dimStyles (vl-catch-all-apply 'vla-get-DimStyles (list doc))
            addRes    (if (not (vl-catch-all-error-p dimStyles))
                        (vl-catch-all-apply 'vla-Add (list dimStyles dimStyleName))
                        dimStyles)
            modOk     nil)
      (if (not (vl-catch-all-error-p addRes))
        (progn
          (setq dsEname (tblobjname "DIMSTYLE" dimStyleName)
                dsEd    (if dsEname (entget dsEname) nil))
          (if dsEd
            (progn
              (setq newEd dsEd)
              (if (assoc 340 newEd)
                (setq newEd (subst (cons 340 textStyleEname) (assoc 340 newEd) newEd))
                (setq newEd (append newEd (list (cons 340 textStyleEname))))
              )
              (if (assoc 40 newEd)
                (setq newEd (subst (cons 40 1.0) (assoc 40 newEd) newEd))
                (setq newEd (append newEd (list (cons 40 1.0))))
              )
              (if (assoc 140 newEd)
                (setq newEd (subst (cons 140 (float textH_DU)) (assoc 140 newEd) newEd))
                (setq newEd (append newEd (list (cons 140 (float textH_DU)))))
              )
              (if (assoc 41 newEd)
                (setq newEd (subst (cons 41 (float arrowSz_DU)) (assoc 41 newEd) newEd))
                (setq newEd (append newEd (list (cons 41 (float arrowSz_DU)))))
              )
              (if (assoc 271 newEd)
                (setq newEd (subst (cons 271 dimDec) (assoc 271 newEd) newEd))
                (setq newEd (append newEd (list (cons 271 dimDec))))
              )
              (setq modOk (not (null (entmod newEd))))
            )
          )
        )
      )

      ;; Jalur 2 (fallback bila DimStyle belum terbentuk via Jalur 1): entmake DIMSTYLE
      (if (and (not modOk) (null (tblsearch "DIMSTYLE" dimStyleName)))
        (setq makeOk
          (not (null
            (entmake
              (list
                (cons 0 "DIMSTYLE")
                (cons 100 "AcDbSymbolTableRecord")
                (cons 100 "AcDbDimStyleTableRecord")
                (cons 2 dimStyleName)
                (cons 70 0)
                (cons 40 1.0)
                (cons 41 (float arrowSz_DU))
                (cons 140 (float textH_DU))
                (cons 271 dimDec)
                (cons 340 textStyleEname)
              )
            )
          ))
        )
      )

      ;; Verifikasi pasca-pembuatan wajib
      (setq verRes (asdim:verify-dim-style dimStyleName textStyleName))
      (if (cdr (assoc "VALID" verRes))
        (list (cons "STATUS"  "OK")
              (cons "CREATED" T)
              (cons "ENAME"   (tblobjname "DIMSTYLE" dimStyleName)))
        (list (cons "STATUS" "ERROR")
              (cons "ERROR" (strcat "Gagal membuat atau memverifikasi Dimension Style '" dimStyleName "': "
                                    (car (cdr (assoc "ERRORS" verRes))))))
      )
    )
  )
)

;; Provisioning & verifikasi Layer AS-DIM tanpa mengubah CLAYER global
(defun asdim:ensure-dim-layer ( / layName tblRec flag okMake)
  (setq layName (asdim:layer-name)
        tblRec  (tblsearch "LAYER" layName))
  (if tblRec
    (progn
      (setq flag (cdr (assoc 70 tblRec)))
      (cond
        ((and (= (type flag) 'INT) (/= (logand flag 1) 0))
         (list (cons "STATUS" "CONFLICT")
               (cons "ERROR" (strcat "Layer '" layName "' dalam kondisi FROZEN. Cairkan layer lalu jalankan ulang."))))
        ((and (= (type flag) 'INT) (/= (logand flag 4) 0))
         (list (cons "STATUS" "CONFLICT")
               (cons "ERROR" (strcat "Layer '" layName "' dalam kondisi LOCKED. Buka kunci layer lalu jalankan ulang."))))
        (t
         (list (cons "STATUS"  "OK")
               (cons "CREATED" nil)))
      )
    )
    (progn
      (setq okMake
        (not (null
          (entmake
            (list
              (cons 0 "LAYER")
              (cons 100 "AcDbSymbolTableRecord")
              (cons 100 "AcDbLayerTableRecord")
              (cons 2 layName)
              (cons 70 0)
              (cons 62 3)
              (cons 6 "CONTINUOUS")
            )
          )
        ))
      )
      (if (and okMake (tblsearch "LAYER" layName))
        (list (cons "STATUS"  "OK")
              (cons "CREATED" T))
        (list (cons "STATUS" "ERROR")
              (cons "ERROR" (strcat "Gagal membuat layer '" layName "'.")))
      )
    )
  )
)

;;; ============================================================================
;;; SECTION 12: XDATA IDENTITY & BATCH ID ENGINE (ASDIM_OBJ)
;;; 7 Field: SourceGroupID, DimBatchID, Orientation, DimType,
;;;          SlotIdx, Placement, SchemaVer
;;; ============================================================================

(defun asdim:make-dim-xdata (sourceGroupId batchId orient dimType slotIdx placement schemaVer)
  (list -3
    (list (asdim:dim-xdata-app)
      (cons 1000 sourceGroupId)
      (cons 1000 batchId)
      (cons 1000 orient)
      (cons 1000 dimType)
      (cons 1070 slotIdx)
      (cons 1000 placement)
      (cons 1000 schemaVer)
    )
  )
)

;; Baca kembali & validasi 7 field XData ASDIM_OBJ pada entitas DIMENSION
(defun asdim:parse-dim-xdata (ename / entData xrec vals sgid bid ori dtype sidx plc sver)
  (if (or (null ename) (not (= (type ename) 'ENAME)) (null (entget ename)))
    nil
    (progn
      (setq entData (entget ename (list (asdim:dim-xdata-app)))
            xrec    (cadr (assoc -3 entData)))
      (if (and xrec (>= (length (cdr xrec)) 7))
        (progn
          (setq vals  (cdr xrec)
                sgid  (if (= (car (nth 0 vals)) 1000) (cdr (nth 0 vals)) nil)
                bid   (if (= (car (nth 1 vals)) 1000) (cdr (nth 1 vals)) nil)
                ori   (if (= (car (nth 2 vals)) 1000) (cdr (nth 2 vals)) nil)
                dtype (if (= (car (nth 3 vals)) 1000) (cdr (nth 3 vals)) nil)
                sidx  (if (= (car (nth 4 vals)) 1070) (cdr (nth 4 vals)) nil)
                plc   (if (= (car (nth 5 vals)) 1000) (cdr (nth 5 vals)) nil)
                sver  (if (= (car (nth 6 vals)) 1000) (cdr (nth 6 vals)) nil))
          (if (and (= (type sgid) 'STR) (> (strlen (asdim:trim sgid)) 0)
                   (= (type bid)  'STR) (> (strlen (asdim:trim bid))  0)
                   (member ori '("H" "V"))
                   (member dtype '("CHAIN" "OVERALL"))
                   (= (type sidx) 'INT) (>= sidx 0)
                   (member plc '("TOP" "BOTTOM" "LEFT" "RIGHT"))
                   (= (type sver) 'STR) (> (strlen (asdim:trim sver)) 0))
            (list (cons "SOURCE_GROUP_ID" sgid)
                  (cons "DIM_BATCH_ID"    bid)
                  (cons "ORIENTATION"     ori)
                  (cons "DIM_TYPE"        dtype)
                  (cons "SLOT_IDX"        sidx)
                  (cons "PLACEMENT"       plc)
                  (cons "SCHEMA_VER"      sver))
            nil
          )
        )
        nil
      )
    )
  )
)

;; Format angka bulat menjadi 4 digit dengan leading zero (mis. 1 -> "0001")
(defun asdim:pad4 (n / s)
  (setq s (itoa n))
  (while (< (strlen s) 4)
    (setq s (strcat "0" s))
  )
  s
)

;; Pindai Model Space untuk ASDIM_OBJ eksisting -> hasilkan Batch ID unik berikutnya
;; serta jumlah dimensi ASDIM eksisting pada sourceGroupId (untuk peringatan Phase 2)
(defun asdim:scan-existing-dim-batches (sourceGroupId /
                                        ss i ename parsed bid numStr numVal
                                        maxBatchNum existingForGroup)
  (setq maxBatchNum      0
        existingForGroup 0
        ss (ssget "_X" (list '(0 . "DIMENSION") '(410 . "Model")
                             (list -3 (list (asdim:dim-xdata-app))))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename (ssname ss i))
        (if (asdim:is-model-space-entity ename)
          (progn
            (setq parsed (asdim:parse-dim-xdata ename))
            (if parsed
              (progn
                (if (= (cdr (assoc "SOURCE_GROUP_ID" parsed)) sourceGroupId)
                  (setq existingForGroup (1+ existingForGroup))
                )
                (setq bid (cdr (assoc "DIM_BATCH_ID" parsed)))
                (if (and (= (type bid) 'STR)
                         (> (strlen bid) 6)
                         (= (strcase (substr bid 1 6)) "ASDIM-"))
                  (progn
                    (setq numStr (substr bid 7)
                          numVal (atoi numStr))
                    (if (> numVal maxBatchNum)
                      (setq maxBatchNum numVal)
                    )
                  )
                )
              )
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )
  (list (cons "NEXT_BATCH_ID"      (strcat "ASDIM-" (asdim:pad4 (1+ maxBatchNum))))
        (cons "EXISTING_FOR_GROUP" existingForGroup))
)

;;; ============================================================================
;;; SECTION 13: BUBBLE CLEARANCE & DIMENSION PLAN CALCULATOR
;;; Acuan: ASDIM V1_0 SPEK R3 Section 7 & Section 9
;;; ============================================================================

;; Hitung minimum clearance d_clear terhadap bubble ASGRID R3 pada sisi placement
(defun asdim:calc-bubble-clearance (spec placement /
                                    ext annoExt bDia sc bPos drawStart drawEnd hasBub rawClear)
  (setq ext       (float (cdr (assoc "EXT_LEN" spec)))
        annoExt   (float (asdim:get-anno-ext-len spec))
        bDia      (float (cdr (assoc "BUBBLE_DIA_PRINT" spec)))
        sc        (float (cdr (assoc "SCALE_DENOM" spec)))
        bPos      (cdr (assoc "BUBBLE_POS" spec))
        drawStart (or (= bPos "Both Ends") (= bPos "Start"))
        drawEnd   (or (= bPos "Both Ends") (= bPos "End"))
        hasBub    (cond
                    ((= placement "TOP")    drawEnd)
                    ((= placement "BOTTOM") drawStart)
                    ((= placement "LEFT")   drawStart)
                    ((= placement "RIGHT")  drawEnd)
                    (t nil)))
  (if hasBub
    (progn
      (setq rawClear (- (+ annoExt (* bDia sc)) ext))
      (if (> rawClear 0.0) rawClear 0.0)
    )
    0.0
  )
)

;; Bangun daftar job dimensi lengkap (WCS) sebelum satu pun entitas dibuat
(defun asdim:build-dim-plan (groupId spec coords cfg /
                             x0 y0 z0 ext cumX cumY xMin xMax yMin yMax
                             nH nV sc uf
                             doHChain doHOverall doVChain doVOverall
                             hPlace vPlace d1 rowGap d2 dOvH dOvV
                             jobs seenSlots slotKey
                             k p1 p2 loc meas)
  (setq x0         (cdr (assoc "X0" coords))
        y0         (cdr (assoc "Y0" coords))
        z0         (cdr (assoc "Z0" coords))
        ext        (cdr (assoc "EXT_LEN" coords))
        cumX       (cdr (assoc "CUM_X" coords))
        cumY       (cdr (assoc "CUM_Y" coords))
        xMin       x0
        xMax       (last cumX)
        yMin       y0
        yMax       (last cumY)
        nH         (cdr (assoc "NUM_H" spec))
        nV         (cdr (assoc "NUM_V" spec))
        sc         (float (cdr (assoc "SCALE_DENOM" spec)))
        uf         (float (cdr (assoc "UNIT_FACTOR" cfg)))
        doHChain   (and (cdr (assoc "DO_H_CHAIN" cfg))   (>= nV 2))
        doHOverall (and (cdr (assoc "DO_H_OVERALL" cfg)) (>= nV 2))
        doVChain   (and (cdr (assoc "DO_V_CHAIN" cfg))   (>= nH 2))
        doVOverall (and (cdr (assoc "DO_V_OVERALL" cfg)) (>= nH 2))
        hPlace     (cdr (assoc "H_PLACE" cfg))
        vPlace     (cdr (assoc "V_PLACE" cfg))
        d1         (* (float (cdr (assoc "CHAIN_OFF_PRINT" cfg))) sc uf)
        rowGap     (* (float (cdr (assoc "ROW_GAP_PRINT" cfg)))   sc uf)
        d2         (+ d1 rowGap)
        dOvH       (if doHChain d2 d1)
        dOvV       (if doVChain d2 d1)
        jobs       '()
        seenSlots  '())

  ;; A. Horizontal Chain (mengukur sepanjang X menggunakan cumX / DIST_V)
  (if doHChain
    (progn
      (setq k 0)
      (while (< k (1- nV))
        (setq meas (- (nth (1+ k) cumX) (nth k cumX)))
        (if (= hPlace "TOP")
          (setq p1  (list (nth k cumX)      (+ yMax ext) z0)
                p2  (list (nth (1+ k) cumX) (+ yMax ext) z0)
                loc (list (/ (+ (nth k cumX) (nth (1+ k) cumX)) 2.0) (+ yMax ext d1) z0))
          (setq p1  (list (nth k cumX)      (- yMin ext) z0)
                p2  (list (nth (1+ k) cumX) (- yMin ext) z0)
                loc (list (/ (+ (nth k cumX) (nth (1+ k) cumX)) 2.0) (- yMin ext d1) z0))
        )
        (setq slotKey (strcat groupId "|H|CHAIN|" (itoa (1+ k)) "|" hPlace))
        (if (and (> meas 0.0) (not (member slotKey seenSlots)))
          (setq seenSlots (cons slotKey seenSlots)
                jobs      (append jobs (list (list (cons "ORIENT"    "H")
                                                   (cons "DIMTYPE"   "CHAIN")
                                                   (cons "SLOT_IDX"  (1+ k))
                                                   (cons "PLACEMENT" hPlace)
                                                   (cons "EXT1"      p1)
                                                   (cons "EXT2"      p2)
                                                   (cons "DIMLOC"    loc)
                                                   (cons "ROT_RAD"   0.0)
                                                   (cons "EXP_MEAS"  meas)))))
        )
        (setq k (1+ k))
      )
    )
  )

  ;; B. Horizontal Overall (SlotIdx = 0)
  (if doHOverall
    (progn
      (setq meas (- xMax xMin))
      (if (= hPlace "TOP")
        (setq p1  (list xMin (+ yMax ext) z0)
              p2  (list xMax (+ yMax ext) z0)
              loc (list (/ (+ xMin xMax) 2.0) (+ yMax ext dOvH) z0))
        (setq p1  (list xMin (- yMin ext) z0)
              p2  (list xMax (- yMin ext) z0)
              loc (list (/ (+ xMin xMax) 2.0) (- yMin ext dOvH) z0))
      )
      (setq slotKey (strcat groupId "|H|OVERALL|0|" hPlace))
      (if (and (> meas 0.0) (not (member slotKey seenSlots)))
        (setq seenSlots (cons slotKey seenSlots)
              jobs      (append jobs (list (list (cons "ORIENT"    "H")
                                                 (cons "DIMTYPE"   "OVERALL")
                                                 (cons "SLOT_IDX"  0)
                                                 (cons "PLACEMENT" hPlace)
                                                 (cons "EXT1"      p1)
                                                 (cons "EXT2"      p2)
                                                 (cons "DIMLOC"    loc)
                                                 (cons "ROT_RAD"   0.0)
                                                 (cons "EXP_MEAS"  meas)))))
      )
    )
  )

  ;; C. Vertical Chain (mengukur sepanjang Y menggunakan cumY / DIST_H)
  (if doVChain
    (progn
      (setq k 0)
      (while (< k (1- nH))
        (setq meas (- (nth (1+ k) cumY) (nth k cumY)))
        (if (= vPlace "LEFT")
          (setq p1  (list (- xMin ext) (nth k cumY)      z0)
                p2  (list (- xMin ext) (nth (1+ k) cumY) z0)
                loc (list (- xMin ext d1) (/ (+ (nth k cumY) (nth (1+ k) cumY)) 2.0) z0))
          (setq p1  (list (+ xMax ext) (nth k cumY)      z0)
                p2  (list (+ xMax ext) (nth (1+ k) cumY) z0)
                loc (list (+ xMax ext d1) (/ (+ (nth k cumY) (nth (1+ k) cumY)) 2.0) z0))
        )
        (setq slotKey (strcat groupId "|V|CHAIN|" (itoa (1+ k)) "|" vPlace))
        (if (and (> meas 0.0) (not (member slotKey seenSlots)))
          (setq seenSlots (cons slotKey seenSlots)
                jobs      (append jobs (list (list (cons "ORIENT"    "V")
                                                   (cons "DIMTYPE"   "CHAIN")
                                                   (cons "SLOT_IDX"  (1+ k))
                                                   (cons "PLACEMENT" vPlace)
                                                   (cons "EXT1"      p1)
                                                   (cons "EXT2"      p2)
                                                   (cons "DIMLOC"    loc)
                                                   (cons "ROT_RAD"   (/ pi 2.0))
                                                   (cons "EXP_MEAS"  meas)))))
        )
        (setq k (1+ k))
      )
    )
  )

  ;; D. Vertical Overall (SlotIdx = 0)
  (if doVOverall
    (progn
      (setq meas (- yMax yMin))
      (if (= vPlace "LEFT")
        (setq p1  (list (- xMin ext) yMin z0)
              p2  (list (- xMin ext) yMax z0)
              loc (list (- xMin ext dOvV) (/ (+ yMin yMax) 2.0) z0))
        (setq p1  (list (+ xMax ext) yMin z0)
              p2  (list (+ xMax ext) yMax z0)
              loc (list (+ xMax ext dOvV) (/ (+ yMin yMax) 2.0) z0))
      )
      (setq slotKey (strcat groupId "|V|OVERALL|0|" vPlace))
      (if (and (> meas 0.0) (not (member slotKey seenSlots)))
        (setq seenSlots (cons slotKey seenSlots)
              jobs      (append jobs (list (list (cons "ORIENT"    "V")
                                                 (cons "DIMTYPE"   "OVERALL")
                                                 (cons "SLOT_IDX"  0)
                                                 (cons "PLACEMENT" vPlace)
                                                 (cons "EXT1"      p1)
                                                 (cons "EXT2"      p2)
                                                 (cons "DIMLOC"    loc)
                                                 (cons "ROT_RAD"   (/ pi 2.0))
                                                 (cons "EXP_MEAS"  meas)))))
      )
    )
  )

  jobs
)

;;; ============================================================================
;;; SECTION 14: ACTIVEX DIMENSION GENERATOR & SAFE BATCH CLEANUP
;;; ============================================================================

;; Buat satu entitas DIMENSION native via vla-AddDimRotated, pasang properti,
;; sematkan XData ASDIM_OBJ, lalu verifikasi penuh hasil baca-balik.
(defun asdim:create-single-dim (ms groupId batchId job textH_DU arrowSz_DU dimDec /
                                p1 p2 loc rotRad expMeas
                                layName dsName
                                dimObj ename rLay rSty rTxt rArr rPrec rUpd
                                ed xdata newEd modOk
                                readBack rbSty rbMeas rbTxt rbArr rbLay tolVer errMsg)
  (setq p1      (cdr (assoc "EXT1" job))
        p2      (cdr (assoc "EXT2" job))
        loc     (cdr (assoc "DIMLOC" job))
        rotRad  (float (cdr (assoc "ROT_RAD" job)))
        expMeas (float (cdr (assoc "EXP_MEAS" job)))
        layName (asdim:layer-name)
        dsName  (asdim:dim-style-name)
        tolVer  1e-3
        ename   nil
        errMsg  nil)

  ;; 1. Buat entitas native AcDbRotatedDimension melalui ActiveX
  (setq dimObj
    (vl-catch-all-apply 'vla-AddDimRotated
      (list ms
            (vlax-3d-point p1)
            (vlax-3d-point p2)
            (vlax-3d-point loc)
            rotRad)))

  (if (or (vl-catch-all-error-p dimObj) (null dimObj))
    (setq errMsg (strcat "vla-AddDimRotated gagal: "
                         (if (vl-catch-all-error-p dimObj)
                           (vl-catch-all-error-message dimObj)
                           "objek nil")))
    (progn
      (setq ename (vlax-vla-object->ename dimObj))
      ;; 2. Tetapkan properti langsung pada objek dimensi (tanpa ubah sysvar global)
      (setq rLay  (vl-catch-all-apply 'vla-put-Layer (list dimObj layName))
            rSty  (vl-catch-all-apply 'vla-put-StyleName (list dimObj dsName))
            rTxt  (vl-catch-all-apply 'vla-put-TextHeight (list dimObj (float textH_DU)))
            rArr  (vl-catch-all-apply 'vla-put-ArrowheadSize (list dimObj (float arrowSz_DU)))
            rPrec (vl-catch-all-apply 'vla-put-PrimaryUnitsPrecision (list dimObj dimDec)))
      (cond
        ((vl-catch-all-error-p rLay)
         (setq errMsg (strcat "Gagal mengatur Layer pada dimensi: " (vl-catch-all-error-message rLay))))
        ((vl-catch-all-error-p rSty)
         (setq errMsg (strcat "Gagal mengatur StyleName pada dimensi: " (vl-catch-all-error-message rSty))))
        ((vl-catch-all-error-p rTxt)
         (setq errMsg (strcat "Gagal mengatur TextHeight pada dimensi: " (vl-catch-all-error-message rTxt))))
        ((vl-catch-all-error-p rArr)
         (setq errMsg (strcat "Gagal mengatur ArrowheadSize pada dimensi: " (vl-catch-all-error-message rArr))))
        ((vl-catch-all-error-p rPrec)
         (setq errMsg (strcat "Gagal mengatur PrimaryUnitsPrecision pada dimensi: " (vl-catch-all-error-message rPrec))))
      )

      ;; 3. Sematkan XData identitas ASDIM_OBJ
      (if (null errMsg)
        (progn
          (setq ed    (entget ename)
                xdata (asdim:make-dim-xdata
                        groupId
                        batchId
                        (cdr (assoc "ORIENT" job))
                        (cdr (assoc "DIMTYPE" job))
                        (cdr (assoc "SLOT_IDX" job))
                        (cdr (assoc "PLACEMENT" job))
                        (asdim:dim-schema-ver))
                newEd (append ed (list xdata))
                modOk (entmod newEd))
          (if (null modOk)
            (setq errMsg "Gagal menulis XData ASDIM_OBJ pada entitas DIMENSION.")
          )
        )
      )

      ;; 4. Update & verifikasi baca-balik lengkap
      (if (null errMsg)
        (progn
          (setq rUpd (vl-catch-all-apply 'vla-Update (list dimObj)))
          (if (vl-catch-all-error-p rUpd)
            (setq errMsg (strcat "vla-Update gagal pada dimensi: " (vl-catch-all-error-message rUpd)))
            (progn
              (setq ed       (entget ename)
                    readBack (asdim:parse-dim-xdata ename)
                    rbLay    (if ed (cdr (assoc 8 ed)) nil)
                    rbSty    (vl-catch-all-apply 'vla-get-StyleName (list dimObj))
                    rbTxt    (vl-catch-all-apply 'vla-get-TextHeight (list dimObj))
                    rbArr    (vl-catch-all-apply 'vla-get-ArrowheadSize (list dimObj))
                    rbMeas   (vl-catch-all-apply 'vla-get-Measurement (list dimObj)))
              (cond
                ((or (null ed) (/= (cdr (assoc 0 ed)) "DIMENSION"))
                 (setq errMsg "Verifikasi gagal: entitas bukan DIMENSION valid."))
                ((not (asdim:is-model-space-entity ename))
                 (setq errMsg "Verifikasi gagal: entitas dimensi tidak berada di Model Space."))
                ((or (null rbLay) (/= (strcase rbLay) (strcase layName)))
                 (setq errMsg (strcat "Verifikasi gagal: layer aktual '" (if rbLay rbLay "") "' != '" layName "'.")))
                ((or (vl-catch-all-error-p rbSty) (/= (strcase rbSty) (strcase dsName)))
                 (setq errMsg (strcat "Verifikasi gagal: StyleName bukan '" dsName "'.")))
                ((or (vl-catch-all-error-p rbTxt) (> (abs (- (float rbTxt) (float textH_DU))) tolVer))
                 (setq errMsg "Verifikasi gagal: TextHeight aktual tidak sesuai target DU."))
                ((or (vl-catch-all-error-p rbArr) (> (abs (- (float rbArr) (float arrowSz_DU))) tolVer))
                 (setq errMsg "Verifikasi gagal: ArrowheadSize aktual tidak sesuai target DU."))
                ((or (vl-catch-all-error-p rbMeas) (> (abs (- (float rbMeas) expMeas)) tolVer))
                 (setq errMsg (strcat "Verifikasi gagal: Measurement aktual tidak sama dengan jarak grid DU ("
                                      (asdim:format-real expMeas) ").")))
                ((or (null readBack)
                     (/= (cdr (assoc "SOURCE_GROUP_ID" readBack)) groupId)
                     (/= (cdr (assoc "DIM_BATCH_ID" readBack)) batchId)
                     (/= (cdr (assoc "ORIENTATION" readBack)) (cdr (assoc "ORIENT" job)))
                     (/= (cdr (assoc "DIM_TYPE" readBack)) (cdr (assoc "DIMTYPE" job)))
                     (/= (cdr (assoc "SLOT_IDX" readBack)) (cdr (assoc "SLOT_IDX" job)))
                     (/= (cdr (assoc "PLACEMENT" readBack)) (cdr (assoc "PLACEMENT" job))))
                 (setq errMsg "Verifikasi gagal: XData ASDIM_OBJ baca-balik tidak cocok."))
              )
            )
          )
        )
      )
    )
  )

  (if (null errMsg)
    (list (cons "STATUS" "OK")
          (cons "ENAME"  ename))
    (list (cons "STATUS" "ERROR")
          (cons "ENAME"  ename)
          (cons "ERROR"  errMsg))
  )
)

;; Cleanup aman khusus entitas baru pada batch berjalan (tidak menyentuh dimensi lama / ASGRID / tabel resource)
(defun asdim:cleanup-batch-entities (enameList / e delCnt failCnt)
  (setq delCnt  0
        failCnt 0)
  (foreach e enameList
    (if (and e (= (type e) 'ENAME))
      (if (entget e)
        (if (entdel e)
          (setq delCnt (1+ delCnt))
          (setq failCnt (1+ failCnt))
        )
      )
    )
  )
  (list (cons "DELETED" delCnt)
        (cons "FAILED"  failCnt))
)

;;; ============================================================================
;;; SECTION 15: COMMAND-LINE CONFIGURATION INTERFACE (PHASE 2 CLI SEMENTARA)
;;; ============================================================================

;; Prompt bilangan real > 0 dengan nilai default
(defun asdim:prompt-pos-real (label defVal / val done)
  (setq done nil
        val  nil)
  (while (not done)
    (setq val (getreal (strcat "\n" label " <" (asdim:format-real defVal) ">: ")))
    (cond
      ((null val)
       (setq val  (float defVal)
             done T))
      ((> val 0.0)
       (setq val  (float val)
             done T))
      (t
       (princ "\n  [Input tidak valid] Nilai harus lebih besar dari 0."))
    )
  )
  val
)

;; Prompt pilihan Ya/Tidak dengan default
(defun asdim:prompt-yes-no (label defYes / kw)
  (initget "Yes No")
  (setq kw (getkword (strcat "\n" label " [Yes/No] <" (if defYes "Yes" "No") ">: ")))
  (cond
    ((null kw) defYes)
    ((= kw "Yes") T)
    (t nil)
  )
)

;; Kumpulkan seluruh konfigurasi Phase 2 melalui command line
(defun asdim:prompt-cli-config (spec metaRes existingForGroup /
                                insUnits recUnit unitKw unitFactor unitConf
                                canH canV doHC doHO doVC doVO
                                hPlace vPlace chainOff rowGap txtH arrSz prec
                                sc d1 clearH clearV proceedAdd)
  (setq insUnits (getvar "INSUNITS")
        recUnit  (cond
                   ((= insUnits 4) "MM")
                   ((= insUnits 5) "CM")
                   ((= insUnits 6) "M")
                   (t "MM"))
        canH     (cdr (assoc "CAN_DIM_H" metaRes))
        canV     (cdr (assoc "CAN_DIM_V" metaRes))
        sc       (float (cdr (assoc "SCALE_DENOM" spec))))

  ;; 1. Peringatan dimensi ASDIM eksisting pada grup yang sama (Phase 2 tidak menghapus dimensi lama)
  (if (> existingForGroup 0)
    (progn
      (princ (strcat "\n\n[PERINGATAN PHASE 2] Ditemukan " (itoa existingForGroup)
                     " dimensi ASDIM_OBJ eksisting pada grup ini."))
      (princ "\n  Phase 2 TIDAK menghapus dimensi lama. Lanjut akan menambah batch dimensi baru.")
      (setq proceedAdd (asdim:prompt-yes-no "Lanjutkan membuat batch dimensi tambahan?" nil))
      (if (not proceedAdd)
        (setq unitConf nil)
        (setq unitConf 'ASK)
      )
    )
    (setq unitConf 'ASK)
  )

  (if (null unitConf)
    nil
    (progn
      ;; 2. Konfirmasi satuan gambar wajib (termasuk saat INSUNITS = 4)
      (princ (strcat "\n\n--- KONFIRMASI SATUAN GAMBAR (WAJIB) ---"))
      (princ (strcat "\n  INSUNITS saat ini (informasional) = "
                     (if (= (type insUnits) 'INT) (itoa insUnits) "<unknown>")
                     " (rekomendasi awal: " recUnit "; INSUNITS tidak akan diubah)."))
      (initget "MM CM M Cancel")
      (setq unitKw (getkword (strcat "\nPilih satuan aktual koordinat gambar [MM/CM/M/Cancel] <" recUnit ">: ")))
      (if (null unitKw) (setq unitKw recUnit))
      (if (= unitKw "Cancel")
        nil
        (progn
          (setq unitFactor
            (cond
              ((= unitKw "MM") 1.0)
              ((= unitKw "CM") 0.1)
              ((= unitKw "M")  0.001)
              (t nil)))
          (if (not (asdim:prompt-yes-no
                     (strcat "Konfirmasi satuan aktual gambar = " unitKw
                             " (unitFactor=" (asdim:format-real unitFactor)
                             " hanya untuk ukuran cetak; nilai jarak grid DU tidak diubah)?")
                     nil))
            (progn
              (princ "\n[ASDIM] Konfirmasi satuan tidak diberikan. Proses dihentikan tanpa membuat dimensi.")
              nil
            )
            (progn
              ;; 3. Pilihan orientasi & tipe dimensi
              (setq doHC nil doHO nil doVC nil doVO nil
                    hPlace "TOP" vPlace "LEFT")
              (if canH
                (progn
                  (setq doHC (asdim:prompt-yes-no "Buat Horizontal Chain Dimension (arah X / DIST_V)?" T)
                        doHO (asdim:prompt-yes-no "Buat Horizontal Overall Dimension (arah X)?" T))
                  (if (or doHC doHO)
                    (progn
                      (initget "Top Bottom")
                      (setq hPlace (getkword "\nPosisi Horizontal Dimension [Top/Bottom] <Top>: "))
                      (setq hPlace (if (= hPlace "Bottom") "BOTTOM" "TOP"))
                    )
                  )
                )
                (princ "\n  [INFO] Horizontal Dimension dilewati karena NUM_V < 2.")
              )
              (if canV
                (progn
                  (setq doVC (asdim:prompt-yes-no "Buat Vertical Chain Dimension (arah Y / DIST_H)?" T)
                        doVO (asdim:prompt-yes-no "Buat Vertical Overall Dimension (arah Y)?" T))
                  (if (or doVC doVO)
                    (progn
                      (initget "Left Right")
                      (setq vPlace (getkword "\nPosisi Vertical Dimension [Left/Right] <Left>: "))
                      (setq vPlace (if (= vPlace "Right") "RIGHT" "LEFT"))
                    )
                  )
                )
                (princ "\n  [INFO] Vertical Dimension dilewati karena NUM_H < 2.")
              )

              (if (not (or doHC doHO doVC doVO))
                (progn
                  (princ "\n[ASDIM] Tidak ada tipe dimensi yang dipilih. Proses dibatalkan.")
                  nil
                )
                (progn
                  ;; 4. Offset, Row Spacing, Text Height, Arrow Size, Precision
                  (setq chainOff (asdim:prompt-pos-real "Chain Offset / Offset Baris Pertama (printed mm)" 8.0)
                        rowGap   (if (or (and doHC doHO) (and doVC doVO))
                                   (asdim:prompt-pos-real "Row Spacing antarbaris Chain & Overall (printed mm)" 8.0)
                                   8.0)
                        txtH     (asdim:prompt-pos-real "Printed Text Height (mm)" 2.5)
                        arrSz    (asdim:prompt-pos-real "Printed Arrow Size (mm)" 2.0))

                  (initget "0 1 2 3 4")
                  (setq prec (getkword "\nDecimal Precision [0/1/2/3/4] <0>: "))
                  (setq prec (if prec (atoi prec) 0))

                  ;; 5. Peringatan bubble clearance (non-blocking, sesuai Spek R3 Section 9)
                  (setq d1 (* chainOff sc unitFactor))
                  (if (or doHC doHO)
                    (progn
                      (setq clearH (asdim:calc-bubble-clearance spec hPlace))
                      (if (and (> clearH 0.0) (<= d1 clearH))
                        (princ (strcat "\n  [PERINGATAN BUBBLE] Offset Horizontal " hPlace " ("
                                       (asdim:format-real d1) " DU) <= clearance bubble ASGRID ("
                                       (asdim:format-real clearH) " DU); dimensi dapat menumpuk bubble."))
                      )
                    )
                  )
                  (if (or doVC doVO)
                    (progn
                      (setq clearV (asdim:calc-bubble-clearance spec vPlace))
                      (if (and (> clearV 0.0) (<= d1 clearV))
                        (princ (strcat "\n  [PERINGATAN BUBBLE] Offset Vertical " vPlace " ("
                                       (asdim:format-real d1) " DU) <= clearance bubble ASGRID ("
                                       (asdim:format-real clearV) " DU); dimensi dapat menumpuk bubble."))
                      )
                    )
                  )

                  (list (cons "UNIT_LABEL"      unitKw)
                        (cons "UNIT_FACTOR"     unitFactor)
                        (cons "DO_H_CHAIN"      doHC)
                        (cons "DO_H_OVERALL"    doHO)
                        (cons "DO_V_CHAIN"      doVC)
                        (cons "DO_V_OVERALL"    doVO)
                        (cons "H_PLACE"         hPlace)
                        (cons "V_PLACE"         vPlace)
                        (cons "CHAIN_OFF_PRINT" chainOff)
                        (cons "ROW_GAP_PRINT"   rowGap)
                        (cons "TEXT_H_PRINT"    txtH)
                        (cons "ARROW_SZ_PRINT"  arrSz)
                        (cons "PRECISION"       prec))
                )
              )
            )
          )
        )
      )
    )
  )
)

;;; ============================================================================
;;; SECTION 16: MAIN COMMAND (c:ASDIM — PHASE 2 STYLE ENGINE + DIMENSION GENERATOR)
;;; ============================================================================

(defun c:ASDIM ( / *error* sel ename xRes xStatus groupId xSchemaVer
                   readRes spec metaRes coords disc geomRes
                   scanRes batchId existingCnt cfg
                   axRes doc ms
                   sc uf textH_DU arrowSz_DU dimDec
                   stRes dsRes layRes
                   dimPlan job createRes createdEnts batchActive batchErr cleanRes)

  (setq createdEnts '()
        batchActive nil)

  ;; Error handler lokal: hanya membersihkan entitas dimensi baru pada batch berjalan
  (defun *error* (msg / isCancel cln)
    (if (and batchActive createdEnts)
      (progn
        (setq cln (asdim:cleanup-batch-entities createdEnts)
              batchActive nil)
        (princ (strcat "\n[" (asdim:version-label) " CLEANUP] Interupsi saat pembuatan batch: "
                       (itoa (cdr (assoc "DELETED" cln))) " dimensi baru dihapus, "
                       (itoa (cdr (assoc "FAILED" cln))) " gagal dihapus."))
        (if (> (cdr (assoc "FAILED" cln)) 0)
          (princ "\n  [PERINGATAN] Sebagian dimensi baru gagal dibersihkan; periksa gambar secara manual.")
        )
      )
    )
    (setq isCancel (member msg '("Function cancelled"
                                 "quit / exit abort"
                                 "console break")))
    (cond
      ((or (null msg) isCancel)
       (princ (strcat "\n[" (asdim:version-label) "] Dibatalkan oleh pengguna.")))
      (t
       (princ (strcat "\n[" (asdim:version-label) " ERROR] " msg)))
    )
    (princ)
  )

  (princ (strcat "\n[" (asdim:version-label) "] Automatic Grid Dimension Generator (Phase 2 CLI)."))

  ;; === TAHAP 1: AUDIT WAJIB PHASE 1 R1 (READ-ONLY) ===
  (setq sel (entsel "\nPilih salah satu objek grid milik ASGRID (LINE / BUBBLE / TEXT): "))
  (cond
    ((null sel)
     (princ (strcat "\n[" (asdim:version-label) "] Tidak ada objek yang dipilih. Proses dihentikan.")))
    ((not (asdim:is-model-space-entity (setq ename (car sel))))
     (princ (strcat "\n[" (asdim:version-label) " GAGAL] Objek yang dipilih bukan berasal dari Model Space.")))
    (t
     (setq xRes    (asdim:parse-asgrid-xdata ename)
           xStatus (cdr (assoc "STATUS" xRes)))
     (if (/= xStatus "OK")
       (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" xRes))))
       (progn
         (setq groupId    (cdr (assoc "GROUP_ID" xRes))
               xSchemaVer (cdr (assoc "SCHEMA_VER" xRes))
               readRes    (asdim:meta-read-group groupId))
         (if (/= (cdr (assoc "STATUS" readRes)) "OK")
           (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" readRes))))
           (progn
             (setq spec    (cdr (assoc "SPEC" readRes))
                   metaRes (asdim:meta-validate-spec spec groupId xSchemaVer))
             (if (not (cdr (assoc "VALID" metaRes)))
               (asdim:print-audit-report groupId spec metaRes nil nil nil)
               (progn
                 (setq coords  (asdim:calc-grid-coords spec)
                       disc    (asdim:discover-group-entities groupId)
                       geomRes (asdim:validate-grid-geometry spec coords disc))
                 (asdim:print-audit-report groupId spec metaRes coords disc geomRes)

                 ;; === TAHAP 2: KONFIGURASI, STYLE ENGINE & DIMENSION GENERATOR ===
                 (if (cdr (assoc "VALID" geomRes))
                   (progn
                     (setq scanRes     (asdim:scan-existing-dim-batches groupId)
                           batchId     (cdr (assoc "NEXT_BATCH_ID" scanRes))
                           existingCnt (cdr (assoc "EXISTING_FOR_GROUP" scanRes))
                           cfg         (asdim:prompt-cli-config spec metaRes existingCnt))
                     (if cfg
                       (progn
                         ;; 2A. Verifikasi ActiveX
                         (setq axRes (asdim:ensure-activex))
                         (if (/= (cdr (assoc "STATUS" axRes)) "OK")
                           (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" axRes))))
                           (progn
                             (setq doc        (cdr (assoc "DOC" axRes))
                                   ms         (cdr (assoc "MS"  axRes))
                                   sc         (float (cdr (assoc "SCALE_DENOM" spec)))
                                   uf         (float (cdr (assoc "UNIT_FACTOR" cfg)))
                                   textH_DU   (* (float (cdr (assoc "TEXT_H_PRINT" cfg)))   sc uf)
                                   arrowSz_DU (* (float (cdr (assoc "ARROW_SZ_PRINT" cfg))) sc uf)
                                   dimDec     (cdr (assoc "PRECISION" cfg)))

                             ;; 2B. Pre-check RegApp ASDIM_OBJ, Text Style, Dim Style, Layer
                             (cond
                               ((not (asdim:ensure-regapp (asdim:dim-xdata-app)))
                                (princ (strcat "\n[" (asdim:version-label) " GAGAL] Gagal mendaftarkan RegApp '" (asdim:dim-xdata-app) "'.")))
                               ((/= (cdr (assoc "STATUS" (setq stRes (asdim:ensure-arial-style)))) "OK")
                                (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" stRes)))))
                               ((/= (cdr (assoc "STATUS" (setq dsRes (asdim:ensure-dim-style doc (cdr (assoc "ENAME" stRes)) textH_DU arrowSz_DU dimDec)))) "OK")
                                (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" dsRes)))))
                               ((/= (cdr (assoc "STATUS" (setq layRes (asdim:ensure-dim-layer)))) "OK")
                                (princ (strcat "\n[" (asdim:version-label) " GAGAL] " (cdr (assoc "ERROR" layRes)))))
                               (t
                                ;; 2C. Bangun rencana dimensi & eksekusi batch dengan safe cleanup
                                (setq dimPlan (asdim:build-dim-plan groupId spec coords cfg))
                                (if (null dimPlan)
                                  (princ (strcat "\n[" (asdim:version-label) " GAGAL] Rencana dimensi kosong."))
                                  (progn
                                    (setq batchActive T
                                          batchErr    nil)
                                    (foreach job dimPlan
                                      (if (null batchErr)
                                        (progn
                                          (setq createRes (asdim:create-single-dim ms groupId batchId job textH_DU arrowSz_DU dimDec))
                                          (if (cdr (assoc "ENAME" createRes))
                                            (setq createdEnts (cons (cdr (assoc "ENAME" createRes)) createdEnts))
                                          )
                                          (if (/= (cdr (assoc "STATUS" createRes)) "OK")
                                            (setq batchErr (cdr (assoc "ERROR" createRes)))
                                          )
                                        )
                                      )
                                    )
                                    (setq batchActive nil)
                                    (if batchErr
                                      (progn
                                        (setq cleanRes (asdim:cleanup-batch-entities createdEnts))
                                        (princ (strcat "\n[" (asdim:version-label) " GAGAL] Pembuatan batch dimensi dihentikan: " batchErr))
                                        (princ (strcat "\n  Safe Cleanup: " (itoa (cdr (assoc "DELETED" cleanRes)))
                                                       " dimensi baru dihapus, " (itoa (cdr (assoc "FAILED" cleanRes))) " gagal dihapus."))
                                        (if (> (cdr (assoc "FAILED" cleanRes)) 0)
                                          (princ "\n  [PERINGATAN] Sebagian dimensi baru gagal dihapus; periksa gambar secara manual.")
                                        )
                                        (princ "\n  Dimensi lama, entitas ASGRID, dan resource pra-eksisting tidak diubah.")
                                      )
                                      (progn
                                        (princ "\n======================================================================")
                                        (princ (strcat "\n  [" (asdim:version-label) "] GENERASI DIMENSI SELESAI"))
                                        (princ "\n======================================================================")
                                        (princ (strcat "\n  Source Group ID : " groupId))
                                        (princ (strcat "\n  Dim Batch ID    : " batchId))
                                        (princ (strcat "\n  Dimensi Dibuat  : " (itoa (length createdEnts)) " entitas native DIMENSION"))
                                        (princ (strcat "\n  Satuan Konfirm. : " (cdr (assoc "UNIT_LABEL" cfg))
                                                       " (unitFactor=" (asdim:format-real uf) ")"))
                                        (princ (strcat "\n  Style / Layer   : " (asdim:dim-style-name) " ("
                                                       (asdim:text-style-name) ") / " (asdim:layer-name)))
                                        (princ (strcat "\n  TextH / ArrowSz : " (asdim:format-real textH_DU)
                                                       " / " (asdim:format-real arrowSz_DU) " DU (Prec=" (itoa dimDec) ")"))
                                        (princ "\n======================================================================\n")
                                      )
                                    )
                                  )
                                ))
                             )
                           )
                         )
                       )
                     )
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

;; Pesan muat saat APPLOAD
(princ "\n[ASDIM V1.0-Phase2] Berhasil dimuat (Style Engine & Dimension Generator). Perintah: ASDIM.")
(princ)
