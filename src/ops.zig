const std = @import("std");
const mem = @import("mem.zig");

const Register = mem.Register;
const ConditionFlag = mem.ConditionFlag;

// Instructions

pub const Opcode = enum(u8) {
    BR, // branch
    ADD, // add
    LD, // load
    ST, // store
    JSR, // jump register
    AND, // bitwise and
    LDR, // load register
    STR, // store register
    RTI, // ununsed
    NOT, // bitwise not
    LDI, // load indirect
    STI, // store indirect
    JMP, // jump
    RES, // reserved (unused)
    LEA, // load effective address
    TRAP, // execute trap

    pub fn from(val: u16) Opcode {
        return @enumFromInt(val);
    }
};

fn signExtend(x: u16, bit_count: u4) u16 {
    if ((x >> (bit_count - 1)) & 1 == 1) {
        return x | @as(u16, 0xFFFF) << bit_count;
    }
    return x;
}

test "signExtend" {
    const one: u16 = 0x0001;
    try std.testing.expectEqual(1, signExtend(one, 3));
    try std.testing.expectEqual(0xFFF8, signExtend(0x0018, 5));
}

fn updateFlags(register: Register) void {
    const register_value = mem.registers.get(register);

    if (register_value == 0) {
        mem.registers.set(.COND, ConditionFlag.ZRO.val());
    } else if (register_value >> 15 == 1) { // a 1 in the left-most bit indicates negative
        mem.registers.set(.COND, ConditionFlag.NEG.val());
    } else {
        mem.registers.set(.COND, ConditionFlag.POS.val());
    }
}

test "updateFlags" {
    // R0 = 0
    mem.registers.set(.R0, 0x0);
    updateFlags(.R0);
    try std.testing.expectEqual(mem.registers.get(.COND), ConditionFlag.ZRO.val());
    // R1 = 1
    mem.registers.set(.R1, 0x1);
    updateFlags(.R1);
    try std.testing.expectEqual(mem.registers.get(.COND), ConditionFlag.POS.val());
    // R2 = -1
    mem.registers.set(.R2, 0xFFFF);
    updateFlags(.R2);
    try std.testing.expectEqual(mem.registers.get(.COND), ConditionFlag.NEG.val());
}

pub fn addOp(instruction: u16) void {
    const dr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const sr1: Register = @enumFromInt((instruction >> 6) & 0x7);
    const imm_flag: u16 = (instruction >> 5) & 0x1;

    if (imm_flag == 1) {
        const sr1_val: u16 = mem.registers.get(sr1);
        const imm5: u16 = signExtend(instruction & 0x1F, 5);

        mem.registers.set(dr, sr1_val +% imm5);
    } else {
        const sr2: Register = @enumFromInt(instruction & 0x7);
        const sr1_val: u16 = mem.registers.get(sr1);
        const sr2_val: u16 = mem.registers.get(sr2);

        mem.registers.set(dr, sr1_val +% sr2_val);
    }

    updateFlags(dr);
}

test "addOp" {
    // Add [R1] + [R2] store in R0
    mem.registers.set(.R1, 2);
    mem.registers.set(.R2, 3);
    addOp(0b0001_000_001_0_00_010);
    try std.testing.expectEqual(5, mem.registers.get(.R0));
    try std.testing.expectEqual(ConditionFlag.POS.val(), mem.registers.get(.COND));

    // Add [R3] + [R4] store in R7
    mem.registers.set(.R3, 1);
    mem.registers.set(.R4, 0xFFFF);
    addOp(0b0001_111_011_0_00_100);
    try std.testing.expectEqual(0, mem.registers.get(.R7));
    try std.testing.expectEqual(ConditionFlag.ZRO.val(), mem.registers.get(.COND));

    // Add [R6] + imm5 (32) store in R5
    mem.registers.set(.R6, 17);
    addOp(0b0001_101_110_1_01111);
    try std.testing.expectEqual(32, mem.registers.get(.R5));
    try std.testing.expectEqual(ConditionFlag.POS.val(), mem.registers.get(.COND));

    // Add [R7] + imm5 (-1) store in R1
    mem.registers.set(.R7, 0);
    addOp(0b0001_001_111_1_10001);
    try std.testing.expectEqual(0xFFF1, mem.registers.get(.R1));
    try std.testing.expectEqual(ConditionFlag.NEG.val(), mem.registers.get(.COND));
}

