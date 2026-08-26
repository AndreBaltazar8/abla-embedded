idf_component_register(REQUIRES nvs_flash)
set(ABLA_OBJECT "${CMAKE_SOURCE_DIR}/../../build/examples/imu-offsets/abla_app.o")
include("${CMAKE_SOURCE_DIR}/../../tools/idf/abla-object.cmake")
