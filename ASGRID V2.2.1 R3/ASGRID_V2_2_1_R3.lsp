;;; ============================================================================
;;; PROGRAM     : ASGRID V2.2 (PHASE 2 - GENERATOR + ASGRIDEDIT MODE 1)
;;; TARGET      : AutoCAD 2021 (AutoLISP Standar + DCL)
;;; BASELINE    : ASGRID_V2_1_2.lsp (V2.1.2 tetap dipertahankan sebagai backup)
;;; FILE TERKAIT: ASGRID_V2_2_1_R3.dcl (harus tersedia di Support File Search Path)
;;; UNIT        : Millimeter (mm) pada Model Space (WCS)
;;; COMMANDS    :
;;;   - ASGRID      : Membuat grid baru (menggunakan Shared Stateless Services)
;;;   - ASGRIDCHECK : Diagnostik integritas mendalam (100% READ-ONLY)
;;;   - ASGRIDEDIT  : Editor Anotasi Mode 1 (Create-Verify-Swap-Commit)
;;; FONDASI V2.2 PHASE 1 :
;;;   1. Ekstraksi Shared Stateless Services (asgrid:*) tanpa global state.
;;;   2. Decoupled Annotation Engine (mengembalikan ename list + counts).
;;;   3. Metadata opsional ANNO_EXT_LEN dengan fallback ke EXT_LEN (Schema 1.0),
;;;      ditambah asgrid:meta-update-group & snapshot pemulihan XRecord.
;;;   4. Live Preview Service (asgrid:prev-render-grid) mendukung geomExtLen
;;;      dan annoExtLen terpisah.
;;;   5. Shared Group Audit Service (asgrid:audit-group-entities, READ-ONLY).
;;; ============================================================================

;;; ============================================================================
;;; SECTION 1: SHARED STATELESS CONSTANTS & CORE UTILITIES (PREFIX: asgrid:*)
;;; Catatan: Zero global data/state variables. Seluruh fungsi bersifat murni
;;;          dengan parameter eksplisit dan return value eksplisit.
;;; ============================================================================

(defun asgrid:dict-name () "ASGRID_GROUPS")
(defun asgrid:xdata-app () "ASGRID_OBJ")
(defun asgrid:xdata-tmp-app () "ASGRID_TX_TMP")

