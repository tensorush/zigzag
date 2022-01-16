const std = @import("std");
const ray = @import("ray.zig");
const camera = @import("camera.zig");
const config = @import("config.zig");
const sphere = @import("sphere.zig");
const vector = @import("vector.zig");
const material = @import("material.zig");

const Vec3 = config.Vec3;

pub const IntersectResult = struct {
    objectIndex: ?usize = undefined,
    t: f64 = std.math.f64_max,
};

pub const Scene = struct {
    objects: std.ArrayList(sphere.Sphere),
    lights: std.ArrayList(usize),
    camera: *camera.Camera,

    pub fn intersect(self: *Scene, cur_ray: ray.Ray) IntersectResult {
        var result: IntersectResult = .{};
        for (self.objects.items) |cur_sphere, index| {
            const t = cur_sphere.intersects(cur_ray);
            if (t > 0.0 and t < result.t) {
                result.t = t;
                result.objectIndex = index;
            }
        }
        return result;
    }

    pub fn collect_lights(self: *Scene) !void {
        for (self.objects.items) |obj, light_index| {
            if (obj.is_light()) {
                try self.lights.append(light_index);
            }
        }
    }
};

pub fn sample_lights(scene: *Scene, intersection: Vec3, normal: Vec3, ray_dir: Vec3, cur_material: *const material.Material) Vec3 {
    var color = config.ZERO_VECTOR;
    for (scene.lights.items) |light_index| {
        const light = scene.objects.items[light_index];
        var l = light.center - intersection;
        const light_dist_sqr = vector.dot_product(l, l);
        l = vector.normalize(l);
        var d = vector.dot_product(normal, l);
        var shadow_ray = ray.Ray{ .origin = intersection, .dir = l };
        var shadow_result = scene.intersect(shadow_ray);
        if (shadow_result.objectIndex) |shadow_index| {
            if (shadow_index == light_index) {
                if (d > 0.0) {
                    const sin_alpha_max_sqr = light.radius_squared / light_dist_sqr;
                    const cos_alpha_max = @sqrt(1.0 - sin_alpha_max_sqr);
                    const omega = 2.0 * (1.0 - cos_alpha_max);
                    d *= omega;
                    const c = cur_material.diffuse * light.material.emissive;
                    color += c * @splat(config.NUM_DIMS, d);
                }
                if (cur_material.material_type == material.MaterialType.GLOSSY or cur_material.material_type == material.MaterialType.MIRROR) {
                    const reflected = vector.reflect(l, normal);
                    d = -vector.dot_product(reflected, ray_dir);
                    if (d > 0.0) {
                        const smul = @splat(config.NUM_DIMS, std.math.pow(f64, d, cur_material.exp));
                        const spec_color = cur_material.specular * smul;
                        color += spec_color;
                    }
                }
            }
        }
    }
    return color;
}
