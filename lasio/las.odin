package lasio

// import "base:runtime"
import "core:fmt"
import "core:os"
import "core:io"
import "core:bufio"
import "core:mem"
import "core:math"
import "core:strings"
import "core:strconv"
// import "core:encoding/endian"

ReadFileError :: union {
    OpenError,
    ReaderCreationError,
    mem.Allocator_Error,
    ReaderReadByteError,
    ParseHeaderError,
}

OpenError :: struct {
    file_name: string,
    error: os.Errno,
}

ReaderCreationError :: struct {
    file_name: string,
    stream: io.Stream,
}

ReaderReadByteError :: struct {
    file_name: string,
    reader: bufio.Reader,
}

ParseHeaderError :: struct {
    file_name: string,
    line:      string,
    message:   string,
}

FLAGS :: enum {
    TILDE, // `~` character, indicating section
    POUND, // `#` chatacter, indication comment
    OTHER, // ` ` or `\t` chatacters, indication data
}

load_las :: proc(
    file_name: string,
    bufreader_size: int,
    allocator := context.allocator) -> (
    las_data: LasData,
    err     : ReadFileError) {

    las_data.file_name = file_name
    // create an handler
    handle, open_error := os.open(file_name, os.O_RDONLY)
    if open_error != os.ERROR_NONE {
        fmt.printfln("Failed to open %v with err: %v", file_name, open_error)
        return las_data, OpenError{file_name, open_error}
    }

    // create a stream
    stream := os.stream_from_handle(handle)

    // create a reader
    reader, ok := io.to_reader(stream)
    if !ok {
        fmt.printfln("Failed make reader of %v with err: %v", file_name, open_error)
        return las_data, ReaderCreationError{file_name, stream}
    }

    // define bufio_reader
    bufio_reader : bufio.Reader
    bufio.reader_init(&bufio_reader, reader, bufreader_size, allocator=allocator)
    bufio_reader.max_consecutive_empty_reads = 1

    next_line:        string
    vers_parse_err:   ReadFileError

    version_header:   Version
    version_header, next_line, vers_parse_err = parse_version_info(file_name, &bufio_reader, allocator=allocator)
    if vers_parse_err != nil {
        delete(version_header.add)
        return las_data, vers_parse_err
    } else {
        las_data.version = version_header
    }


    well_info_header:      WellInformation
    params_info_header:    ParameterInformation
    curve_info_header:     CurveInformation
    others_info_header:    OtherInformation
    log_datas_info_header: LogData

    for vers_parse_err == nil {

        switch {

            case strings.contains(next_line, "~W"):
                well_info_header, next_line, vers_parse_err = parse_well_info(
                    file_name,
                    &bufio_reader,
                    next_line,
                    allocator=allocator)
                if vers_parse_err != nil {
                    return las_data, vers_parse_err
                } else {
                    las_data.well_info = well_info_header
                }

            case strings.contains(next_line, "~C"):
                curve_info_header, next_line, vers_parse_err = parse_curve_info(
                    file_name,
                    &bufio_reader,
                    next_line,
                    allocator=allocator)
                if vers_parse_err != nil {
                    delete(curve_info_header.curves)
                    return las_data, vers_parse_err
                } else {
                    las_data.curve_info = curve_info_header
                }

            case strings.contains(next_line, "~P"):
                params_info_header, next_line, vers_parse_err = parse_param_info(
                    file_name,
                    &bufio_reader,
                    next_line,
                    allocator=allocator)
                if vers_parse_err != nil {
                    delete(params_info_header.params)
                    return las_data, vers_parse_err
                } else {
                    las_data.parameter_info = params_info_header
                }

            case strings.contains(next_line, "~O"):
                others_info_header, next_line, vers_parse_err = parse_other_info(
                    file_name,
                    &bufio_reader,
                    next_line,
                    allocator=allocator)
                if vers_parse_err != nil {
                    return las_data, vers_parse_err
                } else {
                    las_data.other_info = others_info_header
                }

            case strings.contains(next_line, "~A"):
                log_datas_info_header, next_line, vers_parse_err = parse_ascii_log_info(
                    file_name,
                    &bufio_reader,
                    next_line,
                    version_header,
                    well_info_header,
                    curve_info_header,
                    allocator=allocator)
                if vers_parse_err != nil {
                    return las_data, vers_parse_err
                } else {
                    las_data.log_data = log_datas_info_header
                }

            case len(next_line) == 0:
                return las_data, nil
        }
    }

    return las_data, nil
}