pub fn andOp(instruction: u16) void {
    const dr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const sr1: Register = @enumFromInt((instruction >> 6) & 0x7);
    const imm_flag: u16 = (instruction >> 5) & 0x1;

    if (imm_flag == 1) {
        const sr1_val: u16 = mem.registers.get(sr1);
        const imm5: u16 = signExtend(instruction & 0x1F, 5);

        mem.registers.set(dr, sr1_val & imm5);
    } else {
        const sr2: Register = @enumFromInt(instruction & 0x7);
        const sr1_val: u16 = mem.registers.get(sr1);
        const sr2_val: u16 = mem.registers.get(sr2);

        mem.registers.set(dr, sr1_val & sr2_val);
    }

    updateFlags(dr);
}

test "andOp" {
    // Bit-wise AND [R1] & imm5 (0b01010) store in R0
    mem.registers.set(.R1, 0xFFFF);
    andOp(0b0101_000_001_1_01010);
    try std.testing.expectEqual(0xA, mem.registers.get(.R0));
    try std.testing.expectEqual(ConditionFlag.POS.val(), mem.registers.get(.COND));

    // Bit-wise AND [R2] & imm5 (0b10101) store in R3
    mem.registers.set(.R2, 0xFFFF);
    andOp(0b0101_011_010_1_10101);
    try std.testing.expectEqual(0xFFF5, mem.registers.get(.R3));
    try std.testing.expectEqual(ConditionFlag.NEG.val(), mem.registers.get(.COND));

    // Bit-wise AND [R4] & [R5] store in R6
    mem.registers.set(.R4, 0xAAAA);
    mem.registers.set(.R5, 0x5555);
    andOp(0b0101_110_100_0_00_101);
    try std.testing.expectEqual(0x0, mem.registers.get(.R6));
    try std.testing.expectEqual(ConditionFlag.ZRO.val(), mem.registers.get(.COND));
}

pub fn brOp(instruction: u16) void {
    const nzp: u16 = (instruction >> 9) & 0x7;
    const last_op_flag: ConditionFlag = @enumFromInt(mem.registers.get(.COND));

    if (nzp == 0x7 or
        ((nzp & 0b100) != 0 and last_op_flag == .NEG) or
        ((nzp & 0b010) != 0 and last_op_flag == .ZRO) or
        ((nzp & 0b001) != 0 and last_op_flag == .POS))
    {
        const pc_offset: u16 = signExtend(instruction & 0x1FF, 9);
        const branched_pc: u16 = mem.registers.get(.PC) +% pc_offset;
        mem.registers.set(.PC, branched_pc);
    }
}

test "brOp" {
    // BR/BRnzp 0x3000 -> 0x300A
    mem.registers.set(.PC, 0x3000);
    brOp(0b0000_111_000001010);
    try std.testing.expectEqual(0x300A, mem.registers.get(.PC));

    // BRnp 0x3000 -> 0x300A
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.COND, ConditionFlag.NEG.val());
    brOp(0b0000_101_000001010);
    try std.testing.expectEqual(0x300A, mem.registers.get(.PC));

    // BRn 0x3000 -> 0x300A
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.COND, ConditionFlag.NEG.val());
    brOp(0b0000_100_000001010);
    try std.testing.expectEqual(0x300A, mem.registers.get(.PC));

    // BRz 0x3000 -> 0x300A
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.COND, ConditionFlag.ZRO.val());
    brOp(0b0000_010_000001010);
    try std.testing.expectEqual(0x300A, mem.registers.get(.PC));

    // BRp 0x3000 -> 0x300A
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.COND, ConditionFlag.POS.val());
    brOp(0b0000_001_000001010);
    try std.testing.expectEqual(0x300A, mem.registers.get(.PC));

    // BRz 0x3000 <- no branch
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.COND, ConditionFlag.NEG.val());
    brOp(0b0000_010_000001010);
    try std.testing.expectEqual(0x3000, mem.registers.get(.PC));
}

