# TECHNICAL REVIEW — ASGRID V2.1.2 (Quick Fix & Diagnostic Improvement)

- **Baseline Audit:** `ASGRID_V2_1_1.lsp` dan `ASGRID_V2_1_1.dcl`
- **Target Rilis:** Folder `ASGRID V2.1.2` (`ASGRID_V2_1_2.lsp` & `ASGRID_V2_1_2.dcl`)
- **Status Pengujian:** Verifikasi statis menyeluruh telah dilakukan; eksekusi langsung di AutoCAD 2021 belum dilakukan dan perlu dijalankan mengikuti `testing_checklist_v2_1_2.md`.

## 1. Tahap 1 — Hasil Audit Kode Aktual V2.1.1

| Area Audit | Lokasi di V2.1.1 | Celah yang Ditemukan | Perbaikan Minimalis V2.1.2 |
| :--- | :--- | :--- | :--- |
| Pembaca XRecord | `asgrid:meta-read-group` (baris 223–224) | Memanggil `(float val)` langsung pada `DIST_H_ITEM` dan `DIST_V_ITEM` tanpa `(numberp val)`. Jika XRecord rusak berisi string/point, `ASGRIDCHECK` crash dengan `bad argument type: numberp`. | Tambahkan pemeriksaan `numberp` / `INT` / 3D point untuk setiap key numerik dan tampung anomali ke `"_READ_ERRORS"` tanpa crash. |
| Validasi Konsistensi Metadata | `asgrid:meta-validate-spec` (baris 258–355) | `DIST_H_COUNT` dan `DIST_V_COUNT` disimpan di XRecord tetapi tidak diperiksa terhadap `(length DIST_H)`/`(length DIST_V)`; `ELEVATION` tidak dicek `numberp` dan tidak dibandingkan dengan komponen Z pada `BASE_PT_WCS`. | Validasi `DIST_H_COUNT`, `DIST_V_COUNT`, `(numberp ELEVATION)`, dan `(equal Z ELEVATION 1e-6)`. |
| Diagnostik `ASGRIDCHECK` | `c:ASGRIDCHECK` (baris 2166–2297) | Hanya menghitung total `LINE`/`BUBBLE`/`TEXT`; tidak mendeteksi ketidaksesuaian DXF type vs Role, `AxisIdx` di luar batas, `EndTag` salah, atau duplikasi slot akibat perintah `COPY`. | Tambahkan audit per entitas: DXF vs Role, rentang `AxisIdx`, `EndTag` vs `BUBBLE_POS`, dan deteksi duplikasi slot `Role\|AxisDir\|AxisIdx\|EndTag` (tetap 100% READ-ONLY). |
| Label DCL & Default Spacing | `ASGRID_V2_1_1.dcl` (baris 156) & `ASGRID_V2_1_1.lsp` (baris 1826, 1872, 2030) | Label `"C. Scale & Annotation"` memakai `&` tunggal (mnemonic DCL). Inisialisasi `strListV` memakai `"5000"`, tetapi penambahan sumbu baru memakai `"4000"`. | Escape menjadi `"C. Scale && Annotation"`. Konsistenkan `DEF_SPACING_H = "4000"` dan `DEF_SPACING_V = "5000"`. |
| Peringatan Proporsi & `INSUNITS` | `fn-update-scale-preview`, `fn-execute-grid-creation` | Belum ada peringatan visual di dialog bila `bubble diameter <= text height`; belum ada peringatan non-blocking bila `INSUNITS != 4`. | Tambahkan tag peringatan di `scale_preview` dan `fn-check-insunits-warning` non-blocking (tanpa mengubah `INSUNITS`/`LTSCALE`). |

## 2. Kompatibilitas Penuh dengan Metadata V2.1.1

- **Schema & Struktur Identik:** V2.1.2 tetap menggunakan `SCHEMA_VER = "1.0"`, Named Object Dictionary `"ASGRID_GROUPS"`, dan XData RegApp `"ASGRID_OBJ"`.
- **Retro-compatibility:** Karena `ASGRID_V2_1_1.lsp` sudah menuliskan key `DIST_H_COUNT`, `DIST_V_COUNT`, `ELEVATION`, `BASE_PT_WCS`, dan 6-field XData `ASGRID_OBJ` pada setiap grup yang dibuatnya, seluruh grid hasil V2.1.1 akan langsung lolos validasi baru dan dapat didiagnosis secara penuh oleh `ASGRIDCHECK` V2.1.2 tanpa perlu migrasi data.

