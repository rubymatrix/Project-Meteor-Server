// Redirects the host names the retail executables have built in (ver01.ffxiv.com,
// account.square-enix.com, lobby01.ffxiv.com, and track01.ffxiv.com from the retail patch
// torrents) to the server named in iphlpapi.ini.
//
// The name lookups live in ws2_32.dll and are reached from the executables, from WinHTTP (boot's
// version check) and from the WebBrowser control (the login page). Each lookup hook swaps a
// redirected name for the server address and calls the real function, so results are built and
// freed by ws2_32 as usual.
//
// Hooks go in two ways, neither of which patches code:
//  - ws2_32's export table, as soon as ws2_32 is loaded: later imports and GetProcAddress get
//    the hooks.
//  - the import table of every loaded module, at start and on each DLL load: catches modules
//    that bound to ws2_32 before the export table was patched.

#define _WIN32_WINNT 0x0601
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

#include "redirect.h"

#define MAX_HOSTS 16

static char    g_server[256];
static wchar_t g_serverW[256];
static char    g_hosts[MAX_HOSTS][256];
static int     g_hostCount;
static BOOL    g_log;
static wchar_t g_logPath[MAX_PATH];
static HMODULE g_self;
static HMODULE g_ws2;
static CRITICAL_SECTION g_logLock;

// ---------------------------------------------------------------------------------------------
// Logging (iphlpapi.log beside the DLL, when log=1)

static void Log(const char* format, ...)
{
    if (!g_log)
        return;

    char line[1024];
    SYSTEMTIME now;
    GetLocalTime(&now);
    int len = wsprintfA(line, "[%02d:%02d:%02d.%03d] [%lu] ", now.wHour, now.wMinute, now.wSecond,
        now.wMilliseconds, GetCurrentProcessId());
    va_list args;
    va_start(args, format);
    len += wvsprintfA(line + len, format, args);
    va_end(args);
    lstrcpyA(line + len, "\r\n");
    len += 2;

    EnterCriticalSection(&g_logLock);
    HANDLE file = CreateFileW(g_logPath, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
        OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file != INVALID_HANDLE_VALUE)
    {
        DWORD written;
        WriteFile(file, line, (DWORD)len, &written, NULL);
        CloseHandle(file);
    }
    LeaveCriticalSection(&g_logLock);
}

// ---------------------------------------------------------------------------------------------
// Name matching

static BOOL IsRedirected(const char* name)
{
    if (name == NULL || g_server[0] == 0)
        return FALSE;

    int len = lstrlenA(name);
    if (len > 0 && name[len - 1] == '.')
        len--;
    for (int i = 0; i < g_hostCount; i++)
    {
        if (lstrlenA(g_hosts[i]) == len &&
            CompareStringA(LOCALE_INVARIANT, NORM_IGNORECASE, name, len, g_hosts[i], len) == CSTR_EQUAL)
            return TRUE;
    }
    return FALSE;
}

static const char* MapA(const char* name, const char* via)
{
    if (!IsRedirected(name))
        return name;
    Log("%s: %s -> %s", via, name, g_server);
    return g_server;
}

static const wchar_t* MapW(const wchar_t* name, const char* via)
{
    if (name == NULL)
        return name;
    char narrow[256];
    if (WideCharToMultiByte(CP_ACP, 0, name, -1, narrow, sizeof(narrow), NULL, NULL) == 0)
        return name;
    if (!IsRedirected(narrow))
        return name;
    Log("%s: %s -> %s", via, narrow, g_server);
    return g_serverW;
}

// ---------------------------------------------------------------------------------------------
// Hooks

typedef struct hostent* (WSAAPI *gethostbyname_t)(const char*);
typedef int (WSAAPI *getaddrinfo_t)(PCSTR, PCSTR, const ADDRINFOA*, PADDRINFOA*);
typedef int (WSAAPI *GetAddrInfoW_t)(PCWSTR, PCWSTR, const ADDRINFOW*, PADDRINFOW*);
typedef int (WSAAPI *GetAddrInfoExA_t)(PCSTR, PCSTR, DWORD, LPGUID, const ADDRINFOEXA*, PADDRINFOEXA*,
    struct timeval*, LPOVERLAPPED, LPLOOKUPSERVICE_COMPLETION_ROUTINE, LPHANDLE);
