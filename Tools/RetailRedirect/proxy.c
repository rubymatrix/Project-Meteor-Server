// Pass-through for every iphlpapi.dll export.
//
// Windows' own networking DLLs import from iphlpapi too, and once this DLL is loaded under that
// name they bind to it. So each export is a thunk that jumps to the same function in the system
// iphlpapi.dll, loaded by full path so the loader can't pick this file again.

#include <windows.h>

#include "redirect.h"

static const char* const g_names[] = {
#define X(index, name) #name,
#include "exports.h"
#undef X
};

#define EXPORT_COUNT (sizeof(g_names) / sizeof(g_names[0]))

// Read by the thunks. Exported as a plain symbol so the asm below can name it.
void* g_real[EXPORT_COUNT];

#if defined(_MSC_VER)
#define X(index, name) \
    __declspec(naked) void Thunk_##name(void) { __asm { jmp dword ptr [g_real + (index) * 4] } }
#include "exports.h"
#undef X
#else
#define STR2(x) #x
#define STR(x) STR2(x)
#define X(index, name) \
    __asm__(".text\n.globl _Thunk_" #name "\n_Thunk_" #name ":\n\tjmp *_g_real+" STR(index) "*4\n");
#include "exports.h"
#undef X
#endif

static BOOL LoadSystemIphlpapi(void)
{
    // In a 32-bit process on 64-bit Windows, System32 maps to SysWOW64.
    wchar_t path[MAX_PATH];
    UINT len = GetSystemDirectoryW(path, MAX_PATH - 16);
    if (len == 0 || len >= MAX_PATH - 16)
        return FALSE;
    lstrcatW(path, L"\\iphlpapi.dll");

    HMODULE real = LoadLibraryW(path);
    if (real == NULL)
        return FALSE;

    // An export this Windows lacks stays NULL; no DLL on this Windows imports it.
    for (unsigned i = 0; i < EXPORT_COUNT; i++)
        g_real[i] = (void*)GetProcAddress(real, g_names[i]);
    return TRUE;
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved)
{
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH)
    {
        DisableThreadLibraryCalls(instance);
        if (!LoadSystemIphlpapi())
            return FALSE;
        Redirect_Start(instance);
    }
    return TRUE;
}
