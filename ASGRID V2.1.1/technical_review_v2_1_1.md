# TECHNICAL REVIEW — ASGRID V2.1.1 (Stability & Metadata Hardening)

- **Baseline Audit:** `ASGRID_V2_1.lsp` (1738 baris) dan `ASGRID_V2_1.dcl` (271 baris)
- **Target Rilis:** `ASGRID_V2_1_1.lsp` dan `ASGRID_V2_1_1.dcl`
- **Catatan Laporan Eksternal:** Laporan audit eksternal (Google Antigravity) tidak ditemukan di workspace saat audit dilakukan; seluruh temuan didasarkan pada audit langsung baris demi baris terhadap kode aktual V2.1.
- **Status Pengujian:** Verifikasi statis menyeluruh telah dilakukan; eksekusi langsung di AutoCAD 2021 belum dilakukan dan perlu dijalankan mengikuti `TESTING_CHECKLIST_V2_1_1.md`.

## 1. Hasil Audit Baseline V2.1 (Celah yang Ditemukan)

| No | Area Audit (V2.1) | Temuan Inkonsistensi / Risiko | Mitigasi pada V2.1.1 |
| :--- | :--- | :--- | :--- |
| 1 | Verifikasi Metadata (`fn-execute-grid-creation`, baris 993–997) | Kegagalan baca-balik XRecord hanya mencetak `[Peringatan Metadata]` (*soft warning*) dan tetap melanjutkan pembuatan geometri. Tidak ada perbandingan isi (*deep compare*) antara spec asal dan data baca-balik. | Diubah menjadi **Hard Gate**: tulis → baca balik → validasi skema → `asgrid:meta-compare-specs` (`1e-6`). Kegagalan langsung membatalkan proses & rollback sebelum geometri dibuat. |
| 2 | Pelacakan Entitas & Rollback (`fn-draw-*`, `*error*`) | Menggunakan `entmake` tanpa menyimpan `ename` yang tercipta. Saat gagal/ESC di tengah proses, `*error*` hanya memanggil `UNDO _End` tanpa menghapus entitas parsial maupun XRecord yang baru ditulis. | Beralih ke `entmakex` dengan daftar lokal `txCreatedEnts` + `txSavedGroupId`/`txSavedXrec`. `fn-rollback-transaction` menghapus hanya objek dan XRecord milik transaksi aktif. |
| 3 | Validasi Jumlah Entitas & XData | `cntLine`, `cntBubble`, `cntText` hanya ditampilkan di ringkasan tanpa dibandingkan dengan ekspektasi dan tanpa memverifikasi keutuhan XData `ASGRID_OBJ` pada entitas hasil. | Ditambahkan `asgrid:calc-expected-counts` dan `fn-verify-tx-entities` sebelum commit transaksi. |
| 4 | Integritas Skema Metadata (`fn-meta-validate-spec`) | Belum memvalidasi tipe data setiap elemen `DIST_H`/`DIST_V`, struktur 3D point `BASE_PT_WCS`, string kosong, dan enum `BUBBLE_POS`. | Diperketat pada `asgrid:meta-validate-spec` mencakup 22 key wajib, tipe data, rentang positif, dan enum valid. |
| 5 | Diagnostik DWG | Belum tersedia cara aman (read-only) bagi pengguna untuk mengaudit kondisi metadata dan entitas seluruh grup di DWG. | Ditambahkan perintah **`ASGRIDCHECK`** yang 100% READ-ONLY. |

## 2. Desain Alur Transaksi V2.1.1

```text
[1] Dialog DCL (asgrid_v2_1_1) + Live Preview (non-permanen)
      │ (OK & fn-validate-all lolos)
      ▼
[2] Input Titik Awal WCS -> Mulai UNDO Group & txActive = T
      │
      ▼
[3] Pre-checks: Text Style ASGRID-ARIAL (arial.ttf), regapp ASGRID_OBJ, Linetype CENTER, Layers
      │
      ▼
[4] Generate Unique Group ID (scan NOD + XData) -> Build Spec -> Pre-write Integrity Check
      │
      ▼
[5] HARD GATE: Tulis XRecord ke NOD ASGRID_GROUPS -> Baca Balik -> Validasi -> Deep Compare (1e-6)
      │ (GAGAL -> Rollback XRecord + Abort sebelum geometri dibuat)
      ▼
[6] Geometry Engine (readBack) -> Cek cntLine == expL
      │ (GAGAL -> Rollback txCreatedEnts + XRecord + Abort)
      ▼
[7] Annotation Engine (readBack) -> Cek cntBubble == expB & cntText == expT
      │ (GAGAL -> Rollback txCreatedEnts + XRecord + Abort)
      ▼
[8] Final Verification: Cek XData ASGRID_OBJ & Group ID pada seluruh txCreatedEnts + Total == expTotal
      │ (GAGAL -> Rollback txCreatedEnts + XRecord + Abort)
      ▼
[9] COMMIT: Reset txActive, Tutup UNDO Group, Pulihkan CMDECHO, Cetak Ringkasan Terverifikasi
```

