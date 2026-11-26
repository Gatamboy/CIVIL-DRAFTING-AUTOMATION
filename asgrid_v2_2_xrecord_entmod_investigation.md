# LAPORAN INVESTIGASI ERROR — ASGRID V2.2 (`ASGRIDEDIT` MODE 1)

- **Tanggal Investigasi:** 2026-11-26
- **Target File Diaudit:** `ASGRID V2.2 Phase 2/ASGRID_V2_2.lsp`
- **Lingkungan Target:** AutoCAD 2021 (AutoLISP standar + DCL, WCS, milimeter)
- **Pesan Error Dilaporkan:**
  > `Verifikasi metadata pasca-update gagal: DIST_H_COUNT (3) tidak sama dengan jumlah item DIST_H (6)`
- **Status Kode Produksi:** Read-only audit (tidak ada kode produksi, metadata, maupun struktur XRecord/XData yang diubah).

---

## 1. Ringkasan Eksekutif (Root Cause)

Akar masalah **bukan** berada pada `fn-edit-build-new-spec`, `asgrid:meta-build-xrecord-payload`, maupun `asgrid:meta-read-group`, melainkan pada **`asgrid:meta-update-group` (baris 688–705)**—serta berdampak sekunder pada **`asgrid:meta-restore-xrecord` (baris 678–683)**—yang menggunakan **`(entmod newXrecData)`** untuk memperbarui objek `XRECORD` di AutoCAD 2021.

Pada AutoCAD 2021, fungsi AutoLISP `(entmod ...)` terhadap entitas **`AcDbXrecord` tidak menimpa (*overwrite*) data resbuf lama**, melainkan **menambahkan (*append*) payload baru ke belakang data resbuf yang sudah ada**. Akibatnya, satu kali pemanggilan `entmod` pada STEP E menggandakan seluruh pasangan `(300 . "DIST_H_ITEM") (40 . val)` di dalam XRecord dari **3 item menjadi 6 item**.

---

## 2. Investigasi Berbasis Bukti Kode Aktual

### A. Sebelum Update (`oldSpec`)
- **Jumlah item `DIST_H`:** `3` (pada grid 4 sumbu horizontal, misal `(4000.0 4000.0 4000.0)`).
- **Nilai `DIST_H_COUNT`:** `3`.
- **Konsistensi:** **Konsisten 100%.** Pada `fn-edit-select-and-validate` (baris 2941), `oldSpec` wajib lulus `(asgrid:meta-validate-spec spec)` sebelum dialog `asgrid_edit_v2_2` ditampilkan. Jika sebelum update sudah tidak konsisten (`3 != 6`), proses edit akan langsung dibatalkan dan tidak pernah mencapai STEP E.

### B. Saat Membangun `newSpec` & Payload
- **`fn-edit-build-new-spec` (baris 3339–3362):**
  - Hanya memperbarui `BUBBLE_DIA_PRINT`, `TEXT_H_PRINT`, `TEXT_STYLE`, `FONT_FILE`, `BUBBLE_POS`, `ANNO_EXT_LEN`, dan `UPDATED_AT`.
  - `DIST_H` dan `DIST_H_COUNT` masuk ke cabang `(t (setq res (append res (list pair))))`, sehingga tetap berisi **3 item** dan nilai **`3`**.
  - `newSpec` kembali lulus `(asgrid:meta-validate-spec newSpec)` sebelum STEP B (baris 3440).
- **`asgrid:meta-build-xrecord-payload` (baris 518–572):**
  - Baris 532 menulis tepat 1 pasang `(300 . "DIST_H_COUNT") (90 . 3)`.
  - Baris 535–537 menjalankan `(foreach dVal (cdr (assoc "DIST_H" spec)) ...)` sebanyak 3 iterasi → menghasilkan **tepat 3 pasang** `(300 . "DIST_H_ITEM") (40 . dVal)`.
- **`asgrid:meta-update-group` (baris 694–701):**
  - Filter `(member code '(-1 0 5 102 330 100 280))` membersihkan seluruh group code data lama (`300`, `1`, `10`, `40`, `90`) dari `header`.
  - Variabel `newXrecData` **sebelum `entmod`** terbukti bersih dan hanya mengandung **3 `DIST_H_ITEM`** (tidak ada item lama yang terbawa di sisi AutoLISP).

### C. Saat `entmod` pada `XRECORD` (Titik Pertama Terjadinya Duplikasi)
- **Lokasi:** `asgrid:meta-update-group`, baris 702:
  ```lisp
  (not (null (entmod newXrecData)))
  ```
- **Perilaku AutoCAD 2021:** Memanggil `(entmod newXrecData)` pada entitas `XRECORD` menyebabkan AutoCAD **menggabungkan (*append*)** resbuf baru di belakang resbuf lama yang tersimpan pada objek `AcDbXrecord`.
- **Isi XRecord di DWG pasca-`entmod`:**
  ```text
  [Header XRecord: -1, 0, 5, 330, 100, 280]
  + [Blok Payload Lama : SCHEMA_VER ... DIST_H_COUNT=3, 3x DIST_H_ITEM ... BUBBLE_DIA_PRINT=8.0 ...]
  + [Blok Payload Baru : SCHEMA_VER ... DIST_H_COUNT=3, 3x DIST_H_ITEM ... BUBBLE_DIA_PRINT=10.0 ...]
  ```
- **Dampak sekunder pada Rollback (`asgrid:meta-restore-xrecord`, baris 678–683):**
  Fungsi pemulihan rollback juga memanggil `(entmod snapshotData)` pada XRecord yang sama. Ketika kegagalan STEP E memicu rollback, `entmod` pada rollback berisiko **menambahkan blok lama sekali lagi** (menjadi 9 item) apabila tidak dibersihkan melalui `UNDO`.

