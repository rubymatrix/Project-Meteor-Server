# xLua (C# part, copied into this repository)

The C# half of [xLua](https://github.com/Tencent/xLua), which lets the server run Lua scripts on
LuaJIT. The C half is built from `native/`.

- Copied from commit `59bf42685dbe36fe0e1678a6ba8597f859ef7ca3`, license MIT (`LICENSE.TXT`).
- Files: `Assets/XLua/Src/*.cs` and `Assets/XLua/Src/TemplateEngine/TemplateEngine.cs`, built
  without Unity (`XLUA_GENERAL`). xLua's Unity editor tools and code generator are not included:
  the server's classes are made available to scripts automatically, without generated code.

## Local changes

Each change is marked with a `// Meteor:` comment in the source.

- A number passed from Lua to a C# parameter that accepts any type (`object`) always arrives as a
  `double` (`ObjectCasters.getObject`). xLua used to send whole numbers as `int`.
- A `byte[]` is passed to Lua as the array itself, indexed from 0 like every other C# array,
  instead of as text (`ObjectTranslator.PushAny`, its typed `byte[]` push, and `CodeEmit`'s fixed
  tables). Scripts read arrays such as `parameterSave.state_mainSkill[0]`.

The C part of xLua has one change of its own, for turning Lua numbers into C# integers the same
way on every platform; see `native/README.md`.
