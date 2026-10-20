using System.Text;

namespace Meteor.Tools.LuaApi;

enum TokKind { Name, Keyword, Number, String, Op, Comment, Eof }

sealed record Token(TokKind Kind, string Text, int Start, int Line)
{
    public int End => Start + Text.Length;
    public bool Is(string op) => (Kind == TokKind.Op || Kind == TokKind.Keyword) && Text == op;
}

/// <summary>Splits Lua source into words, numbers, strings, symbols and comments, remembering where
/// each one starts so the linter can rewrite the file in place.</summary>
static class LuaLexer
{
    static readonly HashSet<string> Keywords = new()
    {
        "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in",
        "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
    };

    static readonly string[] Ops =
    {
        "...", "..", "==", "~=", "<=", ">=", "//", "::", "<<", ">>",
        "+", "-", "*", "/", "%", "^", "#", "&", "~", "|", "<", ">", "=", "(", ")", "{", "}", "[", "]",
        ";", ":", ",", ".",
    };

    public static List<Token> Lex(string src)
    {
        var toks = new List<Token>();
        int i = 0, line = 1;
        while (i < src.Length)
        {
            char c = src[i];
            if (c == '\n') { line++; i++; continue; }
            if (char.IsWhiteSpace(c)) { i++; continue; }

            int start = i, startLine = line;
            if (c == '-' && At(src, i + 1) == '-')
            {
                i += 2;
                int level = LongBracketLevel(src, i);
                if (level >= 0)
                    i = SkipLong(src, i, level, ref line);
                else
                    while (i < src.Length && src[i] != '\n') i++;
                toks.Add(new Token(TokKind.Comment, src[start..i], start, startLine));
                continue;
            }
            if (c == '[' && LongBracketLevel(src, i) >= 0)
            {
                i = SkipLong(src, i, LongBracketLevel(src, i), ref line);
                toks.Add(new Token(TokKind.String, src[start..i], start, startLine));
                continue;
            }
            if (c == '"' || c == '\'')
            {
                i++;
                while (i < src.Length && src[i] != c)
                {
                    if (src[i] == '\\') { if (At(src, i + 1) == '\n') line++; i += 2; continue; }
                    if (src[i] == '\n') break; // a string missing its closing quote; the compile check reports it
                    i++;
                }
                i = Math.Min(i + 1, src.Length);
                toks.Add(new Token(TokKind.String, src[start..i], start, startLine));
                continue;
            }
            if (char.IsDigit(c) || (c == '.' && char.IsDigit(At(src, i + 1))))
            {
                bool hex = c == '0' && (At(src, i + 1) == 'x' || At(src, i + 1) == 'X');
                if (hex) i += 2;
                while (i < src.Length && (char.IsLetterOrDigit(src[i]) || src[i] == '.'))
                {
                    char e = char.ToLowerInvariant(src[i]);
                    bool exponent = hex ? e == 'p' : e == 'e';
                    i++;
                    if (exponent && (At(src, i) == '-' || At(src, i) == '+')) i++;
                }
                toks.Add(new Token(TokKind.Number, src[start..i], start, startLine));
                continue;
            }
            if (char.IsLetter(c) || c == '_')
            {
                while (i < src.Length && (char.IsLetterOrDigit(src[i]) || src[i] == '_')) i++;
                string word = src[start..i];
                toks.Add(new Token(Keywords.Contains(word) ? TokKind.Keyword : TokKind.Name, word, start, startLine));
                continue;
            }
            string? op = null;
            foreach (var o in Ops)
                if (string.CompareOrdinal(src, i, o, 0, o.Length) == 0) { op = o; break; }
            op ??= c.ToString();
            i += op.Length;
            toks.Add(new Token(TokKind.Op, op, start, startLine));
        }
        toks.Add(new Token(TokKind.Eof, "", src.Length, line));
        return toks;
    }

    /// <summary>The same list without comments.</summary>
    public static List<Token> Code(List<Token> toks) => toks.Where(t => t.Kind != TokKind.Comment).ToList();

    static char At(string s, int i) => i < s.Length ? s[i] : '\0';

    static int LongBracketLevel(string s, int i)
    {
        if (At(s, i) != '[') return -1;
        int j = i + 1, level = 0;
        while (At(s, j) == '=') { level++; j++; }
        return At(s, j) == '[' ? level : -1;
    }

    static int SkipLong(string s, int i, int level, ref int line)
    {
        string close = "]" + new string('=', level) + "]";
        int body = i + level + 2;
        int endIdx = s.IndexOf(close, body, StringComparison.Ordinal);
        int stop = endIdx < 0 ? s.Length : endIdx + close.Length;
        for (int k = i; k < stop; k++) if (s[k] == '\n') line++;
        return stop;
    }

    public static string Unquote(Token t)
    {
        if (t.Kind != TokKind.String) return t.Text;
        var s = t.Text;
        if (s.StartsWith('[')) { int l = s.IndexOf('[', 1) + 1; return s[l..^(l)]; }
        var sb = new StringBuilder();
        for (int i = 1; i < s.Length - 1; i++)
        {
            if (s[i] == '\\' && i + 1 < s.Length - 1) { sb.Append(s[++i]); continue; }
            sb.Append(s[i]);
        }
        return sb.ToString();
    }
}
