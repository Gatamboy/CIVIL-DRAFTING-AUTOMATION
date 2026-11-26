# ASDIM V1.0 — Automatic Grid Dimension Generator Technical Specification

**Project:** CIVIL DRAFTING AUTOMATION

**Repository:** [CIVIL-DRAFTING-AUTOMATION](https://github.com/Gatamboy/CIVIL-DRAFTING-AUTOMATION)

**Reference Commit (Provided by User):** `3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15` *(UNVERIFIED against remote GitHub due to offline sandbox; local workspace baseline `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` audited directly)*

**Reference Module:** ASGRID V2.2.1 R3

**Target Application:** AutoCAD 2021

**Development Language:** AutoLISP + DCL + Visual LISP / ActiveX (`vl-load-com`)

**Document Status:** Technical Specification Only (No implementation code written; no runtime tests executed)

**Date:** 2026-11-26

## 1. Overview

**ASDIM V1.0** is an independent AutoCAD 2021 automation module within the **CIVIL DRAFTING AUTOMATION** toolkit. Its sole purpose is to automatically generate native AutoCAD `DIMENSION` entities (horizontal/vertical chain and overall dimensions) from structural building grid geometry previously created by **ASGRID V2.2.1 R3**.

ASDIM V1.0 operates in strict read-only integration with ASGRID: it reads ASGRID's Named Object Dictionary (`ASGRID_GROUPS`) metadata and entity XData (`ASGRID_OBJ`), independently verifies that actual drawing geometry still matches that metadata, and creates native dimensions under its own isolated identity (`ASDIM_OBJ`), layer (`AS-DIM`), Text Style (`ASDIM-ARIAL`), and Dimension Style (`ASDIM-STYLE`).

Throughout this specification, **VERIFIED** facts audited directly from `ASGRID_V2_2_1_R3.lsp` are explicitly distinguished from **PROPOSED DESIGN** decisions for ASDIM V1.0 and **UNVERIFIED** items.

## 2. Objectives and Scope

### Core Objectives

1. Generate native AutoCAD `DIMENSION` entities accurately aligned with ASGRID V2.2.1 R3 grid axes in Model Space (WCS).

2. Support both uniform and nonuniform grid spacing via cumulative coordinate calculation.

3. Enforce strict isolation from ASGRID: zero writes to ASGRID's XRecords, XData, layers, Text Styles, or entities.

4. Enforce Arial font compliance (`arial.ttf` → `ASDIM-ARIAL` → `ASDIM-STYLE`) with zero silent font substitution.

5. Provide transaction safety, duplicate prevention, and controlled regeneration/replacement on repeated execution.

### In-Scope Capabilities (V1.0)

* **Horizontal chain dimensions** (measuring consecutive intervals along WCS X between vertical grid lines).

* **Vertical chain dimensions** (measuring consecutive intervals along WCS Y between horizontal grid lines).

* **Horizontal overall dimension** (measuring total span along WCS X from first to last vertical grid line).

* **Vertical overall dimension** (measuring total span along WCS Y from first to last horizontal grid line).

* **Independent direction toggles:** Horizontal only, Vertical only, or Both directions.

* **Independent type toggles:** Chain only, Overall only, or Chain + Overall together.

* **User-configurable placement and offsets:** Top/Bottom for horizontal dimensions, Left/Right for vertical dimensions, with separate numeric offsets for chain and overall rows.

* **Multi-group DWG support:** Selecting and dimensioning one specific ASGRID group at a time without affecting other ASGRID groups or unrelated dimensions.

## 3. Out of Scope

The following capabilities are explicitly excluded from ASDIM V1.0:

* Wall, partition, or structural member (column/beam/slab) dimensions.

* Door, window, or opening dimensions.

* Room or interior space dimensions.

* Automatic architectural or structural object detection.

* Editing ASGRID geometry or modifying ASGRID metadata/XRecords/XData.

* Live Preview inside the ASDIM DCL dialog.

* Automatic detection of free/empty space around the drawing.

* Automatic collision avoidance with neighboring drawing objects or other grid groups.

* Associative reactor-driven auto-update when a grid is manually edited outside ASDIM.

## 4. ASGRID R3 Source Audit

**Audit Source:** Local workspace baseline `ASGRID V2.2.1 REVISION 3/ASGRID_V2_2_1_R3.lsp` (4,202 lines; SHA-256 `c97af3f59dbece69f7caab4dcd2d94af2e8f05d1f72743eaa04c120ff685570b`).

**Remote Commit Verification Status:** **UNVERIFIED** against remote commit `3bb5d251e1886f5aaa0a9f5db1d4fe89f79e4d15` because outbound network access is disabled in the audit environment. All line numbers below are verified against the local R3 baseline file.

### Inspected Functions & Verified Behavior

| Function Name (Actual in R3) | Source Lines | Verified Implementation Behavior | 
| ----- | ----- | ----- | 
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
| `asgrid:annotation-engine` | L1494–L1594 | Stateless generator computing `cumY = (asgrid:compute-cumulative y0 dH)`, `cumX = (asgrid:compute-cumulative x0 dV)`, `totalY = (- (last cumY) y0)`, `totalX = (- (last cumX) x0)`. Places horizontal bubbles at `x0 - annoExt - bubRadModel` (`START`) and `x0 + totalX + annoExt + bubRadModel` (`END`), and vertical bubbles at `y0 - annoExt - bubRadModel` (`START`) and `y0 + totalY + annoExt + bubRadModel` (`END`). | 
| `asgrid:audit-group-entities` *(Note 1)* | L1827–L1968 | Scans top-level entities via `(ssget "_X" (list (list -3 (list "ASGRID_OBJ"))))`. Checks DXF type vs `Role`, `AxisIdx` bounds, `EndTag` validity, duplicate `(Role|AxisDir|AxisIdx|EndTag)` slots, and entity counts. **Does NOT verify actual `LINE` DXF (10)/(11) coordinates against metadata.** | 
| `fn-meta-build-spec` & `fn-meta-save-group` | L2199–L2265 | Local to `c:ASGRID`. `fn-meta-build-spec` sets `BASE_PT_WCS = ptWcs` and `ELEVATION = (caddr ptWcs)`. `fn-meta-save-group` creates an `XRECORD` via `entmakex` and registers it in `ASGRID_GROUPS` via `dictadd`. | 
| `fn-geometry-engine` | L2353–L2397 | Local to `c:ASGRID`. Computes `cumY` from `(y0, dH)` and `cumX` from `(x0, dV)`. Draws horizontal `LINE` entities (`AxisDir="H"`) from `(x0 - ext, curY, z0)` to `(x0 + totalX + ext, curY, z0)` and vertical `LINE` entities (`AxisDir="V"`) from `(curX, y0 - ext, z0)` to `(curX, y0 + totalY + ext, z0)` directly in WCS via `entmakex`. | 
| Base Point UCS→WCS Transform | L3076–L3080 | Inside `c:ASGRID`: acquires `basePtUcs` via `getpoint`, converts to WCS via `(setq basePt (trans basePtUcs 1 0))`, and passes `basePt` to `fn-execute-grid-creation`. | 

**Critical Audit Notes:**

1. **Naming Discrepancy:** The prompt referenced `asgrid:meta-audit-group-entities`; the actual function name in `ASGRID_V2_2_1_R3.lsp` is **`asgrid:audit-group-entities`** (L1827).

2. **Coordinate Drift Blind Spot:** Because `asgrid:audit-group-entities` does not compare actual `LINE` endpoints (`(assoc 10)` and `(assoc 11)`) against expected WCS coordinates, ASDIM V1.0 **must** implement its own dedicated geometry-consistency check (Section 6) before generating dimensions.

3. **Single-Axis Edge Case:** `asgrid:meta-validate-spec` permits `NUM_H = 1` (`DIST_H_COUNT = 0`, `DIST_H = nil`) or `NUM_V = 1` (`DIST_V_COUNT = 0`, `DIST_V = nil`). ASDIM must handle `NUM_V < 2` (no horizontal dimension possible) and `NUM_H < 2` (no vertical dimension possible) gracefully.

## 5. Metadata Integration

ASDIM V1.0 integrates with ASGRID exclusively as a **read-only consumer** of ASGRID metadata. Because ASDIM is an independent module, it must include its own read-only reader and validator helpers (e.g., `asdim:read-asgrid-group`, `asdim:parse-asgrid-xdata`) so it does not fail if `ASGRID_V2_2_1_R3.lsp` is not currently loaded in the AutoCAD session.

### Selection & Resolution Pipeline (PROPOSED DESIGN)

1. **Entity Selection:** Prompt the user with `entsel` to pick any entity belonging to the target ASGRID grid (`LINE`, `CIRCLE`, or `TEXT`). Allow retry on empty click or clean abort on `Esc`/`Enter`.

2. **Group ID Extraction:** Inspect `(entget ename '("ASGRID_OBJ"))`. Parse the 6-element XData list using the exact R3 schema (`GroupID`, `Role`, `AxisDir`, `AxisIdx`, `EndTag`, `SchemaVer`). Reject non-ASGRID entities or malformed XData with a clear diagnostic message.

3. **NOD XRecord Lookup (Read-Only):** Look up `"ASGRID_GROUPS"` in `(namedobjdict)` without creating any dictionary. Call `(dictsearch rootDict groupId)` and read `(entget xrecEname)`. Parse `(300 . <KEY>)` + typed value pairs into a spec alist.

4. **Pre-Generation Metadata Validation:** Validate all required fields before opening the DCL dialog:

   * `SCHEMA_VER` must equal `"1.0"` (reject unknown/incompatible schema versions).

   * `GROUP_ID` must match the `GroupID` extracted from the selected entity's XData.

   * `BASE_PT_WCS` must be a valid 3-element numeric WCS point `(x0 y0 z0)`, and `ELEVATION` must be numeric and match `z0` within tolerance (`1e-6`).

   * `NUM_H >= 1`, `NUM_V >= 1`; `DIST_H_COUNT = (length DIST_H) = (max 0 (1- NUM_H))`; `DIST_V_COUNT = (length DIST_V) = (max 0 (1- NUM_V))`.

   * Every interval in `DIST_H` and `DIST_V` must be strictly numeric and `> 0.0`.

   * `SCALE_DENOM` must be numeric and `> 0.0`.

   * `EXT_LEN` must be numeric and `> 0.0` (used for geometry consistency verification and placement reference).

   * Optional `ANNO_EXT_LEN` (fallback to `EXT_LEN`) and `BUBBLE_DIA_PRINT` / `BUBBLE_POS` may be read for informational reference only.

5. **Handling Missing, Invalid, or Incompatible Metadata:** Abort immediately before dialog/generation, display an explicit error explaining which key or check failed (e.g., missing NOD entry, schema mismatch, interval count mismatch), and advise running `ASGRIDCHECK`.

6. **Multi-Group DWG Isolation:** Every lookup, geometry check, and dimension generation operation is strictly scoped to the single selected `GROUP_ID`. Other `GROUP_ID` entries in `ASGRID_GROUPS` and their entities are ignored and untouched.

**Hard Invariant:** ASDIM must **never** call `entmod`, `entdel`, `dictadd`, `dictremove`, or write XData on any entity belonging to `ASGRID_OBJ` or any entry inside `ASGRID_GROUPS`.

## 6. Coordinate System

### Confirmed ASGRID R3 Coordinate Semantics (VERIFIED)

From `fn-geometry-engine` (L2353–L2397) and `asgrid:annotation-engine` (L1494–L1594):

* **Coordinate Frame:** All ASGRID geometry and `BASE_PT_WCS` are stored and created in **WCS** (World Coordinate System). User input in `c:ASGRID` is transformed via `(trans basePtUcs 1 0)` (L3079).

* **Elevation:** `z0 = (caddr BASE_PT_WCS)` equals `ELEVATION`. All grid lines, bubbles, and texts lie in the WCS horizontal plane `Z = z0`.

* **Axis Distribution:**

  * `cumX = (asgrid:compute-cumulative x0 DIST_V)` → X-coordinates of the `NUM_V` vertical grid lines (`A, B, C...`). Total width `totalX = (- (last cumX) x0)`.

  * `cumY = (asgrid:compute-cumulative y0 DIST_H)` → Y-coordinates of the `NUM_H` horizontal grid lines (`1, 2, 3...`). Total height `totalY = (- (last cumY) y0)`.

* **Grid Intersections:** The intersection of vertical axis `j` (`1 <= j <= NUM_V`) and horizontal axis `i` (`1 <= i <= NUM_H`) in WCS is:
  

  $$
  P_{j,i} = (\text{cumX}[j-1],\ \text{cumY}[i-1],\ z_0)
  $$

* **Grid Line Endpoints (WCS):**

  * Horizontal line `i` (`AxisDir="H"`, `AxisIdx=i`): `(x0 - EXT_LEN, cumY[i-1], z0)` to `(x0 + totalX + EXT_LEN, cumY[i-1], z0)`.

  * Vertical line `j` (`AxisDir="V"`, `AxisIdx=j`): `(cumX[j-1], y0 - EXT_LEN, z0)` to `(cumX[j-1], y0 + totalY + EXT_LEN, z0)`.

### UCS & WCS Handling in ASDIM (PROPOSED DESIGN)

* ASDIM performs **all** geometric computations and ActiveX dimension creation in **WCS**.

* ASDIM must **never** modify the user's active UCS (`UCSNAME` / `UCSORG` / `UCSXDIR` / `UCSYDIR`).

* Because ActiveX `AddDimRotated` accepts WCS 3D points (`vlax-3d-point`) directly, creating dimensions in Model Space via ActiveX remains invariant under non-default UCSs (rotated or shifted UCS).

* **Important AutoCAD 2021 Note:** If the active UCS is non-planar or rotated relative to WCS, `AddDimRotated` rotation angle `0.0` / `pi/2` operates in the **current UCS XY plane** on some AutoCAD configurations unless verified! **UNVERIFIED / REQUIRES RUNTIME TEST:** During Phase 1 runtime testing in AutoCAD 2021 (Test Case T-18), verify whether `vla-AddDimRotated` interprets `RotationAngle` relative to WCS or active UCS when a rotated UCS is active; if it depends on active UCS, explicitly set the entity's `Normal` = `(0 0 1)` and `HorizontalDirection` / DXF group code `50` / `51` in WCS, or temporarily align OCS without altering persistent user UCS.

### Tolerance & Geometry-Consistency Verification (PROPOSED DESIGN)

Because `asgrid:audit-group-entities` does not verify `LINE` coordinates, ASDIM must run an explicit **Geometry Integrity Gate** (`asdim:verify-grid-geometry`) before generating dimensions:

1. Collect all top-level `LINE` entities with `ASGRID_OBJ` XData matching `GROUP_ID` and `Role = "LINE"`.

2. Verify exact counts: `NUM_H` horizontal lines (`AxisIdx = 1..NUM_H`, no missing or duplicate indices) and `NUM_V` vertical lines (`AxisIdx = 1..NUM_V`, no missing or duplicate indices).

3. For each horizontal line `i`, compare its actual DXF `(10)` and `(11)` WCS points against expected `P_start = (x0 - ext, cumY[i-1], z0)` and `P_end = (x0 + totalX + ext, cumY[i-1], z0)` (accepting either forward or reversed endpoint order) within geometric tolerance `tol = 1e-4` mm (or configurable, stricter than `1e-3` mm; metadata comparison uses `1e-6`).

4. For each vertical line `j`, compare actual `(10)` and `(11)` against `(cumX[j-1], y0 - ext, z0)` and `(cumX[j-1], y0 + totalY + ext, z0)` within `tol`.

5. **Failure Policy:** If any `LINE` is missing, duplicated, moved, rotated, stretched, or shifted in Z elevation beyond `tol`, ASDIM **must abort** with a clear diagnostic report listing the inconsistent axis (e.g., `Vertical axis B moved by 250.0 mm`) and must **not** silently generate dimensions from stale metadata.

## 7. Dimension Calculation

### Axis-to-Dimension Mapping (VERIFIED AGAINST R3 GEOMETRY)

| Dimension Orientation | Measurement Axis | Source Coordinates | Source Interval List | Condition Required | 
| ----- | ----- | ----- | ----- | ----- | 
| **Horizontal Dimensions** | WCS X | `cumX` (vertical grid positions `A, B, C...`) | `DIST_V` (`NUM_V - 1` intervals) | `NUM_V >= 2` | 
| **Vertical Dimensions** | WCS Y | `cumY` (horizontal grid positions `1, 2, 3...`) | `DIST_H` (`NUM_H - 1` intervals) | `NUM_H >= 2` | 

### Worked Example (Nonuniform Spacing)

* Given `BASE_PT_WCS = (x0, y0, z0)` and `DIST_V = (4000.0, 5000.0, 3000.0)` (`NUM_V = 4`):

  * `cumX = (x0, x0 + 4000, x0 + 9000, x0 + 12000)`

  * **Horizontal Chain Dimensions (3 entities):**

    * Interval 1: `x0` → `x0 + 4000` (measured `4000`)

    * Interval 2: `x0 + 4000` → `x0 + 9000` (measured `5000`)

    * Interval 3: `x0 + 9000` → `x0 + 12000` (measured `3000`)

  * **Horizontal Overall Dimension (1 entity):**

    * Span: `x0` → `x0 + 12000` (measured `12000`)

* Given `DIST_H = (3000.0, 4500.0)` (`NUM_H = 3`):

  * `cumY = (y0, y0 + 3000, y0 + 7500)`

  * **Vertical Chain Dimensions (2 entities):** `3000`, `4500`

  * **Vertical Overall Dimension (1 entity):** `7500`

### Definition Points Selection (PROPOSED DESIGN)

Let `yMin = y0`, `yMax = (last cumY)`, `xMin = x0`, `xMax = (last cumX)`, and `ext = EXT_LEN`:

* **Horizontal Chain `k`** (`k = 0 .. NUM_V - 2`):

  * **Top placement:** `ExtPt1 = (cumX[k], yMax + ext, z0)`, `ExtPt2 = (cumX[k+1], yMax + ext, z0)`

  * **Bottom placement:** `ExtPt1 = (cumX[k], yMin - ext, z0)`, `ExtPt2 = (cumX[k+1], yMin - ext, z0)`

* **Horizontal Overall:**

  * **Top placement:** `ExtPt1 = (xMin, yMax + ext, z0)`, `ExtPt2 = (xMax, yMax + ext, z0)`

  * **Bottom placement:** `ExtPt1 = (xMin, yMin - ext, z0)`, `ExtPt2 = (xMax, yMin - ext, z0)`

* **Vertical Chain `k`** (`k = 0 .. NUM_H - 2`):

  * **Left placement:** `ExtPt1 = (xMin - ext, cumY[k], z0)`, `ExtPt2 = (xMin - ext, cumY[k+1], z0)`

  * **Right placement:** `ExtPt1 = (xMax + ext, cumY[k], z0)`, `ExtPt2 = (xMax + ext, cumY[k+1], z0)`

* **Vertical Overall:**

  * **Left placement:** `ExtPt1 = (xMin - ext, yMin, z0)`, `ExtPt2 = (xMin - ext, yMax, z0)`

  * **Right placement:** `ExtPt1 = (xMax + ext, yMin, z0)`, `ExtPt2 = (xMax + ext, yMax, z0)`

*(Anchoring extension line origins at the outer grid-line endpoints `± EXT_LEN` ensures clean extension lines that do not cross through the interior of the building grid.)*

### Precision, Rounding, and Invalid Interval Handling

* Coordinates are computed in double-precision floating point (`float`) directly from `cumX` and `cumY` without intermediate rounding.

* Display precision is controlled by the user-selected decimal places (`DIMDEC`, integer `0..4`, default `0` for millimeter architectural/structural drawings) applied via `ASDIM-STYLE` (or per-dimension property override if needed without mutating user styles).

* Any interval `<= 0.0` or non-numeric is rejected during pre-generation validation; ASDIM never attempts to draw a zero-length dimension.

* If `NUM_V < 2` and horizontal dimensions are enabled, ASDIM warns the user and skips horizontal dimensions (or disables the horizontal toggle in DCL). Similarly for `NUM_H < 2` and vertical dimensions.

## 8. Dimension Generation Engine

### Evaluation of AutoCAD 2021 Native Dimension Methods (PROPOSED DESIGN)

| Method | API Signature | Pros | Cons | Verdict | 
| ----- | ----- | ----- | ----- | ----- | 
| **`vla-AddDimRotated`** (ActiveX) | `(vla-AddDimRotated ms pt1 pt2 loc rotRad)` | Creates true native `AcDbRotatedDimension`; enforces exact orthogonal angle (`0.0` or `pi/2`); immune to sub-tolerance diagonal tilt; no `command` prompt interference or OSNAP distortion. | Requires `(vl-load-com)`; behavior under rotated UCS requires runtime verification (Section 6). | **SELECTED (Primary)** | 
| **`vla-AddDimAligned`** (ActiveX) | `(vla-AddDimAligned ms pt1 pt2 loc)` | Creates native `AcDbAlignedDimension`; simple 3-point call. | Dimension orientation follows `pt1 -> pt2` vector; any tiny Y/X discrepancy creates a slightly tilted aligned dimension instead of a strictly orthogonal grid dimension. | Rejected for orthogonal grids | 
| **`entmakex` `DIMENSION`** | Raw DXF | Pure AutoLISP without COM. | Requires manually constructing anonymous `*D` block geometry or triggering regen/recompute; fragile in AutoCAD 2021. | Rejected | 
| **`command "_.DIMLINEAR"`** | Command line | Native dimension. | Vulnerable to OSNAP, UCS, `CMDECHO`, zoom level, and active `DIMSTYLE` pollution. | Rejected | 

### Entity Creation & Property Assignment

For every dimension entity created via `vla-AddDimRotated` in Model Space (`vla-get-ModelSpace`):

1. Pass `vlax-3d-point` for `ExtPt1`, `ExtPt2`, and `DimLinePoint`.

2. Pass `RotationAngle`: `0.0` radians for Horizontal dimensions; `(/ pi 2.0)` radians for Vertical dimensions.

3. Explicitly set on the returned VLA object (without altering global `CLAYER` or `DIMSTYLE`):

   * `Layer` = configured dimension layer (default `"AS-DIM"`).

   * `StyleName` = `"ASDIM-STYLE"`.

   * `PrimaryUnitsPrecision` = user-selected decimal precision (if overriding style default).

4. Attach `ASDIM_OBJ` XData (Section 12) and record the entity ename in the transaction tracker.

5. Call `(vla-Update dimObj)` to ensure native dimension block geometry is up to date.

## 9. Dimension Placement

### Four Supported Placement Options

* **Horizontal Placement:** `Top` or `Bottom`

* **Vertical Placement:** `Left` or `Right`

### Offset Model & Row Spacing Calculation (PROPOSED DESIGN)

Offsets are specified in **printed millimeters** (or drawing units—**see Section 11 & Unresolved Technical Questions**; recommended default: **drawing/model units (mm)** matching ASGRID's `EXT_LEN`, or printed mm × `SCALE_DENOM` for scale-consistent spacing). Under the **scale-aware printed-mm model** (recommended for visual consistency across 1:50, 1:100, 1:200):

* `chainOffsetModel = chainOffsetPrint * SCALE_DENOM` (default `chainOffsetPrint = 8.0` mm → `800` mm at 1:100).

* `rowGapModel = rowSpacingPrint * SCALE_DENOM` (default `rowSpacingPrint = 8.0` mm → `800` mm at 1:100).

* **Reference Baseline (`refExt`):** Measured outward from the grid line endpoint (`EXT_LEN`).

  * *Note on Grid Bubbles:* In ASGRID R3 (`asgrid:annotation-engine`, L1541–L1582), if bubbles exist on the same side as the dimension, the outer edge of the bubble sits at `annoExt + (BUBBLE_DIA_PRINT * SCALE_DENOM)` from the outer grid intersection. ASDIM V1.0 does not perform automatic collision avoidance, so the DCL should display the current `EXT_LEN` and bubble clearance as read-only guidance so the user can enter an adequate `chainOffset`.

### Dimension Line Coordinates (`DimLinePoint`)

Let `d1 = chainOffsetModel` and `d2 = chainOffsetModel + rowGapModel` (when both Chain and Overall are enabled; if **Overall only** is enabled, Overall uses `d1` directly so there is no wasted empty gap):

| Orientation & Placement | Chain Row (`DimLinePoint`) | Overall Row (`DimLinePoint`) | 
| ----- | ----- | ----- | 
| **Horizontal — Top** | `((xMin + xMax)/2, yMax + ext + d1, z0)` | `((xMin + xMax)/2, yMax + ext + d_ov, z0)` | 
| **Horizontal — Bottom** | `((xMin + xMax)/2, yMin - ext - d1, z0)` | `((xMin + xMax)/2, yMin - ext - d_ov, z0)` | 
| **Vertical — Left** | `(xMin - ext - d1, (yMin + yMax)/2, z0)` | `(xMin - ext - d_ov, (yMin + yMax)/2, z0)` | 
| **Vertical — Right** | `(xMax + ext + d1, (yMin + yMax)/2, z0)` | `(xMax + ext + d_ov, (yMin + yMax)/2, z0)` | 

where `d_ov = d2` if Chain is also enabled, or `d_ov = d1` if Overall only is enabled.

## 10. Arial Text Style and Dimension Style

### Mandatory Font & Style Standards

* **Font:** Arial (`arial.ttf`)

* **Dedicated Text Style:** `ASDIM-ARIAL`

* **Dedicated Dimension Style:** `ASDIM-STYLE`

### Verification & Provisioning Rules (PROPOSED DESIGN)

1. **Verify `arial.ttf`:** Locate `arial.ttf` using the same multi-path resolver proven in `asgrid:find-arial-ttf` (`findfile`, `%WINDIR%\Fonts\`, `%SystemRoot%\Fonts\`, `C:\Windows\Fonts\`). If not found, abort immediately with a clear error. Never silently substitute `txt.shx` or another font.

2. **Verify or Create `ASDIM-ARIAL`:**

   * Check `(tblsearch "STYLE" "ASDIM-ARIAL")`.

   * If absent, create `ASDIM-ARIAL` via `entmakex` (`STYLE` table entry) or ActiveX `TextStyles.Add` with `fontFile = "arial.ttf"`, fixed height `0.0` (so dimension style controls text height dynamically), width factor `1.0`, non-annotative.

   * If already present, verify: (a) font file resolves to `arial.ttf` (case-insensitive, checking both DXF code `3` and extended font XData `ACAD` code `1000` `"Arial"`), (b) fixed height DXF code `40` equals `0.0` (within `1e-6`), and (c) style is non-annotative (`AcadAnnotative` absent or `0`). If `ASDIM-ARIAL` exists with conflicting/incompatible properties, **abort with a clear conflict error** rather than silently mutating a user-customized style.

3. **Verify or Create `ASDIM-STYLE`:**

   * Check `(tblsearch "DIMSTYLE" "ASDIM-STYLE")`.

   * If absent, create `ASDIM-STYLE` via ActiveX (`DimStyles.Add`) or DXF `DIMSTYLE` table record without changing the drawing's active `DIMSTYLE`.

   * Configure `ASDIM-STYLE` properties:

     * `DIMTXSTY` (DXF `340`) = ename of `ASDIM-ARIAL`.

     * `DIMTXT` = `textHeightPrint * SCALE_DENOM` (or `textHeightPrint` with `DIMSCALE = SCALE_DENOM`; see Scaling Model below).

     * `DIMASZ` = `arrowSizePrint * SCALE_DENOM`.

     * `DIMDEC` = configured decimal precision.

     * `DIMSCALE` = `1.0` when `DIMTXT`/`DIMASZ` are pre-scaled in model units (consistent with ASGRID's `model_size = print_size * scale_denom`), OR `DIMSCALE = SCALE_DENOM` with printed `DIMTXT`/`DIMASZ`.

   * **Conflict Protection:** If `ASDIM-STYLE` already exists in the drawing, inspect its `DIMTXSTY` (DXF `340` → style name) and verify it references `ASDIM-ARIAL` (which itself is verified as Arial). If an existing `ASDIM-STYLE` points to a non-Arial text style, abort and notify the user of the conflicting Dimension Style rather than silently overwriting user definitions.

4. **Strict Non-Mutation Guarantee:** Never modify `Standard`, `ASGRID-ARIAL`, existing user Text Styles, existing user Dimension Styles, or global system variables (`TEXTSTYLE`, `DIMSTYLE`, `DIMTXT`, `DIMASZ`, `DIMSCALE`).

### Model-Space Scaling & Drawing Units

* Printed parameters (`Printed Text Height`, `Arrow Size`) are converted to Model Space drawing units using the validated group scale: `modelSize = printSize * SCALE_DENOM` (consistent with ASGRID R3 `asgrid:annotation-engine` L1523–L1524).

* **Drawing Units Validation (`INSUNITS`):** ASDIM must read `(getvar "INSUNITS")` before generation. Unlike ASGRID's silent info message, if `INSUNITS /= 4` (Millimeters), ASDIM must surface an explicit warning in the DCL status area / confirmation prompt noting the current `INSUNITS` value and clarifying that ASGRID metadata intervals and printed sizes assume millimeters (never silently modifying `INSUNITS`).

## 11. DCL Interface

The DCL file (`ASDIM_V1_0.dcl`) defines dialog `asdim_v1_0` with the following controls (no Live Preview tile in V1.0):

| Section / Panel | Control Type | Key (Proposed) | Description & Validation | 
| ----- | ----- | ----- | ----- | 
| **A. Source ASGRID Group** | Read-only text + Button | `grp_id`, `grp_info`, `grp_units`, `btn_pick_grp` | Displays selected `GROUP_ID`, `NUM_H × NUM_V`, `SCALE_DENOM`, `EXT_LEN`, `INSUNITS` status, and option to re-pick another ASGRID group. | 
| **B. Dimension Selection** | Checkboxes (`toggle`) | `chk_horiz`, `chk_vert`, `chk_chain`, `chk_overall` | Independent toggles for Horizontal, Vertical, Chain, and Overall. At least one direction and one type must be enabled. Auto-disable `chk_horiz` if `NUM_V < 2` or `chk_vert` if `NUM_H < 2`. | 
| **C. Placement & Offsets** | Radio buttons + Edit boxes | `rad_h_top`, `rad_h_bot`, `rad_v_left`, `rad_v_right`, `ed_chain_off`, `ed_overall_off` | Selects Top/Bottom (Horizontal) and Left/Right (Vertical), plus positive numeric Chain Offset and Overall Row Spacing. | 
| **D. Style, Scaling & Layer** | Edit boxes, Popup list, Read-only text | `ed_txt_h`, `ed_arrow_sz`, `pop_prec`, `ed_layer`, `txt_dimstyle` | Printed Text Height (`> 0`), Printed Arrow Size (`> 0`), Decimal Precision (`0`–`4`), Dimension Layer (default `AS-DIM`), and read-only style badge (`ASDIM-STYLE / ASDIM-ARIAL`). | 
| **E. Actions** | Buttons | `accept`, `cancel` | `OK` triggers strict dialog validation before closing; `Cancel` exits cleanly with zero DWG changes. | 

**DCL Safety Rules (Lessons from ASGRID R3):**

* Escape ampersands as `&&` in `boxed_column` labels.

* Locate `ASDIM_V1_0.dcl` using sequential `setq` + `if` (`findfile`), **never** `(or (findfile ...))`.

## 12. Dimension Identity and Management

### Dedicated XData RegApp: `ASDIM_OBJ`

ASDIM must **never** reuse `ASGRID_OBJ` or `ASGRID_TX_TMP`. It registers its own RegApp **`ASDIM_OBJ`** via `(tblsearch "APPID" "ASDIM_OBJ")` + `(regapp "ASDIM_OBJ")` + re-verify (exact pattern from `asgrid:ensure-regapp`). During replacement transactions, temporary dimensions may use **`ASDIM_TX_TMP`** before promotion.

### XData Payload Structure (`ASDIM_OBJ`) (PROPOSED DESIGN)

| Index | DXF Code | Field | Example / Allowed Values | 
| ----- | ----- | ----- | ----- | 
| 0 | `1000` | `SourceGroupID` | `"ASG-0001"` (links dimension to source ASGRID group) | 
| 1 | `1000` | `DimBatchID` | `"ASD-20261126-183000-01"` (unique per generation run) | 
| 2 | `1000` | `Orientation` | `"H"` (Horizontal) or `"V"` (Vertical) | 
| 3 | `1000` | `DimType` | `"CHAIN"` or `"OVERALL"` | 
| 4 | `1070` | `SlotIdx` | `1..(N-1)` for `CHAIN`, `0` for `OVERALL` | 
| 5 | `1000` | `Placement` | `"TOP"`, `"BOTTOM"`, `"LEFT"`, or `"RIGHT"` | 
| 6 | `1000` | `SchemaVer` | `"1.0"` | 

### Multi-Group Separation & Repeated Execution Policy

1. **Detection:** Before generating dimensions for `GROUP_ID`, ASDIM scans top-level `DIMENSION` entities via `(ssget "_X" (list '(0 . "DIMENSION") (list -3 '("ASDIM_OBJ"))))` and filters for `SourceGroupID = GROUP_ID`.

2. **Isolation:** Dimensions belonging to other `SourceGroupID`s and user-created dimensions without `ASDIM_OBJ` XData are never touched.

3. **Repeated Execution Decision:** If existing `ASDIM_OBJ` dimensions are found for the selected `GROUP_ID`, ASDIM must halt and present an explicit user decision (via DCL dialog or keyword prompt) with three choices:

   * **Cancel:** Abort cleanly with zero changes.

   * **Replace Existing:** Safely replace all existing `ASDIM_OBJ` dimensions for `GROUP_ID` using the Create-Verify-Swap-Commit transaction (Section 13).

   * **Add New Set (Only if Non-Duplicate):** Permitted only when the requested `(Orientation, DimType, Placement)` slots do not overlap existing slots for that `GROUP_ID` (for example, adding Bottom dimensions when only Top dimensions exist). Exact duplicate `(SourceGroupID, Orientation, DimType, SlotIdx, Placement)` slots are **strictly blocked**.

## 13. Transaction and Rollback

AutoLISP `_.UNDO` alone is **not** assumed to provide an atomic database transaction. ASDIM V1.0 adopts the hardened 6-step **Create-Verify-Swap-Commit** pattern proven in ASGRID V2.2.1:

1. **STEP A — Pre-Flight & Snapshot:** Open a single `_.UNDO _Begin` group; verify `ASDIM-ARIAL`, `ASDIM-STYLE`, layer `AS-DIM`, and RegApps `ASDIM_OBJ`/`ASDIM_TX_TMP`. If replacing existing dimensions, record the ename list and metadata summary of all old `ASDIM_OBJ` dimensions belonging to `GROUP_ID` (do **not** delete them yet).

2. **STEP B — Create (Temporary Identity):** Generate all new native `DIMENSION` entities via `vla-AddDimRotated` tagged with temporary RegApp `ASDIM_TX_TMP` and append every created ename to `txCreatedEnts`.

3. **STEP C — Verify New Entities:** Verify that `(length txCreatedEnts)` equals the exact expected count (`expHChain + expHOverall + expVChain + expVOverall`), every ename is valid (`entget` non-nil), DXF type is `"DIMENSION"`, `StyleName = "ASDIM-STYLE"`, `Layer = targetLayer`, and measured value matches the expected interval within `1e-4`.

4. **STEP D — Swap (Replace Mode Only):** Delete old `ASDIM_OBJ` dimensions for `GROUP_ID` (guarding each `entdel` with `(if (entget e) (entdel e))`) and track deleted enames in `txDeletedOldEnts`. Then promote all `txCreatedEnts` from `ASDIM_TX_TMP` to final `ASDIM_OBJ` (removing `ASDIM_TX_TMP`).

5. **STEP E — Final Post-Commit Audit:** Re-verify all promoted dimensions for `GROUP_ID` (count, XData integrity, zero leftover `ASDIM_TX_TMP`).

6. **STEP F — Commit:** Clear `txActive`, close `_.UNDO _End`, restore `CMDECHO`, and print a concise summary (Group ID, counts created/replaced).

### Rollback & Recovery Behavior

* On any failure in Steps B–E or user interrupt caught by `*error*`:

  1. Delete every entity in `txCreatedEnts` (guarded by `entget`).

  2. Restore any already-deleted old dimensions in `txDeletedOldEnts` using `(if (null (entget e)) (entdel e))` (AutoLISP undelete within the same drawing session).

  3. Verify restored count matches `txDeletedOldEnts` length.

  4. Close `_.UNDO _End` and restore `CMDECHO`.

  5. If rollback verification detects any unrecovered entity, print a **CRITICAL RECOVERY** message instructing the user to immediately run `UNDO` (`Ctrl+Z`) once to revert the entire `_.UNDO _Begin/_End` group.

* **Zero Impact on ASGRID:** Rollback never touches any `ASGRID_OBJ` entity or `ASGRID_GROUPS` XRecord.

## 14. Error Handling

* **Local `*error*` Handler:** Captures runtime exceptions and user cancellations (`"Function cancelled"`, `"quit / exit abort"`, `"console break"`), unloads any open `dclId`, triggers `fn-asdim-rollback` only when `txActive` is `T`, closes `undoOpen`, and restores `CMDECHO`.

* **Distinct Error Categories:**

  * *Pre-dialog / DCL errors:* Missing `ASDIM_V1_0.dcl`, failed `load_dialog`/`new_dialog` (reporting exact `dclFile` path).

  * *Selection & Metadata errors:* Non-ASGRID entity picked, corrupt XData, missing NOD entry, unsupported `SCHEMA_VER`, failed `meta-validate-spec`.

  * *Geometry Mismatch errors:* Moved/deleted/duplicated/stretched ASGRID `LINE` entities (aborts before dimensioning).

  * *Font / Style errors:* Missing `arial.ttf`, conflicting `ASDIM-ARIAL` (non-Arial, annotative, or non-zero fixed height), conflicting `ASDIM-STYLE` (non-Arial text style).

  * *Transaction errors:* ActiveX creation failure, count mismatch, promotion failure → automatic rollback + clear recovery guidance.

## 15. Compatibility Requirements

* **AutoCAD Version:** AutoCAD 2021 (AutoLISP + DCL + Visual LISP ActiveX via `(vl-load-com)`).

* **ASGRID Metadata Compatibility:** Full read-only compatibility with ASGRID Schema `"1.0"`, including:

  * ASGRID V2.2.1 R3 (and V2.2 / V2.2.1 / R1 / R2) grids with `ANNO_EXT_LEN` and `UPDATED_AT`.

  * Legacy ASGRID V2.1 / V2.1.1 / V2.1.2 grids without `ANNO_EXT_LEN` (fallback to `EXT_LEN`).

* **Session Independence:** ASDIM must function even when `ASGRID_V2_2_1_R3.lsp` is not loaded in the current AutoCAD session (self-contained read-only ASGRID metadata reader).

* **Non-Invasive Environment:** Must never modify global `UCS`, `INSUNITS`, `LTSCALE`, `CLAYER`, `TEXTSTYLE`, `DIMSTYLE`, `Standard`, or `ASGRID-ARIAL`.

## 16. File and Command Architecture

### Command Interface

* **Primary Command:** `ASDIM` (`c:ASDIM`)

* Existing ASGRID commands (`ASGRID`, `ASGRIDEDIT`, `ASGRIDCHECK`) remain completely untouched.

### Planned Folder & File Structure (`ASDIM V1.0/`)

| File | Role | Status | 
| ----- | ----- | ----- | 
| `ASDIM_V1_0_TECHNICAL_SPECIFICATION.md` | Master technical specification (this document) | **Created** | 
| `ASDIM_V1_0.lsp` | Independent AutoLISP + ActiveX implementation (`asdim:*` services + `c:ASDIM`) | Planned (Not yet implemented) | 
| `ASDIM_V1_0.dcl` | Independent DCL dialog definition (`asdim_v1_0`) | Planned (Not yet implemented) | 
| `ASDIM_V1_0_CHANGELOG.md` | Release changelog | Planned | 
| `ASDIM_V1_0_TESTING_CHECKLIST.md` | Detailed AutoCAD 2021 runtime test checklist | Planned | 

### Internal Module Layout (Proposed for `ASDIM_V1_0.lsp`)

* Section 1: Stateless constants (`asdim:*`), RegApp helper, numeric/string utilities.

* Section 2: Read-only ASGRID XData & NOD XRecord reader + spec validator.

* Section 3: WCS grid geometry-consistency verifier (`asdim:verify-grid-geometry`).

* Section 4: Arial font, `ASDIM-ARIAL`, `ASDIM-STYLE`, and layer `AS-DIM` provisioning/verification.

* Section 5: Dimension coordinate calculator & ActiveX `vla-AddDimRotated` engine.

* Section 6: `ASDIM_OBJ` identity management, duplicate detection, and 6-step transaction/rollback controller.

* Section 7: `c:ASDIM` entry point and DCL handler.

## 17. Testing Strategy

**Current Runtime Test Status:** **NO RUNTIME TESTS EXECUTED** (ASDIM V1.0 has not yet been implemented).

### A. Static & Code Review Verification (Pre-Runtime)

* Balanced parentheses and string literals check (`depth = 0`).

* Zero `(or (findfile ...))` patterns; sequential `setq` + `if` DCL resolution verified.

* Zero write operations (`entmod`, `entdel`, `dictadd`, `dictremove`) targeting `ASGRID_GROUPS` or `ASGRID_OBJ`.

* DCL key cross-check between `ASDIM_V1_0.lsp` and `ASDIM_V1_0.dcl` (and escaped `&&` labels).

* Verification that `(vl-load-com)` is invoked safely and all `regapp` calls are guarded by `tblsearch "APPID"`.

### B. AutoCAD 2021 Runtime Test Matrix (To Be Executed After Implementation)

| ID | Category | Test Scenario | Expected Result | Status | 
| ----- | ----- | ----- | ----- | ----- | 
| T-01 | Spacing | Uniform grid spacing (e.g., 4×4 @ 4000 mm) | Accurate chain and overall dimensions matching grid intervals. | Not Run | 
| T-02 | Spacing | Nonuniform grid spacing (`DIST_V = 4000,5000,3000`; `DIST_H = 3000,4500`) | Chain shows `4000, 5000, 3000` (H) & `3000, 4500` (V); Overall shows `12000` (H) & `7500` (V). | Not Run | 
| T-03 | Direction | Horizontal dimensions only | Only horizontal dimensions generated; zero vertical dimensions. | Not Run | 
| T-04 | Direction | Vertical dimensions only | Only vertical dimensions generated; zero horizontal dimensions. | Not Run | 
| T-05 | Direction | Both Horizontal and Vertical enabled | Both directions generated accurately. | Not Run | 
| T-06 | Type | Chain only | Only interval chain dimensions generated; no overall row. | Not Run | 
| T-07 | Type | Overall only | Only overall dimension generated at primary offset `d1`. | Not Run | 
| T-08 | Type | Chain and Overall together | Separate non-overlapping rows (`d1` and `d1 + rowGap`). | Not Run | 
| T-09 | Placement | All four placements (Top, Bottom, Left, Right) | Dimensions positioned on exact selected sides with configured offsets. | Not Run | 
| T-10 | Isolation | Multiple ASGRID groups (`ASG-0001`, `ASG-0002`) in one DWG | Dimensioning `ASG-0001` leaves `ASG-0002` untouched; independent sets per group. | Not Run | 
| T-11 | Metadata | Missing or invalid ASGRID metadata (corrupt XRecord / missing NOD) | Aborts cleanly before generation with descriptive error; zero entities created. | Not Run | 
| T-12 | Geometry | Manually moved, stretched, deleted, or duplicated grid `LINE` | Geometry gate detects discrepancy and aborts; no misleading dimensions created. | Not Run | 
| T-13 | Font | Missing `arial.ttf` (simulated) | Aborts with clear error; zero silent font substitution. | Not Run | 
| T-14 | Style Conflict | Pre-existing `ASDIM-ARIAL` with non-Arial font or non-zero fixed height | Aborts with clear conflict error; existing style untouched. | Not Run | 
| T-15 | Style Conflict | Pre-existing `ASDIM-STYLE` referencing non-Arial text style | Aborts with clear conflict error; existing dimstyle untouched. | Not Run | 
| T-16 | Lifecycle | Repeated `ASDIM` execution on same group (Cancel / Add Non-Duplicate / Replace) | Prompts user explicitly; Cancel makes 0 changes; Add blocks duplicates; Replace swaps cleanly. | Not Run | 
| T-17 | Recovery | Simulated failure mid-Replace transaction | Rollback deletes temporary dims and restores previous `ASDIM_OBJ` dims; ASGRID intact. | Not Run | 
| T-18 | UCS | Active rotated/shifted non-default UCS | Dimensions align with WCS grid axes without altering user's UCS. | Not Run | 
| T-19 | Scaling | Different drawing scales (`1:50`, `1:100`, `1:200`) | Text height, arrow size, and offsets scale proportionally to `SCALE_DENOM`. | Not Run | 
| T-20 | Units | Non-millimeter `INSUNITS` (e.g., Meters `6` or Unitless `0`) | Displays explicit units warning without modifying `INSUNITS`. | Not Run | 

## 18. Known Limitations

1. **No Automatic Collision Avoidance:** V1.0 places dimensions strictly at user-configured offsets; if offsets are smaller than ASGRID bubble clearance (`annoExt + bubDiaModel`), dimensions may visually overlap bubbles.

2. **Orthogonal Grids Only:** Supports orthogonal WCS grids matching ASGRID V2.2.1 R3; angled/radial grids are not supported.

3. **Top-Level Entities Only:** Like `ASGRIDCHECK`, `ssget "_X"` scans top-level Model Space entities and cannot inspect ASGRID grids nested inside `BLOCK` definitions.

4. **No Live Associativity:** Dimensions are static native AutoCAD dimensions tied to `GROUP_ID` via XData; if the grid is later moved manually, the user must re-run `ASDIM` (which will detect the mismatch if metadata was not updated).

5. **ActiveX `AddDimRotated` under Rotated UCS:** Exact rotation-angle frame behavior under a rotated UCS in AutoCAD 2021 is marked **UNVERIFIED** until runtime Test T-18 is executed.

## 19. Implementation Phases

| Phase | Scope | Exit Gate | 
| ----- | ----- | ----- | 
| **Phase 1 — Foundation & Read-Only Audit** | Implement `asdim:*` core utilities, read-only ASGRID XData/NOD reader, spec validator, and WCS `LINE` geometry-consistency gate. | Static review passes; correctly reads/validates ASGRID R3 groups and rejects moved lines in AutoCAD 2021. | 
| **Phase 2 — Style Engine & Native Dimension Generator** | Implement `arial.ttf` verification, `ASDIM-ARIAL`, `ASDIM-STYLE`, layer `AS-DIM`, coordinate calculator, and `vla-AddDimRotated` engine with `ASDIM_OBJ` XData. | Generates accurate H/V Chain & Overall native dimensions at all 4 placements in AutoCAD 2021. | 
| **Phase 3 — DCL Interface & Transaction/Rollback** | Implement `ASDIM_V1_0.dcl`, `c:ASDIM` workflow, repeated-execution prompt (Cancel/Add/Replace), and 6-step Create-Verify-Swap-Commit + rollback. | Full static validation + user runtime verification across T-01 through T-20 in AutoCAD 2021. | 

## 20. Acceptance Criteria

ASDIM V1.0 implementation will be accepted only when **all** of the following criteria are satisfied:

1. **Native Dimensions:** 100% of generated dimensions are native AutoCAD `DIMENSION` entities created via ActiveX (`vla-AddDimRotated`), with zero manual line/text substitutes.

2. **Coordinate & Spacing Accuracy:** Nonuniform and uniform grids produce exact measured values matching `DIST_V` (Horizontal) and `DIST_H` (Vertical) cumulative WCS coordinates.

3. **Geometry Integrity Gate:** Moved, stretched, deleted, or duplicated grid lines are reliably detected and block dimension generation.

4. **Strict Arial Compliance:** All generated dimension text uses `ASDIM-STYLE` → `ASDIM-ARIAL` → `arial.ttf` with zero modification to `Standard`, `ASGRID-ARIAL`, or user styles, and hard abort if Arial is unavailable or conflicted.

5. **Zero ASGRID Mutation:** ASGRID's `ASGRID_GROUPS` XRecords, `ASGRID_OBJ` XData, geometry, and annotations remain byte-for-byte / entity-for-entity unchanged (`ASGRIDCHECK` passes before and after `ASDIM`).

6. **Safe Repeated Execution & Rollback:** Duplicate slots are prevented, Replace executes atomically via Create-Verify-Swap-Commit, and rollback cleanly restores prior state on failure.

7. **Runtime Confirmation:** All 20 runtime test cases (T-01–T-20) are explicitly executed and confirmed by the user in AutoCAD 2021.