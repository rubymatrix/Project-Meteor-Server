# xLua (vendored C# runtime)

- Upstream: https://github.com/Tencent/xLua, commit `59bf42685dbe36fe0e1678a6ba8597f859ef7ca3`
- License: MIT (`LICENSE.TXT`)
- Files: `Assets/XLua/Src/*.cs` and `Assets/XLua/Src/TemplateEngine/TemplateEngine.cs`, built with
  `XLUA_GENERAL` (no Unity). Editor tooling, code generation and hotfix injection are not included;
  the map server binds C# by reflection.

## Local changes

Every change is marked `// Meteor:` in the source.

- `ObjectCasters.getObject`: a Lua number passed to an `object` parameter is always a `double`
  (xLua returned `int` for whole numbers). MoonSharp did the same.
- `ObjectTranslator.PushAny`, the typed `byte[]` push and `CodeEmit`'s fixed push/cast tables: a `byte[]` reaches Lua as the C# array
  (indexed from 0, like every other C# array) instead of as a Lua string. Scripts index arrays such
  as `parameterSave.state_mainSkill[0]`.

The native side has its own patch for number conversion (`xlua_tointeger` / `xlua_touint` cast
deterministically); see `native/README.md`.
