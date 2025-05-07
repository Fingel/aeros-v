const common = @import("common.zig");
pub const RAM_START = @extern([*]u8, .{ .name = "__free_ram" });
pub const RAM_END = @extern([*]u8, .{ .name = "__free_ram_end" });
pub const PAGE_SIZE = 4096;
pub const SATP_SV32 = 1 << 31;
// 0000 0000 000[user] [exec][write][read][valid]
pub const PAGE_V = 1 << 0; // Valid bit
pub const PAGE_R = 1 << 1; // Readable
pub const PAGE_W = 1 << 2; // Writable
pub const PAGE_X = 1 << 3; // Executable
pub const PAGE_U = 1 << 4; // User mode

var used_mem: usize = 0;

pub fn allocPages(pages: usize) []u8 {
    const ram = RAM_START[0 .. @intFromPtr(RAM_END) - @intFromPtr(RAM_START)];
    const alloc_size = pages * PAGE_SIZE;
    if (used_mem + alloc_size > ram.len) {
        @panic("out of memory");
    }
    const result = ram[used_mem .. used_mem + alloc_size];
    used_mem += alloc_size;
    @memset(result, 0);
    return result;
}

pub fn mapPage(table1: [*]usize, vaddr: usize, paddr: usize, flags: usize) void {
    if (vaddr % PAGE_SIZE != 0) @panic("Unalignend virtual address");
    if (paddr % PAGE_SIZE != 0) @panic("Unalignend physical address");

    // 0x3FF 0000 0011 1111 1111
    const vpn1 = (vaddr >> 22) & 0x3FF;
    if ((table1[vpn1] & PAGE_V) == 0) { // check of table1 contains this address
        // Create the non-existent 2nd level page table
        const ptPaddr = @intFromPtr(allocPages(1).ptr);
        table1[vpn1] = ((ptPaddr / PAGE_SIZE) << 10) | PAGE_V;
    }

    // set the 2nd level page table entry to map the physical page.
    const vpn0 = (vaddr >> 12) & 0x3FF;
    const table0: [*]usize = @ptrFromInt((table1[vpn1] >> 10) * PAGE_SIZE);
    table0[vpn0] = ((paddr / PAGE_SIZE) << 10) | flags | PAGE_V;
}
