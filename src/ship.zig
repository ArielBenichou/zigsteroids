const std = @import("std");
const mathx = @import("mathx.zig");
const rl = @import("raylib");

pub const Ship = struct {
    death_timestamp: f32 = 0.0,
    velocity: rl.Vector2 = .{ .x = 0, .y = 0 },
    position: rl.Vector2 = .{ .x = 0, .y = 0 },
    rotation: f32 = 0,
    mega_fuel: f32 = 1,

    drag: f32 = 0.03, // less drag is more chanllenging to manuver
    speed_turn: f32 = 1,
    speed_forward: f32 = 24,

    pub fn isDead(self: *Ship) bool {
        return self.death_timestamp != 0.0;
    }

    pub fn turn(self: *Ship, delta: f32) void {
        self.rotation += std.math.tau * self.speed_turn * delta;
    }

    /// change the ship velocity
    pub fn addThrust(self: *Ship, delta: f32, with_mega_fuel: bool) void {
        const is_using_mega_fuel: f32 = @floatFromInt(@intFromBool(with_mega_fuel and self.mega_fuel > 0.0));
        self.mega_fuel -= delta * is_using_mega_fuel;
        self.velocity = self.velocity.add(
            self.getShipDirection().scale((self.speed_forward * (is_using_mega_fuel + 1.0)) * delta),
        );
    }

    pub fn update(self: *Ship, delta: f32, dim: ?rl.Vector2) void {
        // applying drag to velocity
        self.velocity = self.velocity.scale(1.0 - self.drag);
        // applying the velocity to the position
        self.position = self.position.add(self.velocity);

        // wraping the ship around the screen, optinal
        if (dim) |d| {
            self.position.x = @mod(self.position.x, d.x);
            self.position.y = @mod(self.position.y, d.y);
        }

        // regenerate mega_fuel
        self.mega_fuel = std.math.clamp(self.mega_fuel + delta * 0.1, 0, 1);
    }

    pub fn getShipDirection(self: *Ship) rl.Vector2 {
        return mathx.Vector2.fromAngle(self.rotation + std.math.pi * 0.5);
    }
};
