"""Source regression: TX clear policy reaches the ISR before buffer reuse.

This checks configuration/layout/order, not timing or physical sound quality.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "src/esp32"
facade = (root / "i2s_idf6.ab").read_text()
install = facade.split("trusted fun I2sDevice.install(", 1)[1]
policy = "if (!microphone) nativeAddressStoreU8(channelConfig, 16, 1)"
assert install.index("nativeAddressClear(channelConfig, 24)") < install.index(policy)
assert install.index(policy) < install.index("i2s_new_channel(")

driver = (root / "i2s/driver_typed_esp32.ab").read_text()
assert "channel, u32(32),\n                esp32I2sLoadU8(configuration, u32(16))" in driver
interrupt = driver.split("trusted fun esp32I2sDmaTxInterrupt(", 1)[1]
interrupt = interrupt.split("\ntrusted fun ", 1)[0]
clear = interrupt.index("if (esp32I2sLoadU8(handle, u32(32)) != u32(0))")
assert clear < interrupt.index("freestandingSet(buffer, 0, size)", clear)
assert interrupt.index("freestandingSet(buffer, 0, size)", clear) < interrupt.index(
    "esp32RecoveredXQueueGenericSendFromISR("
)
print("PASS: TX-only auto-clear configured and consumed buffers cleared before requeue")
