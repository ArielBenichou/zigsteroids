const std = @import("std");
const mathx = @import("mathx.zig");
const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Drawing = @import("drawing.zig").Drawing;
const State = @import("state.zig").State;
const Sound = @import("sound.zig").Sound;
const Asteroid = @import("asteroid.zig").Asteroid;
const Ship = @import("ship.zig").Ship;
const Particle = @import("particle.zig").Particle;
const Projectile = @import("projectile.zig").Projectile;
const constants = @import("constants.zig");

const SCREEN_SIZE = constants.SCREEN_SIZE;
const SCALE = constants.SCALE;
const LINE_THICKNESS = constants.LINE_THICKNESS;
const CAMERA_SCALE = constants.CAMERA_SCALE;
const SHIP_SCALE = constants.SHIP_SCALE;
var DEBUG_VIZ = false;

var state: State = undefined;
var sound: Sound = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--debug-viz")) {
            DEBUG_VIZ = true;
        }
    }

    //--------------------------------------------------------------------------------------
    rl.initWindow(
        SCREEN_SIZE.x,
        SCREEN_SIZE.y,
        "zigsteroids",
    );
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    rl.initAudioDevice();
    defer rl.closeAudioDevice();
    //--------------------------------------------------------------------------------------

    const seed: u64 = @bitCast(std.time.timestamp());
    std.debug.print("[GAME] Seed: {}", .{seed});
    var prng = std.rand.Xoshiro256.init(seed);

    state = .{
        .ship = undefined,
        .asteroids = std.ArrayList(Asteroid).init(allocator),
        .asteroids_queue = std.ArrayList(Asteroid).init(allocator),
        .particles = std.ArrayList(Particle).init(allocator),
        .projectile = std.ArrayList(Projectile).init(allocator),
        .random = prng.random(),
        .lives = undefined,
        .score = undefined,
        .level_start = undefined,
    };
    defer state.asteroids.deinit();
    defer state.asteroids_queue.deinit();
    defer state.particles.deinit();
    defer state.projectile.deinit();

    const pew_path = try getRelativePath(allocator, "./assets/sounds/pew.wav");
    const boom_path = try getRelativePath(allocator, "./assets/sounds/boom.wav");
    const loser_path = try getRelativePath(allocator, "./assets/sounds/loser.wav");
    const thrust_path = try getRelativePath(allocator, "./assets/sounds/thrust.wav");
    const mega_thrust_path = try getRelativePath(allocator, "./assets/sounds/mega_thrust.wav");
    sound = .{
        .pew = rl.loadSound(pew_path),
        .boom = rl.loadSound(boom_path),
        .loser = rl.loadSound(loser_path),
        .thrust = rl.loadSound(thrust_path),
        .mega_thrust = rl.loadSound(mega_thrust_path),
    };
    allocator.free(pew_path);
    allocator.free(boom_path);
    allocator.free(loser_path);
    allocator.free(thrust_path);
    allocator.free(mega_thrust_path);

    defer rl.unloadSound(sound.pew);
    defer rl.unloadSound(sound.boom);
    defer rl.unloadSound(sound.loser);
    defer rl.unloadSound(sound.thrust);
    defer rl.unloadSound(sound.mega_thrust);

    const drawing = Drawing{
        .line_thickness = LINE_THICKNESS,
        .base_scale = CAMERA_SCALE,
    };

    try init();

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        try update();

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        try render(&drawing);
        state.frame += 1;
        //----------------------------------------------------------------------------------
    }
}

fn init() !void {
    try reset();
    state.lives = 4;
    state.score = 0;
    state.level_start = @floatCast(rl.getTime());
    state.asteroids.clearRetainingCapacity();
    state.asteroids_queue.clearRetainingCapacity();
    const asteroids_count = 20;
    for (0..asteroids_count) |_| {
        const random_angle = std.math.tau * state.random.float(f32);
        const size = state.random.enumValue(Asteroid.Size);
        try state.asteroids_queue.append(.{
            .position = Vector2.init(
                state.random.float(f32) * SCREEN_SIZE.x,
                state.random.float(f32) * SCREEN_SIZE.y,
            ),
            .velocity = mathx.Vector2
                .fromAngle(random_angle)
                .scale(size.velocityScale() * 3.0 * state.random.float(f32)),
            .size = size,
            .seed = state.random.int(u64),
        });
    }
}

