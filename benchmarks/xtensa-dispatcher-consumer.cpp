#include <stdint.h>

extern "C" {
extern uint32_t _xt_interrupt_table[];
extern uint32_t _xt_exception_table[];
extern uint8_t Xthal_intlevel[];
uint32_t xt_ints_on(uint32_t mask);
uint32_t xt_ints_off(uint32_t mask);
void xt_unhandled_interrupt(void *argument);
bool xt_int_has_handler(int interrupt, int cpu);
void *xt_set_interrupt_handler(int interrupt, void *handler, void *argument);
void *xt_set_exception_handler(int exception, void *handler);
}

// Every ABI symbol in xtensa_intr_asm.S is referenced so the archive member
// would be selected unless the Abla object supplies the whole unit.
extern "C" uintptr_t abla_dispatcher_link_probe(uint32_t mask) {
    uintptr_t result = xt_ints_on(mask) ^ xt_ints_off(mask);
    result ^= reinterpret_cast<uintptr_t>(_xt_interrupt_table);
    result ^= reinterpret_cast<uintptr_t>(_xt_exception_table);
    result ^= reinterpret_cast<uintptr_t>(Xthal_intlevel);
    result ^= reinterpret_cast<uintptr_t>(
        xt_set_interrupt_handler(0, nullptr, nullptr));
    result ^= reinterpret_cast<uintptr_t>(
        xt_set_exception_handler(0, nullptr));
    result ^= static_cast<uintptr_t>(xt_int_has_handler(0, 0));
    xt_unhandled_interrupt(nullptr);
    return result;
}
