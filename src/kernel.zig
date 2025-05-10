// const shell = @embedFile("shell.bin");
const std = @import("std");
const common = @import("common.zig");
const riscv = @import("riscv.zig");
const memory = @import("memory.zig");
const proc = @import("proc.zig");

const kernel_base = @extern([*]u8, .{ .name = "__kernel_base" });
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
    main() catch |err| std.debug.panic("{s}", .{@errorName(err)});
    while (true) asm volatile ("wfi");
}

fn main() !void {
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_len], 0);
    riscv.initialize();
    const banner =
        \\                      ▗▄▖  ▗▄▖
        \\                      █▀█ ▗▛▀▜
        \\       ▟██▖ ▟█▙  █▟█▌▐▌ ▐▌▐▙
        \\       ▘▄▟▌▐▙▄▟▌ █▘  ▐▌ ▐▌ ▜█▙
        \\      ▗█▀▜▌▐▛▀▀▘ █   ▐▌ ▐▌   ▜▌
        \\      ▐▙▄█▌▝█▄▄▌ █    █▄█ ▐▄▄▟▘
        \\       ▀▀▝▘ ▝▀▀  ▀    ▝▀▘  ▀▀▘
        \\
    ;

    try common.console.print(banner, .{});
    // Page allocation
    {
        const one = memory.allocPages(1);
        const two = memory.allocPages(2);
        try common.console.print("one: {*} ({}) two: {*} ({})\n", .{
            one.ptr,
            one.len,
            two.ptr,
            two.len,
        });
    }

    // Processes
    {
        proc.initialize();

        // pA = proc.createProcess(&processA);
        // pB = proc.createProcess(&processB);

        proc.yield();

        @panic("switched to idle process");
    }
    const name = "Aero";
    try common.console.print("Hello {s}!\n", .{name});
    // Uncomment to trigger exception
    // asm volatile ("unimp");
}

export fn boot() linksection(".text.boot") callconv(.Naked) void {
    _ = asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (stack_top),
    );
}
var pA: *proc.Process = undefined;
var pB: *proc.Process = undefined;

fn processA() void {
    common.console.print("Starting process A\n", .{}) catch {};
    while (true) {
        common.console.print("A (a.sp = {*} b.sp = {*} counter = {d})\n", .{
            pA.sp,
            pB.sp,
            pA.counter,
        }) catch {};
        const active_stack = pA.stack[pA.stack.len - 14 ..];
        common.console.print("Active stack area: {any}\n", .{active_stack}) catch {};
        proc.yield();
        for (3_000_000_000) |_| asm volatile ("nop");
        pA.counter += 1;
    }
}

fn processB() void {
    common.console.print("Starting process B\n", .{}) catch {};
    while (true) {
        common.console.print("B (a.sp = {*} b.sp = {*} counter = {d})\n", .{
            pA.sp,
            pB.sp,
            pB.counter,
        }) catch {};
        const active_stack = pB.stack[pB.stack.len - 14 ..];
        common.console.print("Active stack area: {any}\n", .{active_stack}) catch {};
        proc.yield();
        for (3_000_000_000) |_| asm volatile ("nop");
        pB.counter += 1;
    }
}
