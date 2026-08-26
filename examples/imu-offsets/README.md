# IMU offset persistence

This ESP-IDF example loads the same nine signed Q16 IMU offset fields used by
M5Unified (`ax` through `mz`) from an isolated `AblaImuDemo` NVS namespace. On
the first run it commits a zeroed record so later boots exercise the load path.

Build with `make imu-offsets`. There is deliberately no upload shortcut because
the example writes persistent flash state; flashing must be an explicit choice.
