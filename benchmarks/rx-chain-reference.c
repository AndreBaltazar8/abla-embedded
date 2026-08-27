#include <stdbool.h>
#include <stdint.h>

bool c_wifi_prepare_rx_chain_native(
    uint32_t descriptor_base,
    uint32_t buffer_base,
    uint32_t descriptor_count
) {
    if (descriptor_base == 0 || (descriptor_base & 3u) != 0 ||
        descriptor_count == 0 || descriptor_count > 4095u ||
        buffer_base == 0 || (buffer_base & 3u) != 0) return false;
    uint32_t descriptor_bytes = (descriptor_count - 1u) * 12u;
    uint32_t buffer_bytes = (descriptor_count - 1u) * 1600u + 1599u;
    if (descriptor_base > UINT32_MAX - descriptor_bytes ||
        buffer_base > UINT32_MAX - buffer_bytes) return false;
    for (uint32_t index = 0; index < descriptor_count; ++index) {
        volatile uint32_t *descriptor =
            (volatile uint32_t *)(uintptr_t)(descriptor_base + index * 12u);
        uint32_t next = index + 1u < descriptor_count
            ? descriptor_base + (index + 1u) * 12u
            : 0u;
        descriptor[1] = buffer_base + index * 1600u;
        descriptor[2] = next;
        descriptor[0] = 0x80000640u;
    }
    return true;
}