// thx deep seek :D
parse_las_line :: proc(line: string) -> (mnem, units, data, desc: string, ok: bool) {
    trimmed := strings.trim_space(line) // Trim leading/trailing whitespace
    if len(trimmed) == 0 do return "", "", "", "", false

    dot_idx := strings.index(trimmed, ".") // Split MNEM (everything before first dot)
    if dot_idx == -1 do return "", "", "", "", false
    mnem = strings.trim_right_space(trimmed[:dot_idx])

    rest := trimmed[dot_idx+1:] // Process remaining parts after MNEM

    space_idx := strings.index(rest, " ") // Find units (between dot and first space)
    if space_idx == -1 {
        units = "" // Case: "MNEM. :DESC" with no units/data
        rest = ""
    } else {
        units = strings.trim_space(rest[:space_idx])
        rest = strings.trim_left_space(rest[space_idx+1:])
    }

    colon_idx := strings.last_index(rest, ":") // Split DATA and DESC using last colon
    if colon_idx == -1 {
        data = strings.trim_space(rest) // No description, all is data
        desc = ""
    } else {
        data = strings.trim_space(rest[:colon_idx])
        desc = strings.trim_space(rest[colon_idx+1:])
    }

    return mnem, units, data, desc, true
}

/*
Parse version info will make version struct and return next first line section
and a potential error.

Input:
- file_name: string, file_name that were being read by the stream and bufio reader
- reader:   ^bufio.Reader, pointer to bufio.Reader struct,
- allocatort: context.allocator

Output:
- version_header: Version, the `Version` struct
- next_line: string, the first line of next sections i.e. the section line itself
    after the version section being read
- err: ReadFileError union, the potential error


Note:
    parse_version_info should always come first, it does not take previous line.
*/
parse_version_info :: proc(file_name: string, reader: ^bufio.Reader, allocator := context.allocator) -> (
    version_header: Version,
    next_line:      string,
    err:            ReadFileError,
) {

    read_lines    := make([dynamic]string, 0, allocator=context.allocator)

    version_header.vers = HeaderItem{}
    version_header.wrap = HeaderItem{}
    version_header.add = []HeaderItem{}

    count_section := 0
    count_line    := 0
    for {

        raw_line, read_bytes_err := bufio.reader_read_string(reader, '\n', allocator=allocator)
        if strings.has_prefix(raw_line, "~") { count_section += 1 }
        if read_bytes_err == os.ERROR_EOF || count_section == 2 {

            clone_err : mem.Allocator_Error
            next_line, clone_err = strings.clone(raw_line)
            if clone_err != nil {
                // TODO: (Kelrey) do better error propagation with more intuitive
                // error message.
                return version_header, next_line, clone_err
            }
            break

        } else if read_bytes_err != nil {

            return version_header, next_line, ReaderReadByteError{file_name=file_name, reader=reader^}

        } else {


            len_line := len(raw_line)-2
            if count_line == 0 {
                append(&read_lines, raw_line[:len_line])
            } else {
                append(&read_lines, raw_line[:len_line])
            }

            count_line += 1

        }
    }

    { // assign all the read lines to Version struct
        additionals := make([dynamic]HeaderItem, 0, allocator=allocator)
        min_item := 2
        count := 0
        for item in read_lines[1:] {
            if !strings.has_prefix(item, "~") {
                mnemonic, _, value, descr, _ := parse_las_line(item)

                switch {
                case strings.contains(mnemonic, "VERS"):

                    new_value:= strconv.atof(value)
                    version_header.vers.mnemonic = mnemonic
                    version_header.vers.value = new_value
                    version_header.vers.descr = descr

                case strings.contains(mnemonic, "WRAP"):

                    new_value: bool
                    if value == "YES" { new_value = true }
                    else              { new_value = false }

                    version_header.wrap.mnemonic = mnemonic
                    version_header.wrap.value = new_value
                    version_header.wrap.descr = descr

                case :

                    adds := HeaderItem{
                        mnemonic= mnemonic,
                        value   = value,
                        descr   = descr,
                    }
                    append(&additionals, adds)
                }

                count += 1
            } else {
                continue
            }
        }

        if count <= min_item { delete(additionals) }
        else { version_header.add = additionals[:] }

    }

    return version_header, next_line, nil
}

