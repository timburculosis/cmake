function(CMAKE_DEPENDENT_CACHE_VAR option type doc default depends force)
  list(APPEND type_list FILEPATH PATH STRING BOOL)
  list(FIND type_list ${type} type_found)
  if( type_found LESS 0 )
    message(FATAL_ERROR "CMAKE_DEPENDENT_CACHE_VAR error: variable type '${type}' must be one of FILEPATH, PATH, STRING, or BOOL")
  endif()

  set(${option}_AVAILABLE 1)
  foreach(d ${depends})
    string(REGEX REPLACE " +" ";" CMAKE_DEPENDENT_OPTION_DEP "${d}")
    if(${CMAKE_DEPENDENT_OPTION_DEP})
    else()
      set(${option}_AVAILABLE 0)
    endif()
  endforeach()

  if(${option}_AVAILABLE)
    set(${option} "${default}" CACHE "${type}" "${doc}" FORCE)
  else()
    set(${option} "${force}" CACHE INTERNAL "${doc}" FORCE)
  endif()
endfunction()
