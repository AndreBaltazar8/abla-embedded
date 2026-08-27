#include <cstdint>

extern "C" __attribute__((noinline)) bool
cxx_wifi_management_frame_valid(
    std::uint32_t address,
    std::uint32_t length
) {
    if (address == 0 || length < 24u || address > 0xffffffffu - length) {
        return false;
    }
    const auto *frame = reinterpret_cast<const volatile std::uint8_t *>(
        static_cast<std::uintptr_t>(address)
    );
    const std::uint16_t control =
        static_cast<std::uint16_t>(frame[0]) |
        static_cast<std::uint16_t>(frame[1]) << 8;
    if ((control & 3u) != 0 || ((control >> 2) & 3u) != 0) {
        return false;
    }
    const std::uint8_t subtype = static_cast<std::uint8_t>(control >> 4) & 15u;
    std::uint32_t fixed = 0;
    switch (subtype) {
    case 0: fixed = 4; break;
    case 1: case 3: fixed = 6; break;
    case 2: fixed = 10; break;
    case 4: case 9: fixed = 0; break;
    case 5: case 8: fixed = 12; break;
    case 11: fixed = 6; break;
    case 10: case 12: fixed = 2; break;
    case 6: case 13: case 14: return true;
    default: return false;
    }
    std::uint32_t current = 24u + fixed;
    if (current > length) {
        return false;
    }
    while (current < length) {
        if (current > length - 2u) {
            return false;
        }
        const std::uint32_t element_length = frame[current + 1u];
        if (element_length > length - current - 2u) {
            return false;
        }
        current += element_length + 2u;
    }
    return current == length;
}
