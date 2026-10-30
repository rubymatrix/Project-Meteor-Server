using System.Globalization;
using System.Text;

namespace Meteor.Tools.LuaApi;

sealed record Finding(string File, int Line, string Rule, string Message, bool Error, Edit? Fix);
sealed record Edit(int Start, int Length, string Replacement);

// Checks scripts against the list of server functions (Data/lua-api) and against what LuaJIT
// accepts. Rules:
//  case        a server function spelled with different capitals (endEvent for EndEvent)
//  dot-call    a server object's method called with '.', which leaves out the object itself;
//              it must be obj:Method()
//  bit32       the bit32 library, which LuaJIT doesn't have (it has bit)
//  lua52       syntax or libraries from newer Lua versions that LuaJIT doesn't support
//  unknown     a call to a method that neither the server nor any script defines (a warning,
//              since a script can create functions while it runs)
//  require     require() of a file that doesn't exist, or whose name differs in capitals
//              (Linux, unlike macOS and Windows, treats battleUtils and battleutils as different files)
sealed class Linter
{
    static readonly HashSet<string> StringMethods = new()
    {
        "byte", "char", "dump", "find", "format", "gmatch", "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper",
    };

    readonly ApiManifest api;
    readonly HashSet<string> luaFunctions = new(StringComparer.Ordinal);
    readonly HashSet<string> luaFields = new(StringComparer.Ordinal);
    readonly Dictionary<string, List<string>> methodsByFold, membersByFold;
    // Every script by its path under Data/scripts without ".lua" (e.g. "battle/actions"), and the
    // same with capitals ignored, to suggest the right spelling.
    readonly HashSet<string> modules;
    readonly Dictionary<string, string> modulesByLowerCase;

    // modulePaths: Every script's path under Data/scripts, with / between folders.
    public Linter(ApiManifest api, IEnumerable<string> allSources, IEnumerable<string> modulePaths)
    {
        this.api = api;
        modules = modulePaths.Select(p => p.EndsWith(".lua", StringComparison.Ordinal) ? p[..^4] : p).ToHashSet(StringComparer.Ordinal);
        modulesByLowerCase = modules.GroupBy(m => m.ToLowerInvariant()).ToDictionary(g => g.Key, g => g.First());
        foreach (var src in allSources) CollectLuaNames(LuaLexer.Code(LuaLexer.Lex(src)));
        methodsByFold = Fold(api.MethodNames);
        membersByFold = Fold(api.Types.SelectMany(t => t.Members.Select(m => m.Name)));
    }

    static Dictionary<string, List<string>> Fold(IEnumerable<string> names) =>
        names.Distinct().GroupBy(FoldName).ToDictionary(g => g.Key, g => g.ToList());

    static string FoldName(string n) => n.Replace("_", "").ToLowerInvariant();

    // Collects the function and field names scripts define themselves. A call to one of
    // those is on a Lua table, not a server object, so the server-name rules leave it alone.
    void CollectLuaNames(List<Token> t)
    {
        for (int i = 0; i < t.Count; i++)
        {
            if (t[i].Is("function"))
            {
                int j = i + 1;
                string? last = null;
                while (j < t.Count && t[j].Kind == TokKind.Name)
                {
                    last = t[j].Text;
                    if (t[j + 1].Is(".") || t[j + 1].Is(":")) j += 2; else break;
                }
                if (last != null) luaFunctions.Add(last);
            }
            else if (t[i].Kind == TokKind.Name && t[i + 1].Is("="))
            {
                bool isField = i > 0 && (t[i - 1].Is(".") || t[i - 1].Is("{") || t[i - 1].Is(",") || t[i - 1].Is(";"));
                if (t[i + 2].Is("function")) luaFunctions.Add(t[i].Text);
                if (isField) luaFields.Add(t[i].Text);
            }
        }
    }

