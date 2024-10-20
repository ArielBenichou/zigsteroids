const std = @import("std");
const rl = @import("raylib");

pub const Vector2 = struct {
    pub fn fromAngle(angle: anytype) rl.Vector2 {
        const T = @TypeOf(angle);
        switch (@typeInfo(T)) {
            .Float, .ComptimeFloat => return rl.Vector2.init(
                std.math.cos(angle),
                std.math.sin(angle),
            ),
            else => @compileError("Input must be float."),
        }
    }
};
