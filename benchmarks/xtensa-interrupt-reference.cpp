#include <cstdint>

extern "C" __attribute__((noinline)) std::uint32_t cxx_esp32_core_id() {
    std::uint32_t id;
    asm volatile(
        "rsr.prid %0\n"
        "extui %0, %0, 13, 1"
        : "=a"(id)
    );
    return id;
}

extern "C" __attribute__((noinline)) std::uint32_t
cxx_xtensa_interrupts_enable(std::uint32_t mask) {
    std::uint32_t previous;
    asm volatile(
        "movi %0, 0\n"
        "xsr %0, intenable\n"
        "rsync\n"
        "or a8, %0, %1\n"
        "wsr a8, intenable\n"
        "rsync"
        : "=&a"(previous)
        : "a"(mask)
        : "a8"
    );
    return previous;
}

extern "C" __attribute__((noinline)) std::uint32_t
cxx_xtensa_interrupts_disable(std::uint32_t mask) {
    std::uint32_t previous;
    asm volatile(
        "movi %0, 0\n"
        "xsr %0, intenable\n"
        "rsync\n"
        "or a8, %0, %1\n"
        "xor a8, a8, %1\n"
        "wsr a8, intenable\n"
        "rsync"
        : "=&a"(previous)
        : "a"(mask)
        : "a8"
    );
    return previous;
}
extern "C" __attribute__((section(".iram1.text"), noinline, used))
void cxx_xtensa_interrupt_handler() {
    auto status = *reinterpret_cast<volatile std::uint32_t *>(0x3ff730c0);
    *reinterpret_cast<volatile std::uint32_t *>(0x3ff730c4) = status;
}

extern "C" __attribute__((noinline)) std::uint32_t
cxx_xtensa_interrupt_handler_address() {
    return reinterpret_cast<std::uintptr_t>(&cxx_xtensa_interrupt_handler);
}

struct XtensaInterruptEntry {
    volatile std::uintptr_t handler;
    volatile std::uintptr_t argument;
};

extern "C" XtensaInterruptEntry _xt_interrupt_table[];

extern "C" __attribute__((noinline)) bool
cxx_wifi_mac_install_interrupt_handler() {
    std::uint32_t core;
    asm volatile(
        "rsr.prid %0\n"
        "extui %0, %0, 13, 1"
        : "=a"(core)
    );
    if (core >= 2) return false;

    std::uint32_t previous;
    asm volatile(
        "movi %0, 0\n"
        "xsr %0, intenable\n"
        "rsync\n"
        "or a8, %0, %1\n"
        "xor a8, a8, %1\n"
        "wsr a8, intenable\n"
        "rsync"
        : "=&a"(previous)
        : "a"(std::uint32_t{1})
        : "a8"
    );

    auto &entry = _xt_interrupt_table[core];
    entry.argument = 0;
    entry.handler = reinterpret_cast<std::uintptr_t>(
        &cxx_xtensa_interrupt_handler
    );

    if ((previous & 1) != 0) {
        asm volatile(
            "movi a8, 0\n"
            "xsr a8, intenable\n"
            "rsync\n"
            "or a9, a8, %0\n"
            "wsr a9, intenable\n"
            "rsync"
            :
            : "a"(std::uint32_t{1})
            : "a8", "a9"
        );
    }
    return true;
}
