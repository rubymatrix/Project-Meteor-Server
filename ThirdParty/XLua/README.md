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
- `ObjectTranslator.Push`: `IList` (except `byte[]`) and `IDictionary` reach Lua as tables, lists
  1-based, as MoonSharp converted them. Scripts index and count them with `#`, `ipairs` and `pairs`.

The native side has its own patch for number conversion (`xlua_tointeger` / `xlua_touint` cast
deterministically); see `native/README.md`.
