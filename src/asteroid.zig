const std = @import("std");
const math = std.math;
const rl = @import("raylib");
const SHIP_SCALE = @import("constants.zig").SHIP_SCALE;
const CAMERA_SCALE = @import("constants.zig").CAMERA_SCALE;

pub const Asteroid = struct {
    position: rl.Vector2,
    velocity: rl.Vector2 = .{ .x = 0, .y = 0 },
    size: Size,
    seed: u64,
    remove: bool = false,

    pub fn update(self: *Asteroid, dim: ?rl.Vector2) void {
        // applying the velocity to the position
        self.position = self.position.add(self.velocity);

        // wraping the asteroid around the screen, optinal
        if (dim) |d| {
            self.position.x = @mod(self.position.x, d.x);
            self.position.y = @mod(self.position.y, d.y);
        }
    }

    pub const Size = enum {
        big,
        medium,
        small,

        pub fn size(self: Size) f32 {
            return switch (self) {
                .big => SHIP_SCALE * 3.0,
                .medium => SHIP_SCALE * 1.4,
                .small => SHIP_SCALE * 1.0,
            };
        }

        pub fn hitbox(self: Size) f32 {
            return switch (self) {
                .big => self.size() * CAMERA_SCALE * 0.4,
                .medium => self.size() * CAMERA_SCALE * 0.45,
                .small => self.size() * CAMERA_SCALE * 0.5,
            };
        }

        pub fn velocityScale(self: Size) f32 {
            return switch (self) {
                .big => 0.75,
                .medium => 1.0,
                .small => 1.6,
            };
        }
    };
};