typedef int (WSAAPI *GetAddrInfoExW_t)(PCWSTR, PCWSTR, DWORD, LPGUID, const ADDRINFOEXW*, PADDRINFOEXW*,
    struct timeval*, LPOVERLAPPED, LPLOOKUPSERVICE_COMPLETION_ROUTINE, LPHANDLE);
typedef HANDLE (WSAAPI *WSAAsyncGetHostByName_t)(HWND, u_int, const char*, char*, int);

static gethostbyname_t         Real_gethostbyname;
static getaddrinfo_t           Real_getaddrinfo;
static GetAddrInfoW_t          Real_GetAddrInfoW;
static GetAddrInfoExA_t        Real_GetAddrInfoExA;
static GetAddrInfoExW_t        Real_GetAddrInfoExW;
static WSAAsyncGetHostByName_t Real_WSAAsyncGetHostByName;

static struct hostent* WSAAPI Hook_gethostbyname(const char* name)
{
    return Real_gethostbyname(MapA(name, "gethostbyname"));
}

static int WSAAPI Hook_getaddrinfo(PCSTR node, PCSTR service, const ADDRINFOA* hints, PADDRINFOA* result)
{
    return Real_getaddrinfo(MapA(node, "getaddrinfo"), service, hints, result);
}

static int WSAAPI Hook_GetAddrInfoW(PCWSTR node, PCWSTR service, const ADDRINFOW* hints, PADDRINFOW* result)
{
    return Real_GetAddrInfoW(MapW(node, "GetAddrInfoW"), service, hints, result);
}

static int WSAAPI Hook_GetAddrInfoExA(PCSTR name, PCSTR service, DWORD nameSpace, LPGUID nspId,
    const ADDRINFOEXA* hints, PADDRINFOEXA* result, struct timeval* timeout, LPOVERLAPPED overlapped,
    LPLOOKUPSERVICE_COMPLETION_ROUTINE completion, LPHANDLE handle)
{
    return Real_GetAddrInfoExA(MapA(name, "GetAddrInfoExA"), service, nameSpace, nspId, hints, result,
        timeout, overlapped, completion, handle);
}

static int WSAAPI Hook_GetAddrInfoExW(PCWSTR name, PCWSTR service, DWORD nameSpace, LPGUID nspId,
    const ADDRINFOEXW* hints, PADDRINFOEXW* result, struct timeval* timeout, LPOVERLAPPED overlapped,
    LPLOOKUPSERVICE_COMPLETION_ROUTINE completion, LPHANDLE handle)
{
    return Real_GetAddrInfoExW(MapW(name, "GetAddrInfoExW"), service, nameSpace, nspId, hints, result,
        timeout, overlapped, completion, handle);
}

static HANDLE WSAAPI Hook_WSAAsyncGetHostByName(HWND window, u_int message, const char* name, char* buffer, int length)
{
    return Real_WSAAsyncGetHostByName(window, message, MapA(name, "WSAAsyncGetHostByName"), buffer, length);
}

typedef struct
{
    const char* name;
    void*       hook;
    void**      real;
} Hook;

static Hook g_hooks[] = {
    { "gethostbyname",         (void*)Hook_gethostbyname,         (void**)&Real_gethostbyname },
    { "getaddrinfo",           (void*)Hook_getaddrinfo,           (void**)&Real_getaddrinfo },
    { "GetAddrInfoW",          (void*)Hook_GetAddrInfoW,          (void**)&Real_GetAddrInfoW },
    { "GetAddrInfoExA",        (void*)Hook_GetAddrInfoExA,        (void**)&Real_GetAddrInfoExA },
    { "GetAddrInfoExW",        (void*)Hook_GetAddrInfoExW,        (void**)&Real_GetAddrInfoExW },
    { "WSAAsyncGetHostByName", (void*)Hook_WSAAsyncGetHostByName, (void**)&Real_WSAAsyncGetHostByName },
};

#define HOOK_COUNT (sizeof(g_hooks) / sizeof(g_hooks[0]))

// ---------------------------------------------------------------------------------------------
// Export and import table patching

static void WritePointer(void* slot, DWORD value)
{
    DWORD old;
    if (VirtualProtect(slot, sizeof(DWORD), PAGE_READWRITE, &old))
    {
        *(DWORD*)slot = value;
        VirtualProtect(slot, sizeof(DWORD), old, &old);
    }
}

