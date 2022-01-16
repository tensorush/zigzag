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
    dir: Vec3,

    pub fn calc_intersection_point(self: Ray, t: f64) Vec3 {
        return self.origin + self.dir * @splat(config.NUM_DIMS, t);
    }
};

pub fn trace_path(cur_ray: Ray, cur_scene: *scene.Scene, puu1: f64, puu2: f64, samples: [config.SAMPLES_PER_PIXEL * 2]f64, rng: *std.rand.Random) Vec3 {
    var uu1 = puu1;
    var uu2 = puu2;
    var t_ray = cur_ray;
    var direct = true;
    var bounce: usize = 0;
    var result = config.ZERO_VECTOR;
    var rr_scale = config.IDENTITY_VECTOR;
    while (bounce < config.MAX_BOUNCES) : (bounce += 1) {
        const hit = cur_scene.intersect(t_ray);
        if (hit.objectIndex) |objectIndex| {
            const obj = cur_scene.objects.items[objectIndex];
            const cur_material = obj.material;
            if (direct) {
                result += cur_material.emissive * rr_scale;
            }
            var diffuse = cur_material.diffuse;
            const max_diffuse = vector.max_component(diffuse);
            if (bounce > config.MIN_BOUNCES or max_diffuse < std.math.f64_epsilon) {
                if (rng.float(f64) > max_diffuse) {
                    break;
                }
                diffuse /= @splat(config.NUM_DIMS, max_diffuse);
            }
            const intersection_point = t_ray.calc_intersection_point(hit.t);
            var normal = (intersection_point - obj.center) / @splat(config.NUM_DIMS, obj.radius);
            if (vector.dot_product(normal, t_ray.dir) >= 0.0) {
                normal = -normal;
            }
            switch (cur_material.material_type) {
                .DIFFUSE => {
                    direct = false;
                    const direct_light = rr_scale * scene.sample_lights(cur_scene, intersection_point, normal, t_ray.dir, cur_material);
                    result += direct_light;
                    t_ray = material.interreflect_diffuse(normal, intersection_point, uu1, uu2);
                    rr_scale *= diffuse;
                },
                .GLOSSY => {
                    direct = false;
                    const direct_light = rr_scale * scene.sample_lights(cur_scene, intersection_point, normal, t_ray.dir, cur_material);
                    result += direct_light;
                    const max_spec = vector.max_component(cur_material.specular);
                    const p = max_spec / (max_spec + max_diffuse);
                    const smult = 1.0 / p;
                    if (rng.float(f64) > p) {
                        t_ray = material.interreflect_diffuse(normal, intersection_point, uu1, uu2);
                        const dscale = @splat(config.NUM_DIMS, (1.0 / (1.0 - 1.0 / smult)));
                        const color = diffuse * dscale;
                        rr_scale *= color;
                    } else {
                        t_ray = material.interreflect_specular(normal, intersection_point, uu1, uu2, cur_material.exp, t_ray);
                        const color = cur_material.specular * @splat(config.NUM_DIMS, smult);
                        rr_scale *= color;
                    }
                },
                .MIRROR => {
                    const view = -t_ray.dir;
                    const reflected = vector.normalize(vector.reflect(view, normal));
                    t_ray = .{ .origin = intersection_point, .dir = reflected };
                    rr_scale *= diffuse;
                },
            }
            const sample_index = rng.intRangeAtMost(usize, 0, config.SAMPLES_PER_PIXEL - 1);
            uu1 = samples[sample_index * 2];
            uu2 = samples[sample_index * 2 + 1];
        } else {
            break;
        }
    }
    return result;
}
