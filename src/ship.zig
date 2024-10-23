const std = @import("std");
const mathx = @import("mathx.zig");
const rl = @import("raylib");
const SHIP_SCALE = @import("constants.zig").SHIP_SCALE;
const CAMERA_SCALE = @import("constants.zig").CAMERA_SCALE;

const PEW_PEW_COST = 0.2;
pub const Ship = struct {
    death_timestamp: f32 = 0.0,
    invulnerable: f32 = 0.0,
    velocity: rl.Vector2 = .{ .x = 0, .y = 0 },
    position: rl.Vector2 = .{ .x = 0, .y = 0 },
    rotation: f32 = std.math.tau * 0.5,
    mega_fuel: f32 = 1,
    is_using_mega_fuel: bool = false,

    drag: f32 = 0.03, // less drag is more chanllenging to manuver
    speed_turn: f32 = 1,
    speed_forward: f32 = 24,

    pub const drawing = [_]rl.Vector2{
        rl.Vector2.init(0.0, 0.5),
        rl.Vector2.init(-0.4, -0.5),
        rl.Vector2.init(-0.3, -0.4),
        rl.Vector2.init(0.3, -0.4),
        rl.Vector2.init(0.4, -0.5),
    };

    pub fn hitbox(self: *Ship) f32 {
        _ = self; // autofix
        return SHIP_SCALE * CAMERA_SCALE * 0.5;
    }

    pub fn isDead(self: *Ship) bool {
        return self.death_timestamp != 0.0;
    }

    pub fn isInvulnerable(self: *Ship) bool {
        return self.invulnerable > 0.0;
    }

    pub fn turn(self: *Ship, delta: f32) void {
        self.rotation += std.math.tau * self.speed_turn * delta;
    }

    /// change the ship velocity
    pub fn addThrust(self: *Ship, delta: f32, with_mega_fuel: bool) void {
        self.is_using_mega_fuel = with_mega_fuel and self.mega_fuel > 0.0;
        const mega_fuel_mod: f32 = @floatFromInt(@intFromBool(self.is_using_mega_fuel));
        self.mega_fuel -= delta * mega_fuel_mod * 2;
        self.velocity = self.velocity.add(
            self.getShipDirection().scale((self.speed_forward * (mega_fuel_mod + 1.0)) * delta),
        );
    }

    pub fn canShoot(self: *Ship) bool {
        return self.mega_fuel >= PEW_PEW_COST;
    }

    pub fn shoot(self: *Ship) bool {
        const can_shoot = self.canShoot();
        if (can_shoot) {
            self.mega_fuel -= PEW_PEW_COST;
            self.velocity = self.velocity.add(self.getShipDirection().scale(-0.5));
        }
        return can_shoot;
    }

    pub fn refill(self: *Ship) void {
        self.mega_fuel = std.math.clamp(self.mega_fuel + PEW_PEW_COST, 0, 1);
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

        if (self.isInvulnerable()) {
            self.invulnerable -= delta;
        }
    }

    pub fn getShipDirection(self: *Ship) rl.Vector2 {
        return mathx.Vector2.fromAngle(self.rotation + std.math.pi * 0.5);
    }
};
