cmake_minimum_required(VERSION 3.12.1)
add_library(warnings_Fortran_Intel INTERFACE)

string(CONCAT generator
  "$<IF:$<PLATFORM_ID:Windows>"
      ",/warn:"
      ",-warn;>")

string(CONCAT generator
  "$<$<BOOL:$<TARGET_PROPERTY:WARN_ERROR>>:"
    "${generator}error$<COMMA>stderror>"
  "$<$<BOOL:$<TARGET_PROPERTY:WARN_ALL>>:"
    "$<IF:$<BOOL:$<TARGET_PROPERTY:WARN_ERROR>>"
        ",$<COMMA>"
        ",${generator}>"
    "all>;"
  "$<$<BOOL:$<TARGET_PROPERTY:Intel_ENABLED_WARNINGS>>:"
    "$<IF:$<PLATFORM_ID:Windows>"
        ",/Qdiag-enable:"
        ",-diag-enable=>"
    "$<JOIN:$<TARGET_PROPERTY:Intel_ENABLED_WARNINGS>,$<COMMA>>;>"
  "$<$<BOOL:$<TARGET_PROPERTY:Intel_DISABLED_WARNINGS>>:"
    "$<IF:$<PLATFORM_ID:Windows>"
        ",/Qdiag-disable:"
        ",-diag-disable=>"
    "$<JOIN:$<TARGET_PROPERTY:Intel_DISABLED_WARNINGS>,$<COMMA>>;>")

target_compile_options(shacl::cmake::Warnings_Fortran INTERFACE
  $<$<STREQUAL:${CMAKE_Fortran_COMPILER_ID},Intel>:${generator}>)
