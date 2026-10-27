"""Guard the real facade/backend admission order, not a duplicate cache model."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "src/esp32"
facade = (root / "i2c_idf6.ab").read_text().split("trusted fun i2cMaster(", 1)[1]
facade = facade.split("fun I2cBus.valid", 1)[0]
guard = "if (!espChip32().i2cMasterConfigurationValid(port, sda, scl)) return I2cBus(0)"
assert facade.index(guard) < facade.index("i2cPinsValue(sda, scl)")
assert facade.index(guard) < facade.index("storedI2cBus(port)")
for kind in ("hardware", "software"):
    source = (root / f"i2c/{kind}_master_esp32.ab").read_text()
    marker = "fun i2c_new_master_bus(" if kind == "hardware" else "fun softwareI2cNewMasterBus("
    body = source.split(marker, 1)[1].split("val bus = esp32LibcMalloc", 1)[0]
    assert "espChip32().i2cMasterConfigurationValid(" in body
    assert "int(port), int(sdaNumber), int(sclNumber)" in body
print("PASS: real I2C validation precedes cache/packing and backend allocation")
