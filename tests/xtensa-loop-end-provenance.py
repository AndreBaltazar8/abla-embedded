#!/usr/bin/env python3
"""Taken branches to LEND must not become hardware-loop back edges."""
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
lift = runpy.run_path(str(root / "tools/lift-xtensa-leaves-to-abla"))["lift_control_flow"]
structure = runpy.run_path(str(root / "tools/structurize-acyclic-recovered-functions"))["transform"]

for branch in ("beq a2, a3, .Lend", "j .Lend"):
    body = "entry a1, 16\nmovi a9, 8\nloop a9, .Lend\n" + branch + "\naddi a2, a2, 1\n.Lend:\nretw.n"
    source = lift("earlyExit", body).source
    assert "loopEnd == " in source and "loopActive = false" in source
    transformed, count = structure(source)
    assert count == 0 and transformed == source, "structurizer lost early-exit provenance"
    # The explicit cancellation is executed before assignment of the target PC.
    cancellation = source.rindex("loopActive = false")
    assert "programCounter = " in source[cancellation:]

body = "entry a1, 16\nmovi a9, 8\nloop a9, .Lend\naddi a2, a2, 1\n.Lend:\nretw.n"
source = lift("fallthrough", body).source
assert "loopEnd == " not in source
transformed, count = structure(source)
assert count == 1 and "recoveredLoopRemaining" in transformed
assert "programCounter" not in transformed
print("Xtensa LEND provenance: conditional exit, jump exit, and fallthrough passed")
