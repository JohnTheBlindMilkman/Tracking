include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(Tracking_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(Tracking_setup_options)
  option(Tracking_ENABLE_HARDENING "Enable hardening" ON)
  option(Tracking_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Tracking_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Tracking_ENABLE_HARDENING
    OFF)

  Tracking_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Tracking_PACKAGING_MAINTAINER_MODE)
    option(Tracking_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Tracking_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Tracking_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Tracking_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Tracking_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Tracking_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Tracking_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Tracking_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Tracking_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Tracking_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Tracking_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Tracking_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Tracking_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Tracking_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Tracking_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Tracking_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Tracking_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Tracking_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Tracking_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Tracking_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Tracking_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Tracking_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Tracking_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Tracking_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Tracking_ENABLE_IPO
      Tracking_WARNINGS_AS_ERRORS
      Tracking_ENABLE_SANITIZER_ADDRESS
      Tracking_ENABLE_SANITIZER_LEAK
      Tracking_ENABLE_SANITIZER_UNDEFINED
      Tracking_ENABLE_SANITIZER_THREAD
      Tracking_ENABLE_SANITIZER_MEMORY
      Tracking_ENABLE_UNITY_BUILD
      Tracking_ENABLE_CLANG_TIDY
      Tracking_ENABLE_CPPCHECK
      Tracking_ENABLE_COVERAGE
      Tracking_ENABLE_PCH
      Tracking_ENABLE_CACHE)
  endif()

  Tracking_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Tracking_ENABLE_SANITIZER_ADDRESS OR Tracking_ENABLE_SANITIZER_THREAD OR Tracking_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Tracking_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Tracking_global_options)
  if(Tracking_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Tracking_enable_ipo()
  endif()

  Tracking_supports_sanitizers()

  if(Tracking_ENABLE_HARDENING AND Tracking_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Tracking_ENABLE_SANITIZER_UNDEFINED
       OR Tracking_ENABLE_SANITIZER_ADDRESS
       OR Tracking_ENABLE_SANITIZER_THREAD
       OR Tracking_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Tracking_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Tracking_ENABLE_SANITIZER_UNDEFINED}")
    Tracking_enable_hardening(Tracking_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Tracking_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Tracking_warnings INTERFACE)
  add_library(Tracking_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Tracking_set_project_warnings(
    Tracking_warnings
    ${Tracking_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    Tracking_enable_sanitizers(
      Tracking_options
      ${Tracking_ENABLE_SANITIZER_ADDRESS}
      ${Tracking_ENABLE_SANITIZER_LEAK}
      ${Tracking_ENABLE_SANITIZER_UNDEFINED}
      ${Tracking_ENABLE_SANITIZER_THREAD}
      ${Tracking_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(Tracking_options PROPERTIES UNITY_BUILD ${Tracking_ENABLE_UNITY_BUILD})

  if(Tracking_ENABLE_PCH)
    target_precompile_headers(
      Tracking_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Tracking_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Tracking_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Tracking_ENABLE_CLANG_TIDY)
    Tracking_enable_clang_tidy(Tracking_options ${Tracking_WARNINGS_AS_ERRORS})
  endif()

  if(Tracking_ENABLE_CPPCHECK)
    Tracking_enable_cppcheck(${Tracking_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Tracking_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Tracking_enable_coverage(Tracking_options)
  endif()

  if(Tracking_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Tracking_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Tracking_ENABLE_HARDENING AND NOT Tracking_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Tracking_ENABLE_SANITIZER_UNDEFINED
       OR Tracking_ENABLE_SANITIZER_ADDRESS
       OR Tracking_ENABLE_SANITIZER_THREAD
       OR Tracking_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Tracking_enable_hardening(Tracking_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
