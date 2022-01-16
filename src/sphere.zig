const ray = @import("ray.zig");
const config = @import("config.zig");
const vector = @import("vector.zig");
const material = @import("material.zig");

const Vec3 = config.Vec3;

pub const Sphere = struct {
    radius: f64,
    center: Vec3,
    material: *const material.Material,
    radius_squared: f64 = 0.0,

    pub fn is_light(self: Sphere) bool {
        return vector.dot_product(self.material.emissive, self.material.emissive) > 0.0;
    }

    pub fn intersects(self: Sphere, cur_ray: ray.Ray) f64 {
        const op = self.center - cur_ray.origin;
        const b = vector.dot_product(op, cur_ray.dir);
        var d = b * b - vector.dot_product(op, op) + self.radius_squared;
        if (d < 0.0) {
            return 0.0;
        }
        d = @sqrt(d);
        var t = b - d;
        if (t > config.RAY_BIAS) {
            return t;
        }
        t = b + d;
        if (t > config.RAY_BIAS) {
            return t;
        }
        return 0.0;
    }
};

pub fn make_sphere(radius: f64, center: Vec3, cur_material: *const material.Material) Sphere {
    return .{ .radius = radius, .center = center, .material = cur_material, .radius_squared = radius * radius };
}
