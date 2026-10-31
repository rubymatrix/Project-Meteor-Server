using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Xunit;
using Xunit.Abstractions;

namespace Meteor.Map.Tests.Formulas
{
    // The item sheet's gear: armour DEF and evasion, weapon damage and delay, item level, class and
    // slot, read from Data/sql/gamedata_items*.sql.
    internal static class GearCatalog
    {
        internal sealed class Item
        {
            public int Id, Level, MainSkill, Compatibility, EquipPoint;
            public double Defense, Evasion, Damage, Delay;
            public bool IsArmor, IsWeapon;
        }

        private static readonly Lazy<Dictionary<int, Item>> items = new Lazy<Dictionary<int, Item>>(Load);

        // gamedata_compatibility: per group, each class's share (0-100) of an item's stats.
        private static readonly Lazy<Dictionary<int, int[]>> compat = new Lazy<Dictionary<int, int[]>>(() =>
        {
            var path = Path.Combine(EngineHarness.SeedDir(), "gamedata_compatibility.sql");
            var all = new Dictionary<int, int[]>();
            foreach (Match m in Regex.Matches(File.ReadAllText(path), @"VALUES\s*\(([\d,]+)\)"))
            {
                var v = m.Groups[1].Value.Split(',').Select(int.Parse).ToArray();
                all[v[0]] = v;
            }
            return all;
        });

        // The share of an item's stats this class gets; job columns are numbered by class id.
        public static double Share(Item i, int classId) =>
            compat.Value.TryGetValue(i.Compatibility, out var v) && classId >= 1 && classId < v.Length ? v[classId] / 100.0 : 1.0;

        public static Item Get(int id) => items.Value.TryGetValue(id, out var i) ? i : null;

        private static IEnumerable<string[]> Rows(string table)
        {
            var path = Path.Combine(EngineHarness.SeedDir(), table + ".sql");
            var prefix = $"INSERT INTO `{table}` VALUES (";
            foreach (var line in File.ReadLines(path))
                if (line.StartsWith(prefix, StringComparison.Ordinal))
                    yield return Split(line.Substring(prefix.Length, line.LastIndexOf(')') - prefix.Length));
        }

        // SQL values split on commas outside quotes; \' and '' escape a quote.
        private static string[] Split(string s)
        {
            var parts = new List<string>();
            var cur = new System.Text.StringBuilder();
            bool quoted = false;
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (quoted && c == '\\' && i + 1 < s.Length) { cur.Append(s[++i]); continue; }
                if (c == '\'')
                {
                    if (quoted && i + 1 < s.Length && s[i + 1] == '\'') { cur.Append('\''); i++; }
                    else quoted = !quoted;
                }
                else if (c == ',' && !quoted) { parts.Add(cur.ToString()); cur.Clear(); }
                else cur.Append(c);
            }
            parts.Add(cur.ToString());
            return parts.ToArray();
        }

        private static double D(string s) => double.Parse(s, CultureInfo.InvariantCulture);

        private static Dictionary<int, Item> Load()
        {
            var all = new Dictionary<int, Item>();
            foreach (var r in Rows("gamedata_items"))
                all[(int)D(r[0])] = new Item { Id = (int)D(r[0]), MainSkill = (int)D(r[12]), Level = (int)D(r[15]), Compatibility = (int)D(r[16]) };
            foreach (var r in Rows("gamedata_items_equipment"))
                if (all.TryGetValue((int)D(r[0]), out var i)) i.EquipPoint = (int)D(r[1]);
            foreach (var r in Rows("gamedata_items_armor"))
                if (all.TryGetValue((int)D(r[0]), out var i)) { i.IsArmor = true; i.Defense = D(r[1]); i.Evasion = D(r[4]); }
            foreach (var r in Rows("gamedata_items_weapon"))
                if (all.TryGetValue((int)D(r[0]), out var i)) { i.IsWeapon = true; i.Damage = D(r[21]); i.Delay = D(r[22]); }
            return all;
        }

        // The armour slots, as the item sheet's equip points.
        public static IEnumerable<int> ArmorPoints =>
            items.Value.Values.Where(i => i.IsArmor && i.EquipPoint > 0).Select(i => i.EquipPoint).Distinct().OrderBy(p => p);

        // Gear a player of this level can buy: the best piece no more than five levels under it, or
        // the newest below that.
        public static Item Best(IEnumerable<Item> pool, int level, Func<Item, double> score)
        {
            var usable = pool.Where(i => i.Level >= 1 && i.Level <= level).ToList();
            var recent = usable.Where(i => i.Level >= level - 5).ToList();
            return (recent.Count > 0 ? recent : usable)
                .OrderByDescending(i => recent.Count > 0 ? score(i) : i.Level).ThenByDescending(score).FirstOrDefault();
        }

        public static Item Weapon(int classId, int level) =>
            Best(items.Value.Values.Where(i => i.IsWeapon && i.MainSkill == classId && i.Damage > 0 && i.Delay > 0), level, i => i.Damage / i.Delay);

        public static IEnumerable<Item> Armor(int classId, int level) =>
            ArmorPoints.Select(p => Best(items.Value.Values.Where(i => i.IsArmor && i.EquipPoint == p && Share(i, classId) >= 1), level, i => i.Defense))
                .Where(i => i != null);