    public List<Finding> Check(string file, string src)
    {
        var all = LuaLexer.Lex(src);
        var t = LuaLexer.Code(all);
        var found = new List<Finding>();
        void Add(Token at, string rule, string msg, bool error, Edit? fix = null) => found.Add(new Finding(file, at.Line, rule, msg, error, fix));

        for (int i = 0; i < t.Count - 1; i++)
        {
            var tok = t[i];

            if (tok.Is(":") && t[i + 1].Kind == TokKind.Name && IsCallStart(t[i + 2]))
            {
                var name = t[i + 1];
                if (api.MethodNames.Contains(name.Text) || luaFunctions.Contains(name.Text) || StringMethods.Contains(name.Text))
                    continue;
                var fix = Unique(methodsByFold, name.Text);
                if (fix != null)
                    Add(name, "case", $"'{name.Text}' is '{fix}' in C#", true, new Edit(name.Start, name.Text.Length, fix));
                else
                    Add(name, "unknown", $"':{name.Text}()' is not a C# method or a script function", false);
                continue;
            }

            if (tok.Is(".") && t[i + 1].Kind == TokKind.Name && i > 0 && IsReceiverEnd(t[i - 1]))
            {
                var name = t[i + 1];
                bool call = IsCallStart(t[i + 2]);
                bool assigned = t[i + 2].Is("=");
                if (IsLibrary(t, i)) continue;

                if (call)
                {
                    string resolved = name.Text;
                    Edit? rename = null;
                    if (!api.MethodNames.Contains(name.Text) && !luaFunctions.Contains(name.Text) && !luaFields.Contains(name.Text))
                    {
                        var fix = Unique(methodsByFold, name.Text);
                        if (fix != null)
                        {
                            resolved = fix;
                            rename = new Edit(name.Start, name.Text.Length, fix);
                            Add(name, "case", $"'{name.Text}' is '{fix}' in C#", true, rename);
                        }
                    }
                    // A name that is also static on some server class still counts: scripts can't reach
                    // static methods at all. (Exempting them once hid 143 action.DoAction(...) calls.)
                    if (api.MethodNames.Contains(resolved) && !luaFunctions.Contains(resolved) && !luaFields.Contains(resolved))
                        Add(tok, "dot-call", $"instance method '{resolved}' called with '.'; use ':'", true, new Edit(tok.Start, 1, ":"));
                    else if (rename == null && char.IsUpper(resolved[0]) && !api.MethodNames.Contains(resolved) && !luaFunctions.Contains(resolved) && !luaFields.Contains(resolved) && !api.GlobalNames.Contains(resolved))
                        Add(name, "unknown", $"'.{resolved}()' is not a C# method or a script function", false);
                }
                else if (!assigned && !api.AllMemberNames.Contains(name.Text) && !luaFields.Contains(name.Text) && !luaFunctions.Contains(name.Text))
                {
                    var fix = Unique(membersByFold, name.Text);
                    if (fix != null)
                        Add(name, "case", $"'{name.Text}' is '{fix}' in C#", true, new Edit(name.Start, name.Text.Length, fix));
                }
                continue;
            }

            if (tok.Kind == TokKind.Name && tok.Text == "require" && (t[i + 1].Kind == TokKind.String || (t[i + 1].Is("(") && t[i + 2].Kind == TokKind.String)))
            {
                var mod = t[i + 1].Kind == TokKind.String ? t[i + 1] : t[i + 2];
                string name = LuaLexer.Unquote(mod);
                if (name == "bit32")
                {
                    Add(tok, "bit32", "require(\"bit32\"): LuaJIT's bit is built in", true);
                    continue;
                }
                // require turns dots into folders: "Battle.Actions" loads Battle/Actions.lua.
                string path = name.Replace('.', '/');
                if (!modules.Contains(path))
                {
                    if (modulesByLowerCase.TryGetValue(path.ToLowerInvariant(), out var real) && !name.Contains('.'))
                        Add(tok, "require", $"'{name}' is '{real}' (file names must match exactly on Linux)", true,
                            new Edit(mod.Start, mod.Text.Length, mod.Text[0] + real + mod.Text[^1]));
                    else
                        Add(tok, "require", $"no script named '{name}'", true);
                }
                continue;
            }

            if (tok.Kind == TokKind.Name && tok.Text == "bit32" && t[i + 1].Is("."))
            {
                var folded = FoldBit32(t, i, out int endIdx);
                if (folded != null)
                    Add(tok, "bit32", $"constant {Src(src, tok.Start, t[endIdx].End)} is {folded}", true, new Edit(tok.Start, t[endIdx].End - tok.Start, folded));
                else
                    Add(tok, "bit32", "bit32 is Lua 5.2; use LuaJIT's bit (signed: add % 2^32 where a value can reach bit 31)", true);
                continue;
            }

            // LuaJIT rejects a call whose "(" starts on the next line, as in "f" then "(args)".
            if (tok.Is("(") && i > 0 && t[i - 1].Line < tok.Line && (t[i - 1].Kind == TokKind.Name || t[i - 1].Is(")") || t[i - 1].Is("]")))
            {
                var prev = t[i - 1];
                bool onlySpace = string.IsNullOrWhiteSpace(src[prev.End..tok.Start]);
                Add(tok, "lua52", "call's '(' starts a new line; LuaJIT reads that as ambiguous", true,
                    onlySpace ? new Edit(prev.End, tok.Start - prev.End, "") : null);
                continue;
            }

            if (tok.Kind == TokKind.Op && (tok.Text is "//" or "&" or "|" or "<<" or ">>" || (tok.Text == "~" && !t[i + 1].Is("="))))
                Add(tok, "lua52", $"operator '{tok.Text}' is Lua 5.3; LuaJIT has bit.* functions", true);
            else if (tok.Kind == TokKind.Name && tok.Text == "_ENV")
                Add(tok, "lua52", "_ENV is Lua 5.2; LuaJIT uses setfenv", true);
            else if (tok.Kind == TokKind.Name && (tok.Text is "table" or "utf8") && t[i + 1].Is(".") && (tok.Text == "utf8" || t[i + 2].Text is "pack" or "unpack"))
                Add(tok, "lua52", $"{tok.Text}.{t[i + 2].Text} is not in LuaJIT", true);
        }
        return found;
    }

