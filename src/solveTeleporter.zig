const std = @import("std");

const WithMemoization = struct {
    alloc: std.mem.Allocator,
    cache: []?u15,

    fn init(alloc: std.mem.Allocator) !WithMemoization {
        const size = 5 * (2 << 15) * (2 << 15);
        return .{
            .alloc = alloc,
            .cache = try alloc.alloc(?u15, size),
        };
    }

    fn deinit(self: *WithMemoization) void {
        self.alloc.free(self.cache);
    }

    fn call(self: *WithMemoization, r0: u15, r1: u15, r7: u15) u15 {
        const k: usize = (@as(usize, r0) << 30) | (@as(usize, r1) << 15) | r7;
        const result = self.cache[k];
        if (result) |val| {
            return val;
        } else {
            const calculated = self.reimpl(r0, r1, r7);
            self.cache[k] = calculated;
            return calculated;
        }
    }

    fn reimpl(self: *WithMemoization, r0: u15, r1: u15, r7: u15) u15 {
        if (r0 == 0) {
            return r1 +% 1;
        }
        if (r1 == 0) {
            return self.call(r0 -% 1, r7, r7);
        }
        const new_r1 = self.call(r0, r1 -% 1, r7);
        return self.call(r0 -% 1, new_r1, r7);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var calc = try WithMemoization.init(alloc);
    defer calc.deinit();

    const max = std.math.maxInt(u15);
    for (1..max + 1) |i| {
        const result = calc.call(4, 1, @truncate(i));
        std.debug.print("{}/{} -> {}\n", .{ i, max, result });
        if (result == 6) {
            std.debug.print("found solution: {}\n", .{i});
            break;
        }
    }
}
