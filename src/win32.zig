const std = @import("std");

const c = @cImport({
    @cInclude("windows.h");
    @cInclude("conio.h");
});

// Windows OS

var h_stdin: c.HANDLE = c.INVALID_HANDLE_VALUE;
var fdw_mode: c.DWORD = 0;
var fdw_old_mode: c.DWORD = 0;

pub fn disableInputBuffering() void {
    h_stdin = c.GetStdHandle(c.STD_INPUT_HANDLE);
    _ = c.GetConsoleMode(h_stdin, &fdw_old_mode);
    fdw_mode = fdw_old_mode ^ c.ENABLE_ECHO_INPUT ^ c.ENABLE_LINE_INPUT;
    _ = c.SetConsoleMode(h_stdin, fdw_mode);
    _ = c.FlushConsoleInputBuffer(h_stdin);
}

pub fn restoreInputBuffering() void {
    _ = c.SetConsoleMode(h_stdin, fdw_old_mode);
}

pub fn checkKey() bool {
    return c.WaitForSingleObject(h_stdin, 1000) == c.WAIT_OBJECT_0 and c._kbhit() != 0;
}

pub fn handleInterrupt(_: c_int) callconv(.C) void {
    restoreInputBuffering();
    std.os.exit(2);
}
