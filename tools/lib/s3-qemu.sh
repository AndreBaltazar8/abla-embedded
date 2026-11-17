# Shared by the S3 emulator drivers (tools/check-s3-*-qemu): start QEMU paused on a free
# local port with an ELF loaded, wait for its GDB listener, and always stop it again.
# Source this file; it needs $root (the project root) and $elf. No device access.
#
#   ABLA_S3_QEMU, ABLA_S3_GDB, ABLA_QEMU_LIBRARY_PATH override the tool locations.

qemu=${ABLA_S3_QEMU:-$HOME/.cache/abla-embedded/qemu-20250817/qemu/bin/qemu-system-xtensa}
gdb=${ABLA_S3_GDB:-$HOME/.espressif/tools/xtensa-esp-elf-gdb/17.1_20260402/xtensa-esp-elf-gdb/bin/xtensa-esp32s3-elf-gdb}
runner=()
if command -v steam-run >/dev/null 2>&1; then runner=(steam-run); fi
qemu_runner=("${runner[@]}")
if [[ -n ${ABLA_QEMU_LIBRARY_PATH:-} ]]; then
    qemu_runner+=(env "LD_LIBRARY_PATH=$ABLA_QEMU_LIBRARY_PATH")
fi
qemu_pid=
qemu_log=
# Not under /tmp: steam-run (which runs QEMU and GDB) has a private /tmp.
mkdir -p "$root/build"
work=$(mktemp -d "$root/build/s3-qemu.XXXXXX")

stop_qemu() {
    if [[ -n $qemu_pid ]] && kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
            kill -0 "$qemu_pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$qemu_pid" 2>/dev/null || true
    fi
    rm -rf "$work"
}
trap stop_qemu EXIT

# A local TCP port nobody listens on.
free_port() {
    local candidate
    while :; do
        candidate=$((20000 + RANDOM % 40000))
        if ! (exec 3<>"/dev/tcp/127.0.0.1/$candidate") 2>/dev/null; then
            printf '%s\n' "$candidate"
            return
        fi
    done
}

# Start QEMU paused (-S) with the ELF as a loader device; sets $port.
start_qemu() {
    port=$(free_port)
    qemu_log=$work/qemu.log
    (cd "$root" && exec "${qemu_runner[@]}" "$qemu" -M esp32s3 -display none -serial none -monitor none -nic none \
        -device "loader,file=$elf,cpu-num=0" -S -gdb "tcp:127.0.0.1:$port") >"$qemu_log" 2>&1 &
    qemu_pid=$!
    local deadline=$((SECONDS + 10))
    while :; do
        if ! kill -0 "$qemu_pid" 2>/dev/null; then
            cat "$qemu_log" >&2
            echo "QEMU exited before its GDB listener came up" >&2
            return 1
        fi
        if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then return 0; fi
        if ((SECONDS > deadline)); then
            echo "QEMU GDB listener did not come up" >&2
            return 1
        fi
        sleep 0.05
    done
}
