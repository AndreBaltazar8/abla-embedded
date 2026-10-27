"""Keep freestanding static-byte profiles identical to the legacy string API."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
legacy = (root / 'src/display/mipi_commands.ab').read_text()
native = (root / 'src/display/mipi_programs.ab').read_text()
expected = dict(re.findall(r'val (\w+)InitCommands = "([^"]+)"', legacy))
actual = re.findall(
    r'fun (\w+)InitProgram\(\): NativeBuffer =\s*'
    r'nativeBufferAt\(nativeStaticBytes\("([^"]+)"\), (\d+)\)', native)
assert len(expected) == len(actual) == 4
assert set(expected) == {name for name, _, _ in actual}
for name, encoded, length in actual:
    assert encoded == expected[name], name
    assert re.fullmatch(r'(\\x[0-9a-f]{2})+', encoded), name
    assert len(encoded) // 4 == int(length), name
print('PASS: four freestanding MIPI profiles preserve every legacy command byte')
