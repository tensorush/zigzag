const std = @import("std");
const Scene = @import("Scene.zig");
const vector = @import("vector.zig");

const Tracer = @This();

const NUM_COLORS: u32 = 255;
const RAY_BIAS: f64 = 0.0005;
const SSAA_FACTOR: usize = 1 << 3;
const NUM_FRAME_DIMS: usize = 1 << 1;
const MIN_NUM_BOUNCES: usize = 1 << 2;
const MAX_NUM_BOUNCES: usize = 1 << 3;
const NUM_SAMPLES_PER_PIXEL: usize = 1 << 8;
const RENDER_FILE_PATH = "renders/render.ppm";

samples: [NUM_SAMPLES_PER_PIXEL * NUM_FRAME_DIMS]f64 = undefined,
scene: Scene,

const Ray = struct {
    direction: vector.Vec,
    origin: vector.Vec,

    const Hit = struct {
        ray_factor: f64 = std.math.floatMax(f64),
        sphere_idx_opt: ?usize = undefined,
    };

    fn computeHitPoint(self: Ray, ray_factor: f64) vector.Vec {
        return self.origin + self.direction * @as(vector.Vec, @splat(ray_factor));
    }

    fn intersect(self: Ray, scene: Scene) Hit {
        var hit = Hit{};
        for (scene.spheres.constSlice(), 0..) |sphere, i| {
            const ray_factor = self.computeRaySphereHit(sphere);
            if (ray_factor > 0.0 and ray_factor < hit.ray_factor) {
                hit = .{ .sphere_idx_opt = i, .ray_factor = ray_factor };
            }
        }
        return hit;
    }

    fn computeRaySphereHit(self: Ray, sphere: Scene.Sphere) f64 {
        const ray_origin_to_sphere_center = sphere.center - self.origin;
        const b = vector.dotProduct(ray_origin_to_sphere_center, self.direction);
        var discriminant = b * b - vector.dotProduct(ray_origin_to_sphere_center, ray_origin_to_sphere_center) + sphere.radius * sphere.radius;
        if (discriminant < 0.0) {
            return 0.0;
        }
        discriminant = @sqrt(discriminant);
        var ray_factor = b - discriminant;
        if (ray_factor > RAY_BIAS) {
            return ray_factor;
        }
        ray_factor = b + discriminant;
        if (ray_factor > RAY_BIAS) {
            return ray_factor;
        }
        return 0.0;
    }
};

