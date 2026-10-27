"""Source-order checks for the classic wrapper; not firmware execution."""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "src/esp32/spi/software_master_esp32.ab").read_text()
transfer = source.split("trusted fun esp32SoftwareSpiTransferBits(", 1)[1].split("trusted noescape fun spi_bus_initialize", 1)[0]
assert "softwareSpiExchangeBit(" in transfer
assert "esp32SoftwareSpiPause" not in source
assert transfer.index("softwareSpiHalfPeriodMicroseconds") < transfer.index("while (bitIndex")
assert "if (sample) old | mask else old & ~mask" in transfer
initialize = source.split("trusted noescape fun spi_bus_initialize", 1)[1].split("trusted noescape fun spi_bus_free", 1)[0]
assert initialize.index("outputCapable()") < initialize.index("esp32SoftwareSpiStore(bus, u32(0)")
assert initialize.index("pin(int(clock)).write(false)") < initialize.index("pin(int(clock)).output()")
assert source.index("pin(int(chipSelect)).write(true)") < source.index("pin(int(chipSelect)).output()")
transaction = source.split("trusted noescape fun spi_device_transmit", 1)[1]
assert transaction.index("esp32SoftwareSpiAcquire") < transaction.index("// Other devices") < transaction.index("esp32SoftwareSpiChipSelect(device, true)")
print("PASS: classic SPI uses shared engine, validates before mutation, and sets idle levels before output/CS")