pub fn jmpOp(instruction: u16) void {
    const br: Register = @enumFromInt((instruction >> 6) & 0x7);
    const jumped_pc: u16 = mem.registers.get(br);

    mem.registers.set(.PC, jumped_pc);
}

test "jmpOp" {
    // JMP PC to 0x5000 from R4
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.R4, 0x5000);
    jmpOp(0b1100_000_100_000000);
    try std.testing.expectEqual(0x5000, mem.registers.get(.PC));

    // RET PC to 0xBEEF
    mem.registers.set(.PC, 0xDEAD);
    mem.registers.set(.R7, 0xBEEF);
    jmpOp(0b1100_000_111_000000);
    try std.testing.expectEqual(0xBEEF, mem.registers.get(.PC));
}

pub fn jsrOp(instruction: u16) void {
    const offset_bit: u16 = (instruction >> 11) & 0x1;
    const pc_now: u16 = mem.registers.get(.PC);

    mem.registers.set(.R7, pc_now);

    if (offset_bit == 0) {
        const br: Register = @enumFromInt((instruction >> 6) & 0x7);
        mem.registers.set(.PC, mem.registers.get(br));
    } else {
        const pc_offset = signExtend(instruction & 0x7FF, 11);
        mem.registers.set(.PC, pc_now +% pc_offset);
    }
}

test "jsrOp" {
    // Jump PC to [R5] = 0xBEEF
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.R5, 0xBEEF);
    jsrOp(0b0100_0_00_101_000000);
    try std.testing.expectEqual(0x3000, mem.registers.get(.R7));
    try std.testing.expectEqual(0xBEEF, mem.registers.get(.PC));

    // Offset PC by 0x3FF
    mem.registers.set(.PC, 0x3300);
    jsrOp(0b0100_1_01111111111);
    try std.testing.expectEqual(0x3300, mem.registers.get(.R7));
    try std.testing.expectEqual(0x36FF, mem.registers.get(.PC));
}

pub fn ldOp(instruction: u16) void {
    const dr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const pc_offset: u16 = signExtend(instruction & 0x1FF, 9);
    const address: u16 = mem.registers.get(.PC) +% pc_offset;

    mem.registers.set(dr, mem.memRead(address));
    updateFlags(dr);
}

test "ldOp" {
    mem.registers.set(.COND, ConditionFlag.ZRO.val());
    mem.registers.set(.PC, 0xBE00);

    mem.memWrite(0xBEFF, 1337);

    ldOp(0b0010_001_011111111);
    try std.testing.expectEqual(1337, mem.registers.get(.R1));
    try std.testing.expectEqual(ConditionFlag.POS.val(), mem.registers.get(.COND));
}

pub fn ldiOp(instruction: u16) void {
    const dr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const pc_offset: u16 = signExtend(instruction & 0x1FF, 9);

    const indirect_address: u16 = mem.registers.get(.PC) +% pc_offset;
    const address: u16 = mem.memRead(indirect_address);

    mem.registers.set(dr, mem.memRead(address));
    updateFlags(dr);
}

test "ldiOp" {
    mem.registers.set(.PC, 0x3000);

    mem.memWrite(0x3001, 0x3456);
    mem.memWrite(0x3456, 1337);

    ldiOp(0b1010_000_000000001);
    try std.testing.expectEqual(1337, mem.registers.get(.R0));
    try std.testing.expectEqual(ConditionFlag.POS.val(), mem.registers.get(.COND));
}

pub fn ldrOp(instruction: u16) void {
    const dr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const br: Register = @enumFromInt((instruction >> 6) & 0x7);

    const offset: u16 = signExtend(instruction & 0x3F, 6);
    const address: u16 = mem.registers.get(br) +% offset;

    mem.registers.set(dr, mem.memRead(address));
    updateFlags(dr);
}

