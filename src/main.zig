const std = @import("std");
const mathx = @import("mathx.zig");
const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Drawing = @import("drawing.zig").Drawing;
const State = @import("state.zig").State;
const Asteroid = @import("asteroid.zig").Asteroid;
const Particle = @import("particle.zig").Particle;
const constants = @import("constants.zig");

const SCREEN_SIZE = constants.SCREEN_SIZE;
const SCALE = constants.SCALE;
const LINE_THICKNESS = constants.LINE_THICKNESS;
const CAMERA_SCALE = constants.CAMERA_SCALE;
const SHIP_SCALE = constants.SHIP_SCALE;
var DEBUG_VIZ = false;

var state: State = undefined;

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
    //--------------------------------------------------------------------------------------

    const seed: u64 = @bitCast(std.time.timestamp());
    std.debug.print("[GAME] Seed: {}", .{seed});
    var prng = std.rand.Xoshiro256.init(seed);

    state = .{
        .ship = undefined,
        .asteroids = std.ArrayList(Asteroid).init(allocator),
        .particles = std.ArrayList(Particle).init(allocator),
        .random = prng.random(),
    };
    defer state.asteroids.deinit();
    defer state.particles.deinit();

    const drawing = Drawing{
        .line_thickness = LINE_THICKNESS,
        .base_scale = CAMERA_SCALE,
    };

    try reset();

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        try update();

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        render(&drawing);
        //----------------------------------------------------------------------------------
    }
}

fn reset() !void {
    state.ship = .{
        .position = SCREEN_SIZE.scale(0.5),
        .speed_turn = 1 * SCALE,
        .speed_forward = 24 * SCALE,
    };

    state.asteroids.clearRetainingCapacity();
    state.particles.clearRetainingCapacity();

    const asteroids_count = 20;
    for (0..asteroids_count) |_| {
        const random_angle = std.math.tau * state.random.float(f32);
        const size = state.random.enumValue(Asteroid.Size);
        try state.asteroids.append(.{
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

fn update() !void {
    const now = @as(f32, @floatCast(rl.getTime()));
    const delta: f32 = @floatCast(rl.getFrameTime());

    // Ship Contorl
    if (rl.isKeyDown(.key_a)) {
        state.ship.turn(-1 * delta);
    }

    if (rl.isKeyDown(.key_d)) {
        state.ship.turn(delta);
    }

    if (rl.isKeyDown(.key_w)) {
        state.ship.addThrust(delta, rl.isKeyDown(.key_b));
    }

    state.ship.update(delta, SCREEN_SIZE);

    // Asteroids
    for (state.asteroids.items) |*asteroid| {
        asteroid.update(SCREEN_SIZE);

        // Collision /w ship not mid mega-burst
        if (!state.ship.is_using_mega_fuel and asteroid.position.distance(state.ship.position) < asteroid.size.hitbox()) {
            if (!state.ship.isDead()) {
                state.ship.death_timestamp = now;
                try spawnDeathParticles();
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

    // End Game / Death
    if (state.ship.isDead() and (now - state.ship.death_timestamp) > 3.0) {
        try reset();
    }
}

fn render(drawing: *const Drawing) void {
    const now = @as(f32, @floatCast(rl.getTime()));
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
            );
        }

        // DRAWING SHIP
        drawing.drawLines(
            state.ship.position,
            SHIP_SCALE, // TODO: move to ship data?
            state.ship.rotation,
            &.{
                Vector2.init(0.0, 0.5),
                Vector2.init(-0.4, -0.5),
                Vector2.init(-0.3, -0.4),
                Vector2.init(0.3, -0.4),
                Vector2.init(0.4, -0.5),
            },
            if (state.ship.isDead() and DEBUG_VIZ) rl.Color.magenta else rl.Color.white,
        );
        if (DEBUG_VIZ) {
            rl.drawCircleV(
                state.ship.position,
                SHIP_SCALE,
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

    // PARTICLES
    for (state.particles.items) |particle| {
        const random_int = state.random.intRangeLessThan(usize, 0, 4);
        const color: rl.Color = p_color: {
            if (random_int == 1) break :p_color rl.Color.red;
            if (random_int == 2) break :p_color rl.Color.orange;
            if (random_int == 3) break :p_color rl.Color.yellow;
            break :p_color rl.Color.white;
        };

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
                    color,
                );
            },
            .dot => |dot| {
                rl.drawCircleV(
                    particle.position,
                    dot.radius,
                    color,
                );
            },
        }
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
            rl.Color.sky_blue,
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
    );
}

fn spawnDeathParticles() !void {
    const points_len = 100;
    for (0..points_len) |_| {
        const random_angle = std.math.tau * state.random.float(f32);
        try state.particles.append(.{
            .ttl = state.random.float(f32) * 3.0,
            .position = state.ship.position,
            .velocity = mathx.Vector2
                .fromAngle(random_angle)
                .scale(@floatFromInt(state.random.intRangeLessThan(usize, 5, 15))),
            .values = p: {
                if (state.random.boolean()) {
                    break :p .{
                        .line = .{
                            .length = SCALE * (1 + 0.4 * state.random.float(f32)),
                            .rotation = random_angle,
                        },
                    };
                } else {
                    break :p .{ .dot = .{
                        .radius = state.random.float(f32) * 3.0,
                    } };
                }
            },
        });
    }
}