fn reset() !void {
    state.ship = .{
        .invulnerable = 1.5,
        .position = SCREEN_SIZE.scale(0.5),
        .speed_turn = 1 * SCALE,
        .speed_forward = 24 * SCALE,
    };

    state.particles.clearRetainingCapacity();
}

fn update() !void {
    const now: f32 = @floatCast(rl.getTime());
    const delta: f32 = @floatCast(rl.getFrameTime());

    if (rl.isKeyDown(.key_left_control) and rl.isKeyDown(.key_r)) {
        try init();
    }

    if (!state.ship.isDead()) {
        // Ship Contorl
        if (rl.isKeyDown(.key_a)) {
            state.ship.turn(-1 * delta);
        }

        if (rl.isKeyDown(.key_d)) {
            state.ship.turn(delta);
        }

        if (rl.isKeyDown(.key_w)) {
            state.ship.addThrust(
                delta,
                rl.isKeyDown(.key_left_shift),
            );

            if (state.frame % 12 == 0) {
                rl.playSound(sound.thrust);
                if (state.ship.is_using_mega_fuel) {
                    rl.playSound(sound.mega_thrust);
                }
            }
        }

        // Shoot
        if (!state.ship.isInvulnerable() and rl.isKeyPressed(.key_space)) {
            if (state.ship.shoot()) {
                rl.playSound(sound.pew);
                try state.projectile.append(.{
                    .position = state.ship.position.add(Ship.drawing[0]),
                    .length = 2.5,
                    .ttl = 1,
                    .rotation = state.ship.rotation,
                    .velocity = state.ship
                        .getShipDirection()
                        .scale(30 * SCALE),
                });
            }
        }

        state.ship.update(delta, SCREEN_SIZE);
    }

    // add asteroids from queue
    for (state.asteroids_queue.items) |asteroid| {
        try state.asteroids.append(asteroid);
    }
    state.asteroids_queue.clearRetainingCapacity();

    // Projectiles
    {
        var i: usize = 0;
        while (i < state.projectile.items.len) : (i += 1) {
            var projectile = &state.projectile.items[i];
            projectile.update(delta, SCREEN_SIZE);

            // Collision /w asteroids
            for (state.asteroids.items) |*asteroid| {
                if (asteroid.position.distance(projectile.position) < asteroid.size.hitbox()) {
                    if (!asteroid.remove) {
                        try hitAsteroid(asteroid, projectile.velocity);
                        projectile.ttl = 0;
                    }
                }
            }
            // Lazer - Collision ship not mid mega-burst
            if (!state.ship.is_using_mega_fuel and projectile.position.distance(state.ship.position) < state.ship.hitbox()) {
                if (!state.ship.isDead()) {
                    try loseLife();
                }
            }

            if (projectile.ttl <= 0) {
                _ = state.projectile.swapRemove(i);
            }
        }
    }

    // Particles
    {
        var i: usize = 0;
        while (i < state.particles.items.len) : (i += 1) {
            var particle = &state.particles.items[i];
            particle.update(delta, null);

            if (particle.ttl <= 0) {
                _ = state.particles.swapRemove(i);
            }
        }
    }

    // Asteroids
    {
        var i: usize = 0;
        while (i < state.asteroids.items.len) : (i += 1) {
            const asteroid = &state.asteroids.items[i];
            asteroid.update(SCREEN_SIZE);

            // Asteroids - Collision
            if (!state.ship.isDead() and
                !state.ship.isInvulnerable() and
                !state.ship.is_using_mega_fuel and
                asteroid.position.distance(state.ship.position) < asteroid.size.hitbox() + state.ship.hitbox())
            {
                if (!asteroid.remove) {
                    try hitAsteroid(asteroid, state.ship.velocity);
                }
                try loseLife();
            }

            if (asteroid.remove) {
                _ = state.asteroids.swapRemove(i);
            }
        }
    }

    // End Game / Death
    const respawn_time = 3.0;
    if (state.ship.isDead() and (now - state.ship.death_timestamp) > respawn_time) {
        if (state.lives <= 0) {
            try init();
        } else {
            try reset();
        }
    }
}

