#!/usr/bin/env python3
"""Bounded executable oracle for the recovered wifi_nvs_cfg_init register model.

Runs only that function, with modeled allocation/memory/callees. Unsupported
syntax fails closed. This is translation-audit evidence, not device execution.
"""
import json
import hashlib
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
source = (root / 'src/esp32/wifi/nvs_esp32.ab').read_text()
body = (root / 'tests/fixtures/wifi-nvs-init-register-model.ab').read_text().split('trusted fun esp32RecoveredWifiNvsCfgInit(', 1)[1]
body = body.split('// Original ABI symbol: wifi_nvs_sta_restore', 1)[0]
body = body.split('): u32 {', 1)[1].strip()
names = sorted(set(re.findall(r'\besp32Data_\w+', body)))
addresses = {name: 0x100000 + index * 0x10000 for index, name in enumerate(names)}

def transpile():
    lines = ['def invoke():']
    depth = 1
    for raw in body.splitlines():
        line = raw.strip()
        if not line or line.startswith('//'):
            continue
        if line.startswith('}'):
            depth -= 1
            line = line[1:].strip()
            if not line:
                continue
        if line == 'else {':
            lines.append('    ' * depth + 'else:')
            depth += 1
        elif line.startswith('if (') and line.endswith(' {'):
            condition = re.sub(r'!(?!=)', 'not ', line[3:-2])
            lines.append('    ' * depth + 'if ' + condition + ':')
            depth += 1
        else:
            line = re.sub(r'^(var|val) ', '', line)
            if not re.match(r'^(r\d+ =|frameAddress =|shiftAmount =|return |ablaUnsafeStoreU32\(|xtensaMemoryBarrier\()', line):
                raise ValueError('unrecognized statement: ' + line)
            lines.append('    ' * depth + line)
    if depth != 0:
        raise ValueError('unbalanced function')
    return compile('\n'.join(lines), '<wifi-nvs-audit>', 'exec')

compiled = transpile()

def compile_structured():
    text = (root / 'src/esp32/wifi/nvs_config_init.ab').read_text().split('): u32 {', 1)[1]
    lines, pending, balance = [], '', 0
    for raw in text.splitlines():
        line = raw.split('//', 1)[0].strip()
        if not line:
            continue
        pending += ' ' + line
        balance += line.count('(') - line.count(')')
        if balance == 0:
            lines.append(pending.strip())
            pending = ''
    assert not pending
    output, depth = ['def invoke():'], 1
    for line in lines:
        if line == '}':
            depth -= 1
            continue
        line = re.sub(r'^(var|val) ', '', line)
        if line.startswith('if ('):
            count = 0
            for end in range(3, len(line)):
                count += (line[end] == '(') - (line[end] == ')')
                if count == 0:
                    break
            condition, suffix = line[3:end+1], line[end+1:].strip()
            output.append('    ' * depth + 'if ' + condition + ':')
            if suffix == '{':
                depth += 1
            else:
                output.append('    ' * (depth + 1) + suffix)
        elif line.startswith('esp32WifiNvsInitDescriptorTail('):
            output.append('    ' * depth + 'return ' + line)
        else:
            assert re.match(r'^(return |\w+ =|esp32WifiLogValue\(|ablaUnsafeStoreU32\(|xtensaMemoryBarrier\(|freestandingSet\()', line), line
            output.append('    ' * depth + line)
    assert depth == 0
    return compile('\n'.join(output), '<structured-nvs-init>', 'exec')

structured = compile_structured()
table_text = (root / 'src/esp32/wifi/nvs_config_descriptors.ab').read_text().split('nativeStaticU32s([', 1)[1].split('])', 1)[0]
descriptor_words = [int(n) for n in re.findall(r'\d+', table_text)]
assert len(descriptor_words) == 85 * 4