### D. Saat Read-Back (`asgrid:meta-read-group`, baris 594–655)
Loop `(foreach pair dList ...)` memindai seluruh isi XRecord yang kini memuat Blok Lama + Blok Baru:
- **Key skalar (`DIST_H_COUNT`, baris 625–627):** Ditambahkan 2 kali ke `res` (keduanya bernilai `3`). Saat `asgrid:meta-validate-spec` memanggil `(cdr (assoc "DIST_H_COUNT" spec))`, fungsi `assoc` mengambil kemunculan **pertama** → tetap terbaca **`3`**. *(Untuk key yang diubah seperti `BUBBLE_DIA_PRINT`, `assoc` juga akan membaca nilai lama dari blok pertama.)*
- **Key list (`DIST_H_ITEM`, baris 606–608):** Setiap kemunculan `(300 . "DIST_H_ITEM") (40 . val)` di-append ke `dH` → `3` item (Blok Lama) + `3` item (Blok Baru) = **`6` item**.
- Saat `asgrid:meta-validate-spec` (baris 772–775) mengevaluasi `(/= cntH (length dH))` → `(/= 3 6)` → muncul pesan error tepat:
  `DIST_H_COUNT (3) tidak sama dengan jumlah item DIST_H (6).`

---

## 3. Simulasi Penelusuran Data (Grid 4 × 4)

| Tahap Penelusuran | `DIST_H_COUNT` | Jumlah `DIST_H` / `DIST_H_ITEM` | `BUBBLE_DIA_PRINT` (via `assoc`) | Status |
| :--- | :---: | :---: | :---: | :--- |
| 1. `oldSpec` (hasil `meta-read-group` awal) | `3` | `3` | `8.0` | Konsisten |
| 2. `newSpec` (hasil `fn-edit-build-new-spec`) | `3` | `3` | `10.0` | Konsisten |
| 3. `newXrecData` (sebelum `entmod`, baris 701) | `3` | `3` | `10.0` | Bersih |
| 4. XRecord di DWG (setelah `entmod`, baris 702) | `3` (muncul 2×) | **`6`** (3 lama + 3 baru) | `8.0` lalu `10.0` | **Korup (Appended)** |
| 5. `readBack` (hasil `meta-read-group` STEP E) | `3` | **`6`** | `8.0` (kemunculan pertama) | **Gagal Validasi (`3 != 6`)** |

**Cara verifikasi langsung di AutoCAD 2021 (read-only):**
Jalankan perintah berikut di command line sebelum dan sesudah `entmod` pada grup uji `"ASG-0001"`:
```lisp
(entget (cdr (assoc -1 (dictsearch (asgrid:meta-get-root-dict nil) "ASG-0001"))))
```
Pasca-`entmod`, seluruh pasangan `(300 . ...)` akan terlihat muncul ganda.

---

## 4. Fungsi Bermasalah

1. **`asgrid:meta-update-group` (`ASGRID_V2_2.lsp`, baris 688–705):** Menggunakan `(entmod newXrecData)` pada `XRECORD` yang memicu perilaku *append* resbuf di AutoCAD 2021.
2. **`asgrid:meta-restore-xrecord` (`ASGRID_V2_2.lsp`, baris 678–683):** Menggunakan `(entmod snapshotData)` pada `XRECORD` sehingga rollback juga berisiko meng-*append* resbuf.

---

## 5. Rekomendasi Perbaikan Minimal & Aman untuk AutoCAD 2021

Ganti metode `entmod` XRecord dengan pola standar AutoLISP **Replace-in-Dictionary (`entmakex` + `dictremove` + `dictadd` + `entdel`)** tanpa mengubah struktur XRecord, Schema `1.0`, XData `ASGRID_OBJ`, generator `ASGRID`, maupun geometri `LINE`:

1. **Perbaikan `asgrid:meta-update-group (groupId newSpec)`:**
   - Buat XRecord baru yang bersih dengan `(entmakex (append '((0 . "XRECORD") (100 . "AcDbXrecord") (280 . 1)) (asgrid:meta-build-xrecord-payload newSpec)))`.
   - Catat `oldXrecEname` dari `(dictsearch rootDict groupId)`.
   - Lepas entry lama dengan `(dictremove rootDict groupId)` dan pasang entry baru dengan `(dictadd rootDict groupId newXrecEname)`.
   - Jika `dictadd` gagal, pasang kembali `(dictadd rootDict groupId oldXrecEname)` dan hapus `newXrecEname` via `(entdel newXrecEname)`.
   - Jika `dictadd` berhasil, hapus `oldXrecEname` via `(entdel oldXrecEname)`.
2. **Perbaikan `asgrid:meta-restore-xrecord` (untuk Rollback Bersih):**
   - Terima `groupId` dan `oldSpec` (atau payload bersih dari snapshot), buat XRecord bersih via `entmakex`, lepas XRecord yang gagal via `dictremove` + `entdel`, lalu pasang kembali XRecord bersih via `dictadd` pada kunci `groupId`.
3. **Jaminan Kompatibilitas:**
   - Seluruh entitas grid merujuk ke `groupId` string (misal `"ASG-0001"`) pada XData `ASGRID_OBJ` dan **tidak** bergantung pada Object Handle XRecord.
   - Mengganti objek XRecord di bawah kunci dictionary `groupId` yang sama tetap 100% kompatibel dengan `ASGRID`, `ASGRIDEDIT`, `ASGRIDCHECK`, serta seluruh grid buatan V2.1, V2.1.1, dan V2.1.2.
