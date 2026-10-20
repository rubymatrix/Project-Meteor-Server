# native: the Lua library

The map server runs its scripts with [LuaJIT](https://luajit.org) through
[xLua](https://github.com/Tencent/xLua). This folder builds the C part of that into one library
file: `libxlua.dylib` (macOS), `libxlua.so` (Linux) or `xlua.dll` (Windows). The C# part of xLua
is in `ThirdParty/XLua`.

| Part | Where it comes from | Version |
|---|---|---|
| `xlua/xlua.c`, `xlua/i64lib.c`, `xlua/i64lib.h` | xLua's `build/` folder (MIT license, `xlua/LICENSE.txt`) | commit `59bf42685dbe36fe0e1678a6ba8597f859ef7ca3`, with one change (below) |
| LuaJIT 2.1 | downloaded during the build | the commit and checksum set in `CMakeLists.txt` |

## Our change to xlua.c

Marked `/* Meteor: */`. When a script passes a number to a server function that takes a whole
number (`int` or `uint`), the conversion now gives the same answer on every machine: fractions
are dropped, and numbers out of range become the smallest or largest allowed value (for `uint`,
anything below 0 becomes 0). Plain C gives different answers on Intel and ARM processors for
numbers out of range. This is also how the old engine (MoonSharp) behaved. The quick check
(`smoke/`) tests it.

## Building

On Windows, run these from a Visual Studio "x64 Native Tools" command prompt.

```
cmake -S native -B native/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build native/build
ctest --test-dir native/build --output-on-failure
```

The library is written to `native/runtimes/<platform>/native/`, and building the map server copies
it next to the server. The last command runs the quick check: it loads the library, makes sure it
contains every function the server calls (`smoke/exports.txt`), and runs `smoke/smoke.lua`.

Options: `-DXLUA_RID=<platform>` to name the platform, `-DLUAJIT_SOURCE_DIR=<folder>` to build
from a local copy of LuaJIT instead of downloading it, `-DXLUA_LUA52COMPAT=ON` to turn on
LuaJIT's extra Lua 5.2 features.

## Updating

- **LuaJIT:** change `LUAJIT_COMMIT` in `CMakeLists.txt`, download
  `https://github.com/LuaJIT/LuaJIT/archive/<commit>.tar.gz` and put its SHA256 checksum in
  `LUAJIT_SHA256`.
- **xLua:** copy the new `xlua.c`, `i64lib.c` and `i64lib.h`, put our change back in, and update
  `smoke/exports.txt` to match the functions declared in `ThirdParty/XLua/Src/LuaDLL.cs`
  (leaving out `luaopen_socket_core`; the socket library isn't built).
