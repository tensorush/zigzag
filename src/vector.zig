const std = @import("std");
const config = @import("config.zig");

const Vec3 = config.Vec3;

pub fn dot_product(u: Vec3, v: Vec3) f64 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

pub fn cross_product(u: Vec3, v: Vec3) Vec3 {
    return .{ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0] };
}

pub fn getMaxComponent(u: Vec3) f64 {
    return std.math.max(std.math.max(u[0], u[1]), u[2]);
}

pub fn reflect(direction: Vec3, normal: Vec3) Vec3 {
    return normal * @splat(config.SCENE_DIMS, dot_product(direction, normal) * @as(f64, config.SCREEN_DIMS)) - direction;
}

pub fn normalize(u: Vec3) Vec3 {
    const len_sqrd = dot_product(u, u);
    return if (len_sqrd > std.math.f64_epsilon) u * @splat(config.SCENE_DIMS, 1.0 / @sqrt(len_sqrd)) else u;
}

pub fn transformIntoBasis(u_in: Vec3, u_x: Vec3, u_y: Vec3, u_z: Vec3) Vec3 {
    return (u_x * @splat(config.SCENE_DIMS, u_in[0]) + u_y * @splat(config.SCENE_DIMS, u_in[1]) + u_z * @splat(config.SCENE_DIMS, u_in[2]));
}

pub fn create_unit_vector(x: f64, y: f64, z: f64) Vec3 {
    const len_sqrd = x * x + y * y + z * z;
    return if (len_sqrd > std.math.f64_epsilon) Vec3{ x, y, z } / @splat(config.SCENE_DIMS, @sqrt(len_sqrd)) else .{ x, y, z };
}

pub const Basis = struct {
    axis_2: Vec3,
    axis_3: Vec3,
};

pub fn buildBasis(u_1: Vec3) Basis {
    var u_2: Vec3 = undefined;
    if (@fabs(u_1[0]) > @fabs(u_1[1])) {
        const len = 1.0 / @sqrt(u_1[0] * u_1[0] + u_1[2] * u_1[2]);
        u_2 = .{ -u_1[2] * len, 0.0, u_1[0] * len };
    } else {
        const len = 1.0 / @sqrt(u_1[1] * u_1[1] + u_1[2] * u_1[2]);
        u_2 = .{ 0.0, u_1[2] * len, -u_1[1] * len };
    }
    return .{ .axis_2 = u_2, .axis_3 = cross_product(u_1, u_2) };
}
