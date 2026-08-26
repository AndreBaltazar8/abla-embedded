ABLA_PROJECT_ROOT ?= $(abspath ../ablac)
EMBEDDED_SHELL ?= $(abspath shell.nix)

.PHONY: setup check blink serial i2s-tone wifi-connect atom-echo \
	upload-blink upload-serial upload-i2s-tone upload-wifi-connect \
	upload-atom-echo clean

setup:
	./tools/setup

check:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/check-source'

blink:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example blink'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/blink build'

serial:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example serial'
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/serial'

i2s-tone:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example i2s-tone'
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/i2s-tone'

wifi-connect:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example wifi-connect'
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/wifi-connect'

atom-echo:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example atom-echo'
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/atom-echo'

upload-blink: blink
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/blink flash'

upload-serial: serial
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/serial -t upload'

upload-i2s-tone: i2s-tone
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/i2s-tone -t upload'

upload-wifi-connect: wifi-connect
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/wifi-connect -t upload'

upload-atom-echo: atom-echo
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/atom-echo -t upload'

clean:
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/blink -t clean || true'
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/serial -t clean || true'
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/i2s-tone -t clean || true'
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/wifi-connect -t clean || true'
	nix-shell $(EMBEDDED_SHELL) --run 'pio run -d examples/atom-echo -t clean || true'
