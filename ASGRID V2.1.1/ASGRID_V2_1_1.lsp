;;; ============================================================================
;;; PROGRAM     : ASGRID V2.1.1 - AUTOMATIC BUILDING GRID GENERATOR
;;;               (STABILITY & METADATA HARDENING)
;;; TARGET      : AutoCAD 2021 (AutoLISP Standar + DCL)
;;; BASELINE    : ASGRID_V2_1.lsp (V2.1 tetap dipertahankan sebagai backup)
;;; FILE TERKAIT: ASGRID_V2_1_1.dcl (harus tersedia di Support File Search Path)
;;; UNIT        : Millimeter (mm) pada Model Space (WCS)
;;; COMMANDS    :
;;;   - ASGRID      : Membuat grid baru dengan Live Preview & Hardened Metadata
;;;   - ASGRIDCHECK : Diagnostik integritas metadata & entitas (100% READ-ONLY)
;;; HARDENING V2.1.1 :
;;;   A. Metadata Verification sebagai Hard Gate (tulis -> baca balik ->
;;;      deep compare -> batalkan bila tidak cocok sebelum geometri dibuat).
;;;   B. Transaction Safety & Isolated Rollback (pelacakan ename via entmakex,
;;;      rollback hanya entitas & XRecord milik transaksi aktif saat gagal/ESC).
;;;   C. Exact Expected vs Actual Entity Count Validation + XData Verification.
;;;   D. Strict Metadata Integrity Validation (tipe data, rentang, keunikan).
;;;   E. Perintah diagnostik READ-ONLY ASGRIDCHECK (tanpa modifikasi otomatis).
;;; ============================================================================

;;; ============================================================================
;;; SHARED STATELESS METADATA & VALIDATION LIBRARY (PREFIX: asgrid:*)
;;; Catatan: Tidak ada variabel global data/state; seluruh fungsi murni
;;;          stateless sehingga aman dipakai bersama oleh ASGRID & ASGRIDCHECK
;;;          dan siap digunakan kembali oleh ASGRID EDIT di versi berikutnya.
;;; ============================================================================

