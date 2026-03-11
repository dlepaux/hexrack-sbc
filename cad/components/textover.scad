include <../config.scad>

// ============================================================================
// TEXTOVER LABELS MODULE
// ============================================================================
// Renders engraved text labels above each SBC
// Parameters:
//   textover_data - Array of text arrays, one per SBC: [["line1", "line2"], ["line1", "line2"]]
//   board_center_x - X position of the first board center
//   board_index - Which board (0, 1, 2...)
//   eff_w - Effective board width
//   gap - Gap between boards
//   bxo - Board X offset (subtracted from bcx for correct positioning)
//   ph - Panel height
//   pt - Panel thickness
module textover_label(textover_data, board_center_x, board_index, eff_w, gap, bxo, ph, pt) {
  // Get text lines for this board
  if (textover_data != false && board_index < len(textover_data)) {
    lines = textover_data[board_index];
    num_lines = len(lines);
    
    // Calculate X position for this board (same formula as exclusion zone)
    label_x = board_center_x - bxo + board_index * (eff_w + gap);
    
    // Calculate Z position (from top of panel, going down)
    // First line at top, subsequent lines below
    total_text_height = num_lines * textover_font_size_primary + (num_lines - 1) * textover_line_spacing;
    label_z_start = ph - textover_z_offset;
    
    // Render each line
    for (i = [0 : num_lines - 1]) {
      line_z = label_z_start - i * (textover_font_size_primary + textover_line_spacing);
      
      translate([label_x, 0, line_z])
      rotate([90, 0, 0])
      linear_extrude(height = textover_depth + EPS, center = true)
      text(
        lines[i], 
        size = i == 0 ? textover_font_size_primary : textover_font_size_secondary, 
        font = i == 0 ? textover_font_primary : textover_font_secondary,
        halign = "center", 
        valign = "top"
      );
    }
  }
}


// Render all textover labels for all boards
module textoverLabels(preset, bcx, eff_w, gap, bxo, ph, pt) {
  textover_data = preset_textover(preset);
  bc = preset_board_count(preset);
  
  if (textover_data != false && len(textover_data) > 0) {
    for (i = [0 : bc - 1]) {
      textover_label(textover_data, bcx, i, eff_w, gap, bxo, ph, pt);
    }
  }
}
