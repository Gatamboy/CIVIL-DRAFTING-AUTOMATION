// ============================================================================
// FILE        : ASGRID_V2.dcl
// PROGRAM     : ASGRID V2.0 - AUTOMATIC BUILDING GRID GENERATOR (DCL UI)
// TARGET      : AutoCAD 2021
// DESKRIPSI   : Antarmuka dialog input berbasis formulir & tabel spacing
//               untuk program AutoLISP ASGRID_V2.lsp.
// ============================================================================

asgrid_v2 : dialog {
  label = "ASGRID V2.0 - Automatic Building Grid Generator (WCS / mm)";
  initial_focus = "num_h";

  // --------------------------------------------------------------------------
  // A. GRID CONFIGURATION
  // --------------------------------------------------------------------------
  : boxed_column {
    label = "A. Grid Configuration";
    : row {
      : edit_box {
        key = "num_h";
        label = "Horizontal Grids (1, 2, 3...):";
        edit_width = 6;
        fixed_width = true;
      }
      : spacer { width = 2; }
      : edit_box {
        key = "num_v";
        label = "Vertical Grids (A, B, C...):";
        edit_width = 6;
        fixed_width = true;
      }
      : spacer { width = 2; }
      : button {
        key = "btn_update_tbl";
        label = "Update Table";
        fixed_width = true;
      }
    }
    : text {
      key = "orient_info";
      label = "Orientation: WCS (mm) | Horizontal = X-axis (1,2,3...) | Vertical = Y-axis (A,B,C...AA)";
    }
  }

  // --------------------------------------------------------------------------
  // B. GRID SPACING (TABEL INTERVAL INDIVIDUAL - 8 BARIS/HALAMAN)
  // --------------------------------------------------------------------------
  : boxed_row {
    label = "B. Grid Spacing (Individual Interval Distances in mm)";

    // --- Kolom Kiri: Horizontal Spacing (Sumbu Y) ---
    : boxed_column {
      label = "Horizontal Intervals (Y-axis)";
      : row {
        : text { label = "Interval"; width = 11; fixed_width = true; }
        : text { label = "Distance (mm)"; width = 14; fixed_width = true; }
      }
      : row {
        : text { key = "h_lbl_1"; label = "1 - 2"; width = 11; fixed_width = true; }
        : edit_box { key = "h_val_1"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "h_lbl_2"; label = "2 - 3"; width = 11; fixed_width = true; }
        : edit_box { key = "h_val_2"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "h_lbl_3"; label = "3 - 4"; width = 11; fixed_width = true; }
        : edit_box { key = "h_val_3"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "h_lbl_4"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "h_val_4"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "h_lbl_5"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "h_val_5"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "h_lbl_6"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "h_val_6"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "h_lbl_7"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "h_val_7"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "h_lbl_8"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "h_val_8"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : button { key = "h_prev"; label = "< Prev"; width = 8; fixed_width = true; }
        : text   { key = "h_page"; label = "Page 1/1"; width = 10; alignment = centered; }
        : button { key = "h_next"; label = "Next >"; width = 8; fixed_width = true; }
      }
    }

    // --- Kolom Kanan: Vertical Spacing (Sumbu X) ---
    : boxed_column {
      label = "Vertical Intervals (X-axis)";
      : row {
        : text { label = "Interval"; width = 11; fixed_width = true; }
        : text { label = "Distance (mm)"; width = 14; fixed_width = true; }
      }
      : row {
        : text { key = "v_lbl_1"; label = "A - B"; width = 11; fixed_width = true; }
        : edit_box { key = "v_val_1"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "v_lbl_2"; label = "B - C"; width = 11; fixed_width = true; }
        : edit_box { key = "v_val_2"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "v_lbl_3"; label = "C - D"; width = 11; fixed_width = true; }
        : edit_box { key = "v_val_3"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "v_lbl_4"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "v_val_4"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "v_lbl_5"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "v_val_5"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "v_lbl_6"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "v_val_6"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "v_lbl_7"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "v_val_7"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : text { key = "v_lbl_8"; label = "-"; width = 11; fixed_width = true; }
        : edit_box { key = "v_val_8"; edit_width = 12; fixed_width = true; }
      }
      : row {
        : button { key = "v_prev"; label = "< Prev"; width = 8; fixed_width = true; }
        : text   { key = "v_page"; label = "Page 1/1"; width = 10; alignment = centered; }
        : button { key = "v_next"; label = "Next >"; width = 8; fixed_width = true; }
      }
    }
  }

  // --------------------------------------------------------------------------
  // C. SCALE & ANNOTATION
  // --------------------------------------------------------------------------
  : boxed_column {
    label = "C. Scale & Annotation";
    : row {
      : column {
        : edit_box {
          key = "scale_denom";
          label = "Drawing Scale (1 : N):";
          edit_width = 10;
          fixed_width = true;
        }
        : edit_box {
          key = "txt_height";
          label = "Printed Text Height (mm):";
          edit_width = 10;
          fixed_width = true;
        }
        : edit_box {
          key = "bub_dia";
          label = "Printed Bubble Dia (mm):";
          edit_width = 10;
          fixed_width = true;
        }
      }
      : spacer { width = 2; }
      : column {
        : edit_box {
          key = "ext_len";
          label = "Extension Length (mm):";
          edit_width = 10;
          fixed_width = true;
        }
        : popup_list {
          key = "bub_pos";
          label = "Bubble Position:";
          edit_width = 14;
          fixed_width = true;
        }
        : spacer { height = 1; }
      }
    }
    : text {
      key = "scale_preview";
      label = "Model Space Preview -> Text: 250.00 mm | Bubble Dia: 800.00 mm";
    }
  }

  // --------------------------------------------------------------------------
  // D. FONT STYLE
  // --------------------------------------------------------------------------
  : boxed_column {
    label = "D. Font Style";
    : text {
      key = "font_info";
      label = "Text Style: ASGRID-ARIAL  |  Font File: arial.ttf (Isolated from other objects)";
    }
    : text {
      key = "font_status";
      label = "Checking Arial font availability...";
    }
  }

  // --------------------------------------------------------------------------
  // VALIDATION ERROR BAR & ACTION BUTTONS
  // --------------------------------------------------------------------------
  errtile;
  ok_cancel;
}
