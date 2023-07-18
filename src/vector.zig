const std = @import("std");
const config = @import("config.zig");

pub const Vec4 = @Vector(config.VECTOR_LEN, f64);

pub const ZERO_VECTOR: Vec4 = @splat(0.0);
pub const IDENTITY_VECTOR: Vec4 = @splat(1.0);
pub const INVERSE_ANTI_ALIASING_FACTOR: Vec4 = @splat(1.0 / @as(f64, @floatFromInt(config.ANTI_ALIASING_FACTOR)));

pub const Basis = struct {
    axis2: Vec4,
    axis3: Vec4,
};

pub fn buildBasis(u: Vec4) Basis {
    var v: Vec4 = undefined;
    if (@fabs(u[0]) > @fabs(u[1])) {
        const len = 1.0 / @sqrt(u[0] * u[0] + u[2] * u[2]);
        v = .{ -u[2] * len, 0.0, u[0] * len, 0.0 };
    } else {
        const len = 1.0 / @sqrt(u[1] * u[1] + u[2] * u[2]);
        v = .{ 0.0, u[2] * len, -u[1] * len, 0.0 };
    }
    return .{ .axis2 = v, .axis3 = crossProduct(u, v) };
}

pub fn transformIntoBasis(u_in: Vec4, u_x: Vec4, u_y: Vec4, u_z: Vec4) Vec4 {
    var v_x = u_x;
    v_x *= @splat(u_in[0]);
    var v_y = u_y;
    v_y *= @splat(u_in[1]);
    var v_z = u_z;
    v_z *= @splat(u_in[2]);
    return v_x + v_y + v_z;
}

pub fn createUnitVector(x: f64, y: f64, z: f64) Vec4 {
    const len_sq = x * x + y * y + z * z;
    return if (len_sq > std.math.floatEps(f64)) Vec4{ x, y, z, 0.0 } / @as(Vec4, @splat(@sqrt(len_sq))) else .{ x, y, z, 0.0 };
}

pub fn normalize(u: Vec4) Vec4 {
    const len_sq = dotProduct(u, u);
    return if (len_sq > std.math.floatEps(f64)) u * @as(Vec4, @splat(1.0 / @sqrt(len_sq))) else u;
}

pub fn reflect(direction: Vec4, normal: Vec4) Vec4 {
    return normal * @as(Vec4, @splat(dotProduct(direction, normal) * @as(f64, config.NUM_SCREEN_DIMS))) - direction;
}

pub fn crossProduct(u: Vec4, v: Vec4) Vec4 {
    return .{ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0], 0.0 };
}

pub fn dotProduct(u: Vec4, v: Vec4) f64 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

pub fn getMaxComponent(u: Vec4) f64 {
    return @max(u[0], u[1], u[2]);
}
