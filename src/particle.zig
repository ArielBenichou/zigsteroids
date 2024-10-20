const rl = @import("raylib");

pub const ParticleCommon = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    ttl: f32,

    pub fn update(self: *@This(), delta: f32, dim: ?rl.Vector2) void {
        // applying drag to velocity
        const drag = 0.02;

        self.velocity = self.velocity.scale(1.0 - drag);
        // applying the velocity to the position
        self.position = self.position.add(self.velocity);

        // wraping the asteroid around the screen, optinal
        if (dim) |d| {
            self.position.x = @mod(self.position.x, d.x);
            self.position.y = @mod(self.position.y, d.y);
        }

        self.ttl -= delta;
    }
};

const LineParticle = struct {
    common: ParticleCommon,
    rotation: f32,
    length: f32,

    pub fn update(self: *@This(), delta: f32, dim: ?rl.Vector2) void {
        self.common.update(delta, dim);
        self.length *= 0.93;
    }
};

const DotParticle = struct {
    common: ParticleCommon,
    radius: f32,

    pub fn update(self: *@This(), delta: f32, dim: ?rl.Vector2) void {
        self.common.update(delta, dim);
        self.radius *= 0.97;
    }
};

pub const Particle = union(enum) {
    line: LineParticle,
    dot: DotParticle,

    pub fn update(self: *@This(), delta: f32, dim: ?rl.Vector2) void {
        switch (self) {
            .dot => |*dot| dot.update(delta, dim),
            .line => |*line| line.update(delta, dim),
            else => unreachable,
        }
    }
};
