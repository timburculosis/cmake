function(git_submodule_list)
  # ** NOTE **
  #
  # Variables which are expected to contain file or directory paths are
  # dereferenced within quotes in order to accomodate whitespace characters
  # in the path. A frequent offender in this regard are paths including
  # the 'Program Files' directory found on the Windows operating system.
  #
  #
  # --------------------------------------------------------------------------
  # Step 1: Determine the repository remote url root for use with relative git
  # submodule remote urls
  # --------------------------------------------------------------------------
  #

  #
  # Determine the highest level directory (aka root) of the git repository
  # hosting the current source directory.
  #
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" rev-parse --show-toplevel
    OUTPUT_VARIABLE repository.root
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  #
  # Determine the current branch of the git repository hosting the current
  # source directory.
  #
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" rev-parse --abbrev-ref HEAD
    OUTPUT_VARIABLE repository.branch
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  #
  # Determine the upstream remote name (e.g. origin) of the current branch of
  # the git repository hosting the current source directory. This operation can
  # fail if the current branch is not currently associated with a branch on the
  # remote.
  #
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" config --get branch.${repository.branch}.remote
    OUTPUT_VARIABLE repository.remote.name
    RESULT_VARIABLE failure
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  #
  # If the upstream remote name could not be determined by considering the
  # corresponding git branch property, we examine the remotes for the repository
  # as whole. If 'origin' is found amongst the available remote, it is assumed
  # to be the appropriate remote. Otherwise, no remote is assumed. This
  # replicates the behavior of git submodules.
  #
  if(failure)
    #
    # `git remote` returns a list of remote aliases (one per line).
    #
    execute_process(
      COMMAND  "${GIT_EXECUTABLE}" remote
      OUTPUT_VARIABLE repository.remotes
      OUTPUT_STRIP_TRAILING_WHITESPACE)

    #
    # The output of `git remote` is converted to a cmake list by replacing
    # newlines with semicolons (the cmake list's element delimiter character)
    #
    string(REPLACE "\n" ";" path_output "${repository.remotes}")

    #
    # If origin is amongst the reported remote aliases, we declare success
    #
    if("origin" IN_LIST repository.remotes)
      set(repository.remote.name origin)
      set(failure OFF)
    endif()
  endif()

  if(NOT failure)
    #
    # We query the git config for the url associated with the repository remote
    #
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" config --get remote.${repository.remote.name}.url
      OUTPUT_VARIABLE repository.remote.url
      OUTPUT_STRIP_TRAILING_WHITESPACE)

    #
    # Searching backwards, we remove split the repository remote url at the
    # first forward
    set(repository.remote.root "${repository.remote.url}")
  else()
    set(repository.remote.url "")
  endif()

  #
  # --------------------------------------------------------------------------
  # Step 2: Collect a list of the git submodules associated with the repository.
  #
  # For each submodule, we collect the following information
  #
  # + name
  # + commit hash
  # + remote url
  # + branch (optional)
  #
  # Beyond that, for each submodule, we establish variables
  #
  # + toggling the use of the submodule package
  # + toggling eager submodule consumption
  # + toggling submodule update mode
  #
  # --------------------------------------------------------------------------
  #
  if(EXISTS "${repository.root}/.gitmodules")
    #
    # List the entries in the git module file with the phrase 'path'
    #
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" config --file .gitmodules --get-regexp path
      WORKING_DIRECTORY "${repository.root}"
      OUTPUT_VARIABLE output
      OUTPUT_STRIP_TRAILING_WHITESPACE)

    #
    # Split the text output on newlines to form a list of lines.
    #
    string(REPLACE "\n" ";" output "${output}")

    foreach(line IN LISTS output)
      #
      # Split the line on whitespace. The result is a key-value pair, where
      # the key is '<submodule name>.path' and the value is the path relative
      # to the repository root directory.
      #
      string(REPLACE " " ";" line "${line}")

      #
      # Get the key and strip the '.path' component of the key to isolate the
      # submodule key.
      #
      # *** NOTE ***
      # We assume the submodule name does not embed white space.
      #
      list(GET line 0 submodule.key)
      string(FIND "${submodule.key}" ".path" truncate_point REVERSE)
      string(SUBSTRING "${submodule.key}" 0 ${truncate_point} submodule.key)

      #
      # We isolate that submodule relative path and construct the submodule
      # absolute path
      #
      list(GET line 1 submodule.path.relative)
      set(submodule.path.absolute "${repository.root}/${submodule.path.relative}")

      #
      # Only information on submodules that still exist in the repository is
      # collected.
      #
      if (EXISTS "${submodule.path.absolute}")
        #
        # We recover the submodule project name by taking the last component
        # of the submodule directory path.
        #
        # *** NOTE ***
        # We assume the submodule project name does not contain forward slashes.
        #
        get_filename_component(submodule.name "${submodule.path.absolute}" NAME)

        #
        # Provided the user has enabled git submodule packages, a fine-grained
        # option allowing the user to opt out on a submodule-by-submodule basis.
        #
        CMAKE_DEPENDENT_OPTION(
          git.submodule.package.${submodule.name}
          "Use dependency submodule for ${submodule.name}"
          ON "git.submodule.packages" OFF)

        #
        # There are potentially many submodule packages, each of which
        # establishes multiple options. This can be somewhat overwhelming to
        # a casual user when reviewing the cmake-gui or ccmake entry.
        #
        # Given the defaults have been chosen well, most users should only
        # rarely need to consider these customization points. By marking these
        # options as advanced, users can opt into the added flexibility (and
        # corresponding complexity) as needed, but can generally remain
        # blissfully unaware.
        #
        mark_as_advanced(git.submodule.package.${submodule.name})

        #
        # We collect the submodule commit hash by reviewing the corresponding
        # git index entry.
        #
        # We establish two cache entries, one that stores the commit hash
        # tracked by the parent respository and one that reflects the commit
        # hash of the current state of the submodule in the binary tree.
        #
        execute_process(
          COMMAND "${GIT_EXECUTABLE}" ls-tree HEAD "${submodule.path.relative}"
          WORKING_DIRECTORY "${repository.root}"
          OUTPUT_VARIABLE repository.index.entry
          OUTPUT_STRIP_TRAILING_WHITESPACE)

        string(REPLACE " " ";" repository.index.entry "${repository.index.entry}")
        string(REPLACE "\t" ";" repository.index.entry "${repository.index.entry}")
        list(GET repository.index.entry 2 submodule.commit_hash)

        CMAKE_DEPENDENT_CACHE_VAR(
          git.submodule.package.${submodule.name}.commit_hash.initial
          STRING
          "Initial commit hash tracked by ${submodule.name} git submodule"
          "${submodule.commit_hash}"
          "git.submodule.package.${submodule.name}"
          "")

        CMAKE_DEPENDENT_CACHE_VAR(
          git.submodule.package.${submodule.name}.commit_hash
          STRING
          "Current commit hash tracked by ${submodule.name} git submodule"
          "${submodule.commit_hash}"
          "git.submodule.package.${submodule.name}"
          "")

        mark_as_advanced(git.submodule.package.${submodule.name}.commit_hash.initial)
        mark_as_advanced(git.submodule.package.${submodule.name}.commit_hash)

        #
        # Collect the url associated with the submodule.
        #
        # If it is defined to be relative to the host repository, compute an
        # absolute address using the repository remote computed in Step 1. If no
        # repository remote could determined in Step 1, issue an error and cease
        # to process.
        #
        execute_process(
          COMMAND "${GIT_EXECUTABLE}" config --file .gitmodules
                                             --get "${submodule.key}.url"
          WORKING_DIRECTORY "${repository.root}"
          OUTPUT_VARIABLE submodule.url
          OUTPUT_STRIP_TRAILING_WHITESPACE)

        if(submodule.url MATCHES "^[.][.][/]")
          if(repository.remote.url)
            set(repository.remote.url.prefix "${repository.remote.url}")
            while(submodule.url MATCHES "^[.][.][/]")
              string(FIND "${repository.remote.url.prefix}" "/" truncate_point REVERSE)
              string(SUBSTRING "${repository.remote.url.prefix}"
                0 ${truncate_point} repository.remote.url.prefix)
              string(SUBSTRING "${submodule.url}" 3 -1 submodule.url)
            endwhile()
            set(submodule.url "${repository.remote.url.prefix}/${submodule.url}")
          else()
            message("${submodule.name} git submodule has a relative url: ${submodule.url}")
            message("${PROJECT_NAME} git repository branch, \"${repository.branch}\", does not establish a remote")
            message("${PROJECT_NAME} git repository does not provide a remote named \"origin\"")
            message(FATAL_ERROR "Could not fetch determine remote for git submodule")
          endif()
        endif()

        #
        # The repository url is exposed to the user in the cache for
        # verification and to allow for the user to modify the value after the
        # initial configure. The latter ability allows distinct build trees to
        # reference distinct forks of a dependency (each of which may provide
        # exclusive content)
        #
        CMAKE_DEPENDENT_CACHE_VAR(
          git.submodule.package.${submodule.name}.url
          STRING
          "Remote url for ${submodule.name} git submodule"
          "${submodule.url}"
          "git.submodule.package.${submodule.name}"
          "")

        mark_as_advanced(git.submodule.package.${submodule.name}.url)

        #
        # We attempt to collect the branch tracked by the submodule. This can
        # fail if the submodule doesn't track a branch (obviously).
        #
        execute_process(
          COMMAND "${GIT_EXECUTABLE}" config --file .gitmodules
                                             --get "${submodule.key}.branch"
          WORKING_DIRECTORY "${repository.root}"
          OUTPUT_VARIABLE submodule.branch
          RESULT_VARIABLE failure
          OUTPUT_STRIP_TRAILING_WHITESPACE)

        #
        # Iff the submodule tracks a branch we expose a cache variable to the
        # user along with an update policy.
        #
        if(NOT failure)
          CMAKE_DEPENDENT_CACHE_VAR(
            git.submodule.package.${submodule.name}.branch
            STRING
            "Branch tracked by ${submodule.name} git submodule"
            "${submodule.branch}"
            "git.submodule.package.${submodule.name}"
            "")

          mark_as_advanced(git.submodule.package.${submodule.name}.branch)

          #
          # Three update model options are supported
          #
          # + default
          #   Fallback to the value specified by 'git.submodule.packages.update'
          #   cache variable
          #
          # + ON
          #   On the initial cmake configuration in which the submodule
          #   repository cloned, if the submodule tracks a branch, update the
          #   submodule respository to the HEAD of the branch
          #
          # + OFF
          #   Never update a submodule state
          #
          CMAKE_DEPENDENT_SELECTION(
            git.submodule.package.${submodule.name}.update
            "${submodule.name} git submodule package configuration-time branch update behavior"
            DEFAULT default OPTIONS default ON OFF
            CONDITION "git.submodule.package.${submodule.name}.branch"
            OFF)

          mark_as_advanced(git.submodule.package.${submodule.name}.update)
        endif()

        #
        # Three consumption options are supported for a given git submodule
        # package.
        #
        # + default
        #   Fall back to the value specified by 'git.submodule.packages.eager'
        #   cache variable
        #
        # + ON
        #   Always use the git submodule package.
        #
        # + OFF
        #   Use the git submodule package iff the the package cannot be found
        #   through the underlying `find_package` utility
        #
        CMAKE_DEPENDENT_SELECTION(
          git.submodule.package.${submodule.name}.eager
          "find_package will prefer to consume ${submodule.name} via submodule"
          DEFAULT default OPTIONS default ON OFF
          CONDITION "git.submodule.package.${submodule.name}"
          OFF)

        mark_as_advanced(git.submodule.package.${submodule.name}.eager)
      endif()
    endforeach()
  endif()
endfunction()
