const std = @import("std");
const rl = @import("raylib");
const Ship = @import("ship.zig").Ship;
const Asteroid = @import("asteroid.zig").Asteroid;

pub const State = struct {
    ship: Ship,
    asteroids: std.ArrayList(Asteroid),
    random: std.Random,
};
