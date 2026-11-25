;;; ============================================================================
;;; PROGRAM     : ASGRID V2.1 - AUTOMATIC BUILDING GRID GENERATOR
;;;               (LIVE PREVIEW & METADATA FOUNDATION)
;;; TARGET      : AutoCAD 2021 (AutoLISP Standar + DCL)
;;; BASELINE    : ASGRID_V2.lsp (V2.0 tetap dipertahankan sebagai backup)
;;; FILE TERKAIT: ASGRID_V2_1.dcl (harus tersedia di Support File Search Path)
;;; UNIT        : Millimeter (mm) pada Model Space (WCS)
;;; COMMAND     : ASGRID
;;; FITUR V2.1  :
;;;   1. Live Preview pada dialog DCL (image tile, non-permanen, proporsional,
;;;      mendukung mode adaptif untuk jumlah grid banyak).
;;;   2. Fondasi Metadata DWG:
;;;      - Group Metadata disimpan di Named Object Dictionary ("ASGRID_GROUPS")
;;;        berupa XRecord per Group ID unik (ASG-0001, ASG-0002, ...).
;;;      - Object Identity disimpan via XData ("ASGRID_OBJ") pada tiap entitas
;;;        dengan Role (LINE/BUBBLE/TEXT), AxisDir, AxisIdx, dan EndTag.
;;;   3. Pemisahan tegas Geometry Engine & Annotation Engine yang membaca dari
;;;      satu struktur spesifikasi/metadata yang sama (siap untuk ASGRID EDIT).
;;; ============================================================================

