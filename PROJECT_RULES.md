# PROJECT RULES — CIVIL DRAFTING AUTOMATION

**Repository Resmi:** `https://github.com/Gatamboy/CIVIL-DRAFTING-AUTOMATION.git`  
**Target Kompatibilitas Utama:** AutoCAD 2021 (AutoLISP + DCL + Visual LISP / ActiveX)  
**Prioritas Tertinggi:** Menjaga kestabilan baseline dan mencegah regresi.

---

## 1. Identitas & Tujuan Proyek

Repository ini merupakan toolkit automasi drafting teknik sipil dan bangunan berbasis AutoLISP, dengan target kompatibilitas utama **AutoCAD 2021**.

Modul yang sedang dikembangkan meliputi:
- **ASGRID** — pembuatan grid bangunan (`c:ASGRID`) dan audit integritas (*read-only*, `c:ASGRIDCHECK`).
- **ASGRIDEDIT** — pengeditan anotasi grid (`c:ASGRIDEDIT` Mode 1, perintah di dalam modul ASGRID).
- **ASDIM** — pembuatan dimensi otomatis berdasarkan metadata ASGRID (`c:ASDIM`).
- Modul drafting sipil dan struktur lainnya pada tahap berikutnya.

---

## 2. Pembagian Tanggung Jawab

| Peran / Alat | Tanggung Jawab |
| :--- | :--- |
| **Antigravity** | Workspace utama, pengelolaan file, implementasi, pemeriksaan, dan Git. |
| **Gemini** | Bantuan implementasi dan analisis kode. |
| **ChatGPT** | Perencanaan teknis, penyusunan spesifikasi, review independen, dan persetujuan perubahan. |
| **AutoCAD 2021** | Pengujian runtime dan validasi hasil gambar. |
| **GitHub** | Penyimpanan versi dan baseline resmi. |

---

## 3. Aturan Perlindungan Baseline

1. **Jangan mengubah atau menghapus versi yang sudah dinyatakan stabil.**
2. **Jangan menimpa folder versi sebelumnya.**
3. **Setiap revisi harus dibuat pada folder atau branch baru.**
4. **Jangan melakukan `commit`, `push`, `merge`, atau `reset` tanpa instruksi eksplisit.**
5. **Jangan menghapus file, riwayat Git, atau dokumentasi lama.**
6. **Sebelum mengedit file, periksa status Git dan identifikasi baseline.**
7. **Jika ada konflik antara instruksi dan kode baseline, hentikan perubahan dan laporkan.**

---

## 4. Status Baseline yang Harus Dipertahankan

| Modul / Versi | Status Resmi | Path Lokal Aktual | SHA-256 Terverifikasi (Git blob / LF) | Referensi Commit GitHub |
| :--- | :--- | :--- | :--- | :--- |
| **ASGRID V2.2.1 R3** (Kode & DCL) | Baseline resmi; pengujian AutoCAD 2021 `T-01` s.d. `T-10` dikonfirmasi lulus oleh pengguna | `ASGRID V2.2.1 R3/ASGRID_V2_2_1_R3.lsp` (`169.523` byte)<br>`ASGRID V2.2.1 R3/ASGRID_V2_2_1_R3.dcl` (`12.745` byte) | `.lsp`: `c97af3f59dbece69f7caab4dcd2d94af2e8f05d1f72743eaa04c120ff685570b`<br>`.dcl`: `e0e5013365adb7990f9b83b851da80cc658797e05d7a5ef03651d571574f05d3` | `01e1f608581724ec17bb1aecbf19313340dc3cfb` *(terverifikasi lokal; konsolidasi dokumentasi pada `3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15`)* |
| **ASGRID V2.2.1 R3** (Dokumentasi Konsolidasi) | Referensi arsitektur, metadata, dan status pengujian R3 | `ASGRID V2.2.1 R3 NOTE/asgrid_v2_2_1_r3_documentation.md` | — | `3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15` *(terverifikasi lokal)* |
| **ASDIM V1.0 — Spesifikasi Teknis R3** | Spesifikasi acuan resmi ASDIM V1.0 | `ASDIM V1_0 SPEK R3/asdim_v1_0_technical_specification_r3.md` | — | `612baa859d68e0fe560dfd654eafbe3614f7c1ce` *(terverifikasi lokal)* |
| **ASDIM V1.0 — Phase 1 R1** | Baseline resmi; pengujian AutoCAD 2021 dikonfirmasi lulus oleh pengguna *(lihat catatan arsip dokumen lokal)* | `ASDIM V1_0 PHASE 1 R1/ASDIM_V1_0_PHASE1_R1.lsp` (`50.119` byte) | `ad4add162aded6a5887117245ab37441a0a3d9380cfdf5406d6188642897eabf` | `424447e93bbbf2ba0d4e25a13f68f4e9022d9d70` *(terverifikasi lokal)* |
| **ASDIM V1.0 — Phase 2 R2** | Baseline kode saat ini; lulus static review independen; **belum diuji langsung oleh pengguna di AutoCAD 2021** | `ASDIM V1_0 PHASE 2 R2/ASDIM_V1_0_PHASE2_R2.lsp` (`107.698` byte) | `8f39fabf5d4fbe2c4f6f5dcaab42517401a4afdee547430486ec13dea46c5271` | `7ef804cd83a52ed9f2cd45c97dba9fa37800be27` *(terverifikasi lokal)* |

