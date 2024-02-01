const std = @import("std");

pub const LEN: u16 = 1 << 2;

pub const Vec = @Vector(LEN, f64);

pub const Basis = struct {
    axis2: Vec,
    axis3: Vec,

    pub fn init(u: Vec) Basis {
        var v: Vec = undefined;
        if (@abs(u[0]) > @abs(u[1])) {
            const len = 1.0 / @sqrt(u[0] * u[0] + u[2] * u[2]);
            v = .{ -u[2] * len, 0.0, u[0] * len, 0.0 };
        } else {
            const len = 1.0 / @sqrt(u[1] * u[1] + u[2] * u[2]);
            v = .{ 0.0, u[2] * len, -u[1] * len, 0.0 };
        }
        return .{ .axis2 = v, .axis3 = crossProduct(u, v) };
    }
};

pub fn transformIntoBasis(u_in: Vec, u_x: Vec, u_y: Vec, u_z: Vec) Vec {
    const v_x = u_x * @as(Vec, @splat(u_in[0]));
    const v_y = u_y * @as(Vec, @splat(u_in[1]));
    const v_z = u_z * @as(Vec, @splat(u_in[2]));
    return v_x + v_y + v_z;
}

pub fn normalize(u: Vec) Vec {
    const len_sq = dotProduct(u, u);
    return if (len_sq > std.math.floatEps(f64)) u * @as(Vec, @splat(1.0 / @sqrt(len_sq))) else u;
}

pub fn crossProduct(u: Vec, v: Vec) Vec {
    return .{ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0], 0.0 };
}

pub fn dotProduct(u: Vec, v: Vec) f64 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

pub fn getMaxComponent(u: Vec) f64 {
    return @max(u[0], u[1], u[2]);
}
