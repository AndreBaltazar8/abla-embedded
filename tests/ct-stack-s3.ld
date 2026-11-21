/* Link-only ABI check, not a flashable image. */
ENTRY(ct_stack_probe)
MEMORY {
    code (rx) : ORIGIN = 0x40378000, LENGTH = 0x10000
    data (rw) : ORIGIN = 0x3FC98000, LENGTH = 0x10000
}
SECTIONS {
    .text : ALIGN(4) { *(.literal .literal.* .iram1 .iram1.* .text .text.*) } > code
    .data : ALIGN(4) { *(.rodata .rodata.* .data .data.* .bss .bss.* COMMON) } > data
    .stack (NOLOAD) : ALIGN(16) {
        __abla_boot_stack_low = .; . += 4096; __abla_boot_stack_top = .;
    } > data
    /DISCARD/ : { *(.xtensa.info .xt.lit .xt.prop .note.GNU-stack .comment) }
}
