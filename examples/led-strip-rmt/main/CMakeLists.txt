idf_component_register(REQUIRES esp_driver_gpio esp_driver_rmt)
set(ABLA_OBJECT "${CMAKE_SOURCE_DIR}/../../build/examples/led-strip-rmt/abla_app.o")
include("${CMAKE_SOURCE_DIR}/../../tools/idf/abla-object.cmake")
