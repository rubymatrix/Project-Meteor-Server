using System.Text;
using System.Text.RegularExpressions;

namespace Meteor.Tools.LuaApi;

// The rules from Data/Docs/lua-style.md that need a script's scopes or the other scripts:
//  naming     a name a script declares in snake_case or with an all-caps acronym (messageID)
//  global     a global nothing outside its file reaches: no server callback, no C# lookup by name,
//             no script that shares its globals through require
//  header     the file's --[[ ]] description sits above its requires, or a file of 30 or more
//             lines of code has none (a short script named after its client class needs none)
//  comment    a comment longer than four lines
//  banner     a section-divider comment
//  restate    a comment above a declaration that repeats its name or parameters (a warning:
//             the check is a guess)
//  quest-map  a quest's onTalk, onPush, onEmote or onNotice that branches on the sequence with
//             if/elseif instead of a handler table
sealed partial class Conventions
{
    const int MaxCommentLines = 4;
    const int MinDescribedLines = 30;

    sealed record GlobalDef(Token Name, bool Function, bool TopLevel, int FunctionToken, bool Listed = false);

    sealed class Script
    {
        public required string Path;
        public required string Src;
        public required List<Token> All;
        public required List<Token> Code;
        public readonly List<string> Requires = new();
        public readonly List<(Token Name, string Kind)> Declared = new();
        public readonly List<GlobalDef> Globals = new();
        // Global names the file reads or writes, with the source position of each use.
        public readonly Dictionary<string, List<int>> GlobalUses = new(StringComparer.Ordinal);
        public readonly List<(Token Name, int From, int To)> Callbacks = new();
        // Each global use with the function it sits in (null at the top level) and whether it is an
        // assignment straight in that function's body.
        public readonly Dictionary<string, List<(int At, Frame? Function, bool Write, bool BodyWrite)>> UsesByFunction = new(StringComparer.Ordinal);
    }

    readonly ApiManifest api;
    readonly HashSet<string> serverNames;
    readonly Dictionary<string, Script> scripts = new(StringComparer.Ordinal);
    readonly Dictionary<string, HashSet<string>> sharing = new(StringComparer.Ordinal);

    // sources: every script by its path under Data/scripts ("Quest/Man/Man206.lua").
    // serverNames: every string the C# code spells out; a script name in one can be looked up by it.
    public Conventions(ApiManifest api, IReadOnlyDictionary<string, string> sources, HashSet<string> serverNames)
    {
        this.api = api;
        this.serverNames = serverNames;
        foreach (var (path, src) in sources)
        {
            var all = LuaLexer.Lex(src);
            var s = new Script { Path = path, Src = src, All = all, Code = LuaLexer.Code(all) };
            Walk(s);
            scripts[path] = s;
        }
        ShareGlobals();
    }

    static string Module(string path) => path.EndsWith(".lua", StringComparison.Ordinal) ? path[..^4] : path;

    static bool IsLibrary(string path) => !path.Contains('/') || path.StartsWith("Battle/", StringComparison.Ordinal);

    static bool InRuntime(string path) => path.StartsWith("Ai/", StringComparison.Ordinal) || path.StartsWith("Content/", StringComparison.Ordinal);

