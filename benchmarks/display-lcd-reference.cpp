#include <cstdint>

extern "C" __attribute__((noinline)) std::int32_t cxx_display_rgb565(
    std::int32_t red,
    std::int32_t green,
    std::int32_t blue
) {
    return ((red & 248) << 8) | ((green & 252) << 3) |
        ((static_cast<std::uint32_t>(blue) & 248) >> 3);
}

extern "C" __attribute__((noinline)) std::uint64_t cxx_display_view() {
    // M5StickC Plus2's fixed rotation resolves to this packed view.
    return 8839097467015ull;
}
