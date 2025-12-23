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
    while (true) {
        var in_buf: [1024]u8 = undefined;
        var reader = std.io.Reader.fixed(&in_buf);
        reader.end = 0;

        var read_ops = struct {
            const S = @This();
            in_buf: []u8,
            reader: *std.io.Reader,
            fn setInputLine(
                s: *S,
                line: []const u8,
            ) void {
                var len = line.len;
                @memmove(s.in_buf[0..len], line);
                if (line[len - 1] != '\n') {
                    s.in_buf[len] = '\n';
                    len += 1;
                }
                s.reader.seek = 0;
                s.reader.end = len;
            }
        }{ .in_buf = &in_buf, .reader = &reader };

        var out_buf: [500 * 1024]u8 = undefined;
        var writer = std.io.Writer.fixed(&out_buf);

        var vm = try VM.init(
            self.alloc,
            self.program_data,
            &reader,
            &writer,
        );
        defer vm.deinit();

        var last_in: u8 = '\n';
        while (!vm.halted) {
            const next_instruction = vm.peekInstruction();
            if (next_instruction == .in and last_in == '\n') {
                var options: [15][]const u8 = undefined;
                const options_len = try extractOptions(out_buf[0..writer.end], &options);
                if (options_len > 0) {
                    const use = std.crypto.random.intRangeLessThan(usize, 0, options_len);
                    std.debug.print("PICKING OPTION: {s}\n", .{options[use]});
                    read_ops.setInputLine(options[use]);
                } else {
                    std.debug.print("LOOKING\n", .{});
                    read_ops.setInputLine("look");
                }
                writer.end = 0;
                // break;
            }
            if (next_instruction == .in) {
                last_in = (try reader.peek(1))[0];
            }
            if (next_instruction == .halt) {
                std.debug.print("EXECUTION ENDED WITH:\n{s}", .{out_buf[0..writer.end]});
            }
            try vm.step();
        }
    }
}

const known_locations = [_][]const u8{
    "Foothills",
    "Dark cave",
    "Rope bridge",
    "Falling through the air!",
    "Moss cavern",
    "Passage",
    "Twisty passages",
    "Fumbling around in the darkness",
    "Panicked and lost",
};

const known_items = [_][]const u8{
    "tablet",
    "empty lantern",
    "can",
};

fn extractOptions(data: []u8, save_to: [][]const u8) !usize {
    std.debug.print("PARSING:\n{s}", .{data});

    var reader = std.io.Reader.fixed(data);
    const at = out: while (try reader.takeDelimiter('\n')) |line| {
        if (line.len > 0 and line[0] == '=') {
            break :out line[3 .. line.len - 3];
        }
    } else return 0;
    const known = for (known_locations) |loc| {
        if (std.mem.eql(u8, loc, at)) {
            break true;
        }
    } else false;
    if (!known) {
        std.debug.print("DISCOVERED LOCATION: {s}\n", .{at});
        @panic(":)");
    }

    var found: usize = 0;
    while (try reader.takeDelimiter('\n')) |line| {
        if (std.mem.eql(u8, line, "Things of interest here:")) {
            while (try reader.takeDelimiter('\n')) |line2| {
                if (line2.len > 0 and line2[0] == '-') {
                    const item = line2[2..];
                    const known_item = for (known_items) |it| {
                        if (std.mem.eql(u8, it, item)) {
                            break true;
                        }
                    } else false;
                    if (!known_item) {
                        std.debug.print("DISCOVERED ITEM: {s}\n", .{item});
                        @panic(":D");
                    }
                    // TODO: append 'take <item>'
                } else {
                    break;
                }
            }
        } else if ((line.len >= 10 and std.mem.eql(u8, line[0..10], "There are ") and std.mem.eql(u8, line[line.len - 7 ..], " exits:")) or (line.len >= 9 and std.mem.eql(u8, line[0..9], "There is ") and std.mem.eql(u8, line[line.len - 6 ..], " exit:"))) {
            while (try reader.takeDelimiter('\n')) |line2| {
                if (line2.len > 0 and line2[0] == '-') {
                    std.debug.print("OPTION: {s}\n", .{line2[2..]});
                    save_to[found] = line2[2..];
                    found += 1;
                } else {
                    break;
                }
            }
        }
    }

    save_to[found] = "take tablet";
    found += 1;
    save_to[found] = "take empty lantern";
    found += 1;
    save_to[found] = "use tablet";
    found += 1;
    save_to[found] = "use empty lantern";
    found += 1;

    return found;
}
