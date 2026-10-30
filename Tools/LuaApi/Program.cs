using System.Text;
using Meteor.Tools.LuaApi;

// Commands:
//   manifest            rewrite Data/lua-api (the list of server functions scripts can use)
//   manifest --check    fail if Data/lua-api is out of date with the server code
//   lint [paths]        report script problems; fails if any are errors
//   fix [paths]         correct the problems that have a mechanical fix, in place
//   actions [--check]   rewrite Data/scripts/Ai/Actions.lua (battle command ids by name)
//   style [--check]     rewrite script layout to Data/Docs/lua-style.md; keeps a file only if its bytecode is unchanged
string root = FindRoot();
string apiDir = Path.Combine(root, "Data", "lua-api");
string manifestPath = Path.Combine(apiDir, "manifest.json");
string luaLsPath = Path.Combine(apiDir, "meteor.d.lua");
string scriptsDir = Path.Combine(root, "Data", "scripts");
// Some scripts have non-ASCII bytes in comments. Reading and writing them as Latin-1 keeps every
// byte exactly as it was.
var bytes = Encoding.Latin1;

string cmd = args.Length > 0 ? args[0] : "lint";
var rest = args.Skip(1).ToList();

switch (cmd)
{
    case "manifest":
    {
        var m = ManifestBuilder.Build(root);
        string json = m.ToJson(), lua = ManifestBuilder.ToLuaLs(m);
        if (rest.Contains("--check"))
        {
            bool same = File.Exists(manifestPath) && File.ReadAllText(manifestPath) == json
                        && File.Exists(luaLsPath) && File.ReadAllText(luaLsPath) == lua;
            Console.WriteLine(same ? "lua-api is current" : "lua-api is stale: run `dotnet run --project Tools/LuaApi -- manifest` and commit Data/lua-api");
            return same ? 0 : 1;
        }
        Directory.CreateDirectory(apiDir);
        File.WriteAllText(manifestPath, json);
        File.WriteAllText(luaLsPath, lua);
        Console.WriteLine($"{m.Types.Count} types, {m.Globals.Count} globals -> {Path.GetRelativePath(root, apiDir)}");
        return 0;
    }
    case "style":
    {
        bool check = rest.Remove("--check");
        string luajit = Environment.GetEnvironmentVariable("LUAJIT") ?? "luajit";
        var targets = rest.Where(a => !a.StartsWith("--")).ToList();
        var files = Directory.EnumerateFiles(scriptsDir, "*.lua", SearchOption.AllDirectories)
            .Where(f => targets.Count == 0 || targets.Any(t => Path.GetFullPath(f).StartsWith(Path.GetFullPath(t), StringComparison.Ordinal)))
            .OrderBy(f => f, StringComparer.Ordinal).ToList();
        int changed = 0, refused = 0;
        foreach (var f in files)
        {
            string before = File.ReadAllText(f, bytes);
            string after = Style.Format(before);
            if (after == before) continue;
            string rel = Path.GetRelativePath(root, f).Replace('\\', '/');
            string? why = !Style.Shape(before).SequenceEqual(Style.Shape(after)) ? "code would change"
                : Style.Compiles(before, luajit) && !Style.Compiles(after, luajit) ? "rewrite does not compile" : null;
            if (why != null)
            {
                refused++;
                Console.WriteLine($"{rel}: left alone ({why})");
                continue;
            }
            changed++;
            if (check) Console.WriteLine($"{rel}: needs style fixes");
            else File.WriteAllText(f, after, bytes);
        }
        Console.WriteLine($"{files.Count} files checked, {changed} {(check ? "need fixes" : "fixed")}, {refused} left alone");
        return check && changed > 0 || refused > 0 ? 1 : 0;
    }
    case "actions":
    {
        string path = Path.Combine(scriptsDir, "Ai", "Actions.lua");
        string lua = ActionTable.Build(root);
        if (rest.Contains("--check"))
        {
            bool same = File.Exists(path) && File.ReadAllText(path) == lua;
            Console.WriteLine(same ? "Actions.lua is current" : "Actions.lua is stale: run `dotnet run --project Tools/LuaApi -- actions` and commit it");
            return same ? 0 : 1;
        }
        File.WriteAllText(path, lua);
        Console.WriteLine($"{lua.Split('\n').Count(l => l.Contains(" = ") && !l.StartsWith("Action"))} actions -> {Path.GetRelativePath(root, path)}");
        return 0;
    }
    case "lint":
    case "fix":
    {
        bool warnings = rest.Contains("--warnings");
        // "fix --rule case,dot-call" applies only the fixes for the rules listed.
        int ri = rest.IndexOf("--rule");
        HashSet<string>? ruleFilter = ri >= 0 && ri + 1 < rest.Count ? rest[ri + 1].Split(',').ToHashSet() : null;
        if (ri >= 0) rest.RemoveRange(ri, Math.Min(2, rest.Count - ri));
        var api = ApiManifest.FromJson(File.ReadAllText(manifestPath));
        var allFiles = Directory.EnumerateFiles(scriptsDir, "*.lua", SearchOption.AllDirectories).OrderBy(f => f, StringComparer.Ordinal).ToList();
        var targets = rest.Where(a => !a.StartsWith("--")).ToList();
        var files = targets.Count == 0 ? allFiles : allFiles.Where(f => targets.Any(t => Path.GetFullPath(f).StartsWith(Path.GetFullPath(t), StringComparison.Ordinal))).ToList();
        var sources = allFiles.ToDictionary(f => f, f => File.ReadAllText(f, bytes));
        var linter = new Linter(api, sources.Values, allFiles.Select(f => Path.GetRelativePath(scriptsDir, f).Replace('\\', '/')));

        var findings = new List<Finding>();
        foreach (var f in files)
        {
            var rel = Path.GetRelativePath(root, f).Replace('\\', '/');
            var found = linter.Check(rel, sources[f]);
            if (cmd == "fix")
            {
                bool Selected(Finding x) => x.Fix != null && (ruleFilter == null || ruleFilter.Contains(x.Rule));
                var edits = found.Where(Selected).Select(x => x.Fix!).ToList();
                if (edits.Count > 0)
                {
                    File.WriteAllText(f, Linter.Apply(sources[f], edits), bytes);
                    found = found.Where(x => !Selected(x)).ToList();
                }
            }
            findings.AddRange(found);
        }

        foreach (var x in findings.Where(x => x.Error || warnings))
            Console.WriteLine($"{x.File}:{x.Line}: {(x.Error ? "error" : "warning")} [{x.Rule}] {x.Message}{(x.Fix != null ? " (fixable)" : "")}");
        Console.WriteLine();
        foreach (var g in findings.GroupBy(x => (x.Rule, x.Error)).OrderBy(g => g.Key.Rule))
            Console.WriteLine($"{g.Key.Rule,-9} {(g.Key.Error ? "error" : "warning"),-7} {g.Count(),5}  ({g.Count(x => x.Fix != null)} fixable)");
        Console.WriteLine($"{files.Count} files checked");
        return findings.Any(x => x.Error) ? 1 : 0;
    }
    default:
        Console.Error.WriteLine("usage: LuaApi manifest [--check] | actions [--check] | lint [--warnings] [paths] | fix [--rule r1,r2] [paths]");
        return 2;
}

static string FindRoot()
{
    var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
    while (dir != null && !File.Exists(Path.Combine(dir.FullName, "Meteor.sln"))) dir = dir.Parent;
    return dir?.FullName ?? throw new InvalidOperationException("run inside the Meteor repository");
}
