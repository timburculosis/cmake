include(Backports/IncludeGuard)
include_guard(GLOBAL)

if( "Intel" STREQUAL "${CMAKE_Fortran_COMPILER_ID}")
  set(Fortran.Intel.DiagDisable "" CACHE STRING "comma-separated list of Intel Fortran diagnostic numbers to dissable")
endif()

add_library(Fortran_IntelDiagDisable INTERFACE)
add_library(Fortran::IntelDiagDisable ALIAS Fortran_IntelDiagDisable)

string(CONCAT generator
  "$<$<BOOL:${Fortran.Intel.DiagDisable}>:"
    "$<$<STREQUAL:Intel,${CMAKE_Fortran_COMPILER_ID}>:"
      "$<$<NOT:$<PLATFORM_ID:Windows>>:-diag-disable;${Fortran.Intel.DiagDisable}>"
      "$<$<PLATFORM_ID:Windows>:/Qdiag-disable:${Fortran.Intel.DiagDisable}>"
    ">"
  ">"
)

target_compile_options(Fortran_IntelDiagDisable INTERFACE ${generator})