(defun c:ASGRID ( /
                  ;; Error handler & state sistem
                  *error* oldCmdEcho undoOpen dclId
                  ;; Konstanta konfigurasi & metadata
                  PAGE_SIZE STYLE_NAME FONT_FILE BUB_POS_LIST
                  APP_NAME APP_VER SCHEMA_VER
                  DICT_NAME XDATA_APP
                  LAY_GRID LAY_BUBBLE LAY_TEXT
                  ;; Modul 2: Utilitas, Penomoran (V1.0/V2.0) & Parser Ketat
                  fn-index-to-alpha
                  fn-trim
                  fn-parse-pos-int
                  fn-parse-pos-real
                  fn-replace-nth
                  fn-resize-str-list
                  fn-pad-4
                  fn-get-timestamp
                  ;; Modul 3: Layer, Linetype & Text Style Arial (V2.0)
                  fn-ensure-linetype-center
                  fn-ensure-layer
                  fn-find-arial-ttf
                  fn-ensure-arial-style
                  ;; Modul 4: Fondasi Metadata DWG (NOD/XRecord + XData)
                  fn-make-obj-xdata
                  fn-meta-get-root-dict
                  fn-meta-list-group-ids
                  fn-meta-generate-next-id
                  fn-meta-build-spec
                  fn-meta-save-group
                  fn-meta-read-group
                  fn-meta-validate-spec
                  ;; Modul 5: Primitif Entitas WCS (entmake + XData Identity)
                  fn-draw-line
                  fn-draw-circle
                  fn-draw-text-mc
                  ;; Modul 6: Geometry Engine & Annotation Engine (Terpisah)
                  fn-compute-cumulative
                  fn-geometry-engine
                  fn-annotation-engine
                  fn-execute-grid-creation
                  ;; Modul 7: Live Preview Engine (DCL Image Tile - Terpisah)
                  fn-prev-draw-circle
                  fn-prev-draw-char
                  fn-prev-draw-string
                  fn-update-live-preview
                  ;; Modul 8: Manajemen Antarmuka DCL & Tabel Pagination (V2.0)
                  fn-refresh-h-table
                  fn-refresh-v-table
                  fn-update-scale-preview
                  fn-sync-grid-counts
                  fn-save-h-slot
                  fn-save-v-slot
                  fn-flush-active-page
                  ;; Modul 9: Validasi Input Terpusat (V2.0)
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
  (setq PAGE_SIZE    8
        STYLE_NAME   "ASGRID-ARIAL"
        FONT_FILE    "arial.ttf"
        BUB_POS_LIST '("Both Ends" "Start" "End")
        APP_NAME     "ASGRID"
        APP_VER      "2.1"
        SCHEMA_VER   "1.0"
        DICT_NAME    "ASGRID_GROUPS"
        XDATA_APP    "ASGRID_OBJ"
        LAY_GRID     "AS-GRID"
        LAY_BUBBLE   "AS-BUBBLE"
        LAY_TEXT     "AS-TEXT"
        oldCmdEcho   (getvar "CMDECHO")
        undoOpen     nil
        dclId        nil)

  ;; ==========================================================================
  ;; MODUL 1: ERROR HANDLER LOKAL (MEMULIHKAN DCL, UNDO, DAN CMDECHO)
  ;; ==========================================================================
  (defun *error* (msg)
    (if (and dclId (>= dclId 0))
      (progn
        (unload_dialog dclId)
        (setq dclId nil)
      )
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
    (if (and msg
             (not (member msg '("Function cancelled"
                                "quit / exit abort"
                                "console break"))))
      (princ (strcat "\n[ASGRID V2.1 ERROR] " msg))
      (princ "\n[ASGRID V2.1] Proses dibatalkan oleh pengguna.")
    )
    (princ)
  )

  ;; ==========================================================================
  ;; MODUL 2: UTILITAS, PENOMORAN HURUF (V1.0/V2.0), DAN PARSER VALIDASI KETAT
  ;; ==========================================================================

  ;; Konversi indeks berbasis-1 (1,2,...) ke huruf (A..Z, AA, AB, ...)
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

  ;; Hapus spasi/tab di awal dan akhir string
  (defun fn-trim (s / res)
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
  (defun fn-parse-pos-int (s / clean len idx ch ok val)
    (setq clean (fn-trim s)
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
  (defun fn-parse-pos-real (s / clean val)
    (setq clean (fn-trim s))
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

  ;; Ganti elemen ke-idx (berbasis-0) dalam sebuah list
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

  ;; Sesuaikan panjang list string spacing ke targetLen sambil menjaga nilai lama
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

  ;; Format integer menjadi minimal 4 digit (contoh: 1 -> "0001")
  (defun fn-pad-4 (n / s)
    (setq s (itoa n))
    (while (< (strlen s) 4)
      (setq s (strcat "0" s))
    )
    s
  )

  ;; Ambil timestamp lokal dari CDATE AutoCAD (YYYY-MM-DD HH:MM:SS)
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
            "ASGRID V2.1 tidak akan mengganti font secara diam-diam.\n"
            "Pastikan font Arial terpasang di Windows Fonts atau Support File Search Path AutoCAD."
          )
        )
        (princ (strcat "\n[ASGRID V2.1 ERROR] Font '" FONT_FILE "' tidak ditemukan. Proses dihentikan."))
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
                (princ (strcat "\n[ASGRID V2.1 ERROR] Style '" STYLE_NAME "' memakai font lain (" existingFont ")."))
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
                (princ (strcat "\n[ASGRID V2.1 ERROR] Gagal membuat Text Style '" STYLE_NAME "'."))
              )
            )
          )
        )
        ok
      )
    )
  )

  ;; ==========================================================================
  ;; MODUL 4: FONDASI METADATA DWG (NOD/XRECORD + XDATA OBJECT IDENTITY)
  ;; ==========================================================================

  ;; Bangun daftar XData ringan untuk identitas setiap objek AutoCAD
  ;; role   : "LINE" | "BUBBLE" | "TEXT"
  ;; axisDir: "H" | "V"
  ;; axisIdx: integer berbasis-1 (1, 2, 3...)
  ;; endTag : "NONE" | "START" | "END"
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

  ;; Ambil atau buat Named Object Dictionary khusus "ASGRID_GROUPS"
  ;; createIfMissing = T saat menyimpan; nil saat hanya membaca/preview
  (defun fn-meta-get-root-dict (createIfMissing / nod dictRec dictEname newDict)
    (setq nod     (namedobjdict)
          dictRec (dictsearch nod DICT_NAME))
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
              (dictadd nod DICT_NAME newDict)
              newDict
            )
            nil
          )
        )
        nil
      )
    )
  )

  ;; Kumpulkan seluruh Group ID yang ada di NOD maupun XData objek (anti bentrok)
  (defun fn-meta-list-group-ids ( / rootDict ids entData ss i ename xrec gid)
    (setq ids '())
    ;; 1. Dari Named Object Dictionary ASGRID_GROUPS
    (setq rootDict (fn-meta-get-root-dict nil))
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
    ;; 2. Pengaman ekstra: pindai objek yang membawa XData ASGRID_OBJ
    (setq ss (ssget "_X" (list (list -3 (list XDATA_APP)))))
    (if ss
      (progn
        (setq i 0)
        (while (< i (sslength ss))
          (setq ename   (ssname ss i)
                entData (entget ename (list XDATA_APP))
                xrec    (cadr (assoc -3 entData)))
          (if (and xrec (assoc 1000 (cdr xrec)))
            (progn
              (setq gid (cdr (assoc 1000 (cdr xrec))))
              (if (and (= (type gid) 'STR) (not (member gid ids)))
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

  ;; Hasilkan Group ID unik berikutnya (ASG-0001, ASG-0002, ...)
  (defun fn-meta-generate-next-id ( / existingIds maxNum gid numPart)
    (setq existingIds (fn-meta-list-group-ids)
          maxNum      0)
    (foreach gid existingIds
      (if (and (>= (strlen gid) 5)
               (= (strcase (substr gid 1 4)) "ASG-"))
        (progn
          (setq numPart (fn-parse-pos-int (substr gid 5)))
          (if (and numPart (> numPart maxNum))
            (setq maxNum numPart)
          )
        )
      )
    )
    (strcat "ASG-" (fn-pad-4 (1+ maxNum)))
  )

  ;; Bangun struktur asosiasi terpadu (single source of truth) untuk metadata & engine
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

  ;; Validasi kelengkapan & konsistensi struktur spec/metadata
  ;; Mengembalikan list pesan error (nil jika valid 100%)
  (defun fn-meta-validate-spec (spec / errs reqKeys k nH nV dH dV)
    (setq errs '()
          reqKeys '("SCHEMA_VER" "GROUP_ID" "MODULE" "GENERATOR_VER"
                    "NUM_H" "NUM_V" "DIST_H" "DIST_V" "BASE_PT_WCS"
                    "SCALE_DENOM" "TEXT_H_PRINT" "BUBBLE_DIA_PRINT"
                    "EXT_LEN" "BUBBLE_POS" "TEXT_STYLE"
                    "LAYER_GRID" "LAYER_BUBBLE" "LAYER_TEXT"))
    (foreach k reqKeys
      (if (null (assoc k spec))
        (setq errs (append errs (list (strcat "Key metadata hilang: " k))))
      )
    )
    (if (null errs)
      (progn
        (setq nH (cdr (assoc "NUM_H" spec))
              nV (cdr (assoc "NUM_V" spec))
              dH (cdr (assoc "DIST_H" spec))
              dV (cdr (assoc "DIST_V" spec)))
        (if (/= (length dH) (max 0 (1- nH)))
          (setq errs (append errs (list "Jumlah DIST_H tidak sama dengan NUM_H - 1.")))
        )
        (if (/= (length dV) (max 0 (1- nV)))
          (setq errs (append errs (list "Jumlah DIST_V tidak sama dengan NUM_V - 1.")))
        )
        (if (or (<= (cdr (assoc "SCALE_DENOM" spec)) 0.0)
                (<= (cdr (assoc "TEXT_H_PRINT" spec)) 0.0)
                (<= (cdr (assoc "BUBBLE_DIA_PRINT" spec)) 0.0)
                (<= (cdr (assoc "EXT_LEN" spec)) 0.0))
          (setq errs (append errs (list "Parameter skala/anotasi harus > 0.")))
        )
      )
    )
    errs
  )

  ;; Simpan Group Metadata sebagai XRecord di dalam NOD "ASGRID_GROUPS"
  ;; Tidak pernah menimpa Group ID yang sudah ada.
  (defun fn-meta-save-group (spec / rootDict groupId xrecData xrecEname dVal)
    (setq groupId  (cdr (assoc "GROUP_ID" spec))
          rootDict (fn-meta-get-root-dict T))
    (cond
      ((null rootDict)
       (princ "\n[ASGRID V2.1 ERROR] Gagal membuat/mengakses Named Object Dictionary ASGRID_GROUPS.")
       nil)
      ((dictsearch rootDict groupId)
       (princ (strcat "\n[ASGRID V2.1 ERROR] Group ID '" groupId "' sudah ada di DWG; penimpaan dicegah."))
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
         (progn
           (dictadd rootDict groupId xrecEname)
           xrecEname
         )
         nil
       ))
    )
  )

  ;; Baca kembali Group Metadata dari NOD XRecord ke format spec asosiasi
  ;; (Dipakai untuk verifikasi V2.1 dan siap dipakai langsung oleh ASGRID EDIT)
  (defun fn-meta-read-group (groupId / rootDict rec dList res dH dV curKey pair code val)
    (setq rootDict (fn-meta-get-root-dict nil))
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

  ;; ==========================================================================
  ;; MODUL 5: PRIMITIF ENTITAS WCS VIA ENTMAKE + XDATA OBJECT IDENTITY
  ;; ==========================================================================
  (defun fn-draw-line (p1 p2 layName xdata)
    (entmake
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

  (defun fn-draw-circle (cpt rad layName xdata)
    (entmake
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

  (defun fn-draw-text-mc (cpt txtH txtStr layName styleName xdata)
    (entmake
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
        (cons 72 1) ; Horizontal: Center
        (cons 11 cpt)
        (cons 100 "AcDbText")
        (cons 73 2) ; Vertical: Middle
        xdata
      )
    )
  )

  ;; ==========================================================================
  ;; MODUL 6: GEOMETRY ENGINE & ANNOTATION ENGINE (MEMBACA SPEC YANG SAMA)
  ;; ==========================================================================

  ;; Hitung list koordinat kumulatif dari titik awal dan daftar jarak
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

  ;; Koordinator eksekusi pembuatan grid, penyimpanan metadata, & ringkasan
  (defun fn-execute-grid-creation (ptWcs /
                                    groupId spec metaErrs readBack readErrs
                                    cntLine annRes cntBubble cntText
                                    cumY cumX totalY totalX x0 y0 z0
                                    textHModel bubDiaModel
                                  )
    (princ "\n[ASGRID V2.1] Memproses metadata, layer, Text Style Arial, dan geometri grid...")
    (setvar "CMDECHO" 0)
    (command "_.UNDO" "_Begin")
    (setq undoOpen T)

    ;; 1. Pastikan Text Style Arial valid sebelum membuat objek apa pun
    (if (not (fn-ensure-arial-style))
      (progn
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (exit)
      )
    )

    ;; 2. Daftarkan RegApp XData untuk Object Identity
    (regapp XDATA_APP)

    ;; 3. Pastikan linetype dan layer tersedia
    (if (not (fn-ensure-linetype-center))
      (princ "\n  [Peringatan] Linetype CENTER gagal dimuat; layer AS-GRID akan memakai CONTINUOUS.")
    )
    (fn-ensure-layer LAY_GRID   "CENTER"     8)
    (fn-ensure-layer LAY_BUBBLE "CONTINUOUS" 2)
    (fn-ensure-layer LAY_TEXT   "CONTINUOUS" 7)

    ;; 4. Bangun Group ID unik & Group Metadata Spec
    (setq groupId  (fn-meta-generate-next-id)
          spec     (fn-meta-build-spec groupId ptWcs)
          metaErrs (fn-meta-validate-spec spec))

    (if metaErrs
      (progn
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert (strcat "Validasi metadata gagal:\n" (car metaErrs)))
        (exit)
      )
    )

    ;; 5. Simpan Group Metadata ke NOD XRecord & verifikasi baca balik
    (if (null (fn-meta-save-group spec))
      (progn
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (alert "Gagal menyimpan metadata kelompok grid ke DWG.")
        (exit)
      )
    )
    (setq readBack (fn-meta-read-group groupId)
          readErrs (if readBack (fn-meta-validate-spec readBack) '("XRecord gagal dibaca balik.")))
    (if readErrs
      (princ (strcat "\n  [Peringatan Metadata] " (car readErrs)))
    )

    ;; 6. Jalankan Geometry Engine dan Annotation Engine dari spec yang sama
    (setq cntLine   (fn-geometry-engine spec)
          annRes    (fn-annotation-engine spec)
          cntBubble (car annRes)
          cntText   (cadr annRes))

    ;; 7. Tutup grup UNDO & pulihkan CMDECHO
    (command "_.UNDO" "_End")
    (setq undoOpen nil)
    (setvar "CMDECHO" oldCmdEcho)

    ;; 8. Ringkasan hasil di command line
    (setq x0          (car (cdr (assoc "BASE_PT_WCS" spec)))
          y0          (cadr (cdr (assoc "BASE_PT_WCS" spec)))
          z0          (caddr (cdr (assoc "BASE_PT_WCS" spec)))
          cumY        (fn-compute-cumulative y0 (cdr (assoc "DIST_H" spec)))
          cumX        (fn-compute-cumulative x0 (cdr (assoc "DIST_V" spec)))
          totalY      (- (last cumY) y0)
          totalX      (- (last cumX) x0)
          textHModel  (* (cdr (assoc "TEXT_H_PRINT" spec)) (cdr (assoc "SCALE_DENOM" spec)))
          bubDiaModel (* (cdr (assoc "BUBBLE_DIA_PRINT" spec)) (cdr (assoc "SCALE_DENOM" spec))))

    (princ "\n--------------------------------------------------------")
    (princ "\n[ASGRID V2.1] SELESAI - RINGKASAN PEMBUATAN GRID")
    (princ "\n--------------------------------------------------------")
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
    (princ (strcat "\n  Objek dibuat         : " (itoa cntLine) " garis as, "
                                              (itoa cntBubble) " bubble, "
                                              (itoa cntText) " teks."))
    (princ (strcat "\n  Status Metadata      : " (if readErrs "PERINGATAN" "TERSIMPAN & TERVALIDASI")))
    (princ "\n--------------------------------------------------------")
  )

  ;; ==========================================================================
  ;; MODUL 7: LIVE PREVIEW ENGINE (DCL IMAGE TILE - TERPISAH DARI GENERATE)
  ;; ==========================================================================

  ;; Gambar lingkaran poligon 12-segmen pada DCL image tile via vector_image
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

  ;; Mini stroke-font 4x6 piksel berbasis vector_image untuk angka 0-9 & huruf A-Z
  ;; Koordinat segmen dalam grid lokal (0..4, 0..6), y mengarah ke bawah
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

  ;; Gambar string label (misal "1", "12", "A", "AA") terpusat di (cx, cy)
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

  ;; Render Live Preview secara proporsional di image tile "grid_preview"
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

    ;; Baca parameter aktif dari state & dialog (fallback aman bila user sedang mengetik)
    (setq pH     (if (fn-parse-pos-int (get_tile "num_h")) (fn-parse-pos-int (get_tile "num_h")) curNumH)
          pV     (if (fn-parse-pos-int (get_tile "num_v")) (fn-parse-pos-int (get_tile "num_v")) curNumV)
          sc     (if (fn-parse-pos-real (get_tile "scale_denom")) (fn-parse-pos-real (get_tile "scale_denom")) 100.0)
          th     (if (fn-parse-pos-real (get_tile "txt_height")) (fn-parse-pos-real (get_tile "txt_height")) 2.5)
          bd     (if (fn-parse-pos-real (get_tile "bub_dia")) (fn-parse-pos-real (get_tile "bub_dia")) 8.0)
          ex     (if (fn-parse-pos-real (get_tile "ext_len")) (fn-parse-pos-real (get_tile "ext_len")) 1500.0)
          posIdx (atoi (get_tile "bub_pos"))
          bPos   (if (and (>= posIdx 0) (< posIdx (length BUB_POS_LIST)))
                   (nth posIdx BUB_POS_LIST)
                   "Both Ends"))

    ;; Konversi daftar spacing aktif ke angka positif (fallback 4000 bila sementara kosong/invalid)
    (setq dH '()
          dV '()
          okData T)
    (foreach s strListH
      (setq val (fn-parse-pos-real s))
      (if val
        (setq dH (append dH (list val)))
        (progn (setq dH (append dH (list 4000.0))) (setq okData nil))
      )
    )
    (foreach s strListV
      (setq val (fn-parse-pos-real s))
      (if val
        (setq dV (append dV (list val)))
        (progn (setq dV (append dV (list 4000.0))) (setq okData nil))
      )
    )

    ;; Hitung bounding box model space
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

    ;; Ukuran proporsional bubble & teks (dengan batas keterbacaan di canvas DCL)
    (setq bubRadPx (max 3.0 (min 11.0 (* bubRadModel scalePx)))
          txtHPx   (max 4.0 (min (* bubRadPx 1.2) (* th sc scalePx))))

    ;; Mode adaptif untuk jumlah grid banyak agar bubble & label tidak tumpang tindih
    (setq stepH     (if (> (length cumY) 10) (max 1 (/ (length cumY) 6)) 1)
          stepV     (if (> (length cumX) 10) (max 1 (/ (length cumX) 6)) 1)
          denseMode (or (> stepH 1) (> stepV 1)))

    ;; Mulai menggambar di DCL image tile (100% non-permanen)
    (start_image "grid_preview")
    (fill_image 0 0 w h 0) ; Latar hitam ala Model Space

    ;; Bingkai tipis preview
    (vector_image 0 0 (1- w) 0 8)
    (vector_image (1- w) 0 (1- w) (1- h) 8)
    (vector_image (1- w) (1- h) 0 (1- h) 8)
    (vector_image 0 (1- h) 0 0 8)

    ;; 1. Gambar garis as horizontal & bubble
    (setq px1 (fix (+ offX (* (- (- 0.0 ex) minX) scalePx) 0.5))
          px2 (fix (+ offX (* (- (+ totalX ex) minX) scalePx) 0.5))
          i   1)
    (foreach curY cumY
      (setq py1 (fix (- (1- h) (+ offY (* (- curY minY) scalePx)) 0.5))
            lbl (itoa i))
      ;; Garis grid horizontal (warna 9 = abu-abu terang)
      (vector_image px1 py1 px2 py1 9)

      ;; Bubble & label (tampilkan penuh atau sampling adaptif di mode padat)
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

    ;; 2. Gambar garis as vertikal & bubble
    (setq py1 (fix (- (1- h) (+ offY (* (- (- 0.0 ex) minY) scalePx)) 0.5))
          py2 (fix (- (1- h) (+ offY (* (- (+ totalY ex) minY) scalePx)) 0.5))
          i   1)
    (foreach curX cumX
      (setq px1 (fix (+ offX (* (- curX minX) scalePx) 0.5))
            lbl (fn-index-to-alpha i))
      ;; Garis grid vertikal (warna 9 = abu-abu terang)
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

    ;; Perbarui teks ringkasan di bawah preview
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
  ;; MODUL 8: MANAJEMEN ANTARMUKA DCL & TABEL PAGINATION (V2.0 + HOOK PREVIEW)
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
    (setq pH (fn-parse-pos-int (get_tile "num_h"))
          pV (fn-parse-pos-int (get_tile "num_v")))
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
    (setq sc (fn-parse-pos-real (get_tile "scale_denom"))
          th (fn-parse-pos-real (get_tile "txt_height"))
          bd (fn-parse-pos-real (get_tile "bub_dia")))
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
  ;; MODUL 9: VALIDASI INPUT TERPUSAT SEBELUM DIALOG DITUTUP (V2.0)
  ;; ==========================================================================
  (defun fn-validate-all ( / pH pV sc th bd ex posIdx idx val parsedH parsedV errSlot ok)
    (fn-flush-active-page)
    (setq ok T)

    ;; 1. Validasi jumlah grid horizontal & vertikal
    (setq pH (fn-parse-pos-int (get_tile "num_h"))
          pV (fn-parse-pos-int (get_tile "num_v")))
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

    ;; 2. Validasi jumlah & nilai spacing horizontal (harus = numH - 1)
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
              (setq val (fn-parse-pos-real (nth idx strListH)))
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

    ;; 3. Validasi jumlah & nilai spacing vertikal (harus = numV - 1)
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
              (setq val (fn-parse-pos-real (nth idx strListV)))
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

    ;; 4. Validasi Scale, Text Height, Bubble Diameter, Extension, Bubble Position
    (if ok
      (progn
        (setq sc     (fn-parse-pos-real (get_tile "scale_denom"))
              th     (fn-parse-pos-real (get_tile "txt_height"))
              bd     (fn-parse-pos-real (get_tile "bub_dia"))
              ex     (fn-parse-pos-real (get_tile "ext_len"))
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
             (princ "\n[ASGRID V2.1 Peringatan] Diameter bubble cetak <= tinggi teks cetak; teks dapat melewati bubble.")
           )
           (done_dialog 1))
        )
      )
    )
  )

  ;; ==========================================================================
  ;; ALUR UTAMA PROGRAM ASGRID V2.1
  ;; ==========================================================================

  ;; 1. Temukan dan muat file DCL V2.1
  (setq dclFile (findfile "ASGRID_V2_1.dcl"))
  (if (null dclFile)
    (progn
      (alert
        (strcat
          "File dialog 'ASGRID_V2_1.dcl' tidak ditemukan!\n\n"
          "Pastikan 'ASGRID_V2_1.dcl' disimpan pada folder yang terdaftar di\n"
          "AutoCAD Options -> Files -> Support File Search Path."
        )
      )
      (princ "\n[ASGRID V2.1 ERROR] File 'ASGRID_V2_1.dcl' tidak ditemukan.")
      (princ)
    )
    (progn
      (setq dclId (load_dialog dclFile))
      (if (or (null dclId) (< dclId 0))
        (progn
          (alert "Gagal memuat file dialog 'ASGRID_V2_1.dcl'.")
          (princ "\n[ASGRID V2.1 ERROR] load_dialog gagal untuk 'ASGRID_V2_1.dcl'.")
          (princ)
        )
        (if (not (new_dialog "asgrid_v2_1" dclId))
          (progn
            (unload_dialog dclId)
            (setq dclId nil)
            (alert "Definisi dialog 'asgrid_v2_1' tidak ditemukan di dalam 'ASGRID_V2_1.dcl'.")
            (princ "\n[ASGRID V2.1 ERROR] new_dialog gagal untuk 'asgrid_v2_1'.")
            (princ)
          )
          (progn
            ;; 2. Inisialisasi nilai default dialog
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
              (strcat "Next Group ID: " nextGroupIdPreview " (Saved in DWG Metadata)"))

            ;; Isi popup_list Bubble Position
            (start_list "bub_pos")
            (mapcar 'add_list BUB_POS_LIST)
            (end_list)
            (set_tile "bub_pos" "0")

            ;; Cek status font Arial
            (setq arialPath (fn-find-arial-ttf))
            (if arialPath
              (set_tile "font_status" (strcat "Status: Font Arial tersedia (" arialPath ")"))
              (set_tile "font_status" "PERINGATAN: File font arial.ttf TIDAK ditemukan pada sistem!")
            )

            ;; Render tabel spacing, pratinjau skala, dan Live Preview awal
            (fn-refresh-h-table)
            (fn-refresh-v-table)
            (fn-update-scale-preview)

            ;; 3. Daftarkan callback tile DCL
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

            ;; 4. Tampilkan dialog
            (setq dclRes (start_dialog))
            (unload_dialog dclId)
            (setq dclId nil)

            ;; 5. Jika OK (dclRes = 1), minta titik awal lalu jalankan engine V2.1
            (if (= dclRes 1)
              (progn
                (setq basePtUcs (getpoint "\n[ASGRID V2.1] Klik titik awal grid (pojok kiri bawah): "))
                (if basePtUcs
                  (progn
                    (setq basePt (trans basePtUcs 1 0))
                    (fn-execute-grid-creation basePt)
                  )
                  (princ "\n[ASGRID V2.1] Titik awal tidak dipilih. Proses dibatalkan tanpa mengubah gambar.")
                )
              )
              (princ "\n[ASGRID V2.1] Dibatalkan oleh pengguna. Tidak ada objek yang dibuat.")
            )
            (princ)
          )
        )
      )
    )
  )
)

;; Pesan saat file berhasil dimuat melalui APPLOAD
(princ "\n[ASGRID V2.1] Berhasil dimuat. Pastikan ASGRID_V2_1.dcl tersedia, lalu ketik ASGRID.")
(princ)
