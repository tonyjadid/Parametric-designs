/*
    Elfa Shelf Bracket SCAD model
    Author: Tony Jadid

    This OpenSCAD script generates an Elfa-compatible shelf bracket
    designed to fit standard Elfa wall rails with a reinforced backplate.

    Features:
    - Adjustable number of vertical hook columns and spacing between them.
    - Parametric hook geometry for inner/outside hook distance, depth, height,
      and notch placement.
    - Calculated hook height based on Elfa pitch and clearance gap.
    - Optional 3D measurement text for quick dimensional validation.
    - Configurable foundation fillet to improve slicer layer adhesion,
      reducing stress on thin hook joints.
    - Dual hook columns are created for each rail to provide a stiff,
      reinforced bracket structure.

    The model uses a 2D hook profile extruded across the hook width, then
    optionally adds a smooth tapered base foundation to merge with the backplate.
*/

/* [Horizontal Layout] */
number_of_columns = 1;            // Number of vertical standards (rails) to mount to or on a board
column_spacing_x = 85;            // Center-to-center distance between the columns (mm)

/* [Elfa Slot Spacing (Horizontal)] */
// Distance between the inner faces of the two hooks (mm)
hook_inner_distance = 8.3;  
// Distance between the outer faces of the two hooks (mm)
hook_outer_distance = 13.5;  

/* [Information Display] */
// Show calculated dimensions as 3D text above the model (turn off before printing)
show_measurement_text = false;

/* [Elfa Mount Settings] */
number_of_hooks = 2;              // Number of vertical hooks per column
bracket_width_per_column = 24;    // The base width of the backplate covering one column group
backplate_thickness = 3;

/* [Strength Optimization] */
// How deep the hooks penetrate into the interior (mm)
hook_embed_depth = 3;     
// Chamfer/fillet radius at the base of the hook inside the backplate (mm)
hook_root_chamfer = 2.5;    

/* [Slicer Layer Overlap Optimization,  this seems to work] */
// To prevent the slicer from creating a weak flat layer joint, a 3D foundation taper forces intersecting perimeters.
hook_base_width_fillet = 1;     // Taper lateral width left/right (adds total width at surface)
hook_base_height_fillet = 0;  // Taper vertically up/down along the backplate
hook_base_fillet_depth = 2;   // Length of taper transitioning outwards into the main hook

/* [Spacing & Height] */
hook_pitch_y = 32;           // Standard Elfa pitch vertically (center-to-center distance)
hook_vertical_offset = 1;   // Distance from bottom of bracket to first hook
bracket_top_margin = 21;      // Margin above the top hook

/* [Hook Profile (Elfa Style)] */
hook_depth = 12;             // Depth penetrating the wall standard
hook_top_y_front = 15;       // Front top height of the hook
hook_top_y_back = 12;        // Sloped rear top height for insertion
hook_gap_size = 20;          // Distance BETWEEN one hook bottom and the next hook top
notch_depth = 4.5;              // Clearance for standard wall thickness
notch_distance_from_bottom = 7; // Distance from the hook's lowest tip up to the notch (rests on the standard)
base_bottom_y = 8.8;            // Bottom angle thickness matching notch
hook_tip_chamfer = 2.5;       // Angled tip for smoother insertion

/* [Appearance] */
bracket_color = "#4682B4"; // SteelBlue
text_color = "#FFFFFF";    // White

// --- Calculations ---
// The hook width is the half-gap between the two hook faces.
hook_width = (hook_outer_distance - hook_inner_distance) / 2;
// The horizontal spacing of the hook pair within a column.
calculated_hook_pitch_x = hook_inner_distance + hook_width;

// Calculate the total height of each hook from its pitch and clearance gap.
calculated_hook_total_height = hook_pitch_y - hook_gap_size;

// Auto-calculate structural dimensions
bracket_height = hook_vertical_offset + ((number_of_hooks - 1) * hook_pitch_y) + bracket_top_margin;
total_bracket_width = (number_of_columns - 1) * column_spacing_x + bracket_width_per_column;

