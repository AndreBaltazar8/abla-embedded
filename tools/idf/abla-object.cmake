# Link one prebuilt Abla object into an ESP-IDF component without a C shim.
# The including component sets ABLA_OBJECT before including this file.
if(NOT DEFINED ABLA_OBJECT)
    message(FATAL_ERROR "ABLA_OBJECT must name an Abla-produced object")
endif()
if(NOT EXISTS "${ABLA_OBJECT}")
    message(FATAL_ERROR "Missing Abla object: ${ABLA_OBJECT}")
endif()

add_library(abla_application_object OBJECT IMPORTED GLOBAL)
set_property(
    TARGET abla_application_object
    PROPERTY IMPORTED_OBJECTS "${ABLA_OBJECT}"
)
target_sources(
    ${COMPONENT_LIB}
    INTERFACE $<TARGET_OBJECTS:abla_application_object>
)
