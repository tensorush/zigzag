const ray = @import("ray.zig");
const Config = @import("Config.zig");
const Vector = @import("Vector.zig");
const material = @import("material.zig");

pub const Sphere = struct {
    material: *const material.Material,
    center: Vector.Vec3,
    radius: f64,

    pub fn isLight(self: Sphere) bool {
        return Vector.dotProduct(self.material.emissive, self.material.emissive) > 0.0;
    }

    pub fn computeRaySphereHit(self: Sphere, cur_ray: ray.Ray) f64 {
        const ray_origin_to_sphere_center = self.center - cur_ray.origin;
        const b = Vector.dotProduct(ray_origin_to_sphere_center, cur_ray.direction);
        var discriminant = b * b - Vector.dotProduct(ray_origin_to_sphere_center, ray_origin_to_sphere_center) + self.radius * self.radius;
        if (discriminant < 0.0) {
            return 0.0;
        }
        discriminant = @sqrt(discriminant);
        var ray_scale_factor = b - discriminant;
        if (ray_scale_factor > Config.RAY_BIAS) {
            return ray_scale_factor;
        }
        ray_scale_factor = b + discriminant;
        if (ray_scale_factor > Config.RAY_BIAS) {
            return ray_scale_factor;
        }
        return 0.0;
    }
};

pub fn makeSphere(radius: f64, center: Vector.Vec3, cur_material: *const material.Material) Sphere {
    return .{ .material = cur_material, .center = center, .radius = radius };
}
