# TECHNICAL REVIEW — ASGRID V2.2.1 (XRecord Reliability Hardening)

- **Baseline:** `ASGRID V2.2 Phase 2/ASGRID_V2_2.lsp` & `ASGRID_V2_2.dcl` (MODE 1 FIX)
- **Target:** `ASGRID V2.2.1 (RELIABILITY HARDENING)/ASGRID_V2_2_1.lsp` & `ASGRID_V2_2_1.dcl`
- **Status Pengujian Runtime:** **Belum diuji langsung di AutoCAD 2021** (hanya verifikasi statis & simulasi logika ekstraksi payload).

## 1. Perbandingan Sebelum dan Sesudah

| Aspek | V2.2 (MODE 1 FIX) | V2.2.1 (RELIABILITY HARDENING) |
| :--- | :--- | :--- |
| `asgrid:meta-extract-raw-payload` | Membuang **semua** `(280 . ...)` setelah `(100 . "AcDbXrecord")`. | State machine 3-tahap: hanya melewati **satu** header `(280 . flag)` tepat setelah `(100 . "AcDbXrecord")`; seluruh `(280 . ...)` payload dipertahankan utuh. |
| Header `280` di `meta-restore-xrecord` | `(assoc 280 snapshotData)` — berisiko membaca payload `280` bila header `280` absen. | `fn-get-header-280`: hanya membaca `280` bila tepat berada setelah `(100 . "AcDbXrecord")` (fallback `1`). |
| Pengecekan `dictremove` | Dipanggil tanpa memeriksa return value `dictremove`. | Hasil `dictremove` diperiksa eksplisit; bila `nil`, proses dihentikan dan `restEname` dibersihkan tanpa menyentuh dictionary. |
| Kegagalan `dictadd` / Verifikasi | Hanya mencoba `(dictadd ... curEname)` bila `(entget curEname)` non-nil (gagal jika `dictremove` menandai `curEname` erased). | `fn-reattach-cur`: mencoba *undelete* `curEname` via `entdel` + `dictadd` + verifikasi, dengan fallback `entmakex` bersih dari `curSnap` + pesan `CRITICAL` (`UNDO Ctrl+Z`) bila gagal total. |
| `asgrid:meta-update-group`, `c:ASGRIDCHECK`, `ASGRID_V2_2_1.dcl` | Baseline teruji. | **Byte-identik** dengan baseline. |

## 2. Cara Kerja Ekstraksi Raw Payload (`asgrid:meta-extract-raw-payload`)

Mengacu pada struktur DXF `AcDbXrecord`:
1. **`state = 0`:** Melewati seluruh header entitas (`-1`, `0`, `5`, `102`, `330`, `100` AcDbEntity/dll.) hingga menemukan `(100 . "AcDbXrecord")`, lalu pindah ke `state = 1`.
2. **`state = 1`:** Memeriksa tepat satu pasangan pertama setelah `(100 . "AcDbXrecord")`. Jika `code = 280` (header *Duplicate Record Cloning Flag*), lewati sekali dan pindah ke `state = 2`. Jika bukan `280`, masukkan langsung ke `res` dan pindah ke `state = 2`.
3. **`state = 2`:** Memasukkan seluruh pasangan DXF berikutnya ke `res` tanpa filter (mempertahankan urutan, tipe data, nilai, serta setiap group code `280` payload).
4. Input `nil`, bukan list, atau elemen bukan dotted pair numerik ditangani aman dan mengembalikan `'()`.

## 3. Alur Eksekusi `asgrid:meta-restore-xrecord`

### A. Alur Normal (Sukses)
`validasi parameter` → `ekstrak origPayload & header 280` → `entmakex restEname` + cek `0 = "XRECORD"` → `ambil curEname & curSnap` → `dictremove` (cek non-nil) → `dictadd restEname` → `read-back dictsearch + entget + cek 0 = "XRECORD" + equal(readPayload, origPayload, 1e-6)` → `hapus curEname hanya jika (entget curEname) masih non-nil` → return `T`.

