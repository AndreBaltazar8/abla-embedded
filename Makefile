ABLA_PROJECT_ROOT ?= $(abspath ../ablac)
EMBEDDED_SHELL ?= $(abspath shell.nix)

.PHONY: setup check blink serial i2c-scan spi-jedec rtc-pcf8563 io-expander i2s-tone wifi-connect atom-echo \
	upload-blink upload-serial upload-i2s-tone upload-wifi-connect \
	upload-atom-echo upload-spi-jedec upload-rtc-pcf8563 upload-io-expander clean

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

i2c-scan:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example i2c-scan'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/i2c-scan build'

spi-jedec:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example spi-jedec'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/spi-jedec build'

rtc-pcf8563:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example rtc-pcf8563'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/rtc-pcf8563 build'

io-expander:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example io-expander'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/io-expander build'

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

upload-spi-jedec: spi-jedec
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/spi-jedec flash'

upload-rtc-pcf8563: rtc-pcf8563
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/rtc-pcf8563 flash'

upload-io-expander: io-expander
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/io-expander flash'

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
