# Technical Review — ASDIM V1.0 Phase 2 Revision 2 (Independent Review Hardening)

**File Diulas:** `ASDIM V1_0 PHASE 2 R2/ASDIM_V1_0_PHASE2_R2.lsp` (2.395 baris, 59 `defun`, SHA-256: `8f39fabf5d4fbe2c4f6f5dcaab42517401a4afdee547430486ec13dea46c5271`)  
**Baseline Phase 2 R1:** `ASDIM V1_0 PHASE 2 R1/ASDIM_V1_0_PHASE2_R1.lsp` *(utuh, SHA-256 tidak berubah)*  
**Baseline Phase 1 R1:** `ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp` *(utuh, SHA-256 tidak berubah)*  
**Acuan ASGRID R3:** `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` *(utuh, SHA-256 tidak berubah)*

## 1. Mekanisme Cleanup ActiveX & Penghapusan `defun` Callback Global (FIX 1)

### A. Penanganan Kegagalan `vlax-vla-object->ename`
Pada `asdim:create-single-dim`:
1. Objek ActiveX hasil `vla-AddDimRotated` dipertahankan di variabel lokal `dimObj`.
2. Konversi segera dijalankan melalui `(vl-catch-all-apply 'vlax-vla-object->ename (list dimObj))`.
3. **Jika berhasil (`ENAME` valid):** `ename` segera didaftarkan ke accumulator `createdEnts` melalui `(apply trackFn (list ename))` **sebelum** pengaturan `Layer`, `StyleName`, `TextHeight`, `ArrowheadSize`, `PrimaryUnitsPrecision`, XData, dan readback. Kegagalan pada tahap lanjutan selalu terjangkau oleh `asdim:cleanup-batch-entities`.
4. **Jika konversi gagal:** konfigurasi entitas dihentikan seketika, lalu program menjalankan:
   - `(setq delRes (vl-catch-all-apply 'vla-Delete (list dimObj)))`
   - `(setq erasedRes (vl-catch-all-apply 'vlax-erased-p (list dimObj)))`
   - Tiga cabang diagnostik eksplisit: (i) `vla-Delete` sukses & `vlax-erased-p` terkonfirmasi `T`; (ii) `vla-Delete` tidak error tetapi `vlax-erased-p` tidak dapat memastikan status erased (**KRITIS** + instruksi cek manual); (iii) `vla-Delete` error (**KRITIS** + pesan error + instruksi cek manual/`UNDO`).
5. Entitas lama dan batch sebelumnya tidak pernah disentuh.

### B. Mekanisme Tracking Tanpa Polusi Namespace Global
Pada R1, `(defun fn-track-created-ent ...)` di dalam `c:ASDIM` masih mendefinisikan simbol fungsi. Pada R2, definisi tersebut dihapus total dan diganti dengan **lambda anonim lokal**:
```lisp
(setq trackFn
  (function
    (lambda (newEname)
      (if (and newEname (= (type newEname) 'ENAME) (not (member newEname createdEnts)))
        (setq createdEnts (cons newEname createdEnts))
      )
    )
  )
)
```
Karena AutoLISP menggunakan *dynamic scoping* dan `trackFn` serta `createdEnts` keduanya merupakan variabel lokal `c:ASDIM`, pendekatan ini mempertahankan alur cleanup yang sama tanpa menambah satu pun `defun` global maupun variabel global baru.

## 2. Validasi DXF `78` (`DIMZIN = 0`) pada `ASDIM-STYLE` (FIX 2)

`asdim:verify-dim-style` kini memeriksa seluruh 6 parameter wajib secara eksplisit:
- **DXF `340` (`DIMTXSTY`):** merujuk Text Style `ASDIM-ARIAL` (`arial.ttf`).
- **DXF `40` (`DIMSCALE`):** `1.0`.
- **DXF `277` (`DIMLUNIT`):** `2` (Decimal untuk `mm`, `cm`, `m`).
- **DXF `271` (`DIMDEC`):** integer tepat sama dengan `expectedDimDec`.
- **DXF `144` (`DIMLFAC`):** `1.0` (pengukuran tetap dalam `DU`).
- **DXF `78` (`DIMZIN`):** wajib ada dan bernilai integer `0`; jika tidak tersedia, bukan integer, atau `/= 0`, verifikasi gagal tanpa mengubah style eksisting.

`asdim:ensure-dim-style` menuliskan `(cons 78 0)` pada kedua jalur pembuatan (`vla-Add` + `entmod` dan fallback `entmake`) lalu melakukan readback melalui `asdim:verify-dim-style`. Global `DIMSTYLE` tidak pernah diubah.

## 3. Validasi Ketat `SCHEMA_VER = "1.0"` pada XData `ASDIM_OBJ` (FIX 3)

- `asdim:parse-dim-xdata` mempertahankan struktur 7 field (`SourceGroupID`, `DimBatchID`, `Orientation`, `DimType`, `SlotIdx`, `Placement`, `SchemaVer`) dan kini mensyaratkan `(= (type sver) 'STR)` sekaligus `(= sver (asdim:dim-schema-ver))` (`"1.0"`).
- XData dengan `SCHEMA_VER` kosong, bukan string, atau berbeda dari `"1.0"` menghasilkan `nil`, sehingga tidak masuk ke `EXISTING_SLOTS` dan tidak diubah/dihapus.
- `asdim:scan-existing-dim-batches` menghitung jumlah entitas tersebut dalam `INVALID_XDATA_CNT` dan `c:ASDIM` mencetak peringatan diagnostik jelas di command line.

## 4. Hasil Static Validation vs. Hal yang Belum Dapat Dibuktikan Secara Statis

### A. Hasil Static Validation (LULUS)
- Keseimbangan tanda kurung & string: `depth = 0`, `max_depth = 28`, 2.395 baris, 0 string tidak tertutup.
- `defun`: 59 fungsi (0 duplikasi; `fn-track-created-ent` dihapus bersih; 31/31 fungsi Phase 1 R1 utuh), tepat 1 command `c:ASDIM`.
- **0 panggilan** `setvar`, `command`, `command-s`, `dictadd`, `dictremove`, `dictrename`, `load_dialog`, `new_dialog`, `start_dialog`.
- Alur `vla-Delete` + `vlax-erased-p`, immediate tracking via `trackFn`, verifikasi DXF `78 = 0`, dan `(= sver (asdim:dim-schema-ver))` seluruhnya terkonfirmasi pada kode.
- SHA-256 baseline Phase 2 R1, Phase 1 R1, dan ASGRID R3 100% tidak berubah.

### B. Belum Dapat Dibuktikan Tanpa AutoCAD 2021 (`UNVERIFIED`)
1. Apakah AutoCAD 2021 mempertahankan pasangan DXF `(78 . 0)` pada `entget` tabel `DIMSTYLE` pasca `entmod`/`entmake` (karena nilai `0` adalah nilai default pada sebagian build DXF AutoCAD; jika AutoCAD menghilangkan `(78 . 0)` saat `entget`, pengujian runtime `R2-08`/`R2-11` akan langsung mengungkapkannya).
2. Perilaku aktual `vla-Delete` dan `vlax-erased-p` pada objek ActiveX `AcDbRotatedDimension` saat `vlax-vla-object->ename` disimulasikan gagal.
3. Writability & readback `PrimaryUnitsPrecision`, `StyleName`, `TextHeight`, `ArrowheadSize`, serta orientasi `vla-AddDimRotated` di bawah *rotated UCS* di AutoCAD 2021.
4. Status pengujian runtime: **`NOT RUN`**.