### B. Alur Ketika `dictremove` Gagal
- `remOk` bernilai `nil` → `dictadd` **tidak** dijalankan.
- XRecord sementara `restEname` dihapus via `(entdel restEname)` agar tidak ada XRecord yatim.
- Entry lama pada dictionary tetap utuh tidak tersentuh. Return `nil`.

### C. Alur Ketika `dictadd` Gagal
- Memanggil `fn-reattach-cur`:
  1. Jika `curEname` berstatus *erased* akibat `dictremove` (`(null (entget curEname))`), jalankan `(entdel curEname)` untuk *undelete*.
  2. Pasang kembali `curEname` via `dictadd` dan verifikasi lewat `dictsearch` + `entget` + `0 = "XRECORD"`.
- Jika `reattachOk = T`: hapus `restEname` dan cetak error normal.
- Jika `reattachOk = nil`: jangan hapus `restEname` (agar tidak menghilangkan satu-satunya salinan yang masih bisa dipulihkan) dan cetak pesan **`CRITICAL`** mengarahkan pengguna menjalankan `UNDO (Ctrl+Z)`.

### D. Alur Fallback dari Snapshot (`curSnap`)
- Di dalam `fn-reattach-cur`, jika *undelete* / `dictadd` terhadap `curEname` gagal tetapi `curSnap` tersedia:
  1. Bangun XRecord bersih baru `fbEname` via `entmakex` menggunakan `fn-get-header-280 curSnap` dan `(asgrid:meta-extract-raw-payload curSnap)`.
  2. Pasang `fbEname` ke `rootDict` dengan `dictadd` dan verifikasi lewat `dictsearch` + `entget` + `0 = "XRECORD"`.
  3. Jika `fbEname` gagal dipasang, bersihkan `fbEname` via `entdel`.

## 4. Batasan Atomisitas AutoLISP & Bagian yang Belum Dapat Dibuktikan Tanpa Runtime AutoCAD

- **Batasan Atomisitas:** AutoLISP tidak menyediakan transaksi database ACID. Jika terjadi *fatal crash* AutoCAD tepat di antara `dictremove` dan `dictadd` (atau saat `fn-reattach-cur` berjalan), pemulihan penuh tetap memerlukan `UNDO (Ctrl+Z)` yang membungkus transaksi di `c:ASGRIDEDIT`.
- **Bagian yang Memerlukan Verifikasi Runtime di AutoCAD 2021:**
  1. Perilaku pasti `(entdel curEname)` untuk *undelete* objek `XRECORD` tepat setelah `(dictremove rootDict groupId)` pada versi/build AutoCAD 2021 pengguna.
  2. Pengujian nyata pemulihan XRecord yang mengandung payload `(280 . 0)` / `(280 . 1)` setelah siklus `entmakex` → `dictadd` → `entget` di database DWG AutoCAD 2021.

## 5. Hasil Static Validation V2.2.1

| No | Pemeriksaan Statis | Hasil |
| :--- | :--- | :--- |
| 1 | Keseimbangan tanda kurung `()` & string `""` (`ASGRID_V2_2_1.lsp`) | **LULUS** (`True`, 0 error) |
| 2 | Duplikasi fungsi top-level | **LULUS** (`NONE`) |
| 3 | Duplikasi command | **LULUS** (`c:ASGRID`, `c:ASGRIDCHECK`, `c:ASGRIDEDIT`) |
| 4 | Global variable baru dari fungsi hardening | **LULUS** (`NONE`, seluruh variabel lokal) |
| 5 | `entmod` pada fungsi XRecord (`extract`/`restore`/`update`) | **LULUS** (`0` pemanggilan) |
| 6 | Keutuhan `asgrid:meta-update-group` vs baseline | **LULUS** (byte-identik) |
| 7 | Keutuhan `c:ASGRIDCHECK` vs baseline | **LULUS** (byte-identik, 100% READ-ONLY) |
| 8 | Keutuhan `ASGRID_V2_2_1.dcl` vs baseline | **LULUS** (byte-identik) |
| 9 | Simulasi `asgrid:meta-extract-raw-payload` (payload `280`, `nil`, non-list) | **LULUS** (header `280` dilewati, payload `280` utuh) |
