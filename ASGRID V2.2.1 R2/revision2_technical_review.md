# TECHNICAL REVIEW — ASGRID V2.2.1 REVISION 2 (Final XRecord Restore Hardening)

- **Baseline:** `ASGRID V2.2.1 REVISION 1/ASGRID_V2_2_1_R1.lsp` & `ASGRID_V2_2_1.dcl`
- **Target:** `ASGRID V2.2.1 REVISION 2/ASGRID_V2_2_1_R2.lsp` & `ASGRID_V2_2_1.dcl`
- **Status Pengujian Runtime:** **Belum dilakukan di AutoCAD 2021** (hanya static validation).

## 1. Fungsi yang Berubah & Alasan Perubahan
Hanya **1 fungsi top-level** yang berubah: **`asgrid:meta-restore-xrecord`** (termasuk helper lokalnya `fn-reattach-cur`). Seluruh fungsi lain di file LSP maupun file DCL **100% byte-identik** dengan Revision 1.

| Temuan | Celah pada R1 | Perbaikan pada R2 |
| :--- | :--- | :--- |
| **Temuan A (`curPayload` `nil`)** | `(or (null curPayload) (equal chkPayload curPayload ...))` mengizinkan `fn-reattach-cur` mengembalikan `T` saat `curPayload` `nil` tanpa bukti kecocokan payload. | `fn-reattach-cur` menolak sejak awal bila `curSnap` atau `curPayload` `nil`/kosong (pesan `CRITICAL`). Kedua jalur (reattach & fallback) mewajibkan `chkPayload` non-nil dan `(equal chkPayload curPayload (asgrid:tol))`. |
| **Temuan B (`dictremove` tidak dicek)** | 3 dari 4 pemanggilan `dictremove` (Jalur 1 reattach, Jalur 2 fallback, dan Step E read-back gagal) tidak memeriksa return value, sehingga berisiko melanjutkan `dictadd` saat key masih terpakai atau menghapus entitas yang masih ditunjuk dictionary (*dangling entry*). | Seluruh **4 dari 4** pemanggilan `dictremove` diperiksa eksplisit (`remOk`, `remBackOk`, `remFbOk`, `remRestOk`). Kegagalan langsung menghentikan langkah lanjutan, mempertahankan entitas yang terpasang, dan mencetak pesan `CRITICAL` (`UNDO Ctrl+Z`). |

## 2. Penanganan Kegagalan pada Setiap Pemanggilan `dictremove`

1. **Step C (`remOk`):** Gagal melepas entry lama sebelum `dictadd restEname` → hentikan proses, bersihkan `restEname` sementara, entry lama tetap utuh.
2. **`fn-reattach-cur` Jalur 1 (`remBackOk`):** Gagal melepas `curEname` yang gagal verifikasi → set `canFallback = nil` agar Jalur 2 tidak memanggil `dictadd` pada key yang masih terisi, tidak menghapus `curEname`, cetak `CRITICAL`.
3. **`fn-reattach-cur` Jalur 2 Fallback (`remFbOk`):** Gagal melepas `fbEname` yang gagal verifikasi → **jangan** memanggil `(entdel fbEname)` agar dictionary tidak menunjuk ke entitas terhapus, cetak `CRITICAL`.
4. **Step E Read-Back Gagal (`remRestOk`):** Gagal melepas `restEname` → **jangan** memanggil `fn-reattach-cur` dan **jangan** menghapus `restEname` (mempertahankan satu-satunya salinan yang masih terpasang), cetak `CRITICAL` dan return `nil`.

## 3. Hasil Perbandingan dengan R1 & Static Validation

| No | Kriteria Pemeriksaan | Hasil |
| :--- | :--- | :--- |
| 1 | Keseimbangan tanda kurung `()` & string `""` (`ASGRID_V2_2_1_R2.lsp`) | **LULUS** (`True`, 0 error) |
| 2 | Duplikasi fungsi top-level & command | **LULUS** (`NONE`; tepat 1 `c:ASGRID`, 1 `c:ASGRIDCHECK`, 1 `c:ASGRIDEDIT`) |
| 3 | Variabel global baru | **LULUS** (`NONE`) |
| 4 | Seluruh fungsi di luar ruang lingkup (`meta-extract-raw-payload`, `meta-parse-xrecord-dxf`, `meta-read-group`, `meta-update-group`, `c:ASGRID`, `c:ASGRIDEDIT`, `c:ASGRIDCHECK`) | **LULUS** (100% byte-identik dengan R1) |
| 5 | `ASGRID_V2_2_1.dcl` identik dengan R1 | **LULUS** (byte-identik) |
| 6 | Seluruh 4/4 pemanggilan `(dictremove ...)` di `asgrid:meta-restore-xrecord` diperiksa return value-nya | **LULUS** (`0` unchecked call) |
| 7 | Bypass `(or (null curPayload) ...)` telah dihapus | **LULUS** (`True`) |
| 8 | Zero `entmod` di `asgrid:meta-restore-xrecord` | **LULUS** (`True`) |
| 9 | Seluruh folder baseline sebelumnya (`V2.2 Phase 2`, `V2.2.1`, `V2.2.1 R1`) utuh | **LULUS** (`True`) |

## 4. Potensi Risiko yang Masih Tersisa
- **Non-ACID AutoLISP:** Jika AutoCAD mengalami *hard crash* di tengah operasi dictionary, pemulihan penuh tetap memerlukan `UNDO (Ctrl+Z)` yang membungkus transaksi di `c:ASGRIDEDIT`.
- **Simulasi kegagalan `dictremove`:** Pada runtime normal AutoCAD 2021, kegagalan `dictremove` jarang terjadi (biasanya hanya pada kondisi database korup/terkunci), sehingga jalur kegagalan `CRITICAL` diverifikasi secara statis dan perlu dipantau saat uji runtime.
- **Ambiguitas inheren DXF `280`:** Tetap berlaku sesuai batasan yang didokumentasikan pada Revision 1 untuk XRecord non-standar tanpa header `280` yang payload pertamanya `(280 . 0..5)`.
