# PHASE 2 TESTING CHECKLIST — ASGRID V2.2 (`ASGRIDEDIT` Mode 1, AutoCAD 2021)

*Catatan: Implementasi Phase 2 telah lolos seluruh pemeriksaan statis, tetapi **belum dijalankan langsung di AutoCAD 2021**. Jalankan checklist ini secara berurutan di AutoCAD 2021 (WCS, milimeter).*

## 0. Persiapan Lingkungan Uji

* \[ \] Tempatkan folder `ASGRID V2.2 Phase 2` (`ASGRID_V2_2.lsp` & `ASGRID_V2_2.dcl`) di direktori *Support File Search Path* dan *Trusted Locations* (pastikan tidak ada `ASGRID_V2_2.dcl` Phase 1 yang lebih dulu terbaca di urutan path).

* \[ \] Muat `ASGRID_V2_2.lsp` via `APPLOAD`; pastikan muncul pesan `[ASGRID V2.2] Berhasil dimuat. Perintah: ASGRID | ASGRIDEDIT | ASGRIDCHECK.`

## A. Pemilihan Grid & Pre-Edit Guardrail

* \[ \] Jalankan `ASGRIDEDIT`, pilih objek `LINE` milik `ASG-0001` → dialog `ASGRID V2.2 - Annotation Editor` terbuka dengan nilai metadata `ASG-0001` (bukan default generator). Klik `Cancel`.

* \[ \] Jalankan `ASGRIDEDIT`, pilih objek `CIRCLE` (bubble) milik `ASG-0001` → dialog terbuka normal. Klik `Cancel`.

* \[ \] Jalankan `ASGRIDEDIT`, pilih objek `TEXT` milik `ASG-0001` → dialog terbuka normal. Klik `Cancel`.

* \[ \] Jalankan `ASGRIDEDIT`, pilih objek biasa (bukan ASGRID) → ditolak bersih dengan pesan error, DWG tidak berubah.

* \[ \] Hapus 1 bubble `ASG-0001` secara manual (`ERASE`), lalu jalankan `ASGRIDEDIT` pada `ASG-0001` → edit dibatalkan oleh *Pre-Edit Integrity Gate* dengan arahan `ASGRIDCHECK`. Tekan `UNDO` untuk memulihkan.

## B. Editing Annotation, Validasi Text Style & Live Preview

* \[ \] Ubah `Printed Bubble Diameter` (misal `8.0` → `10.0`) → verifikasi Live Preview & `ed_scale_prev` berubah real-time → klik `OK` → cek diameter baru via `PROPERTIES`.

* \[ \] Ubah `Printed Text Height` (misal `2.5` → `3.0`) → klik `OK` → cek `Height` teks baru via `PROPERTIES`.

* \[ \] Uji validasi `Text Style`:

  * Pilih style dengan `Fixed Height > 0` atau `Annotative` → pastikan `ed_style_info` menandai `INVALID` dan tombol `OK` menolak dengan pesan jelas.

  * Pilih style valid lain (Height `0`, non-annotative, non-Xref) → klik `OK` → verifikasi seluruh teks grup berganti ke style tersebut sementara `TEXTSTYLE` global dan `Standard` tidak berubah.

* \[ \] Ubah `Bubble Position`: `Both Ends` → `Start` → `End` → `Both Ends`; verifikasi jumlah bubble & teks pada tiap tahap sesuai ekspektasi dan `ASGRIDCHECK` melapor `0 MASALAH`.

* \[ \] Ubah `Annotation Extension Length` (misal `1500` → `2200`) → verifikasi di Live Preview bahwa garis tetap pada `1500` dan bubble bergeser ke `2200` → klik `OK` → verifikasi posisi bubble baru.

* \[ \] Ubah seluruh 5 parameter sekaligus dalam satu kali `ASGRIDEDIT` → klik `OK` → jalankan `ASGRIDCHECK` (`0 MASALAH`).

## C. Geometry Preservation (Zero-Change pada `LINE`)

* \[ \] Sebelum menjalankan `ASGRIDEDIT`, catat Handle, titik `(10)` & `(11)`, dan jumlah seluruh `LINE` pada `ASG-0001` (misal via `(entget (car (entsel)))`).

* \[ \] Setelah mengubah `ANNO_EXT_LEN`, `BUBBLE_DIA_PRINT`, `TEXT_H_PRINT`, `BUBBLE_POS`, dan `TEXT_STYLE`:

  * \[ \] Jumlah `LINE` identik sebelum dan sesudah edit.

  * \[ \] Handle dan koordinat `(10)`/`(11)` seluruh `LINE` **100% identik**.

  * \[ \] Pada `(asgrid:meta-read-group "ASG-0001")`: `EXT_LEN`, `BASE_PT_WCS`, `ELEVATION`, `NUM_H`, `NUM_V`, `DIST_H`, `DIST_V`, `SCALE_DENOM` **tidak berubah**.

## D. Transaction, Rollback & Recovery

