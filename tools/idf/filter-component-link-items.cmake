# Remove exact link-interface items from one build-local ESP-IDF component.
#
# ESP-IDF components sometimes force an archive root with a `-u symbol` item.
# Once the corresponding initialization path lives inside the monolithic Abla
# graph, retaining that item would select the superseded opaque object and all
# of its transitive archive dependencies. This changes only the generated
# target for the current firmware build; the installed SDK remains untouched.
function(abla_filter_component_link_items component)
    if(NOT ARGN)
        message(FATAL_ERROR "No link items selected for ${component}")
    endif()
    if(NOT COMMAND idf_component_get_property)
        message(FATAL_ERROR "ESP-IDF component API is unavailable")
    endif()

    idf_component_get_property(component_library "${component}" COMPONENT_LIB)
    if(NOT TARGET "${component_library}")
        message(FATAL_ERROR "Unknown ESP-IDF component: ${component}")
    endif()

    set(found_items "")
    foreach(property
            LINK_LIBRARIES
            INTERFACE_LINK_LIBRARIES
            LINK_OPTIONS
            INTERFACE_LINK_OPTIONS)
        get_target_property(items "${component_library}" "${property}")
        if(NOT items OR items MATCHES "-NOTFOUND$")
            continue()
        endif()

        set(filtered_items "")
        foreach(item IN LISTS items)
            set(remove_item FALSE)
            foreach(requested IN LISTS ARGN)
                if(item STREQUAL requested OR
                   item STREQUAL "$<LINK_ONLY:${requested}>")
                    set(remove_item TRUE)
                    list(APPEND found_items "${requested}")
                endif()
            endforeach()
            if(NOT remove_item)
                list(APPEND filtered_items "${item}")
            endif()
        endforeach()
        set_property(
            TARGET "${component_library}"
            PROPERTY "${property}" "${filtered_items}"
        )
    endforeach()

    foreach(requested IN LISTS ARGN)
        list(FIND found_items "${requested}" found_index)
        if(found_index EQUAL -1)
            message(FATAL_ERROR
                "Could not find link item '${requested}' in ESP-IDF component ${component}"
            )
        endif()
    endforeach()
endfunction()
