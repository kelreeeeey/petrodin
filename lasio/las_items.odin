package lasio

HeaderItem :: struct #packed {
    mnemonic:          string,
    unit:              ItemValues,
    value:             ItemValues,
    descr:             ItemValues,
}

ItemValues :: union {
    string,
    f64,
    i64,
    bool,
}

// Sections
Version :: struct #packed {
    vers: HeaderItem,
    wrap: HeaderItem,
    add:  []HeaderItem
}

WellInformation :: struct #packed {
    start: HeaderItem,
    stop:  HeaderItem,
    step:  HeaderItem,
    null:  HeaderItem,
    comp:  HeaderItem,
    well:  HeaderItem,
    fld:   HeaderItem,
    loc:   HeaderItem,
    prov:  HeaderItem,
    cnty:  HeaderItem,
    stat:  HeaderItem,
    ctry:  HeaderItem,
    srvc:  HeaderItem,
    date:  HeaderItem,
    uwi:   HeaderItem,
    api:   HeaderItem,
    lic:   HeaderItem,
}

// Curves
CurveInformation :: struct #packed {
    len:    i32,
    curves: []HeaderItem
}

delete_curve_info :: proc(curve_info: CurveInformation) {
	delete(curve_info.curves)
}

// Parameter informations, non-mandatory
ParameterInformation :: struct {
    len:    i32,
    params: []HeaderItem
}

delete_param_info :: proc(param_info: ParameterInformation) {
	delete(param_info.params)
}

// Other informations, non-mandatory
OtherInformation :: struct {
    len:  i32,
    info: []string
}

delete_other_info :: proc(other_info: OtherInformation) {
	delete (other_info.info)
}

// ASCII Log Data, non-mandatory
LogData :: struct {
    wrap:    bool,
    nrows:   i32,
    ncurves: i32,
    logs:    map[string][]f64
}

delete_log_data :: proc(log_data: LogData) {
	delete_map(log_data.logs)
}


// Union of section
SectionType :: union {
    Version,
    WellInformation,
    CurveInformation,
    ParameterInformation,
    OtherInformation,
    LogData,
    []string
}

SectionFlags :: enum {
    V, // version
    W, // well information
    C, // curve information
    P, // parameter information
    O, // other information
    A, // ascii log data
}


// LAS Data
Section :: struct {
    name:  string,
    flag:  SectionFlags,
    items: SectionType
}

LasData :: struct {
    file_name:      string,
    version:        Version,
    well_info:      WellInformation,
    curve_info:     CurveInformation,
    parameter_info: ParameterInformation,
    other_info:     OtherInformation,
    log_data:       LogData
}

delete_las_data :: proc(las_data: LasData) {
	delete(las_data.version.add)
	delete_curve_info(las_data.curve_info)
	delete_other_info(las_data.other_info)
	for curve_name, log in las_data.log_data.logs {
		delete(log)
	}
}
