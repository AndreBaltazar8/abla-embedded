# Native ESP32 radio work

The long-term target is a Wi-Fi path whose implementation is Abla source, not
an application binding to Espressif's precompiled `libnet80211`, `libpp`,
`libcore`, `libphy`, or `libcoexist` archives. That target is not complete yet.

The common `src/esp32/dma_descriptor.ab` module implements the native 12-byte
ESP peripheral-DMA descriptor layout with ordered volatile ownership transfer.
It is reusable by radio, I2S, SPI, camera, and other DMA-backed drivers.

The opt-in `src/esp32/radio/power_esp32.ab` module implements classic ESP32
power-domain, shared/Wi-Fi clock, reset, and MAC-state register primitives.
Power-on is split around the documented 10-microsecond delay because Abla does
not yet expose a target-native CPU cycle counter. Shared-clock ownership must
also be serialized by the caller; the framework does not silently add global
state or pretend that PHY initialization is complete.

The first MAC slice is `src/esp32/radio/mac_esp32.ab`. It directly implements
the classic ESP32 MAC register operations for interrupt causes, RX DMA list
control, four-interface BSSID/receiver filtering, five TX queues, PLCP
parameters, and the MAC timer. Importing it has no hardware side effect, and it
is intentionally absent from the default package entry until native delay,
shared-clock ownership, PHY/calibration, interrupt routing, and bounded DMA
ring ownership are implemented.

The register topology was independently expressed from these permissively
licensed source references:

- [`esp32` PAC 0.40.2](https://github.com/esp-rs/esp-pacs/tree/main/esp32),
  generated register descriptions (MIT or Apache-2.0)
- [`esp-wifi-hal`](https://github.com/esp32-open-mac/esp-wifi-hal)
  0.3.2 at commit
  `4347cf13adc907962cf9e21735c7cc8c943f6e1f` (MIT or Apache-2.0)
- [`esp32-open-mac`](https://github.com/esp32-open-mac/esp32-open-mac)
  at commit
  `20ce43d595be914b4d3f553b28352bc07e003fa1` (MIT)

No vendor archive code or disassembly is copied into the project. Archive
symbols, relocations, and instructions are evidence for dependency mapping and
differential tests. Source implementation comes from public register facts,
permissively licensed open drivers, protocol specifications, and behavior
measured on owned hardware.

The remaining dependency order is:

1. native cycle delay, interrupt-safe shared-clock ownership, and interrupt
   routing;
2. bounded RX/TX ring ownership on top of the implemented descriptors;
3. open 802.11 management, authentication, association, and data framing;
4. hardware crypto plus WPA2 key management;
5. PHY/AGC/channel setup, RF calibration, coexistence, and regulatory limits;
6. a native network interface and IP stack boundary.

Nothing in this module transmits, initializes the radio, or changes the
connected Atom Echo unless application code explicitly calls a trusted method.
