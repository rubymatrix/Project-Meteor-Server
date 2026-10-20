using System.Text;
using Meteor.Tools.LuaApi;

// manifest          regenerate Data/lua-api/{manifest.json,meteor.d.lua}
// manifest --check  fail if the committed manifest differs from the code
// lint [paths]      report findings; exit 1 on errors
// fix [paths]       apply every fixable finding in place
string root = FindRoot();
string apiDir = Path.Combine(root, "Data", "lua-api");
string manifestPath = Path.Combine(apiDir, "manifest.json");
string luaLsPath = Path.Combine(apiDir, "meteor.d.lua");
string scriptsDir = Path.Combine(root, "Data", "scripts");
// Scripts are ASCII Lua with the odd Latin-1 byte in comments; Latin-1 round-trips any byte unchanged.
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
            Console.WriteLine(same ? "lua-api is current" : "lua-api is stale: run `dotnet run --project tools/LuaApi -- manifest` and commit Data/lua-api");
            return same ? 0 : 1;
        }
        Directory.CreateDirectory(apiDir);
        File.WriteAllText(manifestPath, json);
        File.WriteAllText(luaLsPath, lua);
        Console.WriteLine($"{m.Types.Count} types, {m.Globals.Count} globals -> {Path.GetRelativePath(root, apiDir)}");
        return 0;
    }
    case "lint":
    case "fix":
    {
        var api = ApiManifest.FromJson(File.ReadAllText(manifestPath));
        var allFiles = Directory.EnumerateFiles(scriptsDir, "*.lua", SearchOption.AllDirectories).OrderBy(f => f, StringComparer.Ordinal).ToList();
        var targets = rest.Where(a => !a.StartsWith("--")).ToList();
        var files = targets.Count == 0 ? allFiles : allFiles.Where(f => targets.Any(t => Path.GetFullPath(f).StartsWith(Path.GetFullPath(t), StringComparison.Ordinal))).ToList();
        var sources = allFiles.ToDictionary(f => f, f => File.ReadAllText(f, bytes));
        var linter = new Linter(api, sources.Values);
        bool warnings = rest.Contains("--warnings");

        var findings = new List<Finding>();
        foreach (var f in files)
        {
            var rel = Path.GetRelativePath(root, f).Replace('\\', '/');
            var found = linter.Check(rel, sources[f]);
            if (cmd == "fix")
            {
                var edits = found.Where(x => x.Fix != null).Select(x => x.Fix!).ToList();
                if (edits.Count > 0)
                {
                    File.WriteAllText(f, Linter.Apply(sources[f], edits), bytes);
                    found = found.Where(x => x.Fix == null).ToList();
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
    case "compile-moonsharp":
    {
        // Parse-only check under the current engine, to tell scripts that were already broken from
        // ones LuaJIT's stricter 5.1 grammar rejects.
        int bad = 0;
        foreach (var f in Directory.EnumerateFiles(scriptsDir, "*.lua", SearchOption.AllDirectories).OrderBy(f => f, StringComparer.Ordinal))
        {
            try { new MoonSharp.Interpreter.Script().LoadString(File.ReadAllText(f, bytes), null, Path.GetRelativePath(scriptsDir, f)); }
            catch (MoonSharp.Interpreter.SyntaxErrorException e) { Console.WriteLine(e.DecoratedMessage ?? e.Message); bad++; }
        }
        Console.WriteLine($"{bad} files failed to compile");
        return bad == 0 ? 0 : 1;
    }
    default:
        Console.Error.WriteLine("usage: LuaApi manifest [--check] | lint [--warnings] [paths] | fix [paths]");
        return 2;
}

static string FindRoot()
{
    var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
    while (dir != null && !File.Exists(Path.Combine(dir.FullName, "Meteor.sln"))) dir = dir.Parent;
    return dir?.FullName ?? throw new InvalidOperationException("run inside the Meteor repository");
}
