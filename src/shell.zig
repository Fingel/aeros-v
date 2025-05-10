comptime {
    @export(start, .{ .name = "start", .section = "_text.start" });
}
const riscv = @import("riscv.zig");

const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

fn start() callconv(.C) void {
    asm volatile ("mv sp, %[stack_top]"
        :
        : [stack_top] "r" (stack_top),
    );
    main() catch {};
}

fn putChar(c: u8) void {
    _ = riscv.syscall(riscv.SYS_PUTCHAR, c, 0, 0);
}

fn main() !void {
    while (true) {
        putChar('B');
        for (3_000_000_000) |_| asm volatile ("nop");
    }
}
