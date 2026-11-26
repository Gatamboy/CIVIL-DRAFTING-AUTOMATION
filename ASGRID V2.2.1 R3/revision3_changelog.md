# Changelog — ASGRID V2.2.1 Revision 3

**Baseline:** `ASGRID V2.2.1 REVISION 2` (`ASGRID_V2_2_1_R2.lsp` & `ASGRID_V2_2_1_R2.dcl`, tetap utuh tanpa modifikasi)  
**Target Runtime:** AutoCAD 2021 (AutoLISP Standar + DCL)  
**Fokus Rilis:** Perbaikan bug runtime `bad argument type: stringp T` pada pemuatan file dialog DCL di `c:ASGRID` dan `c:ASGRIDEDIT`.

## Ringkasan Perubahan

| Area | Lokasi (R3) | Perubahan |
| :--- | :--- | :--- |
| Header File | Baris 5 | Memperbarui referensi `FILE TERKAIT` dari `ASGRID_V2_2.dcl` menjadi `ASGRID_V2_2_1_R3.dcl`. |
| Pencarian DCL (`c:ASGRID`) | Baris 2969–2972 | Mengganti `(or (findfile ...))` dengan pencarian berurutan `setq` + `if`: `ASGRID_V2_2_1_R3.dcl` → `ASGRID_V2_2_1_R2.dcl` → `ASGRID_V2_2_1.dcl` → `ASGRID_V2_2.dcl`. |
| Pesan Error DCL (`c:ASGRID`) | Baris 2977–2998 | Memperbarui pesan `alert` & `princ` untuk file tidak ditemukan ke `'ASGRID_V2_2_1_R3.dcl'`, serta menampilkan path aktual `dclFile` pada kegagalan `load_dialog` dan `new_dialog`. |
| Pencarian DCL (`c:ASGRIDEDIT`) | Baris 4113–4116 | Menerapkan pola `setq` + `if` identik dengan urutan fallback yang sama agar bug laten pada `ASGRIDEDIT` ikut teratasi. |
| Pesan Error DCL (`c:ASGRIDEDIT`) | Baris 4119–4134 | Memperbarui pesan `alert` & `princ` untuk file tidak ditemukan ke `'ASGRID_V2_2_1_R3.dcl'`, serta menampilkan path aktual `dclFile` pada kegagalan `load_dialog` dan `new_dialog`. |
| Sinkronisasi DCL | `ASGRID_V2_2_1_R3.dcl` | Salinan identik *byte-per-byte* dari `ASGRID_V2_2_1_R2.dcl` (12.745 byte, SHA-256 identik). |

## Bagian yang Tidak Diubah

Seluruh logika berikut dipertahankan identik dengan **ASGRID V2.2.1 Revision 2** (0 perubahan):
- Logika generator grid (`c:ASGRID` transaksi & pembuatan entitas)
- Live Preview (`asgrid:prev-render-grid`)
- Struktur metadata dan Schema `1.0`
- NOD `ASGRID_GROUPS`, XRecord, dan XData (`ASGRID_OBJ`, `ASGRID_TX_TMP`)
- Mekanisme Replace-in-Dictionary (`asgrid:meta-update-group`, `asgrid:meta-restore-xrecord`, `asgrid:meta-extract-raw-payload`)
- Sistem rollback transaksi dan `*error*` handler
- Logika `ASGRIDEDIT` Mode 1
- Fungsi diagnostik `ASGRIDCHECK` (100% read-only)
- Struktur dan seluruh tampilan dialog pada file `.dcl`

## Status Verifikasi

- **Pemeriksaan Statis:** LULUS seluruh 8 butir validasi statis (lihat `revision3_technical_review.md`).
- **Pengujian Runtime AutoCAD 2021:** **BELUM DIUJI** — menunggu eksekusi langsung oleh pengguna di AutoCAD 2021 (lihat `revision3_testing_checklist.md`).
