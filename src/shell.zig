comptime {
    @export(start, .{ .name = "start", .section = "_text.start" });
}

const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

fn start() callconv(.C) void {
    asm volatile ("mv sp, %[stack_top]"
        :
        : [stack_top] "r" (stack_top),
    );
    main() catch {};
}

// export fn cMain() void {
//     main() catch {};
// }

fn main() !void {
    const bad_ptr: *usize = @ptrFromInt(0x80200000);
    bad_ptr.* = 0xdecafbad;
    while (true) {}
}
