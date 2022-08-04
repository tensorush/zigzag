const ray = @import("ray.zig");
const config = @import("config.zig");
const vector = @import("vector.zig");
const material = @import("material.zig");

pub const Sphere = struct {
    material: *const material.Material,
    center: vector.Vec4,
    radius: f64,

    pub fn computeRaySphereHit(self: Sphere, cur_ray: ray.Ray) f64 {
        const ray_origin_to_sphere_center = self.center - cur_ray.origin;
        const b = vector.dotProduct(ray_origin_to_sphere_center, cur_ray.direction);
        var discriminant = b * b - vector.dotProduct(ray_origin_to_sphere_center, ray_origin_to_sphere_center) + self.radius * self.radius;
        if (discriminant < 0.0) return 0.0;
        discriminant = @sqrt(discriminant);
        var ray_factor = b - discriminant;
        if (ray_factor > config.RAY_BIAS) return ray_factor;
        ray_factor = b + discriminant;
        if (ray_factor > config.RAY_BIAS) return ray_factor;
        return 0.0;
    }

    pub fn isLight(self: Sphere) bool {
        return vector.dotProduct(self.material.emissive, self.material.emissive) > 0.0;
    }
};

pub fn makeSphere(radius: f64, center: vector.Vec4, cur_material: *const material.Material) Sphere {
    return .{ .material = cur_material, .center = center, .radius = radius };
}
