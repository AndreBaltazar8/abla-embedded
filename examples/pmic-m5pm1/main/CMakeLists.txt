idf_component_register(REQUIRES esp_driver_i2c)
set(ABLA_OBJECT "${CMAKE_SOURCE_DIR}/../../build/examples/pmic-m5pm1/abla_app.o")
include("${CMAKE_SOURCE_DIR}/../../tools/idf/abla-object.cmake")
