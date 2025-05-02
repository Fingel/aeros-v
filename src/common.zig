const std = @import("std");
const riscv = @import("riscv.zig");

pub const console: std.io.AnyWriter = .{
    .context = undefined,
    .writeFn = write_fn,
};

fn putchar(c: u8) void {
    _ = riscv.sbi(c, 0, 0, 0, 0, 0, 0, 1);
}

fn write_fn(_: *const anyopaque, bytes: []const u8) !usize {
    for (bytes) |byte| putchar(byte);
    return bytes.len;
}