    // Which scripts can read each script's globals. require runs a file in the caller's globals, so a
    // file shares them with everything loaded alongside it from any script that requires it. The AI
    // runtime's modules all read the runtime's globals and a module without a return value hands its
    // globals to its users, so Ai/ and Content/ count as one.
    void ShareGlobals()
    {
        var byModule = scripts.Values.ToDictionary(s => Module(s.Path), s => s.Path, StringComparer.Ordinal);
        var requires = scripts.Values.ToDictionary(s => s.Path,
            s => s.Requires.Select(r => byModule.GetValueOrDefault(r.Replace('.', '/'))).OfType<string>().ToList(), StringComparer.Ordinal);
        var requiredBy = scripts.Keys.ToDictionary(p => p, _ => new List<string>(), StringComparer.Ordinal);
        foreach (var (p, rs) in requires) foreach (var r in rs) requiredBy[r].Add(p);

        HashSet<string> Reach(string from, Dictionary<string, List<string>> edges)
        {
            var seen = new HashSet<string>(StringComparer.Ordinal) { from };
            var todo = new Stack<string>(seen);
            while (todo.Count > 0)
                foreach (var n in edges[todo.Pop()])
                    if (seen.Add(n)) todo.Push(n);
            return seen;
        }

        var loads = scripts.Keys.ToDictionary(p => p, p => Reach(p, requires), StringComparer.Ordinal);
        var runtime = scripts.Keys.Where(InRuntime).ToHashSet(StringComparer.Ordinal);
        foreach (var p in scripts.Keys)
        {
            var set = new HashSet<string>(StringComparer.Ordinal);
            foreach (var root in Reach(p, requiredBy)) set.UnionWith(loads[root]);
            if (InRuntime(p)) set.UnionWith(runtime);
            sharing[p] = set;
        }
    }

    static readonly HashSet<string> BlockOpen = new() { "function", "if", "do", "repeat" };

    internal sealed class Frame
    {
        public required char Kind; // 'b' block, '{' table, '(' parens, '[' index
        public HashSet<string>? Locals;
        public int Start;
        public Token? Callback;
        public bool Function;
        // Where the function's body starts in the source: just after its parameter list.
        public int Body;
    }

