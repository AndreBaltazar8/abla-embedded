/* Host-only runner for embedded NativeBuffer's packed32-bit addresses.
 * Never linked into firmware. Run the unchanged Abla test on a guarded,
 * low-address stack instead of replacing its stack-buffer APIs with mocks. */
#define _GNU_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <sys/mman.h>
#include <ucontext.h>
#include <unistd.h>
#ifndef ABLA_TEST_ENTRY
#error Define ABLA_TEST_ENTRY to the exported Abla test entry
#endif
extern int32_t ABLA_TEST_ENTRY(void);
/* The compiler's indirect-call checks end here, as on a device: the host's runtime
 * panic prints and exits 101, and firmware links its own. */
void abla_platform_panic(const char *message, int64_t size);
void abla_platform_panic(const char *message, int64_t size) {
    (void)!write(2, "panic: ", 7);
    (void)!write(2, message, (size_t)size);
    (void)!write(2, "\n", 1);
    _exit(101);
}
static ucontext_t caller, test;
static int result = 125;
static void invoke(void) { result = ABLA_TEST_ENTRY(); }
int main(void) {
#ifdef ABLA_TEST_C6_SRAM
    /* Optional host-only SRAM window for testing real NativeBuffer copies.
     * NOREPLACE refuses collisions; never overwrite an existing mapping. */
    void *c6_sram = mmap((void *)(uintptr_t)0x40800000, 0x80000,
                        PROT_READ | PROT_WRITE,
                        MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
    if (c6_sram == MAP_FAILED) { perror("C6 SRAM mmap"); return 125; }
    if ((uintptr_t)c6_sram != 0x40800000) { munmap(c6_sram, 0x80000); return 125; }
#endif
    const long page = sysconf(_SC_PAGESIZE);
    if (page <= 0) return 125;
    const size_t size = 1024 * 1024;
    const size_t total = size + 2 * (size_t)page;
    void *mapping = mmap(NULL, total, PROT_NONE,
                         MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
    if (mapping == MAP_FAILED) { perror("low-stack mmap"); return 125; }
    if ((uintptr_t)mapping + total > UINT32_MAX ||
        mprotect((char *)mapping + page, size, PROT_READ | PROT_WRITE) ||
        getcontext(&test)) {
        perror("low-stack setup"); munmap(mapping, total); return 125;
    }
    test.uc_stack.ss_sp = (char *)mapping + page;
    test.uc_stack.ss_size = size;
    test.uc_link = &caller;
    makecontext(&test, invoke, 0);
    if (swapcontext(&caller, &test)) { perror("low-stack switch"); result = 125; }
    if (munmap(mapping, total)) { perror("low-stack release"); return 125; }
#ifdef ABLA_TEST_C6_SRAM
    if (munmap(c6_sram, 0x80000)) { perror("C6 SRAM release"); return 125; }
#endif
    return result;
}
