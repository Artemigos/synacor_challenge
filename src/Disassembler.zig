const std = @import("std");

const Self = @This();

const OpSpec = struct {
    args: usize,
    name: []const u8,
};

const ops = [_]OpSpec{
    .{ .args = 0, .name = "halt" },
    .{ .args = 2, .name = "set" },
    .{ .args = 1, .name = "push" },
    .{ .args = 1, .name = "pop" },
    .{ .args = 3, .name = "eq" },
    .{ .args = 3, .name = "gt" },
    .{ .args = 1, .name = "jmp" },
    .{ .args = 2, .name = "jt" },
    .{ .args = 2, .name = "jf" },
    .{ .args = 3, .name = "add" },
    .{ .args = 3, .name = "mult" },
    .{ .args = 3, .name = "mod" },
    .{ .args = 3, .name = "and" },
    .{ .args = 3, .name = "or" },
    .{ .args = 2, .name = "not" },
    .{ .args = 2, .name = "rmem" },
    .{ .args = 2, .name = "wmem" },
    .{ .args = 1, .name = "call" },
    .{ .args = 0, .name = "ret" },
    .{ .args = 1, .name = "out" },
    .{ .args = 1, .name = "in" },
    .{ .args = 0, .name = "noop" },
};

pub fn disassemble(program_data: []u16, writer: *std.io.Writer) !void {
    var ip: usize = 0;
    while (ip < program_data.len) {
        const op = program_data[ip];
        if (op <= 21) {
            const spec = ops[op];
            try writer.print("{d:7}: ", .{ip});
            try writer.writeAll(spec.name);
            for (0..spec.args) |i| {
                const val = program_data[ip + 1 + i];
                if (val >= 32776) {
                    std.log.err("encountered invalid number: {}", .{val});
                    return error.InvalidNumber;
                }
                if (val >= 32768) {
                    const reg: u8 = @truncate(val - 32768);
                    try writer.writeAll(" r");
                    try writer.writeByte(reg + '0');
                } else {
                    try writer.print(" #{}", .{val});
                }
            }
            try writer.writeByte('\n');
            ip += 1 + spec.args;
        } else {
            const val = program_data[ip];
            try writer.print("{d:7}: {}\n", .{ ip, val });
            ip += 1;
        }
    }

    try writer.flush();
}
