const rl = @import("raylib");

pub const Particle = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    ttl: f32,

    values: union(enum) {
        line: struct {
            rotation: f32,
            length: f32,
        },
        dot: struct {
            radius: f32,
        },
    },

    pub fn update(self: *Particle, delta: f32, dim: ?rl.Vector2) void {
        // applying drag to velocity
        const drag = 0.02;
        self.velocity = self.velocity.scale(1.0 - drag);
        // applying the velocity to the position
        self.position = self.position.add(self.velocity);

        switch (self.values) {
            .dot => |*dot| {
                dot.radius *= 0.97;
            },
            .line => |*line| {
                line.length *= 0.93;
            },
        }

        // wraping the asteroid around the screen, optinal
        if (dim) |d| {
            self.position.x = @mod(self.position.x, d.x);
            self.position.y = @mod(self.position.y, d.y);
        }

        self.ttl -= delta;
    }
};