pub fn tracePaths(self: Tracer, frame: []u8, offset: usize, size: usize, rng: std.rand.Random, render_dim: usize) void {
    const camera = self.scene.camera;
    const x_direction = vector.Vec{ camera.fov, 0.0, 0.0, 0.0 };
    var y_direction = vector.normalize(vector.crossProduct(x_direction, camera.direction)) * @as(vector.Vec, @splat(camera.fov));
    var sphere_samples: [NUM_SAMPLES_PER_PIXEL * NUM_FRAME_DIMS]f64 = undefined;
    var chunk_samples: [NUM_SAMPLES_PER_PIXEL * NUM_FRAME_DIMS]f64 = undefined;
    const ray_origin = vector.Vec{ 50.0, 52.0, 295.6, 0.0 };
    const ray_factor: vector.Vec = @splat(136.0);
    const start_x = offset % render_dim;
    const start_y = offset / render_dim;
    var x = start_x;
    var y = start_y;
    samplePixels(&chunk_samples, rng);
    applyTentFilter(&chunk_samples);
    var pixel_offset = offset * vector.LEN;
    const end_offset = pixel_offset + size * vector.LEN;
    while (pixel_offset < end_offset) : (pixel_offset += vector.LEN) {
        samplePixels(&sphere_samples, rng);
        var ssaa_color_vec: vector.Vec = @splat(0.0);
        var ssaa_factor: usize = 0;
        while (ssaa_factor < SSAA_FACTOR) : (ssaa_factor += 1) {
            var raw_color_vec: vector.Vec = @splat(0.0);
            var sample_idx: usize = 0;
            while (sample_idx < NUM_SAMPLES_PER_PIXEL) : (sample_idx += 1) {
                const x_chunk_direction = x_direction * @as(vector.Vec, @splat((((@as(f64, @floatFromInt((ssaa_factor & 1))) + 0.5 + chunk_samples[sample_idx * NUM_FRAME_DIMS]) / 2.0) + @as(f64, @floatFromInt(x))) / @as(f64, @floatFromInt(render_dim)) - 0.5));
                const y_chunk_direction = y_direction * @as(vector.Vec, @splat(-((((@as(f64, @floatFromInt((ssaa_factor >> 1))) + 0.5 + chunk_samples[sample_idx * NUM_FRAME_DIMS + 1]) / 2.0) + @as(f64, @floatFromInt(y))) / @as(f64, @floatFromInt(render_dim)) - 0.5)));
                const ray_direction = vector.normalize(x_chunk_direction + y_chunk_direction + camera.direction);
                const ray = Ray{ .direction = ray_direction, .origin = ray_origin + ray_direction * ray_factor };
                var ray_color_vec = self.tracePath(ray, sphere_samples[sample_idx * NUM_FRAME_DIMS], sphere_samples[sample_idx * NUM_FRAME_DIMS + 1], rng);
                raw_color_vec += ray_color_vec * @as(vector.Vec, @splat(1.0 / @as(f64, NUM_SAMPLES_PER_PIXEL)));
            }
            ssaa_color_vec += raw_color_vec * @as(vector.Vec, @splat(1.0 / @as(f64, @floatFromInt(SSAA_FACTOR))));
        }
        const pixel = getPixel(ssaa_color_vec);
        frame[pixel_offset] = pixel[0];
        frame[pixel_offset + 1] = pixel[1];
        frame[pixel_offset + 2] = pixel[2];
        x += 1;
        if (x == render_dim) {
            x = 0;
            y += 1;
        }
    }
}

fn tracePath(self: Tracer, ray: Ray, x_sphere_sample: f64, y_sphere_sample: f64, rng: std.rand.Random) vector.Vec {
    var color_bleeding_factor: vector.Vec = @splat(1.0);
    var cur_x_sphere_sample = x_sphere_sample;
    var cur_y_sphere_sample = y_sphere_sample;
    var ray_color_vec: vector.Vec = @splat(0.0);
    var bounce_idx: usize = 0;
    var sample_idx: usize = 0;
    var is_direct = true;
    var traced_ray = ray;
    while (bounce_idx < MAX_NUM_BOUNCES) : (bounce_idx += 1) {
        const hit = traced_ray.intersect(self.scene);
        if (hit.sphere_idx_opt) |sphere_idx| {
            const sphere = self.scene.spheres.get(sphere_idx);
            const material = sphere.material;
            var diffuse = material.diffuse;
            if (is_direct) {
                ray_color_vec += material.emissive * color_bleeding_factor;
            }
            const max_diffuse = vector.getMaxComponent(diffuse);
            if (bounce_idx > MIN_NUM_BOUNCES or max_diffuse < std.math.floatEps(f64)) {
                if (rng.float(f64) > max_diffuse) {
                    break;
                }
                diffuse /= @splat(max_diffuse);
            }
            const hit_point = traced_ray.computeHitPoint(hit.ray_factor);
            var normal = (hit_point - sphere.center) / @as(vector.Vec, @splat(sphere.radius));
            if (vector.dotProduct(normal, traced_ray.direction) > 0.0) {
                normal = -normal;
            }
            switch (material.kind) {
                .Diffuse => {
                    is_direct = false;
                    const direct_light = color_bleeding_factor * sampleLights(self.scene, hit_point, normal, traced_ray.direction, material);
                    ray_color_vec += direct_light;
                    traced_ray = interreflectDiffuse(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample);
                    color_bleeding_factor *= diffuse;
                },
                .Glossy => {
                    is_direct = false;
                    const direct_light = color_bleeding_factor * sampleLights(self.scene, hit_point, normal, traced_ray.direction, material);
                    ray_color_vec += direct_light;
                    const max_specular = vector.getMaxComponent(material.specular);
                    const specular_probability = max_specular / (max_specular + max_diffuse);
                    const specular_factor = 1.0 / specular_probability;
                    if (rng.float(f64) > specular_probability) {
                        traced_ray = interreflectDiffuse(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample);
                        color_bleeding_factor *= diffuse * @as(vector.Vec, @splat((1.0 / (1.0 - 1.0 / specular_factor))));
                    } else {
                        traced_ray = interreflectSpecular(normal, hit_point, cur_x_sphere_sample, cur_y_sphere_sample, material.specular_exponent, traced_ray);
                        color_bleeding_factor *= material.specular * @as(vector.Vec, @splat(specular_factor));
                    }
                },
                .Mirror => {
                    traced_ray = .{ .direction = vector.normalize(reflect(-traced_ray.direction, normal)), .origin = hit_point };
                    color_bleeding_factor *= diffuse;
                },
            }
            sample_idx = rng.intRangeAtMost(usize, 0, NUM_SAMPLES_PER_PIXEL - 1);
            cur_x_sphere_sample = self.samples[sample_idx * NUM_FRAME_DIMS];
            cur_y_sphere_sample = self.samples[sample_idx * NUM_FRAME_DIMS + 1];
        } else {
            break;
        }
    }
    return ray_color_vec;
}

