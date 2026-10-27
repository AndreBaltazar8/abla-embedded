"""Source-order regression only; not an electrical/timing simulation."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "src/esp32/i2c"
clear = (root / "bus_clear_esp32s3.ab").read_text()
owned = clear.split("trusted fun esp32S3I2cClearStuckBusOwned(", 1)[1]
owned = owned.split("trusted fun esp32S3I2cRecoverAndClearGuarded(", 1)[0]
captured = owned.split("val savedData =", 1)[1]
assert "return " not in captured  # cleanup cannot be skipped by an early return
assert captured.index("esp32S3I2cClearPinRestore(scl") < captured.index("healthy && esp32S3I2cBusReleased")
assert captured.index("esp32S3I2cClearPinRestore(sda") < captured.index("healthy && esp32S3I2cBusReleased")
assert "pulses < 9" in owned
assert "esp32S3I2cClearWaitClock(scl, started, budget)" in owned

active = clear.split("trusted fun esp32S3I2cRecoverAndClearGuarded(", 1)[1]
assert active.index("gate.tryBeginRecovery") < active.index("esp32S3I2cResetWithRccLock")
assert active.index("esp32S3I2cResetWithRccLock") < active.index("esp32S3I2cClearStuckBusOwned")
assert active.index("esp32S3I2cClearStuckBusOwned") < active.index("gate.finishRecovery(owner, result == 1)")
passive = (root / "guarded_recovery_esp32s3.ab").read_text()
assert "ClearStuckBus" not in passive and "RecoverAndClear" not in passive
print("PASS: explicit active recovery owns gate through reset, clear and unconditional GPIO restoration")
