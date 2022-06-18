const std = @import("std");
const ray = @import("ray.zig");
const camera = @import("camera.zig");
const Config = @import("Config.zig");
const sphere = @import("sphere.zig");
const Vector = @import("Vector.zig");
const material = @import("material.zig");

pub const Hit = struct {
    ray_scale_factor: f64 = std.math.f64_max,
    object_idx: ?usize = undefined,
};

pub const Scene = struct {
    objects: std.ArrayList(sphere.Sphere),
    lights: std.ArrayList(usize),
    camera: *camera.Camera,

    pub fn intersect(self: *Scene, cur_ray: ray.Ray) Hit {
        var hit = Hit{};
        var ray_scale_factor: f64 = undefined;
        for (self.objects.items) |cur_sphere, idx| {
            ray_scale_factor = cur_sphere.computeRaySphereHit(cur_ray);
            if (ray_scale_factor > 0.0 and ray_scale_factor < hit.ray_scale_factor) {
                hit.ray_scale_factor = ray_scale_factor;
                hit.object_idx = idx;
            }
        }
        return hit;
    }

    pub fn collectLights(self: *Scene) !void {
        for (self.objects.items) |object, light_idx| {
            if (object.isLight()) {
                try self.lights.append(light_idx);
            }
        }
    }
};

pub fn sampleLights(scene: *Scene, hit_point: Vector.Vec3, normal: Vector.Vec3, ray_direction: Vector.Vec3, cur_material: *const material.Material) Vector.Vec3 {
    var color = Vector.ZERO_VECTOR;
    for (scene.lights.items) |light_idx| {
        const light = scene.objects.items[light_idx];
        var hit_point_to_light_center = light.center - hit_point;
        const distance_to_light_sqrd = Vector.dotProduct(hit_point_to_light_center, hit_point_to_light_center);
        hit_point_to_light_center = Vector.normalize(hit_point_to_light_center);
        var cos_theta = Vector.dotProduct(normal, hit_point_to_light_center);
        var shadow_ray = ray.Ray{ .origin = hit_point, .direction = hit_point_to_light_center };
        var shadow_ray_hit = scene.intersect(shadow_ray);
        if (shadow_ray_hit.object_idx) |shadow_idx| {
            if (shadow_idx == light_idx) {
                if (cos_theta > 0.0) {
                    const sin_alpha_max_sqrd = light.radius * light.radius / distance_to_light_sqrd;
                    const cos_alpha_max = @sqrt(1.0 - sin_alpha_max_sqrd);
                    const omega = 2.0 * (1.0 - cos_alpha_max);
                    cos_theta *= omega;
                    color += cur_material.diffuse * light.material.emissive * @splat(Config.SCENE_DIMS, cos_theta);
                }
                if (cur_material.material_type == material.MaterialType.GLOSSY or cur_material.material_type == material.MaterialType.MIRROR) {
                    const reflected_direction = Vector.reflect(hit_point_to_light_center, normal);
                    cos_theta = -Vector.dotProduct(reflected_direction, ray_direction);
                    if (cos_theta > 0.0) {
                        const specular_color = cur_material.specular * @splat(Config.SCENE_DIMS, std.math.pow(f64, cos_theta, cur_material.specular_exponent));
                        color += specular_color;
                    }
                }
            }
        }
    }
    return color;
}
