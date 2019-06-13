cmake_minimum_required(VERSION 3.12.1)

function(FortranPreProcess_filename input output)
  get_filename_component(directory "${input}" DIRECTORY)
  get_filename_component(root "${input}" NAME_WE)
  get_filename_component(old_extension "${input}" EXT)
  string(TOLOWER ${old_extension} new_extension)
  set(${output} "${directory}${root}${new_extension}" PARENT_SCOPE)
endfunction()
