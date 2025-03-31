package petrophysics

import intrc "base:intrinsics"
import ls "../lasio"

_::ls


calculate_shale_volume_array_floats :: proc(
    gamma_ray:     []$T,
    gamma_ray_max: T,
    gamma_ray_min: T,
    allocator := context.allocator) -> (shale_volume: []T) where intrc.type_is_float(T) {

    shale := make([dynamic]T, 0, 0, allocator=allocator)

    for gamma in gamma_ray {
        v_shale := ((gamma - gama_ray_min) / (gama_ray_max - gama_ray_min))
        append(&shale, v_shale)
    }

    shale_volume = shale[:]
    return shale_volume
}

calculate_shale_volume_log_data :: proc(
    log_data:      ^ls.LogData,
    gamma_ray_idx: int,
    gamma_ray_max: $T,
    gamma_ray_min: T,
    allocator := context.allocator) -> (shale_volume: []T) where intrc.type_is_float(T) {

    shale := make([dynamic]T, 0, 0, allocator=allocator)

    for gamma in &log_data[gamma_ray_idx] {
        v_shale := ((gamma - gama_ray_min) / (gama_ray_max - gama_ray_min))
        append(&shale, v_shale)
    }

    shale_volume = shale[:]
    return shale_volume
}

// Shale Volume Function
calculate_shale_volume :: proc {
    calculate_shale_volume_log_data,
    calculate_shale_volume_array_floats,
}

calculate_density_porosity_array_floats :: proc(
    rho:     []$T,
    matrix_density: T,
    fluid_density: T,
    allocator := context.allocator) -> (density_porosity: []T) where intrc.type_is_float(T) {

    rho := make([dynamic]T, 0, 0, allocator=allocator)

    for density in rho {
        v_rho_por := ((density - fluid_density) / (matrix_density - fluid_density))
        append(&rho, v_rho_por)
    }

    density_porosity = rho[:]
    return density_porosity
}

calculate_density_porosity_log_data :: proc(
    log_data:      ^ls.LogData,
    rho_por_idx: int,
    matrix_density: $T,
    fluid_density: T,
    allocator := context.allocator) -> (density_porosity: []T) where intrc.type_is_float(T) {

    rho_por := make([dynamic]T, 0, 0, allocator=allocator)

    for density in log_data[rho_por_idx] {
        v_rho_por := ((density - fluid_density) / (matrix_density - fluid_density))
        append(&rho, v_rho_por)
    }

    density_porosity = rho_por[:]
    return density_porosity
}

// Density Porosity Function
calculate_density_porosity :: proc {
    calculate_density_porosity_log_data,
    calculate_density_porosity_array_floats,
}




calculate_water_saturation_array_floats :: proc(
    rho:     []$T,
    matrix_density: T,
    fluid_density: T,
    allocator := context.allocator) -> (density_porosity: []T) where intrc.type_is_float(T) {

    rho := make([dynamic]T, 0, 0, allocator=allocator)

    for density in rho {
        v_rho_por := ((density - fluid_density) / (matrix_density - fluid_density))
        append(&rho, v_rho_por)
    }

    density_porosity = rho[:]
    return density_porosity
}

// Water Saturation Function
