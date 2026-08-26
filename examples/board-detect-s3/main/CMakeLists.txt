idf_component_register(REQUIRES esp_driver_gpio)
set(ABLA_OBJECT "${CMAKE_SOURCE_DIR}/../../build/examples/board-detect-s3/abla_app.o")
include("${CMAKE_SOURCE_DIR}/../../tools/idf/abla-object.cmake")
