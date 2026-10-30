using System.Text;
using System.Text.RegularExpressions;

namespace Meteor.Tools.LuaApi;

// Seeds load after the base dump, in name order; a later row with the same id wins.
static class ActionTable
{
    static readonly Regex Insert = new(
        @"INSERT INTO `?server_battle_commands`?\s*(?:\((?<cols>[^)]*)\))?\s*VALUES\s*(?<rows>.*?);\s*$",
        RegexOptions.Multiline | RegexOptions.Singleline);
    static readonly Regex Row = new(@"\((?<v>(?:[^()']|'(?:[^']|'')*')*)\)");

    static readonly Dictionary<int, string> Classes = new()
    {
        [0] = "Monsters and general", [2] = "Pugilist", [3] = "Gladiator", [4] = "Marauder", [7] = "Archer",
        [8] = "Lancer", [15] = "Monk", [16] = "Paladin", [17] = "Warrior", [18] = "Bard", [19] = "Dragoon",
        [22] = "Thaumaturge", [23] = "Conjurer", [26] = "Black Mage", [27] = "White Mage",
    };

    public static string Build(string root)
    {
        var sqlDir = Path.Combine(root, "Data", "sql");
        var files = new List<string> { Path.Combine(sqlDir, "server_battle_commands.sql") };
        files.AddRange(Directory.EnumerateFiles(Path.Combine(sqlDir, "seed"), "*.sql").OrderBy(f => f, StringComparer.Ordinal));

        var byId = new SortedDictionary<int, (string Name, int Class)>();
        foreach (var file in files)
        {
            foreach (Match m in Insert.Matches(File.ReadAllText(file)))
            {
                var cols = m.Groups["cols"].Success
                    ? m.Groups["cols"].Value.Split(',').Select(c => c.Trim().Trim('`')).ToList()
                    : null;
                int idAt = cols?.IndexOf("id") ?? 0, nameAt = cols?.IndexOf("name") ?? 1, classAt = cols?.IndexOf("classJob") ?? 2;
                foreach (Match r in Row.Matches(m.Groups["rows"].Value))
                {
                    var v = SplitValues(r.Groups["v"].Value);
                    byId[int.Parse(v[idAt])] = (v[nameAt].Trim('\''), int.Parse(v[classAt]));
                }
            }
        }

        var taken = new HashSet<string>();
        var sb = new StringBuilder();
        sb.Append("--[[\nBattle Command Actions\nGenerated from server_battle_commands using Tools/LuaApi actions\n--]]\n");
        sb.Append("Action = {\n");
        foreach (var group in byId.GroupBy(kv => kv.Value.Class).OrderBy(g => g.Key))
        {
            sb.Append($"\t-- {(Classes.TryGetValue(group.Key, out var c) ? c : "Class " + group.Key)}\n");
            foreach (var (id, (name, _)) in group)
            {
                var key = Ident(name);
                if (!taken.Add(key))
                    taken.Add(key = $"{key}{id}");
                sb.Append($"\t{key} = {id},\n");
            }
        }
        sb.Append("}\n\nreturn Action\n");
        return sb.ToString();
    }

    static string Ident(string name)
    {
        var words = Regex.Split(name.ToLowerInvariant(), "[^a-z0-9]+").Where(w => w.Length > 0);
        var s = string.Concat(words.Select(w => char.ToUpperInvariant(w[0]) + w[1..]));
        return char.IsDigit(s[0]) ? "_" + s : s;
    }

    static List<string> SplitValues(string s)
    {
        var parts = new List<string>();
        var cur = new StringBuilder();
        bool quoted = false;
        foreach (char ch in s)
        {
            if (ch == '\'') quoted = !quoted;
            if (ch == ',' && !quoted)
            {
                parts.Add(cur.ToString().Trim());
                cur.Clear();
            }
            else
                cur.Append(ch);
        }
        parts.Add(cur.ToString().Trim());
        return parts;
    }
}
