/* Link-only vector/runtime integration. NOT bootable or flashable:
 * no reset/bootstrap/scheduler. High/debug/NMI/kernel/double capture-and-halt.
 */
ENTRY(abla_irq_vectors_target)
MEMORY {
    internal_code (rx) : ORIGIN = 0x40378000, LENGTH = 0x10000
    internal_data (rw) : ORIGIN = 0x3FC98000, LENGTH = 0x10000
}
SECTIONS {
    .iram1.abla.s3WindowVectors ORIGIN(internal_code) : { KEEP(*(.iram1.abla.s3WindowVectors)) } > internal_code
    .iram1.abla.s3Level2Vector ORIGIN(internal_code)+0x180 : { KEEP(*(.iram1.abla.s3Level2Vector)) } > internal_code
    .iram1.abla.s3Level3Vector ORIGIN(internal_code)+0x1c0 : { KEEP(*(.iram1.abla.s3Level3Vector)) } > internal_code
    .iram1.abla.s3Level4Vector ORIGIN(internal_code)+0x200 : { KEEP(*(.iram1.abla.s3Level4Vector)) } > internal_code
    .iram1.abla.s3Level5Vector ORIGIN(internal_code)+0x240 : { KEEP(*(.iram1.abla.s3Level5Vector)) } > internal_code
    .iram1.abla.s3Level6Vector ORIGIN(internal_code)+0x280 : { KEEP(*(.iram1.abla.s3Level6Vector)) } > internal_code
    .iram1.abla.s3Level7Vector ORIGIN(internal_code)+0x2c0 : { KEEP(*(.iram1.abla.s3Level7Vector)) } > internal_code
    .iram1.abla.s3KernelVector ORIGIN(internal_code)+0x300 : { KEEP(*(.iram1.abla.s3KernelVector)) } > internal_code
    .iram1.abla.s3UserVector ORIGIN(internal_code)+0x340 : { KEEP(*(.iram1.abla.s3UserVector)) } > internal_code
    .iram1.abla.s3DoubleVector ORIGIN(internal_code)+0x3c0 : { KEEP(*(.iram1.abla.s3DoubleVector)) } > internal_code
    .iram1.abla.s3IrqEntries ORIGIN(internal_code)+0x400 : { *(.iram1.abla.s3IrqEntries) } > internal_code
    .iram1.abla.s3ExceptionEntry : ALIGN(4) { *(.iram1.abla.s3ExceptionEntry) } > internal_code
    .iram1.abla.s3FatalEntry : ALIGN(4) { *(.iram1.abla.s3FatalEntry) } > internal_code
    .iram1.abla.s3FirstTask : ALIGN(4) { *(.iram1.abla.s3FirstTask) } > internal_code
    .iram1.abla.s3ContextReturns : ALIGN(4) { *(.iram1.abla.s3ContextReturns) } > internal_code
    .iram1 : ALIGN(4) { *(.iram1 .iram1.*) } > internal_code
    .dram1.abla.s3IrqConfig : ALIGN(4) { *(.dram1.abla.s3IrqConfig) } > internal_data
    .dram1.abla.s3FatalRecords : ALIGN(16) { *(.dram1.abla.s3FatalRecords) } > internal_data
    .dram1 : ALIGN(4) { *(.dram1 .dram1.*) } > internal_data
    .forbidden : { *(.text .text.* .rodata .rodata.* .data .data.* .bss .bss.* COMMON) } > internal_data
    /DISCARD/ : { *(.xtensa.info .xt.lit .xt.prop .note.GNU-stack .comment) }
}
ASSERT((ADDR(.iram1.abla.s3WindowVectors) & 1023) == 0, "VECBASE alignment")
ASSERT(SIZEOF(.iram1.abla.s3WindowVectors) == 0x180, "window vector size")
ASSERT(SIZEOF(.iram1.abla.s3Level2Vector) == 64, "level2 slot size")
ASSERT(SIZEOF(.iram1.abla.s3Level3Vector) == 64, "level3 slot size")
ASSERT(SIZEOF(.iram1.abla.s3UserVector) == 64, "user slot size")
ASSERT(SIZEOF(.iram1.abla.s3KernelVector) == 64, "kernel slot size")
ASSERT(SIZEOF(.iram1.abla.s3DoubleVector) == 64, "double slot size")
ASSERT(SIZEOF(.iram1.abla.s3Level4Vector) == 64, "level4 slot size")
ASSERT(SIZEOF(.iram1.abla.s3Level5Vector) == 64, "level5 slot size")
ASSERT(SIZEOF(.iram1.abla.s3Level6Vector) == 64, "debug slot size")
ASSERT(SIZEOF(.iram1.abla.s3Level7Vector) == 64, "NMI slot size")
ASSERT(SIZEOF(.forbidden) == 0, "ordinary code/data in internal closure")
ASSERT(ADDR(.iram1) + SIZEOF(.iram1) - 0x40378000 <= ADDR(.dram1.abla.s3IrqConfig) - 0x3FC88000,
       "S3 code/data physical SRAM aliases overlap")
