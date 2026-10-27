/* Link-only PSRAM boot closure, NOT reset entry or a flashable image.
 * S3 physical aliases:40378000(I)==3fc88000(D). Keep code in first64KiB
 * and data/owner/stack in next64KiB. Both below bootloader-reserved SRAM,
 * and below DCache banks3fcf0000..3fd00000 and ICache40370000..40378000.
 * Size owner for maximum512 MMU pages:672+4*512=2720B.
 */
ENTRY(abla_esp32s3_psram_boot80_configured_example)
MEMORY {
    internal_code (rx) : ORIGIN = 0x40378000, LENGTH = 0x10000
    internal_data (rw) : ORIGIN = 0x3fc98000, LENGTH = 0x10000
}
SECTIONS {
    .iram1 : ALIGN(4) { *(.iram1 .iram1.*) } > internal_code
    .dram1 : ALIGN(4) { *(.dram1 .dram1.*) } > internal_data
    .dram1.psram_owner (NOLOAD) : ALIGN(16) {
        __abla_psram_owner_low = .; . += 2720; __abla_psram_owner_high = .;
    } > internal_data
    .dram1.psram_stack (NOLOAD) : ALIGN(16) {
        __abla_psram_stack_low = .; . += 8192; __abla_psram_stack_high = .;
    } > internal_data
    .forbidden : { *(.text .text.* .rodata .rodata.* .data .data.* .bss .bss.* COMMON) } > internal_data
    /* Non-allocated decoder metadata: distinguish padding/literals from
     * instructions. Retaining this consumes no device RAM or image segment. */
    .xt.prop 0 : { *(.xt.prop .xt.prop.*) }
    .xt.lit 0 : { *(.xt.lit .xt.lit.*) }
    /DISCARD/ : { *(.xtensa.info .note.GNU-stack .comment) }
}
ASSERT(SIZEOF(.forbidden) == 0, "PSRAM closure retained ordinary code/data")
ASSERT(SIZEOF(.iram1) > 0, "PSRAM closure has no code")
ASSERT(ADDR(.iram1) + SIZEOF(.iram1) - 0x40378000 <= ORIGIN(internal_data) - 0x3fc88000,
       "PSRAM code/data physical SRAM aliases overlap")
ASSERT(__abla_psram_stack_high <= 0x3fcc9000, "PSRAM storage enters bootloader startup reservation")
ASSERT(__abla_psram_stack_high <= 0x3fcf0000, "PSRAM storage enters DCache banks")
ASSERT((__abla_psram_owner_low & 15) == 0 && (__abla_psram_stack_high & 15) == 0,
       "PSRAM owner/stack alignment")
ASSERT(__abla_psram_owner_high <= __abla_psram_stack_low, "PSRAM owner/stack overlap")
