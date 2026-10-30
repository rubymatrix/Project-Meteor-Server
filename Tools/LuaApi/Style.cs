using System.Diagnostics;
using System.Text;

namespace Meteor.Tools.LuaApi;

// Rewrites a script's layout to Data/Docs/lua-style.md: tabs, no semicolons, no parentheses around
// a whole condition, ~= for not-equal, require("x"), double quotes, no trailing spaces. A rewrite
// is kept only when it has the same Shape as the original and still compiles.
static class Style
{
    public static string Format(string src)
    {
        src = src.Replace("\r\n", "\n");
        src = Linter.Apply(src, TokenEdits(src));
        return Reindent(src);
    }

    static List<Edit> TokenEdits(string src)
    {
        var all = LuaLexer.Lex(src);
        var code = LuaLexer.Code(all);
        var edits = new List<Edit>();
        int braces = 0;
        for (int i = 0; i < code.Count; i++)
        {
            var t = code[i];
            if (t.Is("{")) braces++;
            else if (t.Is("}")) braces--;
            else if (t.Is(";") && braces == 0 && !code[i + 1].Is("("))
                edits.Add(new Edit(t.Start, 1, ""));
            else if (t.Kind == TokKind.Op && t.Text == "!" && code[i + 1].Is("=") && code[i + 1].Start == t.End)
                edits.Add(new Edit(t.Start, 2, "~="));
            else if (t.Kind == TokKind.Name && t.Text == "require" && code[i + 1].Is("(") && code[i + 1].Start > t.End
                     && (i == 0 || !code[i - 1].Is(".") && !code[i - 1].Is(":")))
                edits.Add(new Edit(t.End, code[i + 1].Start - t.End, ""));
            else if (t.Kind == TokKind.String && t.Text.Length >= 2 && t.Text[0] == '\'' && t.Text[^1] == '\'')
            {
                string body = t.Text[1..^1];
                if (!body.Contains('"') && !body.Contains('\n'))
                    edits.Add(new Edit(t.Start, t.Text.Length, "\"" + body.Replace("\\'", "'") + "\""));
            }
            else if (t.Kind == TokKind.Keyword && (t.Text == "if" || t.Text == "elseif" || t.Text == "while") && code[i + 1].Is("("))
            {
                int close = Matching(code, i + 1);
                string after = t.Text == "while" ? "do" : "then";
                if (close > 0 && code[close + 1].Is(after))
                {
                    var open = code[i + 1];
                    var shut = code[close];
                    edits.Add(new Edit(open.Start, 1, open.Start == t.End ? " " : ""));
                    edits.Add(new Edit(shut.Start, 1, code[close + 1].Start == shut.End ? " " : ""));
                }
            }
        }
        return edits;
    }

    static int Matching(List<Token> code, int open)
    {
        int depth = 0;
        for (int j = open; j < code.Count; j++)
        {
            if (code[j].Is("(")) depth++;
            else if (code[j].Is(")") && --depth == 0) return j;
            else if (code[j].Kind == TokKind.Eof) break;
        }
        return -1;
    }

    // Leading spaces become tabs at the file's own indent width; text inside long strings and
    // long comments is left alone.
    static string Reindent(string src)
    {
        var frozen = new List<(int Start, int End)>();
        foreach (var t in LuaLexer.Lex(src))
            if ((t.Kind == TokKind.String || t.Kind == TokKind.Comment) && t.Text.Contains('\n'))
                frozen.Add((t.Start, t.End));
        bool Frozen(int pos) => frozen.Any(f => pos > f.Start && pos < f.End);

        var lines = src.Split('\n');
        int unit = 0, at = 0;
        foreach (var l in lines)
        {
            if (!Frozen(at))
            {
                int spaces = l.Length - l.TrimStart(' ').Length;
                if (spaces > 0 && spaces < l.Length && l[spaces] != '\t' && (unit == 0 || spaces < unit) && spaces >= 2) unit = spaces;
            }
            at += l.Length + 1;
        }
        unit = unit == 2 ? 2 : 4;

        var sb = new StringBuilder();
        at = 0;
        for (int n = 0; n < lines.Length; n++)
        {
            string l = lines[n];
            bool frozenStart = Frozen(at);
            bool frozenEnd = Frozen(at + l.Length);
            string outLine = l;
            if (!frozenStart)
            {
                int k = 0, width = 0;
                while (k < l.Length && (l[k] == ' ' || l[k] == '\t')) { width += l[k] == '\t' ? unit : 1; k++; }
                string rest = l[k..];
                outLine = rest.Length == 0 ? "" : new string('\t', width / unit) + new string(' ', width % unit) + rest;
            }
            if (!frozenEnd) outLine = outLine.TrimEnd(' ', '\t');
            sb.Append(outLine);
            if (n < lines.Length - 1) sb.Append('\n');
            at += l.Length + 1;
        }
        return sb.ToString();
    }

    // The code tokens with only what Format may change taken out. LuaJIT bytecode can't be the
    // check: table templates are laid out by a per-process hash seed.
    public static List<string> Shape(string src)
    {
        var code = LuaLexer.Code(LuaLexer.Lex(src.Replace("\r\n", "\n")));
        var drop = new HashSet<int>();
        int braces = 0;
        for (int i = 0; i < code.Count; i++)
        {
            var t = code[i];
            if (t.Is("{")) braces++;
            else if (t.Is("}")) braces--;
            else if (t.Is(";") && braces == 0) drop.Add(i);
            else if (t.Kind == TokKind.Keyword && (t.Text == "if" || t.Text == "elseif" || t.Text == "while") && code[i + 1].Is("("))
            {
                int close = Matching(code, i + 1);
                if (close > 0 && code[close + 1].Is(t.Text == "while" ? "do" : "then")) { drop.Add(i + 1); drop.Add(close); }
            }
        }
        var shape = new List<string>();
        for (int i = 0; i < code.Count; i++)
        {
            if (drop.Contains(i)) continue;
            var t = code[i];
            if (t.Kind == TokKind.Op && t.Text == "!" && i + 1 < code.Count && code[i + 1].Is("=")) { shape.Add("Op:~="); i++; continue; }
            shape.Add(t.Kind == TokKind.String ? "S:" + LuaLexer.Unquote(t) : t.Kind + ":" + t.Text);
        }
        return shape;
    }

    // Whether luajit compiles the source; true when luajit isn't installed.
    public static bool Compiles(string src, string luajit)
    {
        string inFile = Path.GetTempFileName(), outFile = Path.GetTempFileName();
        try
        {
            File.WriteAllText(inFile, src, Encoding.Latin1);
            var p = Process.Start(new ProcessStartInfo(luajit, $"-b \"{inFile}\" \"{outFile}\"")
            { RedirectStandardError = true, RedirectStandardOutput = true, UseShellExecute = false });
            if (p == null) return true;
            p.WaitForExit();
            return p.ExitCode == 0;
        }
        catch (System.ComponentModel.Win32Exception) { return true; }
        finally { File.Delete(inFile); File.Delete(outFile); }
    }
}