    static string Src(string s, int a, int b) => s[a..b];

    static bool IsCallStart(Token t) => t.Is("(") || t.Is("{") || t.Kind == TokKind.String;

    static bool IsReceiverEnd(Token t) => t.Kind == TokKind.Name || t.Is(")") || t.Is("]");

    // True for a.b where a is one of Lua's own libraries (string.format, math.floor, ...).
    static bool IsLibrary(List<Token> t, int dot)
    {
        var recv = t[dot - 1];
        if (recv.Kind != TokKind.Name) return false;
        if (dot >= 2 && (t[dot - 2].Is(".") || t[dot - 2].Is(":"))) return false;
        return recv.Text is "string" or "math" or "table" or "os" or "io" or "coroutine" or "debug" or "bit" or "bit32" or "jit" or "package";
    }

    static string? Unique(Dictionary<string, List<string>> folded, string name)
    {
        if (!folded.TryGetValue(FoldName(name), out var c)) return null;
        var others = c.Where(x => x != name).ToList();
        return others.Count == 1 ? others[0] : null;
    }

    // Works out bit32.f(n, m, ...) when every argument is a plain number, and returns the
    // result as a hex number (e.g. bit32.lshift(1, 4) becomes 0x10). Null when it can't.
    static string? FoldBit32(List<Token> t, int i, out int endIdx)
    {
        endIdx = i;
        if (t[i + 2].Kind != TokKind.Name || !t[i + 3].Is("(")) return null;
        string fn = t[i + 2].Text;
        var args = new List<ulong>();
        int j = i + 4;
        while (true)
        {
            bool neg = false;
            if (t[j].Is("-")) { neg = true; j++; }
            if (t[j].Kind != TokKind.Number || !TryNum(t[j].Text, out double d) || d != Math.Floor(d)) return null;
            args.Add(unchecked((ulong)(long)(neg ? -d : d)) & 0xFFFFFFFF);
            j++;
            if (t[j].Is(",")) { j++; continue; }
            if (t[j].Is(")")) break;
            return null;
        }
        uint r;
        switch (fn)
        {
            case "lshift" when args.Count == 2: r = args[1] >= 32 ? 0 : (uint)(args[0] << (int)args[1]); break;
            case "rshift" when args.Count == 2: r = args[1] >= 32 ? 0 : (uint)(args[0] >> (int)args[1]); break;
            case "bor": r = (uint)args.Aggregate(0UL, (a, b) => a | b); break;
            case "band": r = (uint)args.Aggregate(0xFFFFFFFFUL, (a, b) => a & b); break;
            case "bxor": r = (uint)args.Aggregate(0UL, (a, b) => a ^ b); break;
            case "bnot" when args.Count == 1: r = ~(uint)args[0]; break;
            default: return null;
        }
        endIdx = j;
        return "0x" + r.ToString("X", CultureInfo.InvariantCulture);
    }

    static bool TryNum(string s, out double d)
    {
        if (s.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
        {
            bool ok = ulong.TryParse(s[2..], NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var u);
            d = u;
            return ok;
        }
        return double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out d);
    }

    public static string Apply(string src, IEnumerable<Edit> edits)
    {
        var sb = new StringBuilder(src);
        int lastStart = int.MaxValue;
        foreach (var e in edits.Distinct().OrderByDescending(e => e.Start))
        {
            if (e.Start + e.Length > lastStart) continue; // two fixes for the same text: keep one
            sb.Remove(e.Start, e.Length).Insert(e.Start, e.Replacement);
            lastStart = e.Start;
        }
        return sb.ToString();
    }
}
