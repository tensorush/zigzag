const std = @import("std");
const ray = @import("ray.zig");
const vector = @import("vector.zig");

pub const MaterialType = enum { DIFFUSE, GLOSSY, MIRROR };

pub const Material = struct {
    material_type: MaterialType = MaterialType.DIFFUSE,
    specular: vector.Vec4 = vector.ZERO_VECTOR,
    emissive: vector.Vec4 = vector.ZERO_VECTOR,
    diffuse: vector.Vec4 = vector.ZERO_VECTOR,
    specular_exponent: f64 = 0.0,
};

pub fn interreflectSpecular(normal: vector.Vec4, hit_point: vector.Vec4, x_sphere_sample: f64, y_sphere_sample: f64, specular_exponent: f64, cur_ray: ray.Ray) ray.Ray {
    const view_direction = -cur_ray.direction;
    const reflected_direction = vector.normalize(vector.reflect(view_direction, normal));
    const basis = vector.buildBasis(reflected_direction);
    const sampled_direction = sampleHemisphereSpecular(x_sphere_sample, y_sphere_sample, specular_exponent);
    return .{ .direction = vector.transformIntoBasis(sampled_direction, basis.axis2, basis.axis3, reflected_direction), .origin = hit_point };
}

pub fn interreflectDiffuse(normal: vector.Vec4, hit_point: vector.Vec4, x_sphere_sample: f64, y_sphere_sample: f64) ray.Ray {
    const basis = vector.buildBasis(normal);
    const sampled_direction = sampleHemisphereDiffuse(x_sphere_sample, y_sphere_sample);
    return .{ .direction = vector.transformIntoBasis(sampled_direction, basis.axis2, basis.axis3, normal), .origin = hit_point };
}

pub fn sampleHemisphereSpecular(x_sphere_sample: f64, y_sphere_sample: f64, specular_exponent: f64) vector.Vec4 {
    const phi = 2.0 * std.math.pi * x_sphere_sample;
    const cos_theta = std.math.pow(f64, 1.0 - y_sphere_sample, 1.0 / (specular_exponent + 1.0));
    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
    return .{ @cos(phi) * sin_theta, @sin(phi) * sin_theta, cos_theta, 0.0 };
}

pub fn sampleHemisphereDiffuse(x_sphere_sample: f64, y_sphere_sample: f64) vector.Vec4 {
    const radius = @sqrt(y_sphere_sample);
    const phi = 2.0 * std.math.pi * x_sphere_sample;
    return .{ @cos(phi) * radius, @sin(phi) * radius, @sqrt(1.0 - radius * radius), 0.0 };
}
