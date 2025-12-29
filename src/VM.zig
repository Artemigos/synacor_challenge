const std = @import("std");

pub const Instruction = enum {
    halt,
    set,
    push,
    pop,
    eq,
    gt,
    jmp,
    jt,
    jf,
    add,
    mult,
    mod,
    @"and",
    @"or",
    not,
    rmem,
    wmem,
    call,
    ret,
    out,
    in,
    noop,
};

const Self = @This();

alloc: std.mem.Allocator,

memory: [1 << 15]u16 = @splat(0),
instruction_pointer: u15 = 0,
registers: [8]u16 = @splat(0),
stack: std.ArrayList(u16),
halted: bool = false,

reader: *std.io.Reader,
writer: *std.io.Writer,

pub fn init(
    alloc: std.mem.Allocator,
    program_data: []const u16,
    reader: *std.io.Reader,
    writer: *std.io.Writer,
) !Self {
    var vm: Self = .{
        .alloc = alloc,
        .stack = try std.ArrayList(u16).initCapacity(alloc, 1024),
        .reader = reader,
        .writer = writer,
    };

    std.debug.assert(vm.memory.len > program_data.len);
    @memmove(vm.memory[0..program_data.len], program_data);

    return vm;
}

pub fn deinit(self: *Self) void {
    self.stack.deinit(self.alloc);
}

pub fn step(self: *Self) !void {
    // after self-test, set last register to valid value
    if (self.instruction_pointer == 546) {
        self.registers[7] = 25734;
    }

    // bypass teleporter calculations
    if (self.instruction_pointer == 5511) {
        self.instruction_pointer += 2; // jump over call
        self.registers[0] = 6; // expected valid result of call
    }

    const instruction = self.memory[self.instruction_pointer];
    switch (instruction) {
        0 => {
            self.halted = true;
        },
        1 => {
            const val = try self.get(2);
            try self.set(1, val);
            self.instruction_pointer += 3;
        },
        2 => {
            const val = try self.get(1);
            try self.stack.append(self.alloc, val);
            self.instruction_pointer += 2;
        },
        3 => {
            if (self.stack.pop()) |val| {
                try self.set(1, val);
                self.instruction_pointer += 2;
            } else {
                std.log.err("stack underflow", .{});
                return error.StackUnderflow;
            }
        },
        4 => {
            const l = try self.get(2);
            const r = try self.get(3);
            const result: u1 = if (l == r) 1 else 0;
            try self.set(1, result);
            self.instruction_pointer += 4;
        },
        5 => {
            const l = try self.get(2);
            const r = try self.get(3);
            const result: u1 = if (l > r) 1 else 0;
            try self.set(1, result);
            self.instruction_pointer += 4;
        },
        6 => {
            const addr: u15 = @truncate(try self.get(1));
            self.instruction_pointer = addr;
        },
        7 => {
            const cond = try self.get(1);
            if (cond != 0) {
                const addr: u15 = @truncate(try self.get(2));
                self.instruction_pointer = addr;
            } else {
                self.instruction_pointer += 3;
            }
        },
        8 => {
            const cond = try self.get(1);
            if (cond == 0) {
                const addr: u15 = @truncate(try self.get(2));
                self.instruction_pointer = addr;
            } else {
                self.instruction_pointer += 3;
            }
        },
        9 => {
            const l = try self.get(2);
            const r = try self.get(3);
            const result: u15 = @truncate(l +% r);
            try self.set(1, result);
            self.instruction_pointer += 4;
        },
        10 => {
            const l = try self.get(2);
            const r = try self.get(3);
            const result: u15 = @truncate(l *% r);
            try self.set(1, result);
            self.instruction_pointer += 4;
        },
        11 => {
            const l = try self.get(2);
            const r = try self.get(3);
            const result = l % r;
            try self.set(1, result);
            self.instruction_pointer += 4;
        },
        12 => {
            const l = try self.get(2);
            const r = try self.get(3);
            const result = l & r;
            try self.set(1, result);
            self.instruction_pointer += 4;
        },
        13 => {
            const l = try self.get(2);
            const r = try self.get(3);
            const result = l | r;
            try self.set(1, result);
            self.instruction_pointer += 4;
        },
        14 => {
            const val = try self.get(2);
            const result: u15 = @truncate(val);
            try self.set(1, ~result);
            self.instruction_pointer += 3;
        },
        15 => {
            const addr: u15 = @truncate(try self.get(2));
            const val = self.memory[addr];
            try self.set(1, val);
            self.instruction_pointer += 3;
        },
        16 => {
            const val = try self.get(2);
            const addr: u15 = @truncate(try self.get(1));
            self.memory[addr] = val;
            self.instruction_pointer += 3;
        },
        17 => {
            try self.stack.append(self.alloc, self.instruction_pointer + 2);
            const addr: u15 = @truncate(try self.get(1));
            self.instruction_pointer = addr;
        },
        18 => {
            if (self.stack.pop()) |addr| {
                self.instruction_pointer = @truncate(addr);
            } else {
                self.halted = true;
            }
        },
        19 => {
            const ascii: u8 = @truncate(try self.get(1));
            try self.writer.printAsciiChar(ascii, .{});
            try self.writer.flush();
            self.instruction_pointer += 2;
        },
        20 => {
            var buf: [1]u8 = undefined;
            const read_len = try self.reader.readSliceShort(&buf);
            if (read_len != 1) {
                std.log.err("failed to read one character", .{});
                return error.FailedToReadChar;
            }
            try self.set(1, buf[0]);
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

fn get(self: *Self, offset: u15) !u16 {
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

fn set(self: *Self, offset: u15, val: u16) !void {
    const addr = self.instruction_pointer + offset;
    const arg = self.memory[addr];
    if (arg >= 32776) {
        std.log.err("encountered invalid number: {}", .{arg});
        return error.InvalidNumber;
    }
    if (arg >= 32768) {
        const reg = arg - 32768;
        self.registers[reg] = val;
        return;
    }
    std.log.err("attempted to set non-register: {}", .{arg});
    return error.AttemptedToSetNonRegister;
}

pub fn peekInstruction(self: *Self) Instruction {
    const val = self.memory[self.instruction_pointer];
    return @enumFromInt(val);
}

pub fn snapshot(self: *Self) !Self {
    return .{
        .alloc = self.alloc,
        .memory = self.memory,
        .instruction_pointer = self.instruction_pointer,
        .registers = self.registers,
        .stack = try self.stack.clone(self.alloc),
        .halted = self.halted,
        .reader = self.reader,
        .writer = self.writer,
    };
}

pub fn eq(self: *Self, other: *Self) bool {
    if (self == other) {
        return true;
    }
    if (!std.mem.eql(u16, &self.memory, &other.memory)) {
        return false;
    }
    if (self.instruction_pointer != other.instruction_pointer) {
        return false;
    }
    if (!std.mem.eql(u16, &self.registers, &other.registers)) {
        return false;
    }
    if (self.stack.len != other.stack.len) {
        return false;
    }
    if (!std.mem.eql(u16, self.stack.items, other.stack.items)) {
        return false;
    }
    if (self.halted != other.halted) {
        return false;
    }
    return true;
}

pub fn hash(self: *Self) u64 {
    var h = std.hash.Fnv1a_64.init();
    h.update(std.mem.sliceAsBytes(&self.memory));
    h.update(&std.mem.toBytes(self.instruction_pointer));
    h.update(std.mem.sliceAsBytes(&self.registers));
    h.update(std.mem.sliceAsBytes(self.stack.items));
    h.update(&std.mem.toBytes(self.halted));
    return h.final();
}
