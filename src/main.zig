const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try parseArgs();

    var program_data = try fetchRom(alloc, args.rom_path);
    defer program_data.deinit(alloc);

    var runner = @import("StdioRunner.zig").init(alloc, program_data.items);
    defer runner.deinit();

    try runner.run();
}

const Params = struct {
    rom_path: [:0]const u8,
    socket_path: ?[:0]const u8,
};

fn parseArgs() !Params {
    var args = std.process.args();
    _ = args.next().?;
    return .{
        .rom_path = args.next() orelse return error.RomArgMissing,
        .socket_path = args.next(),
    };
}

fn fetchRom(alloc: std.mem.Allocator, path: [:0]const u8) !std.ArrayList(u16) {
    const file = try std.fs.cwd().openFileZ(path, .{});
    var collected = try std.ArrayList(u16).initCapacity(alloc, 1024);
    var buf: [1024]u8 = undefined;
    while (true) {
        const read_len = try file.read(&buf);
        if (read_len == 0) {
            break;
        }
        std.debug.assert(read_len % 2 == 0);
        const nums = @divExact(read_len, 2);
        for (0..nums) |num| {
            const pos = num * 2;
            const val = std.mem.readInt(u16, @ptrCast(buf[pos .. pos + 2]), .little);
            try collected.append(alloc, val);
        }
    }
    return collected;
}
