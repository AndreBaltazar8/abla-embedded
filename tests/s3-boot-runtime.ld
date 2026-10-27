/* Link-only boot + BSS + runtime setup checkpoint; NOT flashable firmware. */
ENTRY(abla_boot_entry)
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
    .iram1.abla.s3BootVectors : ALIGN(1024) { KEEP(*(.iram1.abla.s3BootVectors)) } > internal_code
    .iram1 : ALIGN(4) { *(.iram1 .iram1.*) } > internal_code
    .dram1.abla.s3IrqConfig : ALIGN(4) { *(.dram1.abla.s3IrqConfig) } > internal_data
    .dram1.abla.s3FatalRecords : ALIGN(16) { *(.dram1.abla.s3FatalRecords) } > internal_data
    .dram1 : ALIGN(4) { *(.dram1 .dram1.*) } > internal_data
    .bss (NOLOAD) : ALIGN(16) {
        __abla_bss_low = .;
        __abla_runtime_local = .; . += 48;
        __abla_runtime_shared = .; . += 544;
        __abla_current_tasks = .; . += 8;
        __abla_task_binding = .; . += 16;
        __abla_second_binding = .; . += 16;
        __abla_scheduler_context = .; . += 44;
        __abla_scheduler_adapter = .; . += 12;
        __abla_scheduler_queue = .; . += 20;
        __abla_scheduler_tasks = .; . += 32;
        __abla_scheduler_running = .; . += 8;
        __abla_scheduler_tick = .; . += 16;
        __abla_preemption_state = .; . += 16;
        . = ALIGN(16); __abla_simd_witness = .; . += 832;
        . = ALIGN(16); __abla_task_cp0 = .; . += 256;
        __abla_task_cp3 = .; . += 256;
        __abla_second_cp0 = .; . += 256;
        __abla_second_cp3 = .; . += 256;
        *(.bss .bss.* COMMON)
        . = ALIGN(4); __abla_bss_top = .;
    } > internal_data
    .boot_stack (NOLOAD) : ALIGN(16) {
        __abla_boot_stack_low = .; . += 4096; __abla_boot_stack_top = .;
    } > internal_data
    .irq_stack (NOLOAD) : ALIGN(16) {
        __abla_irq_stack_low = .; . += 4096;
    } > internal_data
    .task_stack (NOLOAD) : ALIGN(16) {
        __abla_task_stack_low = .; . += 4096;
        __abla_second_stack_low = .; . += 4096;
    } > internal_data
    __abla_rtc_bss_low = 0; __abla_rtc_bss_top = 0;
    .forbidden : { *(.text .text.* .rodata .rodata.* .data .data.*) } > internal_data
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
ASSERT((ADDR(.iram1.abla.s3BootVectors) & 1023) == 0 && SIZEOF(.iram1.abla.s3BootVectors) == 1024, "early vector placement")
ASSERT(ADDR(.iram1) + SIZEOF(.iram1) - 0x40378000 <= ADDR(.dram1.abla.s3IrqConfig) - 0x3FC88000,
       "S3 code/data physical SRAM aliases overlap")
