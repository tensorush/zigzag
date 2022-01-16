const std = @import("std");
const config = @import("config.zig");

const Vec3 = config.Vec3;

pub fn dot_product(u: Vec3, v: Vec3) f64 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

pub fn cross_product(u: Vec3, v: Vec3) Vec3 {
    return .{ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0] };
}

pub fn max_component(u: Vec3) f64 {
    return std.math.max(std.math.max(u[0], u[1]), u[2]);
}

pub fn reflect(dir: Vec3, n: Vec3) Vec3 {
    const h = n * @splat(config.NUM_DIMS, dot_product(dir, n) * 2.0);
    return h - dir;
}

pub fn normalize(u: Vec3) Vec3 {
    const length_squared = dot_product(u, u);
    if (length_squared > std.math.f64_epsilon) {
        const norm_factor = @splat(config.NUM_DIMS, 1.0 / @sqrt(length_squared));
        return u * norm_factor;
    }
    return u;
}

pub fn transform_to_basis(vin: Vec3, vx: Vec3, vy: Vec3, vz: Vec3) Vec3 {
    const sx = @splat(config.NUM_DIMS, vin[0]);
    const sy = @splat(config.NUM_DIMS, vin[1]);
    const sz = @splat(config.NUM_DIMS, vin[2]);
    return (vx * sx + vy * sy + vz * sz);
}

pub fn new_normal(x: f64, y: f64, z: f64) Vec3 {
    const length_squared = x * x + y * y + z * z;
    if (length_squared > std.math.f64_epsilon) {
        const length = @sqrt(length_squared);
        return Vec3{ x, y, z } / @splat(config.NUM_DIMS, length);
    }
    return .{ x, y, z };
}

pub const Axes = struct {
    a: Vec3,
    b: Vec3,
};

pub fn build_basis(v1: Vec3) Axes {
    var v2: Vec3 = undefined;
    if (@fabs(v1[0]) > @fabs(v1[1])) {
        const oo_len = 1.0 / @sqrt(v1[0] * v1[0] + v1[2] * v1[2]);
        v2 = .{ -v1[2] * oo_len, 0.0, v1[0] * oo_len };
    } else {
        const oo_len = 1.0 / @sqrt(v1[1] * v1[1] + v1[2] * v1[2]);
        v2 = .{ 0.0, v1[2] * oo_len, -v1[1] * oo_len };
    }
    return .{ .a = v2, .b = cross_product(v1, v2) };
}
