#include <cstdint>

extern "C" __attribute__((noinline)) bool cxx_wifi_ccmp_packet_number_fresh(
    std::int64_t candidate, std::int64_t previous
) {
    constexpr std::int64_t maximum = 0x0000ffffffffffffLL;
    const bool candidate_valid = candidate >= 0 && candidate <= maximum;
    const bool previous_valid = previous >= 0 && previous <= maximum;
    return candidate_valid && (!previous_valid || candidate > previous);
}