static IMAGE_DATA_DIRECTORY* Directory(HMODULE module, int index)
{
    BYTE* base = (BYTE*)module;
    IMAGE_DOS_HEADER* dos = (IMAGE_DOS_HEADER*)base;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE)
        return NULL;
    IMAGE_NT_HEADERS32* nt = (IMAGE_NT_HEADERS32*)(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR32_MAGIC)
        return NULL;
    IMAGE_DATA_DIRECTORY* dir = &nt->OptionalHeader.DataDirectory[index];
    return dir->VirtualAddress != 0 ? dir : NULL;
}

// Points ws2_32's exports at the hooks. Export entries are RVAs; in a 32-bit process any address
// can be written as an RVA from the module base (mod 2^32).
static void PatchExports(HMODULE module)
{
    BYTE* base = (BYTE*)module;
    IMAGE_DATA_DIRECTORY* dir = Directory(module, IMAGE_DIRECTORY_ENTRY_EXPORT);
    if (dir == NULL)
        return;
    IMAGE_EXPORT_DIRECTORY* exports = (IMAGE_EXPORT_DIRECTORY*)(base + dir->VirtualAddress);
    DWORD* functions = (DWORD*)(base + exports->AddressOfFunctions);
    DWORD* names = (DWORD*)(base + exports->AddressOfNames);
    WORD* ordinals = (WORD*)(base + exports->AddressOfNameOrdinals);

    for (DWORD i = 0; i < exports->NumberOfNames; i++)
    {
        const char* name = (const char*)(base + names[i]);
        for (unsigned h = 0; h < HOOK_COUNT; h++)
        {
            if (lstrcmpA(name, g_hooks[h].name) == 0)
                WritePointer(&functions[ordinals[i]], (DWORD)((BYTE*)g_hooks[h].hook - base));
        }
    }
}

static void PatchImports(HMODULE module)
{
    if (module == g_self || g_ws2 == NULL)
        return;
    BYTE* base = (BYTE*)module;
    IMAGE_DATA_DIRECTORY* dir = Directory(module, IMAGE_DIRECTORY_ENTRY_IMPORT);
    if (dir == NULL)
        return;

    for (IMAGE_IMPORT_DESCRIPTOR* desc = (IMAGE_IMPORT_DESCRIPTOR*)(base + dir->VirtualAddress); desc->Name != 0; desc++)
    {
        for (DWORD* slot = (DWORD*)(base + desc->FirstThunk); *slot != 0; slot++)
        {
            for (unsigned h = 0; h < HOOK_COUNT; h++)
            {
                if (*g_hooks[h].real != NULL && *slot == (DWORD)*g_hooks[h].real)
                    WritePointer(slot, (DWORD)g_hooks[h].hook);
            }
        }
    }
}

typedef BOOL (WINAPI *EnumProcessModules_t)(HANDLE, HMODULE*, DWORD, LPDWORD);

static void PatchAllImports(void)
{
    EnumProcessModules_t enumModules = (EnumProcessModules_t)GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "K32EnumProcessModules");
    if (enumModules == NULL)
        return;
    HMODULE modules[1024];
    DWORD needed = 0;
    if (!enumModules(GetCurrentProcess(), modules, sizeof(modules), &needed))
        return;
    DWORD count = needed / sizeof(HMODULE);
    if (count > sizeof(modules) / sizeof(modules[0]))
        count = sizeof(modules) / sizeof(modules[0]);
    for (DWORD i = 0; i < count; i++)
        PatchImports(modules[i]);
}

// Called once ws2_32 is in the process: keep the real functions, then hook.
static void HookWs2(HMODULE ws2)
{
    if (g_ws2 != NULL)
        return;
    for (unsigned h = 0; h < HOOK_COUNT; h++)
        *g_hooks[h].real = (void*)GetProcAddress(ws2, g_hooks[h].name);
    g_ws2 = ws2;
    PatchExports(ws2);
    PatchAllImports();
    Log("hooked ws2_32");
}

// ---------------------------------------------------------------------------------------------
// DLL load notifications (ntdll, Vista and later)

typedef struct
{
    USHORT Length;
    USHORT MaximumLength;
    PWSTR  Buffer;
} LdrUnicodeString;

typedef struct
{
    ULONG                   Flags;
    const LdrUnicodeString* FullDllName;
    const LdrUnicodeString* BaseDllName;
    PVOID                   DllBase;
    ULONG                   SizeOfImage;
} LdrDllLoadedData;

