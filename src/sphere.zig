const ray = @import("ray.zig");
const config = @import("config.zig");
const vector = @import("vector.zig");
const material = @import("material.zig");

const Vec3 = config.Vec3;

pub const Sphere = struct {
    radius: f64,
    center: Vec3,
    material: *const material.Material,
    radius_sqrd: f64 = 0.0,

    pub fn isLight(self: Sphere) bool {
        return vector.dot_product(self.material.emissive, self.material.emissive) > 0.0;
    }

    pub fn computeRaySphereHit(self: Sphere, cur_ray: ray.Ray) f64 {
        const ray_origin_to_sphere_center = self.center - cur_ray.origin;
        const b = vector.dot_product(ray_origin_to_sphere_center, cur_ray.direction);
        var discriminant = b * b - vector.dot_product(ray_origin_to_sphere_center, ray_origin_to_sphere_center) + self.radius_sqrd;
        if (discriminant < 0.0) {
            return 0.0;
        }
        discriminant = @sqrt(discriminant);
        var ray_scale_factor = b - discriminant;
        if (ray_scale_factor > config.RAY_BIAS) {
            return ray_scale_factor;
        }
        ray_scale_factor = b + discriminant;
        if (ray_scale_factor > config.RAY_BIAS) {
            return ray_scale_factor;
        }
        return 0.0;
    }
};

pub fn make_sphere(radius: f64, center: Vec3, cur_material: *const material.Material) Sphere {
    return .{ .radius = radius, .center = center, .material = cur_material, .radius_sqrd = radius * radius };
}
