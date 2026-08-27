#include <stdbool.h>
#include <stdint.h>

#define REG32(address) (*(volatile uint32_t *)(uintptr_t)(address))

bool c_wifi_radio_power_on_240mhz(void) {
    REG32(1072988292u) &= ~131072u;

    __asm__ volatile(
        "rsr a8, ccount\n"
        "1: rsr a9, ccount\n"
        "sub a9, a9, a8\n"
        "bltu a9, %0, 1b"
        :
        : "a"(2400u)
        : "a8", "a9"
    );

    uint32_t previous = REG32(1072693452u) & 969u;
    REG32(1072693452u) |= 969u;
    REG32(1072693456u) |= 541u;
    REG32(1072693456u) &= ~541u;
    REG32(1072988296u) &= ~268435456u;
    REG32(1072693452u) =
        (REG32(1072693452u) & ~969u) | previous;
    return true;
}
