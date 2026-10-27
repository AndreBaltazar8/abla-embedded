#!/usr/bin/env python3
"""Compare compiled Abla pad planning with independent pinned IDF headers.

Host test only. Reads literal shift/width definitions, never executes header
text or modifies firmware/device. No generated mirror of production masks.
"""
import ctypes
import pathlib
import re
import sys

library, idf_root = sys.argv[1:]
root = pathlib.Path(idf_root)
header = (root / "components/soc/esp32/register/soc/rtc_io_reg.h").read_text()
literal = dict(re.findall(r"^#define\s+(\w+)\s+(0x[0-9a-fA-F]+|[0-9]+)\s*$", header, re.M))

def number(name):
    return int(literal[name], 0)

def bit(name):
    return 1 << number(name + "_S")

def offset(name):
    match = re.search(r"^#define\s+" + re.escape(name) + r"\s+\(DR_REG_RTCIO_BASE\s*\+\s*(0x[0-9a-fA-F]+)\)", header, re.M)
    assert match, name
    return 0x3FF48400 + int(match[1], 16)

fn = ctypes.CDLL(str(pathlib.Path(library).resolve())).abla_touch_pad_register_field
fn.argtypes = [ctypes.c_int64, ctypes.c_int64]
fn.restype = ctypes.c_int64
for channel in range(10):
    prefix = f"RTC_IO_TOUCH_PAD{channel}" if channel < 8 else ("RTC_IO_X32N" if channel == 8 else "RTC_IO_X32P")
    func = number(prefix + "_FUN_SEL_V") << number(prefix + "_FUN_SEL_S")
    mask = func | bit(prefix + "_MUX_SEL") | bit(prefix + "_FUN_IE") | bit(prefix + "_RUE") | bit(prefix + "_RDE")
    # rtc_io_periph.c maps touch0..7 to RTCIO10..17, touch8/9 to8/9.
    rtc = channel + 10 if channel < 8 else channel
    # touch_sensor_ll.h explicitly swaps8/9 for init charge voltage only.
    charge = {8: 9, 9: 8}.get(channel, channel)
    expected = [offset(prefix + "_REG") if channel < 8 else offset("RTC_IO_XTAL_32K_PAD_REG"),
                mask, bit(prefix + "_MUX_SEL"), bit(prefix + "_HOLD"),
                1 << (rtc + number("RTC_GPIO_ENABLE_S")), offset(f"RTC_IO_TOUCH_PAD{charge}_REG")]
    for index, value in enumerate(expected):
        actual = fn(index, channel)
        assert actual == value, f"channel={channel} field={index}: Abla={actual:#x} IDF={value:#x}"
print("PASS: compiled Abla vs IDF register headers, 60 pad fields")
