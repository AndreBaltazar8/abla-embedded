# ESP32-C6 M5Stack board detection

This opt-in example distinguishes M5NanoC6 from M5StampC6 using the package
and embedded-flash eFuse fields used by M5Unified, then writes the canonical
board name to UART0. QFN40 display products intentionally remain unknown: their
identity belongs to display-controller detection rather than this fallback.

Build it with `make board-detect-c6`. Flashing is deliberately not a Makefile
target because a detector example should only be installed on the matching
ESP32-C6 hardware selected by its user.