fn sampleLights(scene: Scene, hit_point: vector.Vec, normal: vector.Vec, ray_direction: vector.Vec, material: Scene.Material) vector.Vec {
    var color: vector.Vec = @splat(0.0);
    for (scene.light_idxs.constSlice()) |light_idx| {
        const light = scene.spheres.get(light_idx);
        var hit_to_light_center = light.center - hit_point;
        const distance_to_light_sq = vector.dotProduct(hit_to_light_center, hit_to_light_center);
        hit_to_light_center = vector.normalize(hit_to_light_center);
        var cos_theta = vector.dotProduct(normal, hit_to_light_center);
        const shadow_ray = Ray{ .direction = hit_to_light_center, .origin = hit_point };
        const shadow_ray_hit = shadow_ray.intersect(scene);
        if (shadow_ray_hit.sphere_idx_opt) |shadow_idx| {
            if (shadow_idx == light_idx) {
                if (cos_theta > 0.0) {
                    const sin_alpha_max_sq = light.radius * light.radius / distance_to_light_sq;
                    const cos_alpha_max = @sqrt(1.0 - sin_alpha_max_sq);
                    const omega = 2.0 * (1.0 - cos_alpha_max);
                    cos_theta *= omega;
                    color += material.diffuse * light.material.emissive * @as(vector.Vec, @splat(cos_theta));
                }
                if (material.kind == .Glossy or material.kind == .Mirror) {
                    cos_theta = -vector.dotProduct(reflect(hit_to_light_center, normal), ray_direction);
                    if (cos_theta > 0.0) {
                        color += material.specular * @as(vector.Vec, @splat(std.math.pow(f64, cos_theta, material.specular_exponent)));
                    }
                }
            }
        }
    }
    return color;
}

pub fn samplePixels(samples: *[NUM_SAMPLES_PER_PIXEL * NUM_FRAME_DIMS]f64, rng: std.rand.Random) void {
    const x_strata = @sqrt(@as(f64, NUM_SAMPLES_PER_PIXEL));
    const y_strata = @as(f64, NUM_SAMPLES_PER_PIXEL) / x_strata;
    var sample_idx: usize = 0;
    var y_step: f64 = 0.0;
    while (y_step < y_strata) : (y_step += 1.0) {
        var x_step: f64 = 0.0;
        while (x_step < x_strata) : (x_step += 1.0) {
            samples[sample_idx] = (x_step + rng.float(f64)) / x_strata;
            samples[sample_idx + 1] = (y_step + rng.float(f64)) / y_strata;
            sample_idx += 2;
        }
    }
}

