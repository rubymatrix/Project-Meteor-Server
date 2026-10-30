using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Meteor.Map.DataObjects;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Consumable effects: the seed rows in server_items_consumable through ConsumableData.Effect.Compute.
    public sealed class EngineConsumableTests
    {
        private const uint MOD_HP = 0, MOD_MP = 1, MOD_STR = 3, MOD_ATTACK = 17;

        // Each row's effects as the server reads them: "modifier:pct:cap;...".
        private static readonly Dictionary<string, List<ConsumableData.Effect>> rows = Load();

        private static Dictionary<string, List<ConsumableData.Effect>> Load()
        {
            var sql = File.ReadAllText(Path.Combine(EngineHarness.SeedDir(), "server_items_consumable.sql"));
            var result = new Dictionary<string, List<ConsumableData.Effect>>();
            foreach (Match m in Regex.Matches(sql, @"VALUES \(\d+,'((?:[^']|'')*)','[a-z]+',\d+,'([^']*)'"))
            {
                var effects = new List<ConsumableData.Effect>();
                foreach (var part in m.Groups[2].Value.Split(';', System.StringSplitOptions.RemoveEmptyEntries))
                {
                    var f = part.Split(':');
                    var e = new ConsumableData.Effect { modifier = uint.Parse(f[0]) };
                    if (f.Length == 2 && f[1].StartsWith("="))
                    {
                        e.isFlat = true;
                        e.flat = int.Parse(f[1].Substring(1), CultureInfo.InvariantCulture);
                    }
                    else
                    {
                        e.pct = double.Parse(f[1], CultureInfo.InvariantCulture);
                        e.cap = f.Length > 2 ? int.Parse(f[2], CultureInfo.InvariantCulture) : 0;
                    }
                    effects.Add(e);
                }
                result[m.Groups[1].Value.Replace("''", "'")] = effects;
            }
            return result;
        }

        private static int Amount(string item, uint modifier, double stat)
        {
            Assert.True(rows.ContainsKey(item), item + " is in server_items_consumable");
            var e = rows[item].Where(x => x.modifier == modifier).ToList();
            Assert.True(e.Count == 1, $"{item} has one effect on modifier {modifier}");
            return e[0].Compute(stat);
        }

        [Fact]
        public void FoodIsAPercentOfTheStatUpToItsCap()
        {
            int a = Amount("Eft Steak", MOD_ATTACK, 600);
            Assert.True(a == 42, Sources.Cite("PN121-I", $"Eft Steak (attack +7%, max 51) on 600 attack: +42, got {a}"));
            int b = Amount("Eft Steak", MOD_ATTACK, 740);
            Assert.True(b == 51, Sources.Cite("PN121-I", $"Eft Steak on 740 attack: +51 (capped), got {b}"));
        }

        [Fact]
        public void HpPotionsOnA2634HpPlayer()
        {
            (string item, int amount)[] cases = { ("Potion", 100), ("Hi-potion", 300), ("Mega-potion", 526) };
            foreach (var (item, amount) in cases)
            {
                int got = Amount(item, MOD_HP, 2634);
                Assert.True(got == amount, Sources.Cite("EL-MED", $"{item} on 2634 max HP: {amount}, got {got}"));
            }
        }

        [Fact]
        public void MpPotionsOnA1914MpPlayer()
        {
            (string item, int amount)[] cases = { ("Ether", 100), ("Hi-ether", 300), ("Mega-ether", 382) };
            foreach (var (item, amount) in cases)
            {
                int got = Amount(item, MOD_MP, 1914);
                Assert.True(got == amount, Sources.Cite("EL-MED", $"{item} on 1914 max MP: {amount}, got {got}"));
            }
        }

        [Fact]
        public void ElixirRestoresHalfHpAndAThirdOfMpUpToTheirCaps()
        {
            int hp = Amount("Elixir", MOD_HP, 5000);
            Assert.True(hp == 2000, Sources.Cite("EL-MED", $"Elixir HP min(50%, 2000) on 5000: 2000, got {hp}"));
            int hpLow = Amount("Elixir", MOD_HP, 2634);
            Assert.True(hpLow == 1317, Sources.Cite("EL-MED", $"Elixir HP min(50%, 2000) on 2634: 1317, got {hpLow}"));
            int mp = Amount("Elixir", MOD_MP, 1914);
            Assert.True(mp == 574, Sources.Cite("EL-MED", $"Elixir MP min(30%, 1050) on 1914: 574, got {mp}"));
            int mpHigh = Amount("Elixir", MOD_MP, 4000);
            Assert.True(mpHigh == 1050, Sources.Cite("EL-MED", $"Elixir MP min(30%, 1050) on 4000: 1050, got {mpHigh}"));
        }

        [Fact]
        public void MegaPotionOfStrength()
        {
            int str = Amount("Mega-potion of Strength", MOD_STR, 200);
            Assert.True(str == 28, Sources.Cite("EL-MED", $"STR +14% (cap 40) on 200: 28, got {str}"));
            int strCap = Amount("Mega-potion of Strength", MOD_STR, 400);
            Assert.True(strCap == 40, Sources.Cite("EL-MED", $"STR +14% (cap 40) on 400: 40, got {strCap}"));
            int atk = Amount("Mega-potion of Strength", MOD_ATTACK, 500);
            Assert.True(atk == 90, Sources.Cite("PN121-B", $"attack +18% (cap 125) on 500: 90, got {atk}"));
            int atkCap = Amount("Mega-potion of Strength", MOD_ATTACK, 800);
            Assert.True(atkCap == 125, Sources.Cite("PN121-B", $"attack +18% (cap 125) on 800: 125, got {atkCap}"));
        }
    }
}
