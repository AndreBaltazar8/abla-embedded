/* Link-only placement regression, NOT a bootloader/application image.
 * S3 IDF memory.ld.in: I40378000 aliases D3fc88000. Reserve first1KiB
 * for future vectors, then disjoint64KiB physical code/data slices.
 * Flash mappings model cache-on callers only; no image/MMU setup implied.
 */
ENTRY(abla_paper_s3_sleep_cycle_example)
MEMORY {
    internal_code (rx) : ORIGIN = 0x40378400, LENGTH = 0xFC00
    internal_data (rw) : ORIGIN = 0x3FC98000, LENGTH = 0x10000
    flash_code (rx) : ORIGIN = 0x42000020, LENGTH = 0x100000
    flash_data (r) : ORIGIN = 0x3C000020, LENGTH = 0x100000
}
SECTIONS {
    .iram1 : ALIGN(4) { *(.iram1 .iram1.*) } > internal_code
    .dram1 : ALIGN(16) { *(.dram1 .dram1.*) *(.data .data.*) } > internal_data
    .bss (NOLOAD) : ALIGN(16) { *(.bss .bss.* COMMON) } > internal_data
    .sleep_storage (NOLOAD) : ALIGN(16) {
        __paper_cycle = .; . += 336;
        __paper_config = .; . += 72;
        __paper_touch_scratch = .; . += 40;
        __paper_scheduler = .; . += 32;
        __paper_quiesce = .; . += 32;
        __paper_scheduler_lock = .; . += 4;
        __paper_peer_mailbox = .; . += 4;
        . = ALIGN(16); __paper_cpu_retention = .; . += 8800;
        . = ALIGN(16); __paper_tag_retention = .; . += 9232;
    } > internal_data
    .sleep_stack (NOLOAD) : ALIGN(16) {
        __paper_sleep_stack_low = .; . += 8192; __paper_sleep_stack_top = .;
        __paper_peer_stack_low = .; . += 4096; __paper_peer_stack_top = .;
    } > internal_data
    .flash_text : ALIGN(4) { *(.literal .literal.*) *(.text .text.*) } > flash_code
    .flash_rodata : ALIGN(4) { *(.rodata .rodata.*) } > flash_data
    /* Keep non-allocated Xtensa instruction/padding metadata for exact
     * disassembly; without it, alignment bytes can decode as fake L32R. */
    .xt.prop 0 : { *(.xt.prop .xt.prop.*) }
    .xt.lit 0 : { *(.xt.lit .xt.lit.*) }
    /DISCARD/ : { *(.xtensa.info .note.GNU-stack .comment .llvm_addrsig) }
}
ASSERT(SIZEOF(.iram1) > 0, "missing retained code")
ASSERT(ADDR(.iram1)+SIZEOF(.iram1)-0x40378000 <= ORIGIN(internal_data)-0x3FC88000,
       "code/data physical SRAM aliases overlap")
ASSERT((__paper_cpu_retention & 15) == 0 && (__paper_tag_retention & 15) == 0,
       "retention DMA alignment")
ASSERT((__paper_sleep_stack_top & 15) == 0 && (__paper_peer_stack_top & 15) == 0,
       "Xtensa stack alignment")