        // Each class's starting gear, as Player.lua hands it out.
        private static readonly Lazy<Dictionary<int, int[]>> starter = new Lazy<Dictionary<int, int[]>>(() =>
        {
            var lua = File.ReadAllText(Path.Combine(EngineFixture.ScriptsDir, "Player.lua"));
            var sets = new Dictionary<int, int[]>();
            foreach (Match m in Regex.Matches(lua, @"state_mainSkill\[0\] == (\d+) then[^\n]*\n\s*player:GetItemPackage\(0\):AddItems\(\{([\d, ]+)\}\)"))
                sets[int.Parse(m.Groups[1].Value)] = m.Groups[2].Value.Split(',').Select(s => int.Parse(s.Trim())).ToArray();
            return sets;
        });

        public static int[] Starter(int classId) => starter.Value.TryGetValue(classId, out var s) ? s : null;
    }

    // Every combat class, in the gear it can have at each level, solos a same-level monster.
    [Collection("engines")]
    public sealed class SoloFightTests
    {
        // Player's HP share left after a same-level fight, auto-attacks and a class nuke only.
        public const double MIN_HP_LEFT = 0.30;
        // Starting gear until the first shop upgrades (Lv1 shop gear onward).
        public const int STARTER_UNTIL = 4;

        private readonly FormulaScript lua;
        private readonly ITestOutputHelper output;

        public SoloFightTests(EngineFixture engines, ITestOutputHelper output)
        {
            lua = new FormulaScript(engines, "combat_damage");
            this.output = output;
        }

        // classId, nuke magnitude, cast s, recast s, MP permille, INT and MND weights (the class's
        // level-1 attack spell, from its script and command row).
        private static readonly Dictionary<int, double[]> Nukes = new Dictionary<int, double[]>
        {
            [22] = new[] { 1050, 2.0, 6, 75, 0.5, 0 },     // THM Thunder
            [23] = new[] { 950, 2.0, 6, 75, 0.25, 0.25 },  // CNJ Stone
        };

        public static IEnumerable<object[]> Cases()
        {
            foreach (var cls in new[] { 2, 3, 4, 7, 8, 22, 23 })
                foreach (var lv in new[] { 1, 3, 5, 7, 10, 15, 20, 25, 30, 35, 40, 45, 50 })
                    yield return new object[] { cls, lv };
        }

        private static (GearCatalog.Item weapon, List<GearCatalog.Item> armor) Gear(int classId, int level)
        {
            if (level < STARTER_UNTIL && GearCatalog.Starter(classId) is int[] set)
            {
                var items = set.Select(GearCatalog.Get).Where(i => i != null).ToList();
                return (items.FirstOrDefault(i => i.IsWeapon), items.Where(i => i.IsArmor).ToList());
            }
            return (GearCatalog.Weapon(classId, level), GearCatalog.Armor(classId, level).ToList());
        }

        // Below Lv26 a monster's swing on an even-level player takes 5-9% of max HP, in any gear.
        [Theory]
        [MemberData(nameof(Cases))]
        public void EvenLevelSwingShareInRealGear(int classId, int level)
        {
            if (level >= 26)
                return;
            var (_, armor) = Gear(classId, level);
            double def = armor.Sum(i => i.Defense * GearCatalog.Share(i, classId));
            double share = lua.One("swingShare", classId, level, level, def);
            Assert.True(share >= 0.05 && share <= 0.09,
                Sources.Cite("CAP-OPEN", $"class {classId} Lv{level}, DEF {def}: even-level swing {share:P1} of max HP, retail 5-9%"));
        }

        // Three levels up: the Lv26-27 leve rows reach 9.4%.
        [Theory]
        [MemberData(nameof(Cases))]
        public void SwingThreeLevelsUpInRealGear(int classId, int level)
        {
            if (level >= 26)
                return;
            var (_, armor) = Gear(classId, level);
            double def = armor.Sum(i => i.Defense * GearCatalog.Share(i, classId));
            double share = lua.One("swingShare", classId, level, level + 3, def);
            Assert.True(share <= 0.10,
                Sources.Cite("CAP-WS", $"class {classId} Lv{level}, DEF {def}: Lv{level + 3} swing {share:P1} of max HP, retail at most 9.4%"));
        }

        [Theory]
        [MemberData(nameof(Cases))]
        public void SameLevelMonsterIsSoloable(int classId, int level)
        {
            var (weapon, armor) = Gear(classId, level);
            Assert.True(weapon != null, $"class {classId} Lv{level}: no weapon in the item sheet");
            double def = armor.Sum(i => i.Defense * GearCatalog.Share(i, classId)), eva = armor.Sum(i => i.Evasion * GearCatalog.Share(i, classId));
            Nukes.TryGetValue(classId, out var n);
            var r = lua.Call("soloFight", classId, level, weapon.Damage, weapon.Delay, def, eva,
                n?[0] ?? 0, n?[1] ?? 0, n?[2] ?? 0, n?[3] ?? 0, n?[4] ?? 0, n?[5] ?? 0);
            double left = r[0], seconds = r[1];
            output.WriteLine($"class {classId} Lv{level}: weapon {weapon.Id} {weapon.Damage}/{weapon.Delay}s, DEF {def}, EVA {eva}: {left:P0} HP left after {seconds:F0} s");
            Assert.True(left >= MIN_HP_LEFT,
                $"class {classId} Lv{level} (weapon {weapon.Id} {weapon.Damage}/{weapon.Delay}s, DEF {def}) against a Lv{level} monster: {left:P0} HP left after {seconds:F0} s, need {MIN_HP_LEFT:P0} [DESIGN]");
        }
    }
}