parse_well_info :: proc(file_name: string, reader: ^bufio.Reader, prev_line: string, allocator := context.allocator) -> (
    well_info_header: WellInformation,
    next_line:        string,
    err:              ReadFileError,
) {

    if !strings.has_prefix(prev_line, "~W") {
        return well_info_header, next_line, ParseHeaderError{
            file_name=file_name,
            line=prev_line,
            message="Line is not a valid WELL INFORMATION section, cannot proceed to parse",
        }
    }

    read_lines    := make([dynamic]string, 0, allocator=context.allocator)

    count_section := 1
    count_line    := 0
    for {

        raw_line, read_bytes_err := bufio.reader_read_string(reader, '\n', allocator=allocator)
        if strings.has_prefix(raw_line, "~") { count_section += 1 }
        if read_bytes_err == os.ERROR_EOF || count_section == 2 {

            clone_err : mem.Allocator_Error
            next_line, clone_err = strings.clone(raw_line)
            if clone_err != nil {
                // TODO: (Kelrey) do better error propagation with more intuitive
                // error message.
                return well_info_header, next_line, clone_err
            }
            break

        } else if read_bytes_err != nil {

            return well_info_header, next_line, ReaderReadByteError{file_name=file_name, reader=reader^}

        } else {


            len_line := len(raw_line)-2
            if count_line == 0 {
                append(&read_lines, raw_line[:len_line])
            } else {
                append(&read_lines, raw_line[:len_line])
            }

            count_line += 1

        }
    }

    { // assign all the read lines to `WellInformation` struct

        // additionals := make([dynamic]HeaderItem, 0, allocator=allocator)
        for item in read_lines {
            if !strings.has_prefix(item, "#") && !strings.has_prefix(item, "~") {

                mnemonic, unit, raw_value, descr, _ := parse_las_line(item)
                switch {

                case strings.contains(mnemonic, "STRT"):
                    value := strconv.atof(strings.trim_space(raw_value))
                    well_info_header.start.mnemonic = "STRT"
                    well_info_header.start.unit     = unit
                    well_info_header.start.value    = value
                    well_info_header.start.descr    = descr

                case strings.contains(mnemonic, "STOP"):
                    value := strconv.atof(strings.trim_space(raw_value))
                    well_info_header.stop.mnemonic = "STOP"
                    well_info_header.stop.unit     = unit
                    well_info_header.stop.value    = value
                    well_info_header.stop.descr    = descr

                case strings.contains(mnemonic, "STEP"):
                    value := strconv.atof(strings.trim_space(raw_value))
                    well_info_header.step.mnemonic = "STEP"
                    well_info_header.step.unit     = unit
                    well_info_header.step.value    = value
                    well_info_header.step.descr    = descr

                case strings.contains(mnemonic, "NULL"):
                    value := strconv.atof(strings.trim_space(raw_value))
                    well_info_header.null.mnemonic = "NULL"
                    well_info_header.null.unit     = unit
                    well_info_header.null.value    = value
                    well_info_header.null.descr    = descr

                case strings.contains(mnemonic, "COMP"):
                    value:                    = raw_value
                    well_info_header.comp.mnemonic = "COMP"
                    well_info_header.comp.unit     = unit
                    well_info_header.comp.value    = value
                    well_info_header.comp.descr    = descr

                case strings.contains(mnemonic, "WELL"):
                    value:                    = raw_value
                    well_info_header.well.mnemonic = "WELL"
                    well_info_header.well.unit     = unit
                    well_info_header.well.value    = value
                    well_info_header.well.descr    = descr

                case strings.contains(mnemonic, "FLD"):
                    value:                    = raw_value
                    well_info_header.fld.mnemonic = "FLD"
                    well_info_header.fld.unit     = unit
                    well_info_header.fld.value    = value
                    well_info_header.fld.descr    = descr

                case strings.contains(mnemonic, "LOC"):
                    value:                    = raw_value
                    well_info_header.loc.mnemonic = "LOC"
                    well_info_header.loc.unit     = unit
                    well_info_header.loc.value    = value
                    well_info_header.loc.descr    = descr

                case strings.contains(mnemonic, "PROV"):
                    value:                    = raw_value
                    well_info_header.prov.mnemonic = "PROV"
                    well_info_header.prov.unit     = unit
                    well_info_header.prov.value    = value
                    well_info_header.prov.descr    = descr

                case strings.contains(mnemonic, "CNTY"):
                    value:                    = raw_value
                    well_info_header.cnty.mnemonic = "CNTY"
                    well_info_header.cnty.unit     = unit
                    well_info_header.cnty.value    = value
                    well_info_header.cnty.descr    = descr

                case strings.contains(mnemonic, "STAT"):
                    value:                    = raw_value
                    well_info_header.stat.mnemonic = "STAT"
                    well_info_header.stat.unit     = unit
                    well_info_header.stat.value    = value
                    well_info_header.stat.descr    = descr

                case strings.contains(mnemonic, "CTRY"):
                    value:                    = raw_value
                    well_info_header.ctry.mnemonic = "CTRY"
                    well_info_header.ctry.unit     = unit
                    well_info_header.ctry.value    = value
                    well_info_header.ctry.descr    = descr

                case strings.contains(mnemonic, "SRVC"):
                    value:                    = raw_value
                    well_info_header.srvc.mnemonic = "SRVC"
                    well_info_header.srvc.unit     = unit
                    well_info_header.srvc.value    = value
                    well_info_header.srvc.descr    = descr

                case strings.contains(mnemonic, "DATE"):
                    value:                    = raw_value
                    well_info_header.date.mnemonic = "DATE"
                    well_info_header.date.unit     = unit
                    well_info_header.date.value    = value
                    well_info_header.date.descr    = descr

                case strings.contains(mnemonic, "UWI"):
                    // TODO:"please exclude all dashes, slashes, and spaces from such UWIs"
                    // from LAS_20_Update_Jan.
                    value:                   = raw_value
                    well_info_header.uwi.mnemonic = "UWI"
                    well_info_header.uwi.unit     = unit
                    well_info_header.uwi.value    = value
                    well_info_header.uwi.descr    = descr

                case strings.contains(mnemonic, "API"):
                    value:                   = raw_value
                    well_info_header.api.mnemonic = "API"
                    well_info_header.api.unit     = unit
                    well_info_header.api.value    = value
                    well_info_header.api.descr    = descr

                case strings.contains(mnemonic, "LIC"):
                    value:                   = raw_value
                    well_info_header.lic.mnemonic = "LIC"
                    well_info_header.lic.unit     = unit
                    well_info_header.lic.value    = value
                    well_info_header.lic.descr    = descr

                case :
                    well_info_header.lic.mnemonic = mnemonic
                    well_info_header.lic.unit     = unit
                    well_info_header.lic.value    = raw_value
                    well_info_header.lic.descr    = descr

                }
            } else {
                continue
            }
        }

    }

    return well_info_header, next_line, nil
}

