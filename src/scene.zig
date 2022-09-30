const std = @import("std");
const ray = @import("ray.zig");
const camera = @import("camera.zig");
const config = @import("config.zig");
const sphere = @import("sphere.zig");
const vector = @import("vector.zig");
const material = @import("material.zig");

pub const Scene = struct {
    spheres: std.ArrayList(sphere.Sphere),
    lights: std.ArrayList(usize),
    camera: *camera.Camera,

    pub fn intersect(self: *Scene, cur_ray: ray.Ray) Hit {
        var ray_factor: f64 = undefined;
        var hit = Hit{};
        for (self.spheres.items) |cur_sphere, i| {
            ray_factor = cur_sphere.computeRaySphereHit(cur_ray);
            if (ray_factor > 0.0 and ray_factor < hit.ray_factor) hit = .{ .sphere_idx_opt = i, .ray_factor = ray_factor };
        }
        return hit;
    }

    pub fn collectLights(self: *Scene) std.mem.Allocator.Error!void {
        for (self.spheres.items) |cur_sphere, light_idx| {
            if (cur_sphere.isLight()) try self.lights.append(light_idx);
        }
    }
};

pub const Hit = struct {
    sphere_idx_opt: ?usize = undefined,
    ray_factor: f64 = std.math.f64_max,
};

pub fn sampleLights(scene: *Scene, hit_point: vector.Vec4, normal: vector.Vec4, ray_direction: vector.Vec4, cur_material: *const material.Material) vector.Vec4 {
    var hit_to_light_center: vector.Vec4 = undefined;
    var distance_to_light_sqrd: f64 = undefined;
    var sin_alpha_max_sqrd: f64 = undefined;
    var light: sphere.Sphere = undefined;
    var shadow_ray_hit: Hit = undefined;
    var cos_alpha_max: f64 = undefined;
    var cos_theta: f64 = undefined;
    var color = vector.ZERO_VECTOR;
    var omega: f64 = undefined;
    for (scene.lights.items) |light_idx| {
        light = scene.spheres.items[light_idx];
        hit_to_light_center = light.center - hit_point;
        distance_to_light_sqrd = vector.dotProduct(hit_to_light_center, hit_to_light_center);
        hit_to_light_center = vector.normalize(hit_to_light_center);
        cos_theta = vector.dotProduct(normal, hit_to_light_center);
        shadow_ray_hit = scene.intersect(.{ .direction = hit_to_light_center, .origin = hit_point });
        if (shadow_ray_hit.sphere_idx_opt) |shadow_idx| {
            if (shadow_idx == light_idx) {
                if (cos_theta > 0.0) {
                    sin_alpha_max_sqrd = light.radius * light.radius / distance_to_light_sqrd;
                    cos_alpha_max = @sqrt(1.0 - sin_alpha_max_sqrd);
                    omega = 2.0 * (1.0 - cos_alpha_max);
                    cos_theta *= omega;
                    color += cur_material.diffuse * light.material.emissive * @splat(config.VECTOR_LEN, cos_theta);
                }
                if (cur_material.material_type == material.MaterialType.GLOSSY or cur_material.material_type == material.MaterialType.MIRROR) {
                    cos_theta = -vector.dotProduct(vector.reflect(hit_to_light_center, normal), ray_direction);
                    if (cos_theta > 0.0) color += cur_material.specular * @splat(config.VECTOR_LEN, std.math.pow(f64, cos_theta, cur_material.specular_exponent));
                }
            }
        }
    }
    return color;
}
