idf_component_register(REQUIRES esp_driver_spi)
set(ABLA_OBJECT "${CMAKE_SOURCE_DIR}/../../build/examples/sd-card/abla_app.o")
include("${CMAKE_SOURCE_DIR}/../../tools/idf/abla-object.cmake")
