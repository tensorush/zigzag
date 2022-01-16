const std = @import("std");
const ray = @import("ray.zig");
const config = @import("config.zig");
const vector = @import("vector.zig");

const Vec3 = config.Vec3;

pub const MaterialType = enum {
    DIFFUSE,
    GLOSSY,
    MIRROR,
};

pub const Material = struct {
    material_type: MaterialType = MaterialType.DIFFUSE,
    diffuse: Vec3 = config.ZERO_VECTOR,
    emissive: Vec3 = config.ZERO_VECTOR,
    specular: Vec3 = config.ZERO_VECTOR,
    exp: f64 = 0.0,
};

pub fn sample_hemisphere_cosine(uu1: f64, uu2: f64) Vec3 {
    const phi = 2.0 * std.math.pi * uu1;
    const r = @sqrt(uu2);
    const s = @sin(phi);
    const c = @cos(phi);
    return .{ c * r, s * r, @sqrt(1.0 - r * r) };
}

pub fn sample_hemisphere_specular(uu1: f64, uu2: f64, exp: f64) Vec3 {
    const phi = 2.0 * std.math.pi * uu1;
    const cos_theta = std.math.pow(f64, 1.0 - uu2, 1.0 / (exp + 1.0));
    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
    return .{ @cos(phi) * sin_theta, @sin(phi) * sin_theta, cos_theta };
}

pub fn interreflect_diffuse(normal: Vec3, intersection_point: Vec3, uu1: f64, uu2: f64) ray.Ray {
    const v2v3 = vector.build_basis(normal);
    const sampled_dir = sample_hemisphere_cosine(uu1, uu2);
    return .{ .origin = intersection_point, .dir = vector.transform_to_basis(sampled_dir, v2v3.a, v2v3.b, normal) };
}

pub fn interreflect_specular(normal: Vec3, intersection_point: Vec3, uu1: f64, uu2: f64, exp: f64, cur_ray: ray.Ray) ray.Ray {
    const view = -cur_ray.dir;
    const reflected = vector.normalize(vector.reflect(view, normal));
    const v2v3 = vector.build_basis(reflected);
    const sampled_dir = sample_hemisphere_specular(uu1, uu2, exp);
    return .{ .origin = intersection_point, .dir = vector.transform_to_basis(sampled_dir, v2v3.a, v2v3.b, reflected) };
}
