package petroapp

// This is an example of using the bindings with GLFW and OpenGL 3.
// For a more complete example with comments, see:
// https://github.com/ocornut/imgui/blob/docking/examples/example_glfw_opengl3/main.cpp
// Based on the above at tag `v1.91.1-docking` (d8c98c)

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)

// import "core:os"
// import "core:c"

import "core:fmt"
import "core:log"
import "core:strings"
import rl "vendor:raylib"
import im "shared:imgui"
import imrl "shared:imgui-raylib"
import ls "../lasio"

// import "shared:imgui/imgui_impl_glfw"
// import "shared:imgui/imgui_impl_opengl3"

// import "vendor:glfw"
// import gl "vendor:OpenGL"

put_cstring_plain :: proc(item: any) -> cstring {
    return strings.unsafe_string_to_cstring(fmt.tprintf("%v", item))
}

put_cstring_hash :: proc(item: any, hash: bool=true) -> cstring {
    return strings.unsafe_string_to_cstring(fmt.tprintf("%#v", item))
}

put_cstring :: proc { put_cstring_plain, put_cstring_hash }

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(1900, 1000, "PetroApp")
    defer rl.CloseWindow()

// // Camera type, defines a camera position/orientation in 3d space
// Camera3D :: struct {
// 	position: Vector3,            // Camera position
// 	target:   Vector3,            // Camera target it looks-at
// 	up:       Vector3,            // Camera up vector (rotation over its axis)
// 	fovy:     f32,                // Camera field-of-view apperture in Y (degrees) in perspective, used as near plane width in orthographic
// 	projection: CameraProjection, // Camera projection: CAMERA_PERSPECTIVE or CAMERA_ORTHOGRAPHIC
// }
// //
//     camera := rl.Camera3D{
//         position={1, 10, 10},
//         target={0,100,0},
//         up={0,0,0},
//         fovy=30,
//         projection=.ORTHOGRAPHIC,
//     }
//     cameraMode: rl.CameraMode = .CUSTOM

    las_file:         ls.LasData
    parsed_ok:        ls.ReadFileError
    defer ls.delete_las_data(las_file)

    file_name_buffer: [1024]byte

    loaded:           bool = false
    font_scale:       f32 = 1.0

    log_table_cols := make(map[int]string, 0)
    defer delete_map(log_table_cols)

    im.CreateContext(nil)
    defer im.DestroyContext(nil)

    imrl.init_imguirl()
    defer imrl.shutdown_imguirl()
    imrl.imguirl_build_font_atlas()

    for !rl.WindowShouldClose() {


        // rl.UpdateCamera(&camera, cameraMode)
        imrl.process_events_imguirl()
        imrl.new_frame_imguirl()

        im.NewFrame()
        defer im.EndFrame()

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        if im.Begin("LAS File Loader", nil, {.NoTitleBar, .MenuBar}) {
            defer im.End()

            // Setup
            im.SetWindowFontScale(font_scale)
            if im.IsKeyPressed(.RightCtrl) && im.IsKeyPressed(.Equal) {
                font_scale += 0.25
                im.SetWindowFontScale(font_scale)
            }
            if im.IsKeyPressed(.RightCtrl) && im.IsKeyPressed(.Minus) {
                font_scale -= 0.25
                im.SetWindowFontScale(font_scale)
            }

            if im.BeginMenuBar() {
                defer im.EndMenuBar()
                if im.BeginMenu("File") {
                    defer im.EndMenu()
                    if im.MenuItem("Open") {
                        log.debugf("open")
                    }
                }
            }

            if im.InputText(
                "Filename",
                transmute(cstring)&file_name_buffer,
                len(file_name_buffer),
                {.EnterReturnsTrue},
            ) {
                if im.IsKeyPressed(.Enter) {

                    if las_file, parsed_ok = ls.load_las(
                        string(file_name_buffer[:]),
                        2016,
                        allocator=context.allocator,
                    ); parsed_ok == nil {
                        im.Text(put_cstring_plain(las_file.version.vers))
                        im.Text(put_cstring_plain(las_file.version.wrap))
                        im.Text(put_cstring(las_file.well_info, true))
                        im.Text(strings.unsafe_string_to_cstring(fmt.tprintf("%#v", las_file.curve_info)))
                        loaded = true
                    } else {
                        im.Text(strings.unsafe_string_to_cstring(fmt.tprintf("Failed to parse the data, err: %#v", parsed_ok.(ls.ParseHeaderError).message)))
                        im.Text(strings.unsafe_string_to_cstring(fmt.tprintf("Failed to parse the data, err: %#v", parsed_ok)))
                    }
                }

            }
            im.SameLine()
            im.SameLine()
            avail := im.GetContentRegionAvail()
            cursor_x := im.GetCursorPosX()
            im.SetCursorPosX(cursor_x + avail.x / 2)
            if im.Button("Load") {
                if las_file, parsed_ok = ls.load_las(
                    string(file_name_buffer[:]),
                    2016,
                    allocator=context.allocator); parsed_ok == nil {
                    // las_panel_render(&las_panel)
                    im.Text(put_cstring_plain(las_file.version.vers))
                    im.Text(put_cstring_plain(las_file.version.wrap))
                    im.Text(put_cstring(las_file.well_info, true))
                    im.Text(strings.unsafe_string_to_cstring(fmt.tprintf("%#v", las_file.curve_info)))
                    loaded = true
                } else {
                    im.Text(strings.unsafe_string_to_cstring(fmt.tprintf("Failed to parse the data, err: %#v", parsed_ok.(ls.ParseHeaderError).message)))
                    im.Text(strings.unsafe_string_to_cstring(fmt.tprintf("Failed to parse the data, err: %#v", parsed_ok)))
                }
            }

            if parsed_ok == nil || loaded {

                n_rows := las_file.log_data.nrows
                // n_curves := las_file.log_data.ncurves
                // las_panel_render(&las_panel)

                if im.BeginTabBar("Las Data") {
                    defer im.EndTabBar()

                    if im.BeginTabItem("Header") {
                        im.Text(put_cstring_plain(fmt.tprintfln("Version Information")))
                        im.Text(put_cstring_plain(fmt.tprintfln("\tVersion:%v", las_file.version.vers)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\tVersion:%v", las_file.version.wrap)))

                        im.Separator()

                        im.Text(put_cstring_plain(fmt.tprintfln("Well Information records:")))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.start)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.stop)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.step)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.null)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.comp)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.well)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.fld)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.loc)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.prov)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.cnty)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.stat)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.srvc)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.date)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.uwi)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.api)))
                        im.Text(put_cstring_plain(fmt.tprintfln("\t%v", las_file.well_info.lic)))

                        // parameters informations
                        im.Separator()

                        im.Text(put_cstring_plain(fmt.tprintfln("Parameter records: %v", las_file.parameter_info.len)))
                        for param in las_file.parameter_info.params {
                            im.Text(put_cstring_plain(fmt.tprintfln("\tParameter: %v", param)))
                        }

                        im.Separator()

                        curve_info := &las_file.curve_info
                        im.Text(put_cstring_plain(fmt.tprintfln("Curve Information")))
                        im.Text(put_cstring_plain(fmt.tprintfln("\tCurve records: %v", curve_info.len)))
                        for idx, curve in curve_info.curves {
                            im.Text(put_cstring_plain(fmt.tprintfln("\tCurve records[%v]: %v", idx, curve)))
                        }

                        im.Separator()

                        im.EndTabItem()
                    }

                    flags_table: im.TableFlags = im.TableFlags_SizingStretchSame | im.TableFlags_ScrollX | im.TableFlags_ScrollY | im.TableFlags_BordersOuter | im.TableFlags_RowBg | im.TableFlags_ContextMenuInBody
                    if im.BeginTabItem("Log Data") {
                        if im.BeginTable(
                            "Log Data",
                            las_file.log_data.ncurves,
                            flags_table, ) {

                            defer im.EndTable()
                            count_col := 0
                            for idx_col in 0..<las_file.log_data.ncurves {
                                curve_item := las_file.curve_info.curves[cast(int)idx_col]
                                im.TableSetupColumn(strings.unsafe_string_to_cstring(fmt.tprintfln( "%v", curve_item.descr)))
                                count_col += 1
                            }
                            im.TableHeadersRow()

                            // thx deepseek, even your code was lil bit wrong, but ok
                            n_lines_to_render :: 200  // Number of visible lines
                            start_line:  i32          // First visible line index
                            curr_scroll: f32          // Current scroll position
                            prev_scroll: f32          // Previous scroll position (for delta)

                            curr_scroll = im.GetScrollY()
                            prev_scroll = curr_scroll

                            total_lines := n_rows
                            line_height := im.GetTextLineHeightWithSpacing()
                            visible_lines := cast(i32)(im.GetWindowHeight() / line_height)

                            // Update start_line based on scroll position
                            start_line = cast(i32)(curr_scroll / line_height)
                            start_line = max(0, start_line - 5)  // 5-line buffer above
                            end_line := min(total_lines, start_line + visible_lines + 10)

                            // Use ListClipper for efficient rendering
                            clipper := im.ListClipper{}
                            im.ListClipper_Begin(&clipper, total_lines, line_height)
                            defer im.ListClipper_End(&clipper)

                            // stepping
                            for im.ListClipper_Step(&clipper) {
                                    for row in clipper.DisplayStart..<clipper.DisplayEnd {
                                        im.TableNextRow()

                                        for idx_col in 0..<count_col {
                                            im.TableNextColumn()
                                            curve := las_file.log_data.logs[idx_col]

                                            // Only render visible lines
                                            if row >= start_line && row < end_line {
                                                im.Text("%.2f", curve[row])
                                            } else {
                                                im.Text("")  // Empty space for non-visible lines
                                            }
                                        }
                                    }
                                }
                        }
                        im.EndTabItem()
                    }
                }

                im.Separator()

            } else {

                im.Text(strings.unsafe_string_to_cstring(
                    fmt.tprintf("Failed to parse the data, err: %#v", parsed_ok.(ls.ParseHeaderError).message)))
                im.Text(strings.unsafe_string_to_cstring(
                    fmt.tprintf("Failed to parse the data, err: %#v", parsed_ok)))
            }
        }

        if loaded {
            n_rows    := las_file.log_data.nrows
            depth_log := las_file.log_data.logs[0]
            some_log  := las_file.log_data.logs[3]
            some_log2  := las_file.log_data.logs[6]

            for idx in 1..<(n_rows) {
                {
                    pos_back := rl.Vector2{40*cast(f32)some_log[idx-1]+200, 0.5*cast(f32)depth_log[idx-1]-1500}
                    pos_forw := rl.Vector2{40*cast(f32)some_log[idx]+200,   0.5*cast(f32)depth_log[idx]-1500}

                    rl.DrawLineEx(pos_back, pos_forw, 10, rl.BLUE)
                }
                {
                    pos_back := rl.Vector2{cast(f32)some_log2[idx-1]+200, 0.5*cast(f32)depth_log[idx-1]-1500}
                    pos_forw := rl.Vector2{cast(f32)some_log2[idx]+200,   0.5*cast(f32)depth_log[idx]-1500}

                    rl.DrawLineEx(pos_back, pos_forw, 10, rl.GREEN)
                }

            }

                // rl.GuiPanel({
                //     200, 200,
                //     200, 200,
                // }, "Panel",)
                // rl.GuiGrid({
                //     200, 200,
                //     200, 200,
                // }, "Grid", 100, 100, nil)

        }

        im.Render()
        imrl.render_draw_data(im.GetDrawData())

        rl.EndDrawing()
    }
}
