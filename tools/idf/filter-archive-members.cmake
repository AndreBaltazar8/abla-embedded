# Create a build-local copy of an imported archive without superseded members.
#
# This is generic linker plumbing for incremental source replacement: the
# installed SDK/archive remains untouched, while the importing target keeps its
# ordinary CMake identity and link ordering.
function(abla_filter_imported_archive_members target)
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "Unknown imported archive target: ${target}")
    endif()
    get_target_property(source "${target}" IMPORTED_LOCATION)
    if(NOT source OR NOT EXISTS "${source}")
        message(FATAL_ERROR "${target} has no readable imported archive")
    endif()
    if(NOT ARGN)
        message(FATAL_ERROR "No archive members selected for ${target}")
    endif()

    set(output_dir "${CMAKE_BINARY_DIR}/abla-filtered-archives")
    file(MAKE_DIRECTORY "${output_dir}")
    set(output "${output_dir}/${target}.a")
    configure_file("${source}" "${output}" COPYONLY)
    execute_process(
        COMMAND "${CMAKE_AR}" d "${output}" ${ARGN}
        RESULT_VARIABLE status
        ERROR_VARIABLE diagnostic
    )
    if(NOT status EQUAL 0)
        message(FATAL_ERROR
            "Could not filter ${target}: ${diagnostic}"
        )
    endif()
    set_property(TARGET "${target}" PROPERTY IMPORTED_LOCATION "${output}")
endfunction()