test "ldrOp" {
    // Load [R0] + offset6 (0x1F) into R2
    mem.registers.set(.R0, 0xBED0);
    mem.memWrite(0xBEEF, 1337);
    ldrOp(0b0110_010_000_011111);
    try std.testing.expectEqual(1337, mem.registers.get(.R2));
    try std.testing.expectEqual(ConditionFlag.POS.val(), mem.registers.get(.COND));

    // Load [R3] + offset6 (0xF) into R4
    mem.registers.set(.R3, 0x3010);
    mem.memWrite(0x301F, 0x8FFF);
    ldrOp(0b0110_100_011_001111);
    try std.testing.expectEqual(0x8FFF, mem.registers.get(.R4));
    try std.testing.expectEqual(ConditionFlag.NEG.val(), mem.registers.get(.COND));
}

pub fn leaOp(instruction: u16) void {
    const dr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const pc_offset: u16 = signExtend(instruction & 0x1FF, 9);

    mem.registers.set(dr, mem.registers.get(.PC) +% pc_offset);
    updateFlags(dr);
}

test "leaOp" {
    // Load 0x30F8 into R6
    mem.registers.set(.COND, ConditionFlag.ZRO.val());
    mem.registers.set(.PC, 0x3000);

    leaOp(0b1110_110_011111000);
    try std.testing.expectEqual(0x30F8, mem.registers.get(.R6));
    try std.testing.expectEqual(ConditionFlag.POS.val(), mem.registers.get(.COND));
}

pub fn notOp(instruction: u16) void {
    const dr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const sr: Register = @enumFromInt((instruction >> 6) & 0x7);
    const sr_val: u16 = mem.registers.get(sr);

    mem.registers.set(dr, ~sr_val);
    updateFlags(dr);
}

test "notOp" {
    // Store bit-wise complement of [R1] in R3
    mem.registers.set(.COND, ConditionFlag.ZRO.val());
    mem.registers.set(.R1, 0xAAAA);
    notOp(0b1001_011_001_111111);
    try std.testing.expectEqual(0x5555, mem.registers.get(.R3));
    try std.testing.expectEqual(ConditionFlag.POS.val(), mem.registers.get(.COND));

    // Store bit-wise complement of [R5] in R7
    mem.registers.set(.COND, ConditionFlag.ZRO.val());
    mem.registers.set(.R5, 0x5555);
    notOp(0b1001_111_101_111111);
    try std.testing.expectEqual(0xAAAA, mem.registers.get(.R7));
    try std.testing.expectEqual(ConditionFlag.NEG.val(), mem.registers.get(.COND));
}

pub fn stOp(instruction: u16) void {
    const sr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const pc_offset: u16 = signExtend(instruction & 0x1FF, 9);

    const sr_val: u16 = mem.registers.get(sr);
    const address: u16 = mem.registers.get(.PC) +% pc_offset;

    mem.memWrite(address, sr_val);
}

test "stOp" {
    // Store [R1] at 0x30FF
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.R1, 0xBEEF);
    stOp(0b0011_001_011111111);
    try std.testing.expectEqual(0xBEEF, mem.memRead(0x30FF));
}

pub fn stiOp(instruction: u16) void {
    const sr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const pc_offset: u16 = signExtend(instruction & 0x1FF, 9);

    const indirect_address: u16 = mem.registers.get(.PC) +% pc_offset;
    const address: u16 = mem.memRead(indirect_address);

    mem.memWrite(address, mem.registers.get(sr));
}

test "stiOp" {
    // Store [R4] at [PC + 0x33]
    mem.memWrite(0x3033, 0xDEAD);
    mem.registers.set(.PC, 0x3000);
    mem.registers.set(.R4, 1337);
    stiOp(0b1011_100_000110011);
    try std.testing.expectEqual(1337, mem.memRead(0xDEAD));
}

pub fn strOp(instruction: u16) void {
    const sr: Register = @enumFromInt((instruction >> 9) & 0x7);
    const br: Register = @enumFromInt((instruction >> 6) & 0x7);

    const offset: u16 = signExtend(instruction & 0x3F, 6);
    const address: u16 = mem.registers.get(br) +% offset;

    mem.memWrite(address, mem.registers.get(sr));
}

test "strOp" {
    // Store [R6] at [R2] + offset
    mem.registers.set(.R6, 1337);
    mem.registers.set(.R2, 0xDE90);
    strOp(0b0111_110_010_011110);
    try std.testing.expectEqual(1337, mem.memRead(0xDEAD));
}
