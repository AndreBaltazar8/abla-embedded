#!/usr/bin/env python3
"""CALLX8 lifting must not silently discard outgoing stack arguments."""

from pathlib import Path
import runpy


root = Path(__file__).resolve().parents[1]
helpers = runpy.run_path(str(root / "tools/lift-xtensa-leaves-to-abla"))
lift = helpers["lift"]
unsupported = helpers["Unsupported"]

unsafe = """entry a1, 32
mov a8, a3
s32i a2, a1, 0
callx8 a8
retw.n"""
try:
    lift("indirectSevenArguments", unsafe)
except unsupported as error:
    if "outgoing stack arguments at a1+0" not in str(error):
        raise
else:
    raise SystemExit("CALLX8 silently dropped the seventh argument")

safe = """entry a1, 32
mov a8, a3
callx8 a8
retw.n"""
result = lift("indirectRegisterArguments", safe)
if "ablaUnsafeCallI32" not in result.source:
    raise SystemExit("register-only CALLX8 stopped lifting")

print("Xtensa indirect stack arguments: ambiguous CALLX8 rejected")
