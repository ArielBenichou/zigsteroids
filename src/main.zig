const std = @import("std");
const math = std.math;
const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Drawing = @import("drawing.zig").Drawing;
const State = @import("state.zig").State;
const Asteroid = @import("asteroid.zig").Asteroid;
const constants = @import("constants.zig");

const SCREEN_SIZE = constants.SCREEN_SIZE;
const SCALE = constants.SCALE;
const LINE_THICKNESS = constants.LINE_THICKNESS;
const CAMERA_SCALE = constants.CAMERA_SCALE;
const BASE_SCALE = constants.BASE_SCALE;

var state: State = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    //--------------------------------------------------------------------------------------
    rl.initWindow(
        SCREEN_SIZE.x,
        SCREEN_SIZE.y,
        "zigsteroids",
    );
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const seed = 1234;
    var prng = std.rand.Xoshiro256.init(seed);

    state = .{
        // TODO: create a Ship.init() function that get the base scale mod, to scale the physics by it
        .ship = .{
            .position = SCREEN_SIZE.scale(0.5),
            .speed_turn = 1 * SCALE,
            .speed_forward = 24 * SCALE,
        },
        .asteroids = std.ArrayList(Asteroid).init(allocator),
        .random = prng.random(),
    };
    defer state.asteroids.deinit();

    const drawing = Drawing{
        .line_thickness = LINE_THICKNESS,
        .base_scale = CAMERA_SCALE,
    };

    try initLevel();

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        update();

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        render(&drawing);
        //----------------------------------------------------------------------------------
    }
}

fn initLevel() !void {
    for (0..10) |_| {
        try state.asteroids.append(.{
            .position = Vector2.init(
                state.random.float(f32) * SCREEN_SIZE.x,
                state.random.float(f32) * SCREEN_SIZE.y,
            ),
            .size = .big,
            .velocity = 0,
            .seed = state.random.int(u64),
        });
    }
}

fn update() void {
    const delta: f32 = @floatCast(rl.getFrameTime());
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
}

fn render(drawing: *const Drawing) void {
    // DRAWING SHIP'S THRUST
    if (rl.isKeyDown(.key_w)) {
        const animation_speed = 25.0;
        const sin_wave_anim = math.sin(@as(f32, @floatCast(rl.getTime())) * animation_speed);
        const boost_tail_anim = state.ship.velocity.length() * 0.05 + sin_wave_anim * 0.1;
        const thrust_color = if (rl.isKeyDown(.key_b) and state.ship.mega_fuel > 0.0) rl.Color.sky_blue else rl.Color.orange;

        drawing.drawLines(
            state.ship.position,
            BASE_SCALE, // TODO: move to ship data?
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
        BASE_SCALE, // TODO: move to ship data?
        state.ship.rotation,
        &.{
            Vector2.init(0.0, 0.5),
            Vector2.init(-0.4, -0.5),
            Vector2.init(-0.3, -0.4),
            Vector2.init(0.3, -0.4),
            Vector2.init(0.4, -0.5),
        },
        rl.Color.white,
    );

    // DRAWING ASTEROIDS
    for (state.asteroids.items) |asteroid| {
        drawAsteroid(drawing, asteroid.position, asteroid.size, asteroid.seed);
    }
}

fn drawAsteroid(drawing: *const Drawing, pos: Vector2, size: Asteroid.Size, seed: u64) void {
    var prng = std.rand.Xoshiro256.init(seed);
    const rand = prng.random();

    var points = std.BoundedArray(Vector2, 16).init(0) catch unreachable;
    const points_len = rand.intRangeLessThan(usize, 8, 15);

    for (0..points_len) |i| {
        const i_float: f32 = @floatFromInt(i);
        const points_len_float: f32 = @floatFromInt(points_len);
        // if we pass the threshold we decrese the radius length making this point cocave
        const radius_offset_rnd: f32 = if (rand.float(f32) < 0.2) 0.2 else 0.0;
        const radius = 0.3 + (0.2 * rand.float(f32)) - radius_offset_rnd;
        const angle = i_float * (math.tau / points_len_float) + (math.pi * 0.125 * rand.float(f32));
        points.append(
            Vector2.init(
                math.cos(angle),
                math.sin(angle),
            ).scale(radius),
        ) catch unreachable;
    }

    drawing.drawLines(
        pos,
        size.size(),
        0.0,
        points.slice(),
        rl.Color.brown,
    );
}
