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
