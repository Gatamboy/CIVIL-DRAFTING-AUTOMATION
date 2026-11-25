;;; ============================================================================
;;; PROGRAM     : ASGRID V2.0 - AUTOMATIC BUILDING GRID GENERATOR (DCL EDITION)
;;; TARGET      : AutoCAD 2021 (Kompatibel AutoLISP Standar + DCL)
;;; FILE TERKAIT: ASGRID_V2.dcl (harus tersedia di Support File Search Path)
;;; UNIT        : Millimeter (mm) pada Model Space (WCS)
;;; COMMAND     : ASGRID
;;; PEMBARUAN   : Antarmuka input DCL dengan tabel spacing individual dinamis,
;;;               validasi terpusat sebelum dialog ditutup, serta Text Style
;;;               khusus ASGRID-ARIAL (arial.ttf) tanpa mengubah style lain.
;;; ============================================================================

(defun c:ASGRID ( /
                  ;; Error handler & state sistem
                  *error* oldCmdEcho undoOpen dclId
                  ;; Konstanta UI & style
                  PAGE_SIZE STYLE_NAME FONT_FILE BUB_POS_LIST
                  ;; Fungsi lokal Modul 2: Utilitas & Penomoran (V1.0 + Parser)
                  fn-index-to-alpha
                  fn-trim
                  fn-parse-pos-int
                  fn-parse-pos-real
                  fn-replace-nth
                  fn-resize-str-list
                  ;; Fungsi lokal Modul 3: Layer, Linetype & Font Arial
                  fn-ensure-linetype-center
                  fn-ensure-layer
                  fn-find-arial-ttf
                  fn-ensure-arial-style
                  ;; Fungsi lokal Modul 4: Pembuatan Entitas WCS via entmake (V1.0)
                  fn-draw-line
                  fn-draw-circle
                  fn-draw-text-mc
                  ;; Fungsi lokal Modul 5: Manajemen Antarmuka DCL
                  fn-refresh-h-table
                  fn-refresh-v-table
                  fn-update-scale-preview
                  fn-sync-grid-counts
                  fn-save-h-slot
                  fn-save-v-slot
                  ;; Fungsi lokal Modul 6: Validasi Input Terpusat
                  fn-validate-all
                  ;; Fungsi lokal Modul 7: Eksekusi Geometri Grid (V1.0)
                  fn-generate-grid
                  ;; State dialog DCL
                  dclFile dclRes
                  curNumH curNumV
                  strListH strListV
                  pageH pageV
                  arialPath
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
      (princ (strcat "\n[ASGRID V2.0 ERROR] " msg))
      (princ "\n[ASGRID V2.0] Proses dibatalkan oleh pengguna.")
    )
    (princ)
  )

  ;; ==========================================================================
  ;; MODUL 2: UTILITAS, PENOMORAN HURUF (V1.0), DAN PARSER VALIDASI KETAT
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

  ;; Hapus spasi di awal dan akhir string (AutoLISP standar)
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

  ;; Parse bilangan bulat positif ketat (menolak huruf, desimal, nol, negatif)
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

  ;; Parse bilangan real positif ketat via distof (menolak teks/nol/negatif)
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

  ;; ==========================================================================
  ;; MODUL 3: LINETYPE, LAYER (V1.0), DAN TEXT STYLE KHUSUS ARIAL (V2.0)
  ;; ==========================================================================

  ;; Pastikan linetype CENTER tersedia (memuat acadiso.lin / fallback entmake)
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

  ;; Buat layer hanya jika belum ada (tidak merusak layer eksisting)
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

  ;; Cari file font arial.ttf di Support Path AutoCAD atau folder Fonts Windows
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

  ;; Pastikan Text Style ASGRID-ARIAL menggunakan arial.ttf tanpa mengubah
  ;; Text Style aktif maupun style milik objek lain dalam gambar.
  ;; Mengembalikan T jika siap digunakan, atau nil jika font tidak tersedia.
  (defun fn-ensure-arial-style ( / tblRec existingFont ok)
    (setq ok nil)
    (if (null (fn-find-arial-ttf))
      (progn
        (alert
          (strcat
            "PERINGATAN: File font '" FONT_FILE "' (Arial) tidak ditemukan pada sistem.\n\n"
            "ASGRID V2.0 tidak akan mengganti font secara diam-diam.\n"
            "Pastikan font Arial terpasang di Windows Fonts atau Support File Search Path AutoCAD."
          )
        )
        (princ (strcat "\n[ASGRID V2.0 ERROR] Font '" FONT_FILE "' tidak ditemukan. Proses dihentikan."))
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
                (princ (strcat "\n[ASGRID V2.0 ERROR] Style '" STYLE_NAME "' memakai font lain (" existingFont ")."))
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
                    (cons 40 0.0)        ; Tinggi dinamis (0.0) agar mengikuti skala cetak
                    (cons 41 1.0)        ; Width factor 1.0
                    (cons 50 0.0)        ; Oblique angle 0.0
                    (cons 71 0)          ; Normal orientation
                    (cons 42 2.5)        ; Last height
                    (cons 3 FONT_FILE)   ; arial.ttf
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
                (princ (strcat "\n[ASGRID V2.0 ERROR] Gagal membuat Text Style '" STYLE_NAME "'."))
              )
            )
          )
        )
        ok
      )
    )
  )

  ;; ==========================================================================
  ;; MODUL 4: PEMBUATAN ENTITAS LANGSUNG PADA WCS VIA ENTMAKE (V1.0)
  ;; ==========================================================================
  (defun fn-draw-line (p1 p2 layName)
    (entmake
      (list
        (cons 0 "LINE")
        (cons 100 "AcDbEntity")
        (cons 8 layName)
        (cons 100 "AcDbLine")
        (cons 10 p1)
        (cons 11 p2)
      )
    )
  )

  (defun fn-draw-circle (cpt rad layName)
    (entmake
      (list
        (cons 0 "CIRCLE")
        (cons 100 "AcDbEntity")
        (cons 8 layName)
        (cons 100 "AcDbCircle")
        (cons 10 cpt)
        (cons 40 rad)
      )
    )
  )

  ;; Teks selalu ditempatkan di tengah bubble (Middle Center) menggunakan STYLE_NAME
  (defun fn-draw-text-mc (cpt txtH txtStr layName)
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
        (cons 7 STYLE_NAME)
        (cons 72 1) ; Horizontal: Center
        (cons 11 cpt)
        (cons 100 "AcDbText")
        (cons 73 2) ; Vertical: Middle
      )
    )
  )

  ;; ==========================================================================
  ;; MODUL 5: MANAJEMEN ANTARMUKA DCL & TABEL SPACING DINAMIS
  ;; ==========================================================================

  ;; Render ulang 8 baris tabel interval Horizontal sesuai halaman aktif
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

  ;; Render ulang 8 baris tabel interval Vertikal sesuai halaman aktif
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

  ;; Simpan perubahan nilai satu baris tabel Horizontal ke strListH
  (defun fn-save-h-slot (slot valStr / idx)
    (setq idx (+ (* pageH PAGE_SIZE) (1- slot)))
    (if (< idx (length strListH))
      (setq strListH (fn-replace-nth idx valStr strListH))
    )
    (set_tile "error" "")
  )

  ;; Simpan perubahan nilai satu baris tabel Vertikal ke strListV
  (defun fn-save-v-slot (slot valStr / idx)
    (setq idx (+ (* pageV PAGE_SIZE) (1- slot)))
    (if (< idx (length strListV))
      (setq strListV (fn-replace-nth idx valStr strListV))
    )
    (set_tile "error" "")
  )

  ;; Sinkronisasi jumlah baris tabel saat jumlah grid diubah pengguna
  (defun fn-sync-grid-counts ( / pH pV)
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
       (fn-refresh-v-table))
    )
  )

  ;; Perbarui pratinjau ukuran Model Space secara dinamis
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
  )

  ;; ==========================================================================
  ;; MODUL 6: VALIDASI INPUT TERPUSAT SEBELUM DIALOG DITUTUP
  ;; ==========================================================================
  (defun fn-validate-all ( / pH pV sc th bd ex posIdx idx val parsedH parsedV errSlot ok)
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
      ;; Pastikan tabel sudah disinkronkan jika user mengubah jumlah lalu langsung klik OK
      ((or (/= pH curNumH) (/= pV curNumV))
       (setq curNumH  pH
             curNumV  pV
             strListH (fn-resize-str-list strListH (max 0 (1- curNumH)) "4000")
             strListV (fn-resize-str-list strListV (max 0 (1- curNumV)) "4000"))
       (fn-refresh-h-table)
       (fn-refresh-v-table)
       (set_tile "error" "Jumlah grid diperbarui. Periksa nilai tabel spacing lalu klik OK lagi.")
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
           ;; Simpan hasil validasi ke variabel utama
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
             (princ "\n[ASGRID V2.0 Peringatan] Diameter bubble cetak <= tinggi teks cetak; teks dapat melewati bubble.")
           )
           (done_dialog 1))
        )
      )
    )
  )

  ;; ==========================================================================
  ;; MODUL 7: EKSEKUSI PEMBUATAN GRID & RINGKASAN HASIL (LOGIKA V1.0)
  ;; ==========================================================================
  (defun fn-generate-grid (ptWcs /
                            x0 y0 z0
                            textHModel bubbleDiaModel bubbleRadModel
                            acc cumYList cumXList totalY totalX
                            drawStart drawEnd
                            cntLine cntBubble cntText
                            i curY curX labelStr pStart pEnd c1 c2
                          )
    (setq x0             (float (car ptWcs))
          y0             (float (cadr ptWcs))
          z0             (if (caddr ptWcs) (float (caddr ptWcs)) 0.0)
          textHModel     (* textHPrint scaleDenom)
          bubbleDiaModel (* bubbleDiaPrint scaleDenom)
          bubbleRadModel (/ bubbleDiaModel 2.0)
          drawStart      (or (= bubblePos "Both Ends") (= bubblePos "Start"))
          drawEnd        (or (= bubblePos "Both Ends") (= bubblePos "End")))

    ;; Hitung koordinat kumulatif Y (garis horizontal)
    (setq acc      y0
          cumYList (list acc))
    (foreach val distListH
      (setq acc      (+ acc val)
            cumYList (append cumYList (list acc)))
    )
    (setq totalY (- acc y0))

    ;; Hitung koordinat kumulatif X (garis vertikal)
    (setq acc      x0
          cumXList (list acc))
    (foreach val distListV
      (setq acc      (+ acc val)
            cumXList (append cumXList (list acc)))
    )
    (setq totalX (- acc x0))

    ;; Siapkan grup UNDO, linetype, layer, dan Text Style Arial
    (princ "\n[ASGRID V2.0] Memproses layer, linetype, Text Style Arial, dan geometri grid...")
    (setvar "CMDECHO" 0)
    (command "_.UNDO" "_Begin")
    (setq undoOpen T)

    (if (not (fn-ensure-arial-style))
      (progn
        (command "_.UNDO" "_End")
        (setq undoOpen nil)
        (setvar "CMDECHO" oldCmdEcho)
        (exit)
      )
    )

    (if (not (fn-ensure-linetype-center))
      (princ "\n  [Peringatan] Linetype CENTER gagal dimuat; layer AS-GRID akan memakai CONTINUOUS.")
    )

    (fn-ensure-layer "AS-GRID"   "CENTER"     8)
    (fn-ensure-layer "AS-BUBBLE" "CONTINUOUS" 2)
    (fn-ensure-layer "AS-TEXT"   "CONTINUOUS" 7)

    ;; Buat garis as horizontal (1, 2, 3, ...) sejajar sumbu X
    (setq cntLine   0
          cntBubble 0
          cntText   0
          i         1)
    (foreach curY cumYList
      (setq labelStr (itoa i)
            pStart   (list (- x0 extLen) curY z0)
            pEnd     (list (+ x0 totalX extLen) curY z0))

      (if (fn-draw-line pStart pEnd "AS-GRID")
        (setq cntLine (1+ cntLine))
      )

      (if drawStart
        (progn
          (setq c1 (list (- x0 extLen bubbleRadModel) curY z0))
          (if (fn-draw-circle c1 bubbleRadModel "AS-BUBBLE")
            (setq cntBubble (1+ cntBubble))
          )
          (if (fn-draw-text-mc c1 textHModel labelStr "AS-TEXT")
            (setq cntText (1+ cntText))
          )
        )
      )

      (if drawEnd
        (progn
          (setq c2 (list (+ x0 totalX extLen bubbleRadModel) curY z0))
          (if (fn-draw-circle c2 bubbleRadModel "AS-BUBBLE")
            (setq cntBubble (1+ cntBubble))
          )
          (if (fn-draw-text-mc c2 textHModel labelStr "AS-TEXT")
            (setq cntText (1+ cntText))
          )
        )
      )
      (setq i (1+ i))
    )

    ;; Buat garis as vertikal (A, B, C, ..., AA, AB) sejajar sumbu Y
    (setq i 1)
    (foreach curX cumXList
      (setq labelStr (fn-index-to-alpha i)
            pStart   (list curX (- y0 extLen) z0)
            pEnd     (list curX (+ y0 totalY extLen) z0))

      (if (fn-draw-line pStart pEnd "AS-GRID")
        (setq cntLine (1+ cntLine))
      )

      (if drawStart
        (progn
          (setq c1 (list curX (- y0 extLen bubbleRadModel) z0))
          (if (fn-draw-circle c1 bubbleRadModel "AS-BUBBLE")
            (setq cntBubble (1+ cntBubble))
          )
          (if (fn-draw-text-mc c1 textHModel labelStr "AS-TEXT")
            (setq cntText (1+ cntText))
          )
        )
      )

      (if drawEnd
        (progn
          (setq c2 (list curX (+ y0 totalY extLen bubbleRadModel) z0))
          (if (fn-draw-circle c2 bubbleRadModel "AS-BUBBLE")
            (setq cntBubble (1+ cntBubble))
          )
          (if (fn-draw-text-mc c2 textHModel labelStr "AS-TEXT")
            (setq cntText (1+ cntText))
          )
        )
      )
      (setq i (1+ i))
    )

    ;; Tutup grup UNDO & pulihkan CMDECHO
    (command "_.UNDO" "_End")
    (setq undoOpen nil)
    (setvar "CMDECHO" oldCmdEcho)

    ;; Ringkasan hasil di command line
    (princ "\n--------------------------------------------------------")
    (princ "\n[ASGRID V2.0] SELESAI - RINGKASAN PEMBUATAN GRID")
    (princ "\n--------------------------------------------------------")
    (princ (strcat "\n  Titik awal (WCS)     : (" (rtos x0 2 2) ", " (rtos y0 2 2) ", " (rtos z0 2 2) ") mm"))
    (princ (strcat "\n  Jumlah grid (H x V)  : " (itoa numH) " Horizontal x " (itoa numV) " Vertikal"))
    (princ (strcat "\n  Area grid (X x Y)    : " (rtos totalX 2 2) " mm x " (rtos totalY 2 2) " mm"))
    (princ (strcat "\n  Skala cetak          : 1:" (rtos scaleDenom 2 2)))
    (princ (strcat "\n  Tinggi teks model    : " (rtos textHModel 2 2) " mm (cetak " (rtos textHPrint 2 2) " mm)"))
    (princ (strcat "\n  Diameter bubble model: " (rtos bubbleDiaModel 2 2) " mm (cetak " (rtos bubbleDiaPrint 2 2) " mm)"))
    (princ (strcat "\n  Perpanjangan garis   : " (rtos extLen 2 2) " mm"))
    (princ (strcat "\n  Posisi bubble        : " bubblePos))
    (princ (strcat "\n  Text Style / Font    : " STYLE_NAME " (" FONT_FILE ")"))
    (princ (strcat "\n  Objek dibuat         : " (itoa cntLine) " garis as, "
                                              (itoa cntBubble) " bubble, "
                                              (itoa cntText) " teks."))
    (princ "\n  Layer digunakan      : AS-GRID, AS-BUBBLE, AS-TEXT")
    (princ "\n--------------------------------------------------------")
  )

  ;; ==========================================================================
  ;; ALUR UTAMA PROGRAM ASGRID V2.0
  ;; ==========================================================================

  ;; 1. Temukan dan muat file DCL
  (setq dclFile (findfile "ASGRID_V2.dcl"))
  (if (null dclFile)
    (progn
      (alert
        (strcat
          "File dialog 'ASGRID_V2.dcl' tidak ditemukan!\n\n"
          "Pastikan 'ASGRID_V2.dcl' disimpan pada folder yang terdaftar di\n"
          "AutoCAD Options -> Files -> Support File Search Path."
        )
      )
      (princ "\n[ASGRID V2.0 ERROR] File 'ASGRID_V2.dcl' tidak ditemukan.")
      (princ)
    )
    (progn
      (setq dclId (load_dialog dclFile))
      (if (or (null dclId) (< dclId 0))
        (progn
          (alert "Gagal memuat file dialog 'ASGRID_V2.dcl'.")
          (princ "\n[ASGRID V2.0 ERROR] load_dialog gagal untuk 'ASGRID_V2.dcl'.")
          (princ)
        )
        (if (not (new_dialog "asgrid_v2" dclId))
          (progn
            (unload_dialog dclId)
            (setq dclId nil)
            (alert "Definisi dialog 'asgrid_v2' tidak ditemukan di dalam 'ASGRID_V2.dcl'.")
            (princ "\n[ASGRID V2.0 ERROR] new_dialog gagal untuk 'asgrid_v2'.")
            (princ)
          )
          (progn
            ;; 2. Inisialisasi nilai default dialog (contoh awal grid 4 x 4)
            (setq curNumH  4
                  curNumV  4
                  strListH '("4000" "4000" "4000")
                  strListV '("5000" "5000" "5000")
                  pageH    0
                  pageV    0)

            (set_tile "num_h"       (itoa curNumH))
            (set_tile "num_v"       (itoa curNumV))
            (set_tile "scale_denom" "100")
            (set_tile "txt_height"  "2.5")
            (set_tile "bub_dia"     "8.0")
            (set_tile "ext_len"     "1500")

            ;; Isi popup_list Bubble Position
            (start_list "bub_pos")
            (mapcar 'add_list BUB_POS_LIST)
            (end_list)
            (set_tile "bub_pos" "0") ; Default: Both Ends

            ;; Cek status font Arial untuk informasi di dialog
            (setq arialPath (fn-find-arial-ttf))
            (if arialPath
              (set_tile "font_status" (strcat "Status: Font Arial tersedia (" arialPath ")"))
              (set_tile "font_status" "PERINGATAN: File font arial.ttf TIDAK ditemukan pada sistem!")
            )

            ;; Render tabel spacing dan pratinjau skala awal
            (fn-refresh-h-table)
            (fn-refresh-v-table)
            (fn-update-scale-preview)

            ;; 3. Daftarkan callback tile DCL
            (action_tile "num_h"          "(fn-sync-grid-counts)")
            (action_tile "num_v"          "(fn-sync-grid-counts)")
            (action_tile "btn_update_tbl" "(fn-sync-grid-counts)")

            (action_tile "h_val_1" "(fn-save-h-slot 1 $value)")
            (action_tile "h_val_2" "(fn-save-h-slot 2 $value)")
            (action_tile "h_val_3" "(fn-save-h-slot 3 $value)")
            (action_tile "h_val_4" "(fn-save-h-slot 4 $value)")
            (action_tile "h_val_5" "(fn-save-h-slot 5 $value)")
            (action_tile "h_val_6" "(fn-save-h-slot 6 $value)")
            (action_tile "h_val_7" "(fn-save-h-slot 7 $value)")
            (action_tile "h_val_8" "(fn-save-h-slot 8 $value)")
            (action_tile "h_prev"  "(if (> pageH 0) (progn (setq pageH (1- pageH)) (fn-refresh-h-table)))")
            (action_tile "h_next"  "(progn (setq pageH (1+ pageH)) (fn-refresh-h-table))")

            (action_tile "v_val_1" "(fn-save-v-slot 1 $value)")
            (action_tile "v_val_2" "(fn-save-v-slot 2 $value)")
            (action_tile "v_val_3" "(fn-save-v-slot 3 $value)")
            (action_tile "v_val_4" "(fn-save-v-slot 4 $value)")
            (action_tile "v_val_5" "(fn-save-v-slot 5 $value)")
            (action_tile "v_val_6" "(fn-save-v-slot 6 $value)")
            (action_tile "v_val_7" "(fn-save-v-slot 7 $value)")
            (action_tile "v_val_8" "(fn-save-v-slot 8 $value)")
            (action_tile "v_prev"  "(if (> pageV 0) (progn (setq pageV (1- pageV)) (fn-refresh-v-table)))")
            (action_tile "v_next"  "(progn (setq pageV (1+ pageV)) (fn-refresh-v-table))")

            (action_tile "scale_denom" "(fn-update-scale-preview)")
            (action_tile "txt_height"  "(fn-update-scale-preview)")
            (action_tile "bub_dia"     "(fn-update-scale-preview)")

            (action_tile "accept" "(fn-validate-all)")
            (action_tile "cancel" "(done_dialog 0)")

            ;; 4. Tampilkan dialog
            (setq dclRes (start_dialog))
            (unload_dialog dclId)
            (setq dclId nil)

            ;; 5. Jika OK (dclRes = 1), minta titik awal lalu buat grid
            (if (= dclRes 1)
              (progn
                (setq basePtUcs (getpoint "\n[ASGRID V2.0] Klik titik awal grid (pojok kiri bawah): "))
                (if basePtUcs
                  (progn
                    (setq basePt (trans basePtUcs 1 0))
                    (fn-generate-grid basePt)
                  )
                  (princ "\n[ASGRID V2.0] Titik awal tidak dipilih. Proses dibatalkan tanpa mengubah gambar.")
                )
              )
              (princ "\n[ASGRID V2.0] Dibatalkan oleh pengguna. Tidak ada objek yang dibuat.")
            )
            (princ)
          )
        )
      )
    )
  )
)

;; Pesan saat file berhasil dimuat melalui APPLOAD
(princ "\n[ASGRID V2.0] Berhasil dimuat. Pastikan ASGRID_V2.dcl tersedia, lalu ketik ASGRID.")
(princ)
