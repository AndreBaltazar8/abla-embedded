/* Entry + BSS + PSRAM integration only, not a flashable board image.
 * Loader request is initialized outside BSS and refused until explicitly
 * populated by an owner with the documented board/clock/flash proofs. */
ENTRY(abla_boot_entry)
MEMORY {
    internal_code (rx) : ORIGIN = 0x40378000, LENGTH = 0x10000
    internal_data (rw) : ORIGIN = 0x3fc98000, LENGTH = 0x10000
}
SECTIONS {
    .iram1.abla.s3BootVectors : ALIGN(1024) { KEEP(*(.iram1.abla.s3BootVectors)) } > internal_code
    .iram1 : ALIGN(4) { *(.iram1 .iram1.*) } > internal_code
    .dram1 : ALIGN(4) { *(.dram1 .dram1.*) } > internal_data
    .request : ALIGN(16) {
        __abla_psram_request = .;
        LONG(0x53335053) LONG(0) . += 44;
        __abla_psram_request_top = .;
    } > internal_data
    .bss (NOLOAD) : ALIGN(16) {
        __abla_bss_low = .;
        __abla_psram_owner_low = .; . += 2720;
        __abla_psram_result = .; . += 4;
        *(.bss .bss.* COMMON)
        . = ALIGN(16); __abla_bss_top = .;
    } > internal_data
    .boot_stack (NOLOAD) : ALIGN(16) {
        __abla_boot_stack_low = .; . += 8192; __abla_boot_stack_top = .;
    } > internal_data
    __abla_rtc_bss_low = 0; __abla_rtc_bss_top = 0;
    .forbidden : { *(.text .text.* .rodata .rodata.* .data .data.*) } > internal_data
    .xt.prop 0 : { *(.xt.prop .xt.prop.*) }
    .xt.lit 0 : { *(.xt.lit .xt.lit.*) }
    /DISCARD/ : { *(.xtensa.info .note.GNU-stack .comment) }
}
ASSERT((ADDR(.iram1.abla.s3BootVectors) & 1023) == 0 && SIZEOF(.iram1.abla.s3BootVectors) == 1024, "early vector placement")
ASSERT(SIZEOF(.forbidden) == 0, "non-internal startup code/data")
ASSERT(ADDR(.iram1)+SIZEOF(.iram1)-0x40378000 <= ORIGIN(internal_data)-0x3fc88000, "physical code/data alias overlap")
ASSERT(__abla_psram_request_top-__abla_psram_request == 52, "request layout")
ASSERT(__abla_psram_request_top <= __abla_bss_low && __abla_bss_top <= __abla_boot_stack_low, "request/BSS/stack overlap")
ASSERT(__abla_boot_stack_top <= 0x3fcc9000, "bootloader/cache SRAM reservation")
