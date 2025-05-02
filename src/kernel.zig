const std = @import("std");
const common = @import("common.zig");
const riscv = @import("riscv.zig");

const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });
const ram_start = @extern([*]u8, .{ .name = "__free_ram" });
const ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });

const page_size = 4096;
var used_mem: usize = 0;

fn allocPages(pages: usize) []u8 {
    const ram = ram_start[0 .. @intFromPtr(ram_end) - @intFromPtr(ram_start)];
    const alloc_size = pages * page_size;
    if (used_mem + alloc_size > ram.len) {
        @panic("out of memory");
    }
    const result = ram[used_mem .. used_mem + alloc_size];
    used_mem += alloc_size;
    @memset(result, 0);
    return result;
}

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
    // Uncomment to trigger exception
    // asm volatile ("unimp");

    const two = allocPages(2);
    const one = allocPages(1);
    try common.console.print("one: {*} ({}) two: {*} ({})\n", .{ one.ptr, one.len, two.ptr, two.len });
    const name = "Aero";
    try common.console.print("Hello {s}!\n", .{name});
}

export fn boot() linksection(".text.boot") callconv(.Naked) void {
    _ = asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (stack_top),
    );
}