;; Pastikan RegApp terdaftar di tabel APPID (pola aman AutoCAD 2021 via tblsearch)
(defun asgrid:ensure-regapp (appName)
  (if (not (tblsearch "APPID" appName))
    (regapp appName)
  )
  (not (null (tblsearch "APPID" appName)))
)
(defun asgrid:schema-ver () "1.0")
(defun asgrid:valid-bubble-positions () '("Both Ends" "Start" "End"))
(defun asgrid:tol () 1e-6)

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

;; Konversi indeks berbasis-1 (1,2,...) ke huruf (A..Z, AA, AB, ...)
(defun asgrid:index-to-alpha (idx / n remVal res)
  (setq n   idx
        res "")
  (while (> n 0)
    (setq n      (1- n)
          remVal (rem n 26)
          res    (strcat (chr (+ 65 remVal)) res)
          n      (/ n 26))
  )
  res
)

;; Hitung daftar koordinat kumulatif dari koordinat awal dan daftar interval
(defun asgrid:compute-cumulative (startCoord distList / acc res val)
  (setq acc (float startCoord)
        res (list acc))
  (foreach val distList
    (setq acc (+ acc (float val))
          res (append res (list acc)))
  )
  res
)

;; Ambil timestamp lokal dari CDATE AutoCAD (YYYY-MM-DD HH:MM:SS)
(defun asgrid:get-timestamp ( / s)
  (setq s (rtos (getvar "CDATE") 2 6))
  (if (>= (strlen s) 15)
    (strcat (substr s 1 4) "-" (substr s 5 2) "-" (substr s 7 2) " "
            (substr s 10 2) ":" (substr s 12 2) ":" (substr s 14 2))
    s
  )
)

;; Peringatan non-blocking jika INSUNITS bukan 4 (Millimeters); tidak mengubah INSUNITS
(defun asgrid:check-insunits-warning (verLabel / u)
  (setq u (getvar "INSUNITS"))
  (if (and (= (type u) 'INT) (/= u 4))
    (princ (strcat "\n[" verLabel " Info] INSUNITS gambar saat ini = " (itoa u)
                   " (bukan 4/Millimeters). ASGRID tetap menggunakan satuan mm tanpa mengubah INSUNITS."))
  )
)


;;; ============================================================================
;;; SECTION 2: SHARED FONT ARIAL SERVICE
;;; ============================================================================

;; Cari file font (default "arial.ttf") di Support Path AutoCAD atau Windows Fonts
(defun asgrid:find-font-file (fontFile / p ext winDir sysRoot)
  (if (or (not (= (type fontFile) 'STR)) (= (strlen (asgrid:trim fontFile)) 0))
    nil
    (progn
      (setq p (findfile fontFile))
      (if (null p)
        (setq p (findfile (strcat fontFile ".shx")))
      )
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
  )
)

;; Daftar seluruh Text Style non-Xref, non-shape dari tabel STYLE drawing
(defun asgrid:list-drawing-styles ( / rec nm flag styles)
  (setq styles '()
        rec    (tblnext "STYLE" T))
  (while rec
    (setq nm   (cdr (assoc 2 rec))
          flag (cdr (assoc 70 rec)))
    (if (and (= (type nm) 'STR)
             (> (strlen nm) 0)
             (= (logand flag 1) 0)   ; bukan shape file
             (= (logand flag 16) 0)  ; bukan xref-dependent
             (not (vl-string-search "|" nm)))
      (setq styles (append styles (list nm)))
    )
    (setq rec (tblnext "STYLE"))
  )
  styles
)

;; Deteksi status Annotative pada record tabel STYLE via XData AcadAnnotative
(defun asgrid:style-is-annotative (styleName / ename edata xdata pair found)
  (setq found nil
        ename (tblobjname "STYLE" styleName))
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

;; Validasi ketat Text Style untuk ASGRIDEDIT (tanpa mengubah definisi style)
;; Mengembalikan: (list T fontFile) jika valid, atau (list nil errMsg) jika ditolak
(defun asgrid:validate-text-style (styleName / rec flag fixedH fontFile ename edata xacad)
  (cond
    ((or (not (= (type styleName) 'STR)) (= (strlen (asgrid:trim styleName)) 0))
     (list nil "Nama Text Style kosong."))
    ((vl-string-search "|" styleName)
     (list nil (strcat "Text Style '" styleName "' merupakan Xref-dependent style dan tidak boleh digunakan.")))
    ((null (setq rec (tblsearch "STYLE" styleName)))
     (list nil (strcat "Text Style '" styleName "' tidak ditemukan dalam drawing.")))
    (t
     (setq flag     (cdr (assoc 70 rec))
           fixedH   (cdr (assoc 40 rec))
           fontFile (cdr (assoc 3 rec)))
     (cond
       ((/= (logand flag 1) 0)
        (list nil (strcat "Style '" styleName "' adalah shape file, bukan Text Style.")))
       ((/= (logand flag 16) 0)
        (list nil (strcat "Text Style '" styleName "' bersifat Xref-dependent.")))
       ((and (numberp fixedH) (> fixedH 0.0))
        (list nil (strcat "Text Style '" styleName "' memiliki Fixed Height > 0 ("
                          (rtos fixedH 2 2) "). Pilih style dengan Height = 0 agar skala cetak tetap akurat.")))
       ((asgrid:style-is-annotative styleName)
        (list nil (strcat "Text Style '" styleName "' bersifat Annotative dan ditolak agar tidak terjadi penskalaan ganda.")))
       (t
        ;; Cek ketersediaan file font (jika assoc 3 kosong, cek XData ACAD TrueType)
        (if (or (null fontFile) (= (strlen (asgrid:trim fontFile)) 0))
          (progn
            (setq ename (tblobjname "STYLE" styleName)
                  edata (if ename (entget ename '("ACAD")) nil)
                  xacad (if edata (cadr (assoc -3 edata)) nil))
            (if (and xacad (assoc 1000 (cdr xacad)))
              (list T (cdr (assoc 1000 (cdr xacad))))
              (list nil (strcat "File font untuk Text Style '" styleName "' tidak terdefinisi."))
            )
          )
          (if (asgrid:find-font-file fontFile)
            (list T fontFile)
            (list nil (strcat "File font '" fontFile "' untuk Text Style '" styleName "' tidak ditemukan pada sistem."))
          )
        ))
     ))
  )
)

(defun asgrid:find-arial-ttf (fontFile / p winDir sysRoot)
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

;; Pastikan Text Style khusus (misal "ASGRID-ARIAL") memakai fontFile ("arial.ttf")
;; tanpa mengubah TEXTSTYLE aktif maupun style milik objek lain.
(defun asgrid:ensure-arial-style (styleName fontFile verLabel / tblRec existingFont ok)
  (setq ok nil)
  (if (null (asgrid:find-arial-ttf fontFile))
    (progn
      (alert
        (strcat
          "PERINGATAN: File font '" fontFile "' (Arial) tidak ditemukan pada sistem.\n\n"
          verLabel " tidak akan mengganti font secara diam-diam.\n"
          "Pastikan font Arial terpasang di Windows Fonts atau Support File Search Path AutoCAD."
        )
      )
      (princ (strcat "\n[" verLabel " ERROR] Font '" fontFile "' tidak ditemukan. Proses dihentikan."))
      nil
    )
    (progn
      (setq tblRec (tblsearch "STYLE" styleName))
      (if tblRec
        (progn
          (setq existingFont (strcase (cdr (assoc 3 tblRec))))
          (if (= existingFont (strcase fontFile))
            (setq ok T)
            (progn
              (alert
                (strcat
                  "PERINGATAN: Text Style '" styleName "' sudah ada tetapi tidak menggunakan '" fontFile "' "
                  "(font saat ini: " existingFont ").\n\n"
                  "Untuk menjaga objek lain dalam gambar, ASGRID tidak menimpa style tersebut.\n"
                  "Ubah font style '" styleName "' ke Arial (" fontFile ") secara manual lalu jalankan ulang."
                )
              )
              (princ (strcat "\n[" verLabel " ERROR] Style '" styleName "' memakai font lain (" existingFont ")."))
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
          (if (not ok)
            (progn
              (alert (strcat "Gagal membuat Text Style '" styleName "' dengan font '" fontFile "'."))
              (princ (strcat "\n[" verLabel " ERROR] Gagal membuat Text Style '" styleName "'."))
            )
          )
        )
      )
      ok
    )
  )
)


;;; ============================================================================
;;; SECTION 3: SHARED METADATA, XDATA & XRECORD SERVICE (SCHEMA 1.0 + ANNO_EXT_LEN)
;;; ============================================================================

;; Bangun payload XData identitas objek ASGRID_OBJ
(defun asgrid:make-obj-xdata-for-app (appName groupId role axisDir axisIdx endTag schemaVer)
  (list -3
    (list appName
      (cons 1000 groupId)
      (cons 1000 role)
      (cons 1000 axisDir)
      (cons 1070 axisIdx)
      (cons 1000 endTag)
      (cons 1000 schemaVer)
    )
  )
)

(defun asgrid:make-obj-xdata (groupId role axisDir axisIdx endTag schemaVer)
  (asgrid:make-obj-xdata-for-app (asgrid:xdata-app) groupId role axisDir axisIdx endTag schemaVer)
)

;; Resolver ANNO_EXT_LEN dengan fallback otomatis ke EXT_LEN untuk grid lama
;; (V2.1, V2.1.1, V2.1.2 yang belum menyimpan key opsional ANNO_EXT_LEN)
(defun asgrid:get-anno-ext-len (spec / aExt gExt)
  (setq aExt (cdr (assoc "ANNO_EXT_LEN" spec))
        gExt (cdr (assoc "EXT_LEN" spec)))
  (cond
    ((and (numberp aExt) (> aExt 0.0)) (float aExt))
    ((and (numberp gExt) (> gExt 0.0)) (float gExt))
    (t nil)
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

;; Daftar Group ID yang terdaftar di NOD ASGRID_GROUPS
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

;; Ekstrak field XData ASGRID_OBJ -> (list gid role axisDir axisIdx endTag schemaVer) atau nil
(defun asgrid:parse-entity-xdata-for-app (ename appName / entData xrec vals gid role dir idx etag sver)
  (if (and ename (entget ename))
    (progn
      (setq entData (entget ename (list appName))
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

(defun asgrid:parse-entity-xdata (ename)
  (asgrid:parse-entity-xdata-for-app ename (asgrid:xdata-app))
)

;; Kumpulkan seluruh Group ID dari NOD + XData objek top-level (anti bentrok)
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

;; Susun daftar pasangan payload DXF (300 . key) + (code . val) untuk XRecord
;; Dipakai bersama oleh pembuatan XRecord baru dan asgrid:meta-update-group.
(defun asgrid:meta-build-xrecord-payload (spec / payload dVal aExt updAt)
  (setq payload
    (list
      (cons 300 "SCHEMA_VER")       (cons 1  (cdr (assoc "SCHEMA_VER" spec)))
      (cons 300 "GROUP_ID")         (cons 1  (cdr (assoc "GROUP_ID" spec)))
      (cons 300 "MODULE")           (cons 1  (cdr (assoc "MODULE" spec)))
      (cons 300 "GENERATOR_VER")    (cons 1  (cdr (assoc "GENERATOR_VER" spec)))
      (cons 300 "CREATED_AT")       (cons 1  (cdr (assoc "CREATED_AT" spec)))
      (cons 300 "NUM_H")            (cons 90 (cdr (assoc "NUM_H" spec)))
      (cons 300 "NUM_V")            (cons 90 (cdr (assoc "NUM_V" spec)))
      (cons 300 "BASE_PT_WCS")      (cons 10 (cdr (assoc "BASE_PT_WCS" spec)))
      (cons 300 "ELEVATION")        (cons 40 (float (cdr (assoc "ELEVATION" spec))))
      (cons 300 "AXIS_DIR_H")       (cons 1  (cdr (assoc "AXIS_DIR_H" spec)))
      (cons 300 "AXIS_DIR_V")       (cons 1  (cdr (assoc "AXIS_DIR_V" spec)))
      (cons 300 "DIST_H_COUNT")     (cons 90 (cdr (assoc "DIST_H_COUNT" spec)))
    )
  )
  (foreach dVal (cdr (assoc "DIST_H" spec))
    (setq payload (append payload (list (cons 300 "DIST_H_ITEM") (cons 40 (float dVal)))))
  )
  (setq payload
    (append payload
      (list (cons 300 "DIST_V_COUNT") (cons 90 (cdr (assoc "DIST_V_COUNT" spec))))
    )
  )
  (foreach dVal (cdr (assoc "DIST_V" spec))
    (setq payload (append payload (list (cons 300 "DIST_V_ITEM") (cons 40 (float dVal)))))
  )
  (setq payload
    (append payload
      (list
        (cons 300 "SCALE_DENOM")      (cons 40 (float (cdr (assoc "SCALE_DENOM" spec))))
        (cons 300 "TEXT_H_PRINT")     (cons 40 (float (cdr (assoc "TEXT_H_PRINT" spec))))
        (cons 300 "BUBBLE_DIA_PRINT") (cons 40 (float (cdr (assoc "BUBBLE_DIA_PRINT" spec))))
        (cons 300 "EXT_LEN")          (cons 40 (float (cdr (assoc "EXT_LEN" spec))))
        (cons 300 "BUBBLE_POS")       (cons 1  (cdr (assoc "BUBBLE_POS" spec)))
        (cons 300 "TEXT_STYLE")       (cons 1  (cdr (assoc "TEXT_STYLE" spec)))
        (cons 300 "FONT_FILE")        (cons 1  (cdr (assoc "FONT_FILE" spec)))
        (cons 300 "LAYER_GRID")       (cons 1  (cdr (assoc "LAYER_GRID" spec)))
        (cons 300 "LAYER_BUBBLE")     (cons 1  (cdr (assoc "LAYER_BUBBLE" spec)))
        (cons 300 "LAYER_TEXT")       (cons 1  (cdr (assoc "LAYER_TEXT" spec)))
      )
    )
  )
  ;; Field opsional V2.2: ANNO_EXT_LEN dan UPDATED_AT
  (setq aExt (cdr (assoc "ANNO_EXT_LEN" spec)))
  (if (and (numberp aExt) (> aExt 0.0))
    (setq payload (append payload (list (cons 300 "ANNO_EXT_LEN") (cons 40 (float aExt)))))
  )
  (setq updAt (cdr (assoc "UPDATED_AT" spec)))
  (if (and (= (type updAt) 'STR) (> (strlen updAt) 0))
    (setq payload (append payload (list (cons 300 "UPDATED_AT") (cons 1 updAt))))
  )
  payload
)

;; Parse daftar DXF XRecord (dList) menjadi spec asosiasi ASGRID
;; Dipakai bersama oleh asgrid:meta-read-group dan validasi pra-restore
;; pada asgrid:meta-restore-xrecord (menghindari duplikasi parser).
(defun asgrid:meta-parse-xrecord-dxf (dList / res dH dV readErrs curKey pair code val)
  (if (or (null dList)
          (not (listp dList))
          (/= (cdr (assoc 0 dList)) "XRECORD"))
    nil
    (progn
      (setq res      '()
            dH       '()
            dV       '()
            readErrs '()
            curKey   nil)
      (foreach pair dList
        (if (and (listp pair) (numberp (car pair)))
          (progn
            (setq code (car pair)
                  val  (cdr pair))
            (cond
              ((= code 300)
               (if curKey
                 (setq readErrs (append readErrs
                   (list (strcat "Key XRecord tanpa nilai: " curKey))))
               )
               (setq curKey (if (= (type val) 'STR) val nil)))
              ((and curKey (member code '(1 10 40 70 90)))
               (cond
                 ((= curKey "DIST_H_ITEM")
                  (if (numberp val)
                    (setq dH (append dH (list (float val))))
                    (setq readErrs (append readErrs
                      (list "Nilai DIST_H_ITEM pada XRecord bukan numerik (numberp gagal).")))
                  ))
                 ((= curKey "DIST_V_ITEM")
                  (if (numberp val)
                    (setq dV (append dV (list (float val))))
                    (setq readErrs (append readErrs
                      (list "Nilai DIST_V_ITEM pada XRecord bukan numerik (numberp gagal).")))
                  ))
                 ((member curKey '("ELEVATION" "SCALE_DENOM" "TEXT_H_PRINT"
                                   "BUBBLE_DIA_PRINT" "EXT_LEN" "ANNO_EXT_LEN"))
                  (if (numberp val)
                    (setq res (append res (list (cons curKey (float val)))))
                    (setq readErrs (append readErrs
                      (list (strcat "Nilai " curKey " pada XRecord bukan numerik."))))
                  ))
                 ((member curKey '("NUM_H" "NUM_V" "DIST_H_COUNT" "DIST_V_COUNT"))
                  (if (= (type val) 'INT)
                    (setq res (append res (list (cons curKey val))))
                    (setq readErrs (append readErrs
                      (list (strcat "Nilai " curKey " pada XRecord bukan integer."))))
                  ))
                 ((= curKey "BASE_PT_WCS")
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
                  (setq res (append res (list (cons curKey val)))))
               )
               (setq curKey nil))
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

;; Baca Group Metadata dari NOD XRecord ke spec asosiasi (Hardened + ANNO_EXT_LEN)
(defun asgrid:meta-read-group (groupId / rootDict rec xrecEname dList)
  (setq rootDict (asgrid:meta-get-root-dict nil))
  (if (or (null rootDict) (not (= (type groupId) 'STR)) (= (strlen groupId) 0))
    nil
    (progn
      (setq rec (dictsearch rootDict groupId))
      (if (null rec)
        nil
        (progn
          (setq xrecEname (cdr (assoc -1 rec))
                dList     (if xrecEname (entget xrecEname) nil))
          (asgrid:meta-parse-xrecord-dxf dList)
        )
      )
    )
  )
)

;; Ambil snapshot mentah XRecord (entget) untuk pemulihan rollback bila update gagal
(defun asgrid:meta-get-xrecord-snapshot (groupId / rootDict rec xrecEname)
  (setq rootDict (asgrid:meta-get-root-dict nil))
  (if (and rootDict (= (type groupId) 'STR) (> (strlen groupId) 0))
    (progn
      (setq rec       (dictsearch rootDict groupId)
            xrecEname (if rec (cdr (assoc -1 rec)) nil))
      (if xrecEname (entget xrecEname) nil)
    )
    nil
  )
)

;; V2.2.1 REVISION 1: Ekstrak seluruh payload mentah asli XRecord setelah
;; subclass marker (100 . "AcDbXrecord").
;; State machine 3-tahap sesuai struktur DXF AcDbXrecord:
;;   state 0 = sebelum (100 . "AcDbXrecord") -> lewati header entitas
;;   state 1 = tepat elemen pertama setelah (100 . "AcDbXrecord"):
;;             jika group code 280 dengan nilai integer rentang 0..5
;;             (Duplicate Record Cloning Flag DXF standar), lewati HANYA satu
;;             kali lalu masuk state 2; selain itu pertahankan sebagai payload
;;             pertama dan masuk state 2.
;;   state 2 = dalam payload -> pertahankan SEMUA pasangan DXF apa adanya,
;;             termasuk group code 280 yang muncul sebagai payload.
;; BATASAN DXF (AMBIGUITAS INHEREN):
;;   Apabila sebuah XRecord non-standar tidak memiliki header flag 280 dan
;;   elemen PERTAMA payload-nya persis berupa (280 . 0..5), format DXF tidak
;;   menyediakan penanda pemisah; elemen tersebut akan diperlakukan sebagai
;;   header flag 280. Untuk seluruh XRecord ASGRID (diawali 300 . "SCHEMA_VER")
;;   dan XRecord standar AutoCAD (selalu memiliki header 280), ekstraksi ini
;;   bersifat 100% deterministik.
(defun asgrid:meta-extract-raw-payload (xrecDxf / state res pair code val)
  (setq state 0
        res   '())
  (if (and xrecDxf (listp xrecDxf))
    (foreach pair xrecDxf
      (if (and (listp pair) (numberp (car pair)))
        (progn
          (setq code (car pair)
                val  (cdr pair))
          (cond
            ((= state 0)
             (if (and (= code 100) (= val "AcDbXrecord"))
               (setq state 1)
             ))
            ((= state 1)
             (if (and (= code 280) (= (type val) 'INT) (>= val 0) (<= val 5))
               (setq state 2) ; lewati HANYA header Duplicate Record Cloning Flag (0..5)
               (progn
                 (setq res   (append res (list pair))
                       state 2)
               )
             ))
            (t
             (setq res (append res (list pair))))
          )
        )
      )
    )
  )
  res
)

;; V2.2.1 REVISION 2: Pulihkan XRecord grup di NOD dari snapshot mentah asli
;; menggunakan Replace-in-Dictionary (validate snapshot -> entmakex ->
;; dictremove -> dictadd -> read-back verification -> cleanup) TANPA entmod.
;; Perbaikan Revision 2 (Final Hardening):
;;   A. curPayload nil/kosong TIDAK pernah dianggap lolos verifikasi pada jalur
;;      reattach utama maupun jalur fallback.
;;   B. Seluruh pemanggilan dictremove (Step C, fn-reattach-cur Jalur 1 & 2,
;;      serta Step E read-back gagal) memeriksa return value secara eksplisit;
;;      tidak melanjutkan dictadd atau entdel apabila dictremove gagal, dan
;;      menampilkan pesan CRITICAL (UNDO Ctrl+Z) bila terjadi kegagalan.
(defun asgrid:meta-restore-xrecord (groupId snapshotData /
                                     rootDict parsedSnap snapErrs snapGid
                                     origPayload cloneFlag restData
                                     restEname curRec curEname curSnap
                                     remOk addOk readRec readEname readRaw readPayload
                                     remRestOk reattachStatus
                                     fn-get-header-280 fn-reattach-cur
                                   )
  ;; Ambil header flag 280 (rentang 0..5) tepat setelah (100 . "AcDbXrecord"), default 1
  (defun fn-get-header-280 (dxfList / seenMarker flag pair val)
    (setq seenMarker nil
          flag       1)
    (if (and dxfList (listp dxfList))
      (foreach pair dxfList
        (if (and (listp pair) (numberp (car pair)))
          (cond
            ((eq seenMarker 'DONE) nil)
            (seenMarker
             (setq val (cdr pair))
             (if (and (= (car pair) 280) (= (type val) 'INT) (>= val 0) (<= val 5))
               (setq flag val)
             )
             (setq seenMarker 'DONE))
            ((and (= (car pair) 100) (= (cdr pair) "AcDbXrecord"))
             (setq seenMarker T))
          )
        )
      )
    )
    flag
  )

  ;; Pulihkan entry dictionary kembali ke curEname / curSnap dengan verifikasi
  ;; payload ketat (curPayload wajib non-nil) & pengecekan eksplisit seluruh dictremove.
  ;; Hanya dipanggil bila curEname sebelumnya memang ada (non-nil).
  (defun fn-reattach-cur ( / ok canFallback curPayload
                             chkRec chkEname chkRaw chkPayload
                             remBackOk remFbOk fbData fbEname)
    (setq ok          nil
          canFallback T
          curPayload  (if curSnap (asgrid:meta-extract-raw-payload curSnap) nil))

    ;; Temuan A: Tolak jika curSnap tidak tersedia atau curPayload nil/kosong
    (if (or (null curSnap)
            (null curPayload)
            (not (listp curPayload))
            (= (length curPayload) 0))
      (progn
        (princ (strcat "\n[ASGRID META RESTORE CRITICAL] Payload snapshot curSnap untuk '"
                       groupId "' kosong/tidak dapat diekstrak; pemulihan entry sebelumnya tidak dapat diverifikasi. Jalankan UNDO (Ctrl+Z)."))
        nil
      )
      (progn
        ;; Jalur 1: Undelete (bila erased) & reattach curEname + verifikasi payload eksplisit
        (if curEname
          (progn
            (if (null (entget curEname))
              (entdel curEname)
            )
            (if (entget curEname)
              (if (dictadd rootDict groupId curEname)
                (progn
                  (setq chkRec     (dictsearch rootDict groupId)
                        chkEname   (if chkRec (cdr (assoc -1 chkRec)) nil)
                        chkRaw     (if chkEname (entget chkEname) nil)
                        chkPayload (if chkRaw (asgrid:meta-extract-raw-payload chkRaw) nil))
                  (if (and chkRec
                           chkRaw
                           (= (cdr (assoc 0 chkRaw)) "XRECORD")
                           chkPayload
                           (equal chkPayload curPayload (asgrid:tol)))
                    (setq ok T)
                    (progn
                      ;; Temuan B: Periksa hasil dictremove sebelum mencoba fallback
                      (setq remBackOk (not (null (dictremove rootDict groupId))))
                      (if (not remBackOk)
                        (progn
                          (setq canFallback nil)
                          (princ (strcat "\n[ASGRID META RESTORE CRITICAL] dictremove gagal saat membersihkan reattach tidak cocok untuk '"
                                         groupId "'; fallback dihentikan untuk mencegah korupsi dictionary. Jalankan UNDO (Ctrl+Z)."))
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )

        ;; Jalur 2 (Fallback): Bangun XRecord bersih dari curSnap + verifikasi payload eksplisit
        (if (and (not ok) canFallback curSnap)
          (progn
            (setq fbData
              (append
                (list
                  (cons 0 "XRECORD")
                  (cons 100 "AcDbXrecord")
                  (cons 280 (fn-get-header-280 curSnap))
                )
                curPayload
              )
            )
            (setq fbEname (entmakex fbData))
            (if (and fbEname (entget fbEname) (= (cdr (assoc 0 (entget fbEname))) "XRECORD"))
              (if (dictadd rootDict groupId fbEname)
                (progn
                  (setq chkRec     (dictsearch rootDict groupId)
                        chkEname   (if chkRec (cdr (assoc -1 chkRec)) nil)
                        chkRaw     (if chkEname (entget chkEname) nil)
                        chkPayload (if chkRaw (asgrid:meta-extract-raw-payload chkRaw) nil))
                  (if (and chkRec
                           chkRaw
                           (= (cdr (assoc 0 chkRaw)) "XRECORD")
                           chkPayload
                           (equal chkPayload curPayload (asgrid:tol)))
                    (setq ok T)
                    (progn
                      ;; Temuan B: Cek dictremove sebelum menghapus fbEname (cegah dangling entry)
                      (setq remFbOk (not (null (dictremove rootDict groupId))))
                      (if remFbOk
                        (if (entget fbEname) (entdel fbEname))
                        (princ (strcat "\n[ASGRID META RESTORE CRITICAL] dictremove gagal pada verifikasi fallback '"
                                       groupId "'; fbEname dipertahankan agar tidak meninggalkan dangling entry. Jalankan UNDO (Ctrl+Z)."))
                      )
                    )
                  )
                )
                (if (entget fbEname) (entdel fbEname))
              )
              (if (and fbEname (entget fbEname)) (entdel fbEname))
            )
          )
        )
        ok
      )
    )
  )

  ;; --------------------------------------------------------------------------
  ;; PRA-VALIDASI SNAPSHOT SEBELUM MENYENTUH DICTIONARY ATAU MEMBUAT ENTITAS
  ;; --------------------------------------------------------------------------
  (setq rootDict (asgrid:meta-get-root-dict nil))
  (cond
    ((or (null rootDict)
         (not (= (type groupId) 'STR))
         (= (strlen groupId) 0)
         (null snapshotData)
         (not (listp snapshotData)))
     (princ "\n[ASGRID META RESTORE ERROR] Parameter groupId/snapshot/rootDict tidak valid. Dictionary tidak disentuh.")
     nil)
    ((/= (cdr (assoc 0 snapshotData)) "XRECORD")
     (princ "\n[ASGRID META RESTORE ERROR] Snapshot bukan entitas DXF XRECORD. Dictionary tidak disentuh.")
     nil)
    ((null (member (cons 100 "AcDbXrecord") snapshotData))
     (princ "\n[ASGRID META RESTORE ERROR] Snapshot tidak memiliki subclass marker AcDbXrecord. Dictionary tidak disentuh.")
     nil)
    ((null (setq parsedSnap (asgrid:meta-parse-xrecord-dxf snapshotData)))
     (princ "\n[ASGRID META RESTORE ERROR] Snapshot XRecord gagal diparsing. Dictionary tidak disentuh.")
     nil)
    ((setq snapErrs (asgrid:meta-validate-spec parsedSnap))
     (princ (strcat "\n[ASGRID META RESTORE ERROR] Metadata snapshot tidak valid (" (car snapErrs) "). Dictionary tidak disentuh."))
     nil)
    ((/= (setq snapGid (cdr (assoc "GROUP_ID" parsedSnap))) groupId)
     (princ (strcat "\n[ASGRID META RESTORE ERROR] GROUP_ID snapshot ('"
                    (if (= (type snapGid) 'STR) snapGid "NIL")
                    "') tidak cocok dengan target '" groupId "'. Dictionary tidak disentuh."))
     nil)
    (t
     ;; A. Ekstrak payload mentah asli & header clone flag dari snapshot tervalidasi
     (setq origPayload (asgrid:meta-extract-raw-payload snapshotData)
           cloneFlag   (fn-get-header-280 snapshotData))
     (if (or (null origPayload) (not (listp origPayload)) (= (length origPayload) 0))
       (progn
         (princ (strcat "\n[ASGRID META RESTORE ERROR] Payload mentah snapshot '" groupId "' kosong. Dictionary tidak disentuh."))
         nil
       )
       (progn
         (setq restData (append
                          (list
                            (cons 0 "XRECORD")
                            (cons 100 "AcDbXrecord")
                            (cons 280 cloneFlag)
                          )
                          origPayload))

         ;; B. Buat XRecord pemulihan bersih SEBELUM melepas entry dictionary
         (setq restEname (entmakex restData))
         (if (or (null restEname)
                 (null (entget restEname))
                 (/= (cdr (assoc 0 (entget restEname))) "XRECORD"))
           (progn
             (if (and restEname (entget restEname)) (entdel restEname))
             (princ (strcat "\n[ASGRID META RESTORE ERROR] entmakex gagal membuat XRecord pemulihan untuk '" groupId "'."))
             nil
           )
           (progn
             ;; C. Ambil snapshot entry saat ini & lepas dari dictionary secara terverifikasi
             (setq curRec   (dictsearch rootDict groupId)
                   curEname (if curRec (cdr (assoc -1 curRec)) nil)
                   curSnap  (if (and curEname (entget curEname)) (entget curEname) nil)
                   remOk    T)
             (if curEname
               (setq remOk (not (null (dictremove rootDict groupId))))
             )
             (if (not remOk)
               (progn
                 (if (entget restEname) (entdel restEname))
                 (princ (strcat "\n[ASGRID META RESTORE ERROR] dictremove gagal melepas entry '" groupId "'; pemulihan dibatalkan."))
                 nil
               )
               (progn
                 ;; D. Pasang XRecord hasil pemulihan pada key groupId
                 (setq addOk (dictadd rootDict groupId restEname))
                 (if (null addOk)
                   (progn
                     (setq reattachStatus
                       (cond
                         ((null curEname)   'NO_PREV_ENTRY)
                         ((fn-reattach-cur) 'RESTORED)
                         (t                 'RESTORE_FAILED)
                       ))
                     (cond
                       ((eq reattachStatus 'RESTORED)
                        (if (entget restEname) (entdel restEname))
                        (princ (strcat "\n[ASGRID META RESTORE ERROR] dictadd gagal untuk '" groupId "'; entry sebelumnya berhasil dipulihkan dan terverifikasi.")))
                       ((eq reattachStatus 'NO_PREV_ENTRY)
                        (if (entget restEname) (entdel restEname))
                        (princ (strcat "\n[ASGRID META RESTORE ERROR] dictadd gagal untuk '" groupId "'; tidak ada entry sebelumnya di dictionary untuk dipulihkan.")))
                       (t
                        (princ (strcat "\n[ASGRID META RESTORE CRITICAL] dictadd gagal dan pemulihan entry sebelumnya untuk '" groupId "' GAGAL! Jalankan UNDO (Ctrl+Z) segera.")))
                     )
                     nil
                   )
                   (progn
                     ;; E. Verifikasi baca-balik ketat: key, entity type XRECORD, dan kesamaan payload mentah
                     (setq readRec     (dictsearch rootDict groupId)
                           readEname   (if readRec (cdr (assoc -1 readRec)) nil)
                           readRaw     (if readEname (entget readEname) nil)
                           readPayload (if readRaw (asgrid:meta-extract-raw-payload readRaw) nil))
                     (if (or (null readRec)
                             (null readRaw)
                             (/= (cdr (assoc 0 readRaw)) "XRECORD")
                             (null readPayload)
                             (not (equal readPayload origPayload (asgrid:tol))))
                       (progn
                         ;; Temuan B: Periksa hasil dictremove sebelum reattach / hapus restEname!
                         (setq remRestOk (not (null (dictremove rootDict groupId))))
                         (if (not remRestOk)
                           (progn
                             ;; Jangan lanjut reattach & jangan hapus restEname (cegah dangling entry)
                             (princ (strcat "\n[ASGRID META RESTORE CRITICAL] Verifikasi payload gagal dan dictremove terhadap XRecord baru '"
                                            groupId "' GAGAL! Entry dipertahankan; jalankan UNDO (Ctrl+Z) segera."))
                             nil
                           )
                           (progn
                             (setq reattachStatus
                               (cond
                                 ((null curEname)   'NO_PREV_ENTRY)
                                 ((fn-reattach-cur) 'RESTORED)
                                 (t                 'RESTORE_FAILED)
                               ))
                             (cond
                               ((eq reattachStatus 'RESTORED)
                                (if (entget restEname) (entdel restEname))
                                (princ (strcat "\n[ASGRID META RESTORE ERROR] Verifikasi payload pemulihan gagal untuk '" groupId "'; entry sebelumnya berhasil dipulihkan dan terverifikasi.")))
                               ((eq reattachStatus 'NO_PREV_ENTRY)
                                (if (entget restEname) (entdel restEname))
                                (princ (strcat "\n[ASGRID META RESTORE ERROR] Verifikasi payload pemulihan gagal untuk '" groupId "'; tidak ada entry sebelumnya untuk dipulihkan.")))
                               (t
                                (princ (strcat "\n[ASGRID META RESTORE CRITICAL] Verifikasi gagal dan pemulihan entry sebelumnya untuk '" groupId "' GAGAL! Jalankan UNDO (Ctrl+Z) segera.")))
                             )
                             nil
                           )
                         )
                       )
                       (progn
                         ;; F. Cleanup aman: hapus curEname hanya jika masih hidup (anti double-entdel)
                         (if (and curEname (not (equal curEname restEname)) (entget curEname))
                           (entdel curEname)
                         )
                         T
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
)

;; Perbarui XRecord grup eksisting di NOD menggunakan Replace-in-Dictionary
;; (entmakex -> dictremove -> dictadd -> read-back & deep-compare -> entdel lama)
;; TANPA entmod, mencegah bug append payload XRecord pada AutoCAD 2021.
;; Mengembalikan T hanya jika XRecord baru terpasang, terbaca balik, dan identik
;; dengan newSpec; jika gagal, memulihkan dictionary ke XRecord lama.
(defun asgrid:meta-update-group (groupId newSpec /
                                  rootDict oldRec oldXrecEname oldSnap
                                  newXrecData newXrecEname
                                  remRes addRes readBack readErrs cmpDiffs
                                  restoreOk fn-reattach-old
                                )
  ;; Helper lokal: pulihkan entry dictionary ke XRecord lama (mendukung kondisi
  ;; di mana dictremove menandai oldXrecEname sebagai erased di AutoCAD 2021)
  (defun fn-reattach-old ( / ok fallbackData fallbackEname)
    (setq ok nil)
    (if oldXrecEname
      (progn
        (if (null (entget oldXrecEname))
          (entdel oldXrecEname) ; undelete bila dictremove menandainya erased
        )
        (if (entget oldXrecEname)
          (setq ok (not (null (dictadd rootDict groupId oldXrecEname))))
        )
      )
    )
    ;; Fallback jika reattach oldXrecEname gagal: bangun ulang bersih dari oldSnap
    (if (and (not ok) oldSnap)
      (progn
        (setq fallbackData
          (append
            (list
              (cons 0 "XRECORD")
              (cons 100 "AcDbXrecord")
              (cons 280 (if (assoc 280 oldSnap) (cdr (assoc 280 oldSnap)) 1))
            )
            (asgrid:meta-extract-raw-payload oldSnap)
          )
        )
        (setq fallbackEname (entmakex fallbackData))
        (if (and fallbackEname (entget fallbackEname))
          (setq ok (not (null (dictadd rootDict groupId fallbackEname))))
        )
        (if (and (not ok) fallbackEname (entget fallbackEname))
          (entdel fallbackEname)
        )
      )
    )
    ok
  )
  (setq rootDict (asgrid:meta-get-root-dict nil))
  (cond
    ((or (null rootDict)
         (not (= (type groupId) 'STR))
         (= (strlen groupId) 0))
     (princ "
[ASGRID META UPDATE ERROR] Root dictionary ASGRID_GROUPS atau groupId tidak valid.")
     nil)
    ((null (setq oldRec (dictsearch rootDict groupId)))
     (princ (strcat "
[ASGRID META UPDATE ERROR] Entry '" groupId "' tidak ditemukan di ASGRID_GROUPS."))
     nil)
    (t
     (setq oldXrecEname (cdr (assoc -1 oldRec))
           oldSnap      (if oldXrecEname (entget oldXrecEname) nil))
     (if (or (null oldXrecEname) (null oldSnap))
       (progn
         (princ (strcat "
[ASGRID META UPDATE ERROR] XRecord lama untuk '" groupId "' tidak valid."))
         nil
       )
       (progn
         ;; 1. Buat XRecord baru bersih via entmakex SEBELUM menyentuh entry lama
         (setq newXrecData
           (append
             (list
               (cons 0 "XRECORD")
               (cons 100 "AcDbXrecord")
               (cons 280 1)
             )
             (asgrid:meta-build-xrecord-payload newSpec)
           )
         )
         (setq newXrecEname (entmakex newXrecData))
         (if (or (null newXrecEname)
                 (null (entget newXrecEname))
                 (/= (cdr (assoc 0 (entget newXrecEname))) "XRECORD"))
           (progn
             (if (and newXrecEname (entget newXrecEname)) (entdel newXrecEname))
             (princ (strcat "
[ASGRID META UPDATE ERROR] entmakex gagal membuat XRecord baru untuk '" groupId "'."))
             nil
           )
           (progn
             ;; 2. Lepas entry lama dari dictionary (XRecord lama masih hidup di database)
             (setq remRes (dictremove rootDict groupId))
             (if (null remRes)
               (progn
                 (if (entget newXrecEname) (entdel newXrecEname))
                 (princ (strcat "
[ASGRID META UPDATE ERROR] dictremove gagal melepas entry lama '" groupId "'."))
                 nil
               )
               (progn
                 ;; 3. Pasang XRecord baru pada key groupId yang sama
                 (setq addRes (dictadd rootDict groupId newXrecEname))
                 (if (null addRes)
                   (progn
                     ;; Pemulihan segera: pasang kembali oldXrecEname ke dictionary
                     (setq restoreOk (fn-reattach-old))
                     (if (entget newXrecEname) (entdel newXrecEname))
                     (if restoreOk
                       (princ (strcat "
[ASGRID META UPDATE ERROR] dictadd gagal untuk '" groupId "'; dictionary dipulihkan ke XRecord lama."))
                       (princ (strcat "
[ASGRID META UPDATE CRITICAL] dictadd gagal dan pemulihan '" groupId "' gagal! Jalankan UNDO (Ctrl+Z)."))
                     )
                     nil
                   )
                   (progn
                     ;; 4. Baca kembali & verifikasi penuh SEBELUM menghapus XRecord lama
                     (setq readBack (asgrid:meta-read-group groupId)
                           readErrs (if readBack
                                      (asgrid:meta-validate-spec readBack)
                                      '("XRecord baru gagal dibaca balik."))
                           cmpDiffs (if (and readBack (null readErrs))
                                      (asgrid:meta-compare-specs newSpec readBack)
                                      nil))
                     (if (or (null readBack) readErrs cmpDiffs)
                       (progn
                         ;; Verifikasi gagal: lepas XRecord baru & pasang ulang XRecord lama
                         (dictremove rootDict groupId)
                         (setq restoreOk (fn-reattach-old))
                         (if restoreOk
                           (progn
                             (if (entget newXrecEname) (entdel newXrecEname))
                             (princ (strcat "
[ASGRID META UPDATE ERROR] Verifikasi pasca-update gagal ("
                                            (cond (readErrs (car readErrs)) (cmpDiffs (car cmpDiffs)) (t "readBack nil"))
                                            "); dictionary dipulihkan ke XRecord lama."))
                           )
                           (princ (strcat "
[ASGRID META UPDATE CRITICAL] Verifikasi gagal dan pemulihan '" groupId "' ke XRecord lama gagal! Jalankan UNDO (Ctrl+Z)."))
                         )
                         nil
                       )
                       (progn
                         ;; 5. Seluruh verifikasi lolos: hapus XRecord lama agar tidak ada XRecord yatim
                         (if (and oldXrecEname (entget oldXrecEname))
                           (entdel oldXrecEname)
                         )
                         T
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
)

;; Hitung Expected Entity Counts eksak: (list expL expB expT expTotal)
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

;; Validasi integritas & konsistensi metadata (Schema 1.0 + opsional ANNO_EXT_LEN)
;; Grid lama tanpa ANNO_EXT_LEN tetap lulus 100%.
(defun asgrid:meta-validate-spec (spec / errs readErrs reqKeys k v nH nV dH dV cntH cntV bp elev sc th bd ex aExt bPos)
  (setq errs    '()
        reqKeys '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER"
                  "NUM_H" "NUM_V" "DIST_H" "DIST_V"
                  "DIST_H_COUNT" "DIST_V_COUNT"
                  "BASE_PT_WCS" "ELEVATION" "AXIS_DIR_H" "AXIS_DIR_V"
                  "SCALE_DENOM" "TEXT_H_PRINT" "BUBBLE_DIA_PRINT"
                  "EXT_LEN" "BUBBLE_POS" "TEXT_STYLE" "FONT_FILE"
                  "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT"))

  (if (not (listp spec))
    (setq errs (list "Struktur metadata bukan list valid."))
    (progn
      (setq readErrs (cdr (assoc "_READ_ERRORS" spec)))
      (if readErrs
        (setq errs (append errs readErrs))
      )
      (foreach k reqKeys
        (if (null (assoc k spec))
          (setq errs (append errs (list (strcat "Key metadata hilang: " k))))
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
        (if (or (not (= (type v) 'STR)) (= (strlen (asgrid:trim v)) 0))
          (setq errs (append errs (list (strcat "Nilai string tidak valid/kosong pada key: " k))))
        )
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
            (setq errs (append errs (list "Jumlah DIST_H tidak sama dengan NUM_H - 1.")))
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
            (setq errs (append errs (list "Jumlah DIST_V tidak sama dengan NUM_V - 1.")))
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
        (setq errs (append errs (list "ELEVATION harus berupa nilai numerik.")))
      )
      (if (or (not (listp bp))
              (/= (length bp) 3)
              (not (numberp (nth 0 bp)))
              (not (numberp (nth 1 bp)))
              (not (numberp (nth 2 bp))))
        (setq errs (append errs (list "BASE_PT_WCS harus berupa titik 3D numerik (X Y Z).")))
        (if (and (numberp elev) (not (equal (float (nth 2 bp)) (float elev) (asgrid:tol))))
          (setq errs (append errs (list (strcat "Nilai Z pada BASE_PT_WCS ("
                                                (rtos (nth 2 bp) 2 4)
                                                ") tidak konsisten dengan ELEVATION ("
                                                (rtos elev 2 4) ")."))))
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
      ;; Validasi opsional ANNO_EXT_LEN (hanya jika key hadir)
      (if (assoc "ANNO_EXT_LEN" spec)
        (progn
          (setq aExt (cdr (assoc "ANNO_EXT_LEN" spec)))
          (if (or (not (numberp aExt)) (<= aExt 0.0))
            (setq errs (append errs (list "ANNO_EXT_LEN (opsional) harus numerik > 0.")))
          )
        )
      )
      (if (not (member bPos (asgrid:valid-bubble-positions)))
        (setq errs (append errs (list "BUBBLE_POS tidak sesuai pilihan valid (Both Ends/Start/End).")))
      )
    )
  )
  errs
)

;; Bandingkan dua spec (expected vs readBack) termasuk ANNO_EXT_LEN (toleransi 1e-6)
(defun asgrid:meta-compare-specs (specA specB / diffs strKeys intKeys realKeys k vA vB dA dB i tol aExtA aExtB)
  (setq diffs    '()
        tol      (asgrid:tol)
        strKeys  '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER" "CREATED_AT"
                   "AXIS_DIR_H" "AXIS_DIR_V" "BUBBLE_POS" "TEXT_STYLE" "FONT_FILE"
                   "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT")
        intKeys  '("NUM_H" "NUM_V" "DIST_H_COUNT" "DIST_V_COUNT")
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
    (if (or (not (numberp vA)) (not (numberp vB)) (not (equal vA vB tol)))
      (setq diffs (append diffs (list (strcat "Mismatch real key " k))))
    )
  )
  ;; Bandingkan ANNO_EXT_LEN jika hadir di salah satu spec
  (if (or (assoc "ANNO_EXT_LEN" specA) (assoc "ANNO_EXT_LEN" specB))
    (progn
      (setq aExtA (asgrid:get-anno-ext-len specA)
            aExtB (asgrid:get-anno-ext-len specB))
      (if (or (not (numberp aExtA)) (not (numberp aExtB)) (not (equal aExtA aExtB tol)))
        (setq diffs (append diffs (list "Mismatch real key ANNO_EXT_LEN")))
      )
    )
  )
  (if (not (equal (cdr (assoc "BASE_PT_WCS" specA))
                  (cdr (assoc "BASE_PT_WCS" specB))
                  tol))
    (setq diffs (append diffs (list "Mismatch point key BASE_PT_WCS")))
  )
  (setq dA (cdr (assoc "DIST_H" specA))
        dB (cdr (assoc "DIST_H" specB)))
  (if (/= (length dA) (length dB))
    (setq diffs (append diffs (list "Mismatch panjang DIST_H")))
    (progn
      (setq i 0)
      (while (< i (length dA))
        (if (not (equal (nth i dA) (nth i dB) tol))
          (setq diffs (append diffs (list (strcat "Mismatch DIST_H indeks " (itoa i)))))
        )
        (setq i (1+ i))
      )
    )
  )
  (setq dA (cdr (assoc "DIST_V" specA))
        dB (cdr (assoc "DIST_V" specB)))
  (if (/= (length dA) (length dB))
    (setq diffs (append diffs (list "Mismatch panjang DIST_V")))
    (progn
      (setq i 0)
      (while (< i (length dA))
        (if (not (equal (nth i dA) (nth i dB) tol))
          (setq diffs (append diffs (list (strcat "Mismatch DIST_V indeks " (itoa i)))))
        )
        (setq i (1+ i))
      )
    )
  )
  diffs
)


;;; ============================================================================
;;; SECTION 4: SHARED ANNOTATION ENGINE SERVICE (DECOUPLED & STATELESS)
;;; ============================================================================

;; Primitif CIRCLE via entmakex -> mengembalikan ename atau nil (tanpa mutasi state luar)
(defun asgrid:draw-circle (cpt rad layName xdata)
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

;; Primitif TEXT (Middle Center) via entmakex -> mengembalikan ename atau nil
(defun asgrid:draw-text-mc (cpt txtH txtStr layName styleName xdata)
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

;; SHARED ANNOTATION ENGINE:
;; Membaca spec (menggunakan ANNO_EXT_LEN dengan fallback ke EXT_LEN).
;; Mengembalikan: (list createdEnames cntBubble cntText)
;; Catatan: Urutan & geometri identik 100% dengan V2.1.2.
(defun asgrid:annotation-engine (spec /
                                  groupId xdataApp schemaVer basePt x0 y0 z0
                                  dH dV annoExt sc thP bdP bPos
                                  txtStyle layBub layTxt
                                  textHModel bubRadModel
                                  drawStart drawEnd
                                  cumY cumX totalY totalX
                                  i curY curX lbl c1 c2 e
                                  createdEnts cntBubble cntText
                                )
  (setq groupId     (cdr (assoc "GROUP_ID" spec))
        xdataApp    (if (cdr (assoc "_XDATA_APP_OVERRIDE" spec))
                      (cdr (assoc "_XDATA_APP_OVERRIDE" spec))
                      (asgrid:xdata-app))
        schemaVer   (if (cdr (assoc "SCHEMA_VER" spec)) (cdr (assoc "SCHEMA_VER" spec)) (asgrid:schema-ver))
        basePt      (cdr (assoc "BASE_PT_WCS" spec))
        x0          (car basePt)
        y0          (cadr basePt)
        z0          (caddr basePt)
        dH          (cdr (assoc "DIST_H" spec))
        dV          (cdr (assoc "DIST_V" spec))
        annoExt     (asgrid:get-anno-ext-len spec)
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
        cumY        (asgrid:compute-cumulative y0 dH)
        cumX        (asgrid:compute-cumulative x0 dV)
        totalY      (- (last cumY) y0)
        totalX      (- (last cumX) x0)
        createdEnts '()
        cntBubble   0
        cntText     0)

  ;; Anotasi sumbu horizontal (1, 2, 3, ...)
  (setq i 1)
  (foreach curY cumY
    (setq lbl (itoa i))
    (if drawStart
      (progn
        (setq c1 (list (- x0 annoExt bubRadModel) curY z0))
        (setq e (asgrid:draw-circle c1 bubRadModel layBub
                  (asgrid:make-obj-xdata-for-app xdataApp groupId "BUBBLE" "H" i "START" schemaVer)))
        (if e (setq createdEnts (cons e createdEnts) cntBubble (1+ cntBubble)))
        (setq e (asgrid:draw-text-mc c1 textHModel lbl layTxt txtStyle
                  (asgrid:make-obj-xdata-for-app xdataApp groupId "TEXT" "H" i "START" schemaVer)))
        (if e (setq createdEnts (cons e createdEnts) cntText (1+ cntText)))
      )
    )
    (if drawEnd
      (progn
        (setq c2 (list (+ x0 totalX annoExt bubRadModel) curY z0))
        (setq e (asgrid:draw-circle c2 bubRadModel layBub
                  (asgrid:make-obj-xdata-for-app xdataApp groupId "BUBBLE" "H" i "END" schemaVer)))
        (if e (setq createdEnts (cons e createdEnts) cntBubble (1+ cntBubble)))
        (setq e (asgrid:draw-text-mc c2 textHModel lbl layTxt txtStyle
                  (asgrid:make-obj-xdata-for-app xdataApp groupId "TEXT" "H" i "END" schemaVer)))
        (if e (setq createdEnts (cons e createdEnts) cntText (1+ cntText)))
      )
    )
    (setq i (1+ i))
  )

  ;; Anotasi sumbu vertikal (A, B, C, ..., AA, AB)
  (setq i 1)
  (foreach curX cumX
    (setq lbl (asgrid:index-to-alpha i))
    (if drawStart
      (progn
        (setq c1 (list curX (- y0 annoExt bubRadModel) z0))
        (setq e (asgrid:draw-circle c1 bubRadModel layBub
                  (asgrid:make-obj-xdata-for-app xdataApp groupId "BUBBLE" "V" i "START" schemaVer)))
        (if e (setq createdEnts (cons e createdEnts) cntBubble (1+ cntBubble)))
        (setq e (asgrid:draw-text-mc c1 textHModel lbl layTxt txtStyle
                  (asgrid:make-obj-xdata-for-app xdataApp groupId "TEXT" "V" i "START" schemaVer)))
        (if e (setq createdEnts (cons e createdEnts) cntText (1+ cntText)))
      )
    )
    (if drawEnd
      (progn
        (setq c2 (list curX (+ y0 totalY annoExt bubRadModel) z0))
        (setq e (asgrid:draw-circle c2 bubRadModel layBub
                  (asgrid:make-obj-xdata-for-app xdataApp groupId "BUBBLE" "V" i "END" schemaVer)))
        (if e (setq createdEnts (cons e createdEnts) cntBubble (1+ cntBubble)))
        (setq e (asgrid:draw-text-mc c2 textHModel lbl layTxt txtStyle
                  (asgrid:make-obj-xdata-for-app xdataApp groupId "TEXT" "V" i "END" schemaVer)))
        (if e (setq createdEnts (cons e createdEnts) cntText (1+ cntText)))
      )
    )
    (setq i (1+ i))
  )

  (list createdEnts cntBubble cntText)
)


;;; ============================================================================
;;; SECTION 5: SHARED LIVE PREVIEW SERVICE (MENDUKUNG geomExtLen & annoExtLen)
;;; ============================================================================

(defun asgrid:prev-draw-circle (cx cy rad col / segs k a1 a2 x1 y1 x2 y2 step)
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

(defun asgrid:prev-draw-char (ch x0 y0 sx sy col / segs seg)
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

(defun asgrid:prev-draw-string (txt cx cy hPx col / len sx sy charW gap totalW startX startY i)
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
        (asgrid:prev-draw-char
          (substr txt i 1)
          (+ startX (* (1- i) (+ charW gap)))
          startY sx sy col
        )
        (setq i (1+ i))
      )
    )
  )
)

;; SHARED LIVE PREVIEW RENDERER:
;; Menerima geomExtLen (panjang garis) dan annoExtLen (offset bubble/teks) terpisah.
;; Mengembalikan: (list numH numV totalX totalY denseMode)
(defun asgrid:prev-render-grid (imgKey dH dV geomExtLen annoExtLen sc th bd bPos /
                                 w h pad
                                 cumY cumX totalY totalX
                                 bubRadModel drawStart drawEnd
                                 maxExtStart maxExtEnd
                                 minX maxX minY maxY
                                 spanX spanY scalePx offX offY
                                 bubRadPx txtHPx
                                 stepH stepV denseMode
                                 i curY curX
                                 gx1 gx2 gy1 gy2 ax1 ax2 ay1 ay2
                                 py1 px1 bx by lbl
                               )
  (setq w           (dimx_tile imgKey)
        h           (dimy_tile imgKey)
        pad         14
        cumY        (asgrid:compute-cumulative 0.0 dH)
        cumX        (asgrid:compute-cumulative 0.0 dV)
        totalY      (last cumY)
        totalX      (last cumX)
        bubRadModel (/ (* bd sc) 2.0)
        drawStart   (or (= bPos "Both Ends") (= bPos "Start"))
        drawEnd     (or (= bPos "Both Ends") (= bPos "End"))
        maxExtStart (max geomExtLen (if drawStart (+ annoExtLen (* 2.0 bubRadModel)) 0.0))
        maxExtEnd   (max geomExtLen (if drawEnd   (+ annoExtLen (* 2.0 bubRadModel)) 0.0))
        minX        (- 0.0 maxExtStart)
        maxX        (+ totalX maxExtEnd)
        minY        (- 0.0 maxExtStart)
        maxY        (+ totalY maxExtEnd)
        spanX       (max 1.0 (- maxX minX))
        spanY       (max 1.0 (- maxY minY))
        scalePx     (min (/ (float (- w (* 2 pad))) spanX)
                         (/ (float (- h (* 2 pad))) spanY))
        offX        (/ (- (float w) (* spanX scalePx)) 2.0)
        offY        (/ (- (float h) (* spanY scalePx)) 2.0)
        bubRadPx    (max 3.0 (min 11.0 (* bubRadModel scalePx)))
        txtHPx      (max 4.0 (min (* bubRadPx 1.2) (* th sc scalePx)))
        stepH       (if (> (length cumY) 10) (max 1 (/ (length cumY) 6)) 1)
        stepV       (if (> (length cumX) 10) (max 1 (/ (length cumX) 6)) 1)
        denseMode   (or (> stepH 1) (> stepV 1)))

  (start_image imgKey)
  (fill_image 0 0 w h 0)

  (vector_image 0 0 (1- w) 0 8)
  (vector_image (1- w) 0 (1- w) (1- h) 8)
  (vector_image (1- w) (1- h) 0 (1- h) 8)
  (vector_image 0 (1- h) 0 0 8)

  ;; 1. Sumbu Horizontal (garis memakai geomExtLen; bubble memakai annoExtLen)
  (setq gx1 (fix (+ offX (* (- (- 0.0 geomExtLen) minX) scalePx) 0.5))
        gx2 (fix (+ offX (* (- (+ totalX geomExtLen) minX) scalePx) 0.5))
        ax1 (fix (+ offX (* (- (- 0.0 annoExtLen) minX) scalePx) 0.5))
        ax2 (fix (+ offX (* (- (+ totalX annoExtLen) minX) scalePx) 0.5))
        i   1)
  (foreach curY cumY
    (setq py1 (fix (- (1- h) (+ offY (* (- curY minY) scalePx)) 0.5))
          lbl (itoa i))
    (vector_image gx1 py1 gx2 py1 9)
    (if (or (= stepH 1) (= i 1) (= i (length cumY)) (= (rem (1- i) stepH) 0))
      (progn
        (if drawStart
          (progn
            (setq bx (fix (- ax1 bubRadPx 0.5)))
            (asgrid:prev-draw-circle bx py1 bubRadPx 2)
            (if (>= bubRadPx 5.0)
              (asgrid:prev-draw-string lbl bx py1 txtHPx 7)
            )
          )
        )
        (if drawEnd
          (progn
            (setq bx (fix (+ ax2 bubRadPx 0.5)))
            (asgrid:prev-draw-circle bx py1 bubRadPx 2)
            (if (>= bubRadPx 5.0)
              (asgrid:prev-draw-string lbl bx py1 txtHPx 7)
            )
          )
        )
      )
    )
    (setq i (1+ i))
  )

  ;; 2. Sumbu Vertikal (garis memakai geomExtLen; bubble memakai annoExtLen)
  (setq gy1 (fix (- (1- h) (+ offY (* (- (- 0.0 geomExtLen) minY) scalePx)) 0.5))
        gy2 (fix (- (1- h) (+ offY (* (- (+ totalY geomExtLen) minY) scalePx)) 0.5))
        ay1 (fix (- (1- h) (+ offY (* (- (- 0.0 annoExtLen) minY) scalePx)) 0.5))
        ay2 (fix (- (1- h) (+ offY (* (- (+ totalY annoExtLen) minY) scalePx)) 0.5))
        i   1)
  (foreach curX cumX
    (setq px1 (fix (+ offX (* (- curX minX) scalePx) 0.5))
          lbl (asgrid:index-to-alpha i))
    (vector_image px1 gy1 px1 gy2 9)
    (if (or (= stepV 1) (= i 1) (= i (length cumX)) (= (rem (1- i) stepV) 0))
      (progn
        (if drawStart
          (progn
            (setq by (fix (+ ay1 bubRadPx 0.5)))
            (asgrid:prev-draw-circle px1 by bubRadPx 2)
            (if (>= bubRadPx 5.0)
              (asgrid:prev-draw-string lbl px1 by txtHPx 7)
            )
          )
        )
        (if drawEnd
          (progn
            (setq by (fix (- ay2 bubRadPx 0.5)))
            (asgrid:prev-draw-circle px1 by bubRadPx 2)
            (if (>= bubRadPx 5.0)
              (asgrid:prev-draw-string lbl px1 by txtHPx 7)
            )
          )
        )
      )
    )
    (setq i (1+ i))
  )

  (end_image)
  (list (length cumY) (length cumX) totalX totalY denseMode)
)


;;; ============================================================================
;;; SECTION 6: SHARED GROUP AUDIT SERVICE (100% READ-ONLY)
;;; Dipakai bersama oleh ASGRIDCHECK (dan ASGRIDEDIT pada Phase 2).
;;; Keterbatasan: ssget "_X" hanya memindai entitas top-level (bukan BLOCK).
;;; ============================================================================

(defun asgrid:audit-group-entities (groupId spec /
                                     nH nV bPos expCounts expL expB expT expTot
                                     ss i ename entData dxfType parsed
                                     gid role axisDir axisIdx endTag
                                     lineEnts bubbleEnts textEnts annoEnts
                                     dxfMismatchCnt idxInvalidCnt endTagInvalidCnt
                                     corruptXdataCnt seenSlots dupSlots
                                     expectedDxf endTagOk slotKey
                                     actL actB actT actTot isHealthy
                                   )
  (setq nH               (cdr (assoc "NUM_H" spec))
        nV               (cdr (assoc "NUM_V" spec))
        bPos             (cdr (assoc "BUBBLE_POS" spec))
        expCounts        (asgrid:calc-expected-counts spec)
        expL             (nth 0 expCounts)
        expB             (nth 1 expCounts)
        expT             (nth 2 expCounts)
        expTot           (nth 3 expCounts)
        lineEnts         '()
        bubbleEnts       '()
        textEnts         '()
        annoEnts         '()
        dxfMismatchCnt   0
        idxInvalidCnt    0
        endTagInvalidCnt 0
        corruptXdataCnt  0
        seenSlots        '()
        dupSlots         '())

  (setq ss (ssget "_X" (list (list -3 (list (asgrid:xdata-app))))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename   (ssname ss i)
              entData (entget ename)
              dxfType (if entData (cdr (assoc 0 entData)) "UNKNOWN")
              parsed  (asgrid:parse-entity-xdata ename))
        (if (null parsed)
          (setq corruptXdataCnt (1+ corruptXdataCnt))
          (if (= (nth 0 parsed) groupId)
            (progn
              (setq gid     (nth 0 parsed)
                    role    (nth 1 parsed)
                    axisDir (nth 2 parsed)
                    axisIdx (nth 3 parsed)
                    endTag  (nth 4 parsed))

              (cond
                ((= role "LINE")
                 (setq lineEnts (cons ename lineEnts)))
                ((= role "BUBBLE")
                 (setq bubbleEnts (cons ename bubbleEnts)
                       annoEnts   (cons ename annoEnts)))
                ((= role "TEXT")
                 (setq textEnts (cons ename textEnts)
                       annoEnts (cons ename annoEnts)))
              )

              ;; Cek 1: DXF type vs Role
              (setq expectedDxf
                (cond
                  ((= role "LINE")   "LINE")
                  ((= role "BUBBLE") "CIRCLE")
                  ((= role "TEXT")   "TEXT")
                  (t                 "")))
              (if (/= dxfType expectedDxf)
                (setq dxfMismatchCnt (1+ dxfMismatchCnt))
              )

              ;; Cek 2: AxisIdx dalam rentang NUM_H / NUM_V
              (if (or (and (= axisDir "H") (or (< axisIdx 1) (> axisIdx nH)))
                      (and (= axisDir "V") (or (< axisIdx 1) (> axisIdx nV))))
                (setq idxInvalidCnt (1+ idxInvalidCnt))
              )

              ;; Cek 3: EndTag sesuai Role & BUBBLE_POS
              (setq endTagOk
                (cond
                  ((= role "LINE")
                   (= endTag "NONE"))
                  ((or (= role "BUBBLE") (= role "TEXT"))
                   (cond
                     ((= bPos "Both Ends") (or (= endTag "START") (= endTag "END")))
                     ((= bPos "Start")     (= endTag "START"))
                     ((= bPos "End")       (= endTag "END"))
                     (t                    nil)))
                  (t nil)))
              (if (not endTagOk)
                (setq endTagInvalidCnt (1+ endTagInvalidCnt))
              )

              ;; Cek 4: Duplikasi slot (Role|AxisDir|AxisIdx|EndTag)
              (setq slotKey (strcat role "|" axisDir "|" (itoa axisIdx) "|" endTag))
              (if (member slotKey seenSlots)
                (if (not (member slotKey dupSlots))
                  (setq dupSlots (append dupSlots (list slotKey)))
                )
                (setq seenSlots (cons slotKey seenSlots))
              )
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )

  (setq actL      (length lineEnts)
        actB      (length bubbleEnts)
        actT      (length textEnts)
        actTot    (+ actL actB actT)
        isHealthy (and (= actL expL)
                       (= actB expB)
                       (= actT expT)
                       (= dxfMismatchCnt 0)
                       (= idxInvalidCnt 0)
                       (= endTagInvalidCnt 0)
                       (null dupSlots)))

  (list
    (cons "LINE_ENTS"      lineEnts)
    (cons "BUBBLE_ENTS"    bubbleEnts)
    (cons "TEXT_ENTS"      textEnts)
    (cons "ANNO_ENTS"      annoEnts)
    (cons "ACT_L"          actL)
    (cons "ACT_B"          actB)
    (cons "ACT_T"          actT)
    (cons "ACT_TOT"        actTot)
    (cons "EXP_L"          expL)
    (cons "EXP_B"          expB)
    (cons "EXP_T"          expT)
    (cons "EXP_TOT"        expTot)
    (cons "DXF_MISMATCH"   dxfMismatchCnt)
    (cons "IDX_INVALID"    idxInvalidCnt)
    (cons "ENDTAG_INVALID" endTagInvalidCnt)
    (cons "DUP_SLOTS"      dupSlots)
    (cons "CORRUPT_XDATA"  corruptXdataCnt)
    (cons "IS_HEALTHY"     isHealthy)
  )
)


;;; ============================================================================
;;; PERINTAH UTAMA: ASGRID (V2.2 PHASE 1 - MENGGUNAKAN SHARED SERVICES)
;;; ============================================================================

(defun c:ASGRID ( /
                  ;; Error handler & state transaksi
                  *error* oldCmdEcho undoOpen dclId
                  txActive txSavedGroupId txSavedXrec txCreatedEnts txAbortedByCode
                  ;; Konstanta konfigurasi & metadata
                  PAGE_SIZE STYLE_NAME FONT_FILE BUB_POS_LIST
                  DEF_SPACING_H DEF_SPACING_V
                  APP_NAME APP_VER VER_LABEL SCHEMA_VER
                  DICT_NAME XDATA_APP
                  LAY_GRID LAY_BUBBLE LAY_TEXT
                  ;; Helper lokal khusus c:ASGRID
                  fn-replace-nth
                  fn-resize-str-list
                  fn-pad-4
                  fn-ensure-linetype-center
                  fn-ensure-layer
                  fn-meta-generate-next-id
                  fn-meta-build-spec
                  fn-meta-save-group
                  fn-rollback-transaction
                  fn-verify-tx-entities
                  fn-draw-line
                  fn-geometry-engine
                  fn-execute-grid-creation
                  fn-update-live-preview
                  fn-refresh-h-table
                  fn-refresh-v-table
                  fn-update-scale-preview
                  fn-sync-grid-counts
                  fn-save-h-slot
                  fn-save-v-slot
                  fn-flush-active-page
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
        DEF_SPACING_H   "4000"
        DEF_SPACING_V   "5000"
        APP_NAME        "ASGRID"
        APP_VER         "2.2"
        VER_LABEL       "ASGRID V2.2"
        SCHEMA_VER      (asgrid:schema-ver)
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

  ;; --------------------------------------------------------------------------
  ;; MODUL 1: ERROR HANDLER LOKAL DENGAN TRANSACTION ROLLBACK TERISOLASI
  ;; --------------------------------------------------------------------------
  (defun *error* (msg / isUserCancel)
    (if (and dclId (>= dclId 0))
      (progn
        (unload_dialog dclId)
        (setq dclId nil)
      )
    )
    (if txActive
      (fn-rollback-transaction "Error/Interupsi saat transaksi aktif")
    )
    (if undoOpen
      (progn
        (setvar "CMDECHO" 0)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
      )
    )
    (if oldCmdEcho
      (setvar "CMDECHO" oldCmdEcho)
    )
    (setq isUserCancel (member msg '("Function cancelled"
                                     "quit / exit abort"
                                     "console break")))
    (cond
      (txAbortedByCode
       (princ (strcat "\n[" VER_LABEL "] Proses dihentikan secara aman dengan rollback penuh.")))
      ((and msg (not isUserCancel))
       (princ (strcat "\n[" VER_LABEL " PROGRAM ERROR] " msg
                      "\n  Seluruh perubahan transaksi telah di-rollback. Grup lain tidak terpengaruh.")))
      (t
       (princ (strcat "\n[" VER_LABEL "] Proses dibatalkan oleh pengguna. Tidak ada entitas/metadata parsial.")))
    )
    (princ)
  )

  ;; --------------------------------------------------------------------------
  ;; MODUL 2: UTILITAS LOKAL KHUSUS GENERATOR
  ;; --------------------------------------------------------------------------
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

  ;; --------------------------------------------------------------------------
  ;; MODUL 3: LINETYPE & LAYER (UTUH DARI V2.1.2)
  ;; --------------------------------------------------------------------------
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

  ;; --------------------------------------------------------------------------
  ;; MODUL 4: METADATA BUILDER, SAVE, ROLLBACK & TRANSACTION VERIFIER
  ;; --------------------------------------------------------------------------
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

  ;; V2.2: Menyimpan EXT_LEN dan ANNO_EXT_LEN dengan nilai awal yang sama
  (defun fn-meta-build-spec (groupId ptWcs / zVal)
    (setq zVal (if (and (caddr ptWcs) (numberp (caddr ptWcs)))
                 (float (caddr ptWcs))
                 0.0))
    (list
      (cons "SCHEMA_VER"       SCHEMA_VER)
      (cons "GROUP_ID"         groupId)
      (cons "MODULE"           APP_NAME)
      (cons "GENERATOR_VER"    APP_VER)
      (cons "CREATED_AT"       (asgrid:get-timestamp))
      (cons "NUM_H"            numH)
      (cons "NUM_V"            numV)
      (cons "DIST_H_COUNT"     (length distListH))
      (cons "DIST_V_COUNT"     (length distListV))
      (cons "DIST_H"           distListH)
      (cons "DIST_V"           distListV)
      (cons "BASE_PT_WCS"      (list (float (car ptWcs))
                                     (float (cadr ptWcs))
                                     zVal))
      (cons "ELEVATION"        zVal)
      (cons "AXIS_DIR_H"       "X")
      (cons "AXIS_DIR_V"       "Y")
      (cons "SCALE_DENOM"      scaleDenom)
      (cons "TEXT_H_PRINT"     textHPrint)
      (cons "BUBBLE_DIA_PRINT" bubbleDiaPrint)
      (cons "EXT_LEN"          extLen)
      (cons "ANNO_EXT_LEN"     extLen)
      (cons "BUBBLE_POS"       bubblePos)
      (cons "TEXT_STYLE"       STYLE_NAME)
      (cons "FONT_FILE"        FONT_FILE)
      (cons "LAYER_GRID"       LAY_GRID)
      (cons "LAYER_BUBBLE"     LAY_BUBBLE)
      (cons "LAYER_TEXT"       LAY_TEXT)
    )
  )

  (defun fn-meta-save-group (spec / rootDict groupId xrecData xrecEname)
    (setq groupId  (cdr (assoc "GROUP_ID" spec))
          rootDict (asgrid:meta-get-root-dict T))
    (cond
      ((null rootDict)
       (princ (strcat "\n[" VER_LABEL " ERROR] Gagal membuat/mengakses Named Object Dictionary ASGRID_GROUPS."))
       nil)
      ((or (dictsearch rootDict groupId)
           (member groupId (asgrid:meta-list-all-ids)))
       (princ (strcat "\n[" VER_LABEL " ERROR] Group ID '" groupId "' sudah terpakai; duplikasi dicegah."))
       nil)
      (t
       (setq xrecData
         (append
           (list
             (cons 0 "XRECORD")
             (cons 100 "AcDbXrecord")
             (cons 280 1)
           )
           (asgrid:meta-build-xrecord-payload spec)
         )
       )
       (setq xrecEname (entmakex xrecData))
       (if xrecEname
         (if (dictadd rootDict groupId xrecEname)
           xrecEname
           (progn
             (entdel xrecEname)
             nil
           )
         )
         nil
       ))
    )
  )

  (defun fn-rollback-transaction (reason / e rootDict delCnt)
    (setq delCnt 0)
    (foreach e txCreatedEnts
      (if (and e (entget e))
        (progn
          (entdel e)
          (setq delCnt (1+ delCnt))
        )
      )
    )
    (setq txCreatedEnts '())

    (if txSavedGroupId
      (progn
        (setq rootDict (asgrid:meta-get-root-dict nil))
        (if (and rootDict (dictsearch rootDict txSavedGroupId))
          (dictremove rootDict txSavedGroupId)
        )
        (if (and txSavedXrec (entget txSavedXrec))
          (entdel txSavedXrec)
        )
        (princ (strcat "\n[" VER_LABEL " ROLLBACK] Metadata '" txSavedGroupId
                       "' dihapus dan " (itoa delCnt) " entitas parsial dibersihkan (" reason ")."))
      )
      (if (> delCnt 0)
        (princ (strcat "\n[" VER_LABEL " ROLLBACK] " (itoa delCnt)
                       " entitas parsial dibersihkan (" reason ")."))
      )
    )
    (setq txSavedGroupId nil
          txSavedXrec    nil
          txActive       nil)
  )

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

  ;; --------------------------------------------------------------------------
  ;; MODUL 5: GEOMETRY ENGINE & KOORDINATOR TRANSAKSI GENERATOR
  ;; --------------------------------------------------------------------------
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
          cumY    (asgrid:compute-cumulative y0 dH)
          cumX    (asgrid:compute-cumulative x0 dV)
          totalY  (- (last cumY) y0)
          totalX  (- (last cumX) x0)
          cntLine 0)

    (setq i 1)
    (foreach curY cumY
      (setq pStart (list (- x0 ext) curY z0)
            pEnd   (list (+ x0 totalX ext) curY z0))
      (if (fn-draw-line pStart pEnd layGrid
                        (asgrid:make-obj-xdata groupId "LINE" "H" i "NONE" SCHEMA_VER))
        (setq cntLine (1+ cntLine))
      )
      (setq i (1+ i))
    )

    (setq i 1)
    (foreach curX cumX
      (setq pStart (list curX (- y0 ext) z0)
            pEnd   (list curX (+ y0 totalY ext) z0))
      (if (fn-draw-line pStart pEnd layGrid
                        (asgrid:make-obj-xdata groupId "LINE" "V" i "NONE" SCHEMA_VER))
        (setq cntLine (1+ cntLine))
      )
      (setq i (1+ i))
    )

    cntLine
  )

  (defun fn-execute-grid-creation (ptWcs /
                                    groupId spec metaErrs savedXrec
                                    readBack readErrs cmpDiffs
                                    expCounts expL expB expT expTotal
                                    cntLine annRes annoEnts cntBubble cntText
                                    verRes verOk vL vB vT verErr
                                    cumY cumX totalY totalX x0 y0 z0
                                    textHModel bubDiaModel abortMsg
                                  )
    (asgrid:check-insunits-warning VER_LABEL)
    (princ (strcat "\n[" VER_LABEL "] Memulai transaksi pembuatan grid & verifikasi metadata..."))
    (setvar "CMDECHO" 0)
    (command "_.UNDO" "_Begin")
    (setq undoOpen        T
          txActive        T
          txSavedGroupId  nil
          txSavedXrec     nil
          txCreatedEnts   '()
          txAbortedByCode nil)

    ;; 1. Pre-check: Text Style Arial wajib tersedia
    (if (not (asgrid:ensure-arial-style STYLE_NAME FONT_FILE VER_LABEL))
      (progn
        (setq txActive nil txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (exit)
      )
    )

    ;; 2. Pre-check: Pastikan RegApp XData terdaftar di tabel APPID
    ;;    (regapp mengembalikan nil bila APPID sudah terdaftar; verifikasi via tblsearch)
    (if (not (tblsearch "APPID" XDATA_APP))
      (progn
        (regapp XDATA_APP)
        (if (not (tblsearch "APPID" XDATA_APP))
          (progn
            (setq txActive nil txAbortedByCode T)
            (command "_.UNDO" "_End")
            (setq undoOpen nil)
            (setvar "CMDECHO" oldCmdEcho)
            (alert (strcat "Gagal mendaftarkan XData Application '" XDATA_APP "'. Proses dibatalkan."))
            (exit)
          )
        )
      )
    )

    ;; 3. Pre-check: Linetype & Layers (shared resources)
    (if (not (fn-ensure-linetype-center))
      (princ "\n  [Peringatan] Linetype CENTER gagal dimuat; layer AS-GRID akan memakai CONTINUOUS.")
    )
    (fn-ensure-layer LAY_GRID   "CENTER"     8)
    (fn-ensure-layer LAY_BUBBLE "CONTINUOUS" 2)
    (fn-ensure-layer LAY_TEXT   "CONTINUOUS" 7)

    ;; 4. Bangun Group ID unik & validasi integritas spec pra-tulis
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

    ;; 6. HARD GATE B: Baca ulang XRecord, validasi konsistensi & deep-compare
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

    ;; 7. Hitung Expected Entity Counts eksak dari readBack
    (setq expCounts (asgrid:calc-expected-counts readBack)
          expL      (nth 0 expCounts)
          expB      (nth 1 expCounts)
          expT      (nth 2 expCounts)
          expTotal  (nth 3 expCounts))

    ;; 8. Geometry Engine
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

    ;; 9. Shared Annotation Engine (mencatat seluruh ename baru ke txCreatedEnts)
    (setq annRes        (asgrid:annotation-engine readBack)
          annoEnts      (nth 0 annRes)
          cntBubble     (nth 1 annRes)
          cntText       (nth 2 annRes)
          txCreatedEnts (append annoEnts txCreatedEnts))
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

    ;; 11. COMMIT TRANSAKSI
    (setq txActive       nil
          txSavedGroupId nil
          txSavedXrec    nil
          txCreatedEnts  '())
    (command "_.UNDO" "_End")
    (setq undoOpen nil)
    (setvar "CMDECHO" oldCmdEcho)

    ;; 12. Ringkasan hasil
    (setq x0          (car (cdr (assoc "BASE_PT_WCS" readBack)))
          y0          (cadr (cdr (assoc "BASE_PT_WCS" readBack)))
          z0          (caddr (cdr (assoc "BASE_PT_WCS" readBack)))
          cumY        (asgrid:compute-cumulative y0 (cdr (assoc "DIST_H" readBack)))
          cumX        (asgrid:compute-cumulative x0 (cdr (assoc "DIST_V" readBack)))
          totalY      (- (last cumY) y0)
          totalX      (- (last cumX) x0)
          textHModel  (* (cdr (assoc "TEXT_H_PRINT" readBack)) (cdr (assoc "SCALE_DENOM" readBack)))
          bubDiaModel (* (cdr (assoc "BUBBLE_DIA_PRINT" readBack)) (cdr (assoc "SCALE_DENOM" readBack))))

    (princ "\n------------------------------------------------------------")
    (princ (strcat "\n[" VER_LABEL "] SELESAI - TRANSAKSI TERVERIFIKASI PENUH"))
    (princ "\n------------------------------------------------------------")
    (princ (strcat "\n  Group ID (DWG Meta)  : " groupId " (NOD: " DICT_NAME " | XData: " XDATA_APP ")"))
    (princ (strcat "\n  Titik awal (WCS)     : (" (rtos x0 2 2) ", " (rtos y0 2 2) ", " (rtos z0 2 2) ") mm"))
    (princ (strcat "\n  Jumlah grid (H x V)  : " (itoa numH) " Horizontal x " (itoa numV) " Vertikal"))
    (princ (strcat "\n  Area grid (X x Y)    : " (rtos totalX 2 2) " mm x " (rtos totalY 2 2) " mm"))
    (princ (strcat "\n  Skala cetak          : 1:" (rtos scaleDenom 2 2)))
    (princ (strcat "\n  Tinggi teks model    : " (rtos textHModel 2 2) " mm (cetak " (rtos textHPrint 2 2) " mm)"))
    (princ (strcat "\n  Diameter bubble model: " (rtos bubDiaModel 2 2) " mm (cetak " (rtos bubbleDiaPrint 2 2) " mm)"))
    (princ (strcat "\n  Perpanjangan (G / A) : " (rtos extLen 2 2) " mm / " (rtos (asgrid:get-anno-ext-len readBack) 2 2) " mm"))
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

  ;; --------------------------------------------------------------------------
  ;; MODUL 6: WRAPPER LIVE PREVIEW & MANAJEMEN DIALOG DCL (UTUH DARI V2.1.2)
  ;; --------------------------------------------------------------------------
  (defun fn-update-live-preview ( / sc th bd ex posIdx bPos dH dV val okData prevRes nH nV totalX totalY denseMode)
    (setq sc     (if (asgrid:parse-pos-real (get_tile "scale_denom")) (asgrid:parse-pos-real (get_tile "scale_denom")) 100.0)
          th     (if (asgrid:parse-pos-real (get_tile "txt_height")) (asgrid:parse-pos-real (get_tile "txt_height")) 2.5)
          bd     (if (asgrid:parse-pos-real (get_tile "bub_dia")) (asgrid:parse-pos-real (get_tile "bub_dia")) 8.0)
          ex     (if (asgrid:parse-pos-real (get_tile "ext_len")) (asgrid:parse-pos-real (get_tile "ext_len")) 1500.0)
          posIdx (atoi (get_tile "bub_pos"))
          bPos   (if (and (>= posIdx 0) (< posIdx (length BUB_POS_LIST)))
                   (nth posIdx BUB_POS_LIST)
                   "Both Ends")
          dH     '()
          dV     '()
          okData T)

    (foreach s strListH
      (setq val (asgrid:parse-pos-real s))
      (if val
        (setq dH (append dH (list val)))
        (progn (setq dH (append dH (list (atof DEF_SPACING_H)))) (setq okData nil))
      )
    )
    (foreach s strListV
      (setq val (asgrid:parse-pos-real s))
      (if val
        (setq dV (append dV (list val)))
        (progn (setq dV (append dV (list (atof DEF_SPACING_V)))) (setq okData nil))
      )
    )

    ;; Untuk generator ASGRID, geomExtLen dan annoExtLen keduanya sama dengan ex (EXT_LEN)
    (setq prevRes   (asgrid:prev-render-grid "grid_preview" dH dV ex ex sc th bd bPos)
          nH        (nth 0 prevRes)
          nV        (nth 1 prevRes)
          totalX    (nth 2 prevRes)
          totalY    (nth 3 prevRes)
          denseMode (nth 4 prevRes))

    (set_tile "prev_info_1"
      (strcat "Grid: " (itoa nH) "H (1.." (itoa nH) ") x "
              (itoa nV) "V (A.." (asgrid:index-to-alpha nV) ")"
              (if (not okData) " [Pending input]" "")))
    (set_tile "prev_info_2"
      (strcat "Total Dim: X = " (rtos totalX 2 0) " mm | Y = " (rtos totalY 2 0) " mm"))
    (set_tile "prev_info_3"
      (strcat "Bubble: " bPos " | "
              (if denseMode "Mode: Dense (Sampled Labels)" "Mode: Full Detail")))
  )

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
          (set_tile lblKey (strcat (asgrid:index-to-alpha (1+ idx)) " - " (asgrid:index-to-alpha (+ idx 2))))
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
             strListH (fn-resize-str-list strListH (max 0 (1- curNumH)) DEF_SPACING_H)
             strListV (fn-resize-str-list strListV (max 0 (1- curNumV)) DEF_SPACING_V))
       (fn-refresh-h-table)
       (fn-refresh-v-table)
       (fn-update-live-preview))
    )
  )

  (defun fn-update-scale-preview ( / sc th bd warnTxt)
    (setq sc (asgrid:parse-pos-real (get_tile "scale_denom"))
          th (asgrid:parse-pos-real (get_tile "txt_height"))
          bd (asgrid:parse-pos-real (get_tile "bub_dia")))
    (if (and sc th bd)
      (progn
        (setq warnTxt
          (cond
            ((<= bd th)        " [WARN: Bubble <= Text!]")
            ((< bd (* 2.0 th)) " [Note: Bubble sempit]")
            (t                 "")))
        (set_tile "scale_preview"
          (strcat "Model -> Text: " (rtos (* th sc) 2 1)
                  " mm | Bubble: " (rtos (* bd sc) 2 1) " mm" warnTxt))
      )
      (set_tile "scale_preview"
        "Model Space Preview -> Masukkan skala, tinggi teks, dan diameter bubble valid (> 0).")
    )
    (fn-update-live-preview)
  )

  ;; --------------------------------------------------------------------------
  ;; MODUL 7: VALIDASI INPUT TERPUSAT SEBELUM DIALOG DITUTUP
  ;; --------------------------------------------------------------------------
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
             strListH (fn-resize-str-list strListH (max 0 (1- curNumH)) DEF_SPACING_H)
             strListV (fn-resize-str-list strListV (max 0 (1- curNumV)) DEF_SPACING_V))
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
                            (asgrid:index-to-alpha (1+ idx)) " - " (asgrid:index-to-alpha (+ idx 2))
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
             (princ (strcat "\n[" VER_LABEL " Peringatan] Diameter bubble cetak <= tinggi teks cetak; teks dapat melewati bubble."))
           )
           (done_dialog 1))
        )
      )
    )
  )

  ;; --------------------------------------------------------------------------
  ;; ALUR UTAMA PROGRAM ASGRID V2.2
  ;; --------------------------------------------------------------------------
  (setq dclFile (findfile "ASGRID_V2_2_1_R3.dcl"))
  (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1_R2.dcl")))
  (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1.dcl")))
  (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2.dcl")))
  (if (null dclFile)
    (progn
      (alert
        (strcat
          "File dialog 'ASGRID_V2_2_1_R3.dcl' tidak ditemukan!\n\n"
          "Pastikan 'ASGRID_V2_2_1_R3.dcl' disimpan pada folder yang terdaftar di\n"
          "AutoCAD Options -> Files -> Support File Search Path."
        )
      )
      (princ (strcat "\n[" VER_LABEL " ERROR] File 'ASGRID_V2_2_1_R3.dcl' tidak ditemukan."))
      (princ)
    )
    (progn
      (setq dclId (load_dialog dclFile))
      (if (or (null dclId) (< dclId 0))
        (progn
          (alert (strcat "Gagal memuat file dialog '" dclFile "'."))
          (princ (strcat "\n[" VER_LABEL " ERROR] load_dialog gagal untuk '" dclFile "'."))
          (princ)
        )
        (if (not (new_dialog "asgrid_v2_2" dclId))
          (progn
            (unload_dialog dclId)
            (setq dclId nil)
            (alert (strcat "Definisi dialog 'asgrid_v2_2' tidak ditemukan di dalam '" dclFile "'."))
            (princ (strcat "\n[" VER_LABEL " ERROR] new_dialog gagal untuk 'asgrid_v2_2'."))
            (princ)
          )
          (progn
            (setq curNumH            4
                  curNumV            4
                  strListH           (list DEF_SPACING_H DEF_SPACING_H DEF_SPACING_H)
                  strListV           (list DEF_SPACING_V DEF_SPACING_V DEF_SPACING_V)
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

            (setq arialPath (asgrid:find-arial-ttf FONT_FILE))
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
                (setq basePtUcs (getpoint (strcat "\n[" VER_LABEL "] Klik titik awal grid (pojok kiri bawah): ")))
                (if basePtUcs
                  (progn
                    (setq basePt (trans basePtUcs 1 0))
                    (fn-execute-grid-creation basePt)
                  )
                  (princ (strcat "\n[" VER_LABEL "] Titik awal tidak dipilih. Proses dibatalkan tanpa mengubah gambar."))
                )
              )
              (princ (strcat "\n[" VER_LABEL "] Dibatalkan oleh pengguna. Tidak ada objek yang dibuat."))
            )
            (princ)
          )
        )
      )
    )
  )
)


;;; ============================================================================
;;; PERINTAH DIAGNOSTIK READ-ONLY: ASGRIDCHECK (MENGGUNAKAN SHARED AUDIT SERVICE)
;;; ============================================================================

(defun c:ASGRIDCHECK ( /
                       *error*
                       nodIds ss i ename parsed gid role
                       orphanEntMap corruptXdataCnt issuesCnt totalGroups
                       spec valErrs auditRes
                       actL actB actT actTot expL expB expT expTot
                       dxfMis idxInv etagInv dupSlots
                       entry gExt aExt
                       fn-inc-orphan-role
                     )

  (defun *error* (msg)
    (if (and msg (not (member msg '("Function cancelled" "quit / exit abort" "console break"))))
      (princ (strcat "\n[ASGRIDCHECK ERROR] " msg))
      (princ "\n[ASGRIDCHECK] Pemeriksaan dibatalkan.")
    )
    (princ)
  )

  (defun fn-inc-orphan-role (amap g r / rec cnts l b tCnt newRec res)
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
        (foreach pair amap
          (if (= (car pair) g)
            (setq res (append res (list newRec)))
            (setq res (append res (list pair)))
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
  (princ "\n  ASGRIDCHECK V2.2 - DEEP DIAGNOSTICS (100% READ-ONLY)      ")
  (princ "\n============================================================")
  (princ "\n  Catatan: Pemindaian memakai ssget \"_X\" (entitas top-level;")
  (princ "\n           tidak mencakup nested entities di dalam BLOCK).")

  (setq nodIds          (asgrid:meta-list-nod-ids)
        orphanEntMap    '()
        corruptXdataCnt 0
        issuesCnt       0)

  ;; 1. Deteksi entitas dengan XData korup atau Group ID tanpa metadata di NOD
  (setq ss (ssget "_X" (list (list -3 (list (asgrid:xdata-app))))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename  (ssname ss i)
              parsed (asgrid:parse-entity-xdata ename))
        (if (null parsed)
          (setq corruptXdataCnt (1+ corruptXdataCnt)
                issuesCnt       (1+ issuesCnt))
          (if (not (member (nth 0 parsed) nodIds))
            (setq orphanEntMap (fn-inc-orphan-role orphanEntMap (nth 0 parsed) (nth 1 parsed)))
          )
        )
        (setq i (1+ i))
      )
    )
  )

  ;; 2. Audit tiap grup terdaftar di NOD menggunakan asgrid:audit-group-entities
  (setq totalGroups (length nodIds))
  (princ (strcat "\n  Grup terdaftar di NOD (" (asgrid:dict-name) "): " (itoa totalGroups)))

  (if (= totalGroups 0)
    (princ "\n  Tidak ada kelompok grid ASGRID terdaftar di DWG ini.")
    (foreach gid nodIds
      (princ (strcat "\n\n  [GRUP: " gid "]"))
      (setq spec (asgrid:meta-read-group gid))
      (if (null spec)
        (progn
          (princ "\n    - Status XRecord : ERROR (XRecord tidak dapat dibaca atau bukan tipe XRECORD)")
          (setq issuesCnt (1+ issuesCnt))
        )
        (progn
          (setq valErrs (asgrid:meta-validate-spec spec))
          (if valErrs
            (progn
              (princ (strcat "\n    - Integritas Meta: ERROR (" (itoa (length valErrs)) " masalah ditemukan)"))
              (foreach errItem valErrs
                (princ (strcat "\n        * " errItem))
              )
              (setq issuesCnt (1+ issuesCnt))
            )
            (progn
              (setq auditRes (asgrid:audit-group-entities gid spec)
                    actL     (cdr (assoc "ACT_L" auditRes))
                    actB     (cdr (assoc "ACT_B" auditRes))
                    actT     (cdr (assoc "ACT_T" auditRes))
                    actTot   (cdr (assoc "ACT_TOT" auditRes))
                    expL     (cdr (assoc "EXP_L" auditRes))
                    expB     (cdr (assoc "EXP_B" auditRes))
                    expT     (cdr (assoc "EXP_T" auditRes))
                    expTot   (cdr (assoc "EXP_TOT" auditRes))
                    dxfMis   (cdr (assoc "DXF_MISMATCH" auditRes))
                    idxInv   (cdr (assoc "IDX_INVALID" auditRes))
                    etagInv  (cdr (assoc "ENDTAG_INVALID" auditRes))
                    dupSlots (cdr (assoc "DUP_SLOTS" auditRes))
                    gExt     (cdr (assoc "EXT_LEN" spec))
                    aExt     (asgrid:get-anno-ext-len spec))

              (princ (strcat "\n    - Integritas Meta: OK (Schema " (cdr (assoc "SCHEMA_VER" spec))
                             " | Gen V" (cdr (assoc "GENERATOR_VER" spec))
                             " | Scale 1:" (rtos (cdr (assoc "SCALE_DENOM" spec)) 2 0) ")"))
              (princ (strcat "\n    - Konfigurasi    : " (itoa (cdr (assoc "NUM_H" spec))) "H x "
                             (itoa (cdr (assoc "NUM_V" spec))) "V | Elev: "
                             (rtos (cdr (assoc "ELEVATION" spec)) 2 2)
                             " | Bubble: " (cdr (assoc "BUBBLE_POS" spec))))
              (princ (strcat "\n    - Extension      : Geom " (rtos gExt 2 1) " mm | Anno "
                             (rtos aExt 2 1) " mm"
                             (if (assoc "ANNO_EXT_LEN" spec) "" " (fallback EXT_LEN)")))
              (princ (strcat "\n    - Entitas Aktual : Lines " (itoa actL) "/" (itoa expL)
                             " | Bubbles " (itoa actB) "/" (itoa expB)
                             " | Texts " (itoa actT) "/" (itoa expT)
                             " (Total " (itoa actTot) "/" (itoa expTot) ")"))

              (if (= actTot 0)
                (progn
                  (princ "\n    - Status Entitas : PERINGATAN - Metadata yatim (0 entitas ditemukan di gambar).")
                  (setq issuesCnt (1+ issuesCnt))
                )
                (progn
                  (if (or (/= actL expL) (/= actB expB) (/= actT expT))
                    (progn
                      (princ "\n    - Jumlah Entitas : PERINGATAN - Tidak sesuai ekspektasi metadata.")
                      (setq issuesCnt (1+ issuesCnt))
                    )
                  )
                  (if (> dxfMis 0)
                    (progn
                      (princ (strcat "\n    - DXF vs Role    : PERINGATAN - " (itoa dxfMis)
                                     " entitas memiliki tipe DXF tidak sesuai Role."))
                      (setq issuesCnt (1+ issuesCnt))
                    )
                  )
                  (if (> idxInv 0)
                    (progn
                      (princ (strcat "\n    - AxisIdx Range  : PERINGATAN - " (itoa idxInv)
                                     " entitas memiliki AxisIdx di luar batas NUM_H/NUM_V."))
                      (setq issuesCnt (1+ issuesCnt))
                    )
                  )
                  (if (> etagInv 0)
                    (progn
                      (princ (strcat "\n    - EndTag vs Pos  : PERINGATAN - " (itoa etagInv)
                                     " entitas memiliki EndTag tidak sesuai BUBBLE_POS."))
                      (setq issuesCnt (1+ issuesCnt))
                    )
                  )
                  (if dupSlots
                    (progn
                      (princ (strcat "\n    - Duplikasi Slot : PERINGATAN - Ditemukan "
                                     (itoa (length dupSlots)) " slot duplikat (contoh: " (car dupSlots) ")."))
                      (setq issuesCnt (1+ issuesCnt))
                    )
                  )
                  (if (cdr (assoc "IS_HEALTHY" auditRes))
                    (princ "\n    - Status Entitas : OK (Lengkap, DXF/Role/AxisIdx/EndTag valid, 0 duplikat).")
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  ;; 3. Laporan entitas yatim & XData korup
  (if orphanEntMap
    (progn
      (princ "\n\n  [PERINGATAN: ENTITAS TANPA METADATA DI NOD]")
      (foreach entry orphanEntMap
        (setq gid       (car entry)
              actL      (nth 0 (cdr entry))
              actB      (nth 1 (cdr entry))
              actT      (nth 2 (cdr entry))
              issuesCnt (1+ issuesCnt))
        (princ (strcat "\n    - Group ID '" gid "' tidak ada di NOD (ditemukan: "
                       (itoa actL) " LINE, " (itoa actB) " BUBBLE, " (itoa actT) " TEXT)."))
      )
    )
  )

  (if (> corruptXdataCnt 0)
    (princ (strcat "\n\n  [PERINGATAN: XDATA KORUP] Ditemukan " (itoa corruptXdataCnt)
                   " entitas dengan struktur XData ASGRID_OBJ tidak valid/tidak lengkap."))
  )

  ;; 4. Ringkasan akhir
  (princ "\n------------------------------------------------------------")
  (if (= issuesCnt 0)
    (princ "\n[ASGRIDCHECK V2.2] HASIL: SEMUA GRUP & ENTITAS SEHAT (0 MASALAH).")
    (princ (strcat "\n[ASGRIDCHECK V2.2] HASIL: DITEMUKAN " (itoa issuesCnt)
                   " PERINGATAN/MASALAH. (Mode READ-ONLY: tidak ada data diubah.)"))
  )
  (princ "\n------------------------------------------------------------")
  (princ)
)



;;; ============================================================================
;;; PERINTAH BARU PHASE 2: ASGRIDEDIT (MODE 1 - ANNOTATION EDITOR)
;;; Mengedit anotasi grid (Bubble Diameter, Text Height, Text Style, Bubble
;;; Position, Annotation Extension Length) tanpa mengubah geometri LINE,
;;; koordinat, jumlah sumbu, spacing, SCALE_DENOM, maupun EXT_LEN.
;;; Transaksi 6-langkah: A. Snapshot -> B. Create (Temp XData) -> C. Verify ->
;;;                      D. Swap (Delete Old + Promote Temp->Final) ->
;;;                      E. Update Metadata & Read-Back -> F. Final Audit/Commit
;;; ============================================================================

(defun c:ASGRIDEDIT ( /
                      ;; Error handler & state transaksi
                      *error* oldCmdEcho undoOpen dclId
                      txActive txAbortedByCode txStage
                      txNewAnnoEnts txDeletedOldEnts txMetaUpdated
                      oldXrecSnap oldAnnoSnapshots oldLineSnapCoords
                      oldSpec groupId
                      ;; Konstanta & state dialog
                      VER_LABEL BUB_POS_LIST styleList
                      dclFile dclRes
                      newBubDia newTxtH newTxtStyle newFontFile newBubPos newAnnoExt
                      ;; Helper lokal
                      fn-edit-select-and-validate
                      fn-edit-update-preview
                      fn-edit-validate-dialog
                      fn-edit-capture-line-coords
                      fn-edit-verify-lines-intact
                      fn-edit-verify-temp-annos
                      fn-edit-promote-temp-to-final
                      fn-edit-recreate-from-dxf
                      fn-edit-rollback
                      fn-edit-build-new-spec
                      fn-edit-execute-transaction
                      ;; Hasil seleksi awal
                      selInfo initAuditRes
                    )

  (setq VER_LABEL          "ASGRIDEDIT V2.2"
        BUB_POS_LIST       (asgrid:valid-bubble-positions)
        oldCmdEcho         (getvar "CMDECHO")
        undoOpen           nil
        dclId              nil
        txActive           nil
        txAbortedByCode    nil
        txStage            "INIT"
        txNewAnnoEnts      '()
        txDeletedOldEnts   '()
        txMetaUpdated      nil
        oldXrecSnap        nil
        oldAnnoSnapshots   '()
        oldLineSnapCoords  '()
        oldSpec            nil
        groupId            nil)

  ;; --------------------------------------------------------------------------
  ;; 1. ERROR HANDLER LOKAL DENGAN ROLLBACK & RECOVERY
  ;; --------------------------------------------------------------------------
  (defun *error* (msg / isUserCancel)
    (if (and dclId (>= dclId 0))
      (progn
        (unload_dialog dclId)
        (setq dclId nil)
      )
    )
    (if txActive
      (fn-edit-rollback (strcat "Interupsi/Error pada tahap " txStage))
    )
    (if undoOpen
      (progn
        (setvar "CMDECHO" 0)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
      )
    )
    (if oldCmdEcho
      (setvar "CMDECHO" oldCmdEcho)
    )
    (setq isUserCancel (member msg '("Function cancelled"
                                     "quit / exit abort"
                                     "console break")))
    (cond
      (txAbortedByCode
       (princ (strcat "\n[" VER_LABEL "] Proses dihentikan secara aman.")))
      ((and msg (not isUserCancel))
       (princ (strcat "\n[" VER_LABEL " PROGRAM ERROR] " msg
                      "\n  Transaksi dihentikan pada tahap " txStage ".")))
      (t
       (princ (strcat "\n[" VER_LABEL "] Proses dibatalkan oleh pengguna.")))
    )
    (princ)
  )

  ;; --------------------------------------------------------------------------
  ;; 2. PEMILIHAN OBJEK & PRE-EDIT INTEGRITY GATE (READ-ONLY)
  ;; --------------------------------------------------------------------------
  (defun fn-edit-select-and-validate ( / sel ename parsed gid spec valErrs auditRes)
    (setq sel (entsel (strcat "\n[" VER_LABEL "] Pilih salah satu objek grid ASGRID (LINE/BUBBLE/TEXT): ")))
    (if (null sel)
      (progn
        (princ (strcat "\n[" VER_LABEL "] Tidak ada objek dipilih. Proses dibatalkan."))
        nil
      )
      (progn
        (setq ename  (car sel)
              parsed (asgrid:parse-entity-xdata ename))
        (cond
          ((null parsed)
           (alert "Objek yang dipilih bukan bagian dari grid ASGRID yang valid (tidak memiliki XData ASGRID_OBJ valid).")
           (princ (strcat "\n[" VER_LABEL " ERROR] Objek terpilih tidak memiliki XData ASGRID_OBJ yang valid."))
           nil)
          (t
           (setq gid  (nth 0 parsed)
                 spec (asgrid:meta-read-group gid))
           (cond
             ((null spec)
              (alert (strcat "Metadata untuk Group ID '" gid "' tidak ditemukan di NOD ASGRID_GROUPS.\nEdit dibatalkan."))
              (princ (strcat "\n[" VER_LABEL " ERROR] Group ID '" gid "' tidak memiliki metadata di NOD."))
              nil)
             ((setq valErrs (asgrid:meta-validate-spec spec))
              (alert (strcat "Metadata grup '" gid "' tidak valid/korup:\n" (car valErrs)
                             "\n\nJalankan ASGRIDCHECK untuk rincian. Edit dibatalkan tanpa mengubah DWG."))
              (princ (strcat "\n[" VER_LABEL " ERROR] Validasi metadata '" gid "' gagal: " (car valErrs)))
              nil)
             (t
              (setq auditRes (asgrid:audit-group-entities gid spec))
              (if (not (cdr (assoc "IS_HEALTHY" auditRes)))
                (progn
                  (alert (strcat "Grup '" gid "' tidak dalam kondisi sehat (terdapat entitas hilang, duplikat slot, atau anomali XData).\n\n"
                                 "Jalankan ASGRIDCHECK untuk memeriksa detail. Edit dibatalkan tanpa mengubah DWG."))
                  (princ (strcat "\n[" VER_LABEL " ERROR] Pre-edit audit gagal untuk '" gid "'. Jalankan ASGRIDCHECK."))
                  nil
                )
                (list gid spec auditRes)
              ))
           ))
        )
      )
    )
  )

  ;; --------------------------------------------------------------------------
  ;; 3. LIVE PREVIEW & VALIDASI DIALOG EDITOR
  ;; --------------------------------------------------------------------------
  (defun fn-edit-update-preview ( / bd th aExt posIdx bPos stIdx stName stVal
                                    sc gExt dH dV prevRes nH nV totalX totalY denseMode warnTxt)
    (setq sc     (cdr (assoc "SCALE_DENOM" oldSpec))
          gExt   (cdr (assoc "EXT_LEN" oldSpec))
          dH     (cdr (assoc "DIST_H" oldSpec))
          dV     (cdr (assoc "DIST_V" oldSpec))
          bd     (if (asgrid:parse-pos-real (get_tile "ed_bub_dia"))
                   (asgrid:parse-pos-real (get_tile "ed_bub_dia"))
                   (cdr (assoc "BUBBLE_DIA_PRINT" oldSpec)))
          th     (if (asgrid:parse-pos-real (get_tile "ed_txt_height"))
                   (asgrid:parse-pos-real (get_tile "ed_txt_height"))
                   (cdr (assoc "TEXT_H_PRINT" oldSpec)))
          aExt   (if (asgrid:parse-pos-real (get_tile "ed_anno_ext"))
                   (asgrid:parse-pos-real (get_tile "ed_anno_ext"))
                   (asgrid:get-anno-ext-len oldSpec))
          posIdx (atoi (get_tile "ed_bub_pos"))
          bPos   (if (and (>= posIdx 0) (< posIdx (length BUB_POS_LIST)))
                   (nth posIdx BUB_POS_LIST)
                   (cdr (assoc "BUBBLE_POS" oldSpec)))
          stIdx  (atoi (get_tile "ed_txt_style"))
          stName (if (and (>= stIdx 0) (< stIdx (length styleList)))
                   (nth stIdx styleList)
                   (cdr (assoc "TEXT_STYLE" oldSpec))))

    ;; Peringatan non-blocking untuk ukuran bubble & perbandingan ANNO_EXT vs EXT_LEN
    (setq warnTxt
      (cond
        ((<= bd th)         " [WARN: Bubble <= Text!]")
        ((< aExt gExt)      " [Note: Anno EXT < Geom EXT]")
        ((< bd (* 2.0 th))  " [Note: Bubble sempit]")
        (t                  "")))
    (set_tile "ed_scale_prev"
      (strcat "Model -> Text: " (rtos (* th sc) 2 1)
              " mm | Bubble: " (rtos (* bd sc) 2 1) " mm" warnTxt))

    ;; Cek status Text Style yang dipilih secara live
    (setq stVal (asgrid:validate-text-style stName))
    (if (car stVal)
      (set_tile "ed_style_info" (strcat "Style OK: " stName " (Font: " (cadr stVal) ")"))
      (set_tile "ed_style_info" (strcat "Style INVALID: " (cadr stVal)))
    )

    ;; Render Live Preview via shared service (geomExtLen = gExt TETAP, annoExtLen = aExt DINAMIS)
    (setq prevRes   (asgrid:prev-render-grid "ed_preview" dH dV gExt aExt sc th bd bPos)
          nH        (nth 0 prevRes)
          nV        (nth 1 prevRes)
          totalX    (nth 2 prevRes)
          totalY    (nth 3 prevRes)
          denseMode (nth 4 prevRes))

    (set_tile "ed_prev_info_1"
      (strcat "Grid: " (itoa nH) "H (1.." (itoa nH) ") x "
              (itoa nV) "V (A.." (asgrid:index-to-alpha nV) ")"
              (if denseMode " [Dense Mode]" " [Full Detail]")))
    (set_tile "ed_prev_info_2"
      (strcat "Total Dim: X = " (rtos totalX 2 0) " mm | Y = " (rtos totalY 2 0) " mm"))
    (set_tile "ed_prev_info_3"
      (strcat "Geom EXT: " (rtos gExt 2 0) " | Anno EXT: " (rtos aExt 2 0) " mm | " bPos))
  )

  (defun fn-edit-validate-dialog ( / bd th aExt posIdx stIdx stName stVal ok)
    (setq ok     T
          bd     (asgrid:parse-pos-real (get_tile "ed_bub_dia"))
          th     (asgrid:parse-pos-real (get_tile "ed_txt_height"))
          aExt   (asgrid:parse-pos-real (get_tile "ed_anno_ext"))
          posIdx (atoi (get_tile "ed_bub_pos"))
          stIdx  (atoi (get_tile "ed_txt_style")))

    (cond
      ((null bd)
       (set_tile "error" "Error: Printed Bubble Diameter harus angka positif (> 0).")
       (mode_tile "ed_bub_dia" 2)
       (setq ok nil))
      ((null th)
       (set_tile "error" "Error: Printed Text Height harus angka positif (> 0).")
       (mode_tile "ed_txt_height" 2)
       (setq ok nil))
      ((or (< stIdx 0) (>= stIdx (length styleList)))
       (set_tile "error" "Error: Pilihan Text Style tidak valid.")
       (mode_tile "ed_txt_style" 2)
       (setq ok nil))
      ((or (< posIdx 0) (>= posIdx (length BUB_POS_LIST)))
       (set_tile "error" "Error: Pilihan Bubble Position tidak valid.")
       (mode_tile "ed_bub_pos" 2)
       (setq ok nil))
      ((null aExt)
       (set_tile "error" "Error: Annotation Extension Length harus angka positif (> 0).")
       (mode_tile "ed_anno_ext" 2)
       (setq ok nil))
      (t
       (setq stName (nth stIdx styleList)
             stVal  (asgrid:validate-text-style stName))
       (if (not (car stVal))
         (progn
           (set_tile "error" (strcat "Error Text Style: " (cadr stVal)))
           (mode_tile "ed_txt_style" 2)
           (setq ok nil)
         )
         (progn
           (setq newBubDia   bd
                 newTxtH     th
                 newTxtStyle stName
                 newFontFile (cadr stVal)
                 newBubPos   (nth posIdx BUB_POS_LIST)
                 newAnnoExt  aExt)
           (set_tile "error" "")
           (done_dialog 1)
         )
       ))
    )
  )

  ;; --------------------------------------------------------------------------
  ;; 4. HELPER TRANSAKSI: LINE SNAPSHOT, TEMP VERIFY, PROMOTE & ROLLBACK
  ;; --------------------------------------------------------------------------

  ;; Rekam (ename p10 p11) setiap LINE agar dapat dibuktikan 0 perubahan geometri
  (defun fn-edit-capture-line-coords (lineEnts / e ed res)
    (setq res '())
    (foreach e lineEnts
      (setq ed (entget e))
      (if ed
        (setq res (cons (list e (cdr (assoc 10 ed)) (cdr (assoc 11 ed))) res))
      )
    )
    res
  )

  ;; Verifikasi seluruh LINE lama masih eksis dengan koordinat 10/11 identik
  (defun fn-edit-verify-lines-intact (snapList / ok item e ed tol)
    (setq ok  T
          tol (asgrid:tol))
    (foreach item snapList
      (if ok
        (progn
          (setq e  (nth 0 item)
                ed (if e (entget e) nil))
          (if (or (null ed)
                  (/= (cdr (assoc 0 ed)) "LINE")
                  (not (equal (cdr (assoc 10 ed)) (nth 1 item) tol))
                  (not (equal (cdr (assoc 11 ed)) (nth 2 item) tol)))
            (setq ok nil)
          )
        )
      )
    )
    ok
  )

  ;; STEP C: Verifikasi seluruh anotasi sementara berdasarkan daftar ename eksplisit
  ;; (bukan pencarian global)
  (defun fn-edit-verify-temp-annos (tmpEnts spec expB expT /
                                     nH nV bPos expStyle tmpApp
                                     e ed dxfType parsed gid role dir idx etag
                                     cntB cntT seenSlots slotKey errMsg
                                     expectedDxf endTagOk
                                   )
    (setq nH        (cdr (assoc "NUM_H" spec))
          nV        (cdr (assoc "NUM_V" spec))
          bPos      (cdr (assoc "BUBBLE_POS" spec))
          expStyle  (cdr (assoc "TEXT_STYLE" spec))
          tmpApp    (asgrid:xdata-tmp-app)
          cntB      0
          cntT      0
          seenSlots '()
          errMsg    nil)

    (foreach e tmpEnts
      (if (null errMsg)
        (progn
          (setq ed (if e (entget e) nil))
          (if (null ed)
            (setq errMsg "Salah satu entitas anotasi sementara tidak ditemukan di database.")
            (progn
              (setq dxfType (cdr (assoc 0 ed))
                    parsed  (asgrid:parse-entity-xdata-for-app e tmpApp))
              (if (null parsed)
                (setq errMsg "Entitas sementara tidak memiliki XData sementara ASGRID_TX_TMP yang valid.")
                (progn
                  (setq gid  (nth 0 parsed)
                        role (nth 1 parsed)
                        dir  (nth 2 parsed)
                        idx  (nth 3 parsed)
                        etag (nth 4 parsed))
                  (setq expectedDxf
                    (cond
                      ((= role "BUBBLE") "CIRCLE")
                      ((= role "TEXT")   "TEXT")
                      (t                 "")))
                  (setq endTagOk
                    (cond
                      ((= bPos "Both Ends") (or (= etag "START") (= etag "END")))
                      ((= bPos "Start")     (= etag "START"))
                      ((= bPos "End")       (= etag "END"))
                      (t                    nil)))
                  (setq slotKey (strcat role "|" dir "|" (itoa idx) "|" etag))
                  (cond
                    ((/= gid groupId)
                     (setq errMsg "Group ID pada XData sementara tidak cocok."))
                    ((/= dxfType expectedDxf)
                     (setq errMsg (strcat "DXF type (" dxfType ") tidak sesuai Role (" role ").")))
                    ((and (= role "TEXT") (/= (strcase (cdr (assoc 7 ed))) (strcase expStyle)))
                     (setq errMsg (strcat "Text Style entitas sementara tidak sesuai (" expStyle ").")))
                    ((or (and (= dir "H") (or (< idx 1) (> idx nH)))
                         (and (= dir "V") (or (< idx 1) (> idx nV))))
                     (setq errMsg "AxisIdx anotasi sementara di luar rentang NUM_H/NUM_V."))
                    ((not endTagOk)
                     (setq errMsg "EndTag anotasi sementara tidak sesuai BUBBLE_POS."))
                    ((member slotKey seenSlots)
                     (setq errMsg (strcat "Duplikasi slot pada anotasi sementara: " slotKey)))
                    (t
                     (setq seenSlots (cons slotKey seenSlots))
                     (if (= role "BUBBLE") (setq cntB (1+ cntB)))
                     (if (= role "TEXT")   (setq cntT (1+ cntT))))
                  )
                )
              )
            )
          )
        )
      )
    )

    (if (null errMsg)
      (cond
        ((/= cntB expB)
         (setq errMsg (strcat "Jumlah bubble sementara (" (itoa cntB) ") != ekspektasi (" (itoa expB) ").")))
        ((/= cntT expT)
         (setq errMsg (strcat "Jumlah text sementara (" (itoa cntT) ") != ekspektasi (" (itoa expT) ").")))
        ((/= (length tmpEnts) (+ expB expT))
         (setq errMsg "Total ename sementara tidak sama dengan jumlah bubble + text."))
      )
    )
    (list (null errMsg) cntB cntT errMsg)
  )

  ;; STEP D2: Promosikan XData ASGRID_TX_TMP -> XData final ASGRID_OBJ (hapus temp XData)
  (defun fn-edit-promote-temp-to-final (tmpEnts / tmpApp finApp e parsed ed baseEd newEd ok)
    (setq tmpApp (asgrid:xdata-tmp-app)
          finApp (asgrid:xdata-app)
          ok     T)
    (foreach e tmpEnts
      (if ok
        (progn
          (setq parsed (asgrid:parse-entity-xdata-for-app e tmpApp)
                ed     (if e (entget e (list tmpApp finApp)) nil))
          (if (or (null parsed) (null ed))
            (setq ok nil)
            (progn
              ;; Buang grup -3 lama, pasang -3 baru: hapus tmpApp (kosong) + pasang finApp final
              (setq baseEd (vl-remove-if '(lambda (p) (= (car p) -3)) ed)
                    newEd  (append baseEd
                             (list
                               (list -3
                                 (list tmpApp) ; hapus XData sementara
                                 (list finApp
                                   (cons 1000 (nth 0 parsed))
                                   (cons 1000 (nth 1 parsed))
                                   (cons 1000 (nth 2 parsed))
                                   (cons 1070 (nth 3 parsed))
                                   (cons 1000 (nth 4 parsed))
                                   (cons 1000 (nth 5 parsed))
                                 )
                               )
                             )))
              (if (or (null (entmod newEd))
                      (null (asgrid:parse-entity-xdata e)))
                (setq ok nil)
              )
            )
          )
        )
      )
    )
    ok
  )

  ;; Fallback recovery: buat ulang satu entitas lama dari snapshot DXF bila undelete gagal
  (defun fn-edit-recreate-from-dxf (rawDxf / cleanDxf pair)
    (setq cleanDxf '())
    (foreach pair rawDxf
      (if (not (member (car pair) '(-1 5 330 102)))
        (setq cleanDxf (append cleanDxf (list pair)))
      )
    )
    (entmakex cleanDxf)
  )

  ;; ROLLBACK & RECOVERY LENGKAP:
  ;; 1. Hapus seluruh anotasi baru (txNewAnnoEnts).
  ;; 2. Pulihkan anotasi lama yang sempat terhapus (undelete via entdel, fallback DXF snapshot).
  ;; 3. Pulihkan XRecord asli via asgrid:meta-restore-xrecord jika metadata sudah diubah.
  ;; 4. Verifikasi kembali kondisi pasca-rollback & laporkan jujur jika tidak 100% pulih.
  (defun fn-edit-rollback (reason / e snapEntry rawDxf delNewCnt restOldCnt restFailCnt
                                    metaRestOk postAudit linesOk)
    (setq delNewCnt   0
          restOldCnt  0
          restFailCnt 0
          metaRestOk  T)

    ;; 1. Hapus seluruh anotasi baru
    (foreach e txNewAnnoEnts
      (if (and e (entget e))
        (progn
          (entdel e)
          (setq delNewCnt (1+ delNewCnt))
        )
      )
    )
    (setq txNewAnnoEnts '())

    ;; 2. Pulihkan anotasi lama yang sempat terhapus
    (foreach e txDeletedOldEnts
      (if e
        (progn
          ;; Coba undelete native AutoCAD (entdel pada entitas terhapus)
          (if (null (entget e))
            (entdel e)
          )
          (if (entget e)
            (setq restOldCnt (1+ restOldCnt))
            (progn
              ;; Fallback dari snapshot DXF
              (setq snapEntry (assoc e oldAnnoSnapshots)
                    rawDxf    (if snapEntry (cdr snapEntry) nil))
              (if (and rawDxf (fn-edit-recreate-from-dxf rawDxf))
                (setq restOldCnt (1+ restOldCnt))
                (setq restFailCnt (1+ restFailCnt))
              )
            )
          )
        )
      )
    )
    (setq txDeletedOldEnts '())

    ;; 3. Pulihkan XRecord asli jika metadata sempat diubah
    (if (and txMetaUpdated oldXrecSnap)
      (setq metaRestOk (asgrid:meta-restore-xrecord groupId oldXrecSnap))
    )
    (setq txMetaUpdated nil
          txActive      nil)

    ;; 4. Verifikasi pasca-rollback
    (setq linesOk   (fn-edit-verify-lines-intact oldLineSnapCoords)
          postAudit (if (and groupId oldSpec)
                      (asgrid:audit-group-entities groupId oldSpec)
                      nil))

    (princ (strcat "\n[" VER_LABEL " ROLLBACK] Alasan: " reason
                   "\n  Anotasi baru dihapus: " (itoa delNewCnt)
                   " | Anotasi lama dipulihkan: " (itoa restOldCnt)
                   " | Metadata pulih: " (if metaRestOk "YA" "GAGAL")))

    (if (or (> restFailCnt 0)
            (not metaRestOk)
            (not linesOk)
            (and postAudit (not (cdr (assoc "IS_HEALTHY" postAudit)))))
      (progn
        (princ (strcat "\n[" VER_LABEL " RECOVERY WARNING] Rollback tidak pulih 100% pada tahap " txStage "."
                       "\n  Jalankan perintah UNDO (Ctrl+Z) segera dan periksa DWG dengan ASGRIDCHECK."))
        (alert (strcat "PERINGATAN PEMULIHAN (" VER_LABEL "):\n\n"
                       "Rollback pada tahap " txStage " tidak berhasil sepenuhnya.\n"
                       "Jalankan perintah UNDO (Ctrl+Z) untuk mengembalikan kondisi DWG, lalu periksa dengan ASGRIDCHECK."))
      )
      (princ (strcat "\n[" VER_LABEL " ROLLBACK] Kondisi grup '" groupId "' pulih 100% seperti semula."))
    )
  )

  ;; Bangun newSpec: hanya 5 parameter anotasi (+ FONT_FILE & UPDATED_AT) yang berubah;
  ;; seluruh parameter geometri & SCALE_DENOM dipertahankan identik dari oldSpec.
  (defun fn-edit-build-new-spec ( / res pair k)
    (setq res '())
    (foreach pair oldSpec
      (setq k (car pair))
      (cond
        ((= k "BUBBLE_DIA_PRINT") (setq res (append res (list (cons k newBubDia)))))
        ((= k "TEXT_H_PRINT")     (setq res (append res (list (cons k newTxtH)))))
        ((= k "TEXT_STYLE")       (setq res (append res (list (cons k newTxtStyle)))))
        ((= k "FONT_FILE")        (setq res (append res (list (cons k newFontFile)))))
        ((= k "BUBBLE_POS")       (setq res (append res (list (cons k newBubPos)))))
        ((= k "ANNO_EXT_LEN")     (setq res (append res (list (cons k newAnnoExt)))))
        ((= k "UPDATED_AT")       (setq res (append res (list (cons k (asgrid:get-timestamp))))))
        (t                        (setq res (append res (list pair))))
      )
    )
    ;; Tambahkan ANNO_EXT_LEN & UPDATED_AT bila grup lama belum memilikinya
    (if (null (assoc "ANNO_EXT_LEN" res))
      (setq res (append res (list (cons "ANNO_EXT_LEN" newAnnoExt))))
    )
    (if (null (assoc "UPDATED_AT" res))
      (setq res (append res (list (cons "UPDATED_AT" (asgrid:get-timestamp)))))
    )
    res
  )

  ;; --------------------------------------------------------------------------
  ;; 5. EKSEKUSI TRANSAKSI 6-LANGKAH (A. SNAPSHOT -> F. FINAL AUDIT & COMMIT)
  ;; --------------------------------------------------------------------------
  (defun fn-edit-execute-transaction ( /
                                       oldLineEnts oldAnnoEnts e
                                       newSpec valErrs tempSpec
                                       expCounts expL expB expT expTot
                                       annRes cntB cntT verRes verOk verErr
                                       readBack readErrs cmpDiffs
                                       finalAudit abortMsg
                                     )
    (asgrid:check-insunits-warning VER_LABEL)
    (princ (strcat "\n[" VER_LABEL "] Memulai transaksi edit anotasi untuk grup '" groupId "'..."))
    (setvar "CMDECHO" 0)
    (command "_.UNDO" "_Begin")
    (setq undoOpen        T
          txActive        T
          txAbortedByCode nil
          txStage         "STEP-A-SNAPSHOT"
          txNewAnnoEnts   '()
          txDeletedOldEnts '()
          txMetaUpdated   nil)

    ;; Pastikan kedua RegApp terdaftar via tblsearch
    (if (or (not (asgrid:ensure-regapp (asgrid:xdata-app)))
            (not (asgrid:ensure-regapp (asgrid:xdata-tmp-app))))
      (progn
        (setq txActive nil txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert "Gagal memastikan RegApp XData (ASGRID_OBJ / ASGRID_TX_TMP). Edit dibatalkan.")
        (exit)
      )
    )

    ;; STEP A — SNAPSHOT
    (setq oldXrecSnap       (asgrid:meta-get-xrecord-snapshot groupId)
          oldLineEnts       (cdr (assoc "LINE_ENTS" initAuditRes))
          oldAnnoEnts       (cdr (assoc "ANNO_ENTS" initAuditRes))
          oldLineSnapCoords (fn-edit-capture-line-coords oldLineEnts)
          oldAnnoSnapshots  '())
    (foreach e oldAnnoEnts
      (if (and e (entget e (list (asgrid:xdata-app))))
        (setq oldAnnoSnapshots (cons (cons e (entget e (list (asgrid:xdata-app)))) oldAnnoSnapshots))
      )
    )
    (if (or (null oldXrecSnap) (/= (length oldAnnoSnapshots) (length oldAnnoEnts)))
      (progn
        (setq txActive nil txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert "Gagal mengambil snapshot lengkap metadata/anotasi lama. Edit dibatalkan.")
        (exit)
      )
    )

    ;; Bangun & validasi newSpec
    (setq newSpec (fn-edit-build-new-spec)
          valErrs (asgrid:meta-validate-spec newSpec))
    (if valErrs
      (progn
        (setq txActive nil txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Validasi metadata baru gagal:\n" (car valErrs)))
        (exit)
      )
    )

    ;; STEP B — CREATE (Anotasi sementara dengan RegApp ASGRID_TX_TMP)
    (setq txStage   "STEP-B-CREATE"
          expCounts (asgrid:calc-expected-counts newSpec)
          expL      (nth 0 expCounts)
          expB      (nth 1 expCounts)
          expT      (nth 2 expCounts)
          expTot    (nth 3 expCounts)
          tempSpec  (append newSpec (list (cons "_XDATA_APP_OVERRIDE" (asgrid:xdata-tmp-app))))
          annRes    (asgrid:annotation-engine tempSpec)
          txNewAnnoEnts (nth 0 annRes)
          cntB      (nth 1 annRes)
          cntT      (nth 2 annRes))

    (if (or (/= cntB expB) (/= cntT expT))
      (progn
        (fn-edit-rollback (strcat "STEP B gagal membuat anotasi sementara (B:"
                                  (itoa cntB) "/" (itoa expB) " T:" (itoa cntT) "/" (itoa expT) ")"))
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert "Gagal membuat seluruh anotasi sementara. Anotasi lama tetap dipertahankan.")
        (exit)
      )
    )

    ;; STEP C — VERIFY (Verifikasi eksplisit atas daftar ename sementara)
    (setq txStage "STEP-C-VERIFY"
          verRes  (fn-edit-verify-temp-annos txNewAnnoEnts newSpec expB expT)
          verOk   (nth 0 verRes)
          verErr  (nth 3 verRes))
    (if (not verOk)
      (progn
        (fn-edit-rollback (strcat "STEP C verifikasi gagal: " verErr))
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Verifikasi anotasi sementara gagal:\n" verErr
                       "\n\nAnotasi lama dan metadata tetap dipertahankan."))
        (exit)
      )
    )

    ;; STEP D — SWAP (1. Hapus anotasi lama; 2. Promosikan temp XData -> final ASGRID_OBJ)
    (setq txStage "STEP-D-SWAP")
    (foreach e oldAnnoEnts
      (if (and e (entget e))
        (progn
          (entdel e)
          (setq txDeletedOldEnts (cons e txDeletedOldEnts))
        )
      )
    )
    (if (/= (length txDeletedOldEnts) (length oldAnnoEnts))
      (progn
        (fn-edit-rollback "STEP D gagal menghapus seluruh anotasi lama")
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert "Gagal menghapus seluruh anotasi lama. Rollback telah dijalankan.")
        (exit)
      )
    )
    (if (not (fn-edit-promote-temp-to-final txNewAnnoEnts))
      (progn
        (fn-edit-rollback "STEP D gagal mengonversi XData sementara ke ASGRID_OBJ final")
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert "Gagal mengonversi identitas XData final. Rollback telah dijalankan.")
        (exit)
      )
    )

    ;; STEP E — UPDATE METADATA & READ-BACK VERIFICATION
    (setq txStage "STEP-E-UPDATE-META")
    (if (not (asgrid:meta-update-group groupId newSpec))
      (progn
        (fn-edit-rollback "STEP E gagal memperbarui XRecord metadata di NOD")
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert "Gagal memperbarui metadata grup. Rollback telah dijalankan.")
        (exit)
      )
    )
    (setq txMetaUpdated T)

    (setq readBack (asgrid:meta-read-group groupId)
          readErrs (if readBack (asgrid:meta-validate-spec readBack) '("XRecord gagal dibaca balik."))
          cmpDiffs (if (and readBack (null readErrs)) (asgrid:meta-compare-specs newSpec readBack) nil))
    (if (or (null readBack) readErrs cmpDiffs)
      (progn
        (setq abortMsg (cond (readErrs (car readErrs)) (cmpDiffs (car cmpDiffs)) (t "Read-back kosong.")))
        (fn-edit-rollback (strcat "STEP E verifikasi metadata gagal: " abortMsg))
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Verifikasi metadata pasca-update gagal:\n" abortMsg "\n\nRollback telah dijalankan."))
        (exit)
      )
    )

    ;; STEP F — FINAL VERIFY & COMMIT
    (setq txStage    "STEP-F-FINAL-AUDIT"
          finalAudit (asgrid:audit-group-entities groupId readBack))
    (if (or (not (cdr (assoc "IS_HEALTHY" finalAudit)))
            (/= (cdr (assoc "ACT_L" finalAudit)) (length oldLineEnts))
            (not (fn-edit-verify-lines-intact oldLineSnapCoords)))
      (progn
        (fn-edit-rollback "STEP F final audit atau verifikasi keutuhan LINE gagal")
        (setq txAbortedByCode T)
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert "Final audit pasca-edit gagal. Rollback telah dijalankan.")
        (exit)
      )
    )

    ;; COMMIT TRANSAKSI
    (setq txActive         nil
          txNewAnnoEnts    '()
          txDeletedOldEnts '()
          txMetaUpdated    nil)
    (command "_.UNDO" "_End")
    (setq undoOpen nil)
    (setvar "CMDECHO" oldCmdEcho)

    ;; Laporan sukses
    (princ "\n------------------------------------------------------------")
    (princ (strcat "\n[" VER_LABEL "] SELESAI - ANOTASI GRUP '" groupId "' DIPERBARUI"))
    (princ "\n------------------------------------------------------------")
    (princ (strcat "\n  Bubble Diameter (mm) : " (rtos (cdr (assoc "BUBBLE_DIA_PRINT" oldSpec)) 2 2)
                   " -> " (rtos newBubDia 2 2)))
    (princ (strcat "\n  Text Height (mm)     : " (rtos (cdr (assoc "TEXT_H_PRINT" oldSpec)) 2 2)
                   " -> " (rtos newTxtH 2 2)))
    (princ (strcat "\n  Text Style           : " (cdr (assoc "TEXT_STYLE" oldSpec))
                   " -> " newTxtStyle " (" newFontFile ")"))
    (princ (strcat "\n  Bubble Position      : " (cdr (assoc "BUBBLE_POS" oldSpec))
                   " -> " newBubPos))
    (princ (strcat "\n  Geometry EXT_LEN     : " (rtos (cdr (assoc "EXT_LEN" readBack)) 2 2) " mm (TIDAK BERUBAH)"))
    (princ (strcat "\n  Annotation EXT_LEN   : " (rtos (asgrid:get-anno-ext-len oldSpec) 2 2)
                   " -> " (rtos newAnnoExt 2 2) " mm"))
    (princ (strcat "\n  Final Audit          : Lines " (itoa (cdr (assoc "ACT_L" finalAudit))) "/" (itoa expL)
                   " (100% Utuh) | Bubbles " (itoa (cdr (assoc "ACT_B" finalAudit))) "/" (itoa expB)
                   " | Texts " (itoa (cdr (assoc "ACT_T" finalAudit))) "/" (itoa expT) " (OK)"))
    (princ "\n------------------------------------------------------------")
  )

  ;; --------------------------------------------------------------------------
  ;; 6. ALUR UTAMA PERINTAH ASGRIDEDIT
  ;; --------------------------------------------------------------------------
  (setq selInfo (fn-edit-select-and-validate))
  (if selInfo
    (progn
      (setq groupId      (nth 0 selInfo)
            oldSpec      (nth 1 selInfo)
            initAuditRes (nth 2 selInfo)
            styleList    (asgrid:list-drawing-styles))

      ;; Pastikan style lama grup masuk ke daftar bila ada di tabel STYLE
      (if (and (tblsearch "STYLE" (cdr (assoc "TEXT_STYLE" oldSpec)))
               (not (member (cdr (assoc "TEXT_STYLE" oldSpec)) styleList)))
        (setq styleList (cons (cdr (assoc "TEXT_STYLE" oldSpec)) styleList))
      )

      (setq dclFile (findfile "ASGRID_V2_2_1_R3.dcl"))
      (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1_R2.dcl")))
      (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2_1.dcl")))
      (if (null dclFile) (setq dclFile (findfile "ASGRID_V2_2.dcl")))
      (if (null dclFile)
        (progn
          (alert "File dialog 'ASGRID_V2_2_1_R3.dcl' tidak ditemukan pada Support File Search Path.")
          (princ (strcat "\n[" VER_LABEL " ERROR] File 'ASGRID_V2_2_1_R3.dcl' tidak ditemukan."))
        )
        (progn
          (setq dclId (load_dialog dclFile))
          (if (or (null dclId) (< dclId 0))
            (progn
              (alert (strcat "Gagal memuat file dialog '" dclFile "'."))
              (princ (strcat "\n[" VER_LABEL " ERROR] load_dialog gagal untuk '" dclFile "'."))
            )
            (if (not (new_dialog "asgrid_edit_v2_2" dclId))
              (progn
                (unload_dialog dclId)
                (setq dclId nil)
                (alert (strcat "Definisi dialog 'asgrid_edit_v2_2' tidak ditemukan di dalam '" dclFile "'."))
                (princ (strcat "\n[" VER_LABEL " ERROR] new_dialog gagal untuk 'asgrid_edit_v2_2'."))
              )
              (progn
                ;; Isi panel A (Read-Only) dari metadata grup
                (set_tile "ed_group_id"     (strcat "Group ID               : " groupId))
                (set_tile "ed_num_h"        (strcat "Horizontal Grids       : " (itoa (cdr (assoc "NUM_H" oldSpec)))))
                (set_tile "ed_num_v"        (strcat "Vertical Grids         : " (itoa (cdr (assoc "NUM_V" oldSpec)))))
                (set_tile "ed_scale"        (strcat "Drawing Scale (Locked) : 1:" (rtos (cdr (assoc "SCALE_DENOM" oldSpec)) 2 0)))
                (set_tile "ed_geom_ext"     (strcat "Geometry EXT_LEN       : " (rtos (cdr (assoc "EXT_LEN" oldSpec)) 2 2) " mm (Locked)"))
                (set_tile "ed_cur_anno_ext" (strcat "Current ANNO_EXT_LEN   : " (rtos (asgrid:get-anno-ext-len oldSpec) 2 2) " mm"
                                                    (if (assoc "ANNO_EXT_LEN" oldSpec) "" " (fallback EXT_LEN)")))

                ;; Isi panel B (Editable) dari metadata grup (bukan default generator)
                (set_tile "ed_bub_dia"    (rtos (cdr (assoc "BUBBLE_DIA_PRINT" oldSpec)) 2 2))
                (set_tile "ed_txt_height" (rtos (cdr (assoc "TEXT_H_PRINT" oldSpec)) 2 2))
                (set_tile "ed_anno_ext"   (rtos (asgrid:get-anno-ext-len oldSpec) 2 2))

                ;; Isi popup_list Text Style & pilih style aktif grup
                (start_list "ed_txt_style")
                (mapcar 'add_list styleList)
                (end_list)
                (set_tile "ed_txt_style"
                  (itoa (if (vl-position (cdr (assoc "TEXT_STYLE" oldSpec)) styleList)
                          (vl-position (cdr (assoc "TEXT_STYLE" oldSpec)) styleList)
                          0)))

                ;; Isi popup_list Bubble Position & pilih posisi aktif grup
                (start_list "ed_bub_pos")
                (mapcar 'add_list BUB_POS_LIST)
                (end_list)
                (set_tile "ed_bub_pos"
                  (itoa (if (vl-position (cdr (assoc "BUBBLE_POS" oldSpec)) BUB_POS_LIST)
                          (vl-position (cdr (assoc "BUBBLE_POS" oldSpec)) BUB_POS_LIST)
                          0)))

                ;; Render preview awal
                (fn-edit-update-preview)

                ;; Callback dialog
                (action_tile "ed_bub_dia"    "(fn-edit-update-preview)")
                (action_tile "ed_txt_height" "(fn-edit-update-preview)")
                (action_tile "ed_txt_style"  "(fn-edit-update-preview)")
                (action_tile "ed_bub_pos"    "(fn-edit-update-preview)")
                (action_tile "ed_anno_ext"   "(fn-edit-update-preview)")
                (action_tile "accept"        "(fn-edit-validate-dialog)")
                (action_tile "cancel"        "(done_dialog 0)")

                (setq dclRes (start_dialog))
                (unload_dialog dclId)
                (setq dclId nil)

                (if (= dclRes 1)
                  (fn-edit-execute-transaction)
                  (princ (strcat "\n[" VER_LABEL "] Dibatalkan oleh pengguna. Tidak ada perubahan pada DWG."))
                )
              )
            )
          )
        )
      )
    )
  )
  (princ)
)


;; Pesan saat file berhasil dimuat melalui APPLOAD
(princ "\n[ASGRID V2.2] Berhasil dimuat. Perintah: ASGRID | ASGRIDEDIT | ASGRIDCHECK.")
(princ)