> **Catatan Verifikasi Hash:** Ukuran byte dan nilai SHA-256 pada tabel di atas mengacu pada **Git blob dengan line ending LF**. Pada lingkungan Windows dengan konfigurasi `core.autocrlf = true`, file hasil checkout di disk menggunakan line ending CRLF sehingga ukuran byte dan hash file mentah di disk berbeda, sementara isi Git blob (LF) tetap identik.

### Catatan Status Baseline Penting
- **ASGRID V2.2.1 R3:** Ditetapkan sebagai baseline resmi; pengujian runtime di AutoCAD 2021 untuk seluruh skenario checklist `T-01` s.d. `T-10` (`revision3_testing_checklist.md`) telah dikonfirmasi **lulus** oleh pengguna. Dokumentasi konsolidasi di `ASGRID V2.2.1 R3 NOTE/` dan file dokumentasi awal di `ASGRID V2.2.1 R3/` tetap dipertahankan utuh sesuai aturan perlindungan dokumentasi lama.
- **ASDIM Phase 1 R1:** Ditetapkan sebagai baseline resmi; pengujian runtime di AutoCAD 2021 telah dikonfirmasi **lulus** oleh pengguna. Sebagai catatan arsip, file checklist dan technical review lokal di `ASDIM V1_0 PHASE 1 R1/` masih memuat label status `NOT RUN` dan dipertahankan utuh sesuai aturan perlindungan dokumentasi lama.
- **ASDIM Phase 2 R2:** Merupakan **baseline kode saat ini**. Sudah lulus static review independen (2.395 baris, 59 `defun`), namun **belum diuji langsung oleh pengguna di AutoCAD 2021** (checklist runtime `R2-01` s.d. `R2-26` belum dijalankan). **Phase 2 R2 tidak boleh diberi status `runtime-tested`.**

---

## 5. Standar Implementasi AutoLISP

- **Target Runtime:** AutoCAD 2021 (AutoLISP standar + DCL + Visual LISP / ActiveX `vl-load-com` sesuai kebutuhan modul).
- **Kompatibilitas Metadata:** Pertahankan kompatibilitas struktur metadata yang telah ditetapkan:
  - Named Object Dictionary (NOD) `ASGRID_GROUPS` dan payload `XRECORD` Schema `"1.0"`.
  - XData `ASGRID_OBJ` (dan `ASGRID_TX_TMP` selama transaksi `ASGRIDEDIT`).
  - Isolasi ketat `ASDIM_OBJ` / `ASDIM_TX_TMP` dengan operasi 100% *read-only* terhadap entitas dan metadata ASGRID.