## 3. Rumus Eksak Expected Entity Count

Berdasarkan struktur aktual `fn-geometry-engine` dan `fn-annotation-engine` pada V2.1:
- **Garis Horizontal (`LINE`, `AxisDir="H"`):** `NUM_H`
- **Garis Vertikal (`LINE`, `AxisDir="V"`):** `NUM_V`
- **Total Garis (`expL`):** `NUM_H + NUM_V`
- **Pengali Ujung Bubble (`endsMult`):**
  - `"Both Ends"` → `2` (ujung `START` dan `END`)
  - `"Start"` atau `"End"` → `1`
- **Total Bubble (`expB`):** `(NUM_H + NUM_V) × endsMult`
- **Total Teks (`expT`):** `(NUM_H + NUM_V) × endsMult`
- **Total Entitas (`expTotal`):** `expL + expB + expT = (NUM_H + NUM_V) × (1 + 2 × endsMult)`

Contoh verifikasi:
- Grid `4 × 4` dengan `"Both Ends"`: `expL = 8`, `expB = 16`, `expT = 16`, `expTotal = 40`.
- Grid `4 × 4` dengan `"Start"`: `expL = 8`, `expB = 8`, `expT = 8`, `expTotal = 24`.

## 4. Arsitektur Shared Stateless Library & Evaluasi `ASGRIDCHECK`

- **Alasan Arsitektur:** Untuk menghindari duplikasi fungsi pembaca/validator metadata antara `c:ASGRID` dan `c:ASGRIDCHECK` (serta menyiapkan API bersih bagi `ASGRID EDIT` di versi berikutnya), 14 fungsi utilitas murni ditempatkan di namespace terkendali `asgrid:*`.
- **Zero Global State Variables:** Tidak ada satu pun variabel global data/state yang dibuat. Seluruh state transaksi (`txActive`, `txCreatedEnts`, `txSavedGroupId`, `txSavedXrec`, `dclId`, `undoOpen`) tetap lokal di dalam `c:ASGRID`.
- **Jaminan READ-ONLY pada `ASGRIDCHECK`:** Pemeriksaan statis memastikan `c:ASGRIDCHECK` memiliki **0** pemanggilan fungsi mutasi (`entmake`, `entmakex`, `entmod`, `entdel`, `dictadd`, `dictremove`, `command`, `setvar`).

## 5. Hasil Code Review Statis V2.1.1

| Kriteria Code Review | Hasil Verifikasi Statis |
| :--- | :--- |
| Keseimbangan tanda kurung `()` dan string `""` (`ASGRID_V2_1_1.lsp`) | **LULUS** (0 error) |
| Keseimbangan kurung kurawal `{}` dan string `""` (`ASGRID_V2_1_1.dcl`) | **LULUS** (0 error) |
| Kesesuaian Dialog ID (`asgrid_v2_1_1`) dan seluruh tile key LSP ↔ DCL | **LULUS** (0 tile hilang/tidak cocok) |
| Deklarasi lokal seluruh fungsi internal di `c:ASGRID` dan `c:ASGRIDCHECK` | **LULUS** (0 fungsi bocor) |
| Namespace top-level (`asgrid:*` dan `c:*` saja, 0 variabel global state) | **LULUS** (16 fungsi terkelola) |
| Kepatuhan READ-ONLY pada `c:ASGRIDCHECK` | **LULUS** (0 operasi mutasi) |
| Isolasi rollback (tidak pernah menghapus berdasarkan layer atau grup lain) | **LULUS** (berbasis `txCreatedEnts` & `txSavedGroupId`) |
| Keutuhan baseline V2.1 (`ASGRID_V2_1.lsp` & `ASGRID_V2_1.dcl`) | **LULUS** (tidak dimodifikasi) |

## 6. Analisis Risiko & Kompatibilitas AutoCAD 2021

- **Risiko terhadap fitur V2.1:** Sangat rendah. Modul Live Preview (Modul 7), Pagination DCL (Modul 8), Validasi Dialog (Modul 9), dan Text Style `ASGRID-ARIAL` (Modul 3) tidak diubah logikanya.
- **Keterbatasan `UNDO` vs `entdel` saat rollback:** Rollback dilakukan secara eksplisit via `entdel` pada `txCreatedEnts` dan `dictremove` pada `txSavedGroupId` sebelum `UNDO _End`, sehingga bahkan bila terjadi error di tengah grup UNDO, database DWG langsung bersih tanpa bergantung pada `UNDO _Back`.
- **Kesiapan `ASGRID EDIT`:** Karena `fn-geometry-engine` dan `fn-annotation-engine` membaca langsung dari `readBack` (hasil `asgrid:meta-read-group`), serta setiap objek memiliki XData `ASGRID_OBJ` dengan `Role` (`LINE`/`BUBBLE`/`TEXT`), `ASGRID EDIT` Mode 1 dan Mode 2 dapat langsung dibangun di atas API `asgrid:*` tanpa mengubah skema metadata `1.0`.
