# Technical Review — ASDIM V1.0 Phase 2 Revision 1 (Audit Hardening)

**File Diulas:** `ASDIM V1_0 PHASE 2 R1/ASDIM_V1_0_PHASE2_R1.lsp` (2.353 baris, 60 `defun`)  
**Baseline Phase 2:** `ASDIM V1_0 PHASE 2/ASDIM_V1_0_PHASE2.lsp` *(utuh, SHA-256 tidak berubah)*  
**Baseline Phase 1 R1:** `ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp` *(utuh, SHA-256 tidak berubah)*  
**Acuan ASGRID R3:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` *(utuh, SHA-256 tidak berubah)*

## 1. Implementasi Empat Perbaikan Audit

### FIX 1 — Pemeriksaan `SlotKey` Lintas Batch
- `asdim:scan-existing-dim-batches` memindai `(ssget "_X" (list '(0 . "DIMENSION") '(410 . "Model") (list -3 (list (asdim:dim-xdata-app)))))`, memvalidasi Model Space (`asdim:is-model-space-entity`), mem-parsing 7 field XData melalui `asdim:parse-dim-xdata`, memfilter hanya `SOURCE_GROUP_ID = sourceGroupId`, dan mengumpulkan daftar kanonik 5-tupel `EXISTING_SLOTS` via `asdim:make-slot-key`: `SourceGroupID|Orientation|DimType|SlotIdx|Placement`.
- Dimensi dari Group ID lain maupun dimensi tanpa XData `ASDIM_OBJ` valid tidak masuk ke `EXISTING_SLOTS`.
- `asdim:check-slot-collisions` membandingkan setiap job dalam `dimPlan` terhadap `EXISTING_SLOTS` sekaligus duplikasi internal. Gerbang ini dijalankan di `c:ASDIM` (Tahap 2A) **sebelum** provisioning style/layer dan **sebelum** satu pun `DIMENSION` dibuat. Jika ditemukan benturan, seluruh daftar slot bentrok dilaporkan dan proses dibatalkan tanpa menyentuh dimensi lama.

### FIX 2 — Immediate Entity Tracking & Safe Cleanup
- `c:ASDIM` mendefinisikan callback lokal `fn-track-created-ent` (0 variabel global baru) yang menambahkan `ename` ke accumulator lokal `createdEnts` dengan deduplikasi `(not (member newEname createdEnts))`.
- Di dalam `asdim:create-single-dim`, segera setelah `vla-AddDimRotated` mengembalikan `dimObj` dan `vlax-vla-object->ename` berhasil, `(if trackFn (apply trackFn (list ename)))` langsung dipanggil **sebelum** `vla-put-Layer`, `vla-put-StyleName`, `vla-put-TextHeight`, `vla-put-ArrowheadSize`, `vla-put-PrimaryUnitsPrecision`, `entmod` XData, `vla-Update`, dan readback verification.
- Jika operasi lanjutan gagal atau diinterupsi (`*error*`), `ename` sudah pasti tercatat di `createdEnts` dan dibersihkan oleh `asdim:cleanup-batch-entities` tanpa menyentuh dimensi lama maupun entitas ASGRID.

### FIX 3 — Verifikasi Readback `PrimaryUnitsPrecision`
- Setelah `vla-put-PrimaryUnitsPrecision` dipanggil pada `asdim:create-single-dim`, program membaca ulang dengan `(vl-catch-all-apply 'vla-get-PrimaryUnitsPrecision (list dimObj))`.
- Jika getter mengembalikan error ActiveX, bukan integer, atau tidak sama dengan `dimDec`, pembuatan dimensi dinyatakan gagal (`STATUS = "ERROR"`) dan entitas yang sudah tercatat pada `createdEnts` segera dihapus melalui cleanup.

### FIX 4 — Validasi & Provisioning `ASDIM-STYLE` yang Diperkuat
- `asdim:verify-dim-style` memeriksa secara eksplisit:
  - Nama style: `ASDIM-STYLE`
  - **DXF `340` (`DIMTXSTY`):** harus `ENAME` valid yang merujuk Text Style `ASDIM-ARIAL` (yang telah diverifikasi memakai `arial.ttf`).
  - **DXF `40` (`DIMSCALE`):** `1.0` (menerima omission default DXF AutoCAD `1.0` jika tidak ditulis terpisah, menolak nilai selain `1.0`).
  - **DXF `277` (`DIMLUNIT`):** `2` (Decimal — berlaku untuk `mm`, `cm`, dan `m`; menolak format non-Decimal seperti Scientific/Engineering/Architectural/Fractional).
  - **DXF `271` (`DIMDEC`):** wajib integer tepat sama dengan `expectedDimDec` (`0..4`).
  - **DXF `144` (`DIMLFAC`):** `1.0` bila ada, menjaga nilai pengukuran tetap dalam `DU` asli tanpa dikali/dibagi `unitFactor`.
- Pada pembuatan baru, `asdim:ensure-dim-style` menuliskan seluruh pasangan DXF tersebut termasuk `(78 . 0)` (`DIMZIN = 0` agar digit desimal sesuai `DIMDEC` tidak terpotong), lalu menjalankan verifikasi baca-balik wajib melalui `asdim:verify-dim-style`. Jika gagal, error dilaporkan disertai catatan bahwa entri tabel baru yang sempat terbuat dapat tertinggal sebagai definisi *inert*.
- Jika `ASDIM-STYLE` sudah ada tetapi tidak memenuhi salah satu syarat di atas, proses dihentikan tanpa mengubah style eksisting.

## 2. Jaminan Isolasi Global `DIMSTYLE` / `TEXTSTYLE`

- **0 panggilan `setvar`** dan **0 panggilan `command`/`command-s`** di seluruh `ASDIM_V1_0_PHASE2_R1.lsp`.
- Pembuatan `ASDIM-ARIAL`, `ASDIM-STYLE`, dan `AS-DIM` dilakukan langsung pada tabel/koleksi tanpa mengaktifkan style atau layer tersebut secara global, sehingga `DIMSTYLE`, `TEXTSTYLE`, `CLAYER`, `INSUNITS`, `Standard`, dan `ASGRID-ARIAL` tidak pernah berubah.

## 3. Hasil Static Validation

| Pemeriksaan | Hasil | Bukti |
| :--- | :--- | :--- |
| Keseimbangan tanda kurung & string | **LULUS** | `depth = 0`, `max_depth = 27`, 2.353 baris, 0 string tidak tertutup. |
| Duplicate `defun` & command | **LULUS** | 60 `defun` (57 dari Phase 2 + `asdim:make-slot-key`, `asdim:check-slot-collisions`, `fn-track-created-ent`), 0 duplikasi, tepat 1 command `c:ASDIM`. |
| Local variable scope | **LULUS** | Seluruh variabel lokal termasuk `pair`, `dimLunit`, `dimDec`, `dimLfac`, `existingSlots`, `slotCollisions`, `enameRes`, `rbPrec` dideklarasikan lokal; 0 variabel global baru. |
| Larangan `setvar`/`command`/`dictadd`/DCL | **LULUS** | **0 kemunculan** di seluruh kode eksekusi. |
| Pelestarian Phase 1 R1 & ASGRID R3 | **LULUS** | 31/31 fungsi Phase 1 R1 utuh; SHA-256 Phase 2, Phase 1 R1, dan ASGRID R3 tidak berubah. |

## 4. Batasan Teknis yang Belum Dapat Diverifikasi Secara Statis (`UNVERIFIED`)

1. Perilaku AutoCAD 2021 saat `entmod` DXF `340`, `277`, `271`, `40`, `144`, `78` pada record `DIMSTYLE` hasil `vla-Add` (serta fallback `entmake` `DIMSTYLE`), termasuk apakah AutoCAD menyimpan atau menghilangkan pasangan default `277 = 2` dan `40 = 1.0` pada `entget` baca-balik.
2. Writability dan readback aktual `vla-put-PrimaryUnitsPrecision` / `vla-get-PrimaryUnitsPrecision`, `StyleName`, `TextHeight`, dan `ArrowheadSize` pada `AcadDimRotated` di AutoCAD 2021.
3. Perilaku sudut `vla-AddDimRotated` di bawah UCS terputar (*rotated UCS*) di AutoCAD 2021.
4. Pengujian runtime: **NOT RUN** hingga pengguna menjalankannya langsung di AutoCAD 2021.
