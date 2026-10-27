#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
extern uint32_t abla_sqrt_f32_bits(uint32_t);
static int check(uint32_t bits) {
    float x, y;
    uint32_t expected;
    memcpy(&x, &bits, 4);
    y = sqrtf(x);
    memcpy(&expected, &y, 4);
    uint32_t actual = abla_sqrt_f32_bits(bits);
    if ((expected & 0x7fffffff) > 0x7f800000) {
        if ((actual & 0x7fffffff) > 0x7f800000 && (actual & 0x400000)) return 0;
    } else if (actual == expected) return 0;
    fprintf(stderr, "sqrt %08x: got %08x expected %08x\n", bits, actual, expected);
    return 1;
}
int main(void) {
    const uint32_t edges[] = {0, 0x80000000, 1, 2, 3, 0x7fffff, 0x800000,
        0x3f7fffff, 0x3f800000, 0x3f800001, 0x7f7fffff,
        0x7f800000, 0xff800000, 0x7f800001, 0xffc00001};
    for (unsigned i=0; i<sizeof edges/sizeof *edges; ++i) if (check(edges[i])) return 1;
    // Every positive subnormal plus stratified normal/negative/NaN inputs.
    for (uint32_t i=1; i<0x800000; ++i) if (check(i)) return 1;
    uint32_t state=0x12345678;
    for (unsigned i=0; i<1000000; ++i) {
        state=1664525*state+1013904223;
        if (check(state)) return 1;
    }
    puts("PASS: all positive subnormals, one million sampled encodings, and edge cases");
    return 0;
}
