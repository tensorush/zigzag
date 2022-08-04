const std = @import("std");
const config = @import("config.zig");

pub const ZERO_VECTOR = @splat(config.VECTOR_LEN, @as(f64, 0.0));
pub const IDENTITY_VECTOR = @splat(config.VECTOR_LEN, @as(f64, 1.0));
pub const INVERSE_ANTI_ALIASING_FACTOR = @splat(config.VECTOR_LEN, 1.0 / @as(f64, config.ANTI_ALIASING_FACTOR));

pub const Vec4 = std.meta.Vector(config.VECTOR_LEN, f64);

pub const Basis = struct {
    axis2: Vec4,
    axis3: Vec4,
};

pub fn buildBasis(u: Vec4) Basis {
    var v: Vec4 = undefined;
    if (@fabs(u[0]) > @fabs(u[1])) {
        const len = 1.0 / @sqrt(u[0] * u[0] + u[2] * u[2]);
        v = .{ -u[2] * len, 0.0, u[0] * len };
    } else {
        const len = 1.0 / @sqrt(u[1] * u[1] + u[2] * u[2]);
        v = .{ 0.0, u[2] * len, -u[1] * len };
    }
    return .{ .axis2 = v, .axis3 = crossProduct(u, v) };
}

pub fn transformIntoBasis(u_in: Vec4, u_x: Vec4, u_y: Vec4, u_z: Vec4) Vec4 {
    return (u_x * @splat(config.VECTOR_LEN, u_in[0]) + u_y * @splat(config.VECTOR_LEN, u_in[1]) + u_z * @splat(config.VECTOR_LEN, u_in[2]));
}

pub fn createUnitVector(x: f64, y: f64, z: f64) Vec4 {
    const len_sqrd = x * x + y * y + z * z;
    return if (len_sqrd > std.math.f64_epsilon) Vec4{ x, y, z } / @splat(config.VECTOR_LEN, @sqrt(len_sqrd)) else .{ x, y, z };
}

pub fn normalize(u: Vec4) Vec4 {
    const len_sqrd = dotProduct(u, u);
    return if (len_sqrd > std.math.f64_epsilon) u * @splat(config.VECTOR_LEN, 1.0 / @sqrt(len_sqrd)) else u;
}

pub fn reflect(direction: Vec4, normal: Vec4) Vec4 {
    return normal * @splat(config.VECTOR_LEN, dotProduct(direction, normal) * @as(f64, config.NUM_SCREEN_DIMS)) - direction;
}
pub fn crossProduct(u: Vec4, v: Vec4) Vec4 {
    return .{ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0] };
}

pub fn dotProduct(u: Vec4, v: Vec4) f64 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

pub fn getMaxComponent(u: Vec4) f64 {
    return std.math.max3(u[0], u[1], u[2]);
}
