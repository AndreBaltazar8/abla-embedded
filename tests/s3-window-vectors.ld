/* Link-placement regression ONLY: missing exception/interrupt handlers,
 * reset entry, stack and runtime. Never flash this ELF.
 * Disjoint instruction/data SRAM slices, matching s3-cache-closure.ld.
 */
ENTRY(abla_window_vectors_target)
MEMORY {
    internal_code (rx) : ORIGIN = 0x40378000, LENGTH = 0x10000
    internal_data (rw) : ORIGIN = 0x3FC98000, LENGTH = 0x10000
}
SECTIONS {
    .iram1.abla.s3WindowVectors ORIGIN(internal_code) : {
        KEEP(*(.iram1.abla.s3WindowVectors))
    } > internal_code
    /* Do not place ordinary instructions in unimplemented vector slots. */
    .iram1 ORIGIN(internal_code) + 0x400 : {
        *(.iram1 .iram1.*)
    } > internal_code
    .dram1 : ALIGN(4) { *(.dram1 .dram1.*) } > internal_data
    .forbidden : { *(.text .text.* .rodata .rodata.* .data .data.* .bss .bss.* COMMON) } > internal_data
    /DISCARD/ : { *(.xtensa.info .xt.lit .xt.prop .note.GNU-stack .comment) }
}
ASSERT((ADDR(.iram1.abla.s3WindowVectors) & 1023) == 0, "VECBASE must be 1024 aligned")
ASSERT(SIZEOF(.iram1.abla.s3WindowVectors) == 0x180, "six window vector slots required")
ASSERT(SIZEOF(.forbidden) == 0, "vector closure retained ordinary code/data")
ASSERT(ADDR(.iram1) + SIZEOF(.iram1) - 0x40378000 <= ADDR(.dram1) - 0x3FC88000,
       "S3 code/data physical SRAM aliases overlap")
