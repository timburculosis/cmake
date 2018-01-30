string(CONCAT generator
  "$<$<STREQUAL:${CMAKE_Fortran_COMPILER_ID},Intel>"
    ":$<$<NOT:$<PLATFORM_ID:Windows>>"
       ":$<$<BOOL:FortranTypes.real.32>:-real-size 32>"
        "$<$<BOOL:FortranTypes.real.64>:-real-size 64>>"
     "$<$<PLATFORM_ID:Windows>"
       ":$<$<BOOL:FortranTypes.real.32>:/real-size:32>"
        "$<$<BOOL:FortranTypes.real.64>:/real-size:64>>>")

target_compile_options(Fortran_Real_Fortran INTERFACE ${generator})

unset(generator)