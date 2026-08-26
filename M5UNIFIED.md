# M5Unified architecture mapping

M5Unified was audited at upstream commit
`3eaaf828adfd0923c71ccc2e233a0199d9958faa`. Its useful architectural boundary
is board support: it maps built-in buttons, displays, touch, audio, power,
battery, IMU, and RTC devices onto one board-facing API. It deliberately treats
Wi-Fi, generic SPI/I2C devices, SD cards, and RGB LEDs as ESP32 ecosystem
services rather than M5-specific drivers.

Abla Embedded follows the same separation without linking the M5Unified C++
runtime. `src/m5stack` contains statically selected board profiles; `src/esp32`
continues to own reusable peripherals and vendor-service boundaries. Static
selection matters on small firmware: there is no board-probe code, virtual
object, heap allocation, or aggregate ABI in an application that already knows
its target board.

The initial `m5AtomEcho()` profile provides:

- button A on GPIO39;
- the RGB LED on GPIO27;
- one shared I2S device with BCLK 19, WS 33, speaker data 22, and PDM mic data
  23;
- Grove Port A clock/data pins 32 and 26;
- button deep-sleep wake configuration;
- the GPIO0-high Atom-family initialization used by M5Unified to avoid the
  onboard CH552 reducing Wi-Fi sensitivity.

Future M5Stack profiles should preserve these logical method names and add
capability-specific modules for display, touch, PMIC/battery, RTC, and IMU.
Hardware that is absent from a board should not be represented by a fake
implementation.
