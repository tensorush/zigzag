const std = @import("std");
const ray = @import("ray.zig");
const scene = @import("scene.zig");
const camera = @import("camera.zig");
const config = @import("config.zig");
const sphere = @import("sphere.zig");
const vector = @import("vector.zig");
const material = @import("material.zig");

const Vec3 = config.Vec3;

pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub fn computeHitPoint(self: Ray, ray_scale_factor: f64) Vec3 {
        return self.origin + self.direction * @splat(config.SCENE_DIMS, ray_scale_factor);
    }
};

pub fn tracePath(cur_ray: Ray, cur_scene: *scene.Scene, x_sphere_sample: f64, y_sphere_sample: f64, samples: [config.SAMPLES_PER_PIXEL * config.SCREEN_DIMS]f64, rng: *std.rand.Random) Vec3 {
    var is_direct = true;
    var bounce: usize = 0;
    var traced_ray = cur_ray;
    var ray_color = config.ZERO_VECTOR;
    var cur_x_sphere_sample = x_sphere_sample;
    var cur_y_sphere_sample = y_sphere_sample;
    var color_bleeding_factor = config.IDENTITY_VECTOR;
    while (bounce < config.MAX_BOUNCES) : (bounce += 1) {
        const hit = cur_scene.intersect(traced_ray);
        if (hit.object_idx) |object_idx| {
            const object = cur_scene.objects.items[object_idx];
            const cur_material = object.material;
            if (is_direct) {
                ray_color += cur_material.emissive * color_bleeding_factor;
            }
            var diffuse = cur_material.diffuse;
            const max_diffuse = vector.getMaxComponent(diffuse);
            if (bounce > config.MIN_BOUNCES or max_diffuse < std.math.f64_epsilon) {
                if (rng.float(f64) > max_diffuse) {
                    break;
                }
                diffuse /= @splat(config.SCENE_DIMS, max_diffuse);
            }
            const hit_point = traced_ray.computeHitPoint(hit.ray_scale_factor);
            var normal = (hit_point - object.center) / @splat(config.SCENE_DIMS, object.radius);
            if (vector.dot_product(normal, traced_ray.direction) >= 0.0) {
                normal = -normal;
            }
            switch (cur_material.material_type) {
                .DIFFUSE => {
                    is_direct = false;
                    const direct_light = color_bleeding_factor * scene.sampleLights(cur_scene, hit_point, normal, traced_ray.direction, cur_material);
                    ray_color += direct_light;
                    traced_ray = material.interreflectDiffuse(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample);
                    color_bleeding_factor *= diffuse;
                },
                .GLOSSY => {
                    is_direct = false;
                    const direct_light = color_bleeding_factor * scene.sampleLights(cur_scene, hit_point, normal, traced_ray.direction, cur_material);
                    ray_color += direct_light;
                    const max_specular = vector.getMaxComponent(cur_material.specular);
                    const specular_probability = max_specular / (max_specular + max_diffuse);
                    const specular_factor = 1.0 / specular_probability;
                    if (rng.float(f64) > specular_probability) {
                        traced_ray = material.interreflectDiffuse(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample);
                        const dscale = @splat(config.SCENE_DIMS, (1.0 / (1.0 - 1.0 / specular_factor)));
                        const color = diffuse * dscale;
                        color_bleeding_factor *= color;
                    } else {
                        traced_ray = material.interreflectSpecular(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample, cur_material.specular_exponent, traced_ray);
                        const color = cur_material.specular * @splat(config.SCENE_DIMS, specular_factor);
                        color_bleeding_factor *= color;
                    }
                },
                .MIRROR => {
                    const view_direction = -traced_ray.direction;
                    const reflected_direction = vector.normalize(vector.reflect(view_direction, normal));
                    traced_ray = .{ .origin = hit_point, .direction = reflected_direction };
                    color_bleeding_factor *= diffuse;
                },
            }
            const sample_idx = rng.intRangeAtMost(usize, 0, config.SAMPLES_PER_PIXEL - 1);
            cur_x_sphere_sample = samples[sample_idx * config.SCREEN_DIMS];
            cur_y_sphere_sample = samples[sample_idx * config.SCREEN_DIMS + 1];
        } else {
            break;
        }
    }
    return ray_color;
}
