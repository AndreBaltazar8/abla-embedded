# ESP32-S3 M5Stack board detection

This opt-in ESP-IDF example runs the allocation-free S3 detector used by
multi-board firmware. GPIO signatures are captured and restored, I2C probes
always close their temporary bus, and peripheral-controlled outputs are left
untouched. Static board profiles do not import this code.

Build with `make board-detect-s3`. There is deliberately no upload shortcut:
run detection during early startup, before application peripherals claim its
probe pins.