fn render(drawing: *const Drawing) !void {
    const now = @as(f32, @floatCast(rl.getTime()));

    // DRAW LIVES UI
    // HACK: we want to show only the number of lives remaining, so we do the -1
    if (state.lives >= 2) {
        for (0..state.lives - 1) |i| {
            const size = SHIP_SCALE / 1.5;
            drawing.drawLines(
                Vector2.init(@as(f32, @floatFromInt(i + 1)) * size * 20, 20),
                size,
                std.math.pi,
                &Ship.drawing,
                rl.Color.light_gray,
                true,
            );
        }
    }

    // DRAWING SCORE
    try drawing.drawNumber(state.score, Vector2.init(SCREEN_SIZE.x - 20, 20));

    if (!state.ship.isDead()) {
        // DRAWING SHIP'S THRUST
        if (rl.isKeyDown(.key_w)) {
            const animation_speed = 25.0;
            const sin_wave_anim = std.math.sin(now * animation_speed);
            const boost_tail_anim = state.ship.velocity.length() * 0.05 + sin_wave_anim * 0.1;
            const thrust_color = if (state.ship.is_using_mega_fuel)
                rl.Color.sky_blue
            else
                rl.Color.orange;

            drawing.drawLines(
                state.ship.position,
                SHIP_SCALE, // TODO: move to ship data?
                state.ship.rotation,
                &.{
                    Vector2.init(-0.25, -0.4),
                    Vector2.init(0.0, -0.8 - boost_tail_anim),
                    Vector2.init(0.25, -0.4),
                },
                thrust_color,
                true,
            );
        }

        // DRAWING SHIP
        drawing.drawLines(
            state.ship.position,
            SHIP_SCALE, // TODO: move to ship data?
            state.ship.rotation,
            &Ship.drawing,
            if (state.ship.isInvulnerable() and @mod(rl.getTime(), 0.25) >= 0.125) rl.Color.gray else rl.Color.white,
            true,
        );
        if (DEBUG_VIZ) {
            rl.drawCircleLinesV(
                state.ship.position,
                state.ship.hitbox(),
                rl.Color.magenta,
            );
        }
    }

    // DRAWING ASTEROIDS
    for (state.asteroids.items) |asteroid| {
        drawAsteroid(
            drawing,
            asteroid.position,
            asteroid.size,
            asteroid.seed,
        );
        if (DEBUG_VIZ) {
            rl.drawCircleLinesV(
                asteroid.position,
                asteroid.size.hitbox(),
                rl.Color.magenta,
            );
        }
    }

    // DRAWING PARTICLES
    for (state.particles.items) |particle| {
        switch (particle.values) {
            .line => |line| {
                drawing.drawLines(
                    particle.position,
                    line.length,
                    line.rotation,
                    &.{
                        Vector2.init(-0.5, 0),
                        Vector2.init(0.5, 0),
                    },
                    particle.color,
                    true,
                );
            },
            .dot => |dot| {
                rl.drawCircleV(
                    particle.position,
                    dot.radius,
                    particle.color,
                );
            },
        }
    }

    // DRAWING PORJECTILES
    for (state.projectile.items) |*projetile| {
        drawing.drawLines(
            projetile.position,
            projetile.length,
            projetile.rotation,
            &.{
                Vector2.init(0, -0.5),
                Vector2.init(0, 0.5),
            },
            rl.Color.red,
            true,
        );
    }

    // DRAWING FUEL BAR
    {
        const margin = 10;
        const padding = 5;
        const height = 150;
        const width = 50;
        // BORDER
        rl.drawRectangleLines(
            margin,
            SCREEN_SIZE.y - margin - height,
            width,
            height,
            rl.Color.white,
        );
        // FILL
        const fuel_height = (height - padding * 2) * state.ship.mega_fuel;
        rl.drawRectangle(
            margin + padding,
            @intFromFloat(SCREEN_SIZE.y - margin - padding - fuel_height),
            width - padding * 2,
            @intFromFloat(fuel_height),
            if (state.ship.canShoot()) rl.Color.sky_blue else rl.Color.dark_blue,
        );
    }
}