parse_curve_info :: proc(file_name: string, reader: ^bufio.Reader, prev_line: string, allocator := context.allocator) -> (
    curves_info_header: CurveInformation,
    next_line:        string,
    err:              ReadFileError,
) {

    if !strings.has_prefix(prev_line, "~C") {
        return curves_info_header, next_line, ParseHeaderError{
            file_name=file_name,
            line=prev_line,
            message="Line is not a valid CURVES INFORMATION section, cannot proceed to parse",
        }
    }

    read_lines    := make([dynamic]string, 0, allocator=context.allocator)

    count_section := 1
    count_line    := 0
    for {

        raw_line, read_bytes_err := bufio.reader_read_string(reader, '\n', allocator=allocator)
        if strings.has_prefix(raw_line, "~") { count_section += 1 }
        if read_bytes_err == os.ERROR_EOF || count_section == 2 {

            clone_err : mem.Allocator_Error
            next_line, clone_err = strings.clone(raw_line)
            if clone_err != nil {
                // TODO: (Kelrey) do better error propagation with more intuitive
                // error message.
                return curves_info_header, next_line, clone_err
            }
            break

        } else if read_bytes_err != nil {

            return curves_info_header, next_line, ReaderReadByteError{file_name=file_name, reader=reader^}

        } else {


            len_line := len(raw_line)-2
            if count_line == 0 {
                append(&read_lines, raw_line[:len_line])
            } else {
                append(&read_lines, raw_line[:len_line])
            }

            count_line += 1

        }
    }

    { // assign all the read lines to `CurveInformation` struct

        count:int = 0
        // items     := make_map(map[int]HeaderItem)//, 0, allocator=allocator)

        for _item in read_lines {
            item : string
            if strings.has_prefix(_item, "\n") {
                item = _item[1:]
            } else {
                item = _item
            }
            if !strings.has_prefix(item, "#") && !strings.has_prefix(item, "~") {
                header_item : HeaderItem
                mnemonic, unit, value, descr, _ := parse_las_line(item)

                parsed_desc, _ := strings.split_n(descr, " ", 2)

                header_item.mnemonic = mnemonic
                header_item.unit     = unit
                header_item.value    = value
                header_item.descr    = parsed_desc[1]

                // append(&items, header_item)

                idx := strconv.atoi(parsed_desc[0]) - 1
                curves_info_header.curves[idx] = header_item
                count += 1


            } else {

                continue

            }
        }
        curves_info_header.len = cast(i32)count

    }

    return curves_info_header, next_line, nil
}

