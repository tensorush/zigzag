const std = @import("std");
const scene = @import("scene.zig");
const config = @import("config.zig");
const sphere = @import("sphere.zig");
const vector = @import("vector.zig");
const material = @import("material.zig");

pub const Ray = struct {
    direction: vector.Vec4,
    origin: vector.Vec4,

    pub fn computeHitPoint(self: Ray, ray_factor: f64) vector.Vec4 {
        return self.origin + self.direction * @splat(config.VECTOR_LEN, ray_factor);
    }
};

pub fn tracePath(cur_ray: Ray, cur_scene: *scene.Scene, x_sphere_sample: f64, y_sphere_sample: f64, samples: [config.NUM_SAMPLES_PER_PIXEL * config.NUM_SCREEN_DIMS]f64, rng: *std.rand.Random) vector.Vec4 {
    var cur_material: *const material.Material = undefined;
    var color_bleeding_factor = vector.IDENTITY_VECTOR;
    var specular_probability: f64 = undefined;
    var direct_light: vector.Vec4 = undefined;
    var cur_x_sphere_sample = x_sphere_sample;
    var cur_y_sphere_sample = y_sphere_sample;
    var cur_sphere: sphere.Sphere = undefined;
    var hit_point: vector.Vec4 = undefined;
    var specular_factor: f64 = undefined;
    var diffuse: vector.Vec4 = undefined;
    var normal: vector.Vec4 = undefined;
    var ray_color = vector.ZERO_VECTOR;
    var max_specular: f64 = undefined;
    var max_diffuse: f64 = undefined;
    var hit: scene.Hit = undefined;
    var bounce_idx: usize = 0;
    var sample_idx: usize = 0;
    var traced_ray = cur_ray;
    var is_direct = true;
    while (bounce_idx < config.MAX_NUM_BOUNCES) : (bounce_idx += 1) {
        hit = cur_scene.intersect(traced_ray);
        if (hit.sphere_idx_opt) |sphere_idx| {
            cur_sphere = cur_scene.spheres.items[sphere_idx];
            cur_material = cur_sphere.material;
            diffuse = cur_material.diffuse;
            if (is_direct) ray_color += cur_material.emissive * color_bleeding_factor;
            max_diffuse = vector.getMaxComponent(diffuse);
            if (bounce_idx > config.MIN_NUM_BOUNCES or max_diffuse < std.math.f64_epsilon) {
                if (rng.float(f64) > max_diffuse) break;
                diffuse /= @splat(config.VECTOR_LEN, max_diffuse);
            }
            hit_point = traced_ray.computeHitPoint(hit.ray_factor);
            normal = (hit_point - cur_sphere.center) / @splat(config.VECTOR_LEN, cur_sphere.radius);
            if (vector.dotProduct(normal, traced_ray.direction) > 0.0) normal = -normal;
            switch (cur_material.material_type) {
                .DIFFUSE => {
                    is_direct = false;
                    direct_light = color_bleeding_factor * scene.sampleLights(cur_scene, hit_point, normal, traced_ray.direction, cur_material);
                    ray_color += direct_light;
                    traced_ray = material.interreflectDiffuse(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample);
                    color_bleeding_factor *= diffuse;
                },
                .GLOSSY => {
                    is_direct = false;
                    direct_light = color_bleeding_factor * scene.sampleLights(cur_scene, hit_point, normal, traced_ray.direction, cur_material);
                    ray_color += direct_light;
                    max_specular = vector.getMaxComponent(cur_material.specular);
                    specular_probability = max_specular / (max_specular + max_diffuse);
                    specular_factor = 1.0 / specular_probability;
                    if (rng.float(f64) > specular_probability) {
                        traced_ray = material.interreflectDiffuse(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample);
                        color_bleeding_factor *= diffuse * @splat(config.VECTOR_LEN, (1.0 / (1.0 - 1.0 / specular_factor)));
                    } else {
                        traced_ray = material.interreflectSpecular(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample, cur_material.specular_exponent, traced_ray);
                        color_bleeding_factor *= cur_material.specular * @splat(config.VECTOR_LEN, specular_factor);
                    }
                },
                .MIRROR => {
                    traced_ray = .{ .direction = vector.normalize(vector.reflect(-traced_ray.direction, normal)), .origin = hit_point };
                    color_bleeding_factor *= diffuse;
                },
            }
            sample_idx = rng.intRangeAtMost(usize, 0, config.NUM_SAMPLES_PER_PIXEL - 1);
            cur_x_sphere_sample = samples[sample_idx * config.NUM_SCREEN_DIMS];
            cur_y_sphere_sample = samples[sample_idx * config.NUM_SCREEN_DIMS + 1];
        } else {
            break;
        }
    }
    return ray_color;
}
