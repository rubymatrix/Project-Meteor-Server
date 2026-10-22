cmake_minimum_required(VERSION 3.16)
project(RetailRedirect C)

# Loads into the retail executables, which are 32-bit.
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
    message(FATAL_ERROR "Build for 32-bit x86: cmake -A Win32 (Visual Studio) or an i686 MinGW compiler.")
endif()

add_library(iphlpapi SHARED proxy.c redirect.c iphlpapi.def)
set_target_properties(iphlpapi PROPERTIES PREFIX "" OUTPUT_NAME "iphlpapi")

if(MSVC)
    # No CRT dependency on the player's PC; no safe-exception-handler table for the asm thunks.
    set_property(TARGET iphlpapi PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded")
    target_link_options(iphlpapi PRIVATE /SAFESEH:NO)
else()
    # The code calls only kernel32/user32, so no C runtime: nothing to install on the player's PC.
    target_compile_options(iphlpapi PRIVATE -O2 -Wall -fno-stack-protector)
    target_link_options(iphlpapi PRIVATE -nostdlib -Wl,-e,_DllMain@12 -Wl,--enable-stdcall-fixup)
    target_link_libraries(iphlpapi PRIVATE kernel32 user32 gcc)
endif()

add_custom_command(TARGET iphlpapi POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_SOURCE_DIR}/iphlpapi.ini $<TARGET_FILE_DIR:iphlpapi>)