// Optional debug labels showing the calculated hook dimensions above the part.
if (show_measurement_text) {
    color(text_color)
    translate([0, 0, bracket_height + 5])
    rotate([90, 0, 0])
    linear_extrude(1)
    union() {
        text(str("Hook Width: ", hook_width, " mm"), size = 2.5, halign = "center", valign = "bottom");
        translate([0, -4, 0])
            text(str("Calculated Hook Height: ", calculated_hook_total_height, " mm"), size = 2.5, halign = "center", valign = "bottom");
    }
}

color(bracket_color)
union() {
    // Main solid support backplate spanning across all columns
    translate([-total_bracket_width/2, -backplate_thickness, 0])
        cube([total_bracket_width, backplate_thickness, bracket_height]);

    // Generate hook groups for each column
    for (col = [0 : number_of_columns - 1]) {
        x_col_offset = (col - (number_of_columns - 1) / 2) * column_spacing_x;
        
        translate([x_col_offset, 0, 0]) {
            // Left reinforced hook column
            translate([-calculated_hook_pitch_x/2, 0, 0])
                hook_column();

            // Right reinforced hook column
            translate([calculated_hook_pitch_x/2, 0, 0])
                hook_column();
        }
    }
}

// Build one column of hooks arranged vertically.
// Each hook in the column is placed at the standard Elfa pitch.
module hook_column() {
    // Compute the bottom of the hook geometry from the rear top height.
    hook_bottom_z = hook_top_y_back - calculated_hook_total_height;
    // Calculated Z-value for the notch based on the distance from the hook bottom
    actual_notch_z = hook_bottom_z + notch_distance_from_bottom;
    
    for (i = [0 : number_of_hooks - 1]) {
        z_pos = hook_vertical_offset + (i * hook_pitch_y);
        
        translate([0, 0, z_pos]) {
            // 1. The core constant-thickness hook profile
            // Polygon X -> Depth (Y), Polygon Y -> Height (Z)
            rotate([90, 0, 90])
            linear_extrude(height=hook_width, center=true)
            polygon([
                [-hook_embed_depth, base_bottom_y - hook_root_chamfer], 
                [0, base_bottom_y],                                       
                [notch_depth, actual_notch_z],                              
                [notch_depth, hook_bottom_z],                               
                [hook_depth - hook_tip_chamfer, hook_bottom_z],            
                [hook_depth, hook_bottom_z + hook_tip_chamfer],            
                [hook_depth, hook_top_y_back],                          
                [0, hook_top_y_front],                                   
                [-hook_embed_depth, hook_top_y_front + hook_root_chamfer] 
            ]);
            
            // 2. The 3D Tapered Foundation for Slicer Adhesion
            // Gradually slopes from a widened base footprint down to the bare hook shape.
            if (hook_base_fillet_depth > 0) {
                y_target = hook_base_fillet_depth;
                
                // Interpolate matching heights to follow the exact slopes of the hook profile.
                // These values define the tapering shape between the hook surface and the wide base.
                t_bottom = y_target / notch_depth;
                z_bottom_taper = base_bottom_y * (1 - t_bottom) + actual_notch_z * t_bottom;
                
                t_top = y_target / hook_depth;
                z_top_taper = hook_top_y_front * (1 - t_top) + hook_top_y_back * t_top;
                
                hull() {
                    // Wide foundation base deeply bonded with the backplate surface.
                    // This polygon defines the widened support footprint.
                    rotate([90, 0, 90])
                    linear_extrude(height=hook_width + hook_base_width_fillet*2, center=true)
                    polygon([
                        [-0.1, base_bottom_y - hook_base_height_fillet],
                        [0.1, base_bottom_y - hook_base_height_fillet],
                        [0.1, hook_top_y_front + hook_base_height_fillet],
                        [-0.1, hook_top_y_front + hook_base_height_fillet]
                    ]);
                    
                    // Merging smoothly into the exact hook dimensions at the taper depth.
                    rotate([90, 0, 90])
                    linear_extrude(height=hook_width, center=true)
                    polygon([
                        [y_target - 0.1, z_bottom_taper],
                        [y_target, z_bottom_taper],
                        [y_target, z_top_taper],
                        [y_target - 0.1, z_top_taper]
                    ]);
                }
            }
        }
    }
}