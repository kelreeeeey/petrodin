package petroapp

// This is an example of using the bindings with GLFW and OpenGL 3.
// For a more complete example with comments, see:
// https://github.com/ocornut/imgui/blob/docking/examples/example_glfw_opengl3/main.cpp
// Based on the above at tag `v1.91.1-docking` (d8c98c)

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)

import "core:os"
import "core:c"
import "core:fmt"
import "core:log"
import "core:strings"
import im "shared:imgui"
import "shared:imgui/imgui_impl_glfw"
import "shared:imgui/imgui_impl_opengl3"

import "vendor:glfw"
import gl "vendor:OpenGL"
import ls "../lasio"

put_cstring_plain :: proc(item: any) -> cstring {
    return strings.unsafe_string_to_cstring(fmt.tprintf("%v", item))
}

put_cstring_hash :: proc(item: any, hash: bool=true) -> cstring {
    return strings.unsafe_string_to_cstring(fmt.tprintf("%#v", item))
}

put_cstring :: proc { put_cstring_plain, put_cstring_hash }

main :: proc() {
    context.logger = log.create_console_logger()
    log.debug("Well!")

    assert(cast(bool)glfw.Init())
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 2)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1) // i32(true)

    window := glfw.CreateWindow(1280, 720, "Dear ImGui GLFW+OpenGL3 example", nil, nil)
    assert(window != nil)
    defer glfw.DestroyWindow(window)

    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(2) // vsync

    gl.load_up_to(3, 2, proc(p: rawptr, name: cstring) {
        (cast(^rawptr)p)^ = glfw.GetProcAddress(name)
    })

    im.CHECKVERSION()
    im.CreateContext()
    defer im.DestroyContext()
    io := im.GetIO()
    io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}
    when !DISABLE_DOCKING {
        io.ConfigFlags += {.DockingEnable}
        io.ConfigFlags += {.ViewportsEnable}

        style := im.GetStyle()
        style.WindowRounding = 0
        style.Colors[im.Col.WindowBg].w = 1
    }

    im.StyleColorsDark()

    imgui_impl_glfw.InitForOpenGL(window, true)
    defer imgui_impl_glfw.Shutdown()
    imgui_impl_opengl3.Init("#version 150")
    defer imgui_impl_opengl3.Shutdown()

    // here all the panels and data go.
    // file_name: string = os.args[1]

    las_file:         ls.LasData
    parsed_ok:        ls.ReadFileError
    file_name_buffer: [1024]byte
    loaded:           bool = false
    font_scale: f32 = 1.0

    defer ls.delete_las_data(las_file)


    // las_panel: LAS_Panel
    // las_panel_init(&las_panel, &las_file, "LAS Panel")


    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()

        imgui_impl_opengl3.NewFrame()
        imgui_impl_glfw.NewFrame()
        im.NewFrame()

        // ui code

        // viewport := im.GetMainViewport()
        // im.SetNextWindowPos({0,0}, .Appearing)
        // im.SetNextWindowSize(viewport.Size, .Appearing)

        im.ShowDemoWindow()
        if im.Begin("LAS File Loader", nil, {.NoCollapse, .MenuBar}) {
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
                    las_file, parsed_ok = ls.load_las(
                        string(file_name_buffer[:]),
                        2016,
                        allocator=context.allocator)
                    if parsed_ok == nil {
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

            }
            im.SameLine()
            im.SameLine()
            avail := im.GetContentRegionAvail()
            cursor_x := im.GetCursorPosX()
            im.SetCursorPosX(cursor_x + avail.x / 2)
            if im.Button("Load") {
                las_file, parsed_ok = ls.load_las(
                    string(file_name_buffer[:]),
                    2016,
                    allocator=context.allocator)
                if parsed_ok == nil {
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
                n_curves := las_file.log_data.ncurves
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
                        for curve in curve_info.curves {
                            im.Text(put_cstring_plain(fmt.tprintfln("\tCurve records: %v", curve)))
                        }

                        im.Separator()

                        im.EndTabItem()
                    }

                    flags_table: im.TableFlags = im.TableFlags_SizingStretchSame | im.TableFlags_ScrollX | im.TableFlags_ScrollY | im.TableFlags_BordersOuter | im.TableFlags_RowBg | im.TableFlags_ContextMenuInBody
                    if im.BeginTabItem("Log Data") {
                        if im.BeginTable(
                            "Log Data",
                            cast(c.int)las_file.log_data.ncurves,
                            flags_table, ) {

                            defer im.EndTable()
                            for log, param in las_file.log_data.logs {
                                im.TableSetupColumn(strings.unsafe_string_to_cstring(fmt.tprintfln( "%v", log)))
                            }
                            im.TableHeadersRow()

                            // inner_width: f32 = 1000.0
                            // im.PushID("flags3")
                            // im.PushItemWidth(im.CalcTextSize("A").x * 30)

                            for log, param in las_file.log_data.logs {
                                im.TableNextColumn()
                                for n_row in 0..<n_rows{
                                    im.Text(strings.unsafe_string_to_cstring(fmt.tprintfln( "%#v", param[n_row])))
                                }
                            }
                        }
                        im.EndTabItem()
                    }

                    if im.BeginTabItem("Plot Log") {

                        // if im.BeginTable(
                        //     "Log Data",
                        //     cast(c.int)las_file.log_data.ncurves,
                        //     flags_table, ) {
                        //
                        //     defer im.EndTable()
                        //     for log, param in las_file.log_data.logs {
                        //         im.TableSetupColumn(strings.unsafe_string_to_cstring(fmt.tprintfln( "%v", log)))
                        //     }
                        //     im.TableHeadersRow()
                        //
                        //     // inner_width: f32 = 1000.0
                        //     // im.PushID("flags3")
                        //     // im.PushItemWidth(im.CalcTextSize("A").x * 30)
                        //
                        for log, param in las_file.log_data.logs {
                            dd := transmute([]f32)param
                            im.PlotLines(
                                strings.unsafe_string_to_cstring(fmt.tprintfln( "%#v", log)),
                                &dd[0],
                                cast(i32)las_file.log_data.nrows,
                            )
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

        // las_panel.rendered += 1

        im.Render()
        display_w, display_h := glfw.GetFramebufferSize(window)
        gl.Viewport(0, 0, display_w, display_h)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        imgui_impl_opengl3.RenderDrawData(im.GetDrawData())

        when !DISABLE_DOCKING {
            backup_current_window := glfw.GetCurrentContext()
            im.UpdatePlatformWindows()
            im.RenderPlatformWindowsDefault()
            glfw.MakeContextCurrent(backup_current_window)
        }

        glfw.SwapBuffers(window)
    }
}
