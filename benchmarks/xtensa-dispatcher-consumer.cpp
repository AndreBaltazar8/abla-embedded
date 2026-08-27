#include <stdint.h>

extern "C" {
extern uint32_t _xt_interrupt_table[];
extern uint32_t _xt_exception_table[];
uint32_t xt_ints_on(uint32_t mask);
uint32_t xt_ints_off(uint32_t mask);
void *xt_set_interrupt_handler(int interrupt, void *handler, void *argument);
}

// Every ABI symbol in xtensa_intr_asm.S is referenced so the archive member
// would be selected unless the Abla object supplies the whole unit.
extern "C" uintptr_t abla_dispatcher_link_probe(uint32_t mask) {
    uintptr_t result = xt_ints_on(mask) ^ xt_ints_off(mask);
    result ^= reinterpret_cast<uintptr_t>(_xt_interrupt_table);
    result ^= reinterpret_cast<uintptr_t>(_xt_exception_table);
    result ^= reinterpret_cast<uintptr_t>(
        xt_set_interrupt_handler(0, nullptr, nullptr));
    return result;
}
