const std = @import("std");
const math = std.math;
const rl = @import("raylib");
const BASE_SCALE = @import("constants.zig").BASE_SCALE;

pub const Asteroid = struct {
    position: rl.Vector2,
    velocity: f32,
    size: Size,
    seed: u64,

    pub const Size = enum {
        big,
        medium,
        small,

        pub fn size(self: Size) f32 {
            return switch (self) {
                .big => BASE_SCALE * 3.0,
                .medium => BASE_SCALE * 1.4,
                .small => BASE_SCALE * 1.0,
            };
        }
    };
};
