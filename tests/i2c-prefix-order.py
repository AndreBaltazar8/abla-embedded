"""Source-order checks complement the pure FIFO capacity tests."""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "src/esp32/i2c/stream_esp32s3.ab").read_text()
chunk = source.split("trusted fun esp32S3I2cStreamChunkOwned(", 1)[1]
assert chunk.index("count < 0 || count > 32") < chunk.index("val commandCount = count +")
address = chunk.index("if (first) mmioStoreU32(base + 0x1c")
prefix = chunk.index("if (registerPrefix >= 0) mmioStoreU32(base + 0x1c, registerPrefix)")
payload = chunk.index("esp32S3I2cWriteFifo(port, data, count)")
assert address < prefix < payload < chunk.index("esp32S3I2cRunBatch(")
assert "val prefix = if (first) registerPrefix else -1" in source
assert "nativeStackAllocate" not in source
print("PASS: prefix follows address once, precedes payload, and requires no payload copy buffer")
