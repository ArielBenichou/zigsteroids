const rl = @import("raylib");
const Vector2 = rl.Vector2;

pub const Drawing = struct {
    line_thickness: f32,
    base_scale: f32,

    pub fn drawLines(
        self: *const Drawing,
        origin: Vector2,
        scale: f32,
        rotation: f32,
        points: []const Vector2,
        color: rl.Color,
    ) void {
        for (0..points.len) |i| {
            rl.drawLineEx(
                self.transform(
                    points[i],
                    origin,
                    scale,
                    rotation,
                ),
                self.transform(
                    points[(i + 1) % points.len],
                    origin,
                    scale,
                    rotation,
                ),
                self.line_thickness,
                color,
            );
        }
    }

    fn transform(
        self: Drawing,
        v: Vector2,
        origin: Vector2,
        scale: f32,
        rotation: f32,
    ) Vector2 {
        return v
            .scale(scale * self.base_scale)
            .rotate(rotation)
            .add(origin);
    }
};
