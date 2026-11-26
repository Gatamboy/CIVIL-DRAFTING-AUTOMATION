# ASDIM V1.0 — Automatic Grid Dimension Generator Technical Specification (Revision 2)

**Project:** CIVIL DRAFTING AUTOMATION  
**Repository:** [CIVIL-DRAFTING-AUTOMATION](https://github.com/Gatamboy/CIVIL-DRAFTING-AUTOMATION)  
**Specification Revision:** Revision 2 (R2)  
**Previous Specification Baseline:** `ASDIM V1_0 SPEK/asdim_v1_0_technical_specification_R1.md` *(preserved unchanged)*  
**ASGRID R3 Reference Commit (Provided by User):** `3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15` *(UNVERIFIED against remote GitHub due to offline sandbox; local workspace baseline `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` audited directly)*  
**Reference Module:** ASGRID V2.2.1 R3  
**Target Application:** AutoCAD 2021  
**Development Language:** AutoLISP + DCL + Visual LISP / ActiveX (`vl-load-com`)  
**Document Status:** Technical Specification Only (No implementation code written; no runtime tests executed)  
**Date:** 2026-11-26

## 1. Overview

**ASDIM V1.0** is an independent AutoCAD 2021 automation module within the **CIVIL DRAFTING AUTOMATION** toolkit. Its sole purpose is to automatically generate native AutoCAD `DIMENSION` entities (horizontal/vertical chain and overall dimensions) from structural building grid geometry previously created by **ASGRID V2.2.1 R3**.

ASDIM V1.0 operates in strict read-only integration with ASGRID: it reads ASGRID's Named Object Dictionary (`ASGRID_GROUPS`) metadata and entity XData (`ASGRID_OBJ`) in Model Space, independently verifies that actual Model Space `LINE` geometry still matches that metadata, and creates native dimensions under its own isolated identity (`ASDIM_OBJ`), layer (`AS-DIM`), Text Style (`ASDIM-ARIAL`), and Dimension Style (`ASDIM-STYLE`).

Throughout this specification:
- **VERIFIED** denotes facts audited directly from `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp`.
- **PROPOSED DESIGN** denotes engineering design specifications for ASDIM V1.0.
- **UNVERIFIED** denotes AutoCAD 2021 runtime/API behaviors or remote commit hashes that cannot be proven statically and must be verified before acceptance.

## 2. Objectives and Scope

### Core Objectives
1. Generate native AutoCAD `DIMENSION` entities accurately aligned with ASGRID V2.2.1 R3 grid axes in Model Space (WCS).
2. Support both uniform and nonuniform grid spacing via cumulative coordinate calculation.
3. Enforce strict isolation from ASGRID: zero writes to ASGRID's XRecords, XData, layers, Text Styles, or entities.
4. Enforce Arial font compliance (`arial.ttf` → `ASDIM-ARIAL` → `ASDIM-STYLE`) with zero silent font substitution and zero modification to global styles.
5. Require explicit user confirmation of actual drawing units on every run without assuming millimeters or modifying `INSUNITS`.
6. Provide transaction safety, exact 5-tuple slot duplicate prevention, and controlled regeneration/replacement on repeated execution.

### In-Scope Capabilities (V1.0)
- **Horizontal chain dimensions** (measuring consecutive intervals along WCS X between vertical grid lines).
- **Vertical chain dimensions** (measuring consecutive intervals along WCS Y between horizontal grid lines).
- **Horizontal overall dimension** (measuring total span along WCS X from first to last vertical grid line).
- **Vertical overall dimension** (measuring total span along WCS Y from first to last horizontal grid line).
- **Independent direction toggles:** Horizontal only, Vertical only, or Both directions.
- **Independent type toggles:** Chain only, Overall only, or Chain + Overall together.
- **User-configurable placement and offsets:** Top/Bottom for horizontal dimensions, Left/Right for vertical dimensions, with separate numeric offsets for chain and overall rows plus non-blocking bubble-overlap warnings.
- **Multi-group DWG support:** Selecting and dimensioning one specific ASGRID group at a time without affecting other ASGRID groups or unrelated dimensions.

## 3. Out of Scope

The following capabilities are explicitly excluded from ASDIM V1.0:
- Wall, partition, or structural member (column/beam/slab) dimensions.
- Door, window, or opening dimensions.
- Room or interior space dimensions.
- Automatic architectural or structural object detection.
- Editing ASGRID geometry or modifying ASGRID metadata/XRecords/XData.
- Live Preview inside the ASDIM DCL dialog.
- Automatic detection of free/empty space around the drawing.
- Automatic collision avoidance with ASGRID bubbles, neighboring drawing objects, or other grid groups.
- Paper Space dimensioning or associative reactor-driven auto-updates.

## 4. ASGRID R3 Source Audit

**Audit Source:** Local workspace baseline `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` (4,202 lines; SHA-256 `c97af3f59dbece69f7caab4dcd2d94af2e8f05d1f72743eaa04c120ff685570b`).  
**Remote Commit Verification Status:** **UNVERIFIED** against remote commit `3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15` because outbound network access is disabled in this environment. All line numbers below are verified against the local R3 baseline file.

### Inspected Functions & Verified Behavior

| Function Name (Actual in R3) | Source Lines | Verified Implementation Behavior |
| :--- | :--- | :--- |
| `asgrid:compute-cumulative` | L117–L125 | Initializes `acc = (float startCoord)` and `res = (list acc)`, then iteratively appends `acc = (+ acc (float val))` for each element in `distList`. Returns a list of length `(+ 1 (length distList))`. |
| `asgrid:check-insunits-warning` | L138–L144 | Reads `(getvar "INSUNITS")`. Prints a non-blocking info message if `INSUNITS /= 4` (Millimeters); does **not** modify `INSUNITS` and does **not** abort execution. |
| `asgrid:validate-text-style` | L225–L266 | Checks `STYLE` table entry, rejects shape/vertical bit flags, rejects non-zero fixed height (`(assoc 40)`), checks font file presence, and inspects `AcadAnnotative` XData to reject annotative styles. |
| `asgrid:find-arial-ttf` | L268–L292 | Searches `arial.ttf` via `findfile`, `%WINDIR%\Fonts\`, `%SystemRoot%\Fonts\`, and `C:\Windows\Fonts\`. Returns full path string or `nil`. |
| `asgrid:ensure-arial-style` | L294–L370 | Verifies `arial.ttf` first; creates or validates `ASGRID-ARIAL` without modifying `Standard` or global `TEXTSTYLE`. Aborts if Arial cannot be verified. |
| `asgrid:make-obj-xdata-for-app` / `asgrid:make-obj-xdata` | L376–L391 | Builds DXF `-3` XData list under `appName` (`"ASGRID_OBJ"` by default) with 6 ordered resbufs: `(1000 . groupId)`, `(1000 . role)`, `(1000 . axisDir)`, `(1070 . axisIdx)`, `(1000 . endTag)`, `(1000 . schemaVer)`. |
| `asgrid:get-anno-ext-len` | L395–L403 | Resolves `ANNO_EXT_LEN` as float if numeric and `> 0.0`; otherwise falls back automatically to `EXT_LEN` (supporting older V2.1–V2.1.2 metadata). |
| `asgrid:meta-get-root-dict` | L406–L435 | Looks up `"ASGRID_GROUPS"` in `(namedobjdict)`. When `createIfMissing` is `nil`, performs strictly read-only lookup and returns dictionary ename or `nil`. |
| `asgrid:parse-entity-xdata-for-app` / `asgrid:parse-entity-xdata` | L456–L489 | Reads `(entget ename (list appName))`, validates `>= 6` XData entries and exact DXF codes/domains (`Role` in `("LINE" "BUBBLE" "TEXT")`, `AxisDir` in `("H" "V")`, `AxisIdx > 0` int, `EndTag` in `("NONE" "START" "END")`, non-empty `GroupID` & `SchemaVer`). Returns `(list gid role dir idx etag sver)` or `nil`. |
| `asgrid:meta-build-xrecord-payload` | L518–L572 | Serializes group spec into alternating `(300 . <KEY>)` + typed DXF value pairs (`1` String, `10` 3D Point, `40` Real, `90` Int32), including repeated `(300 . "DIST_H_ITEM") (40 . val)` and `(300 . "DIST_V_ITEM") (40 . val)`, plus optional `ANNO_EXT_LEN` and `UPDATED_AT`. |
| `asgrid:meta-parse-xrecord-dxf` | L577–L656 | Parses raw XRecord DXF pairs into an association list, aggregating `DIST_H_ITEM` into `"DIST_H"` and `DIST_V_ITEM` into `"DIST_V"`, and recording malformed entries under `"_READ_ERRORS"`. |
| `asgrid:meta-read-group` | L659–L675 | Read-only lookup: fetches `"ASGRID_GROUPS"` (`createIfMissing = nil`), calls `(dictsearch rootDict groupId)`, reads `(entget xrecEname)`, and delegates to `asgrid:meta-parse-xrecord-dxf`. Returns spec alist or `nil`. |
| `asgrid:meta-validate-spec` | L1226–L1370 | Validates 24 required keys, non-empty strings, `NUM_H > 0`, `NUM_V > 0`, `DIST_H_COUNT = (length DIST_H) = max(0, NUM_H - 1)`, `DIST_V_COUNT = (length DIST_V) = max(0, NUM_V - 1)`, all interval values `> 0.0`, valid 3D `BASE_PT_WCS`, numeric `ELEVATION`, positive `SCALE_DENOM`/`TEXT_H_PRINT`/`BUBBLE_DIA_PRINT`/`EXT_LEN`, and valid `BUBBLE_POS`. Returns list of error strings (`nil` when valid). |
| `asgrid:annotation-engine` | L1494–L1594 | Stateless generator computing `cumY = (asgrid:compute-cumulative y0 dH)`, `cumX = (asgrid:compute-cumulative x0 dV)`, `totalY = (- (last cumY) y0)`, `totalX = (- (last cumX) x0)`. Computes `bubRadModel = (/ (* BUBBLE_DIA_PRINT SCALE_DENOM) 2.0)`. Places horizontal bubbles at `x0 - annoExt - bubRadModel` (`START`) and `x0 + totalX + annoExt + bubRadModel` (`END`), and vertical bubbles at `y0 - annoExt - bubRadModel` (`START`) and `y0 + totalY + annoExt + bubRadModel` (`END`). |
| `asgrid:audit-group-entities` *(Note 1)* | L1827–L1968 | Scans top-level entities via `(ssget "_X" (list (list -3 (list "ASGRID_OBJ"))))`. Checks DXF type vs `Role`, `AxisIdx` bounds, `EndTag` validity, duplicate `(Role, AxisDir, AxisIdx, EndTag)` slots, and entity counts. **Does NOT verify actual `LINE` DXF (10)/(11) coordinates against metadata and does NOT filter by Model Space.** |
| `fn-meta-build-spec` & `fn-meta-save-group` | L2199–L2265 | Local to `c:ASGRID`. `fn-meta-build-spec` sets `BASE_PT_WCS = ptWcs` and `ELEVATION = (caddr ptWcs)`. `fn-meta-save-group` creates an `XRECORD` via `entmakex` and registers it in `ASGRID_GROUPS` via `dictadd`. |
| `fn-geometry-engine` | L2353–L2397 | Local to `c:ASGRID`. Computes `cumY` from `(y0, dH)` and `cumX` from `(x0, dV)`. Draws horizontal `LINE` entities (`AxisDir="H"`) from `(x0 - ext, curY, z0)` to `(x0 + totalX + ext, curY, z0)` and vertical `LINE` entities (`AxisDir="V"`) from `(curX, y0 - ext, z0)` to `(curX, y0 + totalY + ext, z0)` directly in WCS via `entmakex`. |
| Base Point UCS→WCS Transform | L3076–L3080 | Inside `c:ASGRID`: acquires `basePtUcs` via `getpoint`, converts to WCS via `(setq basePt (trans basePtUcs 1 0))`, and passes `basePt` to `fn-execute-grid-creation`. |

**Critical Audit Findings:**
1. **Naming Discrepancy:** The actual function name in `ASGRID_V2_2_1_R3.lsp` is **`asgrid:audit-group-entities`** (L1827), not `asgrid:meta-audit-group-entities`.
2. **Coordinate Drift & Space Blind Spot:** `asgrid:audit-group-entities` neither compares `LINE` DXF `(10)`/`(11)` endpoints against metadata nor filters `ssget "_X"` to Model Space. ASDIM V1.0 must implement its own Model Space–filtered WCS geometry-consistency gate (Section 6).
3. **Single-Axis Edge Case:** `asgrid:meta-validate-spec` permits `NUM_H = 1` (`DIST_H_COUNT = 0`, `DIST_H = nil`) or `NUM_V = 1` (`DIST_V_COUNT = 0`, `DIST_V = nil`). ASDIM must disable/skip horizontal dimensions when `NUM_V < 2`, disable/skip vertical dimensions when `NUM_H < 2`, and abort cleanly if both `NUM_H < 2` and `NUM_V < 2`.

## 5. Metadata Integration

ASDIM V1.0 is a **read-only consumer** of ASGRID metadata and embeds its own self-contained read-only reader/validator helpers (`asdim:read-asgrid-group`, `asdim:parse-asgrid-xdata`) so it operates independently even when `ASGRID_V2_2_1_R3.lsp` is not loaded.

### Selection & Resolution Pipeline (PROPOSED DESIGN)
1. **Model Space Entity Selection:** Prompt the user with `entsel` to pick any entity belonging to the target ASGRID grid (`LINE`, `CIRCLE`, or `TEXT`). Verify immediately that the picked entity belongs to Model Space (`(cdr (assoc 410 ed)) = "Model"` and `(cdr (assoc 67 ed))` is `nil` or `0`); reject Paper Space entities with a clear message.
2. **Group ID Extraction:** Inspect `(entget ename '("ASGRID_OBJ"))` and parse the 6-element XData list (`GroupID`, `Role`, `AxisDir`, `AxisIdx`, `EndTag`, `SchemaVer`). Reject non-ASGRID entities or malformed XData.
3. **NOD XRecord Lookup (Read-Only):** Look up `"ASGRID_GROUPS"` in `(namedobjdict)` without creating any dictionary, call `(dictsearch rootDict groupId)`, read `(entget xrecEname)`, and parse `(300 . <KEY>)` + typed DXF value pairs.
4. **Pre-Generation Metadata Validation:** Validate all required fields before opening the DCL dialog:
   - `SCHEMA_VER` must equal `"1.0"`.
   - `GROUP_ID` must match the `GroupID` from the picked entity's XData.
   - `BASE_PT_WCS` must be a valid 3-element numeric WCS point `(x0 y0 z0)`, and `ELEVATION` must match `z0` within `1e-6`.
   - `NUM_H >= 1`, `NUM_V >= 1`; `DIST_H_COUNT = (length DIST_H) = (max 0 (1- NUM_H))`; `DIST_V_COUNT = (length DIST_V) = (max 0 (1- NUM_V))`.
   - Every interval in `DIST_H` and `DIST_V` must be strictly numeric and `> 0.0`.
   - At least one dimensionable direction must exist (`NUM_V >= 2` or `NUM_H >= 2`); if both are `< 2`, abort with a clear explanation.
   - `SCALE_DENOM` and `EXT_LEN` must be numeric and `> 0.0`.
   - Optional `ANNO_EXT_LEN` (fallback to `EXT_LEN`), `BUBBLE_DIA_PRINT`, and `BUBBLE_POS` are read for bubble-clearance warnings (Section 9).
5. **Handling Missing, Invalid, or Incompatible Metadata:** Abort immediately before dialog/generation, report the exact failing key or rule, and advise running `ASGRIDCHECK`.
6. **Multi-Group DWG Isolation:** All lookups, geometry checks, and dimension generation are strictly scoped to the single selected `GROUP_ID`.

**Hard Invariant:** ASDIM must **never** modify any `ASGRID_OBJ` entity or any entry inside `ASGRID_GROUPS`.

## 6. Coordinate System

### Confirmed ASGRID R3 Coordinate Semantics (VERIFIED)
From `fn-geometry-engine` (L2353–L2397) and `asgrid:annotation-engine` (L1494–L1594):
- **Coordinate Frame:** All ASGRID geometry and `BASE_PT_WCS` are stored in **WCS** (drawing-coordinate units, `DU`). User input in `c:ASGRID` is converted via `(trans basePtUcs 1 0)` (L3079).
- **Elevation:** `z0 = (caddr BASE_PT_WCS)` equals `ELEVATION`. All grid lines, bubbles, and texts lie on WCS plane `Z = z0`.
- **Axis Distribution:**
  - `cumX = (asgrid:compute-cumulative x0 DIST_V)` → X-coordinates of the `NUM_V` vertical grid lines (`A, B, C...`), `totalX = (- (last cumX) x0)`.
  - `cumY = (asgrid:compute-cumulative y0 DIST_H)` → Y-coordinates of the `NUM_H` horizontal grid lines (`1, 2, 3...`), `totalY = (- (last cumY) y0)`.
- **Grid Intersections:** Vertical axis `j` (`1 <= j <= NUM_V`) × horizontal axis `i` (`1 <= i <= NUM_H`) in WCS:
  $$P_{j,i} = (\text{cumX}[j-1],\ \text{cumY}[i-1],\ z_0)$$
- **Grid Line Endpoints (WCS):**
  - Horizontal line `i` (`AxisDir="H"`, `AxisIdx=i`): `(x0 - EXT_LEN, cumY[i-1], z0)` to `(x0 + totalX + EXT_LEN, cumY[i-1], z0)`.
  - Vertical line `j` (`AxisDir="V"`, `AxisIdx=j`): `(cumX[j-1], y0 - EXT_LEN, z0)` to `(cumX[j-1], y0 + totalY + EXT_LEN, z0)`.

### Model Space Filtering & Entity-Space Validation (PROPOSED DESIGN)
Both the geometry-integrity gate and `ASDIM_OBJ` dimension discovery are **strictly restricted to Model Space** using a two-layer filter:
1. **Selection Set Filter (`ssget "_X"`):** Every database scan must include `'(410 . "Model")`:
   - ASGRID geometry scan: `(ssget "_X" (list '(0 . "LINE") '(410 . "Model") (list -3 '("ASGRID_OBJ"))))`
   - ASDIM dimension scan: `(ssget "_X" (list '(0 . "DIMENSION") '(410 . "Model") (list -3 '("ASDIM_OBJ"))))`
2. **Per-Entity DXF Validation:** On every matched or picked entity, verify `(entget ename)`:
   - `(strcase (cdr (assoc 410 ed)))` equals `"MODEL"`, AND
   - `(cdr (assoc 67 ed))` is either `nil` or `0` (excluding Paper Space entities where `67 = 1`).
3. **Top-Level Entity Limitation:** `ssget "_X"` with `'(410 . "Model")` inspects top-level Model Space entities only. Grid lines or dimensions nested inside `BLOCK` (`INSERT`) definitions are **not** scanned and are not supported in V1.0.

### UCS & WCS Handling in ASDIM (PROPOSED DESIGN)
- ASDIM performs all coordinate calculations in **WCS** and must **never** modify the user's persistent active UCS (`UCSNAME`, `UCSORG`, `UCSXDIR`, `UCSYDIR`).
- **UNVERIFIED / REQUIRES PHASE 2 RUNTIME TEST (T-18):** Whether AutoCAD 2021's `vla-AddDimRotated` interprets `RotationAngle` (`0.0` / `(/ pi 2.0)`) relative to WCS or the active UCS XY plane when a rotated/shifted non-default UCS is active has **not** been proven at runtime. This must be verified in **Phase 2** (once the Dimension Generation Engine exists) under Test Case `T-18`. If `vla-AddDimRotated` aligns to active UCS, Phase 2 must explicitly enforce WCS orientation on the created dimension object (`Normal = (0 0 1)` and WCS horizontal direction) without altering the user's active UCS.

### Tolerance & Geometry-Consistency Gate (PROPOSED DESIGN)
Before generating any dimension, `asdim:verify-grid-geometry` validates all Model Space `LINE` entities matching `GROUP_ID` and `Role = "LINE"`:
1. Verify exact counts: `NUM_H` horizontal lines (`AxisIdx = 1..NUM_H`) and `NUM_V` vertical lines (`AxisIdx = 1..NUM_V`), with zero missing or duplicate indices.
2. For each horizontal line `i`, compare actual DXF `(10)` and `(11)` WCS points against expected `(x0 - ext, cumY[i-1], z0)` and `(x0 + totalX + ext, cumY[i-1], z0)` (accepting reversed endpoint order) within geometric tolerance `tol_geom = 1e-4` DU (metadata floating-point comparisons use `1e-6`).
3. For each vertical line `j`, compare actual `(10)` and `(11)` against `(cumX[j-1], y0 - ext, z0)` and `(cumX[j-1], y0 + totalY + ext, z0)` within `tol_geom`.
4. **Failure Policy:** If any `LINE` is missing, duplicated, moved, rotated, stretched, or shifted in Z beyond `tol_geom`, ASDIM **must abort** with a specific diagnostic message and must **not** generate dimensions from inconsistent metadata.

## 7. Dimension Calculation

### Axis-to-Dimension Mapping (VERIFIED AGAINST R3 GEOMETRY)
| Dimension Orientation | Measurement Axis | Source Coordinates | Source Interval List | Condition Required |
| :--- | :--- | :--- | :--- | :--- |
| **Horizontal Dimensions** | WCS X | `cumX` (vertical grid positions `A, B, C...`) | `DIST_V` (`NUM_V - 1` intervals) | `NUM_V >= 2` |
| **Vertical Dimensions** | WCS Y | `cumY` (horizontal grid positions `1, 2, 3...`) | `DIST_H` (`NUM_H - 1` intervals) | `NUM_H >= 2` |

### Worked Example (Nonuniform Spacing, in Drawing Units)
- Given `BASE_PT_WCS = (x0, y0, z0)` and `DIST_V = (4000.0, 5000.0, 3000.0)` (`NUM_V = 4`):
  - `cumX = (x0, x0 + 4000, x0 + 9000, x0 + 12000)`
  - **Horizontal Chain (3 entities):** `4000`, `5000`, `3000`
  - **Horizontal Overall (1 entity):** `12000`
- Given `DIST_H = (3000.0, 4500.0)` (`NUM_H = 3`):
  - `cumY = (y0, y0 + 3000, y0 + 7500)`
  - **Vertical Chain (2 entities):** `3000`, `4500`
  - **Vertical Overall (1 entity):** `7500`

### Extension Line Origin Points (`ExtPt1`, `ExtPt2`) (PROPOSED DESIGN)
Let `xMin = x0`, `xMax = (last cumX)`, `yMin = y0`, `yMax = (last cumY)`, and `ext = EXT_LEN` (all in drawing units `DU`):
- **Horizontal Chain `k`** (`k = 0 .. NUM_V - 2`, `SlotIdx = k + 1`):
  - **Top:** `ExtPt1 = (cumX[k], yMax + ext, z0)`, `ExtPt2 = (cumX[k+1], yMax + ext, z0)`
  - **Bottom:** `ExtPt1 = (cumX[k], yMin - ext, z0)`, `ExtPt2 = (cumX[k+1], yMin - ext, z0)`
- **Horizontal Overall** (`SlotIdx = 0`):
  - **Top:** `ExtPt1 = (xMin, yMax + ext, z0)`, `ExtPt2 = (xMax, yMax + ext, z0)`
  - **Bottom:** `ExtPt1 = (xMin, yMin - ext, z0)`, `ExtPt2 = (xMax, yMin - ext, z0)`
- **Vertical Chain `k`** (`k = 0 .. NUM_H - 2`, `SlotIdx = k + 1`):
  - **Left:** `ExtPt1 = (xMin - ext, cumY[k], z0)`, `ExtPt2 = (xMin - ext, cumY[k+1], z0)`
  - **Right:** `ExtPt1 = (xMax + ext, cumY[k], z0)`, `ExtPt2 = (xMax + ext, cumY[k+1], z0)`
- **Vertical Overall** (`SlotIdx = 0`):
  - **Left:** `ExtPt1 = (xMin - ext, yMin, z0)`, `ExtPt2 = (xMin - ext, yMax, z0)`
  - **Right:** `ExtPt1 = (xMax + ext, yMin, z0)`, `ExtPt2 = (xMax + ext, yMax, z0)`

### Drawing Units & Printed-Size Conversion (REVISION 2 RESOLUTION)
- **Drawing Coordinates:** All ASGRID intervals (`DIST_H`, `DIST_V`, `EXT_LEN`, `ANNO_EXT_LEN`, `BASE_PT_WCS`) are treated strictly as **drawing-coordinate units (`DU`)**. ASDIM must **never** assume every drawing is in millimeters.
- **Role of `INSUNITS`:** `(getvar "INSUNITS")` is strictly **informational** and is used **only** to recommend an initial default selection in the DCL. `INSUNITS` does **not** prove the actual units used to create the grid, and ASDIM must **never** modify `INSUNITS`.
- **Unified Printed-to-Drawing Conversion Formula:**
  All user-entered printed sizes — **Printed Text Height**, **Printed Arrow Size**, **Chain Offset (Printed mm)**, and **Overall Row Spacing (Printed mm)** — are converted to drawing units (`DU`) via:
  $$\text{size}_{\text{DU}} = \text{size}_{\text{print,mm}} \times \text{SCALE\_DENOM} \times \text{unitFactor}$$
  where `unitFactor` (`DU per mm`) is determined from the user-confirmed **Actual Drawing Unit** selection:
  | Confirmed Actual Drawing Unit | `unitFactor` (`DU / mm`) | Recommended Default When `INSUNITS` = | Example (`2.5 mm` print @ `1:100`) |
  | :--- | :--- | :--- | :--- |
  | Millimeters (`mm`) | `1.0` | `4` (Millimeters) | `250.0 DU` |
  | Centimeters (`cm`) | `0.1` | `5` (Centimeters) | `25.0 DU` |
  | Meters (`m`) | `0.001` | `6` (Meters) | `0.25 DU` |
- **Mandatory Explicit Unit Confirmation Rule (ALL Drawings, Including `INSUNITS = 4`):**
  - On **every** execution — **including when `INSUNITS = 4`** — ASDIM displays `(getvar "INSUNITS")` as informational context, pre-selects a recommended initial unit (`mm` if `INSUNITS = 4`, `cm` if `5`, `m` if `6`, or `mm` with a warning if `0`/other), and **requires the user to explicitly confirm the actual drawing unit** (`chk_unit_confirm` unchecked by default) before dimension generation is allowed.
  - Dimension generation is strictly blocked until explicit unit confirmation is given.
  - If the user cannot verify the actual drawing unit (leaves confirmation unchecked or cancels), ASDIM **stops cleanly without creating any dimensions**.

### Precision, Rounding, and Invalid Intervals
- All coordinates are computed in double-precision float without intermediate rounding.
- Decimal display precision (`0`–`4`, default `0`) is applied per entity via `PrimaryUnitsPrecision`.
- Any interval `<= 0.0` or non-numeric fails pre-generation validation; zero-length dimensions are never created.
- When `NUM_V = 1`, Horizontal controls are disabled and skipped; when `NUM_H = 1`, Vertical controls are disabled and skipped.

## 8. Dimension Generation Engine

### Evaluation of AutoCAD 2021 Native Dimension Methods (PROPOSED DESIGN)
| Method | API Signature | Pros | Cons | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **`vla-AddDimRotated`** (ActiveX) | `(vla-AddDimRotated ms ExtPt1 ExtPt2 DimLinePoint rotRad)` | Native `AcDbRotatedDimension`; enforces exact orthogonal angle (`0.0` or `(/ pi 2.0)`); immune to sub-tolerance diagonal tilt; no OSNAP/command interference. | Requires `(vl-load-com)`; rotation-angle frame under rotated UCS is **UNVERIFIED** (Phase 2 Test `T-18`). | **SELECTED (Primary)** |
| **`vla-AddDimAligned`** (ActiveX) | `(vla-AddDimAligned ms ExtPt1 ExtPt2 DimLinePoint)` | Native `AcDbAlignedDimension`. | Orientation follows `ExtPt1 -> ExtPt2` vector; tiny numerical drift causes slight tilt. | Rejected |
| **`entmakex` `DIMENSION`** | Raw DXF | Pure AutoLISP. | Requires anonymous `*D` block synthesis; fragile in AutoCAD 2021. | Rejected |
| **`command "_.DIMLINEAR"`** | Command line | Native dimension. | Vulnerable to OSNAP, UCS, `CMDECHO`, and global `DIMSTYLE` state. | Rejected |

### Entity Creation & Property Assignment
For every dimension generated in Model Space (`vla-get-ModelSpace`):
1. Call `(vla-AddDimRotated ms (vlax-3d-point ExtPt1) (vlax-3d-point ExtPt2) (vlax-3d-point DimLinePoint) rotRad)` with `rotRad = 0.0` (Horizontal) or `(/ pi 2.0)` (Vertical).
2. Assign properties directly on the returned VLA object (without altering global `CLAYER` or `DIMSTYLE`):
   - `Layer` = target layer (default `"AS-DIM"`).
   - `StyleName` = `"ASDIM-STYLE"`.
   - `TextHeight` = `textHeight_DU` *(writability marked **UNVERIFIED** until Phase 2 Test `T-22`)*.
   - `ArrowheadSize` = `arrowSize_DU` *(writability marked **UNVERIFIED** until Phase 2 Test `T-22`)*.
   - `PrimaryUnitsPrecision` = `dimDec` (`0..4`) *(writability marked **UNVERIFIED** until Phase 2 Test `T-22`)*.
3. Attach temporary XData (`ASDIM_TX_TMP`) via `entmod` on `(vlax-vla-object->ename dimObj)` and append the ename to `txCreatedEnts`.
4. Call `(vla-Update dimObj)`.

## 9. Dimension Placement

### Four Supported Placement Options
- **Horizontal Placement:** `Top` or `Bottom`
- **Vertical Placement:** `Left` or `Right`

### Offset Model & Row Spacing (Consistent Unified Units)
Both offsets are entered in **printed millimeters** and converted to drawing units (`DU`) using the Section 7 unified formula:
- `d1 = chainOffsetPrint_mm * SCALE_DENOM * unitFactor` (default `chainOffsetPrint_mm = 8.0`)
- `rowGap = rowSpacingPrint_mm * SCALE_DENOM * unitFactor` (default `rowSpacingPrint_mm = 8.0`)
- `d2 = d1 + rowGap`
- `d_ov = d2` when both Chain and Overall are enabled; `d_ov = d1` when Overall only is enabled.

### Dimension Line Coordinates (`DimLinePoint`)
| Orientation & Placement | Chain Row (`DimLinePoint`) | Overall Row (`DimLinePoint`) |
| :--- | :--- | :--- |
| **Horizontal — Top** | `((xMin + xMax)/2, yMax + ext + d1, z0)` | `((xMin + xMax)/2, yMax + ext + d_ov, z0)` |
| **Horizontal — Bottom** | `((xMin + xMax)/2, yMin - ext - d1, z0)` | `((xMin + xMax)/2, yMin - ext - d_ov, z0)` |
| **Vertical — Left** | `(xMin - ext - d1, (yMin + yMax)/2, z0)` | `(xMin - ext - d_ov, (yMin + yMax)/2, z0)` |
| **Vertical — Right** | `(xMax + ext + d1, (yMin + yMax)/2, z0)` | `(xMax + ext + d_ov, (yMin + yMax)/2, z0)` |

### Bubble Clearance Calculation & Overlap Warning (DERIVED FROM ASGRID R3 SOURCE)
From `ASGRID_V2_2_1_R3.lsp` (`fn-geometry-engine` L2376–L2388 and `asgrid:annotation-engine` L1515, L1524–L1526, L1541–L1582):
- `ext = EXT_LEN` (grid line endpoint distance from outer grid intersection, in `DU`).
- `annoExt = ANNO_EXT_LEN` if present and `> 0.0`, else fallback to `EXT_LEN` (`asgrid:get-anno-ext-len`, L395–L403).
- `bubRadModel = (/ (* BUBBLE_DIA_PRINT SCALE_DENOM) 2.0)` (L1524) → bubble diameter in `DU` as drawn by ASGRID is `bubDia_DU = (* BUBBLE_DIA_PRINT SCALE_DENOM)`. *(Note: ASGRID R3 does not multiply `bubRadModel` by a `unitFactor`; if `unitFactor /= 1.0`, ASDIM should warn that ASGRID's stored bubble geometry assumes `1.0 DU/mm`.)*
- `drawStart = (or (= BUBBLE_POS "Both Ends") (= BUBBLE_POS "Start"))` (L1525).
- `drawEnd   = (or (= BUBBLE_POS "Both Ends") (= BUBBLE_POS "End"))` (L1526).
- **Bubble Outer-Edge Distance from Outer Grid Intersection (VERIFIED):**
  - Bubble center sits at `annoExt + bubRadModel` from the outer grid intersection (L1541, L1552, L1570, L1581).
  - Therefore, the outermost tangent edge of the bubble sits at:
    $$d_{\text{bubble,outer}} = \text{annoExt} + 2 \times \text{bubRadModel} = \text{annoExt} + (\text{BUBBLE\_DIA\_PRINT} \times \text{SCALE\_DENOM})$$
- **Placement-to-Bubble-Presence Mapping (VERIFIED):**
  | ASDIM Placement | ASGRID Axis & EndTag on Same Side | Bubble Present When |
  | :--- | :--- | :--- |
  | **Horizontal — Top** | Vertical (`V`) — `END` (`yMax + ...`) | `drawEnd` is true (`"Both Ends"` or `"End"`) |
  | **Horizontal — Bottom** | Vertical (`V`) — `START` (`yMin - ...`) | `drawStart` is true (`"Both Ends"` or `"Start"`) |
  | **Vertical — Left** | Horizontal (`H`) — `START` (`xMin - ...`) | `drawStart` is true (`"Both Ends"` or `"Start"`) |
  | **Vertical — Right** | Horizontal (`H`) — `END` (`xMax + ...`) | `drawEnd` is true (`"Both Ends"` or `"End"`) |
- **Minimum Clearance Beyond `EXT_LEN` Baseline:**
  - If a bubble is present on the selected placement side:
    $$d_{\text{clear}} = \max\Big(0.0,\ (\text{annoExt} + \text{BUBBLE\_DIA\_PRINT} \times \text{SCALE\_DENOM}) - \text{EXT\_LEN}\Big)$$
  - If no bubble is present on that side: $d_{\text{clear}} = 0.0$.
- **Overlap Warning Rule (Non-Blocking):** If a bubble is present on the selected side and `d1 <= d_clear`, ASDIM displays a clear non-blocking warning in the DCL and command line. Automatic collision avoidance remains out of scope.

## 10. Arial Text Style and Dimension Style

### Mandatory Font & Style Standards
- **Font:** Arial (`arial.ttf`)
- **Dedicated Text Style:** `ASDIM-ARIAL`
- **Dedicated Dimension Style:** `ASDIM-STYLE`

### Single Consistent AutoCAD 2021 Implementation Strategy
Because AutoCAD 2021's ActiveX `AcadDimStyle` object does **not** expose direct writable properties for `DIMTXT`/`DIMASZ`/`DIMTXSTY` (relying instead on `CopyFrom` which would risk mutating global `DIM*` system variables), ASDIM V1.0 defines one strict, non-invasive hybrid strategy:

1. **Step 1 — Verify `arial.ttf`:** Resolve `arial.ttf` via multi-path lookup (`findfile`, `%WINDIR%\Fonts\`, `%SystemRoot%\Fonts\`, `C:\Windows\Fonts\`, matching `asgrid:find-arial-ttf` L268–L292). Abort immediately if not found; never substitute another font.
2. **Step 2 — Provision / Verify `ASDIM-ARIAL` (DXF `entmakex` + Table Audit):**
   - If `(tblsearch "STYLE" "ASDIM-ARIAL")` is `nil`: create via `entmakex` (`STYLE` table record) with `fontFile = "arial.ttf"`, fixed height `(40 . 0.0)`, width factor `(41 . 1.0)`, non-annotative.
   - If `ASDIM-ARIAL` already exists: verify (a) font resolves to `arial.ttf` (DXF `3` or `ACAD` XData `1000` `"Arial"`), (b) fixed height DXF `40` = `0.0` (within `1e-6`), and (c) non-annotative. Abort with a conflict error if any check fails.
3. **Step 3 — Provision / Verify `ASDIM-STYLE` (Isolated Base Style, Zero Global `DIMSTYLE` Mutation):**
   - Base `ASDIM-STYLE` binds `DIMTXSTY` (DXF `340`) to `ASDIM-ARIAL` and sets `DIMSCALE = 1.0` cleanly without modifying the drawing's active `DIMSTYLE` or global `DIM*` sysvars.
   - **Primary Creation Method (UNVERIFIED — Phase 2 Test `T-21`):** If `(tblsearch "DIMSTYLE" "ASDIM-STYLE")` is `nil`, create via `(vla-Add (vla-get-DimStyles doc) "ASDIM-STYLE")` (creating a valid AutoCAD 2021 `AcDbDimStyleTableRecord` without activating it), then bind `(340 . <ename of ASDIM-ARIAL>)` and `(40 . 1.0)` on `(tblobjname "DIMSTYLE" "ASDIM-STYLE")` via `entmod` (or direct `entmakex` `DIMSTYLE` if `entmod` rejects `340`). **Both `entmod` of DXF `340` on a `DIMSTYLE` table record and direct `entmakex` `DIMSTYLE` are marked UNVERIFIED** until confirmed in AutoCAD 2021 during Phase 2 Test `T-21`.
   - **Existing `ASDIM-STYLE` Verification:** Read `(entget (tblobjname "DIMSTYLE" "ASDIM-STYLE"))`, resolve DXF `340` → `STYLE` name, and confirm it references `"ASDIM-ARIAL"`. If it points to any non-Arial style, abort with a conflict error.
4. **Step 4 — Per-Entity Scaling & Formatting (Multi-Scale DWG Safe):**
   - Per-group visual parameters are computed via `size_DU = size_print_mm * SCALE_DENOM * unitFactor` (Section 7) and applied on each generated `AcDbRotatedDimension` VLA object (`StyleName = "ASDIM-STYLE"`, `TextHeight = textHeight_DU`, `ArrowheadSize = arrowSize_DU`, `PrimaryUnitsPrecision = dimDec`) rather than mutating shared `ASDIM-STYLE` across runs.
   - **UNVERIFIED — Phase 2 Test `T-22`:** Direct writability of `StyleName`, `TextHeight`, `ArrowheadSize`, and `PrimaryUnitsPrecision` on `AcadDimRotated` in AutoCAD 2021 (and confirmation that overriding `TextHeight`/`ArrowheadSize` preserves `ASDIM-ARIAL` font binding) must be verified at runtime in Phase 2.
5. **Step 5 — Post-Generation Effective Style Verification:** On every generated dimension entity in STEP C, read back DXF `(3 . "ASDIM-STYLE")`, `vla-get-StyleName = "ASDIM-STYLE"`, `vla-get-TextHeight ≈ textHeight_DU`, `vla-get-ArrowheadSize ≈ arrowSize_DU`, and confirm `ASDIM-STYLE`'s DXF `340` resolves to `ASDIM-ARIAL` (`arial.ttf`).
6. **Strict Non-Mutation Guarantee:** Never modify `Standard`, `ASGRID-ARIAL`, existing user Text Styles, existing user Dimension Styles, or global system variables (`TEXTSTYLE`, `DIMSTYLE`, `DIMTXT`, `DIMASZ`, `DIMSCALE`, `INSUNITS`).

## 11. DCL Interface

The DCL file (`ASDIM_V1_0.dcl`) defines dialog `asdim_v1_0` (no Live Preview tile in V1.0):

| Section / Panel | Control Type | Key (Proposed) | Description & Validation |
| :--- | :--- | :--- | :--- |
| **A. Source ASGRID Group & Units** | Read-only text, Popup, Toggle, Button | `grp_id`, `grp_info`, `grp_insunits`, `pop_unit`, `chk_unit_confirm`, `btn_pick_grp` | Displays `GROUP_ID`, `NUM_H × NUM_V`, `SCALE_DENOM`, `EXT_LEN`, informational `INSUNITS`, Actual Drawing Unit selector (`mm`/`cm`/`m`, pre-selected from `INSUNITS` as recommendation only), **mandatory unit confirmation toggle (`chk_unit_confirm`, unchecked by default for ALL drawings including `INSUNITS = 4`)**, and re-pick button. |
| **B. Dimension Selection** | Checkboxes (`toggle`) | `chk_horiz`, `chk_vert`, `chk_chain`, `chk_overall` | Independent toggles. At least one direction and one type required. Auto-disables `chk_horiz` when `NUM_V < 2` and `chk_vert` when `NUM_H < 2`. |
| **C. Placement & Offsets (Printed mm)** | Radio buttons, Edit boxes, Warning text | `rad_h_top`, `rad_h_bot`, `rad_v_left`, `rad_v_right`, `ed_chain_off`, `ed_overall_off`, `txt_bub_warn` | Selects Top/Bottom and Left/Right; positive numeric offsets in printed mm; displays non-blocking bubble-clearance warning when `d1 <= d_clear`. |
| **D. Style, Sizing & Layer** | Edit boxes, Popup, Read-only text | `ed_txt_h`, `ed_arrow_sz`, `pop_prec`, `ed_layer`, `txt_dimstyle` | Printed Text Height (`> 0` mm), Printed Arrow Size (`> 0` mm), Decimal Precision (`0`–`4`), Layer (default `AS-DIM`), and read-only style badge (`ASDIM-STYLE / ASDIM-ARIAL`). |
| **E. Actions** | Buttons | `accept`, `cancel` | `OK` validates all fields and **blocks submission unless `chk_unit_confirm` is explicitly checked**; `Cancel` aborts with zero DWG changes. |

**DCL Safety Rules:** Escape `&` as `&&` in `boxed_column` labels; locate `ASDIM_V1_0.dcl` with sequential `setq` + `if` (`findfile`), never `(or (findfile ...))`.

## 12. Dimension Identity and Management

### Dedicated XData RegApp: `ASDIM_OBJ` (and `ASDIM_TX_TMP`)
ASDIM registers **`ASDIM_OBJ`** and **`ASDIM_TX_TMP`** via `(tblsearch "APPID" appName)` + `(regapp appName)` + re-verify. It never reuses `ASGRID_OBJ` or `ASGRID_TX_TMP`.

### XData Payload Structure (`ASDIM_OBJ`) (PROPOSED DESIGN)
| Index | DXF Code | Field | Example / Allowed Values |
| :--- | :--- | :--- | :--- |
| 0 | `1000` | `SourceGroupID` | `"ASG-0001"` |
| 1 | `1000` | `DimBatchID` | `"ASD-20261126-190000-01"` |
| 2 | `1000` | `Orientation` | `"H"` or `"V"` |
| 3 | `1000` | `DimType` | `"CHAIN"` or `"OVERALL"` |
| 4 | `1070` | `SlotIdx` | `1..(N-1)` for `CHAIN` (interval index), `0` for `OVERALL` |
| 5 | `1000` | `Placement` | `"TOP"`, `"BOTTOM"`, `"LEFT"`, or `"RIGHT"` |
| 6 | `1000` | `SchemaVer` | `"1.0"` |

### Canonical Duplicate Slot Identity (REVISION 2 RESOLUTION)
Every dimension's unique slot identity is strictly defined by the **5-tuple**:
$$\text{SlotKey} = (\text{SourceGroupID},\ \text{Orientation},\ \text{DimType},\ \text{SlotIdx},\ \text{Placement})$$

- `CHAIN` dimensions carry `SlotIdx = 1, 2, ..., (N - 1)` corresponding to each grid interval.
- `OVERALL` dimensions carry `SlotIdx = 0`.
- Dimensions on **different intervals** (different `SlotIdx`) have distinct `SlotKey`s and are **never** treated as duplicates of one another.
- Two dimensions sharing the **exact same 5-tuple** `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)` are duplicates and are **strictly rejected** in `Add New Set` mode.

### Multi-Group Separation & Repeated Execution Policy
1. **Model Space Discovery:** Scan `(ssget "_X" (list '(0 . "DIMENSION") '(410 . "Model") (list -3 '("ASDIM_OBJ"))))` + per-entity `410`/`67` verification, extract each dimension's 5-tuple `SlotKey`, and filter for `SourceGroupID = GROUP_ID`.
2. **Isolation:** Dimensions from other `SourceGroupID`s and user-created dimensions without `ASDIM_OBJ` are never modified or deleted.
3. **Repeated Execution Decision:** If any existing `ASDIM_OBJ` dimensions are found for the selected `GROUP_ID`, require an explicit user choice:
   - **Cancel:** Abort cleanly with zero changes.
   - **Replace Existing:** Replace **only** the existing `ASDIM_OBJ` dimensions belonging to the selected `GROUP_ID` via the 6-step transaction (Section 13).
   - **Add New Set (Non-Duplicate Only):** Build the candidate 5-tuple `SlotKey` list `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)` for every dimension to be generated and compare against existing `SlotKey`s for `GROUP_ID`. Permit generation **only** if the intersection is empty (zero colliding 5-tuple slots); if any candidate `SlotKey` already exists, **reject the operation** with a clear duplicate-slot report.

## 13. Transaction and Rollback

AutoLISP `_.UNDO` alone is not treated as an atomic database transaction. ASDIM V1.0 uses a hardened 6-step **Create-Verify-Swap-Commit** controller with explicit separation between **programmatic rollback** and **manual `UNDO` recovery**.

### Resource Provisioning & Lifecycle Policy (REVISION 2 CLARIFICATION)
Before provisioning any shared database resource in STEP A, ASDIM snapshots pre-existence via `tblsearch` for all 5 resources:

| Resource | Type | Pre-Existing Before ASDIM | Newly Created — On Success | Newly Created — On Failure (Programmatic Rollback) |
| :--- | :--- | :--- | :--- | :--- |
| `ASDIM-ARIAL` | `STYLE` | Never modified or deleted | Retained | **Retained as inert shared definition**; never `entdel`'d programmatically |
| `ASDIM-STYLE` | `DIMSTYLE` | Never modified or deleted | Retained | **Retained as inert shared definition**; never `entdel`'d programmatically |
| `AS-DIM` (or target layer) | `LAYER` | Never modified or deleted | Retained | **Retained as inert shared definition**; never `entdel`'d programmatically |
| `ASDIM_OBJ` | `APPID` (RegApp) | Never modified or deleted | Retained | **Retained** (`APPID` records cannot be deleted via `entdel` in AutoLISP) |
| `ASDIM_TX_TMP` | `APPID` (RegApp) | Never modified or deleted | Retained | **Retained** (`APPID` records cannot be deleted via `entdel` in AutoLISP) |

**Resource Safety & `UNDO` Distinction:**
- **Pre-Existing Resources:** Resources that existed before ASDIM started are **never** modified or deleted under any circumstance.
- **Failed Creation Safety:** If creating a new resource fails during STEP A, the operation aborts before creating any dimension entities and leaves the drawing intact.
- **Inert Retained Definitions:** Newly created shared table definitions (`ASDIM-ARIAL`, `ASDIM-STYLE`, `AS-DIM`, `ASDIM_OBJ`, `ASDIM_TX_TMP`) that remain after an entity-generation failure are completely **inert**: they do **not** affect ASGRID entities, ASGRID metadata, active styles/layers, or any other drawing objects.
- **Programmatic Rollback vs. `UNDO` Recovery (UNVERIFIED Distinction):**
  - **Programmatic Rollback** explicitly manages dimension entities (`txCreatedEnts` deletion and `txDeletedOldEnts` undelete) with deterministic count verification.
  - **Manual `UNDO` Recovery** (`_.UNDO _Begin` / `_End`) is provided as a secondary safety boundary, **not** a guaranteed table-cleanup mechanism. Whether a single `UNDO` (`Ctrl+Z`) reverts all newly created symbol-table and `APPID` records in AutoCAD 2021 is **UNVERIFIED** until proven via Phase 3 runtime testing (Test `T-17`); this specification does **not** guarantee single-`UNDO` removal of newly created table resources.

### 6-Step Transaction Flow
1. **STEP A — Pre-Flight, Resource Snapshot & Old-Dim Snapshot:** Open `_.UNDO _Begin`; snapshot pre-existence of the 5 resources; verify/provision `ASDIM-ARIAL`, `ASDIM-STYLE`, layer `AS-DIM`, `ASDIM_OBJ`, `ASDIM_TX_TMP`. In Replace mode, record all existing Model Space `ASDIM_OBJ` dimension enames for `GROUP_ID` without deleting them.
2. **STEP B — Create (Temporary Identity):** Generate all new native `DIMENSION` entities via `vla-AddDimRotated`, tag with `ASDIM_TX_TMP` carrying the complete 5-tuple slot fields (`SourceGroupID`, `Orientation`, `DimType`, `SlotIdx`, `Placement`), and append every ename to `txCreatedEnts`.
3. **STEP C — Verify New Entities:** Verify exact count, valid `entget`, DXF `"DIMENSION"`, Model Space (`410 = "Model"`), unique 5-tuple `SlotKey`s across `txCreatedEnts`, effective style (`ASDIM-STYLE` → `ASDIM-ARIAL`), target layer, and measured value within `1e-4` DU.
4. **STEP D — Swap (Replace Mode Only):** Delete old `ASDIM_OBJ` dimensions for `GROUP_ID` (guarded by `(if (entget e) (entdel e))`, tracked in `txDeletedOldEnts`), then promote `txCreatedEnts` from `ASDIM_TX_TMP` to `ASDIM_OBJ`.
5. **STEP E — Final Post-Commit Audit:** Re-verify all promoted Model Space dimensions for `GROUP_ID` (count, 5-tuple `SlotKey` integrity, zero duplicate slots, zero leftover `ASDIM_TX_TMP`).
6. **STEP F — Commit:** Clear `txActive`, close `_.UNDO _End`, restore `CMDECHO`, and report summary counts.

### Programmatic Rollback & Failure Recovery
On any failure in Steps B–E or interrupt in `*error*`:
1. Delete every entity in `txCreatedEnts` (guarded by `entget`).
2. Undelete every entity in `txDeletedOldEnts` via `(if (null (entget e)) (entdel e))`.
3. Verify restored count equals `(length txDeletedOldEnts)`.
4. Close `_.UNDO _End`, restore `CMDECHO`, and report which newly created shared definitions (if any) remain inert without affecting ASGRID or other objects.
5. If programmatic rollback verification detects any unrecovered dimension, print a **CRITICAL RECOVERY** warning instructing the user to inspect the drawing and consider `UNDO` (`Ctrl+Z`).
6. **Zero ASGRID Impact:** Rollback never touches any `ASGRID_OBJ` entity or `ASGRID_GROUPS` XRecord.

## 14. Error Handling

- **Local `*error*` Handler:** Captures runtime exceptions and user cancellations (`"Function cancelled"`, `"quit / exit abort"`, `"console break"`), unloads any open `dclId`, triggers `fn-asdim-rollback` only when `txActive` is `T`, closes `undoOpen`, and restores `CMDECHO`.
- **Error Categories:**
  - *DCL errors:* Missing `ASDIM_V1_0.dcl`, failed `load_dialog`/`new_dialog` (reporting exact `dclFile`).
  - *Space / Selection / Metadata errors:* Paper Space pick rejected, non-ASGRID entity, corrupt XData, missing NOD entry, unsupported `SCHEMA_VER`, failed spec validation, or `NUM_H < 2` and `NUM_V < 2`.
  - *Unit Confirmation errors:* Missing explicit drawing-unit confirmation (for **any** `INSUNITS` value, including `INSUNITS = 4`) → blocks generation and stops cleanly without creating dimensions.
  - *Duplicate Slot errors:* Any colliding 5-tuple `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)` in `Add New Set` mode → rejects operation cleanly.
  - *Geometry Mismatch errors:* Moved/deleted/duplicated/stretched Model Space ASGRID `LINE` entities → abort with offending axis report.
  - *Font / Style errors:* Missing `arial.ttf`, conflicting `ASDIM-ARIAL`, conflicting `ASDIM-STYLE` → abort without mutating existing styles.
  - *Transaction errors:* ActiveX creation/property failure, verification mismatch, promotion failure → automatic programmatic rollback + clear recovery guidance.

## 15. Compatibility Requirements

- **AutoCAD Version:** AutoCAD 2021 (AutoLISP + DCL + Visual LISP ActiveX via `(vl-load-com)`).
- **ASGRID Metadata Compatibility:** Full read-only compatibility with ASGRID Schema `"1.0"` (V2.2.1 R3, V2.2–R2, and legacy V2.1–V2.1.2 grids without `ANNO_EXT_LEN` via fallback to `EXT_LEN`).
- **Session Independence:** Operates even when `ASGRID_V2_2_1_R3.lsp` is not loaded in the AutoCAD session.
- **Non-Invasive Environment:** Never modifies global `UCS`, `INSUNITS`, `LTSCALE`, `CLAYER`, `TEXTSTYLE`, `DIMSTYLE`, `Standard`, or `ASGRID-ARIAL`.

## 16. File and Command Architecture

- **Primary Command:** `ASDIM` (`c:ASDIM`). Existing ASGRID commands (`ASGRID`, `ASGRIDEDIT`, `ASGRIDCHECK`) remain untouched.
- **Specification & Planned Module Files:**
  - `ASDIM V1_0 SPEK R2/asdim_v1_0_technical_specification_r2.md` (this document — **Created**)
  - `ASDIM V1_0 SPEK R2/asdim_v1_0_spec_r2_changelog.md` (revision changelog — **Created**)
  - `ASDIM_V1_0.lsp` (Planned — Not yet implemented)
  - `ASDIM_V1_0.dcl` (Planned — Not yet implemented)
  - `ASDIM_V1_0_CHANGELOG.md` (Planned)
  - `ASDIM_V1_0_TESTING_CHECKLIST.md` (Planned)

## 17. Testing Strategy

**Current Runtime Test Status:** **NO RUNTIME TESTS EXECUTED** (ASDIM V1.0 has not yet been implemented).

### A. Static & Code Review Verification (Pre-Runtime)
- Balanced parentheses and string literals (`depth = 0`).
- Zero `(or (findfile ...))` patterns; sequential `setq` + `if` DCL lookup verified.
- Zero write operations targeting `ASGRID_GROUPS` or `ASGRID_OBJ`.
- Every `ssget "_X"` includes `'(410 . "Model")` plus per-entity `410`/`67` Model Space checks.
- Mandatory unit confirmation gate enforced for all `INSUNITS` values (including `INSUNITS = 4`).
- Duplicate check uses full 5-tuple `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)`.
- DCL key cross-check and escaped `&&` labels.
- All `regapp` calls guarded by `tblsearch "APPID"`.

### B. AutoCAD 2021 Runtime Test Matrix (To Be Executed After Implementation)

| ID | Target Phase | Category | Test Scenario | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| T-01 | Phase 2 | Spacing | Uniform grid spacing (4×4 @ 4000 DU) | Accurate chain and overall dimensions matching grid intervals. | Not Run |
| T-02 | Phase 2 | Spacing | Nonuniform grid spacing (`DIST_V = 4000,5000,3000`; `DIST_H = 3000,4500`) | Chain `4000, 5000, 3000` (H) & `3000, 4500` (V); Overall `12000` (H) & `7500` (V). | Not Run |
| T-03 | Phase 2 | Direction | Horizontal dimensions only | Only horizontal dimensions created; zero vertical dimensions. | Not Run |
| T-04 | Phase 2 | Direction | Vertical dimensions only | Only vertical dimensions created; zero horizontal dimensions. | Not Run |
| T-05 | Phase 2 | Direction | Both Horizontal and Vertical | Both directions created accurately. | Not Run |
| T-06 | Phase 2 | Type | Chain only | Only interval chain dimensions created; no overall row. | Not Run |
| T-07 | Phase 2 | Type | Overall only | Only overall dimension created at primary offset `d1`. | Not Run |
| T-08 | Phase 2 | Type | Chain and Overall together | Separate non-overlapping rows (`d1` and `d1 + rowGap`). | Not Run |
| T-09 | Phase 2 | Placement | All four placements (Top, Bottom, Left, Right) | Dimensions positioned on exact selected sides; bubble-overlap warning triggers when `d1 <= d_clear`. | Not Run |
| T-10 | Phase 2 | Isolation | Multiple ASGRID groups (`ASG-0001`, `ASG-0002`) in one DWG | Dimensioning `ASG-0001` leaves `ASG-0002` untouched. | Not Run |
| T-11 | Phase 1 | Metadata | Missing or invalid ASGRID metadata / `NUM_H = 1` & `NUM_V = 1` | Aborts cleanly with descriptive error; single-axis edge cases disable impossible direction. | Not Run |
| T-12 | Phase 1 | Geometry | Manually moved, stretched, deleted, or duplicated Model Space `LINE` | Geometry gate detects discrepancy and aborts. | Not Run |
| T-13 | Phase 2 | Font | Missing `arial.ttf` (simulated) | Aborts with clear error; zero silent substitution. | Not Run |
| T-14 | Phase 2 | Style Conflict | Pre-existing `ASDIM-ARIAL` with non-Arial font or non-zero fixed height | Aborts with conflict error; existing style untouched. | Not Run |
| T-15 | Phase 2 | Style Conflict | Pre-existing `ASDIM-STYLE` referencing non-Arial text style | Aborts with conflict error; existing dimstyle untouched. | Not Run |
| T-16 | Phase 3 | Lifecycle & Slot Identity | Repeated `ASDIM` on same group (Cancel / Add Non-Duplicate / Replace) | Prompts explicitly; Cancel = 0 changes; Add evaluates 5-tuple `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)` so different `SlotIdx` values are distinct while exact 5-tuple collisions are rejected; Replace affects only selected `GROUP_ID`. | Not Run |
| T-17 | Phase 3 | Recovery & UNDO (**UNVERIFIED**) | Simulated failure mid-Replace transaction | Programmatic rollback deletes temp dims, restores old dims, preserves pre-existing resources, leaves ASGRID intact; additionally observes actual AutoCAD 2021 `UNDO` behavior on newly created table/`APPID` records. | Not Run |
| T-18 | **Phase 2** | **UCS (UNVERIFIED)** | Active rotated/shifted non-default UCS with `vla-AddDimRotated` | Verifies `RotationAngle` frame behavior and confirms dimensions align with WCS grid axes without altering user UCS. | Not Run |
| T-19 | Phase 2 | Scaling | Different drawing scales (`1:50`, `1:100`, `1:200`) in one DWG | Per-entity text height, arrow size, and offsets scale accurately per group without cross-group style corruption. | Not Run |
| T-20 | Phase 3 | Units Confirmation | Mandatory unit confirmation across `INSUNITS = 4` (mm), `0` (Unitless), `5` (cm), `6` (m) | Blocks generation until user explicitly confirms actual unit (including when `INSUNITS = 4`), stops cleanly if unconfirmed, applies `unitFactor`, never modifies `INSUNITS`. | Not Run |
| T-21 | **Phase 2** | **API (UNVERIFIED)** | `ASDIM-STYLE` creation & DXF `340` (`DIMTXSTY` → `ASDIM-ARIAL`) binding | Verifies `vla-Add` + `entmod` (or `entmakex`) creates valid `ASDIM-STYLE` bound to `ASDIM-ARIAL` without altering global `DIMSTYLE`. | Not Run |
| T-22 | **Phase 2** | **API (UNVERIFIED)** | `AcadDimRotated` per-entity `StyleName`, `TextHeight`, `ArrowheadSize`, `PrimaryUnitsPrecision` | Verifies all 4 ActiveX properties are writable in AutoCAD 2021 and preserve `ASDIM-ARIAL` effective font. | Not Run |
| T-23 | Phase 1 & 2 | Space Filter | Paper Space `LINE` / `DIMENSION` entities present in layout tabs | Paper Space entities are ignored by `ssget "_X"` and rejected on `entsel`. | Not Run |

## 18. Known Limitations

1. **No Automatic Collision Avoidance:** V1.0 warns when `d1 <= d_clear` on sides with ASGRID bubbles, but does not automatically shift offsets or avoid neighboring drawing objects.
2. **Orthogonal Grids Only:** Supports orthogonal WCS grids matching ASGRID V2.2.1 R3; angled/radial grids are not supported.
3. **Top-Level Model Space Entities Only:** `ssget "_X"` with `'(410 . "Model")` cannot inspect ASGRID grids or dimensions nested inside `BLOCK` definitions.
4. **No Live Associativity:** Dimensions are static native AutoCAD dimensions; manual grid edits invalidate geometry consistency until updated.
5. **Unverified AutoCAD 2021 Runtime Behaviors:** (a) `vla-AddDimRotated` rotation-angle frame under rotated UCS (`T-18`), (b) `DIMSTYLE` DXF `340` binding without global `DIMSTYLE` mutation (`T-21`), (c) `AcadDimRotated` per-entity property writability (`T-22`), and (d) whether a single `UNDO` removes all newly created symbol-table/`APPID` definitions after failure (`T-17`) remain **UNVERIFIED** until runtime testing in AutoCAD 2021.

## 19. Implementation Phases

| Phase | Scope | Exit Gate |
| :--- | :--- | :--- |
| **Phase 1 — Foundation, Model Space Filter & Read-Only Audit** | Implement `asdim:*` core utilities, Model Space–filtered read-only ASGRID XData/NOD reader, spec validator (including `NUM_H=1`/`NUM_V=1`), and WCS `LINE` geometry-consistency gate. | Static review passes; Tests `T-11`, `T-12`, and `T-23` (geometry part) pass in AutoCAD 2021. |
| **Phase 2 — Style Engine & Native Dimension Generator** | Implement `arial.ttf` check, `ASDIM-ARIAL`, `ASDIM-STYLE`, layer `AS-DIM`, unified `unitFactor` scaling, bubble-clearance calculator, and `vla-AddDimRotated` engine with `ASDIM_OBJ` XData (5-tuple slot fields). | Tests `T-01`–`T-10`, `T-13`–`T-15`, **`T-18` (rotated UCS)**, `T-19`, **`T-21`**, **`T-22`**, and `T-23` pass in AutoCAD 2021. |
| **Phase 3 — DCL Interface, Mandatory Unit Confirmation & Transaction/Rollback** | Implement `ASDIM_V1_0.dcl`, `c:ASDIM` workflow, mandatory unit confirmation gate (all drawings including `INSUNITS = 4`), repeated-execution prompt with 5-tuple duplicate check, resource pre-existence snapshot, and 6-step Create-Verify-Swap-Commit + programmatic rollback. | Full static validation + user runtime verification across all 23 test cases (`T-01`–`T-23`) in AutoCAD 2021. |

## 20. Acceptance Criteria

ASDIM V1.0 implementation will be accepted only when **all** of the following criteria are satisfied:
1. **Native Dimensions:** 100% of generated dimensions are native AutoCAD `DIMENSION` entities created via `vla-AddDimRotated` in Model Space, with zero manual line/text substitutes.
2. **Coordinate & Spacing Accuracy:** Nonuniform and uniform grids produce exact measured values matching `DIST_V` (Horizontal) and `DIST_H` (Vertical) cumulative WCS coordinates.
3. **Model Space & Geometry Integrity Gate:** Paper Space entities are excluded; moved, stretched, deleted, or duplicated Model Space grid lines block dimension generation.
4. **Mandatory Unit Confirmation & Scaling Safety:** Drawing intervals are treated as `DU`, `INSUNITS` is informational only and never modified, explicit user confirmation of actual drawing units is required on **every** run (including when `INSUNITS = 4`) before generation proceeds, and `size_DU = size_print_mm * SCALE_DENOM * unitFactor` is applied consistently across text height, arrow size, and offsets.
5. **Strict Arial & Style Isolation:** All generated dimension text uses `ASDIM-STYLE` → `ASDIM-ARIAL` → `arial.ttf` with zero mutation to `Standard`, `ASGRID-ARIAL`, user styles, or global `DIMSTYLE`.
6. **Zero ASGRID Mutation:** ASGRID's `ASGRID_GROUPS` XRecords, `ASGRID_OBJ` XData, geometry, and annotations remain untouched (`ASGRIDCHECK` passes before and after `ASDIM`).
7. **5-Tuple Slot Identity, Resource Safety & Programmatic Rollback:** Duplicate checks evaluate the complete 5-tuple `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)`, Replace affects only the selected `GROUP_ID`, programmatic rollback restores prior dimensions without modifying/deleting pre-existing resources, and any retained inert shared definitions do not affect ASGRID or other objects.
8. **Runtime Confirmation:** All 23 runtime test cases (`T-01`–`T-23`, including `T-17`, `T-18`, `T-21`, and `T-22`) are explicitly executed and confirmed by the user in AutoCAD 2021.
