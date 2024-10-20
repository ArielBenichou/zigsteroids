const rl = @import("raylib");

pub const Projectile = struct {
    position: rl.Vector2,
    length: f32,
    rotation: f32,
    velocity: rl.Vector2,
    ttl: f32,

    pub fn update(self: *@This(), delta: f32, dim: ?rl.Vector2) void {
        // applying the velocity to the position
        self.position = self.position.add(self.velocity);
        self.length *= 0.98;

        // wraping the asteroid around the screen, optinal
        if (dim) |d| {
            self.position.x = @mod(self.position.x, d.x);
            self.position.y = @mod(self.position.y, d.y);
        }

        self.ttl -= delta;
    }
};
