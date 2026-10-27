/* Link-only closure probe, NOT bootable/flashable. P4 unified internal SRAM
 * 0x4ff00000..0x4ffc0000 (IDF soc.h). Explicit disjoint 64KiB slices.
 * Place the WHOLE monolithic closure, including LLVM outlined helpers and
 * constants, internally. Annotating just the entry does not establish this.
 * Application vectors/stacks/heap and other callbacks are not modeled here.
 */
ENTRY(abla_p4_irq_closure_target)
MEMORY {
    code (rx) : ORIGIN = 0x4ff10000, LENGTH = 0x10000
    data (rw) : ORIGIN = 0x4ff20000, LENGTH = 0x10000
}
SECTIONS {
    .iram1 : ALIGN(64) {
        __p4_entry_start = .;
        *(.iram1.abla.p4IrqEntry)
        __p4_entry_end = .;
        *(.iram1 .iram1.* .text .text.*)
    } > code
    .dram1 : ALIGN(4) {
        __p4_config_start = .;
        *(.dram1.abla.p4IrqConfig)
        __p4_config_end = .;
        *(.dram1 .dram1.* .rodata .rodata.* .srodata .srodata.* .data .data.* .sdata .sdata.*)
        /* LLVM emits unwind metadata even without an exception runtime.
         * Retain it internally rather than silently discarding generated data. */
        *(.eh_frame .eh_frame.* .eh_frame_hdr .gcc_except_table .gcc_except_table.*)
    } > data
    .dram1.bss (NOLOAD) : ALIGN(4) { *(.bss .bss.* .sbss .sbss.* COMMON) } > data
    .riscv.attributes 0 : { *(.riscv.attributes) }
    /DISCARD/ : { *(.comment .note.GNU-stack) }
}
ASSERT((__p4_entry_start & 63) == 0, "IRQ entry alignment")
ASSERT(__p4_entry_end > __p4_entry_start, "missing real IRQ entry")
ASSERT(__p4_config_end - __p4_config_start == 32, "missing/duplicate per-core IRQ config")
