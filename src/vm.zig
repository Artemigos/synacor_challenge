const std = @import("std");
const utils = @import("utils.zig");

pub const VM = struct {
    alloc: std.mem.Allocator,

    memory: [1 << 15]u16 = @splat(0),
    instruction_pointer: u15 = 0,
    registers: [8]u16 = @splat(0),
    stack: std.ArrayList(u16),
    halted: bool = false,

    pub fn init(alloc: std.mem.Allocator, program_data: []const u16) !VM {
        var vm: VM = .{
            .alloc = alloc,
            .stack = try std.ArrayList(u16).initCapacity(alloc, 1024),
        };

        std.debug.assert(vm.memory.len > program_data.len);
        @memmove(vm.memory[0..program_data.len], program_data);

        return vm;
    }

    pub fn deinit(self: *VM) void {
        self.stack.deinit(self.alloc);
    }

    pub fn step(self: *VM) !void {
        const instruction = self.memory[self.instruction_pointer];
        switch (instruction) {
            19 => {
                const ascii: u8 = @truncate(try self.get_val(1));
                try utils.bufferedPrint("{c}", .{ascii});
                self.instruction_pointer += 2;
            },
            21 => {
                self.instruction_pointer += 1;
            },
            else => {
                std.log.err("unknown instruction: {}", .{instruction});
                return error.UnknownInstruction;
            },
        }
    }

    fn get_val(self: *VM, offset: u15) !u16 {
        const addr = self.instruction_pointer + offset;
        const arg = self.memory[addr];
        if (arg >= 32776) {
            std.log.err("encountered invalid number: {}", .{arg});
            return error.InvalidNumber;
        }
        if (arg >= 32768) {
            const reg = arg - 32768;
            return self.registers[reg];
        }
        return arg;
    }
};