parse_param_info :: proc(file_name: string, reader: ^bufio.Reader, prev_line: string, allocator := context.allocator) -> (
    params_info_header: ParameterInformation,
    next_line:          string,
    err:                ReadFileError,
) {

    if !strings.has_prefix(prev_line, "~P") {
        return params_info_header, next_line, ParseHeaderError{
            file_name=file_name,
            line=prev_line,
            message="Line is not a valid PARAMETERS INFORMATION section, cannot proceed to parse",
        }
    }

    read_lines    := make([dynamic]string, 0, allocator=context.allocator)

    count_section := 0
    count_line    := 0
    if count_section != 1 {
        for {

            raw_line, read_bytes_err := bufio.reader_read_string(reader, '\n', allocator=allocator)
            if strings.has_prefix(raw_line, "~") { count_section += 1 }
            if read_bytes_err == os.ERROR_EOF || count_section == 1 {

                clone_err : mem.Allocator_Error
                next_line, clone_err = strings.clone(raw_line)
                if clone_err != nil {
                    // TODO: (Kelrey) do better error propagation with more intuitive
                    // error message.
                    return params_info_header, next_line, clone_err
                }
                break

            } else if read_bytes_err != nil {

                return params_info_header, next_line, ReaderReadByteError{file_name=file_name, reader=reader^}

            } else {

                len_line := len(raw_line)-2
                if count_line == 0 {
                    append(&read_lines, raw_line[:len_line])
                } else {
                    append(&read_lines, raw_line[:len_line])
                }

                count_line += 1

            }
        }
    }

    { // assign all the read lines to `CurveInformation` struct

        count:i32 = 0
        items     := make([dynamic]HeaderItem, 0, allocator=allocator)
        for item in read_lines {
            if !strings.has_prefix(item, "#") && !strings.has_prefix(item, "~") {
                header_item : HeaderItem
                mnemonic, unit, raw_value, descr, _ := parse_las_line(item)

                // NOTE: Check if the strings should be a numeric value or
                // just a plain ahh string.
                value: ItemValues
                if strings.contains_any(raw_value, "-0123456789") {
                    value = strconv.atof(raw_value)
                } else {
                    value = raw_value
                }

                header_item.mnemonic = mnemonic
                header_item.unit     = unit
                header_item.value    = value
                header_item.descr    = descr

                append(&items, header_item)
                count += 1

            } else {

                continue

            }
        }
        params_info_header.len = count
        params_info_header.params = items[:]
    }

    return params_info_header, next_line, nil
}

