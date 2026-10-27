# Link one large Xtensa LLVM object without invoking GNU BFD's shared-literal
# relaxation pass. ESP32 exception vectors normally rely on that pass to move
# eight four-byte literals; place those literals explicitly at their fixed
# hardware-vector offsets instead.
function(abla_enable_xtensa_monolithic_link component)
    if(NOT IDF_TARGET STREQUAL "esp32")
        return()
    endif()
    if(NOT DEFINED ENV{IDF_PATH})
        message(FATAL_ERROR "IDF_PATH is required for the ESP32 linker setup")
    endif()
    execute_process(
        COMMAND
            "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/prepare-esp32-vector-literals"
            "$ENV{IDF_PATH}"
        RESULT_VARIABLE status
    )
    if(NOT status EQUAL 0)
        message(FATAL_ERROR "Could not prepare the ESP32 vector linker layout")
    endif()
    target_link_options(${component} INTERFACE "-Wl,--no-relax")
endfunction()
