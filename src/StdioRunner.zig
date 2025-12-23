const std = @import("std");
const VM = @import("VM.zig");

const Self = @This();

alloc: std.mem.Allocator,
program_data: []u16,

pub fn init(alloc: std.mem.Allocator, program_data: []u16) Self {
    return .{
        .alloc = alloc,
        .program_data = program_data,
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn run(self: *Self) !void {
    var in_buf: [64]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&in_buf);

    var out_buf: [64]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buf);

    var vm = try VM.init(
        self.alloc,
        self.program_data,
        &stdin.interface,
        &stdout.interface,
    );
    defer vm.deinit();

    while (!vm.halted) {
        try vm.step();
    }
}
