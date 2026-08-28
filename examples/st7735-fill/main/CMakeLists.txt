idf_component_register(REQUIRES esp_driver_i2c esp_driver_spi)
set(ABLA_OBJECT "${CMAKE_SOURCE_DIR}/../../build/examples/st7735-fill/abla_app.o")
include("${CMAKE_SOURCE_DIR}/../../tools/idf/abla-object.cmake")