    // One pass over the tokens: tracks blocks, locals and table constructors well enough to tell
    // declarations, table fields, local uses and global uses apart.
    void Walk(Script s)
    {
        var t = s.Code;
        var stack = new List<Frame> { new() { Kind = 'b', Locals = new(StringComparer.Ordinal) } };
        List<Token>? pendingFor = null;
        int depth = 0; // open blocks above the file's own

        bool IsLocal(string n)
        {
            for (int k = stack.Count - 1; k >= 0; k--)
                if (stack[k].Locals?.Contains(n) == true) return true;
            return false;
        }
        HashSet<string> Scope()
        {
            for (int k = stack.Count - 1; k >= 0; k--)
                if (stack[k].Locals != null) return stack[k].Locals!;
            throw new InvalidOperationException();
        }
        void Declare(Token n, string kind)
        {
            Scope().Add(n.Text);
            s.Declared.Add((n, kind));
        }
        void Use(Token n, bool write = false)
        {
            if (IsLocal(n.Text)) return;
            if (!s.GlobalUses.TryGetValue(n.Text, out var at)) s.GlobalUses[n.Text] = at = new();
            at.Add(n.Start);
            Frame? fn = null;
            for (int k = stack.Count - 1; k >= 0 && fn == null; k--)
                if (stack[k].Function) fn = stack[k];
            if (!s.UsesByFunction.TryGetValue(n.Text, out var uses)) s.UsesByFunction[n.Text] = uses = new();
            uses.Add((n.Start, fn, write, write && fn != null && stack[^1] == fn));
        }
        // Reads "(a, b, ...)" from i (the "(") and opens the function's block with them as locals.
        int OpenFunction(int i, int functionTok, bool method, Token? callback)
        {
            var frame = new Frame { Kind = 'b', Locals = new(StringComparer.Ordinal), Start = functionTok, Callback = callback, Function = true };
            if (method) frame.Locals.Add("self");
            stack.Add(frame);
            depth++;
            if (!t[i].Is("(")) return i;
            i++;
            while (i < t.Count && !t[i].Is(")"))
            {
                if (t[i].Kind == TokKind.Name) Declare(t[i], "parameter");
                i++;
            }
            frame.Body = t[i].End;
            return i;
        }

        for (int i = 0; i < t.Count; i++)
        {
            var tok = t[i];
            var prev = i > 0 ? t[i - 1] : null;
            var top = stack[^1];

            if (tok.Kind == TokKind.Name && tok.Text == "require" && (t[i + 1].Kind == TokKind.String || (t[i + 1].Is("(") && t[i + 2].Kind == TokKind.String)))
                s.Requires.Add(LuaLexer.Unquote(t[i + 1].Kind == TokKind.String ? t[i + 1] : t[i + 2]));

            if (tok.Is("local"))
            {
                if (t[i + 1].Is("function"))
                {
                    Declare(t[i + 2], "local function");
                    i = OpenFunction(i + 3, i + 1, false, null);
                    continue;
                }
                int j = i + 1;
                var names = new List<Token>();
                while (t[j].Kind == TokKind.Name)
                {
                    names.Add(t[j]);
                    if (!t[j + 1].Is(",")) break;
                    j += 2;
                }
                foreach (var n in names) Declare(n, "local");
                i = j;
                continue;
            }

            if (tok.Is("function"))
            {
                if (t[i + 1].Kind != TokKind.Name)
                {
                    i = OpenFunction(i + 1, i, false, null);
                    continue;
                }
                int j = i + 1;
                var path = new List<Token> { t[j] };
                bool method = false;
                while (t[j + 1].Is(".") || t[j + 1].Is(":"))
                {
                    method = t[j + 1].Is(":");
                    j += 2;
                    path.Add(t[j]);
                }
                Token? callback = null;
                if (path.Count == 1)
                {
                    var n = path[0];
                    if (IsLocal(n.Text)) Use(n);
                    else
                    {
                        s.Declared.Add((n, "function"));
                        s.Globals.Add(new GlobalDef(n, true, depth == 0, i));
                        Use(n);
                        if (depth == 0) callback = n;
                    }
                }
                else
                {
                    Use(path[0]);
                    s.Declared.Add((path[^1], "field"));
                }
                i = OpenFunction(j + 1, i, method, callback);
                continue;
            }

            if (tok.Is("for"))
            {
                pendingFor = new();
                int j = i + 1;
                while (t[j].Kind == TokKind.Name)
                {
                    pendingFor.Add(t[j]);
                    if (!t[j + 1].Is(",")) break;
                    j += 2;
                }
                i = j;
                continue;
            }

            if (tok.Kind == TokKind.Keyword && BlockOpen.Contains(tok.Text))
            {
                var frame = new Frame { Kind = 'b', Locals = new(StringComparer.Ordinal), Start = i };
                stack.Add(frame);
                depth++;
                if (tok.Is("do") && pendingFor != null)
                {
                    foreach (var n in pendingFor) Declare(n, "loop variable");
                    pendingFor = null;
                }
                continue;
            }
            if (tok.Is("end") || tok.Is("until"))
            {
                if (stack.Count > 1 && stack[^1].Kind == 'b')
                {
                    var closed = stack[^1];
                    stack.RemoveAt(stack.Count - 1);
                    depth--;
                    if (closed.Callback != null) s.Callbacks.Add((closed.Callback, closed.Start, i));
                }
                continue;
            }
            if (tok.Is("{") || tok.Is("(") || tok.Is("["))
            {
                stack.Add(new Frame { Kind = tok.Text[0] });
                continue;
            }
            if (tok.Is("}") || tok.Is(")") || tok.Is("]"))
            {
                if (stack.Count > 1 && stack[^1].Kind != 'b') stack.RemoveAt(stack.Count - 1);
                continue;
            }

            if (tok.Kind != TokKind.Name) continue;
            if (prev != null && (prev.Is(".") || prev.Is(":") || prev.Is("goto") || prev.Is("::"))) continue;

            bool assigns = t[i + 1].Is("=");
            if (top.Kind == '{' && assigns && prev != null && (prev.Is("{") || prev.Is(",") || prev.Is(";")))
            {
                s.Declared.Add((tok, "field"));
                continue;
            }
            if (top.Kind == 'b' && assigns && !IsLocal(tok.Text))
            {
                s.Declared.Add((tok, "global"));
                s.Globals.Add(new GlobalDef(tok, false, depth == 0, -1, prev != null && prev.Is(",")));
                Use(tok, !(prev != null && prev.Is(",")));
                continue;
            }
            Use(tok);
        }
    }

