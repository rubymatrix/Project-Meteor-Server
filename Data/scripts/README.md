# Writing scripts

The map server runs these scripts on **LuaJIT** (Lua 5.1 with LuaJIT's extensions) through xLua.
C# objects reach scripts by reflection: what a script can call is the public API of the map
server's types, listed in `Data/lua-api/manifest.json` and, for editors, `Data/lua-api/meteor.d.lua`.

## Rules

1. **Lua 5.1 as LuaJIT runs it.** `goto`, `bit` and LuaJIT's `string`/`math`/`table` libraries are
   available. Lua 5.2+ features are not: `_ENV`, `bit32`, `//`, `&`, `|`, `~`, `<<`, `>>`,
   `table.pack`, `table.unpack` (use `unpack`), `utf8`.
2. **C# names exactly as declared.** `player:EndEvent()`, not `player:endEvent()`. Names are case
   sensitive and nothing maps one spelling to another.
3. **`:` for instance methods, `.` for fields, properties and statics.** `effect:GetMagnitude()`;
   `player.charaWork`; `effect.GetMagnitude()` passes no object and fails.
4. **Flags as hex literals**, e.g. `0x80000000`. `bit` is signed: where a computed value can reach
   bit 31 and goes to C# as a `uint`, reduce it with `% 0x100000000`.
5. **Don't start a call's `(` on a new line.** Lua 5.1 rejects `f\n(...)` as ambiguous.
6. **Wait only through `global.lua`:** `wait(seconds)`, `waitForSignal(name)`,
   `callClientFunction(...)`, `kickEvent(...)`. Don't yield from code that C# called directly
   (a hook run with a plain call, a director's `init`).
7. **Don't depend on `pairs()` order.** It is unspecified; sort the keys when order matters.

## How values cross

- Lua numbers to C# integers truncate toward zero and saturate for `int`/`uint` (`-1` gives
  `uint` 0, `3e9` gives `int.MaxValue`); `byte`/`short` wrap. To `object` parameters a number is a
  `double`.
- C# arrays, lists and dictionaries stay C# objects: index them from 0 (`state_mainSkill[0]`), and
  use `.Length` (arrays) or `.Count` (lists, dictionaries), not `#` or `ipairs`.
- C# strings arrive as UTF-8: `#` counts bytes.
- Each script file runs in its own global environment with its own `require` cache, as before.

## Checks

From the repository root:

```bash
dotnet run --project tools/LuaApi -- lint
```

reports rule violations (`fix` applies the mechanical ones). After changing C# that scripts use:

```bash
dotnet run --project tools/LuaApi -- manifest
```

and commit `Data/lua-api`. CI fails when the manifest is stale or lint finds an error.
`dotnet test "tests/Map Server Tests"` loads every script and runs the engine checks.

Editors with lua-language-server pick up `.luarc.json` here for completion against the C# API.
