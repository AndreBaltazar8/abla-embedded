#include <cstdint>

extern "C" __attribute__((noinline)) std::uint32_t
cxx_wifi_station_authentication_transition(
    std::uint32_t state, std::uint32_t algorithm,
    std::uint32_t transaction, std::uint32_t status
) {
    auto result = [](std::uint32_t next, std::uint32_t action,
                     std::uint32_t code = 0) {
        return (next & 255u) | ((action & 255u) << 8) |
            ((code & 65535u) << 16);
    };
    if (state != 2) return result(state, 0);
    if (status != 0) return result(1, 1, status);
    if ((algorithm == 0 && transaction == 2) ||
        (algorithm == 2 && transaction == 2) ||
        (algorithm == 4 && transaction == 2) ||
        (algorithm == 5 && transaction == 2)) return result(3, 5);
    if (algorithm == 1) {
        if (transaction == 2) return result(2, 3);
        if (transaction == 4) return result(3, 5);
    }
    if (algorithm == 3) {
        if (transaction == 2) return result(2, 4);
        if (transaction == 4) return result(3, 5);
    }
    return result(state, 9, status);
}
