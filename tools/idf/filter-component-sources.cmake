# Remove fully superseded source files from a build-local ESP-IDF component.
#
# This is the source-component counterpart to filter-archive-members.cmake.
# It never mutates the installed SDK: only the generated target for the current
# firmware build is changed. Use it only after every externally reachable
# definition in the named source has an implementation in the monolithic Abla
# object.
function(abla_filter_component_sources component)
    if(NOT ARGN)
        message(FATAL_ERROR "No source basenames selected for ${component}")
    endif()
    if(NOT COMMAND idf_component_get_property)
        message(FATAL_ERROR "ESP-IDF component API is unavailable")
    endif()

    idf_component_get_property(component_library "${component}" COMPONENT_LIB)
    if(NOT TARGET "${component_library}")
        message(FATAL_ERROR "Unknown ESP-IDF component: ${component}")
    endif()

    get_target_property(component_sources "${component_library}" SOURCES)
    if(NOT component_sources)
        message(FATAL_ERROR "${component} has no source list")
    endif()

    set(filtered_sources "")
    set(removed_sources "")
    foreach(source IN LISTS component_sources)
        get_filename_component(source_name "${source}" NAME)
        list(FIND ARGN "${source_name}" selected_index)
        if(selected_index EQUAL -1)
            list(APPEND filtered_sources "${source}")
        else()
            list(APPEND removed_sources "${source_name}")
        endif()
    endforeach()

    foreach(requested IN LISTS ARGN)
        list(FIND removed_sources "${requested}" removed_index)
        if(removed_index EQUAL -1)
            message(FATAL_ERROR
                "Could not find ${requested} in ESP-IDF component ${component}"
            )
        endif()
    endforeach()

    # CMake does not permit a normal library target with no sources.  Some
    # ESP-IDF components consist entirely of the implementation Abla replaces
    # (esp_hal_pmu currently contains only brownout_hal.c), so retain the
    # component/archive shape with an empty translation unit.  It defines no
    # symbols or storage and therefore contributes nothing to the linked image.
    if(NOT filtered_sources)
        string(MAKE_C_IDENTIFIER "${component}" component_identifier)
        set(empty_source
            "${CMAKE_CURRENT_BINARY_DIR}/abla-empty-${component_identifier}.c"
        )
        file(GENERATE
            OUTPUT "${empty_source}"
            CONTENT "/* Component implementation is supplied by the monolithic Abla object. */\n"
        )
        list(APPEND filtered_sources "${empty_source}")
    endif()

    set_property(
        TARGET "${component_library}"
        PROPERTY SOURCES "${filtered_sources}"
    )
endfunction()
