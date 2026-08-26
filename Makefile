ABLA_PROJECT_ROOT ?= $(abspath ../ablac)
EMBEDDED_SHELL ?= $(abspath shell.nix)

.PHONY: setup check blink serial i2c-scan spi-jedec sd-card rtc-pcf8563 rtc-rx8130 rtc-powerhub io-expander imu power-monitor pmic-axp192 pmic-axp2101 pmic-ip5306 charger-aw32001 i2s-tone wifi-connect atom-echo \
	upload-blink upload-serial upload-i2s-tone upload-wifi-connect \
	upload-atom-echo upload-spi-jedec upload-rtc-pcf8563 upload-rtc-rx8130 upload-rtc-powerhub upload-io-expander clean

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

sd-card:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example sd-card'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/sd-card build'

rtc-pcf8563:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example rtc-pcf8563'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/rtc-pcf8563 build'

rtc-rx8130:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example rtc-rx8130'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/rtc-rx8130 build'

rtc-powerhub:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example rtc-powerhub'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/rtc-powerhub build'

io-expander:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example io-expander'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/io-expander build'

imu:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example imu'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/imu build'

power-monitor:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example power-monitor'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/power-monitor build'

pmic-axp192:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example pmic-axp192'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/pmic-axp192 build'

pmic-axp2101:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example pmic-axp2101'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/pmic-axp2101 build'

pmic-ip5306:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example pmic-ip5306'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/pmic-ip5306 build'

charger-aw32001:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example charger-aw32001'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/charger-aw32001 build'

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

upload-rtc-rx8130: rtc-rx8130
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/rtc-rx8130 flash'

upload-rtc-powerhub: rtc-powerhub
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/rtc-powerhub flash'

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
