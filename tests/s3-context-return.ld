/* Link-only context-return relocation check. NOT bootable/flashable. */
ENTRY(abla_context_return_target)
MEMORY {
    internal_code (rx) : ORIGIN = 0x40378000, LENGTH = 0x10000
    internal_data (rw) : ORIGIN = 0x3FC98000, LENGTH = 0x10000
}
SECTIONS {
    .iram1.abla.s3ContextReturns : ALIGN(4) { *(.iram1.abla.s3ContextReturns) } > internal_code
    .iram1 : ALIGN(4) { *(.iram1 .iram1.*) } > internal_code
    .dram1 : ALIGN(4) { *(.dram1 .dram1.*) } > internal_data
    .forbidden : { *(.text .text.* .rodata .rodata.* .data .data.* .bss .bss.* COMMON) } > internal_data
    /DISCARD/ : { *(.xtensa.info .xt.lit .xt.prop .note.GNU-stack .comment) }
}
ASSERT(SIZEOF(.forbidden) == 0, "context closure retained ordinary code/data")
ASSERT(ADDR(.iram1) + SIZEOF(.iram1) - 0x40378000 <= ADDR(.dram1) - 0x3FC88000,
       "S3 code/data physical SRAM aliases overlap")
