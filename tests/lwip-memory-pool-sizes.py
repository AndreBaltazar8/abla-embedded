#!/usr/bin/env python3
"""Keep recovered lwIP pool descriptors large enough for their active ABI."""

from pathlib import Path
import re


root = Path(__file__).resolve().parents[1]
pool_source = (root / "src/network/lwip/memory_pools_esp32.ab").read_text()

expected_sizes = {
    "RAW_PCB": 72,
    "UDP_PCB": 80,
    "TCP_PCB": 208,
    "TCP_PCB_LISTEN": 76,
    "TCP_SEG": 16,
    "FRAG_PBUF": 24,
    "NETBUF": 36,
    "NETCONN": 60,
    "TCPIP_MSG_API": 16,
    "TCPIP_MSG_INPKT": 16,
    "ARP_QUEUE": 8,
    "IGMP_GROUP": 16,
    "SYS_TIMEOUT": 16,
    "NETDB": 317,
    "ND6_QUEUE": 8,
    "MLD6_GROUP": 32,
    "PBUF": 16,
    "PBUF_POOL": 1532,
}

for name, expected in expected_sizes.items():
    match = re.search(
        rf"memp_{name}_[A-Za-z0-9_]+Storage = nativeStaticBytes\(\"([^\"]+)\"\)",
        pool_source,
    )
    assert match is not None, f"missing initialized descriptor for {name}"
    encoded = match.group(1)
    raw = bytes(int(value, 16) for value in re.findall(r"\\x([0-9a-fA-F]{2})", encoded))
    assert len(raw) == 2, f"invalid descriptor width for {name}"
    actual = int.from_bytes(raw, "little")
    assert actual == expected, f"{name}: expected {expected}, got {actual}"

constructor_requirements = {
    "src/network/lwip/raw_esp32.ab": "freestandingSet(controlBlock, i32(0), u32(72))",
    "src/network/lwip/udp_esp32.ab": "freestandingSet(controlBlock, i32(0), u32(80))",
    "src/network/lwip/tcp_core_esp32.ab": "freestandingSet(pcb, i32(0), u32(208))",
    "src/network/lwip/netbuf_esp32.ab": "freestandingSet(buffer, i32(0), u32(36))",
    "src/network/lwip/api_msg_esp32.ab": "freestandingSet(connection, i32(0), u32(60))",
    "src/network/lwip/pbuf_basic_esp32.ab": "val capacity = u32(1516) - offset",
}
for relative_path, required_source in constructor_requirements.items():
    source = (root / relative_path).read_text()
    assert required_source in source, f"active ABI changed in {relative_path}"

member_requirements = {
    "src/network/lwip/tcp_core_esp32.ab": "listener + u32(73)",
    "src/network/lwip/neighbor_discovery_ipv6_esp32.ab": "newEntry + u32(4)",
    "src/network/lwip/mld_ipv6_esp32.ab": "group + u32(28)",
}
for relative_path, required_source in member_requirements.items():
    source = (root / relative_path).read_text()
    assert required_source in source, f"active member layout changed in {relative_path}"

print("lwIP memory-pool descriptors match all 18 active ABI sizes")