    public List<Finding> Check(string scriptPath, string file)
    {
        var s = scripts[scriptPath];
        var found = new List<Finding>();
        void Add(int line, string rule, string msg, bool error, Edit? fix = null) => found.Add(new Finding(file, line, rule, msg, error, fix));

        CheckNames(s, Add);
        CheckGlobals(s, found, file);
        CheckComments(s, Add);
        if (scriptPath.StartsWith("Quest/", StringComparison.Ordinal)) CheckQuestMaps(s, Add);
        return found;
    }

    // Names the server or the client owns, which keep their spelling.
    bool ServerOwned(string n) =>
        n.StartsWith("rt_", StringComparison.Ordinal) || serverNames.Contains(n)
        || api.MethodNames.Contains(n) || api.AllMemberNames.Contains(n) || api.GlobalNames.Contains(n);

    // Server callbacks, Encounter phase handlers (self["phase_" .. name]) and the client's own
    // event function names (processEvent001_3).
    static bool IsCallback(string n) =>
        n is "init" or "main" or "properties" || OnHook().IsMatch(n)
        || n.StartsWith("phase_", StringComparison.Ordinal) || n.StartsWith("processEvent", StringComparison.Ordinal);

    [GeneratedRegex("^on[A-Z][A-Za-z0-9]*$")] private static partial Regex OnHook();
    [GeneratedRegex("^_*[A-Z][A-Z0-9_]*$")] private static partial Regex UpperSnake();
    [GeneratedRegex("[A-Z]{2}")] private static partial Regex Acronym();

    // camelCase for a snake_case or acronym name: player_x -> playerX, messageID -> messageId,
    // AddGCSeals -> AddGcSeals. Null when the name is fine.
    public static string? Restyle(string n)
    {
        if (n == "_" || n.StartsWith('_') || UpperSnake().IsMatch(n)) return null;
        string fixedName = n;
        if (n.Contains('_'))
        {
            var parts = n.Split('_', StringSplitOptions.RemoveEmptyEntries);
            fixedName = parts[0] + string.Concat(parts.Skip(1).Select(p => char.ToUpperInvariant(p[0]) + p[1..]));
        }
        if (Acronym().IsMatch(fixedName))
        {
            var sb = new StringBuilder();
            for (int k = 0; k < fixedName.Length; k++)
            {
                char c = fixedName[k];
                bool upperRun = k > 0 && char.IsUpper(fixedName[k - 1]) && char.IsUpper(c);
                bool startsWord = k + 1 < fixedName.Length && char.IsLower(fixedName[k + 1]);
                sb.Append(upperRun && !startsWord ? char.ToLowerInvariant(c) : c);
            }
            fixedName = sb.ToString();
        }
        return fixedName == n ? null : fixedName;
    }

    void CheckNames(Script s, Action<int, string, string, bool, Edit?> add)
    {
        var seen = new HashSet<(int, string)>();
        foreach (var (name, kind) in s.Declared)
        {
            if (ServerOwned(name.Text) || IsCallback(name.Text)) continue;
            var better = Restyle(name.Text);
            if (better == null || !seen.Add((name.Line, name.Text))) continue;
            add(name.Line, "naming", $"{kind} '{name.Text}' is '{better}': camelCase, acronyms as words", true, null);
        }
    }