(defun asgrid:dict-name () "ASGRID_GROUPS")
(defun asgrid:xdata-app () "ASGRID_OBJ")
(defun asgrid:valid-bubble-positions () '("Both Ends" "Start" "End"))

;; Hapus spasi/tab di awal dan akhir string
(defun asgrid:trim (s / res)
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

;; Parse bilangan bulat positif ketat
(defun asgrid:parse-pos-int (s / clean len idx ch ok val)
  (setq clean (asgrid:trim s)
        len   (strlen clean))
  (if (= len 0)
    nil
    (progn
      (setq idx 1
            ok  T)
      (while (and ok (<= idx len))
        (setq ch (ascii (substr clean idx 1)))
        (if (or (< ch 48) (> ch 57))
          (setq ok nil)
        )
        (setq idx (1+ idx))
      )
      (if ok
        (progn
          (setq val (atoi clean))
          (if (> val 0) val nil)
        )
        nil
      )
    )
  )
)

;; Parse bilangan real positif ketat via distof
(defun asgrid:parse-pos-real (s / clean val)
  (setq clean (asgrid:trim s))
  (if (= (strlen clean) 0)
    nil
    (progn
      (setq val (distof clean 2))
      (if (and val (> val 0.0))
        (float val)
        nil
      )
    )
  )
)

;; Ambil (atau buat bila createIfMissing=T) Named Object Dictionary ASGRID_GROUPS
(defun asgrid:meta-get-root-dict (createIfMissing / nod dictRec newDict)
  (setq nod     (namedobjdict)
        dictRec (dictsearch nod (asgrid:dict-name)))
  (if dictRec
    (cdr (assoc -1 dictRec))
    (if createIfMissing
      (progn
        (setq newDict
          (entmakex
            (list
              (cons 0 "DICTIONARY")
              (cons 100 "AcDbDictionary")
              (cons 280 0)
              (cons 281 1)
            )
          )
        )
        (if newDict
          (progn
            (dictadd nod (asgrid:dict-name) newDict)
            newDict
          )
          nil
        )
      )
      nil
    )
  )
)

;; Daftar Group ID dari NOD saja (dipakai diagnostik & pengecekan duplikasi)
(defun asgrid:meta-list-nod-ids ( / rootDict ids entData pair)
  (setq ids      '()
        rootDict (asgrid:meta-get-root-dict nil))
  (if rootDict
    (progn
      (setq entData (entget rootDict))
      (foreach pair entData
        (if (= (car pair) 3)
          (if (not (member (cdr pair) ids))
            (setq ids (append ids (list (cdr pair))))
          )
        )
      )
    )
  )
  ids
)

;; Ekstrak field XData ASGRID_OBJ dari satu entitas -> (list gid role axisDir axisIdx endTag schemaVer) atau nil
(defun asgrid:parse-entity-xdata (ename / entData xrec vals gid role dir idx etag sver)
  (if (and ename (entget ename))
    (progn
      (setq entData (entget ename (list (asgrid:xdata-app)))
            xrec    (cadr (assoc -3 entData)))
      (if (and xrec (>= (length (cdr xrec)) 6))
        (progn
          (setq vals (cdr xrec)
                gid  (if (= (car (nth 0 vals)) 1000) (cdr (nth 0 vals)) nil)
                role (if (= (car (nth 1 vals)) 1000) (cdr (nth 1 vals)) nil)
                dir  (if (= (car (nth 2 vals)) 1000) (cdr (nth 2 vals)) nil)
                idx  (if (= (car (nth 3 vals)) 1070) (cdr (nth 3 vals)) nil)
                etag (if (= (car (nth 4 vals)) 1000) (cdr (nth 4 vals)) nil)
                sver (if (= (car (nth 5 vals)) 1000) (cdr (nth 5 vals)) nil))
          (if (and (= (type gid) 'STR) (> (strlen gid) 0)
                   (member role '("LINE" "BUBBLE" "TEXT"))
                   (member dir '("H" "V"))
                   (= (type idx) 'INT) (> idx 0)
                   (member etag '("NONE" "START" "END"))
                   (= (type sver) 'STR) (> (strlen sver) 0))
            (list gid role dir idx etag sver)
            nil
          )
        )
        nil
      )
    )
    nil
  )
)

;; Kumpulkan seluruh Group ID dari NOD + XData objek (anti bentrok lintas sumber)
(defun asgrid:meta-list-all-ids ( / ids ss i ename parsed gid)
  (setq ids (asgrid:meta-list-nod-ids)
        ss  (ssget "_X" (list (list -3 (list (asgrid:xdata-app))))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename  (ssname ss i)
              parsed (asgrid:parse-entity-xdata ename))
        (if parsed
          (progn
            (setq gid (car parsed))
            (if (not (member gid ids))
              (setq ids (append ids (list gid)))
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )
  ids
)

;; Baca Group Metadata dari NOD XRecord ke spec asosiasi
(defun asgrid:meta-read-group (groupId / rootDict rec dList res dH dV curKey pair code val)
  (setq rootDict (asgrid:meta-get-root-dict nil))
  (if (null rootDict)
    nil
    (progn
      (setq rec (dictsearch rootDict groupId))
      (if (null rec)
        nil
        (progn
          (setq dList  (entget (cdr (assoc -1 rec)))
                res    '()
                dH     '()
                dV     '()
                curKey nil)
          (foreach pair dList
            (setq code (car pair)
                  val  (cdr pair))
            (cond
              ((= code 300)
               (setq curKey val))
              ((and curKey (member code '(1 10 40 70 90)))
               (cond
                 ((= curKey "DIST_H_ITEM") (setq dH (append dH (list (float val)))))
                 ((= curKey "DIST_V_ITEM") (setq dV (append dV (list (float val)))))
                 (t (setq res (append res (list (cons curKey val)))))
               )
               (setq curKey nil))
            )
          )
          (setq res (append res (list (cons "DIST_H" dH) (cons "DIST_V" dV))))
          res
        )
      )
    )
  )
)

;; Hitung Expected Entity Counts eksak dari spec:
;; Mengembalikan: (list expLines expBubbles expTexts expTotal)
(defun asgrid:calc-expected-counts (spec / nH nV bPos endsMult expL expB expT)
  (setq nH       (cdr (assoc "NUM_H" spec))
        nV       (cdr (assoc "NUM_V" spec))
        bPos     (cdr (assoc "BUBBLE_POS" spec))
        endsMult (cond
                   ((= bPos "Both Ends") 2)
                   ((or (= bPos "Start") (= bPos "End")) 1)
                   (t 0))
        expL     (+ nH nV)
        expB     (* (+ nH nV) endsMult)
        expT     (* (+ nH nV) endsMult))
  (list expL expB expT (+ expL expB expT))
)

;; Validasi integritas mendalam terhadap sebuah spec metadata
;; Mengembalikan daftar pesan error (nil jika 100% valid)
(defun asgrid:meta-validate-spec (spec / errs reqKeys k v nH nV dH dV bp sc th bd ex bPos)
  (setq errs    '()
        reqKeys '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER"
                  "NUM_H" "NUM_V" "DIST_H" "DIST_V" "BASE_PT_WCS"
                  "ELEVATION" "AXIS_DIR_H" "AXIS_DIR_V"
                  "SCALE_DENOM" "TEXT_H_PRINT" "BUBBLE_DIA_PRINT"
                  "EXT_LEN" "BUBBLE_POS" "TEXT_STYLE" "FONT_FILE"
                  "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT"))

  ;; 1. Cek kelengkapan seluruh key wajib
  (if (not (listp spec))
    (setq errs (list "Struktur metadata bukan list valid."))
    (foreach k reqKeys
      (if (null (assoc k spec))
        (setq errs (append errs (list (strcat "Key metadata hilang: " k))))
      )
    )
  )

  ;; 2. Cek tipe & rentang nilai tiap field
  (if (null errs)
    (progn
      ;; String wajib tidak kosong
      (foreach k '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER"
                   "AXIS_DIR_H" "AXIS_DIR_V" "TEXT_STYLE" "FONT_FILE"
                   "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT")
        (setq v (cdr (assoc k spec)))
        (if (or (not (= (type v) 'STR)) (= (strlen (asgrid:trim v)) 0))
          (setq errs (append errs (list (strcat "Nilai string tidak valid/kosong pada key: " k))))
        )
      )

      ;; Jumlah sumbu horizontal & vertikal
      (setq nH (cdr (assoc "NUM_H" spec))
            nV (cdr (assoc "NUM_V" spec)))
      (if (or (not (= (type nH) 'INT)) (<= nH 0))
        (setq errs (append errs (list "NUM_H harus bilangan bulat > 0.")))
      )
      (if (or (not (= (type nV) 'INT)) (<= nV 0))
        (setq errs (append errs (list "NUM_V harus bilangan bulat > 0.")))
      )

      ;; Daftar spacing horizontal & vertikal
      (setq dH (cdr (assoc "DIST_H" spec))
            dV (cdr (assoc "DIST_V" spec)))
      (if (and (= (type nH) 'INT) (> nH 0))
        (if (or (not (listp dH)) (/= (length dH) (max 0 (1- nH))))
          (setq errs (append errs (list "Jumlah DIST_H tidak sama dengan NUM_H - 1.")))
          (foreach v dH
            (if (or (not (numberp v)) (<= v 0.0))
              (setq errs (append errs (list "Terdapat nilai DIST_H non-numerik atau <= 0.")))
            )
          )
        )
      )
      (if (and (= (type nV) 'INT) (> nV 0))
        (if (or (not (listp dV)) (/= (length dV) (max 0 (1- nV))))
          (setq errs (append errs (list "Jumlah DIST_V tidak sama dengan NUM_V - 1.")))
          (foreach v dV
            (if (or (not (numberp v)) (<= v 0.0))
              (setq errs (append errs (list "Terdapat nilai DIST_V non-numerik atau <= 0.")))
            )
          )
        )
      )

      ;; Base point WCS (harus 3 angka valid)
      (setq bp (cdr (assoc "BASE_PT_WCS" spec)))
      (if (or (not (listp bp))
              (/= (length bp) 3)
              (not (numberp (nth 0 bp)))
              (not (numberp (nth 1 bp)))
              (not (numberp (nth 2 bp))))
        (setq errs (append errs (list "BASE_PT_WCS harus berupa titik 3D numerik (X Y Z).")))
      )

      ;; Parameter skala & anotasi positif
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
      (if (not (member bPos (asgrid:valid-bubble-positions)))
        (setq errs (append errs (list "BUBBLE_POS tidak sesuai pilihan valid (Both Ends/Start/End).")))
      )
    )
  )
  errs
)

;; Bandingkan dua spec (expected vs readBack) secara mendalam dengan toleransi 1e-6
;; Mengembalikan daftar perbedaan (nil jika identik 100%)
(defun asgrid:meta-compare-specs (specA specB / diffs strKeys intKeys realKeys k vA vB dA dB i)
  (setq diffs    '()
        strKeys  '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER" "CREATED_AT"
                   "AXIS_DIR_H" "AXIS_DIR_V" "BUBBLE_POS" "TEXT_STYLE" "FONT_FILE"
                   "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT")
        intKeys  '("NUM_H" "NUM_V")
        realKeys '("ELEVATION" "SCALE_DENOM" "TEXT_H_PRINT" "BUBBLE_DIA_PRINT" "EXT_LEN"))

  (foreach k strKeys
    (setq vA (cdr (assoc k specA))
          vB (cdr (assoc k specB)))
    (if (not (equal vA vB))
      (setq diffs (append diffs (list (strcat "Mismatch string key " k))))
    )
  )
  (foreach k intKeys
    (setq vA (cdr (assoc k specA))
          vB (cdr (assoc k specB)))
    (if (not (equal vA vB))
      (setq diffs (append diffs (list (strcat "Mismatch integer key " k))))
    )
  )
  (foreach k realKeys
    (setq vA (cdr (assoc k specA))
          vB (cdr (assoc k specB)))
    (if (or (not (numberp vA)) (not (numberp vB)) (not (equal vA vB 1e-6)))
      (setq diffs (append diffs (list (strcat "Mismatch real key " k))))
    )
  )
  ;; Bandingkan BASE_PT_WCS
  (if (not (equal (cdr (assoc "BASE_PT_WCS" specA))
                  (cdr (assoc "BASE_PT_WCS" specB))
                  1e-6))
    (setq diffs (append diffs (list "Mismatch point key BASE_PT_WCS")))
  )
  ;; Bandingkan list DIST_H
  (setq dA (cdr (assoc "DIST_H" specA))
        dB (cdr (assoc "DIST_H" specB)))
  (if (/= (length dA) (length dB))
    (setq diffs (append diffs (list "Mismatch panjang DIST_H")))
    (progn
      (setq i 0)
      (while (< i (length dA))
        (if (not (equal (nth i dA) (nth i dB) 1e-6))
          (setq diffs (append diffs (list (strcat "Mismatch DIST_H indeks " (itoa i)))))
        )
        (setq i (1+ i))
      )
    )
  )
  ;; Bandingkan list DIST_V
  (setq dA (cdr (assoc "DIST_V" specA))
        dB (cdr (assoc "DIST_V" specB)))
  (if (/= (length dA) (length dB))
    (setq diffs (append diffs (list "Mismatch panjang DIST_V")))
    (progn
      (setq i 0)
      (while (< i (length dA))
        (if (not (equal (nth i dA) (nth i dB) 1e-6))
          (setq diffs (append diffs (list (strcat "Mismatch DIST_V indeks " (itoa i)))))
        )
        (setq i (1+ i))
      )
    )
  )
  diffs
)


;;; ============================================================================
;;; PERINTAH UTAMA: ASGRID (V2.1.1 - HARDENED GENERATOR)
;;; ============================================================================

(defun c:ASGRID ( /
                  ;; Error handler & state transaksi
                  *error* oldCmdEcho undoOpen dclId
                  txActive txSavedGroupId txSavedXrec txCreatedEnts txAbortedByCode
                  ;; Konstanta konfigurasi & metadata
                  PAGE_SIZE STYLE_NAME FONT_FILE BUB_POS_LIST
                  APP_NAME APP_VER SCHEMA_VER
                  DICT_NAME XDATA_APP
                  LAY_GRID LAY_BUBBLE LAY_TEXT
                  ;; Modul 2: Utilitas & Penomoran (V1.0/V2.0/V2.1)
                  fn-index-to-alpha
                  fn-replace-nth
                  fn-resize-str-list
                  fn-pad-4
                  fn-get-timestamp
                  ;; Modul 3: Layer, Linetype & Text Style Arial (V2.0)
                  fn-ensure-linetype-center
                  fn-ensure-layer
                  fn-find-arial-ttf
                  fn-ensure-arial-style
                  ;; Modul 4: Metadata Hard Gate & Transaction Rollback (V2.1.1)
                  fn-make-obj-xdata
                  fn-meta-generate-next-id
                  fn-meta-build-spec
                  fn-meta-save-group
                  fn-rollback-transaction
                  fn-verify-tx-entities
                  ;; Modul 5: Primitif Entitas WCS via entmakex + pelacakan transaksi
                  fn-draw-line
                  fn-draw-circle
                  fn-draw-text-mc
                  ;; Modul 6: Geometry Engine, Annotation Engine & Koordinator Transaksi
                  fn-compute-cumulative
                  fn-geometry-engine
                  fn-annotation-engine
                  fn-execute-grid-creation
                  ;; Modul 7: Live Preview Engine (V2.1 - Utuh)
                  fn-prev-draw-circle
                  fn-prev-draw-char
                  fn-prev-draw-string
                  fn-update-live-preview
                  ;; Modul 8: Manajemen Antarmuka DCL & Pagination (V2.0/V2.1 - Utuh)
                  fn-refresh-h-table
                  fn-refresh-v-table
                  fn-update-scale-preview
                  fn-sync-grid-counts
                  fn-save-h-slot
                  fn-save-v-slot
                  fn-flush-active-page
                  ;; Modul 9: Validasi Input Terpusat (V2.0/V2.1 - Utuh)
                  fn-validate-all
                  ;; State dialog DCL
                  dclFile dclRes
                  curNumH curNumV
                  strListH strListV
                  pageH pageV
                  arialPath nextGroupIdPreview
                  ;; Variabel hasil validasi
                  numH numV
                  distListH distListV
                  scaleDenom textHPrint bubbleDiaPrint extLen bubblePos
                  ;; Titik awal WCS
                  basePtUcs basePt
                )

  ;; Konstanta konfigurasi
  (setq PAGE_SIZE       8
        STYLE_NAME      "ASGRID-ARIAL"
        FONT_FILE       "arial.ttf"
        BUB_POS_LIST    (asgrid:valid-bubble-positions)
        APP_NAME        "ASGRID"
        APP_VER         "2.1.1"
        SCHEMA_VER      "1.0"
        DICT_NAME       (asgrid:dict-name)
        XDATA_APP       (asgrid:xdata-app)
        LAY_GRID        "AS-GRID"
        LAY_BUBBLE      "AS-BUBBLE"
        LAY_TEXT        "AS-TEXT"
        oldCmdEcho      (getvar "CMDECHO")
        undoOpen        nil
        dclId           nil
        txActive        nil
        txSavedGroupId  nil
        txSavedXrec     nil
        txCreatedEnts   '()
        txAbortedByCode nil)

  ;; ==========================================================================
  ;; MODUL 1: ERROR HANDLER LOKAL DENGAN TRANSACTION ROLLBACK TERISOLASI
  ;; ==========================================================================
  (defun *error* (msg / isUserCancel)
    ;; 1. Tutup dialog DCL bila masih terbuka
    (if (and dclId (>= dclId 0))
      (progn
        (unload_dialog dclId)
        (setq dclId nil)
      )
    )

    ;; 2. Jika transaksi pembuatan grid sedang aktif, lakukan rollback aman
    (if txActive
      (fn-rollback-transaction "Error/Interupsi saat transaksi aktif")
    )

    ;; 3. Tutup UNDO Group jika masih terbuka
    (if undoOpen
      (progn
        (setvar "CMDECHO" 0)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
      )
    )

    ;; 4. Pulihkan system variable CMDECHO
    (if oldCmdEcho
      (setvar "CMDECHO" oldCmdEcho)
    )

    ;; 5. Bedakan pembatalan pengguna vs error program vs abort terkendali
    (setq isUserCancel (member msg '("Function cancelled"
                                     "quit / exit abort"
                                     "console break")))
    (cond
      (txAbortedByCode
       (princ "\n[ASGRID V2.1.1] Proses dihentikan secara aman dengan rollback penuh."))
      ((and msg (not isUserCancel))
       (princ (strcat "\n[ASGRID V2.1.1 PROGRAM ERROR] " msg
                      "\n  Seluruh perubahan transaksi telah di-rollback. Grup lain tidak terpengaruh.")))
      (t
       (princ "\n[ASGRID V2.1.1] Proses dibatalkan oleh pengguna. Tidak ada entitas/metadata parsial."))
    )
    (princ)
  )

  ;; ==========================================================================
  ;; MODUL 2: UTILITAS & PENOMORAN HURUF (V1.0 / V2.0 / V2.1)
  ;; ==========================================================================

  (defun fn-index-to-alpha (idx / n remVal res)
    (setq n idx
          res "")
    (while (> n 0)
      (setq n      (1- n)
            remVal (rem n 26)
            res    (strcat (chr (+ 65 remVal)) res)
            n      (/ n 26))
    )
    res
  )

  (defun fn-replace-nth (idx newVal lst / i res)
    (setq i   0
          res '())
    (foreach item lst
      (if (= i idx)
        (setq res (append res (list newVal)))
        (setq res (append res (list item)))
      )
      (setq i (1+ i))
    )
    res
  )

  (defun fn-resize-str-list (lst targetLen defStr / res i)
    (setq res '()
          i   0)
    (while (< i targetLen)
      (if (< i (length lst))
        (setq res (append res (list (nth i lst))))
        (setq res (append res (list defStr)))
      )
      (setq i (1+ i))
    )
    res
  )

  (defun fn-pad-4 (n / s)
    (setq s (itoa n))
    (while (< (strlen s) 4)
      (setq s (strcat "0" s))
    )
    s
  )

  (defun fn-get-timestamp ( / s)
    (setq s (rtos (getvar "CDATE") 2 6))
    (if (>= (strlen s) 15)
      (strcat (substr s 1 4) "-" (substr s 5 2) "-" (substr s 7 2) " "
              (substr s 10 2) ":" (substr s 12 2) ":" (substr s 14 2))
      s
    )
  )

  ;; ==========================================================================
  ;; MODUL 3: LINETYPE, LAYER (V1.0), DAN TEXT STYLE KHUSUS ARIAL (V2.0)
  ;; ==========================================================================

  (defun fn-ensure-linetype-center ( / linFile)
    (if (not (tblsearch "LTYPE" "CENTER"))
      (progn
        (setq linFile (cond
                        ((findfile "acadiso.lin"))
                        ((findfile "acad.lin"))
                        (t nil)
                      ))
        (if linFile
          (command "_.-LINETYPE" "_Load" "CENTER" linFile "")
        )
        (if (not (tblsearch "LTYPE" "CENTER"))
          (entmake
            (list
              (cons 0 "LTYPE")
              (cons 100 "AcDbSymbolTableRecord")
              (cons 100 "AcDbLinetypeTableRecord")
              (cons 2 "CENTER")
              (cons 70 0)
              (cons 3 "Center ____ _ ____ _ ____ _ ____ _ ____ _ ____")
              (cons 72 65)
              (cons 73 4)
              (cons 40 50.8)
              (cons 49 31.75) (cons 74 0)
              (cons 49 -6.35) (cons 74 0)
              (cons 49 6.35)  (cons 74 0)
              (cons 49 -6.35) (cons 74 0)
            )
          )
        )
      )
    )
    (not (null (tblsearch "LTYPE" "CENTER")))
  )

  (defun fn-ensure-layer (layName ltypeName colorIdx / useLtype)
    (if (not (tblsearch "LAYER" layName))
      (progn
        (setq useLtype (if (tblsearch "LTYPE" ltypeName) ltypeName "CONTINUOUS"))
        (entmake
          (list
            (cons 0 "LAYER")
            (cons 100 "AcDbSymbolTableRecord")
            (cons 100 "AcDbLayerTableRecord")
            (cons 2 layName)
            (cons 70 0)
            (cons 62 colorIdx)
            (cons 6 useLtype)
          )
        )
      )
    )
  )

  (defun fn-find-arial-ttf ( / p winDir sysRoot)
    (setq p (findfile FONT_FILE))
    (if (null p)
      (progn
        (setq winDir (getenv "WINDIR"))
        (if winDir
          (setq p (findfile (strcat winDir "\\Fonts\\" FONT_FILE)))
        )
      )
    )
    (if (null p)
      (progn
        (setq sysRoot (getenv "SystemRoot"))
        (if sysRoot
          (setq p (findfile (strcat sysRoot "\\Fonts\\" FONT_FILE)))
        )
      )
    )
    (if (null p)
      (setq p (findfile (strcat "C:\\Windows\\Fonts\\" FONT_FILE)))
    )
    p
  )

  (defun fn-ensure-arial-style ( / tblRec existingFont ok)
    (setq ok nil)
    (if (null (fn-find-arial-ttf))
      (progn
        (alert
          (strcat
            "PERINGATAN: File font '" FONT_FILE "' (Arial) tidak ditemukan pada sistem.\n\n"
            "ASGRID V2.1.1 tidak akan mengganti font secara diam-diam.\n"
            "Pastikan font Arial terpasang di Windows Fonts atau Support File Search Path AutoCAD."
          )
        )
        (princ (strcat "\n[ASGRID V2.1.1 ERROR] Font '" FONT_FILE "' tidak ditemukan. Proses dihentikan."))
        nil
      )
      (progn
        (setq tblRec (tblsearch "STYLE" STYLE_NAME))
        (if tblRec
          (progn
            (setq existingFont (strcase (cdr (assoc 3 tblRec))))
            (if (= existingFont (strcase FONT_FILE))
              (setq ok T)
              (progn
                (alert
                  (strcat
                    "PERINGATAN: Text Style '" STYLE_NAME "' sudah ada tetapi tidak menggunakan '" FONT_FILE "' "
                    "(font saat ini: " existingFont ").\n\n"
                    "Untuk menjaga objek lain dalam gambar, ASGRID tidak menimpa style tersebut.\n"
                    "Ubah font style '" STYLE_NAME "' ke Arial (arial.ttf) secara manual lalu jalankan ulang ASGRID."
                  )
                )
                (princ (strcat "\n[ASGRID V2.1.1 ERROR] Style '" STYLE_NAME "' memakai font lain (" existingFont ")."))
                (setq ok nil)
              )
            )
          )
          (progn
            (regapp "ACAD")
            (setq ok
              (not (null
                (entmake
                  (list
                    (cons 0 "STYLE")
                    (cons 100 "AcDbSymbolTableRecord")
                    (cons 100 "AcDbTextStyleTableRecord")
                    (cons 2 STYLE_NAME)
                    (cons 70 0)
                    (cons 40 0.0)
                    (cons 41 1.0)
                    (cons 50 0.0)
                    (cons 71 0)
                    (cons 42 2.5)
                    (cons 3 FONT_FILE)
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
            (if (not ok)
              (progn
                (alert (strcat "Gagal membuat Text Style '" STYLE_NAME "' dengan font '" FONT_FILE "'."))
                (princ (strcat "\n[ASGRID V2.1.1 ERROR] Gagal membuat Text Style '" STYLE_NAME "'."))
              )
            )
          )
        )
        ok
      )
    )
  )

  ;; ==========================================================================
  ;; MODUL 4: METADATA HARD GATE & ISOLATED TRANSACTION ROLLBACK (V2.1.1)
  ;; ==========================================================================

  (defun fn-make-obj-xdata (groupId role axisDir axisIdx endTag)
    (list -3
      (list XDATA_APP
        (cons 1000 groupId)
        (cons 1000 role)
        (cons 1000 axisDir)
        (cons 1070 axisIdx)
        (cons 1000 endTag)
        (cons 1000 SCHEMA_VER)
      )
    )
  )

  ;; Hasilkan Group ID unik berikutnya (memindai NOD + XData seluruh DWG)
  (defun fn-meta-generate-next-id ( / existingIds maxNum gid numPart)
    (setq existingIds (asgrid:meta-list-all-ids)
          maxNum      0)
    (foreach gid existingIds
      (if (and (>= (strlen gid) 5)
               (= (strcase (substr gid 1 4)) "ASG-"))
        (progn
          (setq numPart (asgrid:parse-pos-int (substr gid 5)))
          (if (and numPart (> numPart maxNum))
            (setq maxNum numPart)
          )
        )
      )
    )
    (strcat "ASG-" (fn-pad-4 (1+ maxNum)))
  )

  ;; Bangun struktur spec terpadu (single source of truth)
  (defun fn-meta-build-spec (groupId ptWcs)
    (list
      (cons "SCHEMA_VER"       SCHEMA_VER)
      (cons "GROUP_ID"         groupId)
      (cons "MODULE"           APP_NAME)
      (cons "GENERATOR_VER"    APP_VER)
      (cons "CREATED_AT"       (fn-get-timestamp))
      (cons "NUM_H"            numH)
      (cons "NUM_V"            numV)
      (cons "DIST_H"           distListH)
      (cons "DIST_V"           distListV)
      (cons "BASE_PT_WCS"      (list (float (car ptWcs))
                                     (float (cadr ptWcs))
                                     (if (caddr ptWcs) (float (caddr ptWcs)) 0.0)))
      (cons "ELEVATION"        (if (caddr ptWcs) (float (caddr ptWcs)) 0.0))
      (cons "AXIS_DIR_H"       "X")
      (cons "AXIS_DIR_V"       "Y")
      (cons "SCALE_DENOM"      scaleDenom)
      (cons "TEXT_H_PRINT"     textHPrint)
      (cons "BUBBLE_DIA_PRINT" bubbleDiaPrint)
      (cons "EXT_LEN"          extLen)
      (cons "BUBBLE_POS"       bubblePos)
      (cons "TEXT_STYLE"       STYLE_NAME)
      (cons "FONT_FILE"        FONT_FILE)
      (cons "LAYER_GRID"       LAY_GRID)
      (cons "LAYER_BUBBLE"     LAY_BUBBLE)
      (cons "LAYER_TEXT"       LAY_TEXT)
    )
  )

  ;; Simpan Group Metadata ke NOD XRecord (menolak Group ID duplikat)
  (defun fn-meta-save-group (spec / rootDict groupId xrecData xrecEname dVal)
    (setq groupId  (cdr (assoc "GROUP_ID" spec))
          rootDict (asgrid:meta-get-root-dict T))
    (cond
      ((null rootDict)
       (princ "\n[ASGRID V2.1.1 ERROR] Gagal membuat/mengakses Named Object Dictionary ASGRID_GROUPS.")
       nil)
      ((or (dictsearch rootDict groupId)
           (member groupId (asgrid:meta-list-all-ids)))
       (princ (strcat "\n[ASGRID V2.1.1 ERROR] Group ID '" groupId "' sudah terpakai; duplikasi dicegah."))
       nil)
      (t
       (setq xrecData
         (list
           (cons 0 "XRECORD")
           (cons 100 "AcDbXrecord")
           (cons 280 1)
           ;; Identitas
           (cons 300 "SCHEMA_VER")       (cons 1  (cdr (assoc "SCHEMA_VER" spec)))
           (cons 300 "GROUP_ID")         (cons 1  groupId)
           (cons 300 "MODULE")           (cons 1  (cdr (assoc "MODULE" spec)))
           (cons 300 "GENERATOR_VER")    (cons 1  (cdr (assoc "GENERATOR_VER" spec)))
           (cons 300 "CREATED_AT")       (cons 1  (cdr (assoc "CREATED_AT" spec)))
           ;; Geometri
           (cons 300 "NUM_H")            (cons 90 (cdr (assoc "NUM_H" spec)))
           (cons 300 "NUM_V")            (cons 90 (cdr (assoc "NUM_V" spec)))
           (cons 300 "BASE_PT_WCS")      (cons 10 (cdr (assoc "BASE_PT_WCS" spec)))
           (cons 300 "ELEVATION")        (cons 40 (cdr (assoc "ELEVATION" spec)))
           (cons 300 "AXIS_DIR_H")       (cons 1  (cdr (assoc "AXIS_DIR_H" spec)))
           (cons 300 "AXIS_DIR_V")       (cons 1  (cdr (assoc "AXIS_DIR_V" spec)))
           (cons 300 "DIST_H_COUNT")     (cons 90 (length (cdr (assoc "DIST_H" spec))))
         )
       )
       (foreach dVal (cdr (assoc "DIST_H" spec))
         (setq xrecData (append xrecData (list (cons 300 "DIST_H_ITEM") (cons 40 (float dVal)))))
       )
       (setq xrecData
         (append xrecData
           (list (cons 300 "DIST_V_COUNT") (cons 90 (length (cdr (assoc "DIST_V" spec)))))
         )
       )
       (foreach dVal (cdr (assoc "DIST_V" spec))
         (setq xrecData (append xrecData (list (cons 300 "DIST_V_ITEM") (cons 40 (float dVal)))))
       )
       ;; Anotasi & Layer
       (setq xrecData
         (append xrecData
           (list
             (cons 300 "SCALE_DENOM")      (cons 40 (cdr (assoc "SCALE_DENOM" spec)))
             (cons 300 "TEXT_H_PRINT")     (cons 40 (cdr (assoc "TEXT_H_PRINT" spec)))
             (cons 300 "BUBBLE_DIA_PRINT") (cons 40 (cdr (assoc "BUBBLE_DIA_PRINT" spec)))
             (cons 300 "EXT_LEN")          (cons 40 (cdr (assoc "EXT_LEN" spec)))
             (cons 300 "BUBBLE_POS")       (cons 1  (cdr (assoc "BUBBLE_POS" spec)))
             (cons 300 "TEXT_STYLE")       (cons 1  (cdr (assoc "TEXT_STYLE" spec)))
             (cons 300 "FONT_FILE")        (cons 1  (cdr (assoc "FONT_FILE" spec)))
             (cons 300 "LAYER_GRID")       (cons 1  (cdr (assoc "LAYER_GRID" spec)))
             (cons 300 "LAYER_BUBBLE")     (cons 1  (cdr (assoc "LAYER_BUBBLE" spec)))
             (cons 300 "LAYER_TEXT")       (cons 1  (cdr (assoc "LAYER_TEXT" spec)))
           )
         )
       )
       (setq xrecEname (entmakex xrecData))
       (if xrecEname
         (if (dictadd rootDict groupId xrecEname)
           xrecEname
           (progn
             ;; Hapus XRecord yang gagal ditambahkan ke dictionary agar tidak yatim
             (entdel xrecEname)
             nil
           )
         )
         nil
       ))
    )
  )

  ;; Rollback transaksi secara terisolasi:
  ;; Hanya menghapus ename di txCreatedEnts dan XRecord txSavedGroupId milik
  ;; transaksi aktif ini. Grup lain dan entitas lain di DWG 100% aman.
  (defun fn-rollback-transaction (reason / e rootDict delCnt)
    (setq delCnt 0)
    ;; 1. Hapus entitas parsial yang dibuat oleh transaksi ini saja
    (foreach e txCreatedEnts
      (if (and e (entget e))
        (progn
          (entdel e)
          (setq delCnt (1+ delCnt))
        )
      )
    )
    (setq txCreatedEnts '())

    ;; 2. Hapus XRecord metadata milik transaksi ini saja dari NOD
    (if txSavedGroupId
      (progn
        (setq rootDict (asgrid:meta-get-root-dict nil))
        (if (and rootDict (dictsearch rootDict txSavedGroupId))
          (dictremove rootDict txSavedGroupId)
        )
        (if (and txSavedXrec (entget txSavedXrec))
          (entdel txSavedXrec)
        )
        (princ (strcat "\n[ASGRID V2.1.1 ROLLBACK] Metadata '" txSavedGroupId
                       "' dihapus dan " (itoa delCnt) " entitas parsial dibersihkan (" reason ")."))
      )
      (if (> delCnt 0)
        (princ (strcat "\n[ASGRID V2.1.1 ROLLBACK] " (itoa delCnt)
                       " entitas parsial dibersihkan (" reason ")."))
      )
    )
    (setq txSavedGroupId nil
          txSavedXrec    nil
          txActive       nil)
  )

  ;; Verifikasi XData pada seluruh entitas yang baru dibuat dalam transaksi
  ;; Mengembalikan list (list okFlag validL validB validT errMsg)
  (defun fn-verify-tx-entities (expectedGroupId / e parsed vL vB vT badMsg)
    (setq vL     0
          vB     0
          vT     0
          badMsg nil)
    (foreach e txCreatedEnts
      (if (null badMsg)
        (progn
          (setq parsed (asgrid:parse-entity-xdata e))
          (cond
            ((null parsed)
             (setq badMsg "Entitas kehilangan atau memiliki XData ASGRID_OBJ tidak valid."))
            ((/= (car parsed) expectedGroupId)
             (setq badMsg (strcat "Mismatch Group ID pada XData entitas (terbaca: "
                                  (car parsed) ", seharusnya: " expectedGroupId ").")))
            ((= (cadr parsed) "LINE")   (setq vL (1+ vL)))
            ((= (cadr parsed) "BUBBLE") (setq vB (1+ vB)))
            ((= (cadr parsed) "TEXT")   (setq vT (1+ vT)))
            (t
             (setq badMsg "Role XData entitas tidak dikenali."))
          )
        )
      )
    )
    (list (null badMsg) vL vB vT badMsg)
  )

  ;; ==========================================================================
  ;; MODUL 5: PRIMITIF ENTITAS WCS VIA ENTMAKEX (MELACAK ENAME TRANSAKSI)
  ;; ==========================================================================
  (defun fn-draw-line (p1 p2 layName xdata / e)
    (setq e
      (entmakex
        (list
          (cons 0 "LINE")
          (cons 100 "AcDbEntity")
          (cons 8 layName)
          (cons 100 "AcDbLine")
          (cons 10 p1)
          (cons 11 p2)
          xdata
        )
      )
    )
    (if e (setq txCreatedEnts (cons e txCreatedEnts)))
    e
  )

  (defun fn-draw-circle (cpt rad layName xdata / e)
    (setq e
      (entmakex
        (list
          (cons 0 "CIRCLE")
          (cons 100 "AcDbEntity")
          (cons 8 layName)
          (cons 100 "AcDbCircle")
          (cons 10 cpt)
          (cons 40 rad)
          xdata
        )
      )
    )
    (if e (setq txCreatedEnts (cons e txCreatedEnts)))
    e
  )

  (defun fn-draw-text-mc (cpt txtH txtStr layName styleName xdata / e)
    (setq e
      (entmakex
        (list
          (cons 0 "TEXT")
          (cons 100 "AcDbEntity")
          (cons 8 layName)
          (cons 100 "AcDbText")
          (cons 10 cpt)
          (cons 40 txtH)
          (cons 1 txtStr)
          (cons 50 0.0)
          (cons 7 styleName)
          (cons 72 1)
          (cons 11 cpt)
          (cons 100 "AcDbText")
          (cons 73 2)
          xdata
        )
      )
    )
    (if e (setq txCreatedEnts (cons e txCreatedEnts)))
    e
  )

  ;; ==========================================================================
  ;; MODUL 6: GEOMETRY ENGINE, ANNOTATION ENGINE & TRANSACTION COORDINATOR
  ;; ==========================================================================

  (defun fn-compute-cumulative (startCoord distList / acc res val)
    (setq acc (float startCoord)
          res (list acc))
    (foreach val distList
      (setq acc (+ acc (float val))
            res (append res (list acc)))
    )
    res
  )

  ;; GEOMETRY ENGINE: Hanya membuat garis sumbu grid (LINE)
  (defun fn-geometry-engine (spec /
                              groupId basePt x0 y0 z0
                              dH dV ext layGrid
                              cumY cumX totalY totalX
                              i curY curX pStart pEnd cntLine
                            )
    (setq groupId (cdr (assoc "GROUP_ID" spec))
          basePt  (cdr (assoc "BASE_PT_WCS" spec))
          x0      (car basePt)
          y0      (cadr basePt)
          z0      (caddr basePt)
          dH      (cdr (assoc "DIST_H" spec))
          dV      (cdr (assoc "DIST_V" spec))
          ext     (cdr (assoc "EXT_LEN" spec))
          layGrid (cdr (assoc "LAYER_GRID" spec))
          cumY    (fn-compute-cumulative y0 dH)
          cumX    (fn-compute-cumulative x0 dV)
          totalY  (- (last cumY) y0)
          totalX  (- (last cumX) x0)
          cntLine 0)

    ;; Garis as horizontal (sejajar sumbu X)
    (setq i 1)
    (foreach curY cumY
      (setq pStart (list (- x0 ext) curY z0)
            pEnd   (list (+ x0 totalX ext) curY z0))
      (if (fn-draw-line pStart pEnd layGrid
                        (fn-make-obj-xdata groupId "LINE" "H" i "NONE"))
        (setq cntLine (1+ cntLine))
      )
      (setq i (1+ i))
    )

    ;; Garis as vertikal (sejajar sumbu Y)
    (setq i 1)
    (foreach curX cumX
      (setq pStart (list curX (- y0 ext) z0)
            pEnd   (list curX (+ y0 totalY ext) z0))
      (if (fn-draw-line pStart pEnd layGrid
                        (fn-make-obj-xdata groupId "LINE" "V" i "NONE"))
        (setq cntLine (1+ cntLine))
      )
      (setq i (1+ i))
    )

    cntLine
  )

  ;; ANNOTATION ENGINE: Hanya membuat bubble (CIRCLE) & label teks (TEXT)
  (defun fn-annotation-engine (spec /
                                groupId basePt x0 y0 z0
                                dH dV ext sc thP bdP bPos
                                txtStyle layBub layTxt
                                textHModel bubRadModel
                                drawStart drawEnd
                                cumY cumX totalY totalX
                                i curY curX lbl c1 c2
                                cntBubble cntText
                              )
    (setq groupId     (cdr (assoc "GROUP_ID" spec))
          basePt      (cdr (assoc "BASE_PT_WCS" spec))
          x0          (car basePt)
          y0          (cadr basePt)
          z0          (caddr basePt)
          dH          (cdr (assoc "DIST_H" spec))
          dV          (cdr (assoc "DIST_V" spec))
          ext         (cdr (assoc "EXT_LEN" spec))
          sc          (cdr (assoc "SCALE_DENOM" spec))
          thP         (cdr (assoc "TEXT_H_PRINT" spec))
          bdP         (cdr (assoc "BUBBLE_DIA_PRINT" spec))
          bPos        (cdr (assoc "BUBBLE_POS" spec))
          txtStyle    (cdr (assoc "TEXT_STYLE" spec))
          layBub      (cdr (assoc "LAYER_BUBBLE" spec))
          layTxt      (cdr (assoc "LAYER_TEXT" spec))
          textHModel  (* thP sc)
          bubRadModel (/ (* bdP sc) 2.0)
          drawStart   (or (= bPos "Both Ends") (= bPos "Start"))
          drawEnd     (or (= bPos "Both Ends") (= bPos "End"))
          cumY        (fn-compute-cumulative y0 dH)
          cumX        (fn-compute-cumulative x0 dV)
          totalY      (- (last cumY) y0)
          totalX      (- (last cumX) x0)
          cntBubble   0
          cntText     0)

    ;; Anotasi sumbu horizontal (1, 2, 3, ...)
    (setq i 1)
    (foreach curY cumY
      (setq lbl (itoa i))
      (if drawStart
        (progn
          (setq c1 (list (- x0 ext bubRadModel) curY z0))
          (if (fn-draw-circle c1 bubRadModel layBub
                              (fn-make-obj-xdata groupId "BUBBLE" "H" i "START"))
            (setq cntBubble (1+ cntBubble))
          )
          (if (fn-draw-text-mc c1 textHModel lbl layTxt txtStyle
                               (fn-make-obj-xdata groupId "TEXT" "H" i "START"))
            (setq cntText (1+ cntText))
          )
        )
      )
      (if drawEnd
        (progn
          (setq c2 (list (+ x0 totalX ext bubRadModel) curY z0))
          (if (fn-draw-circle c2 bubRadModel layBub
                              (fn-make-obj-xdata groupId "BUBBLE" "H" i "END"))
            (setq cntBubble (1+ cntBubble))
          )
          (if (fn-draw-text-mc c2 textHModel lbl layTxt txtStyle
                               (fn-make-obj-xdata groupId "TEXT" "H" i "END"))
            (setq cntText (1+ cntText))
          )
        )
      )
      (setq i (1+ i))
    )

    ;; Anotasi sumbu vertikal (A, B, C, ..., AA, AB)
    (setq i 1)
    (foreach curX cumX
      (setq lbl (fn-index-to-alpha i))
      (if drawStart
        (progn
          (setq c1 (list curX (- y0 ext bubRadModel) z0))
          (if (fn-draw-circle c1 bubRadModel layBub
                              (fn-make-obj-xdata groupId "BUBBLE" "V" i "START"))
            (setq cntBubble (1+ cntBubble))
          )
          (if (fn-draw-text-mc c1 textHModel lbl layTxt txtStyle
                               (fn-make-obj-xdata groupId "TEXT" "V" i "START"))
            (setq cntText (1+ cntText))
          )
        )
      )
      (if drawEnd
        (progn
          (setq c2 (list curX (+ y0 totalY ext bubRadModel) z0))
          (if (fn-draw-circle c2 bubRadModel layBub
                              (fn-make-obj-xdata groupId "BUBBLE" "V" i "END"))
            (setq cntBubble (1+ cntBubble))
          )
          (if (fn-draw-text-mc c2 textHModel lbl layTxt txtStyle
                               (fn-make-obj-xdata groupId "TEXT" "V" i "END"))
            (setq cntText (1+ cntText))
          )
        )
      )
      (setq i (1+ i))
    )

    (list cntBubble cntText)
  )

  ;; Koordinator Transaksi V2.1.1:
  ;; Pre-checks -> Metadata Write -> Hard Gate Read-Back & Deep Compare ->
  ;; Geometry Engine -> Annotation Engine -> Entity Count & XData Verification ->
  ;; Commit (atau Rollback penuh bila ada satu pun kegagalan).
  (defun fn-execute-grid-creation (ptWcs /
                                    groupId spec metaErrs savedXrec
                                    readBack readErrs cmpDiffs
                                    expCounts expL expB expT expTotal
                                    cntLine annRes cntBubble cntText
                                    verRes verOk vL vB vT verErr
                                    cumY cumX totalY totalX x0 y0 z0
                                    textHModel bubDiaModel abortMsg
                                  )
    (princ "\n[ASGRID V2.1.1] Memulai transaksi pembuatan grid & verifikasi metadata...")
    (setvar "CMDECHO" 0)
    (command "_.UNDO" "_Begin")
    (setq undoOpen        T
          txActive        T
          txSavedGroupId  nil
          txSavedXrec     nil
          txCreatedEnts   '()
          txAbortedByCode nil)

    ;; 1. Pre-check: Text Style Arial wajib tersedia
    (if (not (fn-ensure-arial-style))
      (progn
        (setq txActive nil txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (exit)
      )
    )

    ;; 2. Pre-check: Daftarkan RegApp XData untuk Object Identity
    (if (null (regapp XDATA_APP))
      (progn
        (setq txActive nil txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Gagal mendaftarkan XData Application '" XDATA_APP "'. Proses dibatalkan."))
        (exit)
      )
    )

    ;; 3. Pre-check: Pastikan linetype & layer tersedia
    (if (not (fn-ensure-linetype-center))
      (princ "\n  [Peringatan] Linetype CENTER gagal dimuat; layer AS-GRID akan memakai CONTINUOUS.")
    )
    (fn-ensure-layer LAY_GRID   "CENTER"     8)
    (fn-ensure-layer LAY_BUBBLE "CONTINUOUS" 2)
    (fn-ensure-layer LAY_TEXT   "CONTINUOUS" 7)

    ;; 4. Bangun Group ID unik & validasi integritas spec sebelum menulis
    (setq groupId  (fn-meta-generate-next-id)
          spec     (fn-meta-build-spec groupId ptWcs)
          metaErrs (asgrid:meta-validate-spec spec))

    (if metaErrs
      (progn
        (fn-rollback-transaction "Spec metadata pra-tulis tidak valid")
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Validasi metadata gagal sebelum penulisan:\n" (car metaErrs)))
        (exit)
      )
    )

    ;; 5. HARD GATE A: Tulis metadata ke NOD XRecord SEBELUM geometri dimulai
    (setq savedXrec (fn-meta-save-group spec))
    (if (null savedXrec)
      (progn
        (fn-rollback-transaction "Gagal menulis XRecord ke NOD")
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Gagal menyimpan metadata grup '" groupId "' ke DWG. Pembuatan grid dibatalkan."))
        (exit)
      )
    )
    (setq txSavedGroupId groupId
          txSavedXrec    savedXrec)

    ;; 6. HARD GATE B: Baca ulang XRecord, validasi integritas, & deep-compare
    (setq readBack (asgrid:meta-read-group groupId)
          readErrs (if readBack
                     (asgrid:meta-validate-spec readBack)
                     '("XRecord tidak dapat dibaca kembali dari NOD."))
          cmpDiffs (if (and readBack (null readErrs))
                     (asgrid:meta-compare-specs spec readBack)
                     nil))

    (if (or (null readBack) readErrs cmpDiffs)
      (progn
        (setq abortMsg (cond
                         (readErrs (car readErrs))
                         (cmpDiffs (car cmpDiffs))
                         (t "Metadata baca-balik kosong.")))
        (fn-rollback-transaction (strcat "Hard Gate metadata gagal: " abortMsg))
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "HARD GATE GAGAL: Verifikasi metadata '" groupId "' tidak lolos.\n\n"
                       "Detail: " abortMsg "\n\n"
                       "Geometri tidak dibuat dan metadata telah di-rollback."))
        (exit)
      )
    )

    ;; 7. Hitung Expected Entity Counts eksak dari metadata terverifikasi (readBack)
    (setq expCounts (asgrid:calc-expected-counts readBack)
          expL      (nth 0 expCounts)
          expB      (nth 1 expCounts)
          expT      (nth 2 expCounts)
          expTotal  (nth 3 expCounts))

    ;; 8. Jalankan Geometry Engine dari metadata terverifikasi (readBack)
    (setq cntLine (fn-geometry-engine readBack))
    (if (/= cntLine expL)
      (progn
        (fn-rollback-transaction
          (strcat "Geometry Engine count mismatch (" (itoa cntLine) "/" (itoa expL) ")"))
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Gagal membuat seluruh garis grid (" (itoa cntLine) " dari " (itoa expL) ").\n"
                       "Seluruh transaksi telah di-rollback."))
        (exit)
      )
    )

    ;; 9. Jalankan Annotation Engine dari metadata terverifikasi (readBack)
    (setq annRes    (fn-annotation-engine readBack)
          cntBubble (car annRes)
          cntText   (cadr annRes))
    (if (or (/= cntBubble expB) (/= cntText expT))
      (progn
        (fn-rollback-transaction
          (strcat "Annotation Engine count mismatch (Bubble "
                  (itoa cntBubble) "/" (itoa expB) ", Text "
                  (itoa cntText) "/" (itoa expT) ")"))
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Gagal membuat seluruh anotasi grid.\n"
                       "Bubble: " (itoa cntBubble) "/" (itoa expB)
                       " | Text: " (itoa cntText) "/" (itoa expT) "\n"
                       "Seluruh transaksi telah di-rollback."))
        (exit)
      )
    )

    ;; 10. Validasi akhir: Total entitas aktual & verifikasi XData tiap entitas
    (setq verRes (fn-verify-tx-entities groupId)
          verOk  (nth 0 verRes)
          vL     (nth 1 verRes)
          vB     (nth 2 verRes)
          vT     (nth 3 verRes)
          verErr (nth 4 verRes))

    (if (or (not verOk)
            (/= (length txCreatedEnts) expTotal)
            (/= vL expL)
            (/= vB expB)
            (/= vT expT))
      (progn
        (setq abortMsg (if verErr verErr
                         (strcat "Total entitas terverifikasi ("
                                 (itoa (+ vL vB vT)) ") tidak sama dengan ekspektasi ("
                                 (itoa expTotal) ").")))
        (fn-rollback-transaction (strcat "Verifikasi akhir entitas/XData gagal: " abortMsg))
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "VALIDASI ENTITAS/XDATA GAGAL:\n" abortMsg "\n\n"
                       "Seluruh entitas dan metadata transaksi telah di-rollback."))
        (exit)
      )
    )

    ;; 11. COMMIT TRANSAKSI: Bersihkan status transaksi, tutup UNDO & pulihkan CMDECHO
    (setq txActive       nil
          txSavedGroupId nil
          txSavedXrec    nil
          txCreatedEnts  '())
    (command "_.UNDO" "_End")
    (setq undoOpen nil)
    (setvar "CMDECHO" oldCmdEcho)

    ;; 12. Ringkasan hasil terverifikasi di command line
    (setq x0          (car (cdr (assoc "BASE_PT_WCS" readBack)))
          y0          (cadr (cdr (assoc "BASE_PT_WCS" readBack)))
          z0          (caddr (cdr (assoc "BASE_PT_WCS" readBack)))
          cumY        (fn-compute-cumulative y0 (cdr (assoc "DIST_H" readBack)))
          cumX        (fn-compute-cumulative x0 (cdr (assoc "DIST_V" readBack)))
          totalY      (- (last cumY) y0)
          totalX      (- (last cumX) x0)
          textHModel  (* (cdr (assoc "TEXT_H_PRINT" readBack)) (cdr (assoc "SCALE_DENOM" readBack)))
          bubDiaModel (* (cdr (assoc "BUBBLE_DIA_PRINT" readBack)) (cdr (assoc "SCALE_DENOM" readBack))))

    (princ "\n------------------------------------------------------------")
    (princ "\n[ASGRID V2.1.1] SELESAI - TRANSAKSI TERVERIFIKASI PENUH")
    (princ "\n------------------------------------------------------------")
    (princ (strcat "\n  Group ID (DWG Meta)  : " groupId " (NOD: " DICT_NAME " | XData: " XDATA_APP ")"))
    (princ (strcat "\n  Titik awal (WCS)     : (" (rtos x0 2 2) ", " (rtos y0 2 2) ", " (rtos z0 2 2) ") mm"))
    (princ (strcat "\n  Jumlah grid (H x V)  : " (itoa numH) " Horizontal x " (itoa numV) " Vertikal"))
    (princ (strcat "\n  Area grid (X x Y)    : " (rtos totalX 2 2) " mm x " (rtos totalY 2 2) " mm"))
    (princ (strcat "\n  Skala cetak          : 1:" (rtos scaleDenom 2 2)))
    (princ (strcat "\n  Tinggi teks model    : " (rtos textHModel 2 2) " mm (cetak " (rtos textHPrint 2 2) " mm)"))
    (princ (strcat "\n  Diameter bubble model: " (rtos bubDiaModel 2 2) " mm (cetak " (rtos bubbleDiaPrint 2 2) " mm)"))
    (princ (strcat "\n  Perpanjangan garis   : " (rtos extLen 2 2) " mm"))
    (princ (strcat "\n  Posisi bubble        : " bubblePos))
    (princ (strcat "\n  Text Style / Font    : " STYLE_NAME " (" FONT_FILE ")"))
    (princ (strcat "\n  Validasi Entitas     : Lines " (itoa vL) "/" (itoa expL)
                                              " | Bubbles " (itoa vB) "/" (itoa expB)
                                              " | Texts " (itoa vT) "/" (itoa expT)
                                              " (Total " (itoa expTotal) "/" (itoa expTotal) " OK)"))
    (princ "\n  Hard Gate Metadata   : LOLOS (Tulis -> Baca Balik -> Deep Compare OK)")
    (princ "\n  XData Identity       : TERVERIFIKASI PADA SELURUH ENTITAS")
    (princ "\n------------------------------------------------------------")
  )

  ;; ==========================================================================
  ;; MODUL 7: LIVE PREVIEW ENGINE (DCL IMAGE TILE - UTUH DARI V2.1)
  ;; ==========================================================================

  (defun fn-prev-draw-circle (cx cy rad col / segs k a1 a2 x1 y1 x2 y2 step)
    (setq segs 12
          step (/ (* 2.0 pi) segs)
          k    0)
    (while (< k segs)
      (setq a1 (* k step)
            a2 (* (1+ k) step)
            x1 (fix (+ cx (* rad (cos a1)) 0.5))
            y1 (fix (+ cy (* rad (sin a1)) 0.5))
            x2 (fix (+ cx (* rad (cos a2)) 0.5))
            y2 (fix (+ cy (* rad (sin a2)) 0.5)))
      (vector_image x1 y1 x2 y2 col)
      (setq k (1+ k))
    )
  )

  (defun fn-prev-draw-char (ch x0 y0 sx sy col / segs seg)
    (setq segs
      (cdr (assoc (strcase ch)
        '(("0" . ((0 0 4 0) (4 0 4 6) (4 6 0 6) (0 6 0 0)))
          ("1" . ((2 0 2 6) (1 1 2 0) (1 6 3 6)))
          ("2" . ((0 0 4 0) (4 0 4 3) (4 3 0 3) (0 3 0 6) (0 6 4 6)))
          ("3" . ((0 0 4 0) (4 0 4 6) (0 3 4 3) (0 6 4 6)))
          ("4" . ((0 0 0 3) (0 3 4 3) (4 0 4 6)))
          ("5" . ((4 0 0 0) (0 0 0 3) (0 3 4 3) (4 3 4 6) (4 6 0 6)))
          ("6" . ((4 0 0 0) (0 0 0 6) (0 6 4 6) (4 6 4 3) (4 3 0 3)))
          ("7" . ((0 0 4 0) (4 0 2 6)))
          ("8" . ((0 0 4 0) (4 0 4 6) (4 6 0 6) (0 6 0 0) (0 3 4 3)))
          ("9" . ((4 6 4 0) (4 0 0 0) (0 0 0 3) (0 3 4 3)))
          ("A" . ((0 6 2 0) (2 0 4 6) (1 4 3 4)))
          ("B" . ((0 0 0 6) (0 0 3 0) (3 0 4 1) (4 1 3 3) (0 3 3 3) (3 3 4 4) (4 4 3 6) (3 6 0 6)))
          ("C" . ((4 0 0 0) (0 0 0 6) (0 6 4 6)))
          ("D" . ((0 0 0 6) (0 0 3 0) (3 0 4 2) (4 2 4 4) (4 4 3 6) (3 6 0 6)))
          ("E" . ((4 0 0 0) (0 0 0 6) (0 6 4 6) (0 3 3 3)))
          ("F" . ((4 0 0 0) (0 0 0 6) (0 3 3 3)))
          ("G" . ((4 0 0 0) (0 0 0 6) (0 6 4 6) (4 6 4 3) (4 3 2 3)))
          ("H" . ((0 0 0 6) (4 0 4 6) (0 3 4 3)))
          ("I" . ((1 0 3 0) (2 0 2 6) (1 6 3 6)))
          ("J" . ((4 0 4 6) (4 6 1 6) (1 6 0 4)))
          ("K" . ((0 0 0 6) (4 0 0 3) (0 3 4 6)))
          ("L" . ((0 0 0 6) (0 6 4 6)))
          ("M" . ((0 6 0 0) (0 0 2 3) (2 3 4 0) (4 0 4 6)))
          ("N" . ((0 6 0 0) (0 0 4 6) (4 6 4 0)))
          ("O" . ((0 0 4 0) (4 0 4 6) (4 6 0 6) (0 6 0 0)))
          ("P" . ((0 6 0 0) (0 0 4 0) (4 0 4 3) (4 3 0 3)))
          ("Q" . ((0 0 4 0) (4 0 4 6) (4 6 0 6) (0 6 0 0) (2 4 4 6)))
          ("R" . ((0 6 0 0) (0 0 4 0) (4 0 4 3) (4 3 0 3) (2 3 4 6)))
          ("S" . ((4 0 0 0) (0 0 0 3) (0 3 4 3) (4 3 4 6) (4 6 0 6)))
          ("T" . ((0 0 4 0) (2 0 2 6)))
          ("U" . ((0 0 0 6) (0 6 4 6) (4 6 4 0)))
          ("V" . ((0 0 2 6) (2 6 4 0)))
          ("W" . ((0 0 1 6) (1 6 2 3) (2 3 3 6) (3 6 4 0)))
          ("X" . ((0 0 4 6) (4 0 0 6)))
          ("Y" . ((0 0 2 3) (4 0 2 3) (2 3 2 6)))
          ("Z" . ((0 0 4 0) (4 0 0 6) (0 6 4 6)))
        )
      ))
    )
    (foreach seg segs
      (vector_image
        (fix (+ x0 (* (nth 0 seg) sx) 0.5))
        (fix (+ y0 (* (nth 1 seg) sy) 0.5))
        (fix (+ x0 (* (nth 2 seg) sx) 0.5))
        (fix (+ y0 (* (nth 3 seg) sy) 0.5))
        col
      )
    )
  )

  (defun fn-prev-draw-string (txt cx cy hPx col / len sx sy charW gap totalW startX startY i)
    (setq len (strlen txt))
    (if (> len 0)
      (progn
        (setq sy     (/ (float hPx) 6.0)
              sx     (* sy 0.85)
              charW  (* 4.0 sx)
              gap    (max 1.0 (* 1.4 sx))
              totalW (+ (* len charW) (* (1- len) gap))
              startX (- cx (/ totalW 2.0))
              startY (- cy (/ hPx 2.0))
              i      1)
        (while (<= i len)
          (fn-prev-draw-char
            (substr txt i 1)
            (+ startX (* (1- i) (+ charW gap)))
            startY sx sy col
          )
          (setq i (1+ i))
        )
      )
    )
  )

  (defun fn-update-live-preview ( /
                                  w h pad
                                  pH pV sc th bd ex posIdx bPos
                                  dH dV val okData
                                  cumY cumX totalY totalX
                                  bubRadModel minX maxX minY maxY
                                  spanX spanY scalePx offX offY
                                  drawStart drawEnd
                                  bubRadPx txtHPx
                                  stepH stepV denseMode
                                  i curY curX
                                  px1 px2 py1 py2 bx by lbl
                                )
    (setq w   (dimx_tile "grid_preview")
          h   (dimy_tile "grid_preview")
          pad 14)

    (setq pH     (if (asgrid:parse-pos-int (get_tile "num_h")) (asgrid:parse-pos-int (get_tile "num_h")) curNumH)
          pV     (if (asgrid:parse-pos-int (get_tile "num_v")) (asgrid:parse-pos-int (get_tile "num_v")) curNumV)
          sc     (if (asgrid:parse-pos-real (get_tile "scale_denom")) (asgrid:parse-pos-real (get_tile "scale_denom")) 100.0)
          th     (if (asgrid:parse-pos-real (get_tile "txt_height")) (asgrid:parse-pos-real (get_tile "txt_height")) 2.5)
          bd     (if (asgrid:parse-pos-real (get_tile "bub_dia")) (asgrid:parse-pos-real (get_tile "bub_dia")) 8.0)
          ex     (if (asgrid:parse-pos-real (get_tile "ext_len")) (asgrid:parse-pos-real (get_tile "ext_len")) 1500.0)
          posIdx (atoi (get_tile "bub_pos"))
          bPos   (if (and (>= posIdx 0) (< posIdx (length BUB_POS_LIST)))
                   (nth posIdx BUB_POS_LIST)
                   "Both Ends"))

    (setq dH '()
          dV '()
          okData T)
    (foreach s strListH
      (setq val (asgrid:parse-pos-real s))
      (if val
        (setq dH (append dH (list val)))
        (progn (setq dH (append dH (list 4000.0))) (setq okData nil))
      )
    )
    (foreach s strListV
      (setq val (asgrid:parse-pos-real s))
      (if val
        (setq dV (append dV (list val)))
        (progn (setq dV (append dV (list 4000.0))) (setq okData nil))
      )
    )

    (setq cumY        (fn-compute-cumulative 0.0 dH)
          cumX        (fn-compute-cumulative 0.0 dV)
          totalY      (last cumY)
          totalX      (last cumX)
          bubRadModel (/ (* bd sc) 2.0)
          drawStart   (or (= bPos "Both Ends") (= bPos "Start"))
          drawEnd     (or (= bPos "Both Ends") (= bPos "End"))
          minX        (- 0.0 ex (if drawStart (* 2.0 bubRadModel) 0.0))
          maxX        (+ totalX ex (if drawEnd (* 2.0 bubRadModel) 0.0))
          minY        (- 0.0 ex (if drawStart (* 2.0 bubRadModel) 0.0))
          maxY        (+ totalY ex (if drawEnd (* 2.0 bubRadModel) 0.0))
          spanX       (max 1.0 (- maxX minX))
          spanY       (max 1.0 (- maxY minY))
          scalePx     (min (/ (float (- w (* 2 pad))) spanX)
                           (/ (float (- h (* 2 pad))) spanY))
          offX        (/ (- (float w) (* spanX scalePx)) 2.0)
          offY        (/ (- (float h) (* spanY scalePx)) 2.0))

    (setq bubRadPx (max 3.0 (min 11.0 (* bubRadModel scalePx)))
          txtHPx   (max 4.0 (min (* bubRadPx 1.2) (* th sc scalePx))))

    (setq stepH     (if (> (length cumY) 10) (max 1 (/ (length cumY) 6)) 1)
          stepV     (if (> (length cumX) 10) (max 1 (/ (length cumX) 6)) 1)
          denseMode (or (> stepH 1) (> stepV 1)))

    (start_image "grid_preview")
    (fill_image 0 0 w h 0)

    (vector_image 0 0 (1- w) 0 8)
    (vector_image (1- w) 0 (1- w) (1- h) 8)
    (vector_image (1- w) (1- h) 0 (1- h) 8)
    (vector_image 0 (1- h) 0 0 8)

    (setq px1 (fix (+ offX (* (- (- 0.0 ex) minX) scalePx) 0.5))
          px2 (fix (+ offX (* (- (+ totalX ex) minX) scalePx) 0.5))
          i   1)
    (foreach curY cumY
      (setq py1 (fix (- (1- h) (+ offY (* (- curY minY) scalePx)) 0.5))
            lbl (itoa i))
      (vector_image px1 py1 px2 py1 9)
      (if (or (= stepH 1) (= i 1) (= i (length cumY)) (= (rem (1- i) stepH) 0))
        (progn
          (if drawStart
            (progn
              (setq bx (fix (- px1 bubRadPx 0.5)))
              (fn-prev-draw-circle bx py1 bubRadPx 2)
              (if (>= bubRadPx 5.0)
                (fn-prev-draw-string lbl bx py1 txtHPx 7)
              )
            )
          )
          (if drawEnd
            (progn
              (setq bx (fix (+ px2 bubRadPx 0.5)))
              (fn-prev-draw-circle bx py1 bubRadPx 2)
              (if (>= bubRadPx 5.0)
                (fn-prev-draw-string lbl bx py1 txtHPx 7)
              )
            )
          )
        )
      )
      (setq i (1+ i))
    )

    (setq py1 (fix (- (1- h) (+ offY (* (- (- 0.0 ex) minY) scalePx)) 0.5))
          py2 (fix (- (1- h) (+ offY (* (- (+ totalY ex) minY) scalePx)) 0.5))
          i   1)
    (foreach curX cumX
      (setq px1 (fix (+ offX (* (- curX minX) scalePx) 0.5))
            lbl (fn-index-to-alpha i))
      (vector_image px1 py1 px1 py2 9)
      (if (or (= stepV 1) (= i 1) (= i (length cumX)) (= (rem (1- i) stepV) 0))
        (progn
          (if drawStart
            (progn
              (setq by (fix (+ py1 bubRadPx 0.5)))
              (fn-prev-draw-circle px1 by bubRadPx 2)
              (if (>= bubRadPx 5.0)
                (fn-prev-draw-string lbl px1 by txtHPx 7)
              )
            )
          )
          (if drawEnd
            (progn
              (setq by (fix (- py2 bubRadPx 0.5)))
              (fn-prev-draw-circle px1 by bubRadPx 2)
              (if (>= bubRadPx 5.0)
                (fn-prev-draw-string lbl px1 by txtHPx 7)
              )
            )
          )
        )
      )
      (setq i (1+ i))
    )

    (end_image)

    (set_tile "prev_info_1"
      (strcat "Grid: " (itoa (length cumY)) "H (1.." (itoa (length cumY)) ") x "
              (itoa (length cumX)) "V (A.." (fn-index-to-alpha (length cumX)) ")"
              (if (not okData) " [Pending input]" "")))
    (set_tile "prev_info_2"
      (strcat "Total Dim: X = " (rtos totalX 2 0) " mm | Y = " (rtos totalY 2 0) " mm"))
    (set_tile "prev_info_3"
      (strcat "Bubble: " bPos " | "
              (if denseMode "Mode: Dense (Sampled Labels)" "Mode: Full Detail")))
  )

  ;; ==========================================================================
  ;; MODUL 8: MANAJEMEN ANTARMUKA DCL & TABEL PAGINATION (UTUH DARI V2.1)
  ;; ==========================================================================

  (defun fn-refresh-h-table ( / totalInt totalPages slot idx lblKey valKey)
    (setq totalInt   (length strListH)
          totalPages (max 1 (/ (+ totalInt (1- PAGE_SIZE)) PAGE_SIZE)))
    (if (>= pageH totalPages) (setq pageH (1- totalPages)))
    (if (< pageH 0) (setq pageH 0))

    (setq slot 1)
    (while (<= slot PAGE_SIZE)
      (setq idx    (+ (* pageH PAGE_SIZE) (1- slot))
            lblKey (strcat "h_lbl_" (itoa slot))
            valKey (strcat "h_val_" (itoa slot)))
      (if (< idx totalInt)
        (progn
          (set_tile lblKey (strcat (itoa (1+ idx)) " - " (itoa (+ idx 2))))
          (set_tile valKey (nth idx strListH))
          (mode_tile valKey 0)
        )
        (progn
          (set_tile lblKey "-")
          (set_tile valKey "")
          (mode_tile valKey 1)
        )
      )
      (setq slot (1+ slot))
    )

    (set_tile "h_page" (strcat "Page " (itoa (1+ pageH)) "/" (itoa totalPages)))
    (mode_tile "h_prev" (if (> pageH 0) 0 1))
    (mode_tile "h_next" (if (< (1+ pageH) totalPages) 0 1))
  )

  (defun fn-refresh-v-table ( / totalInt totalPages slot idx lblKey valKey)
    (setq totalInt   (length strListV)
          totalPages (max 1 (/ (+ totalInt (1- PAGE_SIZE)) PAGE_SIZE)))
    (if (>= pageV totalPages) (setq pageV (1- totalPages)))
    (if (< pageV 0) (setq pageV 0))

    (setq slot 1)
    (while (<= slot PAGE_SIZE)
      (setq idx    (+ (* pageV PAGE_SIZE) (1- slot))
            lblKey (strcat "v_lbl_" (itoa slot))
            valKey (strcat "v_val_" (itoa slot)))
      (if (< idx totalInt)
        (progn
          (set_tile lblKey (strcat (fn-index-to-alpha (1+ idx)) " - " (fn-index-to-alpha (+ idx 2))))
          (set_tile valKey (nth idx strListV))
          (mode_tile valKey 0)
        )
        (progn
          (set_tile lblKey "-")
          (set_tile valKey "")
          (mode_tile valKey 1)
        )
      )
      (setq slot (1+ slot))
    )

    (set_tile "v_page" (strcat "Page " (itoa (1+ pageV)) "/" (itoa totalPages)))
    (mode_tile "v_prev" (if (> pageV 0) 0 1))
    (mode_tile "v_next" (if (< (1+ pageV) totalPages) 0 1))
  )

  (defun fn-save-h-slot (slot valStr / idx)
    (setq idx (+ (* pageH PAGE_SIZE) (1- slot)))
    (if (< idx (length strListH))
      (setq strListH (fn-replace-nth idx valStr strListH))
    )
    (set_tile "error" "")
    (fn-update-live-preview)
  )

  (defun fn-save-v-slot (slot valStr / idx)
    (setq idx (+ (* pageV PAGE_SIZE) (1- slot)))
    (if (< idx (length strListV))
      (setq strListV (fn-replace-nth idx valStr strListV))
    )
    (set_tile "error" "")
    (fn-update-live-preview)
  )

  (defun fn-flush-active-page ( / slot idx)
    (setq slot 1)
    (while (<= slot PAGE_SIZE)
      (setq idx (+ (* pageH PAGE_SIZE) (1- slot)))
      (if (< idx (length strListH))
        (setq strListH (fn-replace-nth idx (get_tile (strcat "h_val_" (itoa slot))) strListH))
      )
      (setq idx (+ (* pageV PAGE_SIZE) (1- slot)))
      (if (< idx (length strListV))
        (setq strListV (fn-replace-nth idx (get_tile (strcat "v_val_" (itoa slot))) strListV))
      )
      (setq slot (1+ slot))
    )
  )

  (defun fn-sync-grid-counts ( / pH pV)
    (fn-flush-active-page)
    (setq pH (asgrid:parse-pos-int (get_tile "num_h"))
          pV (asgrid:parse-pos-int (get_tile "num_v")))
    (cond
      ((null pH)
       (set_tile "error" "Jumlah grid horizontal harus bilangan bulat positif (> 0).")
       (mode_tile "num_h" 2))
      ((null pV)
       (set_tile "error" "Jumlah grid vertikal harus bilangan bulat positif (> 0).")
       (mode_tile "num_v" 2))
      (t
       (set_tile "error" "")
       (setq curNumH  pH
             curNumV  pV
             strListH (fn-resize-str-list strListH (max 0 (1- curNumH)) "4000")
             strListV (fn-resize-str-list strListV (max 0 (1- curNumV)) "4000"))
       (fn-refresh-h-table)
       (fn-refresh-v-table)
       (fn-update-live-preview))
    )
  )

  (defun fn-update-scale-preview ( / sc th bd)
    (setq sc (asgrid:parse-pos-real (get_tile "scale_denom"))
          th (asgrid:parse-pos-real (get_tile "txt_height"))
          bd (asgrid:parse-pos-real (get_tile "bub_dia")))
    (if (and sc th bd)
      (set_tile "scale_preview"
        (strcat "Model Space Preview -> Text: "
                (rtos (* th sc) 2 2)
                " mm | Bubble Dia: "
                (rtos (* bd sc) 2 2)
                " mm"))
      (set_tile "scale_preview"
        "Model Space Preview -> Masukkan skala, tinggi teks, dan diameter bubble valid (> 0).")
    )
    (fn-update-live-preview)
  )

  ;; ==========================================================================
  ;; MODUL 9: VALIDASI INPUT TERPUSAT SEBELUM DIALOG DITUTUP (UTUH DARI V2.1)
  ;; ==========================================================================
  (defun fn-validate-all ( / pH pV sc th bd ex posIdx idx val parsedH parsedV errSlot ok)
    (fn-flush-active-page)
    (setq ok T)

    (setq pH (asgrid:parse-pos-int (get_tile "num_h"))
          pV (asgrid:parse-pos-int (get_tile "num_v")))
    (cond
      ((null pH)
       (set_tile "error" "Error: Jumlah grid horizontal harus bilangan bulat positif (> 0).")
       (mode_tile "num_h" 2)
       (setq ok nil))
      ((null pV)
       (set_tile "error" "Error: Jumlah grid vertikal harus bilangan bulat positif (> 0).")
       (mode_tile "num_v" 2)
       (setq ok nil))
      ((or (/= pH curNumH) (/= pV curNumV))
       (setq curNumH  pH
             curNumV  pV
             strListH (fn-resize-str-list strListH (max 0 (1- curNumH)) "4000")
             strListV (fn-resize-str-list strListV (max 0 (1- curNumV)) "4000"))
       (fn-refresh-h-table)
       (fn-refresh-v-table)
       (fn-update-live-preview)
       (set_tile "error" "Jumlah grid diperbarui. Periksa tabel spacing & preview lalu klik OK lagi.")
       (setq ok nil))
    )

    (if ok
      (progn
        (if (/= (length strListH) (max 0 (1- curNumH)))
          (progn
            (set_tile "error" "Error: Jumlah interval horizontal tidak sesuai (harus N - 1).")
            (setq ok nil)
          )
          (progn
            (setq parsedH '()
                  idx     0)
            (while (and ok (< idx (length strListH)))
              (setq val (asgrid:parse-pos-real (nth idx strListH)))
              (if (null val)
                (progn
                  (setq pageH   (/ idx PAGE_SIZE)
                        errSlot (1+ (rem idx PAGE_SIZE)))
                  (fn-refresh-h-table)
                  (set_tile "error"
                    (strcat "Error: Jarak interval horizontal "
                            (itoa (1+ idx)) " - " (itoa (+ idx 2))
                            " harus angka positif (> 0)."))
                  (mode_tile (strcat "h_val_" (itoa errSlot)) 2)
                  (setq ok nil)
                )
                (setq parsedH (append parsedH (list val)))
              )
              (setq idx (1+ idx))
            )
          )
        )
      )
    )

    (if ok
      (progn
        (if (/= (length strListV) (max 0 (1- curNumV)))
          (progn
            (set_tile "error" "Error: Jumlah interval vertikal tidak sesuai (harus N - 1).")
            (setq ok nil)
          )
          (progn
            (setq parsedV '()
                  idx     0)
            (while (and ok (< idx (length strListV)))
              (setq val (asgrid:parse-pos-real (nth idx strListV)))
              (if (null val)
                (progn
                  (setq pageV   (/ idx PAGE_SIZE)
                        errSlot (1+ (rem idx PAGE_SIZE)))
                  (fn-refresh-v-table)
                  (set_tile "error"
                    (strcat "Error: Jarak interval vertikal "
                            (fn-index-to-alpha (1+ idx)) " - " (fn-index-to-alpha (+ idx 2))
                            " harus angka positif (> 0)."))
                  (mode_tile (strcat "v_val_" (itoa errSlot)) 2)
                  (setq ok nil)
                )
                (setq parsedV (append parsedV (list val)))
              )
              (setq idx (1+ idx))
            )
          )
        )
      )
    )

    (if ok
      (progn
        (setq sc     (asgrid:parse-pos-real (get_tile "scale_denom"))
              th     (asgrid:parse-pos-real (get_tile "txt_height"))
              bd     (asgrid:parse-pos-real (get_tile "bub_dia"))
              ex     (asgrid:parse-pos-real (get_tile "ext_len"))
              posIdx (atoi (get_tile "bub_pos")))
        (cond
          ((null sc)
           (set_tile "error" "Error: Drawing Scale harus angka positif (> 0).")
           (mode_tile "scale_denom" 2)
           (setq ok nil))
          ((null th)
           (set_tile "error" "Error: Printed Text Height harus angka positif (> 0).")
           (mode_tile "txt_height" 2)
           (setq ok nil))
          ((null bd)
           (set_tile "error" "Error: Printed Bubble Diameter harus angka positif (> 0).")
           (mode_tile "bub_dia" 2)
           (setq ok nil))
          ((null ex)
           (set_tile "error" "Error: Extension Length harus angka positif (> 0).")
           (mode_tile "ext_len" 2)
           (setq ok nil))
          ((or (< posIdx 0) (>= posIdx (length BUB_POS_LIST)))
           (set_tile "error" "Error: Pilihan Bubble Position tidak valid.")
           (mode_tile "bub_pos" 2)
           (setq ok nil))
          (t
           (setq numH           curNumH
                 numV           curNumV
                 distListH      parsedH
                 distListV      parsedV
                 scaleDenom     sc
                 textHPrint     th
                 bubbleDiaPrint bd
                 extLen         ex
                 bubblePos      (nth posIdx BUB_POS_LIST))
           (if (<= bubbleDiaPrint textHPrint)
             (princ "\n[ASGRID V2.1.1 Peringatan] Diameter bubble cetak <= tinggi teks cetak; teks dapat melewati bubble.")
           )
           (done_dialog 1))
        )
      )
    )
  )

  ;; ==========================================================================
  ;; ALUR UTAMA PROGRAM ASGRID V2.1.1
  ;; ==========================================================================

  (setq dclFile (findfile "ASGRID_V2_1_1.dcl"))
  (if (null dclFile)
    (progn
      (alert
        (strcat
          "File dialog 'ASGRID_V2_1_1.dcl' tidak ditemukan!\n\n"
          "Pastikan 'ASGRID_V2_1_1.dcl' disimpan pada folder yang terdaftar di\n"
          "AutoCAD Options -> Files -> Support File Search Path."
        )
      )
      (princ "\n[ASGRID V2.1.1 ERROR] File 'ASGRID_V2_1_1.dcl' tidak ditemukan.")
      (princ)
    )
    (progn
      (setq dclId (load_dialog dclFile))
      (if (or (null dclId) (< dclId 0))
        (progn
          (alert "Gagal memuat file dialog 'ASGRID_V2_1_1.dcl'.")
          (princ "\n[ASGRID V2.1.1 ERROR] load_dialog gagal untuk 'ASGRID_V2_1_1.dcl'.")
          (princ)
        )
        (if (not (new_dialog "asgrid_v2_1_1" dclId))
          (progn
            (unload_dialog dclId)
            (setq dclId nil)
            (alert "Definisi dialog 'asgrid_v2_1_1' tidak ditemukan di dalam 'ASGRID_V2_1_1.dcl'.")
            (princ "\n[ASGRID V2.1.1 ERROR] new_dialog gagal untuk 'asgrid_v2_1_1'.")
            (princ)
          )
          (progn
            (setq curNumH            4
                  curNumV            4
                  strListH           '("4000" "4000" "4000")
                  strListV           '("5000" "5000" "5000")
                  pageH              0
                  pageV              0
                  nextGroupIdPreview (fn-meta-generate-next-id))

            (set_tile "num_h"       (itoa curNumH))
            (set_tile "num_v"       (itoa curNumV))
            (set_tile "scale_denom" "100")
            (set_tile "txt_height"  "2.5")
            (set_tile "bub_dia"     "8.0")
            (set_tile "ext_len"     "1500")
            (set_tile "prev_meta_info"
              (strcat "Next Group ID: " nextGroupIdPreview " (Verified DWG Metadata)"))

            (start_list "bub_pos")
            (mapcar 'add_list BUB_POS_LIST)
            (end_list)
            (set_tile "bub_pos" "0")

            (setq arialPath (fn-find-arial-ttf))
            (if arialPath
              (set_tile "font_status" (strcat "Status: Font Arial tersedia (" arialPath ")"))
              (set_tile "font_status" "PERINGATAN: File font arial.ttf TIDAK ditemukan pada sistem!")
            )

            (fn-refresh-h-table)
            (fn-refresh-v-table)
            (fn-update-scale-preview)

            (action_tile "num_h"            "(fn-sync-grid-counts)")
            (action_tile "num_v"            "(fn-sync-grid-counts)")
            (action_tile "btn_update_tbl"   "(fn-sync-grid-counts)")

            (action_tile "h_val_1" "(fn-save-h-slot 1 $value)")
            (action_tile "h_val_2" "(fn-save-h-slot 2 $value)")
            (action_tile "h_val_3" "(fn-save-h-slot 3 $value)")
            (action_tile "h_val_4" "(fn-save-h-slot 4 $value)")
            (action_tile "h_val_5" "(fn-save-h-slot 5 $value)")
            (action_tile "h_val_6" "(fn-save-h-slot 6 $value)")
            (action_tile "h_val_7" "(fn-save-h-slot 7 $value)")
            (action_tile "h_val_8" "(fn-save-h-slot 8 $value)")
            (action_tile "h_prev"  "(if (> pageH 0) (progn (fn-flush-active-page) (setq pageH (1- pageH)) (fn-refresh-h-table) (fn-update-live-preview)))")
            (action_tile "h_next"  "(progn (fn-flush-active-page) (setq pageH (1+ pageH)) (fn-refresh-h-table) (fn-update-live-preview))")

            (action_tile "v_val_1" "(fn-save-v-slot 1 $value)")
            (action_tile "v_val_2" "(fn-save-v-slot 2 $value)")
            (action_tile "v_val_3" "(fn-save-v-slot 3 $value)")
            (action_tile "v_val_4" "(fn-save-v-slot 4 $value)")
            (action_tile "v_val_5" "(fn-save-v-slot 5 $value)")
            (action_tile "v_val_6" "(fn-save-v-slot 6 $value)")
            (action_tile "v_val_7" "(fn-save-v-slot 7 $value)")
            (action_tile "v_val_8" "(fn-save-v-slot 8 $value)")
            (action_tile "v_prev"  "(if (> pageV 0) (progn (fn-flush-active-page) (setq pageV (1- pageV)) (fn-refresh-v-table) (fn-update-live-preview)))")
            (action_tile "v_next"  "(progn (fn-flush-active-page) (setq pageV (1+ pageV)) (fn-refresh-v-table) (fn-update-live-preview))")

            (action_tile "scale_denom"      "(fn-update-scale-preview)")
            (action_tile "txt_height"       "(fn-update-scale-preview)")
            (action_tile "bub_dia"          "(fn-update-scale-preview)")
            (action_tile "ext_len"          "(fn-update-live-preview)")
            (action_tile "bub_pos"          "(fn-update-live-preview)")
            (action_tile "btn_refresh_prev" "(progn (fn-flush-active-page) (fn-update-scale-preview))")

            (action_tile "accept" "(fn-validate-all)")
            (action_tile "cancel" "(done_dialog 0)")

            (setq dclRes (start_dialog))
            (unload_dialog dclId)
            (setq dclId nil)

            (if (= dclRes 1)
              (progn
                (setq basePtUcs (getpoint "\n[ASGRID V2.1.1] Klik titik awal grid (pojok kiri bawah): "))
                (if basePtUcs
                  (progn
                    (setq basePt (trans basePtUcs 1 0))
                    (fn-execute-grid-creation basePt)
                  )
                  (princ "\n[ASGRID V2.1.1] Titik awal tidak dipilih. Proses dibatalkan tanpa mengubah gambar.")
                )
              )
              (princ "\n[ASGRID V2.1.1] Dibatalkan oleh pengguna. Tidak ada objek yang dibuat.")
            )
            (princ)
          )
        )
      )
    )
  )
)


;;; ============================================================================
;;; PERINTAH DIAGNOSTIK READ-ONLY: ASGRIDCHECK
;;; Memeriksa integritas metadata NOD/XRecord dan entitas XData ASGRID_OBJ
;;; secara READ-ONLY (tidak mengubah, memperbaiki, atau menghapus data apa pun).
;;; ============================================================================

(defun c:ASGRIDCHECK ( /
                       *error*
                       nodIds ss i ename parsed gid role
                       entMap entry curCounts newCounts
                       corruptXdataCnt orphanEntMap
                       issuesCnt totalGroups
                       spec valErrs expCounts expL expB expT expTot
                       actL actB actT actTot
                       fn-inc-group-role
                     )

  (defun *error* (msg)
    (if (and msg (not (member msg '("Function cancelled" "quit / exit abort" "console break"))))
      (princ (strcat "\n[ASGRIDCHECK ERROR] " msg))
      (princ "\n[ASGRIDCHECK] Pemeriksaan dibatalkan.")
    )
    (princ)
  )

  ;; Helper lokal: tambah counter (L B T) pada assoc list entMap untuk gid tertentu
  (defun fn-inc-group-role (amap g r / rec cnts l b tCnt newRec res)
    (setq rec (assoc g amap))
    (if rec
      (progn
        (setq cnts (cdr rec)
              l    (nth 0 cnts)
              b    (nth 1 cnts)
              tCnt (nth 2 cnts))
        (cond
          ((= r "LINE")   (setq l (1+ l)))
          ((= r "BUBBLE") (setq b (1+ b)))
          ((= r "TEXT")   (setq tCnt (1+ tCnt)))
        )
        (setq newRec (cons g (list l b tCnt))
              res    '())
        (foreach item amap
          (if (= (car item) g)
            (setq res (append res (list newRec)))
            (setq res (append res (list item)))
          )
        )
        res
      )
      (append amap
        (list
          (cons g
            (cond
              ((= r "LINE")   '(1 0 0))
              ((= r "BUBBLE") '(0 1 0))
              ((= r "TEXT")   '(0 0 1))
              (t              '(0 0 0))
            )
          )
        )
      )
    )
  )

  (princ "\n============================================================")
  (princ "\n  ASGRIDCHECK V2.1.1 - DIAGNOSTIK INTEGRITAS (READ-ONLY)    ")
  (princ "\n============================================================")

  (setq nodIds          (asgrid:meta-list-nod-ids)
        entMap          '()
        orphanEntMap    '()
        corruptXdataCnt 0
        issuesCnt       0)

  ;; 1. Pindai seluruh entitas yang membawa XData ASGRID_OBJ (READ-ONLY)
  (setq ss (ssget "_X" (list (list -3 (list (asgrid:xdata-app))))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename  (ssname ss i)
              parsed (asgrid:parse-entity-xdata ename))
        (if (null parsed)
          (progn
            (setq corruptXdataCnt (1+ corruptXdataCnt)
                  issuesCnt       (1+ issuesCnt))
          )
          (progn
            (setq gid  (nth 0 parsed)
                  role (nth 1 parsed))
            (if (member gid nodIds)
              (setq entMap (fn-inc-group-role entMap gid role))
              (setq orphanEntMap (fn-inc-group-role orphanEntMap gid role))
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )

  ;; 2. Laporan per Group ID yang terdaftar di NOD ASGRID_GROUPS
  (setq totalGroups (length nodIds))
  (princ (strcat "\n  Grup terdaftar di NOD (" (asgrid:dict-name) "): " (itoa totalGroups)))

  (if (= totalGroups 0)
    (princ "\n  Tidak ada kelompok grid ASGRID terdaftar di DWG ini.")
    (foreach gid nodIds
      (princ (strcat "\n\n  [GRUP: " gid "]"))
      (setq spec (asgrid:meta-read-group gid))
      (if (null spec)
        (progn
          (princ "\n    - Status XRecord : ERROR (XRecord tidak dapat dibaca)")
          (setq issuesCnt (1+ issuesCnt))
        )
        (progn
          (setq valErrs (asgrid:meta-validate-spec spec))
          (if valErrs
            (progn
              (princ (strcat "\n    - Integritas Meta: ERROR (" (car valErrs) ")"))
              (setq issuesCnt (1+ issuesCnt))
            )
            (progn
              (setq expCounts (asgrid:calc-expected-counts spec)
                    expL      (nth 0 expCounts)
                    expB      (nth 1 expCounts)
                    expT      (nth 2 expCounts)
                    expTot    (nth 3 expCounts)
                    entry     (assoc gid entMap)
                    actL      (if entry (nth 0 (cdr entry)) 0)
                    actB      (if entry (nth 1 (cdr entry)) 0)
                    actT      (if entry (nth 2 (cdr entry)) 0)
                    actTot    (+ actL actB actT))
              (princ (strcat "\n    - Integritas Meta: OK (Schema " (cdr (assoc "SCHEMA_VER" spec))
                             " | Gen V" (cdr (assoc "GENERATOR_VER" spec))
                             " | Scale 1:" (rtos (cdr (assoc "SCALE_DENOM" spec)) 2 0) ")"))
              (princ (strcat "\n    - Konfigurasi    : " (itoa (cdr (assoc "NUM_H" spec))) "H x "
                             (itoa (cdr (assoc "NUM_V" spec))) "V | Bubble: "
                             (cdr (assoc "BUBBLE_POS" spec))))
              (princ (strcat "\n    - Entitas Aktual : Lines " (itoa actL) "/" (itoa expL)
                             " | Bubbles " (itoa actB) "/" (itoa expB)
                             " | Texts " (itoa actT) "/" (itoa expT)
                             " (Total " (itoa actTot) "/" (itoa expTot) ")"))
              (cond
                ((= actTot 0)
                 (princ "\n    - Status Entitas : PERINGATAN - Metadata yatim (0 entitas ditemukan di gambar).")
                 (setq issuesCnt (1+ issuesCnt)))
                ((or (/= actL expL) (/= actB expB) (/= actT expT))
                 (princ "\n    - Status Entitas : PERINGATAN - Jumlah entitas tidak sesuai metadata (sebagian terhapus/terubah).")
                 (setq issuesCnt (1+ issuesCnt)))
                (t
                 (princ "\n    - Status Entitas : OK (Lengkap & cocok dengan metadata)."))
              )
            )
          )
        )
      )
    )
  )

  ;; 3. Laporan anomali XData (entitas tanpa metadata NOD atau XData korup)
  (if orphanEntMap
    (progn
      (princ "\n\n  [PERINGATAN: ENTITAS TANPA METADATA DI NOD]")
      (foreach entry orphanEntMap
        (setq gid    (car entry)
              actL   (nth 0 (cdr entry))
              actB   (nth 1 (cdr entry))
              actT   (nth 2 (cdr entry))
              issuesCnt (1+ issuesCnt))
        (princ (strcat "\n    - Group ID '" gid "' tidak ada di NOD (ditemukan: "
                       (itoa actL) " LINE, " (itoa actB) " BUBBLE, " (itoa actT) " TEXT)."))
      )
    )
  )

  (if (> corruptXdataCnt 0)
    (princ (strcat "\n\n  [PERINGATAN: XDATA KORUP] Ditemukan " (itoa corruptXdataCnt)
                   " entitas dengan struktur XData ASGRID_OBJ tidak valid."))
  )

  ;; 4. Ringkasan akhir READ-ONLY
  (princ "\n------------------------------------------------------------")
  (if (= issuesCnt 0)
    (princ "\n[ASGRIDCHECK] HASIL: SEMUA GRUP & ENTITAS SEHAT (0 MASALAH).")
    (princ (strcat "\n[ASGRIDCHECK] HASIL: DITEMUKAN " (itoa issuesCnt)
                   " PERINGATAN/MASALAH. (Mode READ-ONLY: tidak ada data diubah.)"))
  )
  (princ "\n------------------------------------------------------------")
  (princ)
)

;; Pesan saat file berhasil dimuat melalui APPLOAD
(princ "\n[ASGRID V2.1.1] Berhasil dimuat. Perintah: ASGRID (buat grid) | ASGRIDCHECK (diagnostik read-only).")
(princ)
