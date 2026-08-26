idf_component_register(REQUIRES esp_driver_i2c)
set(ABLA_OBJECT "${CMAKE_SOURCE_DIR}/../../build/examples/pmic-ip5306/abla_app.o")
include("${CMAKE_SOURCE_DIR}/../../tools/idf/abla-object.cmake")
