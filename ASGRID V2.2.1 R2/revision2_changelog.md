# CHANGELOG — ASGRID V2.2.1 REVISION 2 (Final XRecord Restore Hardening)

- **Tanggal Rilis:** 2026-11-26
- **Baseline:** ASGRID V2.2.1 Revision 1 (`ASGRID V2.2.1 REVISION 1/ASGRID_V2_2_1_R1.lsp` & `ASGRID_V2_2_1.dcl` — seluruh versi sebelumnya tetap utuh)
- **Target Lingkungan:** AutoCAD 2021 (AutoLISP standar + DCL, WCS, milimeter)
- **Ruang Lingkup:** Perbaikan terfokus 2 temuan *independent code review* pada `asgrid:meta-restore-xrecord` (dan helper lokalnya `fn-reattach-cur`).
- **Status Pengujian:** Verifikasi statis lulus penuh; **belum dijalankan langsung di AutoCAD 2021**.

## Perubahan dari Revision 1 ke Revision 2

### 1. Temuan A — Menolak `curPayload` `nil`/Kosong pada Jalur Reattach & Fallback
- **Sebelumnya (R1):** Pada `fn-reattach-cur` Jalur 1, kondisi `(or (null curPayload) (equal chkPayload curPayload (asgrid:tol)))` masih mengembalikan `T` bila `curPayload` bernilai `nil`.
- **Sesudah (R2):**
  - `fn-reattach-cur` kini memeriksa di awal bahwa `curSnap` non-nil dan `curPayload` berhasil diekstrak serta tidak kosong (`(> (length curPayload) 0)`). Jika gagal/kosong, fungsi langsung menolak (`nil`) dan mencetak pesan `CRITICAL` (`UNDO Ctrl+Z`).
  - Baik Jalur 1 (*reattach* `curEname`) maupun Jalur 2 (*fallback* `fbEname`) wajib memenuhi `(and chkRec chkRaw (= (cdr (assoc 0 chkRaw)) "XRECORD") chkPayload (equal chkPayload curPayload (asgrid:tol)))`.
  - Penjagaan serupa ditambahkan untuk `origPayload` pada `asgrid:meta-restore-xrecord` (Step A) dan `readPayload` (Step E).

### 2. Temuan B — Pemeriksaan Return Value pada Seluruh 4 Pemanggilan `dictremove`
- **Call #1 (Step C — lepas entry lama sebelum `dictadd restEname`):** Diperiksa via `remOk`; bila gagal, batalkan sebelum `dictadd` dan bersihkan `restEname`.
- **Call #2 (`fn-reattach-cur` Jalur 1 — lepas reattach yang gagal verifikasi payload):** Diperiksa via `remBackOk`; bila gagal, set `canFallback = nil` (menghentikan Jalur 2 agar tidak terjadi `dictadd` bertabrakan), tidak menghapus `curEname`, dan mencetak pesan `CRITICAL` (`UNDO Ctrl+Z`).
- **Call #3 (`fn-reattach-cur` Jalur 2 Fallback — lepas `fbEname` yang gagal verifikasi payload):** Diperiksa via `remFbOk`; `fbEname` hanya di-`entdel` jika `remFbOk` berhasil. Jika gagal, `fbEname` dipertahankan (mencegah *dangling dictionary entry*) dengan pesan `CRITICAL`.
- **Call #4 (Step E — lepas `restEname` setelah read-back gagal):** Diperiksa via `remRestOk`; bila gagal, **tidak** memanggil `fn-reattach-cur` dan **tidak** menghapus `restEname`, langsung mencetak pesan `CRITICAL` (`UNDO Ctrl+Z`) dan mengembalikan `nil`.

## Komponen yang Tidak Diubah (100% Byte-Identik dengan R1)
- `asgrid:meta-extract-raw-payload`, `asgrid:meta-parse-xrecord-dxf`, `asgrid:meta-read-group`, `asgrid:meta-update-group`, `c:ASGRID`, `c:ASGRIDEDIT`, `c:ASGRIDCHECK`, `ASGRID_V2_2_1.dcl`, Schema `1.0`, NOD `ASGRID_GROUPS`, serta RegApp `ASGRID_OBJ` & `ASGRID_TX_TMP`.
