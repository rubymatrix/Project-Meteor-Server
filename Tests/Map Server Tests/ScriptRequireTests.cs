using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Xunit;

namespace Meteor.Map.Tests
{
    // Each script runs with its own globals, so a script that uses modifiersGlobal must reach
    // modifiers.lua through its own requires. Root-level files are modules that run inside the
    // script requiring them, so only the scripts the server loads directly are checked.
    public class ScriptRequireTests
    {
        private static readonly string Root = EngineFixture.ScriptsDir;
        private static readonly Dictionary<string, HashSet<string>> Closures = new Dictionary<string, HashSet<string>>();

        private static string Resolve(string name)
        {
            string n = name.Replace('.', '/');
            foreach (var p in new[] { Path.Combine(Root, n), Path.Combine(Root, n + ".lua") })
                if (File.Exists(p))
                    return Path.GetFullPath(p);
            return null;
        }

        private static HashSet<string> Requires(string file)
        {
            if (Closures.TryGetValue(file, out var done))
                return done;
            var all = Closures[file] = new HashSet<string>();
            foreach (Match m in Regex.Matches(File.ReadAllText(file), @"require\s*\(?\s*[""']([^""']+)[""']"))
            {
                var p = Resolve(m.Groups[1].Value);
                if (p != null && all.Add(p))
                    all.UnionWith(Requires(p));
            }
            return all;
        }

        [Fact]
        public void ScriptsUsingModifiersRequireThem()
        {
            string modifiers = Path.GetFullPath(Path.Combine(Root, "modifiers.lua"));
            var missing = Directory.EnumerateFiles(Root, "*.lua", SearchOption.AllDirectories)
                .Select(Path.GetFullPath)
                .Where(f => Path.GetDirectoryName(f) != Path.GetFullPath(Root).TrimEnd(Path.DirectorySeparatorChar))
                .Where(f => !f.Contains(Path.DirectorySeparatorChar + "__tests" + Path.DirectorySeparatorChar))
                .Where(f => File.ReadAllText(f).Contains("modifiersGlobal") && !Requires(f).Contains(modifiers))
                .Select(f => Path.GetRelativePath(Root, f))
                .ToList();
            Assert.True(missing.Count == 0, "No require(\"modifiers\"): " + string.Join(", ", missing));
        }
    }
}
