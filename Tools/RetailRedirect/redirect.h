#pragma once

#include <windows.h>

// Reads iphlpapi.ini beside the DLL and starts redirecting the configured host names.
void Redirect_Start(HINSTANCE self);
