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
    specular_exponent: f64 = 0.0,
    diffuse: Vec3 = config.ZERO_VECTOR,
    emissive: Vec3 = config.ZERO_VECTOR,
    specular: Vec3 = config.ZERO_VECTOR,
};

pub fn sampleHemisphereDiffuse(x_sphere_sample: f64, y_sphere_sample: f64) Vec3 {
    const r = @sqrt(y_sphere_sample);
    const phi = 2.0 * std.math.pi * x_sphere_sample;
    return .{ @cos(phi) * r, @sin(phi) * r, @sqrt(1.0 - r * r) };
}

pub fn sampleHemisphereSpecular(x_sphere_sample: f64, y_sphere_sample: f64, specular_exponent: f64) Vec3 {
    const phi = 2.0 * std.math.pi * x_sphere_sample;
    const cos_theta = std.math.pow(f64, 1.0 - y_sphere_sample, 1.0 / (specular_exponent + 1.0));
    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
    return .{ @cos(phi) * sin_theta, @sin(phi) * sin_theta, cos_theta };
}

pub fn interreflectDiffuse(normal: Vec3, hit_point: Vec3, x_sphere_sample: f64, y_sphere_sample: f64) ray.Ray {
    const basis = vector.buildBasis(normal);
    const sampled_direction = sampleHemisphereDiffuse(x_sphere_sample, y_sphere_sample);
    return .{ .origin = hit_point, .direction = vector.transformIntoBasis(sampled_direction, basis.axis_2, basis.axis_3, normal) };
}

pub fn interreflectSpecular(normal: Vec3, hit_point: Vec3, x_sphere_sample: f64, y_sphere_sample: f64, specular_exponent: f64, cur_ray: ray.Ray) ray.Ray {
    const view_direction = -cur_ray.direction;
    const reflected_direction = vector.normalize(vector.reflect(view_direction, normal));
    const basis = vector.buildBasis(reflected_direction);
    const sampled_direction = sampleHemisphereSpecular(x_sphere_sample, y_sphere_sample, specular_exponent);
    return .{ .origin = hit_point, .direction = vector.transformIntoBasis(sampled_direction, basis.axis_2, basis.axis_3, reflected_direction) };
}
