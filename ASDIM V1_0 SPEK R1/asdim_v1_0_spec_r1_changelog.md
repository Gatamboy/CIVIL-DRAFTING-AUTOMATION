# Revision Changelog — ASDIM V1.0 Technical Specification (R0 → R1)

**Reference Baseline:** `ASDIM V1.0/ASDIM_V1_0_TECHNICAL_SPECIFICATION.md` (Commit `fa3debdba34008851885090426746d08fd170b70`, unverified remotely)

**Revised Document:** `ASDIM V1_0 SPEK/asdim_v1_0_technical_specification_R1.md`

**ASGRID Source Reference:** ASGRID V2.2.1 R3 (`3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15`, local baseline audited)

**Date:** 2026-11-26

## Summary of Changes

| Item | Affected Sections | Resolution Applied in Revision 1 | 
| ----- | ----- | ----- | 
| **1. Drawing Units & Printed-Size Conversion** | Sections 2, 7, 9, 11, 14, 17, 20 | Established ASGRID intervals as drawing-coordinate units (`DU`), treated `INSUNITS` strictly as informational (never modified), introduced unified `size_DU = size_print_mm * SCALE_DENOM * unitFactor` (`mm=1.0`, `cm=0.1`, `m=0.001`) across text height, arrow size, and offsets, and required explicit user unit confirmation (or clean stop) when `INSUNITS /= 4`. | 
| **2. Dimension Style Implementation** | Sections 8, 10, 17, 18, 19, 20 | Replaced the R0 `DIMSTYLE` ambiguity with one consistent AutoCAD 2021 hybrid strategy: `entmakex` for `ASDIM-ARIAL`, isolated base `ASDIM-STYLE` binding `DIMTXSTY` (DXF `340`) with `DIMSCALE = 1.0` without mutating global `DIMSTYLE`, per-entity ActiveX sizing (`TextHeight`, `ArrowheadSize`, `PrimaryUnitsPrecision`) for multi-scale DWG safety, and explicit post-creation effective-style verification. Marked DXF `340` binding (`T-21`) and `AcadDimRotated` property writability (`T-22`) as **UNVERIFIED** pending Phase 2 runtime tests. | 
| **3. Resource Provisioning & Rollback** | Sections 13, 17, 20 | Added explicit pre-existence snapshot and lifecycle policy table for all 5 resources (`ASDIM-ARIAL`, `ASDIM-STYLE`, `AS-DIM`, `ASDIM_OBJ`, `ASDIM_TX_TMP`): pre-existing resources are never modified/deleted; newly created shared table definitions are retained on success and retained as inert definitions on entity-generation failure (never unsafely `entdel`'d programmatically, revertible via 1× `UNDO`). | 
| **4. Model Space Filtering** | Sections 4, 5, 6, 12, 17, 18, 20 | Restricted both the geometry-integrity gate and `ASDIM_OBJ` discovery to Model Space via dual-layer filtering (`'(410 . "Model")` in `ssget "_X"` + per-entity DXF `410`/`67` validation), rejected Paper Space picks on `entsel`, preserved the top-level entity limitation (`BLOCK` definitions excluded), and added Test `T-23`. | 
| **5. Bubble Clearance & Dimension Offset** | Sections 4, 9, 11, 18 | Derived exact bubble outer-edge clearance directly from `ASGRID_V2_2_1_R3.lsp` (`fn-geometry-engine` L2376–L2388, `asgrid:annotation-engine` L1515–L1582, `asgrid:get-anno-ext-len` L395–L403): `d_clear = max(0, (annoExt + BUBBLE_DIA_PRINT * SCALE_DENOM) - EXT_LEN)` mapped per side (`Top`↔V-END, `Bottom`↔V-START, `Left`↔H-START, `Right`↔H-END) to trigger a non-blocking overlap warning when `d1 <= d_clear`. | 
| **6. UCS Runtime Test Placement** | Sections 6, 17, 18, 19 | Moved rotated/shifted UCS runtime test (`T-18`) from Phase 1 to **Phase 2** (where `vla-AddDimRotated` exists) and explicitly kept rotation-angle behavior under non-default UCS marked **UNVERIFIED**. | 
| **7. Editorial & Audit Polish** | Section 4, 7 | Fixed truncated pipe character in Section 4 audit table (`asgrid:audit-group-entities` row), standardized `ExtPt1`/`ExtPt2`/`DimLinePoint` terminology, and clarified `NUM_H = 1` / `NUM_V = 1` edge-case handling. | 
