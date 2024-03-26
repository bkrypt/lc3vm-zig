const std = @import("std");
const win32 = @import("win32.zig");

const EnumArray = std.EnumArray;

// Registers

pub const Register = enum(u8) {
    R0,
    R1,
    R2,
    R3,
    R4,
    R5,
    R6,
    R7,
    PC,
    COND,
};

pub const ConditionFlag = enum(u8) {
    POS = 1 << 0, // P flag
    ZRO = 1 << 1, // Z flag
    NEG = 1 << 2, // N flag

    pub fn val(self: ConditionFlag) u8 {
        return @intFromEnum(self);
    }
};

pub var registers = EnumArray(Register, u16).initUndefined();

// Memory

pub const memory_max: usize = 1 << 16;
var memory: [memory_max]u16 = [_]u16{0} ** memory_max;

const MR_KBSR: u16 = 0xFE00; // keyboard status
const MR_KBDR: u16 = 0xFE02; // keyboard data

pub fn memRead(address: u16) u16 {
    if (address == MR_KBSR) {
        if (win32.checkKey()) {
            memory[MR_KBSR] = (1 << 15);
            memory[MR_KBDR] = std.io.getStdIn().reader().readByte() catch unreachable;
        } else {
            memory[MR_KBSR] = 0;
        }
    }
    return memory[address];
}

pub fn memWrite(address: u16, value: u16) void {
    memory[address] = value;
}

pub fn readImageFile(file: std.fs.File) !void {
    const origin = try file.reader().readInt(u16, .big);

    var mem_write_index: u16 = origin;
    read_loop: while (mem_write_index < memory_max) {
        memory[mem_write_index] = file.reader().readInt(u16, .big) catch |err| {
            switch (err) {
                error.EndOfStream => break :read_loop,
                else => std.os.abort(),
            }
        };

        mem_write_index += 1;
    }

    // set the PC to starting position
    registers.set(.PC, origin);
}