#define LDR_DLL_NOTIFICATION_REASON_LOADED 1

typedef VOID (CALLBACK *LdrDllNotification_t)(ULONG, const LdrDllLoadedData*, PVOID);
typedef LONG (NTAPI *LdrRegisterDllNotification_t)(ULONG, LdrDllNotification_t, PVOID, PVOID*);

static BOOL IsWs2(const LdrUnicodeString* name)
{
    static const wchar_t ws2[] = L"ws2_32.dll";
    int len = name->Length / sizeof(wchar_t);
    return len == (int)(sizeof(ws2) / sizeof(wchar_t)) - 1 &&
        CompareStringW(LOCALE_INVARIANT, NORM_IGNORECASE, name->Buffer, len, ws2, len) == CSTR_EQUAL;
}

static VOID CALLBACK OnDllNotification(ULONG reason, const LdrDllLoadedData* data, PVOID context)
{
    (void)context;
    if (reason != LDR_DLL_NOTIFICATION_REASON_LOADED)
        return;
    if (g_ws2 == NULL && IsWs2(data->BaseDllName))
        HookWs2((HMODULE)data->DllBase);
    else
        PatchImports((HMODULE)data->DllBase);
}

// ---------------------------------------------------------------------------------------------
// Configuration

static void ReadConfig(HINSTANCE self)
{
    wchar_t dir[MAX_PATH];
    DWORD len = GetModuleFileNameW(self, dir, MAX_PATH);
    if (len == 0 || len >= MAX_PATH)
        return;
    while (len > 0 && dir[len - 1] != L'\\' && dir[len - 1] != L'/')
        len--;
    dir[len] = 0;

    wchar_t ini[MAX_PATH];
    lstrcpyW(ini, dir);
    lstrcatW(ini, L"iphlpapi.ini");
    lstrcpyW(g_logPath, dir);
    lstrcatW(g_logPath, L"iphlpapi.log");

    GetPrivateProfileStringW(L"Redirect", L"server", L"", g_serverW, 256, ini);
    WideCharToMultiByte(CP_ACP, 0, g_serverW, -1, g_server, sizeof(g_server), NULL, NULL);
    g_log = GetPrivateProfileIntW(L"Redirect", L"log", 0, ini) != 0;

    wchar_t hostsW[2048];
    GetPrivateProfileStringW(L"Redirect", L"hosts", L"ver01.ffxiv.com,account.square-enix.com,lobby01.ffxiv.com,track01.ffxiv.com",
        hostsW, 2048, ini);
    char hosts[2048];
    WideCharToMultiByte(CP_ACP, 0, hostsW, -1, hosts, sizeof(hosts), NULL, NULL);

    g_hostCount = 0;
    char* p = hosts;
    while (*p != 0 && g_hostCount < MAX_HOSTS)
    {
        while (*p == ',' || *p == ' ' || *p == '\t')
            p++;
        int n = 0;
        while (p[n] != 0 && p[n] != ',' && p[n] != ' ' && p[n] != '\t' && n < 255)
            n++;
        if (n > 0)
        {
            lstrcpynA(g_hosts[g_hostCount], p, n + 1);
            g_hostCount++;
        }
        p += n;
        while (*p != 0 && *p != ',')
            p++;
    }
}

void Redirect_Start(HINSTANCE self)
{
    g_self = self;
    InitializeCriticalSection(&g_logLock);
    ReadConfig(self);

    wchar_t exe[MAX_PATH];
    GetModuleFileNameW(NULL, exe, MAX_PATH);
    char exeA[MAX_PATH];
    WideCharToMultiByte(CP_ACP, 0, exe, -1, exeA, sizeof(exeA), NULL, NULL);
    Log("loaded into %s; server=%s, %d host(s)", exeA, g_server[0] ? g_server : "(none)", g_hostCount);

    if (g_server[0] == 0)
        return;     // nothing to redirect: plain pass-through

    LdrRegisterDllNotification_t registerNotification =
        (LdrRegisterDllNotification_t)GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "LdrRegisterDllNotification");
    if (registerNotification != NULL)
    {
        PVOID cookie;
        registerNotification(0, OnDllNotification, NULL, &cookie);
    }

    HMODULE ws2 = GetModuleHandleW(L"ws2_32.dll");
    if (ws2 != NULL)
        HookWs2(ws2);
}