    void CheckGlobals(Script s, List<Finding> found, string file)
    {
        var reported = new HashSet<string>(StringComparer.Ordinal);
        var forward = new List<string>();
        var edits = new List<Edit>();
        foreach (var g in s.Globals)
        {
            string n = g.Name.Text;
            if (!reported.Add(n) || IsCallback(n) || ServerOwned(n)) continue;
            // A shared file's constants and enum tables are its vocabulary (GiveItem even looks
            // constants up by name).
            if (IsLibrary(s.Path) && char.IsUpper(n[0])) continue;
            if (sharing[s.Path].Any(other => other != s.Path && scripts[other].GlobalUses.ContainsKey(n))) continue;

            bool usedHere = s.GlobalUses[n].Count > 1 || !g.Function;
            var defs = s.Globals.Where(x => x.Name.Text == n).ToList();
            Edit? fix = null;
            if (defs.All(d => d.TopLevel))
            {
                int first = defs[0].Name.Start;
                bool early = s.GlobalUses[n].Any(at => at < first);
                if (defs.Count == 1 && g.Function && !early)
                    fix = new Edit(s.Code[g.FunctionToken].Start, 0, "local ");
                else if (defs.Count == 1 && !g.Function && !g.Listed && !early)
                    fix = new Edit(g.Name.Start, 0, "local ");
                else
                    forward.Add(n);
            }
            else
                fix = LocalInFunctions(s, n);
            string why = usedHere ? "only this file uses it" : "nothing uses it";
            found.Add(new Finding(file, g.Name.Line, "global", $"'{n}' is global but {why}; make it local", true, fix));
        }
        if (forward.Count > 0)
        {
            var at = AfterHeader(s);
            var decl = new Edit(at, 0, (at == 0 ? "" : "\n") + "local " + string.Join(", ", forward) + "\n" + (at == 0 ? "\n" : ""));
            for (int k = 0; k < found.Count; k++)
                if (found[k].Rule == "global" && forward.Any(n => found[k].Message.StartsWith($"'{n}'", StringComparison.Ordinal)))
                    found[k] = found[k] with { Fix = decl };
        }
    }

    // A global only functions use, each setting it before reading it, is a local in each of them:
    // "local " on an assignment straight in the body, else a "local n" at the top of the body.
    // Null when a function could read a value an earlier call left.
    static Edit? LocalInFunctions(Script s, string n)
    {
        var groups = s.UsesByFunction[n].GroupBy(u => u.Function).ToList();
        if (groups.Count != 1 || groups[0].Key == null) return null;
        var first = groups[0].OrderBy(u => u.At).First();
        if (!first.Write) return null;
        int eol = s.Src.IndexOf('\n', first.At);
        if (groups[0].Any(u => u.At > first.At && (eol < 0 || u.At < eol))) return null; // n = n + 1
        if (first.BodyWrite) return new Edit(first.At, 0, "local ");
        var fn = groups[0].Key;
        int line = s.Src.LastIndexOf('\n', Math.Max(0, fn.Body - 1)) + 1;
        string indent = new(s.Src[line..].TakeWhile(c => c == ' ' || c == '\t').ToArray());
        return new Edit(fn.Body, 0, "\n" + indent + "\tlocal " + n);
    }

    // Where a forward "local a, b" goes: after the requires and the file's description.
    static int AfterHeader(Script s)
    {
        var (_, header, requiresEnd) = Top(s);
        int at = header != null && header.Start >= requiresEnd ? header.End : requiresEnd;
        if (at == 0) return 0;
        int nl = s.Src.IndexOf('\n', at);
        return nl < 0 ? s.Src.Length : nl + 1;
    }

