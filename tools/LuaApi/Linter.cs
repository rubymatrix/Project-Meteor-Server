using System.Globalization;
using System.Text;

namespace Meteor.Tools.LuaApi;

sealed record Finding(string File, int Line, string Rule, string Message, bool Error, Edit? Fix);
sealed record Edit(int Start, int Length, string Replacement);

/// <summary>
/// Checks scripts against the C# API manifest and the LuaJIT language level. Rules:
///  case        member spelled differently from C# (MoonSharp matched endEvent to EndEvent; xLua does not)
///  dot-call    instance method called with '.', which passes no self under xLua
///  bit32       Lua 5.2 bit32 library; LuaJIT has `bit`, which is signed
///  lua52       syntax or libraries LuaJIT lacks (_ENV, //, bitwise operators, table.pack/unpack, utf8)
///  unknown     ':' call to a name neither C# nor any script defines (warning: may be dynamic)
/// </summary>
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

    public Linter(ApiManifest api, IEnumerable<string> allSources)
    {
        this.api = api;
        foreach (var src in allSources) CollectLuaNames(LuaLexer.Code(LuaLexer.Lex(src)));
        methodsByFold = Fold(api.MethodNames);
        membersByFold = Fold(api.Types.SelectMany(t => t.Members.Select(m => m.Name)));
    }

    static Dictionary<string, List<string>> Fold(IEnumerable<string> names) =>
        names.Distinct().GroupBy(FoldName).ToDictionary(g => g.Key, g => g.ToList());

    static string FoldName(string n) => n.Replace("_", "").ToLowerInvariant();

    /// <summary>Names scripts define themselves (functions and table fields), so a ':'/'.' use of them
    /// is a Lua table, not a C# object.</summary>
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
                    if (api.MethodNames.Contains(resolved) && !api.StaticNames.Contains(resolved) && !luaFunctions.Contains(resolved) && !luaFields.Contains(resolved))
                        Add(tok, "dot-call", $"instance method '{resolved}' called with '.'; use ':'", true, new Edit(tok.Start, 1, ":"));
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
                if (LuaLexer.Unquote(mod) == "bit32")
                    Add(tok, "bit32", "require(\"bit32\"): LuaJIT's bit is built in", true);
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

            // Lua 5.1 rejects `f\n(args)` as ambiguous; 5.2 reads it as a call.
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

    /// <summary>a.b where a is a standard library table (string.format, math.floor, ...).</summary>
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

    /// <summary>Folds bit32.f(n, m, ...) with literal number arguments to a hex literal. bit32 results
    /// are unsigned 32-bit, so the literal is too.</summary>
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
            if (e.Start + e.Length > lastStart) continue; // overlapping edit: keep the later one
            sb.Remove(e.Start, e.Length).Insert(e.Start, e.Replacement);
            lastStart = e.Start;
        }
        return sb.ToString();
    }
}
