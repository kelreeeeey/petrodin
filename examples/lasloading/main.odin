package lasload

import "core:fmt"
import "core:os"
import ls "shared:lasio"

main :: proc() {
    file_name: string = os.args[1]
    las_file, parsed_ok := ls.load_las(
        file_name,
        2016,
        allocator=context.allocator)
    defer ls.delete_las_data(las_file)

    if parsed_ok != nil {
        fmt.printfln("Failed to parse the data, err: %v", parsed_ok)
    }

    curve_info : ^ls.CurveInformation
    log_data   : ^ls.LogData

    // idx:=-1

    { // version
        fmt.println("\tVersion:")
        fmt.printfln("\t%v", las_file.version.vers)
        fmt.printfln("\t%v", las_file.version.wrap)
    }

    { // well informations
        fmt.println("\tWell Information records:")
        fmt.printfln("\t%v", las_file.well_info.start)
        fmt.printfln("\t%v", las_file.well_info.stop)
        fmt.printfln("\t%v", las_file.well_info.step)
        fmt.printfln("\t%v", las_file.well_info.null)
        fmt.printfln("\t%v", las_file.well_info.comp)
        fmt.printfln("\t%v", las_file.well_info.well)
        fmt.printfln("\t%v", las_file.well_info.fld)
        fmt.printfln("\t%v", las_file.well_info.loc)
        fmt.printfln("\t%v", las_file.well_info.prov)
        fmt.printfln("\t%v", las_file.well_info.cnty)
        fmt.printfln("\t%v", las_file.well_info.stat)
        fmt.printfln("\t%v", las_file.well_info.srvc)
        fmt.printfln("\t%v", las_file.well_info.date)
        fmt.printfln("\t%v", las_file.well_info.uwi)
        fmt.printfln("\t%v", las_file.well_info.api)
        fmt.printfln("\t%v", las_file.well_info.lic)
    }

    { // curve informations
        curve_info = &las_file.curve_info
        fmt.printfln("\tCurve records: %v", curve_info.len)
        for idx, curve in curve_info.curves {
            fmt.printfln("\t[%v]==> %v", idx, curve)
        }
    }

    { // parameters informations
        fmt.printfln("\tParameter records: %v", las_file.parameter_info.len)
        for param in las_file.parameter_info.params {
            fmt.printfln("\t%v", param)
        }
    }

    { // other informations
        for info in las_file.other_info.info {
            fmt.printfln("\t%v", info)
        }
    }

    { // log data
        log_data = &las_file.log_data
        fmt.printfln("\tWRAP MODE: %v", log_data.wrap)
        n_rows := log_data.nrows
        fmt.printfln("\tNROWS:     %v", n_rows)
        n_curves := log_data.ncurves
        fmt.printfln("\tNCOLS:     %v", n_curves)
        // fmt.printfln("\rITEM     : %v", log_data.logs)
        for log, param in log_data.logs {
            fmt.printfln("\t\tLOG[%v] (5/%v first data points) \t==> %v",
                    log,
                    n_rows,
                    param[:5])
        }
    }

    fmt.println("====================================================================")
    fmt.printfln("")

}
