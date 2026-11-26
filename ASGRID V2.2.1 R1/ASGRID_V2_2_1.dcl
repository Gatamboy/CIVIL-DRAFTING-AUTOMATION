// ============================================================================
// FILE        : ASGRID_V2_2.dcl
// PROGRAM     : ASGRID V2.2 (PHASE 2 - GENERATOR + ASGRIDEDIT MODE 1)
// TARGET      : AutoCAD 2021
// BASELINE    : ASGRID V2.2/ASGRID_V2_2.dcl (Phase 1 tetap sebagai backup)
// DIALOGS     :
//   1. asgrid_v2_2      : Dialog generator grid (identik dengan Phase 1)
//   2. asgrid_edit_v2_2 : Dialog Annotation Editor (Mode 1)
// ============================================================================

// ============================================================================
// DIALOG 1: GENERATOR GRID (ASGRID) - UTUH DARI PHASE 1
// ============================================================================
asgrid_v2_2 : dialog {
  label = "ASGRID V2.2 - Automatic Building Grid Generator";
  initial_focus = "num_h";

  : row {
    : column {
      : boxed_column {
        label = "A. Grid Configuration";
        : row {
          : edit_box {
            key = "num_h";
            label = "Horizontal Grids (1, 2, 3...):";
            edit_width = 5;
            fixed_width = true;
          }
          : spacer { width = 1; }
          : edit_box {
            key = "num_v";
            label = "Vertical Grids (A, B, C...):";
            edit_width = 5;
            fixed_width = true;
          }
          : spacer { width = 1; }
          : button {
            key = "btn_update_tbl";
            label = "Update Table";
            fixed_width = true;
          }
        }
        : text {
          key = "orient_info";
          label = "WCS (mm) | Horizontal = X-axis (1,2,3...) | Vertical = Y-axis (A,B,C...AA)";
        }
      }

      : boxed_row {
        label = "B. Grid Spacing (Individual Interval Distances in mm)";

        : boxed_column {
          label = "Horizontal Intervals (Y-axis)";
          : row {
            : text { label = "Interval"; width = 10; fixed_width = true; }
            : text { label = "Distance (mm)"; width = 13; fixed_width = true; }
          }
          : row {
            : text { key = "h_lbl_1"; label = "1 - 2"; width = 10; fixed_width = true; }
            : edit_box { key = "h_val_1"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "h_lbl_2"; label = "2 - 3"; width = 10; fixed_width = true; }
            : edit_box { key = "h_val_2"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "h_lbl_3"; label = "3 - 4"; width = 10; fixed_width = true; }
            : edit_box { key = "h_val_3"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "h_lbl_4"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "h_val_4"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "h_lbl_5"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "h_val_5"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "h_lbl_6"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "h_val_6"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "h_lbl_7"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "h_val_7"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "h_lbl_8"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "h_val_8"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : button { key = "h_prev"; label = "< Prev"; width = 7; fixed_width = true; }
            : text   { key = "h_page"; label = "Page 1/1"; width = 9; alignment = centered; }
            : button { key = "h_next"; label = "Next >"; width = 7; fixed_width = true; }
          }
        }

        : boxed_column {
          label = "Vertical Intervals (X-axis)";
          : row {
            : text { label = "Interval"; width = 10; fixed_width = true; }
            : text { label = "Distance (mm)"; width = 13; fixed_width = true; }
          }
          : row {
            : text { key = "v_lbl_1"; label = "A - B"; width = 10; fixed_width = true; }
            : edit_box { key = "v_val_1"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "v_lbl_2"; label = "B - C"; width = 10; fixed_width = true; }
            : edit_box { key = "v_val_2"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "v_lbl_3"; label = "C - D"; width = 10; fixed_width = true; }
            : edit_box { key = "v_val_3"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "v_lbl_4"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "v_val_4"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "v_lbl_5"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "v_val_5"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "v_lbl_6"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "v_val_6"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "v_lbl_7"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "v_val_7"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : text { key = "v_lbl_8"; label = "-"; width = 10; fixed_width = true; }
            : edit_box { key = "v_val_8"; edit_width = 11; fixed_width = true; }
          }
          : row {
            : button { key = "v_prev"; label = "< Prev"; width = 7; fixed_width = true; }
            : text   { key = "v_page"; label = "Page 1/1"; width = 9; alignment = centered; }
            : button { key = "v_next"; label = "Next >"; width = 7; fixed_width = true; }
          }
        }
      }

      : boxed_column {
        label = "C. Scale && Annotation";
        : row {
          : column {
            : edit_box {
              key = "scale_denom";
              label = "Drawing Scale (1 : N):";
              edit_width = 9;
              fixed_width = true;
            }
            : edit_box {
              key = "txt_height";
              label = "Printed Text Height (mm):";
              edit_width = 9;
              fixed_width = true;
            }
            : edit_box {
              key = "bub_dia";
              label = "Printed Bubble Dia (mm):";
              edit_width = 9;
              fixed_width = true;
            }
          }
          : spacer { width = 1; }
          : column {
            : edit_box {
              key = "ext_len";
              label = "Extension Length (mm):";
              edit_width = 9;
              fixed_width = true;
            }
            : popup_list {
              key = "bub_pos";
              label = "Bubble Position:";
              edit_width = 13;
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

      : boxed_column {
        label = "D. Font Style";
        : text {
          key = "font_info";
          label = "Text Style: ASGRID-ARIAL  |  Font: arial.ttf (Isolated)";
        }
        : text {
          key = "font_status";
          label = "Checking Arial font availability...";
        }
      }
    }

    : boxed_column {
      label = "E. Live Preview (Schematic - Non-Permanent)";
      : image {
        key = "grid_preview";
        width = 46;
        height = 24;
        color = 0;
        fixed_width = true;
        fixed_height = true;
      }
      : text {
        key = "prev_info_1";
        label = "Grid: 4H (1..4) x 4V (A..D)";
        width = 46;
        fixed_width = true;
      }
      : text {
        key = "prev_info_2";
        label = "Total Dim: X = 15000 mm | Y = 12000 mm";
        width = 46;
        fixed_width = true;
      }
      : text {
        key = "prev_info_3";
        label = "Bubble: Both Ends | Mode: Full Detail";
        width = 46;
        fixed_width = true;
      }
      : text {
        key = "prev_meta_info";
        label = "Next Group ID: ASG-0001 (Verified DWG Metadata)";
        width = 46;
        fixed_width = true;
      }
      : row {
        : spacer { width = 1; }
        : button {
          key = "btn_refresh_prev";
          label = "Refresh Preview";
          fixed_width = true;
        }
        : spacer { width = 1; }
      }
    }
  }

  errtile;
  ok_cancel;
}

// ============================================================================
// DIALOG 2: ANNOTATION EDITOR (ASGRIDEDIT MODE 1)
// ============================================================================
asgrid_edit_v2_2 : dialog {
  label = "ASGRID V2.2 - Annotation Editor";
  initial_focus = "ed_bub_dia";

  : row {
    // ------------------------------------------------------------------------
    // KOLOM KIRI: INFORMASI GRID (READ-ONLY) & ANNOTATION SETTINGS (EDITABLE)
    // ------------------------------------------------------------------------
    : column {
      : boxed_column {
        label = "A. Grid Information (Read-Only)";
        : text { key = "ed_group_id";     label = "Group ID               : ASG-0001"; width = 44; fixed_width = true; }
        : text { key = "ed_num_h";        label = "Horizontal Grids       : 4";        width = 44; fixed_width = true; }
        : text { key = "ed_num_v";        label = "Vertical Grids         : 4";        width = 44; fixed_width = true; }
        : text { key = "ed_scale";        label = "Drawing Scale (Locked) : 1:100";    width = 44; fixed_width = true; }
        : text { key = "ed_geom_ext";     label = "Geometry EXT_LEN       : 1500.00 mm (Locked)"; width = 44; fixed_width = true; }
        : text { key = "ed_cur_anno_ext"; label = "Current ANNO_EXT_LEN   : 1500.00 mm";          width = 44; fixed_width = true; }
      }

      : boxed_column {
        label = "B. Annotation Settings (Editable)";
        : edit_box {
          key = "ed_bub_dia";
          label = "Printed Bubble Diameter (mm):";
          edit_width = 14;
          fixed_width = true;
        }
        : edit_box {
          key = "ed_txt_height";
          label = "Printed Text Height (mm):";
          edit_width = 14;
          fixed_width = true;
        }
        : popup_list {
          key = "ed_txt_style";
          label = "Text Style:";
          edit_width = 22;
          fixed_width = true;
        }
        : popup_list {
          key = "ed_bub_pos";
          label = "Bubble Position:";
          edit_width = 22;
          fixed_width = true;
        }
        : edit_box {
          key = "ed_anno_ext";
          label = "Annotation Extension Length (mm):";
          edit_width = 14;
          fixed_width = true;
        }
        : text {
          key = "ed_scale_prev";
          label = "Model -> Text: 250.0 mm | Bubble: 800.0 mm";
          width = 44;
          fixed_width = true;
        }
        : text {
          key = "ed_style_info";
          label = "Style Status: Valid";
          width = 44;
          fixed_width = true;
        }
      }
    }

    // ------------------------------------------------------------------------
    // KOLOM KANAN: C. LIVE PREVIEW (GEOM EXT TETAP, ANNO EXT DINAMIS)
    // ------------------------------------------------------------------------
    : boxed_column {
      label = "C. Live Preview (Geometry Locked, Annotation Dynamic)";
      : image {
        key = "ed_preview";
        width = 46;
        height = 20;
        color = 0;
        fixed_width = true;
        fixed_height = true;
      }
      : text {
        key = "ed_prev_info_1";
        label = "Grid: 4H (1..4) x 4V (A..D)";
        width = 46;
        fixed_width = true;
      }
      : text {
        key = "ed_prev_info_2";
        label = "Total Dim: X = 15000 mm | Y = 12000 mm";
        width = 46;
        fixed_width = true;
      }
      : text {
        key = "ed_prev_info_3";
        label = "Geom EXT: 1500 mm | Anno EXT: 1500 mm | Both Ends";
        width = 46;
        fixed_width = true;
      }
    }
  }

  // --------------------------------------------------------------------------
  // D. VALIDATION ERROR BAR & ACTION BUTTONS (OK / CANCEL)
  // --------------------------------------------------------------------------
  errtile;
  ok_cancel;
}
