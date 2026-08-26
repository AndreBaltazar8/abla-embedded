idf_component_register(REQUIRES efuse)
set(ABLA_OBJECT "${CMAKE_SOURCE_DIR}/../../build/examples/board-detect-c6/abla_app.o")
include("${CMAKE_SOURCE_DIR}/../../tools/idf/abla-object.cmake")
