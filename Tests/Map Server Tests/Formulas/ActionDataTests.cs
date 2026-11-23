using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // The server's action table (server_battle_commands) against the client's command sheet.
    public sealed class ActionDataTests
    {
        private const string Source = "CL-COMMAND";

        private static readonly Lazy<SeedTable> commands = new Lazy<SeedTable>(() => new SeedTable("server_battle_commands"));
        private static readonly Lazy<SeedTable> statuses = new Lazy<SeedTable>(() => new SeedTable("server_statuseffects"));

        // Attack and Throw are not battle commands on the server.
        private static readonly HashSet<long> NotInTable = new HashSet<long> { 22104, 22113 };

        // Gaps known today. Fixing one fails the test until it is taken off the list.
        private static readonly HashSet<long> StatusMissing = new HashSet<long> { 27102, 27148, 27180, 27318, 27340, 27341, 27344 };
        private static readonly HashSet<string> ScriptMissing = new HashSet<string>
        {
            "spinning_heel", "antagonize", "mighty_strikes", "refill", "sleepga", "presence_of_mind", "benediction",
        };

        private static IEnumerable<string[]> Reference()
        {
            var lines = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "data", "actions.csv"));
            return lines.Skip(1).Select(l => l.Split(','));
        }

        public static IEnumerable<object[]> Actions() => Reference().Select(r => new object[] { long.Parse(r[0]), r[1] });

        private static string[] Ref(long id) => Reference().First(r => long.Parse(r[0]) == id);

        private static double Num(string s) => s.Length == 0 ? 0 : double.Parse(s, CultureInfo.InvariantCulture);

        [Fact]
        public void EveryClientActionIsInTheTable()
        {
            var missing = Reference().Select(r => long.Parse(r[0])).Where(id => !NotInTable.Contains(id) && !commands.Value.Rows.ContainsKey(id)).ToList();
            Assert.True(missing.Count == 0, Sources.Cite(Source, "not in server_battle_commands: " + string.Join(", ", missing)));
        }

        [Theory]
        [MemberData(nameof(Actions))]
        public void MatchesTheClient(long id, string name)
        {
            if (NotInTable.Contains(id))
                return;
            var r = Ref(id);
            var t = commands.Value;
            var diffs = new List<string>();
            void Check(string what, double client, double server)
            {
                if (Math.Abs(client - server) > 1e-6) diffs.Add($"{what} client {client} server {server}");
            }
            if (r[3].Length > 0) Check("level", Num(r[3]), t.Number(id, "lvl"));
            Check("tp", Num(r[4]), t.Number(id, "tpCost"));
            Check("mp per mille", Num(r[5]), t.Number(id, "mpCost"));
            Check("cast s", Num(r[6]), t.Number(id, "castTime") / 1000.0);
            Check("recast s", Num(r[7]), t.Number(id, "recastTime"));
            Assert.True(diffs.Count == 0, Sources.Cite(Source, $"{id} {name}: " + string.Join("; ", diffs)));
        }

        [Fact]
        public void SteelCycloneCosts1000Tp()
        {
            Assert.True(commands.Value.Number(27192, "tpCost") == 1000, Sources.Cite("HF122A", "Steel Cyclone TP after the 1.22a hotfix"));
        }

        [Fact]
        public void AppliedStatusesExist()
        {
            var missing = commands.Value.Rows
                .Where(kv => kv.Key >= 27000 && long.Parse(kv.Value["statusId"]) != 0 && !statuses.Value.Rows.ContainsKey(long.Parse(kv.Value["statusId"])))
                .Select(kv => kv.Key).ToHashSet();
            Assert.True(missing.SetEquals(StatusMissing),
                $"Commands whose status is not in server_statuseffects: now {string.Join(", ", missing.OrderBy(x => x))}; known {string.Join(", ", StatusMissing.OrderBy(x => x))}. Update StatusMissing.");
        }

        [Fact]
        public void PlayerActionsHaveScripts()
        {
            var scripts = new[] { "ability", "weaponskill", "magic" }
                .SelectMany(d => Directory.EnumerateFiles(Path.Combine(AppContext.BaseDirectory, "scripts", "commands", d), "*.lua"))
                .Select(Path.GetFileNameWithoutExtension).ToHashSet();
            var missing = commands.Value.Rows.Where(kv => kv.Key >= 27000 && !scripts.Contains(kv.Value["name"])).Select(kv => kv.Value["name"]).ToHashSet();
            Assert.True(missing.SetEquals(ScriptMissing),
                $"Player actions with no script: now {string.Join(", ", missing.OrderBy(x => x))}; known {string.Join(", ", ScriptMissing.OrderBy(x => x))}. Update ScriptMissing.");
        }
    }
}
