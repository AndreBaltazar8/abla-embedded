#include <cstdint>

extern "C" __attribute__((noinline)) bool
cxx_wifi_rx_frame_valid(std::uint64_t descriptor_address) {
    if (descriptor_address == 0 || descriptor_address > 0xfffffffcu ||
        (descriptor_address & 3u) != 0) {
        return false;
    }
    auto descriptor = reinterpret_cast<volatile std::uint32_t *>(
        static_cast<std::uintptr_t>(descriptor_address)
    );
    const std::uint32_t flags = descriptor[0];
    const std::uint32_t capacity = flags & 0xfffu;
    const std::uint32_t length = (flags >> 12) & 0xfffu;
    if ((flags & 0x80000000u) != 0 || (flags & 0x40000000u) == 0 ||
        length < 32u || length > capacity) {
        return false;
    }
    const std::uint32_t buffer = descriptor[1];
    if (buffer == 0 || buffer > 0xffffffe0u) {
        return false;
    }
    const auto signal = *reinterpret_cast<volatile std::uint32_t *>(
        static_cast<std::uintptr_t>(buffer + 24u)
    );
    return (signal & 0xfffu) < length &&
        ((signal >> 12) & 0xfffu) < length;
}
