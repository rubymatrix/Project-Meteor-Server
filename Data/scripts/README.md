# Writing scripts

The map server runs these scripts with **LuaJIT**, a fast version of Lua 5.1. Scripts can call
the server's own objects and functions (players, NPCs, zones, ...). The full list of what they can
call is in `Data/lua-api/manifest.json`; `Data/lua-api/meteor.d.lua` is the same list for editors.

## Rules

1. **Write Lua 5.1, as LuaJIT runs it.** `goto` and the `bit` library are available. Features from
   newer Lua versions are not: `_ENV`, `bit32`, the operators `//`, `&`, `|`, `~`, `<<` and `>>`,
   `table.pack`, `table.unpack` (use `unpack`) and `utf8`.
2. **Spell server names exactly as the server does, capitals included.** `player:EndEvent()`
   works; `player:endEvent()` doesn't.
3. **Call an object's methods with `:`.** `effect:GetMagnitude()`. Use `.` only to read or set a
   value, as in `player.charaWork`. `effect.GetMagnitude()` doesn't pass `effect` along, and fails.
4. **Write flag values as hex numbers**, e.g. `0x80000000`. LuaJIT's `bit` functions can return
   negative numbers for values at or above `0x80000000`; when such a value goes to the server, add
   `% 0x100000000` to make it positive.
5. **Keep a call's `(` on the same line as the function name.** LuaJIT rejects `f` on one line
   followed by `(...)` on the next.
6. **To wait, use the functions in `global.lua`:** `wait(seconds)`, `waitForSignal(name)`,
   `callClientFunction(...)` and `kickEvent(...)`. Only wait in code the server started as an
   event or command; a function the server calls for a quick answer (a battle formula, a
   director's `init`) can't wait.
7. **Don't rely on the order `pairs()` visits a table in.** It can change; sort the keys when the
   order matters.

## How values pass between scripts and the server

- A Lua number passed to a server function that wants a whole number loses its fraction (2.7
  becomes 2). Numbers that are too big or too small for an `int` or `uint` become the largest or
  smallest allowed value (`-1` becomes `0` for a `uint`).
- Arrays and lists from the server stay as they are: count positions from 0 (`state_mainSkill[0]`)
  and use `.Length` (arrays) or `.Count` (lists) for their size. `#` and `ipairs` don't work on them.
- Text with accented letters: `#` counts bytes, so `#"é"` is 2.
- Every script file has its own global variables, and so do the files it loads with `require`.
  Two scripts never see each other's globals.

## Checks

From the repository root, this lists any rule broken (add `fix` instead of `lint` to correct the
ones with an automatic fix):

```bash
dotnet run --project tools/LuaApi -- lint
```

After changing server code that scripts use, refresh the list of server functions and commit
`Data/lua-api`:

```bash
dotnet run --project tools/LuaApi -- manifest
```

The automated build (CI) fails if that list is out of date or the checks above find an error.
`dotnet test "tests/Map Server Tests"` loads every script and runs the script-engine tests.

Editors that use lua-language-server read `.luarc.json` in this folder and can then autocomplete
server functions.
