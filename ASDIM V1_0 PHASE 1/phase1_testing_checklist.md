# Testing Checklist — ASDIM V1.0 Phase 1 (Foundation & Read-Only Audit)

**Target Runtime:** AutoCAD 2021  
**File Uji:** `ASDIM V1_0 PHASE 1/ASDIM_V1_0_PHASE1.lsp`  
**Status Pengujian Runtime Saat Ini:** **NOT RUN** (Seluruh skenario di bawah ini wajib dieksekusi langsung oleh pengguna pada AutoCAD 2021. Phase 1 belum dianggap lolos runtime sebelum pengujian langsung selesai dikonfirmasi.)

## Daftar Pengujian Runtime AutoCAD 2021

| ID | Skenario Uji | Langkah Uji | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| P1-01 | Loading LSP pada AutoCAD 2021 | Muat `ASDIM_V1_0_PHASE1.lsp` via `APPLOAD` pada AutoCAD 2021. | Muncul pesan `[ASDIM V1.0-Phase1] Berhasil dimuat (100% READ-ONLY Audit). Perintah: ASDIM.` tanpa error sintaks. | NOT RUN |
| P1-02 | Pemanggilan command `ASDIM` | Ketik `ASDIM` lalu tekan `Enter` (coba juga batal dengan `Esc`). | Prompt pemilihan objek muncul; jika `Esc`, program berhenti bersih tanpa error maupun perubahan gambar. | NOT RUN |
| P1-03 | Pemilihan entity grid yang valid | Jalankan `ASDIM`, klik salah satu garis `LINE` milik grup ASGRID R3 yang valid. | Laporan audit tampil lengkap dengan status `[1] VALIDASI METADATA: LULUS`, `[2] AUDIT GEOMETRI: LULUS`, dan `[LULUS]`. | NOT RUN |
| P1-04 | Pemilihan entity tanpa XData ASGRID | Jalankan `ASDIM`, klik objek biasa AutoCAD (mis. `LINE`/`CIRCLE` manual). | Proses berhenti dengan pesan bahwa entity tidak memiliki XData RegApp `ASGRID_OBJ`. | NOT RUN |
| P1-05 | `GROUP_ID` tidak ditemukan di NOD | Uji pada entitas dengan XData `ASGRID_OBJ` yang menunjuk `GROUP_ID` tidak terdaftar di `ASGRID_GROUPS`. | Proses berhenti dengan pesan `GROUP_ID` tidak ditemukan di dalam dictionary `ASGRID_GROUPS`. | NOT RUN |
| P1-06 | NOD Dictionary tidak ditemukan | Jalankan pada DWG tanpa dictionary `ASGRID_GROUPS` (entitas yatim dengan XData `ASGRID_OBJ`). | Proses berhenti dengan pesan Named Object Dictionary `ASGRID_GROUPS` tidak ditemukan. | NOT RUN |
| P1-07 | XRecord tidak valid | Uji pada entri `ASGRID_GROUPS` yang rusak / bukan `AcDbXrecord` atau memiliki pasangan DXF 300 tanpa nilai. | Proses berhenti dengan laporan `INVALID_XRECORD` atau `_READ_ERRORS` tanpa crash. | NOT RUN |
| P1-08 | Metadata tidak lengkap | Uji pada XRecord yang kehilangan salah satu key wajib (mis. `SCALE_DENOM` atau `EXT_LEN`). | `[1] VALIDASI METADATA: GAGAL` dengan daftar key wajib yang hilang; audit geometri tidak dilanjutkan. | NOT RUN |
| P1-09 | Jumlah interval tidak sesuai | Uji pada XRecord dengan `DIST_H_COUNT` atau `DIST_V_COUNT` tidak sama dengan `NUM_H - 1` / `NUM_V - 1`. | `[1] VALIDASI METADATA: GAGAL` dengan pesan ketidakcocokan jumlah interval. | NOT RUN |
| P1-10 | Grid horizontal normal | Uji pada grup ASGRID R3 dengan beberapa sumbu horizontal (`1, 2, 3, 4`). | `LINE H` terdeteksi dan lulus posisi/orientasi/elevasi terhadap `cumY` (`DIST_H`). | NOT RUN |
| P1-11 | Grid vertical normal | Uji pada grup ASGRID R3 dengan beberapa sumbu vertikal (`A, B, C, D`). | `LINE V` terdeteksi dan lulus posisi/orientasi/elevasi terhadap `cumX` (`DIST_V`). | NOT RUN |
| P1-12 | Jarak grid nonuniform | Uji pada grup ASGRID R3 dengan `DIST_V = (4000 5000 3000)` dan `DIST_H = (3000 4500)`. | `Total Span X = 12000`, `Total Span Y = 7500`, seluruh garis lulus audit koordinat kumulatif. | NOT RUN |
| P1-13 | Grid dengan satu baris atau satu kolom (`NUM_H = 1` / `NUM_V = 1`) | Uji pada grup dengan `NUM_H = 1, NUM_V >= 2` (atau sebaliknya). | Metadata lulus dengan pesan `[INFO]` arah yang tidak tersedia; tidak error pada daftar interval kosong. | NOT RUN |
| P1-14 | Elevasi selain nol (`Z != 0`) | Buat grid ASGRID R3 dengan titik dasar pada elevasi `Z = 3500.0` (dan uji juga di bawah UCS non-default). | `ELEVATION = 3500.0000 DU` terbaca akurat dan seluruh garis lulus validasi elevasi WCS. | NOT RUN |
| P1-15 | Entity grid hilang | Hapus salah satu garis grid (mis. sumbu `V-B`), lalu jalankan `ASDIM`. | `[2] AUDIT GEOMETRI: GAGAL` melaporkan `Garis grid vertikal V-B hilang di Model Space` serta selisih jumlah garis. | NOT RUN |
| P1-16 | Entity grid dipindahkan / diubah panjang / diputar | Geser salah satu garis grid (mis. `MOVE` sejauh `250 DU` atau ubah elevasi Z), lalu jalankan `ASDIM`. | `[2] AUDIT GEOMETRI: GAGAL` melaporkan nama sumbu dan besar pergeseran dalam `DU`. | NOT RUN |
| P1-17 | Entity grid duplikat | `COPY` salah satu garis grid di tempat yang sama (membawa XData `ASGRID_OBJ` identik), lalu jalankan `ASDIM`. | `[2] AUDIT GEOMETRI: GAGAL` melaporkan duplikat entitas garis dan selisih jumlah garis. | NOT RUN |
| P1-18 | Entity annotation tidak salah dianggap grid line | Jalankan `ASDIM` dan klik entitas `BUBBLE` (`CIRCLE`) atau `TEXT` milik grup valid. | Grup tetap teridentifikasi; laporan menampilkan `BUBBLE` & `TEXT` terpisah dari `LINE H`/`LINE V` tanpa salah dihitung sebagai garis grid. | NOT RUN |
| P1-19 | Entity Paper Space tidak ikut diproses | Salin/buat objek di Layout Paper Space; coba pilih dari Paper Space atau pastikan tidak ikut dihitung pada `ssget "_X"`. | Pemilihan di Paper Space ditolak; entitas Paper Space tidak pernah ikut dihitung dalam audit Model Space. | NOT RUN |
| P1-20 | Drawing tidak berubah setelah audit (`DBMOD` / `ASGRIDCHECK`) | Catat `DBMOD`, `CLAYER`, `TEXTSTYLE`, `DIMSTYLE`, `INSUNITS`, `UCS`, dan jalankan `ASGRIDCHECK` sebelum & sesudah `ASDIM`. | Tidak ada perubahan entitas, metadata, style, layer, maupun system variable (`DBMOD` tidak bertambah karena `ASDIM`). | NOT RUN |

## Catatan Penguji

- **Tanggal Uji:** ___________________________
- **Versi AutoCAD:** AutoCAD 2021
- **Hasil Akhir:** `[ ] LULUS SEMUA` / `[ ] SEBAGIAN` / `[ ] GAGAL (lampirkan output command line)`
