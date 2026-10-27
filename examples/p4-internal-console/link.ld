/* Application-entry ELF only. Not yet an ESP image/flash recipe.
 * Unified internal SRAM; isolated code/data and16KiB application stack.
 * Caller selects __abla_ram_base: 0x4ff10000 for pre-v3, 0x4ff80000
 * for v3. Older layout stays below ROM download buffers/bootloader; v3
 * starts above the largest supported 512KiB L2 cache reservation.
 * Bootloader configuration and silicon revision still require validation.
 */
ENTRY(abla_p4_application_entry)
MEMORY {
    code (rx) : ORIGIN = __abla_ram_base, LENGTH = 0x10000
    data (rw) : ORIGIN = __abla_ram_base + 0x10000, LENGTH = 0x4000
    stack (rw) : ORIGIN = __abla_ram_base + 0x14000, LENGTH = 0x4000
}
SECTIONS {
    .iram1 : ALIGN(64) { *(.iram1.abla.p4ApplicationEntry) *(.iram1 .iram1.* .text .text.*) } > code
    .dram1 : ALIGN(4) {
        __global_pointer$ = . + 0x800;
        __abla_gp = __global_pointer$;
        *(.dram1 .dram1.* .rodata .rodata.* .srodata .srodata.* .data .data.* .sdata .sdata.*)
        *(.eh_frame .eh_frame.* .eh_frame_hdr)
    } > data
    .dram1.bss (NOLOAD) : ALIGN(4) {
        __abla_bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        __abla_bss_end = .;
    } > data
    .dram1.stack (NOLOAD) : ALIGN(16) { . += 0x4000; __abla_stack_top = .; } > stack
    .riscv.attributes 0 : { *(.riscv.attributes) }
    /DISCARD/ : { *(.comment .note.GNU-stack) }
}
ASSERT((__abla_stack_top & 15) == 0, "unaligned RISC-V stack")
ASSERT(__abla_ram_base == 0x4ff10000 || __abla_ram_base == 0x4ff80000, "unsupported P4 RAM layout")
ASSERT((__abla_bss_start & 3) == 0 && (__abla_bss_end & 3) == 0, "unaligned BSS")