parse_other_info :: proc(file_name: string, reader: ^bufio.Reader, prev_line: string, allocator := context.allocator) -> (
    others_info_header: OtherInformation,
    next_line:          string,
    err:                ReadFileError,
) {

    if !strings.contains(prev_line, "~O") {
        fmt.printfln("Previous line: %v", prev_line)
        return others_info_header, next_line, ParseHeaderError{
            file_name=file_name,
            line=prev_line,
            message="Line is not a valid OTHERS INFORMATION section, cannot proceed to parse",
        }
    }

    read_lines    := make([dynamic]string, 0, allocator=context.allocator)

    count_section := 1
    count_line    := 0
    for {

        raw_line, read_bytes_err := bufio.reader_read_string(reader, '\n', allocator=allocator)
        if strings.contains(raw_line, "~") { count_section += 1 }
        if read_bytes_err == os.ERROR_EOF || count_section == 2 {

            clone_err : mem.Allocator_Error
            next_line, clone_err = strings.clone(raw_line)
            if clone_err != nil {
                // TODO: (Kelrey) do better error propagation with more intuitive
                // error message.
                return others_info_header, next_line, clone_err
            }
            break

        } else if read_bytes_err != nil {

            return others_info_header, next_line, ReaderReadByteError{file_name=file_name, reader=reader^}

        } else {


            len_line := len(raw_line)-2
            if count_line == 0 {
                append(&read_lines, raw_line[:len_line])
            } else {
                append(&read_lines, raw_line[:len_line])
            }

            count_line += 1

        }

    }

    { // assign all the read lines to `OtherInformation` struct

        count:i32 = 0
        items     := make([dynamic]string, 0, allocator=allocator)
        for item in read_lines {
            if !strings.has_prefix(item, "#") {

                append(&items, item)
                count += 1

            } else {

                continue

            }
        }
        others_info_header.len  = count
        others_info_header.info = items[:]
    }

    return others_info_header, next_line, nil
}

