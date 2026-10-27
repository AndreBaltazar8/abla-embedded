"""Keep interrupt-stack-root dispatch calls on Xtensa's CALL4 ABI."""

from pathlib import Path
import re


source = (
    Path(__file__).resolve().parents[1]
    / "src/xtensa/freertos_exceptions_esp32.ab"
).read_text()

expected = {
    "low1": ("407551", "1"),
    "medium2": ("3670016", "0"),
    "medium3": ("683706368", "0"),
}

for mode, (mask, timer) in expected.items():
    match = re.search(
        rf'if \(mode == "{mode}"\) assembly = "((?:[^"\\]|\\.)*)"',
        source,
    )
    assert match, mode
    assembly = match.group(1).replace(r"\n", "\n").replace(r"\t", "\t")
    sequence = (
        f"movi a6, {mask}\n"
        f"movi.n a7, {timer}\n"
        "movi a4, abla_esp32_frxt_dispatch_interrupts\n"
        "callx4 a4"
    )
    assert sequence in assembly, mode
    assert "callx8" not in assembly, mode

print("Xtensa ISR roots: low1/medium2/medium3 use CALL4 dispatcher ABI")
