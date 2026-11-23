using System;
using System.Linq;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // A reading fixes a value for one character whose tribe and allotted points are unknown, so a
    // test passes when some tribe and some legal allotment give that value.
    [Covers("stats.applyPlayerBaseStats", "stats.baseAttributes", "stats.bonusFor", "stats.profile", "stats.tribeOf", "stats.classOf", "stats.interp", "stats.expected")]
    [Collection("engines")]
    public sealed class PlayerScalingTests
    {
        private const int PGL = 2, GLA = 3, MRD = 4, LNC = 8;
        private const int STR = 0, VIT = 1, DEX = 2, INT = 3, MND = 4, PIE = 5, HP = 6, MP = 7, ATK = 8;
        private static readonly string[] Names = { "STR", "VIT", "DEX", "INT", "MND", "PIE", "HP", "MP", "attack" };

        private readonly FormulaScript lua;

        public PlayerScalingTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        private double[] Naked(int classId, int level, int tribe, params int[] points) =>
            lua.Call("nakedPlayerStats", new object[] { classId, level, tribe }
                .Concat(Enumerable.Range(0, 6).Select(i => (object)(i < points.Length ? points[i] : 0))).ToArray());

        // Lv8 and Lv9 Pugilist with no gear, before any attribute points.
        [Fact]
        public void PugilistLevels8And9()
        {
            const string source = "T-37927";
            var fits = Enumerable.Range(1, 15).Where(t => Naked(PGL, 8, t)[STR] == 35 && Naked(PGL, 9, t)[STR] == 37).ToList();
            Assert.True(fits.Count > 0, Sources.Cite(source,
                $"no tribe gives STR 35 at Lv8 and 37 at Lv9; Midlander gives {Naked(PGL, 8, 1)[STR]} and {Naked(PGL, 9, 1)[STR]}"));
            Assert.True(Naked(PGL, 8, fits[0])[ATK] == 74, Sources.Cite(source, $"Lv8 attack: expected 74, got {Naked(PGL, 8, fits[0])[ATK]}"));
            Assert.True(Naked(PGL, 9, fits[0])[ATK] == 77, Sources.Cite(source, $"Lv9 attack: expected 77, got {Naked(PGL, 9, fits[0])[ATK]}"));
        }

        // Lv50 readings of two attributes on one near-naked character.
        [Theory]
        [InlineData("BG-171", PGL, STR, 246, INT, 263)]
        [InlineData("BG-171", PGL, STR, 267, INT, 242)]
        [InlineData("T-36412", LNC, STR, 255, PIE, 244)]
        public void Level50Attributes(string source, int classId, int a, int aSeen, int b, int bSeen)
        {
            const int level = 50;
            int total = Meteor.Map.Actors.Player.BonusPointTotal(level), cap = Meteor.Map.Actors.Player.BonusPointCap(level);
            string closest = "";
            int best = int.MaxValue;
            for (int tribe = 1; tribe <= 15; tribe++)
            {
                var none = Naked(classId, level, tribe);
                int needA = aSeen - (int)none[a], needB = bSeen - (int)none[b];
                if (needA >= 0 && needB >= 0 && needA <= cap && needB <= cap && needA + needB <= total)
                    return;
                int miss = Math.Max(0, needA - cap) + Math.Max(0, needB - cap) + Math.Max(0, -needA) + Math.Max(0, -needB);
                if (miss < best)
                {
                    best = miss;
                    closest = $"tribe {tribe} with no points: {Names[a]} {none[a]}, {Names[b]} {none[b]}";
                }
            }
            Assert.Fail(Sources.Cite(source,
                $"Lv50 class {classId} {Names[a]} {aSeen} / {Names[b]} {bSeen} needs more than {cap} points in one attribute; closest is {closest}"));
        }

        // Max HP and MP retail sent for geared characters. Gear only adds, so the least a naked
        // character of that class and level can have must not be above them.
        [Theory]
        [InlineData(MRD, 26, 758, 249, "login f17")]
        [InlineData(GLA, 27, 750, 405, "party_battle_leve f3453")]
        [InlineData(GLA, 31, 1016, 548, "gridania_to_coerthas f184")]
        [InlineData(PGL, 50, 2634, 1914, "war_quest_update2 f639")]
        public void HpAndMpNotAboveCapture(int classId, int level, int hpSeen, int mpSeen, string where)
        {
            const string source = "CAP-HPMP";
            var least = Enumerable.Range(1, 15).Select(t => Naked(classId, level, t)).ToList();
            double hp = least.Min(s => s[HP]), mp = least.Min(s => s[MP]);
            Assert.True(hp <= hpSeen, Sources.Cite(source, $"class {classId} Lv{level} {where}: retail HP {hpSeen}, server's least is {hp}"));
            Assert.True(mp <= mpSeen, Sources.Cite(source, $"class {classId} Lv{level} {where}: retail MP {mpSeen}, server's least is {mp}"));
        }

        [Theory]
        [InlineData(PGL, 20)]
        [InlineData(LNC, 50)]
        public void ThreeStrengthIsTwoAttack(int classId, int level)
        {
            double before = Naked(classId, level, 1)[ATK], after = Naked(classId, level, 1, 3)[ATK];
            Assert.True(Math.Abs(after - before - 2) <= 0.5,
                Sources.Cite("KAN-III", $"class {classId} Lv{level}: +3 STR moved attack {before} → {after}"));
        }

        [Theory]
        [InlineData(GLA, 30)]
        [InlineData(PGL, 50)]
        public void OneVitalityIsOneHp(int classId, int level)
        {
            double before = Naked(classId, level, 1)[HP], after = Naked(classId, level, 1, 0, 4)[HP];
            Assert.True(after - before == 4, Sources.Cite("T-28942", $"class {classId} Lv{level}: +4 VIT moved HP {before} → {after}"));
        }

        [Theory]
        [InlineData(GLA, 30)]
        [InlineData(LNC, 50)]
        public void OnePietyIsOneMp(int classId, int level)
        {
            double before = Naked(classId, level, 1)[MP], after = Naked(classId, level, 1, 0, 0, 0, 0, 0, 4)[MP];
            Assert.True(after - before == 4, Sources.Cite("T-28942", $"class {classId} Lv{level}: +4 PIE moved MP {before} → {after}"));
        }
    }
}
