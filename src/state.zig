const std = @import("std");
const rl = @import("raylib");
const Ship = @import("ship.zig").Ship;
const Asteroid = @import("asteroid.zig").Asteroid;
const Particle = @import("particle.zig").Particle;

pub const State = struct {
    ship: Ship,
    asteroids: std.ArrayList(Asteroid),
    particles: std.ArrayList(Particle),
    random: std.Random,
};
