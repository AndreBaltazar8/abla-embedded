# Automatic IMU calibration

This ESP-IDF example samples an MPU6886 on the Atom-family Grove bus and runs
an allocation-free integer implementation of M5Unified's stillness
calibration. The 120-byte calibration state and 36-byte Q16 offset table are
Abla-owned static storage.
It does not write NVS; persistence remains an explicit application choice.

Build with `make imu-calibration`. There is no upload shortcut because the
example expects an external MPU6886 on GPIO26/GPIO32.
