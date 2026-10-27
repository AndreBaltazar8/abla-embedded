import runpy
from pathlib import Path

tool = runpy.run_path(str(Path(__file__).resolve().parents[1] / "tools/report-xtensa-stack"))
inspect = tool["inspect"]
symbols = {0x1000: {"names": ["first"], "size": 64}, 0x1040: {"names": ["second"], "size": 32}}
result = inspect(symbols, ["1000: entry a1, 640", "1003: call8 0x1234", "1006: <unknown>", "1040: entry a1, 0x20"])
assert result["largest_frame_bytes"] == 640
assert result["functions_without_entry"] == 0
assert not result["call_graph_analyzed"] and not result["worst_case_stack_proven"]
assert len(result["functions"]) == 2
assert result["functions"][1]["frame_bytes"] == 32
assert "direct_calls" not in result["functions"][0]
result = inspect(symbols, ["1000: j 0x1010", "1010: entry a1, 512", "1040: entry a1, 32"])
assert result["functions_without_entry"] == 1  # never infer entry after jump
try:
    inspect(symbols, ["1003: entry a1, 640", "1040: entry a1, 32"])
except ValueError:
    pass
else:
    raise AssertionError("missing exact entry accepted")
print("PASS: exact-entry frames, missing/branch entries, no false call-graph proof")
report = inspect(symbols, ["1000: entry a1, 640", "1040: entry a1, 32"])
ir = """define void @first() {
  tail call void @second()
  call void inttoptr (i32 1073741824 to ptr)()
  call void %dynamic()
  ret void
}
define void @second() {
  ret void
}
"""
result = tool["call_paths"](report, ir, "first")
assert result["optimized_ir"]["named_entry_frame_sum_bytes"] == 672
assert result["optimized_ir"]["fixed_call_addresses"] == ["0x40000000"]
assert result["optimized_ir"]["unresolved_call_lines"] == [4]
assert not result["worst_case_stack_proven"]
selected = ir.replace("  call void %dynamic()", "  %target = select i1 %choice, ptr inttoptr (i32 1073748088 to ptr), ptr inttoptr (i32 1073748112 to ptr)\n  call void %target()")
result = tool["call_paths"](report, selected, "first")
assert result["optimized_ir"]["fixed_call_addresses"] == ["0x40000000", "0x40001878", "0x40001890"]
assert result["optimized_ir"]["unresolved_call_lines"] == []
for invalid in (ir.replace("  ret void", "  call void @first()", 1), ir.replace("@second()", "@missing()", 1)):
    try:
        tool["call_paths"](report, invalid, "first")
    except ValueError:
        pass
    else:
        raise AssertionError("recursion/missing frame accepted")
print("PASS: conservative tail-call sum, ROM/dynamic exclusions, recursion/missing-frame rejection")
