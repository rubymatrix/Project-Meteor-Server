using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Rows of Data/sql/server_battle_commands.sql: combo links, positionals, durations, cast times
    // and recasts.
    public sealed class RulesCommandRowTests
    {
        private sealed class Row
        {
            public int Id;
            public string Name;
            public int PositionBonus, BestRange, Range, StatusDuration, CastMs, RecastS, MpCost, Combo1, Combo2;
        }

        private const int Front = 1, Rear = 2, Flank = 4;

        private static readonly Lazy<Dictionary<string, Row>> rows = new Lazy<Dictionary<string, Row>>(Load);

        private static Dictionary<string, Row> Load()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null && !File.Exists(Path.Combine(dir.FullName, "Data", "sql", "server_battle_commands.sql")))
                dir = dir.Parent;
            Assert.NotNull(dir);
            var byName = new Dictionary<string, Row>();
            foreach (var line in File.ReadLines(Path.Combine(dir.FullName, "Data", "sql", "server_battle_commands.sql")))
            {
                int start = line.IndexOf("VALUES (", StringComparison.Ordinal);
                if (!line.StartsWith("INSERT", StringComparison.Ordinal) || start < 0)
                    continue;
                var v = Split(line.Substring(start + 8, line.LastIndexOf(')') - start - 8));
                int I(int col) => (int)Convert.ToInt64(double.Parse(v[col], System.Globalization.CultureInfo.InvariantCulture));
                var row = new Row
                {
                    Id = I(0), Name = v[1], PositionBonus = I(15), Range = I(17), BestRange = I(19),
                    StatusDuration = I(23), CastMs = I(26), RecastS = I(27), MpCost = I(28), Combo1 = I(36), Combo2 = I(37),
                };
                byName[row.Name] = row;
            }
            return byName;
        }

        // Comma-separated SQL values; quotes removed, '' unescaped.
        private static List<string> Split(string s)
        {
            var parts = new List<string>();
            var cur = new StringBuilder();
            bool quoted = false;
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (c == '\'')
                {
                    if (quoted && i + 1 < s.Length && s[i + 1] == '\'') { cur.Append('\''); i++; }
                    else quoted = !quoted;
                }
                else if (c == ',' && !quoted) { parts.Add(cur.ToString()); cur.Clear(); }
                else cur.Append(c);
            }
            parts.Add(cur.ToString());
            return parts;
        }

        private static Row Get(string name, string id)
        {
            Assert.True(rows.Value.TryGetValue(name, out var row), Sources.Cite(id, $"{name}: no row in server_battle_commands.sql"));
            return row;
        }

        private static IEnumerable<Row> PlayerCommands => rows.Value.Values.Where(r => r.Id >= 27100 && r.Id < 28000);

        // Every combo opener and the steps that may follow it.
        private static readonly Dictionary<string, string[]> Combos = new Dictionary<string, string[]>
        {
            ["pummel"] = new[] { "concussive_blow", "aura_pulse" },
            ["concussive_blow"] = new[] { "simian_thrash" },
            ["pounce"] = new[] { "demolish", "sucker_punch" },
            ["demolish"] = new[] { "howling_fist" },
            ["sucker_punch"] = new[] { "dragon_kick" },
            ["fast_blade"] = new[] { "flat_blade", "savage_blade" },
            ["savage_blade"] = new[] { "goring_blade" },
            ["riot_blade"] = new[] { "rage_of_halone" },
            ["phalanx"] = new[] { "spirits_within" },
            ["heavy_swing"] = new[] { "skull_sunder" },
            ["skull_sunder"] = new[] { "steel_cyclone" },
            ["brutal_swing"] = new[] { "maim" },
            ["maim"] = new[] { "godsbane" },
            ["path_of_the_storm"] = new[] { "whirlwind" },
            ["heavy_shot"] = new[] { "leaden_arrow", "quick_nock" },
            ["leaden_arrow"] = new[] { "wide_volley" },
            ["quick_nock"] = new[] { "rain_of_death" },
            ["piercing_arrow"] = new[] { "gloom_arrow", "shadowbind" },
            ["gloom_arrow"] = new[] { "bloodletter" },
            ["true_thrust"] = new[] { "leg_sweep", "heavy_thrust" },
            ["leg_sweep"] = new[] { "doom_spike" },
            ["vorpal_thrust"] = new[] { "impulse_drive" },
            ["impulse_drive"] = new[] { "chaos_thrust", "ring_of_talons" },
            ["feint"] = new[] { "disembowel" },
            ["fire"] = new[] { "fira" },
            ["fira"] = new[] { "firaga" },
            ["thunder"] = new[] { "thundara" },
            ["thundara"] = new[] { "thundaga", "burst" },
            ["aero"] = new[] { "aerora" },
            ["stone"] = new[] { "stonera" },
        };

        public static IEnumerable<object[]> ComboOpeners => Combos.Keys.Select(k => new object[] { k });

        private static string Name(int id) => rows.Value.Values.FirstOrDefault(r => r.Id == id)?.Name ?? id.ToString();

        [Theory]
        [MemberData(nameof(ComboOpeners))]
        public void ComboLinks(string opener)
        {
            var row = Get(opener, "CL-CMD");
            var got = new[] { row.Combo1, row.Combo2 }.Where(id => id != 0).Select(Name).OrderBy(n => n);
            var want = Combos[opener].OrderBy(n => n);
            Assert.True(got.SequenceEqual(want),
                Sources.Cite("CL-CMD", $"{opener} combos into: research {string.Join(", ", want)}; server {string.Join(", ", got)}"));
        }

        [Fact]
        public void NoOtherComboLinks()
        {
            var extra = PlayerCommands.Where(r => (r.Combo1 != 0 || r.Combo2 != 0) && !Combos.ContainsKey(r.Name)).Select(r => r.Name).ToList();
            Assert.True(extra.Count == 0, Sources.Cite("CL-CMD", $"Combo openers outside the client sheet's list: {string.Join(", ", extra)}"));
        }

        private static readonly Dictionary<string, int> Positionals = new Dictionary<string, int>
        {
            ["pummel"] = Front, ["fast_blade"] = Front, ["heavy_swing"] = Front, ["true_thrust"] = Front,
            ["concussive_blow"] = Flank, ["howling_fist"] = Flank, ["sucker_punch"] = Flank, ["brutal_swing"] = Flank, ["impulse_drive"] = Flank,
            ["blindside"] = Rear, ["pounce"] = Rear, ["goring_blade"] = Rear, ["riot_blade"] = Rear, ["path_of_the_storm"] = Rear, ["vorpal_thrust"] = Rear,
        };

        public static IEnumerable<object[]> PositionalCommands => Positionals.Keys.Select(k => new object[] { k });

        [Theory]
        [MemberData(nameof(PositionalCommands))]
        public void Positional(string name)
        {
            int got = Get(name, "PN120-L").PositionBonus;
            Assert.True(got == Positionals[name], Sources.Cite("PN120-L", $"{name} positional (1 front, 2 rear, 4 flank): research {Positionals[name]}, server {got}"));
        }

        [Fact]
        public void NoOtherPositionals()
        {
            var extra = PlayerCommands.Where(r => r.PositionBonus != 0 && !Positionals.ContainsKey(r.Name)).Select(r => r.Name).ToList();
            Assert.True(extra.Count == 0, Sources.Cite("PN120-L", $"Positionals outside the list: {string.Join(", ", extra)}"));
        }

        [Theory]
        [InlineData("heavy_shot")]
        [InlineData("piercing_arrow")]
        public void ArcherOpenerBestRange(string name)
        {
            int got = Get(name, "CL-CMD").BestRange;
            Assert.True(got == 8, Sources.Cite("CL-CMD", $"{name} best range: research 8, server {got}"));
        }

        [Theory]
        [InlineData("true_thrust", 10)]
        [InlineData("vorpal_thrust", 20)]
        [InlineData("impulse_drive", 30)]
        [InlineData("disembowel", 30)]
        [InlineData("full_thrust", 30)]
        [InlineData("leg_sweep", 30)]
        [InlineData("second_wind", 45)]
        [InlineData("invigorate", 90)]
        [InlineData("hawks_eye", 90)]
        [InlineData("dragonfire_dive", 900)]
        public void Recast(string name, int seconds)
        {
            int got = Get(name, "RCAP-IFRIT").RecastS;
            Assert.True(Math.Abs(got - seconds) <= 1, Sources.Cite("RCAP-IFRIT", $"{name} recast: research {seconds} ±1 s, server {got} s"));
        }

        [Theory]
        [InlineData("cure", 2)]
        [InlineData("cura", 2)]
        [InlineData("regen", 2)]
        [InlineData("stoneskin", 3)]
        [InlineData("protect", 3)]
        [InlineData("aero", 3)]
        [InlineData("aerora", 3)]
        [InlineData("thunder", 2)]
        [InlineData("thundaga", 5)]
        [InlineData("freeze", 5)]
        [InlineData("burst", 4)]
        [InlineData("blizzard", 2)]
        public void CastTime(string name, int seconds)
        {
            double got = Get(name, "RCAP-IFRIT").CastMs / 1000.0;
            Assert.True(Math.Abs(got - seconds) <= 1, Sources.Cite("RCAP-IFRIT", $"{name} cast time: research {seconds} ±1 s, server {got} s"));
        }

        [Fact]
        public void RaiseRow()
        {
            var r = Get("raise", "CL-CMD");
            Assert.True(r.MpCost == 150, Sources.Cite("CL-CMD", $"Raise MP: research 150 per mille, server {r.MpCost}"));
            Assert.True(r.CastMs == 10000, Sources.Cite("CL-CMD", $"Raise cast: research 10 s, server {r.CastMs / 1000.0} s"));
            Assert.True(r.RecastS == 300, Sources.Cite("CL-CMD", $"Raise recast: research 300 s, server {r.RecastS} s"));
            Assert.True(r.Range == 20, Sources.Cite("CL-CMD", $"Raise range: research 20, server {r.Range}"));
        }

        // Command, the status it gives (for the message), research seconds, tolerance, source.
        [Theory]
        [InlineData("provoke", "Attack Down", 30, 1, "RCAP-IFRIT")]
        [InlineData("sentinel", "Sentinel", 15, 1, "RCAP-IFRIT")]
        [InlineData("vengeance", "Vengeance", 15, 1, "RCAP-IFRIT")]
        [InlineData("antagonize", "Antagonize", 15, 1, "RCAP-IFRIT")]
        [InlineData("rampart", "Rampart", 60, 1, "RCAP-IFRIT")]
        [InlineData("invigorate", "Invigorate", 30, 1, "RCAP-IFRIT")]
        [InlineData("excruciate", "Excruciate", 30, 1, "RCAP-IFRIT")]
        [InlineData("collusion", "Collusion", 30, 1, "RCAP-IFRIT")]
        [InlineData("presence_of_mind", "Presence of Mind", 30, 1, "RCAP-IFRIT")]
        [InlineData("regen", "Regen", 45, 1, "RCAP-IFRIT")]
        [InlineData("protect", "Protect", 300, 1, "RCAP-IFRIT")]
        [InlineData("spinning_heel", "Spinning Heel", 20, 1, "RCAP-IFRIT")]
        [InlineData("taunt", "Taunted", 5, 0, "PN120-L")]
        [InlineData("hallowed_ground", "Hallowed Ground", 20, 0, "W2N")]
        [InlineData("tempered_will", "Tempered Will", 20, 0, "PN121-B")]
        [InlineData("mighty_strikes", "Mighty Strikes", 15, 0, "W2N")]
        [InlineData("riot_blade", "Defense Down", 30, 0, "PN120-L")]
        [InlineData("concussive_blow", "Blind", 30, 0, "PN120-L")]
        [InlineData("gloom_arrow", "Blind", 30, 0, "PN120-L")]
        [InlineData("leaden_arrow", "Heavy", 30, 0, "PN120-L")]
        [InlineData("blizzard", "Heavy", 30, 0, "PN120-L")]
        [InlineData("shadowbind", "Bind", 30, 0, "PN120-L")]
        [InlineData("blizzara", "Bind", 30, 0, "PN120-L")]
        [InlineData("sleep", "Sleep", 60, 0, "PN120-L")]
        [InlineData("repose", "Sleep", 60, 0, "PN120-L")]
        [InlineData("aura_pulse", "Slow", 30, 0, "PN120-L")]
        [InlineData("cover", "Cover", 15, 0, "PN121A")]
        [InlineData("life_surge", "Life Surge", 180, 0, "HF122A")]
        [InlineData("featherfoot", "Featherfoot", 30, 0, "PN120-L")]
        [InlineData("hawks_eye", "Hawk's Eye", 15, 0, "PN120-L")]
        [InlineData("shroud_of_saints", "Shroud of Saints", 20, 0, "PN120-L")]
        [InlineData("sacred_prism", "Sacred Prism", 60, 0, "PN120-L")]
        [InlineData("pounce", "Stun", 10, 1, "PN120-L")]
        [InlineData("shield_bash", "Stun", 5, 2, "PN120-L")]
        [InlineData("heavy_thrust", "Stun", 4, 1, "PN120-L")]
        [InlineData("leg_sweep", "Stun", 8, 1, "PN120-L")]
        [InlineData("thundara", "Stun", 4, 1, "PN120-L")]
        public void StatusDuration(string name, string status, int seconds, int tol, string source)
        {
            int got = Get(name, source).StatusDuration;
            Assert.True(Math.Abs(got - seconds) <= tol,
                Sources.Cite(source, $"{status} from {name}: research {seconds}{(tol > 0 ? $" ±{tol}" : "")} s, server {got} s"));
        }
    }
}
