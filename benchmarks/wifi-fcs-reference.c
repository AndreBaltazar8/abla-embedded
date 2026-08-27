#include <stdint.h>

uint32_t c_wifi_fcs_native(uint32_t address, uint32_t length) {
    const volatile uint8_t *bytes =
        (const volatile uint8_t *)(uintptr_t)address;
    uint32_t crc = UINT32_MAX;
    for (uint32_t index = 0; index < length; ++index) {
        crc ^= bytes[index];
        for (uint32_t bit = 0; bit < 8; ++bit) {
            crc = (crc >> 1) ^
                (UINT32_C(0xedb88320) & (uint32_t)-(int32_t)(crc & 1u));
        }
    }
    return ~crc;
}
