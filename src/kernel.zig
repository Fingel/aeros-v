const std = @import("std");
const common = @import("common.zig");

const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize,
) noreturn {
    _ = error_return_trace;
    _ = ret_addr;
    common.console.print("PANIC: {s}\n", .{msg}) catch {};
    while (true) asm volatile ("");
}

export fn kernel_main() noreturn {
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_len], 0);

    const name = "Aero";
    common.console.print("Hello {s}!\n", .{name}) catch {};

    @panic("OOPS BLUE SCREEN OF DEATH");

    // while (true) asm volatile ("wfi");
}

export fn boot() linksection(".text.boot") callconv(.Naked) void {
    _ = asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (stack_top),
    );
}
