# RetailRedirect: iphlpapi.dll

Points the retail client at a Meteor server without editing the hosts file or any game file.

The retail executables have these host names built in:

| Host | Used by |
|---|---|
| `ver01.ffxiv.com` | ffxivboot (version check, port 54996) |
| `account.square-enix.com` | ffxivlogin (login page, port 80) |
| `lobby01.ffxiv.com` | ffxivgame (lobby, port 54994) |
| `track01.ffxiv.com` | ffxivboot (patch tracker, port 54997; named in the retail torrents) |

ffxivboot, ffxivlogin and ffxivgame all import `iphlpapi.dll`, and Windows loads it from the
executable's folder first. This `iphlpapi.dll` passes every call through to the system one and
sends lookups of the names above to the server in `iphlpapi.ini`. Every other name resolves
normally, and nothing outside the game's processes changes.

## Install

Copy `iphlpapi.dll` and `iphlpapi.ini` next to `ffxivboot.exe`, set `server=` to the Meteor
server's address, and start `ffxivboot.exe`.

## Build

32-bit, like the game.

Windows (Visual Studio):

```
cmake -S . -B build -A Win32
cmake --build build --config Release
```

macOS or Linux (MinGW-w64):

```
cmake -S . -B build -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86 -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc
cmake --build build
```

## How it works

- `proxy.c`: one jump thunk per export, to the same function in the system `iphlpapi.dll`
  (loaded by full path). Windows' own networking DLLs import from iphlpapi as well, and they bind
  to this DLL once it is loaded, so it exports everything the system DLL does.
- `redirect.c`: hooks `gethostbyname`, `getaddrinfo`, `GetAddrInfoW`, `GetAddrInfoExA/W` and
  `WSAAsyncGetHostByName`. Each hook swaps a redirected name for the server and calls the real
  function. Hooks go into ws2_32's export table when ws2_32 loads, and into every module's import
  table at start and on each DLL load, so they reach the executables, WinHTTP (boot) and the
  WebBrowser control (login). No code is patched.
- `exports.h`, `iphlpapi.def`: the export list, from `gen_exports.py`. Regenerate it from a
  Windows install to pick up exports newer Windows versions add:
  `python gen_exports.py exports.h C:\Windows\SysWOW64\iphlpapi.dll` (inputs are merged, so
  the list only grows).

## Troubleshooting

Set `log=1` in `iphlpapi.ini`. `iphlpapi.log` then shows which processes loaded the DLL and each
name it redirected.
