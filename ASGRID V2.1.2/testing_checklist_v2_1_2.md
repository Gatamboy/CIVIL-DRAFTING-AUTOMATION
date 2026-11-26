# TESTING CHECKLIST — ASGRID V2.1.2 (AutoCAD 2021)

*Catatan: Program ini telah lolos pemeriksaan statis kode dan DCL, tetapi **belum dijalankan langsung di AutoCAD 2021**. Jalankan seluruh pengujian berikut langsung di AutoCAD 2021 (WCS, satuan milimeter).*

## 0. Persiapan Lingkungan Uji
- [ ] Simpan seluruh isi folder `ASGRID V2.1.2` di direktori yang terdaftar pada `OPTIONS` → *Files* → *Support File Search Path* dan *Trusted Locations*.
- [ ] Pastikan file V2.1.1 tetap terpisah sebagai baseline dan tidak dimuat bersamaan pada sesi uji yang sama.
- [ ] Muat `ASGRID_V2_1_2.lsp` melalui `APPLOAD` dan pastikan muncul pesan: `[ASGRID V2.1.2] Berhasil dimuat. Perintah: ASGRID (buat grid) | ASGRIDCHECK (deep diagnostics read-only).`

## 1. Uji DCL, Default Spacing & Live Preview
- [ ] Jalankan `ASGRID` dan pastikan label panel C tampil rapi sebagai **`C. Scale & Annotation`** (tanpa garis bawah mnemonic aneh atau karakter hilang).
- [ ] Periksa default awal Vertical Intervals (`5000, 5000, 5000`), lalu ubah `Vertical Grids` dari `4` menjadi `6` dan klik `Update Table`; pastikan interval baru (`D - E`, `E - F`) otomatis terisi **`5000`** (konsisten dengan default awal).
- [ ] Uji variasi spacing berbeda (misal Horizontal `4000, 3500, 4500`; Vertical `5000, 6000, 4500, 5000, 5500`) dan verifikasi proporsi garis di Live Preview berubah real-time.
- [ ] Uji peringatan bubble kecil di dialog: ubah `Printed Bubble Dia` menjadi `2.0` (lebih kecil dari `Printed Text Height = 2.5`); pastikan `scale_preview` menampilkan `[WARN: Bubble <= Text!]`, lalu kembalikan ke `8.0`.
- [ ] Uji pagination (`< Prev` / `Next >`) dengan jumlah grid > 10 (misal `12 × 28`); pastikan nilai tiap halaman tersimpan, penomoran mencapai `AA, AB`, dan Live Preview beralih ke *Dense Mode* dengan rapi.

## 2. Uji Pembuatan Grid, Semua Posisi Bubble & Metadata Readback
- [ ] Buat grup `ASG-0001` (4 × 4, spacing bervariasi, `Both Ends`, scale `1:100`); verifikasi command line menampilkan `Hard Gate Metadata : LOLOS`, `Lines 8/8 | Bubbles 16/16 | Texts 16/16 (Total 40/40 OK)`.
- [ ] Buat grup `ASG-0002` (3 × 5, `Start`, scale `1:50`); verifikasi `Lines 8/8 | Bubbles 8/8 | Texts 8/8 (Total 24/24 OK)`.
- [ ] Buat grup `ASG-0003` (4 × 3, `End`, scale `1:200`); verifikasi `Lines 7/7 | Bubbles 7/7 | Texts 7/7 (Total 21/21 OK)`.
- [ ] Uji `INSUNITS` non-mm (opsional pada file uji terpisah): set `INSUNITS` ke `6` (Meters), jalankan `ASGRID`, pastikan muncul info non-blocking di command line, grid tetap dibuat dalam mm, dan nilai `INSUNITS` serta `LTSCALE` **tidak berubah**.

## 3. Uji ASGRIDCHECK pada Grid Normal & Anomali (100% READ-ONLY)
- [ ] **Grid normal:** Jalankan `ASGRIDCHECK`; pastikan `ASG-0001`, `ASG-0002`, dan `ASG-0003` seluruhnya berstatus `OK (Lengkap, DXF/Role/AxisIdx/EndTag valid, 0 duplikat)` dan `0 MASALAH`.
- [ ] **Setelah 1 objek dihapus:** Hapus 1 lingkaran bubble dari `ASG-0001` (`ERASE`), jalankan `ASGRIDCHECK`. Pastikan `ASG-0001` melaporkan `Bubbles 15/16` dan `Jumlah Entitas : PERINGATAN`, sementara `ASG-0002`/`ASG-0003` tetap `OK`. Tekan `UNDO` untuk memulihkan.
- [ ] **Setelah 1 objek diduplikasi (`COPY`):** Gandakan 1 bubble milik `ASG-0001` dengan perintah `COPY`, lalu jalankan `ASGRIDCHECK`. Pastikan `ASGRIDCHECK` mendeteksi **`Duplikasi Slot : PERINGATAN - Ditemukan 1 slot duplikat`** (misal `BUBBLE|H|1|START`) dan tidak menghapus objek duplikat tersebut. Tekan `UNDO` untuk memulihkan.
- [ ] **Metadata yatim:** Hapus semua entitas milik `ASG-0003`, jalankan `ASGRIDCHECK`. Pastikan dilaporkan `Metadata yatim (0 entitas ditemukan di gambar)` tanpa menghapus XRecord secara otomatis. Tekan `UNDO` untuk memulihkan.
- [ ] **Simulasi aman metadata korup (di file DWG salinan uji saja):** Pada salinan DWG uji, buat XRecord rusak buatan di NOD `"ASGRID_GROUPS"` dengan `DIST_H_ITEM` bertipe string `(cons 1 "BAD")`, lalu jalankan `ASGRIDCHECK`. Pastikan `ASGRIDCHECK` **tidak crash**, melaporkan error tipe data informatif pada grup korup tersebut, dan tetap selesai memeriksa grup lain yang sehat.

## 4. Uji Transaction Rollback, Pembatalan & UNDO
- [ ] Klik `Cancel` pada dialog setelah mengubah parameter → pastikan 0 objek & 0 metadata baru.
- [ ] Klik `OK` pada dialog lalu tekan `ESC` saat diminta klik titik awal → pastikan muncul pesan pembatalan pengguna, `CMDECHO` pulih, dan 0 metadata/entitas parsial.
- [ ] Buat 1 grid baru lalu tekan `UNDO` (`Ctrl+Z`) 1 kali → pastikan seluruh entitas dan XRecord grup baru tersebut terhapus, sementara grup sebelumnya utuh (cek via `ASGRIDCHECK`).

## 5. Uji DWG Persistence & Kompatibilitas dengan Grid V2.1.1
- [ ] Simpan DWG, tutup AutoCAD 2021 sepenuhnya, buka kembali DWG, muat `ASGRID_V2_1_2.lsp`, lalu jalankan `ASGRIDCHECK`. Pastikan seluruh grup terbaca utuh (`0 MASALAH`).
- [ ] **Kompatibilitas lintas versi (V2.1.1 → V2.1.2):** Buka file DWG yang sebelumnya berisi grid buatan **`ASGRID V2.1.1`**, muat `ASGRID_V2_1_2.lsp`, lalu jalankan `ASGRIDCHECK`. Pastikan seluruh grid buatan V2.1.1 lulus seluruh pemeriksaan konsistensi baru (`DIST_H_COUNT`, `DIST_V_COUNT`, `ELEVATION` vs `Z`, DXF/Role, `AxisIdx`, `EndTag`, 0 duplikat) dan pembuatan grid baru di V2.1.2 melanjutkan nomor `ASG-NNNN` tanpa bentrok.
