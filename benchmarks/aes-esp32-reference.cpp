#include <cstdint>

namespace {

inline volatile std::uint32_t* word(std::uint32_t address) {
    return reinterpret_cast<volatile std::uint32_t*>(address);
}

} // namespace

extern "C" __attribute__((noinline)) bool cxx_esp32_aes128_encrypt_block(
    std::uint32_t key_address,
    std::uint32_t input_address,
    std::uint32_t output_address,
    std::uint32_t maximum_polls
) {
    constexpr std::uint32_t last_block_address = 0xfffffff0u;
    if (key_address == 0 || input_address == 0 || output_address == 0 ||
        maximum_polls == 0 || key_address > last_block_address ||
        input_address > last_block_address ||
        output_address > last_block_address || (key_address & 3u) != 0 ||
        (input_address & 3u) != 0 || (output_address & 3u) != 0) return false;

    auto clock = word(0x3ff0001cu);
    auto reset = word(0x3ff00020u);
    *clock = *clock | 1u;
    *reset = *reset | 1u;
    *reset = *reset & ~25u;

    auto key = word(key_address);
    auto input = word(input_address);
    auto output = word(output_address);
    auto aes_key = word(0x3ff01010u);
    auto aes_text = word(0x3ff01030u);
    aes_key[0] = key[0];
    aes_key[1] = key[1];
    aes_key[2] = key[2];
    aes_key[3] = key[3];
    aes_text[0] = input[0];
    aes_text[1] = input[1];
    aes_text[2] = input[2];
    aes_text[3] = input[3];
    *word(0x3ff01008u) = 0;
    *word(0x3ff01000u) = 1;

    std::uint32_t polls = 0;
    std::uint32_t idle = *word(0x3ff01004u);
    while (idle == 0 && polls < maximum_polls) {
        ++polls;
        idle = *word(0x3ff01004u);
    }
    if (idle == 0) return false;
    output[0] = aes_text[0];
    output[1] = aes_text[1];
    output[2] = aes_text[2];
    output[3] = aes_text[3];
    return true;
}