fn drawAsteroid(drawing: *const Drawing, pos: Vector2, size: Asteroid.Size, seed: u64) void {
    var prng = std.rand.Xoshiro256.init(seed);
    const rand = prng.random();

    var points = std
        .BoundedArray(Vector2, 16)
        .init(0) catch unreachable;
    const points_len = rand.intRangeLessThan(usize, 8, 15);

    for (0..points_len) |i| {
        const i_float: f32 = @floatFromInt(i);
        const points_len_float: f32 = @floatFromInt(points_len);
        // if we pass the threshold we decrese the radius length making this point cocave
        const radius_offset_rnd: f32 = if (rand.float(f32) < 0.2) 0.2 else 0.0;
        const radius = 0.3 + (0.2 * rand.float(f32)) - radius_offset_rnd;
        const angle = i_float *
            (std.math.tau / points_len_float) +
            (std.math.pi * 0.125 * rand.float(f32));
        points.append(mathx.Vector2.fromAngle(angle).scale(radius)) catch unreachable;
    }

    drawing.drawLines(
        pos,
        size.size(),
        0.0,
        points.slice(),
        rl.Color.brown,
        true,
    );
}

fn hitAsteroid(asteroid: *Asteroid, impact_maybe: ?Vector2) !void {
    asteroid.remove = true;
    state.ship.refill();
    state.score += asteroid.score();
    try spawnExplosionParticles(asteroid.position, rl.Color.brown);

    if (asteroid.size == .small) return;

    for (0..2) |_| {
        const dir = asteroid.velocity.normalize();
        const size = asteroid.size.getSmaller() orelse unreachable;
        try state.asteroids_queue.append(.{
            .position = asteroid.position,
            .velocity = dir
                .scale(size.velocityScale() * 3.0 * state.random.float(f32))
                .add(if (impact_maybe) |impact| impact.normalize().scale(1.5) else Vector2.zero()),
            .size = size,
            .seed = state.random.int(u64),
        });
    }
}

fn spawnExplosionParticles(origin: Vector2, color: ?rl.Color) !void {
    rl.playSound(sound.boom);
    const points_len = 100;
    for (0..points_len) |_| {
        const random_int = state.random.intRangeLessThan(usize, 0, 4);
        const p_color: rl.Color = color orelse p_color: {
            if (random_int == 1) break :p_color rl.Color.red;
            if (random_int == 2) break :p_color rl.Color.orange;
            if (random_int == 3) break :p_color rl.Color.yellow;
            break :p_color rl.Color.white;
        };
        const random_angle = std.math.tau * state.random.float(f32);
        try state.particles.append(.{
            .ttl = state.random.float(f32) * 3.0,
            .color = p_color,
            .position = origin,
            .velocity = mathx.Vector2
                .fromAngle(random_angle)
                .scale(@floatFromInt(state.random.intRangeLessThan(usize, 5, 15))),
            .values = p: {
                const random_particle_type = state.random.enumValue(std.meta.Tag(std.meta.FieldType(Particle, .values)));
                break :p switch (random_particle_type) {
                    .line => .{
                        .line = .{
                            .length = SCALE * (1 + 0.4 * state.random.float(f32)),
                            .rotation = random_angle,
                        },
                    },
                    .dot => .{
                        .dot = .{
                            .radius = state.random.float(f32) * 3.0,
                        },
                    },
                };
            },
        });
    }
}

fn getRelativePath(allocator: std.mem.Allocator, target_path: []const u8) ![:0]const u8 {
    const cwd_path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd_path);

    const path = try std.fs.path.resolve(
        allocator,
        &.{
            cwd_path,
            target_path,
        },
    );
    defer allocator.free(path);
    const path_null = try allocator.dupeZ(u8, path);
    return path_null;
}

fn loseLife() !void {
    const now: f32 = @floatCast(rl.getTime());
    state.ship.death_timestamp = now;
    rl.playSound(sound.loser);
    state.lives -= 1;
    try spawnExplosionParticles(state.ship.position, null);
}
