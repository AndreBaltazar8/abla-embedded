#include <cstdint>

extern "C" __attribute__((noinline)) bool
cxx_wifi_prepare_tx_descriptor(
    std::uint32_t descriptor_address,
    std::uint32_t buffer_address,
    std::uint32_t mpdu_length
) {
    if (descriptor_address < 0x3ff00004u ||
        descriptor_address > 0x3ffffff4u ||
        (descriptor_address & 3u) != 0 || buffer_address == 0 ||
        mpdu_length > 4091u ||
        (mpdu_length != 0 && buffer_address > 0xffffffffu - mpdu_length + 1u)) {
        return false;
    }
    const std::uint32_t frame_length = mpdu_length + 4u;
    auto descriptor = reinterpret_cast<volatile std::uint32_t *>(
        static_cast<std::uintptr_t>(descriptor_address)
    );
    descriptor[1] = buffer_address;
    descriptor[2] = 0;
    descriptor[0] = 0xc0000000u | frame_length | (frame_length << 12);
    return true;
}
