# Add one prebuilt Abla object to an ESP-IDF component without a C shim.
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
get_target_property(ABLA_COMPONENT_TYPE ${COMPONENT_LIB} TYPE)
if(ABLA_COMPONENT_TYPE STREQUAL "INTERFACE_LIBRARY")
    target_sources(
        ${COMPONENT_LIB}
        INTERFACE $<TARGET_OBJECTS:abla_application_object>
    )
else()
    target_sources(
        ${COMPONENT_LIB}
        PRIVATE $<TARGET_OBJECTS:abla_application_object>
    )
endif()
