const std = @import("std");
const SCAUSE_ECALL = 8;
pub const SYS_PUTCHAR = 1;

pub fn initialize() void {
    write_csr("stvec", @intFromPtr(&kernel_entry));
}

pub fn syscall(sysno: u8, arg0: u8, arg1: u8, arg2: u8) u8 {
    var ret: u8 = undefined;
    asm volatile ("ecall"
        : [ret] "={a0}" (ret),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [sysno] "{a3}" (sysno),
        : "memory"
    );
    return ret;
}

const SbiRet = struct {
    err: usize,
    value: usize,
};
// Translation of https://operating-system-in-1000-lines.vercel.app/en/05-hello-world#say-hello-to-sbi
pub fn sbi(
    arg0: usize,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    fid: usize,
    eid: usize,
) SbiRet {
    var err: usize = undefined;
    var value: usize = undefined;
    // the below inline asm formatting is a shortcut that
    // allows us to avoid writing out a0 r arg0, etc for every argument
    asm volatile ("ecall"
        // this means after the ecall take the values from a0 and a1 store them in the output variables
        : [err] "={a0}" (err),
          [value] "={a1}" (value),
          // this means put these input values directly into these registers
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [arg6] "{a6}" (fid),
          [arg7] "{a7}" (eid),
        : "memory"
    );

    return .{ .err = err, .value = value };
}

fn read_csr(comptime reg: []const u8) usize {
    return asm volatile ("csrr %[_ret_], " ++ reg // template for the asm
        : [_ret_] "=r" (-> usize), // return what is in the ret register out of the function
    );
}

fn write_csr(comptime reg: []const u8, val: usize) void {
    asm volatile ("csrw " ++ reg ++ ", %[_val_]"
        :
        : [_val_] "r" (val), // read value into the register templated by %[val]
    );
}

// Translation of https://operating-system-in-1000-lines.vercel.app/en/08-exception#exception-handler
fn kernel_entry() align(4) callconv(.Naked) void {
    asm volatile (
        \\ csrrw sp, sscratch, sp
        \\ addi sp, sp, -4 * 31
        \\ sw ra,  4 * 0(sp)
        \\ sw gp,  4 * 1(sp)
        \\ sw tp,  4 * 2(sp)
        \\ sw t0,  4 * 3(sp)
        \\ sw t1,  4 * 4(sp)
        \\ sw t2,  4 * 5(sp)
        \\ sw t3,  4 * 6(sp)
        \\ sw t4,  4 * 7(sp)
        \\ sw t5,  4 * 8(sp)
        \\ sw t6,  4 * 9(sp)
        \\ sw a0,  4 * 10(sp)
        \\ sw a1,  4 * 11(sp)
        \\ sw a2,  4 * 12(sp)
        \\ sw a3,  4 * 13(sp)
        \\ sw a4,  4 * 14(sp)
        \\ sw a5,  4 * 15(sp)
        \\ sw a6,  4 * 16(sp)
        \\ sw a7,  4 * 17(sp)
        \\ sw s0,  4 * 18(sp)
        \\ sw s1,  4 * 19(sp)
        \\ sw s2,  4 * 20(sp)
        \\ sw s3,  4 * 21(sp)
        \\ sw s4,  4 * 22(sp)
        \\ sw s5,  4 * 23(sp)
        \\ sw s6,  4 * 24(sp)
        \\ sw s7,  4 * 25(sp)
        \\ sw s8,  4 * 26(sp)
        \\ sw s9,  4 * 27(sp)
        \\ sw s10, 4 * 28(sp)
        \\ sw s11, 4 * 29(sp)

        // Retrieve and save the sp at the time of exception.
        \\ csrr a0, sscratch
        \\ sw a0,  4 * 30(sp)

        // Reset the kernel stack.
        \\ addi a0, sp, 4 * 31
        \\ csrw sscratch, a0
        \\
        \\ csrr a0, sscratch
        \\ sw a0, 4 * 30(sp)
        \\ mv a0, sp
        \\ call handle_trap
        \\
        \\ lw ra,  4 * 0(sp)
        \\ lw gp,  4 * 1(sp)
        \\ lw tp,  4 * 2(sp)
        \\ lw t0,  4 * 3(sp)
        \\ lw t1,  4 * 4(sp)
        \\ lw t2,  4 * 5(sp)
        \\ lw t3,  4 * 6(sp)
        \\ lw t4,  4 * 7(sp)
        \\ lw t5,  4 * 8(sp)
        \\ lw t6,  4 * 9(sp)
        \\ lw a0,  4 * 10(sp)
        \\ lw a1,  4 * 11(sp)
        \\ lw a2,  4 * 12(sp)
        \\ lw a3,  4 * 13(sp)
        \\ lw a4,  4 * 14(sp)
        \\ lw a5,  4 * 15(sp)
        \\ lw a6,  4 * 16(sp)
        \\ lw a7,  4 * 17(sp)
        \\ lw s0,  4 * 18(sp)
        \\ lw s1,  4 * 19(sp)
        \\ lw s2,  4 * 20(sp)
        \\ lw s3,  4 * 21(sp)
        \\ lw s4,  4 * 22(sp)
        \\ lw s5,  4 * 23(sp)
        \\ lw s6,  4 * 24(sp)
        \\ lw s7,  4 * 25(sp)
        \\ lw s8,  4 * 26(sp)
        \\ lw s9,  4 * 27(sp)
        \\ lw s10, 4 * 28(sp)
        \\ lw s11, 4 * 29(sp)
        \\ lw sp,  4 * 30(sp)
        \\ sret
    );
}

const TrapFrame = struct {
    ra: usize,
    gp: usize,
    tp: usize,
    t0: usize,
    t1: usize,
    t2: usize,
    t3: usize,
    t4: usize,
    t5: usize,
    t6: usize,
    a0: usize,
    a1: usize,
    a2: usize,
    a3: usize,
    a4: usize,
    a5: usize,
    a6: usize,
    a7: usize,
    s0: usize,
    s1: usize,
    s2: usize,
    s3: usize,
    s4: usize,
    s5: usize,
    s6: usize,
    s7: usize,
    s8: usize,
    s9: usize,
    s10: usize,
    s11: usize,
    sp: usize,
};

export fn handle_trap(tf: *TrapFrame) void {
    const scause: usize = read_csr("scause");
    const stval: usize = read_csr("stval");
    var user_pc: usize = read_csr("sepc");
    if (scause == SCAUSE_ECALL) {
        handleSyscall(tf);
        user_pc += 4;
    } else {
        std.debug.panic("Unexpected trap scause={x}, stval={x}, sepc={x}", .{ scause, stval, user_pc });
    }
    write_csr("sepc", user_pc);
}

fn handleSyscall(tf: *TrapFrame) void {
    switch (tf.a3) {
        SYS_PUTCHAR => _ = sbi(tf.a0, 0, 0, 0, 0, 0, 0, 1), // should be able to call putChar here
        else => std.debug.panic("Unexpected syscall {}", .{tf.a3}),
    }
}
