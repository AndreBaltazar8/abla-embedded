ABLA_PROJECT_ROOT ?= $(abspath ../ablac)
EMBEDDED_SHELL ?= $(abspath shell.nix)

.PHONY: setup check blink serial i2c-scan spi-jedec sd-card rtc-pcf8563 rtc-rx8130 rtc-powerhub io-expander imu imu-calibration imu-offsets power-monitor pmic-axp192 pmic-axp2101 pmic-ip5306 pmic-m5pm1 charger-aw32001 led-m5pm1 led-powerhub led-paper-mono led-strip-rmt board-detect-s3 board-detect-c6 radio-mac-registers compare-radio-power-size compare-rx-chain-size i2s-tone wifi-connect atom-echo \
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

imu-calibration:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example imu-calibration'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/imu-calibration build'

imu-offsets:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example imu-offsets'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/imu-offsets build'

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

pmic-m5pm1:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example pmic-m5pm1'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/pmic-m5pm1 build'

charger-aw32001:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example charger-aw32001'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/charger-aw32001 build'

led-m5pm1:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example led-m5pm1'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/led-m5pm1 build'

led-powerhub:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example led-powerhub'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/led-powerhub build'

led-paper-mono:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example led-paper-mono'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/led-paper-mono build'

led-strip-rmt:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example led-strip-rmt'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/led-strip-rmt build'

board-detect-c6:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example board-detect-c6'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/board-detect-c6 build'

board-detect-s3:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example board-detect-s3'
	nix-shell $(EMBEDDED_SHELL) --run './tools/idf-project examples/board-detect-s3 build'

radio-mac-registers:
	nix-shell $(ABLA_PROJECT_ROOT)/shell.nix --run './tools/build-example radio-mac-registers'

compare-radio-power-size: radio-mac-registers
	nix-shell -p steam-run --run './tools/compare-radio-power-size'

compare-rx-chain-size: radio-mac-registers
	nix-shell -p steam-run --run './tools/compare-rx-chain-size'

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
