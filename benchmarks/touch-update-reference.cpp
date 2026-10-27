#include <cstdint>

namespace {
struct alignas(8) TouchDetail {
    std::uint64_t point;
    std::uint64_t previous;
    std::uint64_t base;
    std::uint32_t base_milliseconds;
    std::uint8_t state;
    std::uint8_t click_count;
    std::uint16_t reserved;
};

constexpr std::uint8_t pressed_mask = 1;
constexpr std::uint8_t changed_mask = 2;
constexpr std::uint8_t moving_mask = 8;
constexpr std::uint8_t pressed = 1;
constexpr std::uint8_t touch_end = 2;
constexpr std::uint8_t touch_begin = 3;
constexpr std::uint8_t hold_begin = 7;
constexpr std::uint8_t flick_begin = 11;

std::int32_t coordinate(std::uint64_t point, unsigned shift) {
    return static_cast<std::int16_t>(point >> shift);
}

std::uint16_t size(std::uint64_t point) {
    return static_cast<std::uint16_t>(point >> 32);
}

std::uint8_t id(std::uint64_t point) {
    return static_cast<std::uint8_t>((point >> 48) & 7);
}

std::uint64_t with_metadata(
    std::uint64_t point,
    std::uint64_t next
) {
    return (point & 0xffffffffu) | (next & 0xfffff00000000ull);
}

std::int32_t absolute(std::int32_t value) {
    return value < 0 ? -value : value;
}
}

extern "C" __attribute__((noinline)) bool cxx_touch_detail_update(
    TouchDetail* address,
    std::uint32_t now_milliseconds,
    bool is_pressed,
    std::uint64_t next,
    std::uint32_t hold_milliseconds,
    std::int32_t flick_threshold
) {
    auto& detail = *address;
    std::uint8_t mode = detail.state;
    if (mode == 0 && !is_pressed) return false;
    mode &= ~changed_mask;
    if (is_pressed) {
        detail.previous = detail.point;
        detail.point = with_metadata(detail.point, next);
        if ((mode & moving_mask) == 0) {
            if ((mode & pressed_mask) != 0) {
                if (absolute(coordinate(detail.base, 0) -
                        coordinate(next, 0)) > flick_threshold ||
                    absolute(coordinate(detail.base, 16) -
                        coordinate(next, 16)) > flick_threshold) {
                    detail.previous = detail.base;
                    mode |= flick_begin;
                } else if (mode == pressed &&
                    now_milliseconds - detail.base_milliseconds >
                        hold_milliseconds) {
                    mode = hold_begin;
                }
            } else {
                detail.point = next;
                mode = touch_begin;
                if (now_milliseconds - detail.base_milliseconds >
                        hold_milliseconds ||
                    absolute(coordinate(detail.base, 0) -
                        coordinate(next, 0)) > ((flick_threshold + 1) << 2) ||
                    absolute(coordinate(detail.base, 16) -
                        coordinate(next, 16)) > ((flick_threshold + 1) << 2)) {
                    detail.click_count = 0;
                }
                detail.base_milliseconds = now_milliseconds;
                detail.base = next;
                detail.previous = next;
            }
        }
        if ((mode & moving_mask) != 0) detail.point = next;
    } else {
        mode = (mode & pressed_mask)
            ? (mode | changed_mask) & ~pressed_mask
            : 0;
        if (mode == touch_end) {
            detail.base_milliseconds = now_milliseconds;
            ++detail.click_count;
        }
    }
    detail.state = mode;
    return true;
}