* \[ \] **Cancel dialog:** Ubah beberapa nilai lalu klik `Cancel` → 0 perubahan pada entitas & metadata.

* \[ \] **UNDO tunggal:** Setelah `ASGRIDEDIT` berhasil, tekan `UNDO` (`Ctrl+Z`) 1 kali → anotasi lama dan metadata lama kembali utuh (verifikasi via `ASGRIDCHECK`).

* \[ \] **Verifikasi bersihnya XData sementara:** Setelah `ASGRIDEDIT` berhasil, jalankan `(ssget "_X" '((-3 ("ASGRID_TX_TMP"))))` → harus mengembalikan `nil` (0 sisa entitas sementara).

* \[ \] **Simulasi aman kegagalan transaksi (opsional di salinan DWG uji):** Uji pembatalan (`ESC`) / simulasi error pada tahap update metadata atau final audit → pastikan rollback menghapus anotasi baru, memulihkan anotasi lama & XRecord lama, menjaga seluruh `LINE` utuh, dan bila rollback parsial tampil pesan recovery `UNDO`.

## E. Compatibility & Regression

* \[ \] **Grid V2.2 Phase 1/2 baru:** Edit via `ASGRIDEDIT`, lalu jalankan `ASGRIDCHECK` → `0 MASALAH`.

* \[ \] **Grid V2.1.2 lama (tanpa `ANNO_EXT_LEN`):** Buka DWG berisi grid buatan V2.1.2, jalankan `ASGRIDEDIT` → pastikan `Current ANNO_EXT_LEN` menampilkan `(fallback EXT_LEN)` → ubah `ANNO_EXT_LEN` menjadi `2000` → klik `OK` → verifikasi `EXT_LEN` lama tetap utuh, `ANNO_EXT_LEN = 2000` tersimpan, dan `ASGRIDCHECK` melapor `0 MASALAH`.

* \[ \] **Multi-grup dalam satu DWG:** Buat `ASG-0001` dan `ASG-0002`, edit `ASG-0001` → pastikan `ASG-0002` tidak berubah sama sekali.

* \[ \] **Generate setelah Edit:** Setelah `ASGRIDEDIT`, jalankan `ASGRID` untuk membuat grup baru (`ASG-0003`) → berhasil tanpa bentrok Group ID atau error RegApp.

* \[ \] **DWG Persistence:** Simpan DWG, tutup dan buka kembali AutoCAD 2021, muat `ASGRID_V2_2.lsp`, jalankan `ASGRIDCHECK` → seluruh grup sehat (`0 MASALAH`).


## F. Regression Test Khusus Fix XRecord Update & Rollback (Wajib Diuji di AutoCAD 2021)

*Catatan: Perbaikan Replace-in-Dictionary ini telah lolos audit statis kode (0 `entmod` pada XRecord), tetapi **belum dijalankan langsung di AutoCAD 2021**.*

- [ ] **Test A — Edit Normal:** Pilih `ASG-0001`, ubah `Bubble Diameter` (misal `8.0` → `10.0`), klik `OK`. Pastikan tidak muncul error `DIST_H_COUNT (3) vs DIST_H (6)`, `(asgrid:meta-read-group "ASG-0001")` mengembalikan `BUBBLE_DIA_PRINT = 10.0`, dan `DIST_H_COUNT == (length DIST_H)`.
- [ ] **Test B — Edit Berulang (Anti-Penumpukan Payload):** Jalankan `ASGRIDEDIT` pada `ASG-0001` sebanyak 3–5 kali berturut-turut dengan nilai berbeda. Periksa `(entget (cdr (assoc -1 (dictsearch (asgrid:meta-get-root-dict nil) "ASG-0001"))))` dan pastikan jumlah `(300 . "DIST_H_ITEM")` tetap `3` (tidak menumpuk menjadi 6, 9, dst.) dan selalu terbaca nilai terbaru.
- [ ] **Test C — Edit 5 Parameter Sekaligus:** Ubah `Bubble Diameter`, `Text Height`, `Text Style`, `Bubble Position`, dan `Annotation Extension Length` secara bersamaan; pastikan seluruh nilai tersimpan dan `ASGRIDCHECK` melaporkan `0 MASALAH`.
- [ ] **Test D — Preservasi Geometri:** Pastikan jumlah `LINE`, koordinat `(10)`/`(11)`, spacing `DIST_H`/`DIST_V`, `EXT_LEN`, `BASE_PT_WCS`, dan `GROUP_ID` tetap identik sebelum & sesudah edit berulang.
- [ ] **Test E — Cancel:** Buka `ASGRIDEDIT`, ubah nilai, klik `Cancel`; pastikan entitas dan XRecord tidak berubah.
- [ ] **Test F — Simulasi Kegagalan & Rollback (di file DWG salinan uji):** Uji skenario gagal pembuatan XRecord / gagal verifikasi / rollback `asgrid:meta-restore-xrecord`; pastikan tidak ada dictionary entry hilang, tidak ada XRecord yatim, anotasi lama pulih, dan bila rollback gagal penuh tampil pesan pemulihan `UNDO`.