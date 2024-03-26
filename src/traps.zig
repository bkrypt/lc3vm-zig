const std = @import("std");
const mem = @import("mem.zig");

// Traps

pub const Trapcode = enum(u8) {
    GETC = 0x20, // get character from keyboard, not echoed onto console
    OUT = 0x21, // output a character
    PUTS = 0x22, // output a word string
    IN = 0x23, // get character from keyboard, echoed onto console
    PUTSP = 0x24, // output a byte string
    HALT = 0x25, // halt the program

    pub fn from(val: u16) Trapcode {
        return @enumFromInt(val);
    }
};

pub fn getcTrap() void {
    const stdin = std.io.getStdIn();
    const char = stdin.reader().readByte() catch unreachable;

    mem.registers.set(.R0, @as(u16, char));
}

// test "getcTrap" {
//     getcTrap();
//     std.debug.print("{c}\n", .{@as(u8, @intCast(mem.registers.get(.R0)))});
// }

pub fn outTrap() void {
    const stdout = std.io.getStdOut();
    const str_long: u16 = mem.registers.get(.R0);

    const str_char: u8 = @truncate(str_long);
    stdout.writer().writeByte(str_char) catch unreachable;
}

// test "outTrap" {
//     mem.registers.set(.R0, '\n');
//     outTrap();
// }

pub fn putsTrap() void {
    const stdout = std.io.getStdOut();
    const str_start_address: u16 = mem.registers.get(.R0);

    var read_offset: u16 = 0;
    var str_long: u16 = mem.memRead(str_start_address);
    while (str_long != 0) {
        const str_char: u8 = @truncate(str_long);
        stdout.writer().writeByte(str_char) catch unreachable;

        read_offset += 1;
        str_long = mem.memRead(str_start_address + read_offset);
    }
}

// test "putsTrap" {
//     memory[0x3000] = 'Z';
//     memory[0x3001] = 'o';
//     memory[0x3002] = '\n';
//     memory[0x3003] = 0x0;
//     mem.registers.set(.R0, 0x3000);
//     putsTrap();
// }

pub fn inTrap() void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    stdout.writeAll("Enter a character: ") catch unreachable;
    const char: u8 = stdin.reader().readByte() catch unreachable;
    stdout.writer().writeByte(char) catch unreachable;

    mem.registers.set(.R0, @as(u16, char));
}

// test "inTrap" {
//     inTrap();
//     try std.testing.expectEqual('a', mem.registers.get(.R0));
// }

pub fn putspTrap() void {
    const stdout = std.io.getStdOut();
    const str_start_address: u16 = mem.registers.get(.R0);

    var read_offset: u16 = 0;
    var str_long: u16 = mem.memRead(str_start_address);

    while (str_long != 0) {
        const str_char_low: u8 = @truncate(str_long & 0xFF);
        stdout.writer().writeByte(str_char_low) catch unreachable;

        const str_char_high: u8 = @truncate(str_long >> 8);
        if (str_char_high != 0)
            stdout.writer().writeByte(str_char_high) catch unreachable;

        read_offset += 1;
        str_long = mem.memRead(str_start_address + read_offset);
    }
}

// test "putspTrap" {
//     memory[0x3000] = 'a' << 8 | 'b';
//     mem.registers.set(.R0, 0x3000);
//     putspTrap();
// }

pub fn haltTrap() void {
    std.io.getStdOut().writeAll("\nHALT\n") catch unreachable;
    std.os.exit(0);
}

// test "haltTrap" {
//     haltTrap();
// }
