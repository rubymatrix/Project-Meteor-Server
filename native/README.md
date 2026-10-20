# native: xlua library

The map server's Lua runtime: [xLua](https://github.com/Tencent/xLua)'s C glue linked against a
static LuaJIT 2.1 (GC64) into one shared library, `libxlua.dylib` / `libxlua.so` / `xlua.dll`.

| Part | Source | Pin |
|---|---|---|
| `xlua/xlua.c`, `xlua/i64lib.{c,h}` | Tencent/xLua `build/` (MIT, `xlua/LICENSE.txt`) | `59bf42685dbe36fe0e1678a6ba8597f859ef7ca3`, unmodified |
| LuaJIT | LuaJIT/LuaJIT `v2.1`, downloaded at configure time | commit and SHA256 in `CMakeLists.txt` |

Build (Windows: from a VS x64 developer prompt, `-G "NMake Makefiles"` or Ninja):

```
cmake -S native -B native/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build native/build
ctest --test-dir native/build --output-on-failure
```

The library lands in `runtimes/<rid>/native/`; `Map Server.csproj` copies the one for the
build machine (or for `-r <rid>`) next to the server binary. Options: `-DXLUA_RID=<rid>`,
`-DLUAJIT_SOURCE_DIR=<checkout>` (offline), `-DXLUA_LUA52COMPAT=ON`.

The smoke test resolves every entry point in `smoke/exports.txt` (the `DllImport`s of xLua's
`LuaDLL.cs`, minus `luaopen_socket_core`: luasocket is not built), then runs `smoke/smoke.lua`.
Regenerate `exports.txt` when updating xLua's C# sources.

To move LuaJIT: change `LUAJIT_COMMIT`, download
`https://github.com/LuaJIT/LuaJIT/archive/<commit>.tar.gz`, put its SHA256 in `LUAJIT_SHA256`.
