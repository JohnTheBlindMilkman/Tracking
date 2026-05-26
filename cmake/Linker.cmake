macro(Tracking_configure_linker project_name)
  set(Tracking_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(Tracking_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE Tracking_USER_LINKER_OPTION PROPERTY STRINGS ${Tracking_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    Tracking_USER_LINKER_OPTION_VALUES
    ${Tracking_USER_LINKER_OPTION}
    Tracking_USER_LINKER_OPTION_INDEX)

  if(${Tracking_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${Tracking_USER_LINKER_OPTION}', explicitly supported entries are ${Tracking_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${Tracking_USER_LINKER_OPTION}")
endmacro()
