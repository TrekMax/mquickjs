cmake_minimum_required(VERSION 3.20)

project(mquickjs C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

option(MQJS_SMALL "Use -Os like CONFIG_SMALL=y" ON)
option(MQJS_WERROR "Treat warnings as errors (CONFIG_WERROR=y)" OFF)
option(MQJS_SOFTFLOAT "Enable soft-float flags (CONFIG_SOFTFLOAT=y)" OFF)
option(MQJS_ASAN "Enable AddressSanitizer flags (CONFIG_ASAN=y)" OFF)
option(MQJS_GPROF "Enable gprof flags (CONFIG_GPROF=y)" OFF)
option(MQJS_PROFILE "Enable profiling flags (CONFIG_PROFILE=y)" OFF)
option(MQJS_X86_32 "Force -m32 output (CONFIG_X86_32=y)" OFF)
option(MQJS_ARM32 "Enable ARM32 thumb + -m32 build flags (CONFIG_ARM32=y)" OFF)

option(MQJS_BUILD_EXAMPLES "Build example executable" ON)
option(MQJS_BUILD_TESTS "Build C unit test executables (dtoa_test, libm_test)" OFF)

# Host tools are executed at build time to generate headers.
set(MQJS_HOST_CC "gcc" CACHE STRING "Host C compiler used to build header-generator tools when cross-compiling")

# Common flags (mirrors the Makefile intent; build type still controls -g/-O in most toolchains)
set(_mqjs_common_cflags
    -Wall
    -D_GNU_SOURCE
    -fno-math-errno
    -fno-trapping-math
)

if(MQJS_WERROR)
    list(APPEND _mqjs_common_cflags -Werror)
endif()

if(MQJS_SMALL)
    list(APPEND _mqjs_common_cflags -Os)
else()
    list(APPEND _mqjs_common_cflags -O2)
endif()

if(MQJS_SOFTFLOAT)
    list(APPEND _mqjs_common_cflags -msoft-float)
    add_compile_definitions(USE_SOFTFLOAT)
endif()

set(_mqjs_common_ldflags "")

if(MQJS_GPROF)
    list(APPEND _mqjs_common_cflags -p)
    set(_mqjs_common_ldflags "${_mqjs_common_ldflags} -p")
endif()

if(MQJS_PROFILE)
    list(APPEND _mqjs_common_cflags -p)
    set(_mqjs_common_ldflags "${_mqjs_common_ldflags} -p")
endif()

if(MQJS_ASAN)
    list(APPEND _mqjs_common_cflags -fsanitize=address -fno-omit-frame-pointer)
    set(_mqjs_common_ldflags "${_mqjs_common_ldflags} -fsanitize=address -fno-omit-frame-pointer")
endif()

if(MQJS_X86_32)
    list(APPEND _mqjs_common_cflags -m32)
    set(_mqjs_common_ldflags "${_mqjs_common_ldflags} -m32")
endif()

if(MQJS_ARM32)
    list(APPEND _mqjs_common_cflags -mthumb)
    # Makefile also forces -m32 for the atom table generator build flags on ARM32.
    set(_mqjs_build_flags -m32)
else()
    set(_mqjs_build_flags "")
endif()

if(MQJS_X86_32)
    set(_mqjs_build_flags -m32)
endif()

# Apply common link flags (kept simple; advanced users can use CMAKE_EXE_LINKER_FLAGS)
string(STRIP "${_mqjs_common_ldflags}" _mqjs_common_ldflags)
if(NOT _mqjs_common_ldflags STREQUAL "")
    add_link_options(${_mqjs_common_ldflags})
endif()

# Generated headers live in the build directory (avoids touching the source tree)
set(MQJS_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(MQJS_MQUICKJS_ATOM_H "${MQJS_GEN_DIR}/mquickjs_atom.h")
set(MQJS_MQJS_STDLIB_H "${MQJS_GEN_DIR}/mqjs_stdlib.h")
set(MQJS_EXAMPLE_STDLIB_H "${MQJS_GEN_DIR}/example_stdlib.h")

# Host tools to generate headers (mqjs_stdlib / example_stdlib)
if(NOT CMAKE_CROSSCOMPILING)
    add_executable(mqjs_stdlib_host mqjs_stdlib.c mquickjs_build.c)
    target_compile_options(mqjs_stdlib_host PRIVATE ${_mqjs_common_cflags} -O2)
    target_include_directories(mqjs_stdlib_host PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${MQJS_GEN_DIR}")

    add_executable(example_stdlib_host example_stdlib.c mquickjs_build.c)
    target_compile_options(example_stdlib_host PRIVATE ${_mqjs_common_cflags} -O2)
    target_include_directories(example_stdlib_host PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${MQJS_GEN_DIR}")

    set(_mqjs_stdlib_tool "$<TARGET_FILE:mqjs_stdlib_host>")
    set(_example_stdlib_tool "$<TARGET_FILE:example_stdlib_host>")
else()
    # When cross-compiling, the target compiler cannot produce runnable binaries.
    # Build generator tools with MQJS_HOST_CC via custom commands.
    set(_mqjs_stdlib_tool "${MQJS_GEN_DIR}/mqjs_stdlib_host${CMAKE_EXECUTABLE_SUFFIX}")
    set(_example_stdlib_tool "${MQJS_GEN_DIR}/example_stdlib_host${CMAKE_EXECUTABLE_SUFFIX}")

    add_custom_command(
        OUTPUT "${_mqjs_stdlib_tool}"
        COMMAND "${MQJS_HOST_CC}" -Wall -g -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -O2
                -I"${CMAKE_CURRENT_SOURCE_DIR}" -I"${MQJS_GEN_DIR}"
                -o "${_mqjs_stdlib_tool}" "${CMAKE_CURRENT_SOURCE_DIR}/mqjs_stdlib.c" "${CMAKE_CURRENT_SOURCE_DIR}/mquickjs_build.c"
        DEPENDS mqjs_stdlib.c mquickjs_build.c mquickjs_build.h mquickjs_build_opcode.h mquickjs_opcode.h
        VERBATIM
    )

    add_custom_command(
        OUTPUT "${_example_stdlib_tool}"
        COMMAND "${MQJS_HOST_CC}" -Wall -g -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -O2
                -I"${CMAKE_CURRENT_SOURCE_DIR}" -I"${MQJS_GEN_DIR}"
                -o "${_example_stdlib_tool}" "${CMAKE_CURRENT_SOURCE_DIR}/example_stdlib.c" "${CMAKE_CURRENT_SOURCE_DIR}/mquickjs_build.c"
        DEPENDS example_stdlib.c mquickjs_build.c mquickjs_build.h mquickjs_build_opcode.h mquickjs_opcode.h
        VERBATIM
    )

    add_custom_target(mqjs_stdlib_host DEPENDS "${_mqjs_stdlib_tool}")
    add_custom_target(example_stdlib_host DEPENDS "${_example_stdlib_tool}")
endif()

add_custom_command(
    OUTPUT "${MQJS_MQUICKJS_ATOM_H}"
    COMMAND "${_mqjs_stdlib_tool}" -a ${_mqjs_build_flags} > "${MQJS_MQUICKJS_ATOM_H}"
    DEPENDS ${_mqjs_stdlib_tool}
    VERBATIM
)
set_source_files_properties("${MQJS_MQUICKJS_ATOM_H}" PROPERTIES GENERATED TRUE)

add_custom_command(
    OUTPUT "${MQJS_MQJS_STDLIB_H}"
    COMMAND "${_mqjs_stdlib_tool}" ${_mqjs_build_flags} > "${MQJS_MQJS_STDLIB_H}"
    DEPENDS ${_mqjs_stdlib_tool}
    VERBATIM
)
set_source_files_properties("${MQJS_MQJS_STDLIB_H}" PROPERTIES GENERATED TRUE)

add_custom_command(
    OUTPUT "${MQJS_EXAMPLE_STDLIB_H}"
    COMMAND "${_example_stdlib_tool}" ${_mqjs_build_flags} > "${MQJS_EXAMPLE_STDLIB_H}"
    DEPENDS ${_example_stdlib_tool}
    VERBATIM
)
set_source_files_properties("${MQJS_EXAMPLE_STDLIB_H}" PROPERTIES GENERATED TRUE)

add_custom_target(mqjs_generated_headers
    DEPENDS "${MQJS_MQUICKJS_ATOM_H}" "${MQJS_MQJS_STDLIB_H}" "${MQJS_EXAMPLE_STDLIB_H}"
)

# Core sources (shared between mqjs and example)
add_library(mquickjs_core OBJECT
    mquickjs.c
    dtoa.c
    libm.c
    cutils.c
)
add_dependencies(mquickjs_core mqjs_generated_headers)

target_compile_options(mquickjs_core PRIVATE ${_mqjs_common_cflags})
target_include_directories(mquickjs_core PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${MQJS_GEN_DIR}"
)

# mqjs CLI
add_executable(mqjs
    mqjs.c
    readline_tty.c
    readline.c
    $<TARGET_OBJECTS:mquickjs_core>
)
add_dependencies(mqjs mqjs_generated_headers)

target_compile_options(mqjs PRIVATE ${_mqjs_common_cflags})
target_include_directories(mqjs PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${MQJS_GEN_DIR}")
target_link_libraries(mqjs PRIVATE m)

# C API example
if(MQJS_BUILD_EXAMPLES)
    add_executable(example
        example.c
        $<TARGET_OBJECTS:mquickjs_core>
    )
    add_dependencies(example mqjs_generated_headers)
    target_compile_options(example PRIVATE ${_mqjs_common_cflags})
    target_include_directories(example PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${MQJS_GEN_DIR}")
    target_link_libraries(example PRIVATE m)
endif()

# C tests (from Makefile)
if(MQJS_BUILD_TESTS)
    add_executable(dtoa_test
        tests/dtoa_test.c
        tests/gay-fixed.c
        tests/gay-precision.c
        tests/gay-shortest.c
        dtoa.c
        cutils.c
    )
    target_compile_options(dtoa_test PRIVATE ${_mqjs_common_cflags})
    target_include_directories(dtoa_test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${MQJS_GEN_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/tests")
    target_link_libraries(dtoa_test PRIVATE m)

    add_executable(libm_test
        tests/libm_test.c
        libm.c
    )
    target_compile_options(libm_test PRIVATE ${_mqjs_common_cflags})
    target_include_directories(libm_test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${MQJS_GEN_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/tests")
    target_link_libraries(libm_test PRIVATE m)
endif()

# JS regression tests (mirrors Makefile 'test' target) via CTest when available
include(CTest)
if(BUILD_TESTING)
    add_test(NAME js_test_closure   COMMAND mqjs "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_closure.js")
    add_test(NAME js_test_language  COMMAND mqjs "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_language.js")
    add_test(NAME js_test_loop      COMMAND mqjs "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_loop.js")
    add_test(NAME js_test_builtin   COMMAND mqjs "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_builtin.js")

    add_test(NAME js_test_bytecode_gen COMMAND mqjs -o test_builtin.bin "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_builtin.js")
    add_test(NAME js_test_bytecode_run COMMAND mqjs test_builtin.bin)

    if(TARGET example)
        add_test(NAME js_test_example_rect COMMAND example "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_rect.js")
    endif()
endif()