fn applyTentFilter(samples: *[NUM_SAMPLES_PER_PIXEL * NUM_FRAME_DIMS]f64) void {
    var sample_idx: usize = 0;
    while (sample_idx < NUM_SAMPLES_PER_PIXEL) : (sample_idx += 1) {
        const x = samples[sample_idx * NUM_FRAME_DIMS] * @as(f64, NUM_FRAME_DIMS);
        const y = samples[sample_idx * NUM_FRAME_DIMS + 1] * @as(f64, NUM_FRAME_DIMS);
        samples[sample_idx * NUM_FRAME_DIMS] = if (x < 1.0) @sqrt(x) - 1.0 else 1.0 - @sqrt(2.0 - x);
        samples[sample_idx * NUM_FRAME_DIMS + 1] = if (y < 1.0) @sqrt(y) - 1.0 else 1.0 - @sqrt(2.0 - y);
    }
}

fn interreflectSpecular(normal: vector.Vec, hit_point: vector.Vec, x_sphere_sample: f64, y_sphere_sample: f64, specular_exponent: f64, ray: Ray) Ray {
    const view_direction = -ray.direction;
    const reflected_direction = vector.normalize(reflect(view_direction, normal));
    const basis = vector.Basis.init(reflected_direction);
    const sampled_direction = sampleHemisphereSpecular(x_sphere_sample, y_sphere_sample, specular_exponent);
    return .{ .direction = vector.transformIntoBasis(sampled_direction, basis.axis2, basis.axis3, reflected_direction), .origin = hit_point };
}

fn interreflectDiffuse(normal: vector.Vec, hit_point: vector.Vec, x_sphere_sample: f64, y_sphere_sample: f64) Ray {
    const basis = vector.Basis.init(normal);
    const sampled_direction = sampleHemisphereDiffuse(x_sphere_sample, y_sphere_sample);
    return .{ .direction = vector.transformIntoBasis(sampled_direction, basis.axis2, basis.axis3, normal), .origin = hit_point };
}

fn sampleHemisphereSpecular(x_sphere_sample: f64, y_sphere_sample: f64, specular_exponent: f64) vector.Vec {
    const phi = 2.0 * std.math.pi * x_sphere_sample;
    const cos_theta = std.math.pow(f64, 1.0 - y_sphere_sample, 1.0 / (specular_exponent + 1.0));
    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
    return .{ @cos(phi) * sin_theta, @sin(phi) * sin_theta, cos_theta, 0.0 };
}

fn sampleHemisphereDiffuse(x_sphere_sample: f64, y_sphere_sample: f64) vector.Vec {
    const radius = @sqrt(y_sphere_sample);
    const phi = 2.0 * std.math.pi * x_sphere_sample;
    return .{ @cos(phi) * radius, @sin(phi) * radius, @sqrt(1.0 - radius * radius), 0.0 };
}

fn reflect(direction: vector.Vec, normal: vector.Vec) vector.Vec {
    return normal * @as(vector.Vec, @splat(vector.dotProduct(direction, normal) * @as(f64, NUM_FRAME_DIMS))) - direction;
}

pub fn renderPpm(frame: []const u8, render_dim: usize) (std.fs.File.OpenError || std.os.WriteError)!void {
    const render_file = try std.fs.cwd().createFile(RENDER_FILE_PATH, .{});
    defer render_file.close();
    var buf_writer = std.io.bufferedWriter(render_file.writer());
    const writer = buf_writer.writer();
    try writer.print("P3\n{d} {d} {d}\n", .{ render_dim, render_dim, NUM_COLORS });
    for (frame, 1..) |pixel, i| {
        if (i % 4 == 0) {
            try writer.writeAll("\n");
        } else {
            try writer.print("{d} ", .{pixel});
        }
    }
    try buf_writer.flush();
}

fn getPixel(u: vector.Vec) @Vector(3, u8) {
    return .{ getColor(u[2]), getColor(u[1]), getColor(u[0]) };
}

fn getColor(x: f64) u8 {
    return @as(u8, @intFromFloat(std.math.pow(f64, std.math.clamp(x, 0.0, 1.0), 0.45) * @as(f64, @floatFromInt(NUM_COLORS)) + 0.5));
}