- **Isolasi Lingkungan Global:** Hindari perubahan global seperti `setvar`, `TEXTSTYLE`, `DIMSTYLE`, `CLAYER`, `INSUNITS`, `UCS`, `LTSCALE`, maupun modifikasi style `Standard` / `ASGRID-ARIAL` tanpa persetujuan spesifikasi.
- **Namespace & Polusi Simbol:** Gunakan namespace fungsi yang konsisten (`asgrid:*`, `asdim:*`) dan hindari konflik nama maupun penambahan variabel/fungsi global yang tidak diperlukan.
- **Keandalan & Keamanan Transaksi:** Terapkan *error handling* (`*error*`), cleanup, mekanisme rollback terukur, dan validasi entitas secara eksplisit.
- **Larangan Asumsi API/DXF Tanpa Bukti Runtime:** Jangan mengasumsikan fungsi ActiveX atau DXF tertentu berhasil di AutoCAD 2021 sebelum ada bukti runtime. Perhatikan batasan AutoLISP yang sudah terdokumentasi di baseline:
  - Jangan gunakan `(or (findfile ...))` untuk memilih string path file DCL; gunakan pencarian berurutan `setq` + `if`.
  - Selalu periksa `(tblsearch "APPID" appName)` sebelum memanggil `(regapp appName)`.
  - Jangan gunakan `entmod` untuk menimpa isi `XRECORD`; gunakan mekanisme *Replace-in-Dictionary*.
  - Jaga penghapusan entitas `entdel` dengan pengecekan `(if (entget e) (entdel e))`.
- **Integritas Status Pengujian:** Jangan pernah mengklaim `runtime-tested` berdasarkan hasil pemeriksaan statis.

---

## 6. Prosedur Setiap Pekerjaan

### A. Sebelum Implementasi
1. Baca file sumber dan dokumentasi baseline yang relevan.
2. Identifikasi fungsi dan bagian kode yang akan terdampak.
3. Buat rencana perubahan.
4. Sebutkan risiko kompatibilitas dan potensi regresi.
5. Tunggu persetujuan sebelum mengedit.

### B. Setelah Implementasi
1. Periksa perubahan terhadap baseline.
2. Periksa struktur AutoLISP, keseimbangan tanda kurung, string literal, dan duplikasi fungsi.
3. Periksa pemanggilan fungsi yang tidak dikenal.
4. Periksa dampak terhadap metadata, XData, XRecord, dan entitas gambar.
5. Buat changelog, technical review, dan testing checklist.
6. Pisahkan hasil *static review* dari *runtime testing* secara tegas.
7. Laporkan semua temuan dan keterbatasan secara jujur.

---

## 7. Status Lingkungan Workspace & Verifikasi Git

### Status Terkini
- **Workspace aktif:** `d:/Taufik/github/CIVIL-DRAFTING-AUTOMATION` dengan struktur folder modul `ASGRID` dan `ASDIM` berada langsung di root repository.
- **Status Git repository:** Direktori `.git` telah aktif pada workspace lokal dengan remote `origin` mengarah ke `https://github.com/Gatamboy/CIVIL-DRAFTING-AUTOMATION.git`.
- **Baseline lokal & branch:** Branch utama adalah `main` dengan commit baseline lokal `7ef804cd83a52ed9f2cd45c97dba9fa37800be27` (`7ef804c`); pembaruan dokumen aturan proyek ini dilakukan pada branch `chore/update-project-rules`.
- **Verifikasi riwayat & hash lokal:** Seluruh referensi commit baseline pada Bagian 4 (`01e1f60`, `3bb5d25`, `612baa8`, `424447e`, dan `7ef804c`) serta ukuran byte dan SHA-256 Git blob (format LF) keempat file kode/DCL baseline telah terverifikasi secara lokal.
- **Catatan operasional lingkungan Windows:** CLI `git` belum terdaftar pada `PATH` sistem default dan saat ini diakses melalui integrasi GitHub Desktop; konfigurasi `core.autocrlf = true` menyebabkan file di disk berformat CRLF, sedangkan rujukan ukuran byte dan SHA-256 pada Bagian 4 mengacu pada Git blob dengan line ending LF.

### Catatan Historis Inisialisasi (Arsip)
Pada saat dokumen `PROJECT_RULES.md` pertama kali disusun pada direktori kerja sebelumnya (`d:\Taufik\File\CIVIL-DRAFTING-AUTOMATION`), direktori tersebut belum memiliki `.git` dan CLI `git` belum terdeteksi di lingkungan sistem sehingga status branch dan hash commit GitHub sempat dicatat belum terverifikasi lokal. Catatan ini dipertahankan sebagai arsip historis dan telah digantikan oleh status workspace Git pada subbagian **Status Terkini** di atas.
