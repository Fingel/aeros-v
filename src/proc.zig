const memory = @import("memory.zig");
const common = @import("common.zig");

const kernel_base = @extern([*]u8, .{ .name = "__kernel_base" });
const PROCS_MAX = 8;

var procs = [_]Process{.{}} ** PROCS_MAX;
var currentProc: *Process = undefined;
var idleProc: *Process = undefined;

pub const Process = struct {
    pid: usize = 0,
    state: enum { unused, runnable } = .unused,
    sp: *usize = undefined, // stack pointer
    pageTable: [*]usize = undefined,
    stack: [8192]u8 = undefined, // kernel stack
    counter: u32 = 0,
};

pub fn initialize() void {
    idleProc = createProcess(undefined);
    idleProc.pid = 0;
    currentProc = idleProc;
}

pub fn yield() void {
    const next = for (0..PROCS_MAX) |i| {
        const process = &procs[(currentProc.pid + i) % PROCS_MAX];
        if (process.state == .runnable and process.pid > 0) {
            break process;
        }
    } else idleProc;

    if (next == currentProc) return;

    // reset the stack pointer for the exception handler
    const stackBtm: *usize = @alignCast(@ptrCast(&next.stack[next.stack.len - 1]));
    asm volatile (
        \\ csrw sscratch, %[sscratch]
        :
        : [sscratch] "r" (stackBtm),
    );

    const prev = currentProc;
    currentProc = next;

    const pageTableAddr = @intFromPtr(next.pageTable);
    const ppn = (pageTableAddr / memory.PAGE_SIZE);
    const satpValue = memory.SATP_SV32 | ppn;
    common.console.print("PT addr: 0x{x}, PPN: 0x{x}, SATP: 0x{x}\n", .{ pageTableAddr, ppn, satpValue }) catch {};
    // Do I need to calculate the stack position like this?
    // const stackBtmAgain: *usize = @alignCast(@ptrCast(&next.stack[next.stack.len - 1]));
    asm volatile (
        \\ sfence.vma
        \\ csrw satp, %[satp]
        \\ sfence.vma
        \\ csrw sscratch, %[sscratch]
        :
        : [satp] "r" (satpValue),
          [sscratch] "r" (&next.stack[next.stack.len - 1]),
    );
    switch_context(&prev.sp, &next.sp);
}

pub fn createProcess(func: *const fn () void) *Process {
    // Find an unused process control structure
    const p = for (&procs, 0..) |*p, i| {
        if (p.state == .unused) {
            p.pid = i + 1;
            break p;
        }
    } else @panic("No free process slots.");

    // map kernel pages
    const pageTable: [*]usize = @ptrCast(@alignCast(memory.allocPages(1).ptr));
    common.console.print("Creating page table{x}\n", .{&pageTable}) catch {};
    var paddr = @intFromPtr(kernel_base);
    while (paddr < @intFromPtr(memory.RAM_END)) : (paddr += memory.PAGE_SIZE) {
        memory.mapPage(pageTable, paddr, paddr, memory.PAGE_R | memory.PAGE_W | memory.PAGE_X);
    }

    // Stack callee-saved registers
    // Find the end of this process's stack, zeros the registers and then
    // saves the program counter at the top of the stack. The stack layout should look
    // end up like this:
    // [... other stack data ...][pc][s0][s1][s2][s3][s4][s5][s6][s7][s8][s9][s10][s11]
    //                            ^
    //                    p.stack[len-13]
    // Which should match how the switch_context function expects the stack to be laid out.
    var sp: [*]usize = @alignCast(@ptrCast(&p.stack[p.stack.len - 1]));
    const pc = @intFromPtr(func);
    sp[0] = 0; // s11
    sp -= 1;
    sp[0] = 0; // s10
    sp -= 1;
    sp[0] = 0; // s9
    sp -= 1;
    sp[0] = 0; // s8
    sp -= 1;
    sp[0] = 0; // s7
    sp -= 1;
    sp[0] = 0; // s6
    sp -= 1;
    sp[0] = 0; // s5
    sp -= 1;
    sp[0] = 0; // s4
    sp -= 1;
    sp[0] = 0; // s3
    sp -= 1;
    sp[0] = 0; // s2
    sp -= 1;
    sp[0] = 0; // s1
    sp -= 1;
    sp[0] = 0; // s0
    sp -= 1;
    sp[0] = pc; // ra

    p.state = .runnable;
    p.sp = &sp[0];
    p.pageTable = pageTable;
    return p;
}

noinline fn switch_context(cur: **usize, next: **usize) callconv(.C) void {
    // Save callee-saved registers onto the current process's stack.
    asm volatile (
        \\ addi sp, sp, -13 * 4
        \\ sw ra,  0  * 4(sp)
        \\ sw s0,  1  * 4(sp)
        \\ sw s1,  2  * 4(sp)
        \\ sw s2,  3  * 4(sp)
        \\ sw s3,  4  * 4(sp)
        \\ sw s4,  5  * 4(sp)
        \\ sw s5,  6  * 4(sp)
        \\ sw s6,  7  * 4(sp)
        \\ sw s7,  8  * 4(sp)
        \\ sw s8,  9  * 4(sp)
        \\ sw s9,  10 * 4(sp)
        \\ sw s10, 11 * 4(sp)
        \\ sw s11, 12 * 4(sp)
        \\ sw sp, (%[cur])
        \\ lw sp, (%[next])
        \\ lw ra,  0  * 4(sp)
        \\ lw s0,  1  * 4(sp)
        \\ lw s1,  2  * 4(sp)
        \\ lw s2,  3  * 4(sp)
        \\ lw s3,  4  * 4(sp)
        \\ lw s4,  5  * 4(sp)
        \\ lw s5,  6  * 4(sp)
        \\ lw s6,  7  * 4(sp)
        \\ lw s7,  8  * 4(sp)
        \\ lw s8,  9  * 4(sp)
        \\ lw s9,  10 * 4(sp)
        \\ lw s10, 11 * 4(sp)
        \\ lw s11, 12 * 4(sp)
        \\ addi sp, sp, 13 * 4
        \\ ret
        :
        : [cur] "r" (cur),
          [next] "r" (next),
    );
}
