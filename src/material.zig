const std = @import("std");
const ray = @import("ray.zig");
const Config = @import("Config.zig");
const Vector = @import("Vector.zig");

pub const MaterialType = enum {
    DIFFUSE,
    GLOSSY,
    MIRROR,
};

pub const Material = struct {
    material_type: MaterialType = MaterialType.DIFFUSE,
    specular: Vector.Vec3 = Vector.ZERO_VECTOR,
    emissive: Vector.Vec3 = Vector.ZERO_VECTOR,
    diffuse: Vector.Vec3 = Vector.ZERO_VECTOR,
    specular_exponent: f64 = 0.0,
};

pub fn sampleHemisphereDiffuse(x_sphere_sample: f64, y_sphere_sample: f64) Vector.Vec3 {
    const r = @sqrt(y_sphere_sample);
    const phi = 2.0 * std.math.pi * x_sphere_sample;
    return .{ @cos(phi) * r, @sin(phi) * r, @sqrt(1.0 - r * r) };
}

pub fn sampleHemisphereSpecular(x_sphere_sample: f64, y_sphere_sample: f64, specular_exponent: f64) Vector.Vec3 {
    const phi = 2.0 * std.math.pi * x_sphere_sample;
    const cos_theta = std.math.pow(f64, 1.0 - y_sphere_sample, 1.0 / (specular_exponent + 1.0));
    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
    return .{ @cos(phi) * sin_theta, @sin(phi) * sin_theta, cos_theta };
}

pub fn interreflectDiffuse(normal: Vector.Vec3, hit_point: Vector.Vec3, x_sphere_sample: f64, y_sphere_sample: f64) ray.Ray {
    const basis = Vector.buildBasis(normal);
    const sampled_direction = sampleHemisphereDiffuse(x_sphere_sample, y_sphere_sample);
    return .{ .origin = hit_point, .direction = Vector.transformIntoBasis(sampled_direction, basis.axis2, basis.axis3, normal) };
}

pub fn interreflectSpecular(normal: Vector.Vec3, hit_point: Vector.Vec3, x_sphere_sample: f64, y_sphere_sample: f64, specular_exponent: f64, cur_ray: ray.Ray) ray.Ray {
    const view_direction = -cur_ray.direction;
    const reflected_direction = Vector.normalize(Vector.reflect(view_direction, normal));
    const basis = Vector.buildBasis(reflected_direction);
    const sampled_direction = sampleHemisphereSpecular(x_sphere_sample, y_sphere_sample, specular_exponent);
    return .{ .origin = hit_point, .direction = Vector.transformIntoBasis(sampled_direction, basis.axis2, basis.axis3, reflected_direction) };
}
