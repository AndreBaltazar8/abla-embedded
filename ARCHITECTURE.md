# Architecture

The framework has three layers:

1. Portable names and value types used by applications.
2. Target implementations, selected by one import such as `src/esp32/gpio.ab`.
3. An explicit native boundary for services supplied by a board SDK.

For ESP32, LLVM emits `xtensa-esp-unknown-elf` objects with `-mcpu=esp32`.
PlatformIO contributes
startup code, linker scripts, the RTOS, and vendor archives. Abla supplies the
application entry points directly.

Release MCU objects use LLVM `Oz` whole-program optimization followed by the
Espressif machine-code generator. The host optimizer may warn that it cannot
construct an Xtensa target machine; target-independent optimization still runs,
and Espressif `llc` performs target-aware instruction selection. The emitter
removes `.eh_frame`
because Abla's MCU panic boundary traps and the supported Arduino/ESP-IDF
profiles disable exception unwinding; `ABLA_ESP_KEEP_UNWIND=1` preserves it for
an integration with a different unwinding contract.

Every function and datum is emitted into its own ELF section. ESP-IDF and
PlatformIO link with section garbage collection, so importing a module does not
retain unused drivers or dynamic Abla compatibility wrappers.

## Value and allocation model

Board identities and immutable configurations use nominal scalar types. They
remain distinct in Abla source and method resolution, then erase to their
underlying integer before LLVM lowering. ESP32 I2S pin and device configurations
are packed values; ESP-IDF 6 channel ownership lives with the physical port in
the backend rather than forcing application code to borrow a heap object.

Transient native records use the trusted `nativeStackAllocate` boundary. It
lowers to LLVM `alloca`; 8/16/32/64-bit access and memory clearing lower to
native loads, stores, and `llvm.memset`. Persistent packet and audio storage can
still use the ownership-checked `NativeByteBuffer` resource.

## Native boundary

| Area | Current implementation | Why |
| --- | --- | --- |
| GPIO | SDK pad/mux setup, direct volatile data MMIO in Abla | family-specific mux setup with atomic Abla reads/writes |
| UART output | direct volatile MMIO in Abla | stable FIFO/status registers |
| time | ESP timer/Arduino scheduler ABI | integrates with the running RTOS |
| RGB LED | Arduino ESP32 ABI | RMT timing and board compatibility |
| I2S | Abla layouts and state over the ESP-IDF ABI | DMA, interrupts, and clock routing remain vendor services |
| Wi-Fi | ESP-IDF ABI plus Arduino low-level initialization | TCP/IP netif setup and closed PHY/MAC archives |
| TLS | Arduino `WiFiClientSecure` ABI | mature certificate validation and mbedTLS integration |
| sleep | ESP-IDF ABI | RTC-domain wake configuration |

The SDK modules contain declarations, layout constants, and translation code;
firmware logic remains Abla. Future replacements can keep the public method
names and swap only a target module.

The closed ESP32 Wi-Fi PHY/MAC archives are a hard boundary today. Replacing
open layers above or below that boundary is useful, but claiming an all-Abla
radio implementation while those blobs are linked would be inaccurate.

## Definition of done for a target

- Its examples contain only Abla application source.
- Every example builds independently into a flashable firmware image.
- Hardware access is either an Abla implementation or a documented native ABI.
- The final ELF defines the required entry points from the Abla object.
- No dependency is hidden behind a compiler intrinsic merely to make the source
  appear more independent than it is.
