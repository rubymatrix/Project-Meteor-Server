# Native Lua runtime for the map server: xLua's C glue (xlua/) linked against a
# static LuaJIT 2.1 into one shared library named xlua, the name xLua's LuaDLL.cs
# P/Invokes. Output lands in runtimes/<rid>/native/ for Map Server.csproj to copy.
#
#   cmake -S native -B native/build -G Ninja -DCMAKE_BUILD_TYPE=Release
#   cmake --build native/build
#   ctest --test-dir native/build --output-on-failure
#
# Windows: run from a VS x64 developer prompt (msvcbuild.bat needs cl/lib on PATH).

cmake_minimum_required(VERSION 3.24)

if(APPLE AND NOT CMAKE_OSX_DEPLOYMENT_TARGET)
  set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
endif()

project(xlua C)

set(LUAJIT_COMMIT "dd3b24369ddfaa83c78cd6fdd91d157c8968ec8d")
set(LUAJIT_SHA256 "a6ac8457c474c6fb71aaa7660dd5bf8f6e0506496fc74786b2dae18e26a768cc")
set(LUAJIT_URL "https://github.com/LuaJIT/LuaJIT/archive/${LUAJIT_COMMIT}.tar.gz")

option(XLUA_LUA52COMPAT "Build LuaJIT with LUAJIT_ENABLE_LUA52COMPAT" OFF)
set(LUAJIT_SOURCE_DIR "" CACHE PATH "Use this LuaJIT checkout instead of downloading the pinned tarball")
set(XLUA_RID "" CACHE STRING ".NET runtime identifier of the output (detected when empty)")

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# --- RID -------------------------------------------------------------------
if(NOT XLUA_RID)
  if(APPLE AND CMAKE_OSX_ARCHITECTURES)
    set(_arch "${CMAKE_OSX_ARCHITECTURES}")
  else()
    set(_arch "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  string(TOLOWER "${_arch}" _arch)
  if(_arch MATCHES "^(arm64|aarch64)$")
    set(_arch arm64)
  elseif(_arch MATCHES "^(x86_64|amd64|x64)$")
    set(_arch x64)
  else()
    message(FATAL_ERROR "Unsupported architecture '${_arch}'; set XLUA_RID")
  endif()
  if(APPLE)
    set(XLUA_RID "osx-${_arch}")
  elseif(WIN32)
    set(XLUA_RID "win-${_arch}")
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(XLUA_RID "linux-${_arch}")
  else()
    message(FATAL_ERROR "Unsupported system '${CMAKE_SYSTEM_NAME}'; set XLUA_RID")
  endif()
endif()
set(XLUA_OUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/runtimes/${XLUA_RID}/native")
message(STATUS "xlua: RID ${XLUA_RID} -> ${XLUA_OUT_DIR}")

# --- LuaJIT source ---------------------------------------------------------
# LuaJIT's Makefile and msvcbuild.bat both build in-tree, so a user-supplied
# checkout is copied into the build directory first.
set(_lj_root "${CMAKE_CURRENT_BINARY_DIR}/luajit")
if(LUAJIT_SOURCE_DIR)
  if(NOT EXISTS "${_lj_root}/src/lua.h")
    file(COPY "${LUAJIT_SOURCE_DIR}/" DESTINATION "${_lj_root}" PATTERN ".git" EXCLUDE)
  endif()
else()
  set(_lj_tgz "${CMAKE_CURRENT_BINARY_DIR}/luajit-${LUAJIT_COMMIT}.tar.gz")
  if(NOT EXISTS "${_lj_root}/src/lua.h")
    file(DOWNLOAD "${LUAJIT_URL}" "${_lj_tgz}" EXPECTED_HASH SHA256=${LUAJIT_SHA256} TLS_VERIFY ON)
    file(ARCHIVE_EXTRACT INPUT "${_lj_tgz}" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")
    file(RENAME "${CMAKE_CURRENT_BINARY_DIR}/LuaJIT-${LUAJIT_COMMIT}" "${_lj_root}")
  endif()
endif()
set(_lj_src "${_lj_root}/src")

# --- LuaJIT static library -------------------------------------------------
if(MSVC)
  # "mixed" compiles with LUA_BUILD_AS_DLL, so the lua_* definitions carry
  # dllexport and stay exported once the static lib is linked into xlua.dll.
  set(_lj_lib "${_lj_src}/lua51.lib")
  set(_lj_args "")
  if(XLUA_LUA52COMPAT)
    list(APPEND _lj_args lua52compat)
  endif()
  list(APPEND _lj_args mixed)
  add_custom_command(
    OUTPUT "${_lj_lib}"
    COMMAND cmd /c msvcbuild.bat ${_lj_args}
    WORKING_DIRECTORY "${_lj_src}"
    COMMENT "Building LuaJIT (msvcbuild ${_lj_args})"
    VERBATIM)
else()
  set(_lj_lib "${_lj_src}/libluajit.a")
  # -fPIC: the archive is linked into a shared library.
  set(_lj_cflags "-fPIC")
  if(XLUA_LUA52COMPAT)
    string(APPEND _lj_cflags " -DLUAJIT_ENABLE_LUA52COMPAT")
  endif()
  set(_lj_env "")
  if(APPLE)
    list(APPEND _lj_env "MACOSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}")
  endif()
  find_program(MAKE_EXECUTABLE NAMES gmake make REQUIRED)
  cmake_host_system_information(RESULT _jobs QUERY NUMBER_OF_LOGICAL_CORES)
  add_custom_command(
    OUTPUT "${_lj_lib}"
    COMMAND ${CMAKE_COMMAND} -E env ${_lj_env}
            ${MAKE_EXECUTABLE} -j${_jobs} BUILDMODE=static
            "CC=${CMAKE_C_COMPILER}" "XCFLAGS=${_lj_cflags}" libluajit.a
    WORKING_DIRECTORY "${_lj_src}"
    COMMENT "Building LuaJIT (static)"
    VERBATIM)
endif()
add_custom_target(luajit_build DEPENDS "${_lj_lib}")

add_library(luajit STATIC IMPORTED GLOBAL)
set_target_properties(luajit PROPERTIES IMPORTED_LOCATION "${_lj_lib}")
target_include_directories(luajit INTERFACE "${_lj_src}")
add_dependencies(luajit luajit_build)
if(XLUA_LUA52COMPAT)
  target_compile_definitions(luajit INTERFACE LUAJIT_ENABLE_LUA52COMPAT)
endif()

# --- xlua shared library ---------------------------------------------------
add_library(xlua SHARED xlua/xlua.c xlua/i64lib.c)
target_compile_definitions(xlua PRIVATE USING_LUAJIT)
if(WIN32)
  target_compile_definitions(xlua PRIVATE LUA_BUILD_AS_DLL _CRT_SECURE_NO_WARNINGS)
  # msvcbuild compiles LuaJIT with /MD.
  set_target_properties(xlua PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
endif()
# Whole archive: the CLR resolves lua_* from this library, and nothing inside
# it references most of them.
target_link_libraries(xlua PRIVATE "$<LINK_LIBRARY:WHOLE_ARCHIVE,luajit>")
if(NOT WIN32)
  target_link_libraries(xlua PRIVATE m ${CMAKE_DL_LIBS})
endif()
set_target_properties(xlua PROPERTIES
  OUTPUT_NAME xlua
  # $<0:> keeps multi-config generators from appending a per-config subdirectory.
  LIBRARY_OUTPUT_DIRECTORY "${XLUA_OUT_DIR}$<0:>"
  RUNTIME_OUTPUT_DIRECTORY "${XLUA_OUT_DIR}$<0:>"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}$<0:>")
if(APPLE)
  set_target_properties(xlua PROPERTIES INSTALL_NAME_DIR "@rpath")
endif()

# --- smoke test ------------------------------------------------------------
# Loads the library at run time like the CLR does, resolves every entry point
# LuaDLL.cs imports, then runs smoke/smoke.lua through them.
add_executable(xlua_smoke smoke/smoke.c)
add_dependencies(xlua_smoke xlua)
if(NOT WIN32)
  target_link_libraries(xlua_smoke PRIVATE ${CMAKE_DL_LIBS})
endif()
enable_testing()
add_test(NAME xlua_smoke
  COMMAND xlua_smoke "$<TARGET_FILE:xlua>"
          "${CMAKE_CURRENT_SOURCE_DIR}/smoke/exports.txt"
          "${CMAKE_CURRENT_SOURCE_DIR}/smoke/smoke.lua")
