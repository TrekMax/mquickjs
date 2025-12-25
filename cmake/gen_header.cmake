# Usage:
#   cmake -DTOOL=/path/to/tool -DOUT=/path/to/out.h -DARGS_STR="..." -P gen_header.cmake
# ARGS_STR is parsed like a shell command line (UNIX style) into arguments.
# If ARGS (a CMake list) is provided instead, it is used as-is.

if(NOT DEFINED TOOL OR TOOL STREQUAL "")
  message(FATAL_ERROR "TOOL is required")
endif()
if(NOT DEFINED OUT OR OUT STREQUAL "")
  message(FATAL_ERROR "OUT is required")
endif()

if(NOT EXISTS "${TOOL}")
  message(FATAL_ERROR "TOOL does not exist: ${TOOL}")
endif()

if(DEFINED ARGS)
  # Use ARGS as-is (CMake list).
elseif(DEFINED ARGS_STR)
  set(ARGS "${ARGS_STR}")
  separate_arguments(ARGS UNIX_COMMAND "${ARGS_STR}")
else()
  set(ARGS "")
endif()

execute_process(
  COMMAND "${TOOL}" ${ARGS}
  OUTPUT_FILE "${OUT}"
  RESULT_VARIABLE _rv
)

if(NOT _rv EQUAL 0)
  message(FATAL_ERROR "Header generation failed (exit ${_rv}): ${TOOL} ${ARGS}")
endif()
