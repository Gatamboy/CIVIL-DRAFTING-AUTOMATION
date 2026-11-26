# TESTING CHECKLIST — ASGRID V2.2.1 REVISION 2 (AutoCAD 2021)

*Catatan: Seluruh pemeriksaan statis telah lulus, tetapi **pengujian runtime pada AutoCAD 2021 belum dilakukan**. Jalankan checklist ini setelah independent code review.*

## 0. Persiapan Lingkungan Uji
- [ ] Tempatkan folder `ASGRID V2.2.1 REVISION 2` (`ASGRID_V2_2_1_R2.lsp` & `ASGRID_V2_2_1.dcl`) di urutan teratas *Support File Search Path* dan *Trusted Locations*.
- [ ] Muat `ASGRID_V2_2_1_R2.lsp` melalui `APPLOAD` (jangan memuat file LSP versi lain pada sesi yang sama).

## 1. Uji Ketat Payload `nil`/Kosong & Pra-Validasi Snapshot (`asgrid:meta-restore-xrecord`)
Pada DWG salinan uji dengan grup `"ASG-0001"` (`(setq snap1 (asgrid:meta-get-xrecord-snapshot "ASG-0001"))`):
- [ ] Snapshot XRECORD tanpa payload (hanya header `(0 . "XRECORD") (100 . "AcDbXrecord") (280 . 1)`) → ditolak sebelum menyentuh dictionary, `"ASG-0001"` tetap utuh.
- [ ] Snapshot bukan `XRECORD`, tanpa marker `AcDbXrecord`, metadata korup, atau mismatch `GROUP_ID` (`"ASG-0002"` dengan `snap1`) → semuanya ditolak dengan pesan `"Dictionary tidak disentuh."`.

## 2. Uji Restore Normal, `curEname` `nil`, & Verifikasi Payload
- [ ] **Restore normal:** Edit `"ASG-0001"` via `ASGRIDEDIT` (`Bubble Diameter 8.0 → 10.0`), lalu jalankan `(asgrid:meta-restore-xrecord "ASG-0001" snap1)` → mengembalikan `T`, nilai kembali ke `8.0`, `ASGRIDCHECK` → `0 MASALAH`.
- [ ] **Restore saat `curEname` `nil`:** Pada DWG uji, lepas entry `"ASG-0001"` via `(dictremove (asgrid:meta-get-root-dict nil) "ASG-0001")`, lalu jalankan `(asgrid:meta-restore-xrecord "ASG-0001" snap1)` → mengembalikan `T` dan `"ASG-0001"` pulih utuh (`ASGRIDCHECK` → `0 MASALAH`).

## 3. Uji Regresi Penuh (`ASGRID`, `ASGRIDEDIT` Mode 1, `ASGRIDCHECK`)
- [ ] Generate 2+ grid berulang dengan `ASGRID` → berhasil, Group ID unik (`ASG-0001`, `ASG-0002`).
- [ ] Edit berulang 3× pada `ASG-0001` lewat `ASGRIDEDIT` (ubah seluruh 5 parameter anotasi) → `LINE` & `EXT_LEN` tidak berubah, payload XRecord tidak menumpuk (`DIST_H_COUNT == (length DIST_H)`).
- [ ] Uji `Cancel`, `UNDO` tunggal, kompatibilitas grid V2.1.2/V2.2, simpan-tutup-buka DWG, lalu jalankan `ASGRIDCHECK` → `0 MASALAH`.
