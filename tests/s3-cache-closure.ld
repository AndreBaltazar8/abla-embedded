/* Link-only regression, NOT a bootable firmware or upload image.
 * S3 IDF memory.ld.in: 40378000(I) aliases 3fc88000(D).
 * Reserve disjoint 64KiB physical slices for code then data; both are below
 * bootloader-reserved SRAM. The test reserves no CPU vectors or runtime stack.
 */
ENTRY(abla_mspi_transition_target)
MEMORY {
    internal_code (rx) : ORIGIN = 0x40378000, LENGTH = 0x10000
    internal_data (rw) : ORIGIN = 0x3FC98000, LENGTH = 0x10000
}
SECTIONS {
    .iram1 : ALIGN(4) { *(.iram1 .iram1.*) } > internal_code
    .dram1 : ALIGN(4) { *(.dram1 .dram1.*) } > internal_data
    .forbidden : { *(.text .text.* .rodata .rodata.* .data .data.* .bss .bss.* COMMON) } > internal_data
    /DISCARD/ : { *(.xtensa.info .xt.lit .xt.prop .note.GNU-stack .comment) }
}
ASSERT(SIZEOF(.forbidden) == 0, "cache closure retained ordinary code/data")
ASSERT(SIZEOF(.iram1) > 0, "cache closure has no code")
ASSERT(ADDR(.iram1) + SIZEOF(.iram1) - 0x40378000 <= ADDR(.dram1) - 0x3FC88000,
       "S3 code/data physical SRAM aliases overlap")
