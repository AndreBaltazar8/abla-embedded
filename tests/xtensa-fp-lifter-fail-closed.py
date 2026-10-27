#!/usr/bin/env python3
"""Regression checks for semantic-sensitive Xtensa FP reconstruction."""

from pathlib import Path
import runpy


root = Path(__file__).resolve().parents[1]
helpers = runpy.run_path(str(root / "tools/lift-xtensa-leaves-to-abla"))
lift = helpers["lift"]
unsafe_error = helpers["UnsafeSemanticInstruction"]
unsafe_mnemonics = helpers["UNSAFE_XTENSA_FP_MNEMONICS"]
scan = helpers["unsafe_semantic_instructions"]

operands = {
    "addexp.s": "f0, f7",
    "addexpm.s": "f0, f7",
    "const.s": "f5, 1",
    "div0.s": "f3, f2",
    "divn.s": "f0, f2, f6",
    "madd.s": "f0, f2, f6",
    "maddn.s": "f5, f4, f3",
    "mkdadj.s": "f7, f1",
    "msub.s": "f0, f2, f6",
    "nexp01.s": "f4, f2",
    "recip0.s": "f3, f2",
    "rsqrt0.s": "f3, f2",
    "sqrt0.s": "f3, f2",
}

for mnemonic in sorted(unsafe_mnemonics):
    body = (
        "entry a1, 16\n" + mnemonic + " " + operands[mnemonic] +
        "\nrfr a2, f0\nretw.n"
    )
    try:
        lift("unsafeFloat", body, assume_all_registers=True)
    except unsafe_error:
        pass
    else:
        raise SystemExit(f"unsafe instruction was lifted: {mnemonic}")

raw_source = """// Original ABI symbol: unsafe_float
@naked
trusted fun unsafeFloat(): void = $xtensa instructions {
entry a1, 16
div0.s f3, f2
divn.s f0, f2, f6
retw.n
}
"""
if scan(raw_source) != {"div0.s", "divn.s"}:
    raise SystemExit("unsafe source preflight did not find both divider opcodes")

partial = (
    "entry a1, 16\nwfr f1, a2\nwfr f2, a3\n"
    "mov.s f6, f3\nrfr a2, f6\nretw.n"
)
try:
    lift("partiallyDecodedFloat", partial)
except helpers["Unsupported"] as error:
    if "read before definition: f3" not in str(error):
        raise
else:
    raise SystemExit("missing FP producer was replaced with synthetic zero")

safe = lift(
    "safeFloat",
    "entry a1, 16\nwfr f0, a2\nwfr f1, a3\nadd.s f0, f0, f1\n"
    "rfr a2, f0\nretw.n",
)
if "f0 = f0 + f1" not in safe.source:
    raise SystemExit("ordinary exact FP arithmetic was rejected")

print(f"Xtensa FP fail-closed checks: {len(unsafe_mnemonics) + 3} passed")
