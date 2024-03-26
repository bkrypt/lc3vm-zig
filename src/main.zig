const std = @import("std");
const win32 = @import("win32.zig");
const mem = @import("mem.zig");
const ops = @import("ops.zig");
const traps = @import("traps.zig");

const c = @cImport({
    @cInclude("signal.h");
});

const ConditionFlag = mem.ConditionFlag;
const Opcode = ops.Opcode;
const Trapcode = traps.Trapcode;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    _ = c.signal(c.SIGINT, win32.handleInterrupt);
    win32.disableInputBuffering();

    // Process arguments

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next() orelse std.os.exit(1);
    // TODO: must be a relative file path for now
    const image_file_path_relative = args.next() orelse {
        try std.io.getStdErr().writer().print("Usage: lc3vm <relative_image_file_path>\n", .{});
        std.os.exit(0);
    };

    // Read image file into memory

    const rom_file = try std.fs.cwd().openFile(image_file_path_relative, .{ .mode = .read_only });
    defer rom_file.close();

    try mem.readImageFile(rom_file);

    // since exactly one condition flag should be set any given time, set the Z flag
    mem.registers.set(.COND, ConditionFlag.ZRO.val());

    while (true) {
        // fetch
        const pc = mem.registers.get(.PC);
        mem.registers.set(.PC, pc + 1);

        const instruction = mem.memRead(pc);
        const op = Opcode.from(instruction >> 12);

        switch (op) {
            .ADD => ops.addOp(instruction),
            .AND => ops.andOp(instruction),
            .NOT => ops.notOp(instruction),
            .BR => ops.brOp(instruction),
            .JMP => ops.jmpOp(instruction),
            .JSR => ops.jsrOp(instruction),
            .LD => ops.ldOp(instruction),
            .LDI => ops.ldiOp(instruction),
            .LDR => ops.ldrOp(instruction),
            .LEA => ops.leaOp(instruction),
            .ST => ops.stOp(instruction),
            .STI => ops.stiOp(instruction),
            .STR => ops.strOp(instruction),
            .TRAP => {
                mem.registers.set(.R7, mem.registers.get(.PC));
                const trap = Trapcode.from(instruction & 0xFF);

                switch (trap) {
                    .GETC => traps.getcTrap(),
                    .OUT => traps.outTrap(),
                    .PUTS => traps.putsTrap(),
                    .IN => traps.inTrap(),
                    .PUTSP => traps.putspTrap(),
                    .HALT => traps.haltTrap(),
                }
            },
            .RES, .RTI => return error.badOpcode,
        }
    }

    win32.restoreInputBuffering();
}
