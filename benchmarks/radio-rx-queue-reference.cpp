#include <cstdint>

extern "C" __attribute__((noinline)) std::uint32_t
cxx_wifi_rx_take_first(std::uint32_t queue_address, std::int32_t max_polls) {
    if (queue_address == 0 || queue_address > 0xfffffff8u ||
        (queue_address & 3u) != 0 || max_polls <= 0) {
        return 0;
    }
    auto queue = reinterpret_cast<volatile std::uint32_t *>(
        static_cast<std::uintptr_t>(queue_address)
    );
    const std::uint32_t first_address = queue[0];
    const std::uint32_t state = queue[1];
    if ((state & 3u) != 0) return 0;
    const std::uint32_t last_address = state & 0xfffffffcu;
    if (first_address == 0 || last_address == 0 ||
        first_address > 0xfffffff4u || last_address > 0xfffffff4u ||
        ((first_address | last_address) & 3u) != 0) {
        return 0;
    }
    auto first = reinterpret_cast<volatile std::uint32_t *>(
        static_cast<std::uintptr_t>(first_address)
    );
    const std::uint32_t flags = first[0];
    const std::uint32_t capacity = flags & 0xfffu;
    const std::uint32_t length = (flags >> 12) & 0xfffu;
    if ((flags & 0x80000000u) != 0 || (flags & 0x40000000u) == 0 ||
        length < 32u || length > capacity) {
        return 0;
    }
    const std::uint32_t next = first[2];
    if ((next & 3u) != 0 || ((first_address == last_address) != (next == 0))) {
        return 0;
    }
    queue[1] = last_address | 1u;
    auto rx_base = reinterpret_cast<volatile std::uint32_t *>(0x3ff73088u);
    auto rx_control = reinterpret_cast<volatile std::uint32_t *>(0x3ff73084u);
    *rx_base = next;
    *rx_control = *rx_control | 1u;
    std::uint32_t reload = *rx_control & 1u;
    while (reload != 0 && max_polls > 1) {
        --max_polls;
        reload = *rx_control & 1u;
    }
    if (reload != 0) return 0;
    queue[0] = next;
    queue[1] = next == 0 ? 0 : last_address;
    return first_address;
}
