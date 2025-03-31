package petroapp

import "core:fmt"
import "core:strings"
import "core:strconv"
import im "shared:imgui"
import ls "../lasio"

LAS_Panel :: struct {
    pos:    im.Vec2,
    title:  string,
    data:   ^ls.LasData,
    rendered: i32,
}

las_panel_init :: proc(las_panel: ^LAS_Panel, las_file: ^ls.LasData, title: string) {

    las_panel.data  = las_file
    las_panel.title = title
    las_panel.rendered = 0

}

las_panel_render :: proc(las_panel: ^LAS_Panel) {

    im.SetNextWindowPos(las_panel.pos, .Once)
    title := strings.clone_to_cstring(las_panel.title)
    str_to_int := make(map[string]int)
    defer delete_map(str_to_int)

    if im.Begin(title) {
        n_cols        := las_panel.data.log_data.ncurves
        las_file_name := strings.clone_to_cstring(las_panel.data.file_name)

        if im.BeginTable(las_file_name, n_cols) && las_panel.rendered == 0 {
            for log in 0..<n_cols {
                idx := cast(int)log
                curve_name := las_panel.data.curve_info.curves[idx].mnemonic
                str_to_int[curve_name] = idx
                fmt.printfln("%v Curve Name: %v", log, curve_name)
                im.TableSetupColumn(strings.clone_to_cstring(curve_name))

            }
            im.TableHeadersRow()

            n_pts := las_panel.data.log_data.nrows
            for n_col, log_name in las_panel.data.log_data.logs {
                im.TableSetColumnIndex(cast(i32)str_to_int[n_col])
                for n_row in 0..<n_pts {
                    sb := strings.builder_make()
                    strings.write_f64(&sb, log_name[n_row], 'g', true)
                    pt := strings.to_string(sb)
                    // fmt.printfln("Point: %v", pt)
                    im.TextUnformatted(strings.clone_to_cstring(pt))
                }
            }


            im.EndTable()
        }
        im.End()
    }
}