    // The file's leading require statements and its description block. requiresEnd is where the
    // last leading require ends (0 without any); firstCode is the first token that is neither.
    static (int FirstCode, Token? Header, int RequiresEnd) Top(Script s)
    {
        var t = s.All;
        Token? header = null;
        int requiresEnd = 0, i = 0;
        while (i < t.Count && t[i].Kind != TokKind.Eof)
        {
            if (t[i].Kind == TokKind.Comment)
            {
                if (header == null && t[i].Text.StartsWith("--[[", StringComparison.Ordinal)) header = t[i];
                i++;
                continue;
            }
            if (t[i].Kind == TokKind.Name && t[i].Text == "require")
            {
                if (t[i + 1].Kind == TokKind.String) { requiresEnd = t[i + 1].End; i += 2; continue; }
                if (t[i + 1].Is("(") && t[i + 2].Kind == TokKind.String && t[i + 3].Is(")")) { requiresEnd = t[i + 3].End; i += 4; continue; }
            }
            break;
        }
        return (i < t.Count ? t[i].Start : s.Src.Length, header, requiresEnd);
    }

    [GeneratedRegex(@"[-=#*~]{4,}")] private static partial Regex Banner();
    [GeneratedRegex(@"[A-Za-z][A-Za-z0-9]*")] private static partial Regex Word();

    void CheckComments(Script s, Action<int, string, string, bool, Edit?> add)
    {
        var (_, header, requiresEnd) = Top(s);
        if (header != null && header.Start < requiresEnd)
        {
            int from = header.Start, to = header.End;
            while (to < s.Src.Length && char.IsWhiteSpace(s.Src[to])) to++;
            int nl = s.Src.IndexOf('\n', requiresEnd);
            int at = nl < 0 ? s.Src.Length : nl;
            add(header.Line, "header", "the file's description goes after its requires", true,
                new Edit(from, at - from, s.Src[to..at] + "\n\n" + header.Text));
        }

        if (header == null)
        {
            int codeLines = s.Code.Where(x => x.Kind != TokKind.Eof).Select(x => x.Line).Distinct().Count();
            if (codeLines >= MinDescribedLines)
                add(1, "header", $"{codeLines} lines of code and no --[[ ]] description after the requires", true, null);
        }

        var all = s.All;
        for (int i = 0; i < all.Count; i++)
        {
            var c = all[i];
            if (c.Kind != TokKind.Comment) continue;
            bool block = c.Text.StartsWith("--[", StringComparison.Ordinal) && c.Text.Length > 3 && (c.Text[3] == '[' || c.Text[3] == '=');
            if (block)
            {
                int lines = c.Text.Count(ch => ch == '\n') - 1;
                if (lines > MaxCommentLines && c != header)
                    add(c.Line, "comment", $"{lines}-line comment; keep it to {MaxCommentLines} or move it to Data/Docs", true, null);
                else if (c == header && lines > MaxCommentLines)
                    add(c.Line, "comment", $"{lines}-line description; keep it to {MaxCommentLines} or move the rest to Data/Docs", true, null);
                continue;
            }
            if (Banner().IsMatch(c.Text[2..]))
            {
                bool alone = OwnLine(s.Src, c);
                add(c.Line, "banner", "section-divider comment", true, alone ? DeleteLine(s.Src, c) : null);
                continue;
            }
            // A run of line comments, one per line, counts as one comment.
            if (i > 0 && all[i - 1].Kind == TokKind.Comment && all[i - 1].Line == c.Line - 1 && OwnLine(s.Src, all[i - 1]) && OwnLine(s.Src, c)) continue;
            int run = 1;
            while (i + run < all.Count && all[i + run].Kind == TokKind.Comment && all[i + run].Line == c.Line + run && OwnLine(s.Src, all[i + run]) && !all[i + run].Text.StartsWith("--[[", StringComparison.Ordinal)) run++;
            if (run > MaxCommentLines && OwnLine(s.Src, c))
                add(c.Line, "comment", $"{run}-line comment; keep it to {MaxCommentLines} or move it to Data/Docs", true, null);
            CheckRestate(s, i, run, add);
        }
    }

    static readonly HashSet<string> Filler = new(StringComparer.OrdinalIgnoreCase)
    {
        "a", "an", "the", "of", "to", "for", "and", "or", "in", "on", "is", "it", "its", "by", "with", "from", "this", "that", "be", "as", "at",
    };

