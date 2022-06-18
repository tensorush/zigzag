const std = @import("std");
const Config = @import("Config.zig");

pub const ZERO_VECTOR = @splat(Config.SCENE_DIMS, @as(f64, 0.0));
pub const IDENTITY_VECTOR = @splat(Config.SCENE_DIMS, @as(f64, 1.0));
pub const INVERSE_ANTI_ALIASING_FACTOR = @splat(Config.SCENE_DIMS, 1.0 / @as(f64, Config.ANTI_ALIASING_FACTOR));

pub const Vec3 = std.meta.Vector(Config.SCENE_DIMS, f64);

pub fn dotProduct(u: Vec3, v: Vec3) f64 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

pub fn crossProduct(u: Vec3, v: Vec3) Vec3 {
    return .{ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0] };
}

pub fn getMaxComponent(u: Vec3) f64 {
    return std.math.max(std.math.max(u[0], u[1]), u[2]);
}

pub fn reflect(direction: Vec3, normal: Vec3) Vec3 {
    return normal * @splat(Config.SCENE_DIMS, dotProduct(direction, normal) * @as(f64, Config.SCREEN_DIMS)) - direction;
}

pub fn normalize(u: Vec3) Vec3 {
    const len_sqrd = dotProduct(u, u);
    return if (len_sqrd > std.math.f64_epsilon) u * @splat(Config.SCENE_DIMS, 1.0 / @sqrt(len_sqrd)) else u;
}

pub fn transformIntoBasis(u_in: Vec3, u_x: Vec3, u_y: Vec3, u_z: Vec3) Vec3 {
    return (u_x * @splat(Config.SCENE_DIMS, u_in[0]) + u_y * @splat(Config.SCENE_DIMS, u_in[1]) + u_z * @splat(Config.SCENE_DIMS, u_in[2]));
}

pub fn createUnitVector(x: f64, y: f64, z: f64) Vec3 {
    const len_sqrd = x * x + y * y + z * z;
    return if (len_sqrd > std.math.f64_epsilon) Vec3{ x, y, z } / @splat(Config.SCENE_DIMS, @sqrt(len_sqrd)) else .{ x, y, z };
}

pub const Basis = struct {
    axis2: Vec3,
    axis3: Vec3,
};

pub fn buildBasis(u: Vec3) Basis {
    var v: Vec3 = undefined;
    if (@fabs(u[0]) > @fabs(u[1])) {
        const len = 1.0 / @sqrt(u[0] * u[0] + u[2] * u[2]);
        v = .{ -u[2] * len, 0.0, u[0] * len };
    } else {
        const len = 1.0 / @sqrt(u[1] * u[1] + u[2] * u[2]);
        v = .{ 0.0, u[2] * len, -u[1] * len };
    }
    return .{ .axis2 = v, .axis3 = crossProduct(u, v) };
}
