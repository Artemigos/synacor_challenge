const std = @import("std");
const VM = @import("VM.zig");

const Self = @This();

alloc: std.mem.Allocator,
program_data: []u16,

path: ?[]const u8 = null,
server: ?std.net.Server = null,
connection: ?std.net.Server.Connection = null,

input_buf: [1024 * 1024]u8 = undefined,
input_reader: std.io.Reader = std.io.Reader.fixed(&[0]u8{}),

pub fn init(alloc: std.mem.Allocator, program_data: []u16) Self {
    var result: Self = .{
        .alloc = alloc,
        .program_data = program_data,
    };
    result.input_reader.buffer = &result.input_buf;
    return result;
}

pub fn deinit(self: *Self) void {
    if (self.connection) |conn| {
        conn.stream.close();
        self.connection = null;
    }
    if (self.server) |_| {
        self.server.?.deinit();
        self.server = null;
    }
    if (self.path) |p| {
        std.posix.unlink(p) catch {};
        self.path = null;
    }
}

pub fn startSocket(self: *Self, path: []const u8) !void {
    const address = try std.net.Address.initUnix(path);
    errdefer std.posix.unlink(path) catch {};
    const server = try address.listen(.{});
    self.path = path;
    self.server = server;
}

pub fn run(self: *Self) !void {
    var out_buf: [64]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buf);

    var vm = try VM.init(
        self.alloc,
        self.program_data,
        &self.input_reader,
        &stdout.interface,
    );
    defer vm.deinit();
    try self.waitForDebugger();

    var conn = self.connection.?;
    try self.printHeadsUp(&vm);
    var buf: [128]u8 = undefined;
    var reader = conn.stream.reader(&buf);
    const iface = reader.interface();

    while (try iface.takeDelimiter('\n')) |line| {
        if (line.len == 0) {
            try vm.step();
            try self.printHeadsUp(&vm);
        } else if (std.mem.eql(u8, line, "reg")) {
            for (vm.registers, 0..) |val, i| {
                try self.print("reg{}: {}\n", .{ i, val });
            }
        } else if (std.mem.eql(u8, line, "stack")) {
            try self.print("stack size: {}\nitems:\n", .{vm.stack.items.len});
            var iter = std.mem.reverseIterator(vm.stack.items);
            while (iter.next()) |val| {
                try self.print("{}\n", .{val});
            }
        } else if (std.mem.eql(u8, line, "c")) {
            while (!vm.halted) {
                try vm.step();
            }
        } else {
            try self.print("unknown command\n", .{});
        }
    }
}

pub fn waitForDebugger(self: *Self) !void {
    if (self.connection != null) {
        return error.AlreadyConnected;
    }
    if (self.server) |_| {
        std.log.info("waiting for the debugger...", .{});
        self.connection = try self.server.?.accept();
    }
}

fn printHeadsUp(self: *Self, vm: *VM) !void {
    const next_instruction = vm.peekInstruction();
    const instruction_name = std.enums.tagName(@TypeOf(next_instruction), next_instruction);
    try self.print("next: {s}\n", .{instruction_name.?});
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    if (self.connection) |conn| {
        var buf: [128]u8 = undefined;
        var writer = conn.stream.writer(&buf);
        try writer.interface.print(fmt, args);
        try writer.interface.flush();
    }
}
