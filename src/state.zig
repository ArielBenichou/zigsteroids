const std = @import("std");
const rl = @import("raylib");
const Ship = @import("ship.zig").Ship;
const Asteroid = @import("asteroid.zig").Asteroid;
const Particle = @import("particle.zig").Particle;
const Projectile = @import("projectile.zig").Projectile;

pub const State = struct {
    ship: Ship,
    asteroids: std.ArrayList(Asteroid),
    asteroids_queue: std.ArrayList(Asteroid),
    particles: std.ArrayList(Particle),
    projectile: std.ArrayList(Projectile),
    random: std.Random,
    lives: usize,
    score: usize = 0,
    level_start: f32,
    frame: usize = 0,
};