    static IEnumerable<string> NameWords(string n) =>
        Regex.Split(Regex.Replace(n, "([a-z0-9])([A-Z])", "$1 $2"), "[ _]+").Where(w => w.Length > 0).Select(w => w.ToLowerInvariant());

    // A comment directly above a declaration that only says what its name and parameters say.
    void CheckRestate(Script s, int i, int run, Action<int, string, string, bool, Edit?> add)
    {
        var all = s.All;
        int next = i + run;
        if (next >= all.Count || all[next].Kind == TokKind.Comment || all[next].Line != all[i + run - 1].Line + 1) return;
        var text = string.Join(" ", all.Skip(i).Take(run).Select(c => c.Text[2..]));
        var words = Word().Matches(text).Select(m => m.Value).Where(w => !Filler.Contains(w)).ToList();
        if (words.Count == 0) return;

        int k = next;
        if (all[k].Is("local")) k++;
        if (all[k].Is("function")) k++;
        if (all[k].Kind != TokKind.Name) return;
        var name = all[k].Text;
        while (all[k + 1].Is(".") || all[k + 1].Is(":")) { k += 2; name = all[k].Text; }
        var parameters = new List<string>();
        int p = k + 1;
        if (all[p].Is("=") && all[p + 1].Is("function")) p += 2;
        if (all[p].Is("("))
            for (p++; all[p].Kind != TokKind.Eof && !all[p].Is(")"); p++)
                if (all[p].Kind == TokKind.Name) parameters.Add(all[p].Text);

        var nameWords = NameWords(name).ToHashSet();
        int paramHits = parameters.Count(x => x.Length > 1 && words.Contains(x, StringComparer.Ordinal));
        int nameHits = words.Count(w => nameWords.Contains(w.ToLowerInvariant()) || parameters.Contains(w, StringComparer.Ordinal));
        bool listsParameters = paramHits >= 2 || (parameters.Count == 1 && paramHits == 1 && words.Count <= 4);
        bool echoesName = words.Count <= 4 && nameHits * 2 >= words.Count;
        if (listsParameters || echoesName)
            add(all[i].Line, "restate", $"comment repeats '{name}'{(listsParameters ? " and its parameters" : "")}", false, null);
    }

    static bool OwnLine(string src, Token c)
    {
        int k = c.Start - 1;
        while (k >= 0 && src[k] != '\n') { if (!char.IsWhiteSpace(src[k])) return false; k--; }
        return true;
    }

    static Edit DeleteLine(string src, Token c)
    {
        int from = src.LastIndexOf('\n', Math.Max(0, c.Start - 1)) + 1;
        int to = src.IndexOf('\n', c.End);
        to = to < 0 ? src.Length : to + 1;
        return new Edit(from, to - from, "");
    }

    static readonly HashSet<string> NpcCallbacks = new() { "onTalk", "onPush", "onEmote", "onNotice" };

    // An NPC event callback whose body tests the sequence in an if/elseif chain.
    void CheckQuestMaps(Script s, Action<int, string, string, bool, Edit?> add)
    {
        var t = s.Code;
        foreach (var (name, from, to) in s.Callbacks)
        {
            if (!NpcCallbacks.Contains(name.Text)) continue;
            int tests = 0;
            for (int i = from; i < to; i++)
            {
                if (!t[i].Is("if") && !t[i].Is("elseif")) continue;
                for (int j = i + 1; j < to && !t[j].Is("then"); j++)
                    if (t[j].Kind == TokKind.Name && (t[j].Text.StartsWith("SEQ_", StringComparison.Ordinal) || t[j].Text == "sequence"))
                    {
                        tests++;
                        break;
                    }
            }
            if (tests >= 2)
                add(name.Line, "quest-map", $"{name.Text} branches on the sequence {tests} times; use a handler table and runQuestHandler", true, null);
        }
    }
}
