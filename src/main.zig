const std = @import("std");
const VM = @import("vm.zig").VM;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var program_data = try fetchRom(alloc);
    var vm = try VM.init(alloc, program_data.items);
    defer vm.deinit();
    program_data.deinit(alloc);

    while (!vm.halted) {
        try vm.step();
    }
}

pub fn fetchRom(alloc: std.mem.Allocator) !std.ArrayList(u16) {
    var args = std.process.args();
    _ = args.next().?;
    if (args.next()) |path| {
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
    } else {
        return error.RomArgMissing;
    }
}