parse_ascii_log_info :: proc(
    file_name:      string,
    reader:         ^bufio.Reader,
    prev_line:      string,
    version_header: Version,
    well_info:      WellInformation,
    curve_header:   CurveInformation,
    allocator:=     context.allocator) -> (

    ascii_data:     LogData,
    next_line:      string,
    err:            ReadFileError,

) {

    ascii_data.wrap = version_header.wrap.value.(bool)
    // if ascii_data.wrap {
    //     return ascii_data, next_line, ParseHeaderError{
    //         file_name=file_name,
    //         line=prev_line,
    //         message="Wraped format is not currently supported, on Dev :D tho"
    //     }
    // }

    if !strings.has_prefix(prev_line, "~A") {
        return ascii_data, next_line, ParseHeaderError{
            file_name=file_name,
            line=prev_line,
            message="Line is not a valid ASCII LOG DATA section, cannot proceed to parse",
        }
    }

    read_lines    := make([dynamic]string, 0, allocator=context.allocator)
    defer delete(read_lines)

    count_section := 1
    count_line    := 0
    for {

        raw_line, read_bytes_err := bufio.reader_read_string(reader, '\n', allocator=allocator)
        if read_bytes_err == os.ERROR_EOF {
            break

        } else if read_bytes_err != nil {

            return ascii_data, next_line, ReaderReadByteError{file_name=file_name, reader=reader^}

        } else {

            if strings.contains(raw_line, "~") { count_section += 1 }

            len_line := len(raw_line)-1
            if count_line == 0 {
                append(&read_lines, raw_line[:len_line])
            } else {
                append(&read_lines, raw_line[:len_line])
            }

            count_line += 1
        }

    }

    n_curve_int:       = cast(int)curve_header.len
    // n_curve_non_first := n_curve_int-1
    ascii_data.ncurves = curve_header.len

    { // assign all the read lines to `LogData` struct

        count:i32 = 0
        items     := make_map(map[int][]f64, allocator=allocator)
        container := make([][dynamic]f64, n_curve_int, allocator=allocator)

        if !ascii_data.wrap { // if it is not a wrapped version
            for item in read_lines {
                if strings.has_prefix(item, "#") do continue

                datum_points := parse_datum_points(item)
                // fmt.printfln("Datum points %v", datum_points)

                for curve_idx in 0..<n_curve_int {
                    point := strconv.atof(datum_points[curve_idx])
                    if point == well_info.null.value {
                        append(&(container[curve_idx]), math.nan_f64())
                    } else {
                        append(&(container[curve_idx]), point)
                    }
                }

                count += 1
                // fmt.printfln("Length container: %v", len(container))
            }

        } else { // it is a wrapped version

            point:      f64
            is_first:   bool

            inner_count: = 1

            for item in read_lines {

                datum_points     := parse_datum_points(item)
                sub_curve_length := len(datum_points)

                // setting the flag
                if sub_curve_length == 1 {

                    is_first    = true
                    point = strconv.atof(datum_points[0])
                    append(&container[0], point)
                    count += 1

                } else {

                    is_first          = false
                    sub_curve_idx    := 0

                    for curve_idx in sub_curve_idx..<sub_curve_length {

                        point = strconv.atof(datum_points[curve_idx])

                        if point == well_info.null.value {

                            append(&(container[curve_idx+inner_count]), math.nan_f64())
                            // fmt.printfln("IDX: %v --> nan point: %v", curve_idx, point)

                        } else {

                            append(&(container[curve_idx+inner_count]), point)
                            // fmt.printfln("IDX: %v --> point: %v", curve_idx, point)


                        }
                    }

                }

                if !is_first { inner_count += sub_curve_length }
                else         { inner_count  = 1 }
                // fmt.printfln("LINE: %v", item)

            }

        }

        for idx in 0..<n_curve_int {
            // curve_name := curve_header.curves[idx].mnemonic
            // fmt.printfln("Curve name: %v | %v", curve_name, container[idx][:5])
            items[idx] = container[idx][:]
        }

        ascii_data.nrows = count
        ascii_data.logs  = items

    }


    return ascii_data, next_line, nil
}

parse_datum_points_no_wrapped :: proc(ascii_log_line: string) -> []string {
    raw_datum_points := strings.split(ascii_log_line, " ")
    datum_points:= make([dynamic]string)

    for datum in raw_datum_points {
        if datum != "" {
            append(&datum_points, datum)
        }
    }

    return datum_points[:]
}

parse_datum_points_wrapped :: proc(ascii_log_line: string, n_curve_int: int) -> []string {
    raw_datum_points := strings.split_n(ascii_log_line, " ", n_curve_int)
    datum_points:= make([dynamic]string)

    for datum in raw_datum_points {
        if datum != "" {
            append(&datum_points, datum)
        } else {
            append(&datum_points, "")
        }
    }

    return datum_points[:]
}

parse_datum_points :: proc {
    parse_datum_points_no_wrapped,
    parse_datum_points_wrapped,
}

