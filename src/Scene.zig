const std = @import("std");
const vector = @import("vector.zig");

const Scene = @This();

const MAX_NUM_LIGHTS: usize = 1 << 0;
const MAX_NUM_SPHERES: usize = 1 << 4;

spheres: std.BoundedArray(Sphere, MAX_NUM_SPHERES) = undefined,
light_idxs: std.BoundedArray(u8, MAX_NUM_LIGHTS) = undefined,
camera: Camera,

pub const Material = struct {
    specular: vector.Vec = @splat(0.0),
    emissive: vector.Vec = @splat(0.0),
    diffuse: vector.Vec = @splat(0.0),
    specular_exponent: f64 = 0.0,
    kind: Kind = .Diffuse,

    pub const Kind = enum {
        Diffuse,
        Glossy,
        Mirror,
    };
};

pub const Sphere = struct {
    center: vector.Vec,
    material: Material,
    radius: f64,

    pub fn init(material: Material, center: vector.Vec, radius: f64) Sphere {
        return .{ .material = material, .center = center, .radius = radius };
    }
};

const Camera = struct {
    direction: vector.Vec,
    fov: f64,
};

pub fn initCornellBox() Scene {
    var camera = Scene.Camera{ .direction = vector.normalize(.{ 0.0, -0.042612, -1.0, 0.0 }), .fov = std.math.tan(55.0 * std.math.pi / 180.0 * 0.5) };
    const glossy_white = Material{ .kind = .Glossy, .diffuse = .{ 0.3, 0.05, 0.05, 0.0 }, .specular = @splat(0.69), .specular_exponent = 45.0 };
    const mirror = Material{ .kind = .Mirror, .diffuse = @splat(0.99) };
    const diffuse_green = Material{ .diffuse = .{ 0.15, 0.95, 0.15, 0.0 } };
    const diffuse_gray = Material{ .diffuse = .{ 0.75, 0.75, 0.75, 0.0 } };
    const diffuse_blue = Material{ .diffuse = .{ 0.75, 0.25, 0.25, 0.0 } };
    const diffuse_red = Material{ .diffuse = .{ 0.15, 0.15, 0.95, 0.0 } };
    const emissive_white = Material{ .emissive = @splat(10.0) };
    const light = Sphere.init(emissive_white, .{ 50.0, 65.1, 81.6, 0.0 }, 10.5);
    var cornell_box = Scene{ .camera = camera };
    cornell_box.spheres.appendAssumeCapacity(light);
    cornell_box.light_idxs.appendAssumeCapacity(0);
    cornell_box.spheres.appendAssumeCapacity(Sphere.init(mirror, .{ 76.0, 16.5, 78.0, 0.0 }, 16.5));
    cornell_box.spheres.appendAssumeCapacity(Sphere.init(diffuse_gray, .{ 50.0, 1e5, 81.6, 0.0 }, 1e5));
    cornell_box.spheres.appendAssumeCapacity(Sphere.init(diffuse_gray, .{ 50.0, 40.8, 1e5, 0.0 }, 1e5));
    cornell_box.spheres.appendAssumeCapacity(Sphere.init(glossy_white, .{ 27.0, 16.5, 57.0, 0.0 }, 16.5));
    cornell_box.spheres.appendAssumeCapacity(Sphere.init(diffuse_red, .{ 1e5 + 1.0, 40.8, 81.6, 0.0 }, 1e5));
    cornell_box.spheres.appendAssumeCapacity(Sphere.init(diffuse_gray, .{ 50.0, -1e5 + 81.6, 81.6, 0.0 }, 1e5));
    cornell_box.spheres.appendAssumeCapacity(Sphere.init(diffuse_green, .{ -1e5 + 99.0, 40.8, 81.6, 0.0 }, 1e5));
    cornell_box.spheres.appendAssumeCapacity(Sphere.init(diffuse_blue, .{ 50.0, 40.8, -1e5 + 170.0, 0.0 }, 1e5));
    return cornell_box;
}