def run(softap, fail_at=0, allocated=True, existing=False, implementation=compiled):
    memory, trace, events = {}, [], []
    def location(fragment):
        matches = [address for name, address in addresses.items() if fragment in name]
        assert len(matches) == 1, fragment
        return matches[0]
    memory[location('bss_g_wifi_nvs_cfg')] = 0x800000 if existing else 0
    memory[location('g_osi_funcs_p')] = 0x900000
    memory[0x900000 + 376] = 0x910000
    memory[location('esp32Data_g_wifi_nvs_')] = 0xA00000
    memory[location('net80211_funcs')] = 0xB00000 if softap else 0
    memory[0xB00000] = 0 if softap == 'empty' else 1
    def allocate(*arguments):
        assert arguments[0] == 0x910000 and arguments[1] == 4472
        events.append('allocate')
        return 0x800000 if allocated else 0
    def clear(address, byte, size):
        assert address == 0xA00000 and byte == 0 and size == 1316
        events.append('clear')
        return address
    def item(*arguments):
        trace.append(tuple(arguments[:8]))
        return 258 if len(trace) == fail_at else 0
    def tail(keys, values):
        for offset in range(0, len(descriptor_words), 4):
            packed, minimum, limits, initial = descriptor_words[offset:offset+4]
            result = item(keys + (packed & 1023), (packed >> 10) & 127,
                          (packed >> 17) & 7, (packed >> 20) & 1023,
                          minimum, limits & 65535, initial, values + (limits >> 16))
            if result:
                return result
        return 0
    environment = dict(addresses)
    environment.update({f'a{i}': 0 for i in range(2, 8)})
    environment.update({f'stack{i}': 0 for i in range(10)})
    environment.update({
        'u32': lambda n: n & 0xFFFFFFFF,
        'i32': lambda n: ((n + 0x80000000) & 0xFFFFFFFF) - 0x80000000,
        'int': int, 'nativePointerFromAddress': lambda n: n,
        'nativeStackAllocate': lambda size: 0x700000,
        'ablaUnsafeLoadU32': lambda address: memory.get(address, 0),
        'freestandingLoadWord': lambda address: memory.get(address, 0),
        'ablaUnsafeStoreU32': lambda address, value: memory.__setitem__(address, value),
        'ablaUnsafeCallI32I32I32I32I32I32I32': allocate,
        'freestandingSet': clear, 'xtensaMemoryBarrier': lambda: None,
        'esp32RecoveredWifiNvsCfgItemInit': item,
        'esp32WifiNvsInitDescriptorTail': tail,
        'esp32WifiLogValue': lambda *args: events.append('log') or 0,
    })
    exec(implementation, environment)
    result = environment['invoke']()
    # Partial initialization retains ownership; allocation failure leaves null.
    assert memory[location('bss_g_wifi_nvs_cfg')] == (0x800000 if existing or allocated else 0)
    return result, trace, events

tables = {}
for options in [dict(fail_at=n) for n in range(88)] + [dict(allocated=False), dict(existing=True)]:
    # A non-null SoftAP table with a null first entry is also station-only.
    assert run('empty', **options) == run(False, **options)
    assert run('empty', implementation=structured, **options) == run(False, **options)
# Exact selected IDF6 ieee80211_nvs.o REL literal addends in instruction order.
# The source blob also matches the original1000-byte packed key section.
expected_offsets = [0,7,16,29,38,46,55,65,75,85,100,109,119,128,139,155,171,183,195,205,215,225,235,245,256,268,280,288,298,305,313,325,335,347,360,368,377,388,397,406,418,428,439,449,462,475,490,503,518,529,543,557,568,575,583,593,609,618,625,633,645,657,673,687,700,711,727,743,757,771,787,803,818,829,844,856,865,879,890,905,920,935,948,961,973,985]
blob_source = source.split('val esp32Data_Labla_recovered_nvs_data_rodata_wifi_nvs_cfg_init_str1_1_f5e9f763cfStorage = nativeStaticBytes(', 1)[1].split('val esp32Data_', 1)[0]
blob = bytes(int(value, 16) for value in re.findall(r'\\x([0-9a-f]{2})', blob_source))
assert hashlib.sha256(blob).hexdigest() == '3c4333493e7370e758b9d39bc8c34543b5bdfb45d0b6f06f5fe2073aa6e76d28'
for softap in (False, True):
    for options in [dict(fail_at=n) for n in range(88)] + [dict(allocated=False), dict(existing=True)]:
        assert run(softap, **options) == run(softap, implementation=structured, **options), (softap, options)
    result, expected, events = run(softap)
    assert result == 0 and events == ['allocate', 'clear']
    for failure in range(1, len(expected) + 1):
        result, trace, events = run(softap, fail_at=failure)
        assert result == 258 and trace == expected[:failure]
    result, trace, events = run(softap, allocated=False)
    assert result == 257 and trace == [] and events == ['allocate', 'log']
    result, trace, events = run(softap, existing=True)
    assert result == 0 and trace == [] and events == ['log']
    def relative(value):
        matches = [(name, value - base) for name, base in addresses.items() if base <= value < base + 65536]
        return matches[0] if matches else value
    tables['softap' if softap else 'station'] = [[relative(value) for value in row] for row in expected]
    key_offsets = [relative(row[0])[1] for row in expected]
    assert key_offsets == (expected_offsets if softap else [0] + expected_offsets)
print(json.dumps(tables, indent=2))
