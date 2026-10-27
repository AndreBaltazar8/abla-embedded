/* Link-only entry ABI fixture. No runnable firmware/flash layout. */
ENTRY(abla_boot_entry)
MEMORY {
    code (rx) : ORIGIN = 0x40378000, LENGTH = 0x10000
    data (rw) : ORIGIN = 0x3FC98000, LENGTH = 0x10000
}
SECTIONS {
    .iram1.abla.s3BootVectors : ALIGN(1024) { KEEP(*(.iram1.abla.s3BootVectors)) } > code
    .iram1 : ALIGN(4) { *(.iram1 .iram1.*) } > code
    .dram1 : ALIGN(4) { *(.dram1 .dram1.*) } > data
    .boot_stack (NOLOAD) : ALIGN(16) {
        __abla_boot_stack_low = .;
        . += 4096;
        __abla_boot_stack_top = .;
    } > data
    .forbidden : { *(.text .text.* .rodata .rodata.* .data .data.* .bss .bss.* COMMON) } > data
    /DISCARD/ : { *(.xtensa.info .xt.lit .xt.prop .note.GNU-stack .comment) }
}
ASSERT(SIZEOF(.forbidden) == 0, "ordinary code/data in boot closure")
ASSERT((ADDR(.iram1.abla.s3BootVectors) & 1023) == 0 && SIZEOF(.iram1.abla.s3BootVectors) == 1024, "early vector placement")
ASSERT((__abla_boot_stack_top & 15) == 0, "boot stack alignment")
ASSERT(ADDR(.iram1)+SIZEOF(.iram1)-0x40378000 <= __abla_boot_stack_low-0x3FC88000,
       "code/stack physical SRAM aliases overlap")