## 3. Audit Transaction Safety & Rollback (Prioritas E)

Audit terhadap `fn-rollback-transaction` dan `*error*` pada `ASGRID_V2_1_2.lsp` memastikan:
1. **Urutan penghapusan objek:** `txCreatedEnts` disusun secara LIFO (`(cons e txCreatedEnts)`), sehingga saat rollback entitas terbaru dihapus terlebih dahulu melalui `entdel` hanya jika `(entget e)` masih aktif.
2. **Penghapusan metadata transaksi:** XRecord hanya dihapus untuk `txSavedGroupId` milik transaksi berjalan (`dictremove` dari `ASGRID_GROUPS` diikuti `entdel` pada `txSavedXrec`). Metadata grup lain tidak pernah disentuh.
3. **Kegagalan pasca-metadata sebelum geometri selesai:** Karena `txActive = T` dan `txSavedGroupId` diset segera setelah `fn-meta-save-group` berhasil, setiap kegagalan pada Hard Gate, Geometry Engine, Annotation Engine, XData Verification, maupun `ESC`/error mendadak akan langsung memicu `fn-rollback-transaction`, menutup `UNDO` Group, dan memulihkan `CMDECHO`.
4. **Efek samping yang sengaja TIDAK di-rollback (Shared Drawing Resources):**
   - Layer (`AS-GRID`, `AS-BUBBLE`, `AS-TEXT`),
   - Text Style (`ASGRID-ARIAL`),
   - Registered Application (`ASGRID_OBJ`),
   - Linetype (`CENTER`),
   - Kamus induk kosong (`ASGRID_GROUPS`) di NOD.
   Resource tersebut bersifat *shared* di tingkat DWG dan dapat sudah digunakan oleh grup grid lain atau objek lain; menghapusnya saat rollback berisiko merusak gambar. Karena itu resource tersebut dibiarkan tetap ada secara aman.

## 4. Keterbatasan Teknis yang Didokumentasikan

- **Cakupan `ssget "_X"` pada `ASGRIDCHECK`:** `ssget "_X"` hanya memindai entitas *top-level* pada Model Space dan Paper Space. Jika pengguna mengonversi atau memasukkan entitas ASGRID ke dalam definisi `BLOCK` (*nested entities*), `ssget "_X"` tidak akan mendeteksinya sehingga entitas tersebut tidak terhitung dalam grup dan dapat memicu peringatan kekurangan entitas atau metadata yatim. Batasan ini ditampilkan langsung pada header output `ASGRIDCHECK`.
- **DCL `image` tile pada Live Preview:** Menggunakan poligon 12-segmen dan *mini vector stroke font* berbasis `vector_image`, dengan *Dense Mode* otomatis untuk > 10 sumbu agar preview tetap terbaca.

## 5. Hasil Verifikasi Statis V2.1.2

| Kriteria Pemeriksaan | Hasil |
| :--- | :--- |
| Keseimbangan tanda kurung `()` & string `""` (`ASGRID_V2_1_2.lsp`) | **LULUS** (0 error) |
| Keseimbangan kurung kurawal `{}` & string `""` (`ASGRID_V2_1_2.dcl`) | **LULUS** (0 error) |
| Escape mnemonic `&` pada label kontrol DCL | **LULUS** (0 `&` tidak di-escape) |
| Kesesuaian Dialog ID (`asgrid_v2_1_2`) & seluruh tile key LSP ↔ DCL | **LULUS** (0 tile hilang) |
| Deklarasi lokal fungsi internal di `c:ASGRID` & `c:ASGRIDCHECK` | **LULUS** (0 fungsi bocor) |
| Kepatuhan READ-ONLY `c:ASGRIDCHECK` | **LULUS** (0 operasi mutasi) |
| Namespace top-level (`asgrid:*` & `c:*`, 0 global data state) | **LULUS** |
| Keutuhan baseline V2.1.1 (`ASGRID_V2_1_1.lsp` & `ASGRID_V2_1_1.dcl`) | **LULUS** (tidak diubah) |
