const std = @import("std");
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
        connect: bool,
    ) void {
        const bound = if (connect) points.len else (points.len - 1);
        for (0..bound) |i| {
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

    /// note that the position is assume to be the end position, we draw the number backward...
    pub fn drawNumber(self: *const Drawing, n: usize, position: rl.Vector2) !void {
        // zig fmt: off
        const NUMBER_LINES = [10][]const [2]f32{
            &.{ .{ 0,   0 }, .{ 1,   0   }, .{ 1, 1   }, .{ 0, 1   }, .{ 0, 0  }                                         }, // 0
            &.{ .{ 0.5, 0 }, .{ 0.5, 1   }                                                                               }, // 1
            &.{ .{ 0,   1 }, .{ 1,   1   }, .{ 1, 0.5 }, .{ 0, 0.5 }, .{ 0, 0   }, .{ 1, 0   }                           }, // 2
            &.{ .{ 0,   1 }, .{ 1,   1   }, .{ 1, 0.5 }, .{ 0, 0.5 }, .{ 1, 0.5 }, .{ 1, 0   }, .{ 0, 0   }              }, // 3
            &.{ .{ 0,   1 }, .{ 0,   0.5 }, .{ 1, 0.5 }, .{ 1, 1   }, .{ 1, 0   }                                        }, // 4
            &.{ .{ 1,   1 }, .{ 0,   1   }, .{ 0, 0.5 }, .{ 1, 0.5 }, .{ 1, 0   }, .{ 0, 0   }                           }, // 5
            &.{ .{ 0,   1 }, .{ 0,   0   }, .{ 1, 0   }, .{ 1, 0.5 }, .{ 0, 0.5 }                                        }, // 6
            &.{ .{ 0,   1 }, .{ 1,   1   }, .{ 1, 0   }                                                                  }, // 7
            &.{ .{ 0,   0 }, .{ 1,   0   }, .{ 1, 1   }, .{ 0, 1   }, .{ 0, 0.5 }, .{ 1, 0.5 }, .{ 0, 0.5 }, .{ 0, 0   } }, // 8
            &.{ .{ 1,   0 }, .{ 1,   1   }, .{ 0, 1   }, .{ 0, 0.5 }, .{ 1, 0.5 }                                        }, // 9
        };
        // zig fmt: on
        var digits: usize = if (n == 0) 1 else 0;
        var value = n;
        while (value > 0) : (value /= 10) {
            digits += 1;
        }

        value = n;
        for (0..digits) |i| {
            var points = try std.BoundedArray(rl.Vector2, 16).init(0);
            for (NUMBER_LINES[value % 10]) |p| {
                try points.append(Vector2.init(p[0] - 0.5, (1.0 - p[1]) - 0.5));
            }
            const size: f32 = self.base_scale * 0.075;
            self.drawLines(
                position.subtract(.{ .x = @as(f32, @floatFromInt(i)) * self.base_scale * 2, .y = 0 }),
                size,
                0,
                points.slice(),
                rl.Color.white,
                false,
            );
            value /= 10;
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
