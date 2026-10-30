using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Status scripts and the ability or spell scripts that size them, run against stand-in actors.
    [Collection("engines")]
    public sealed class RulesStatusTests
    {
        private const int Weaponskill = 2;
        private const int Ability = 3;

        private readonly FormulaScript lua;

        public RulesStatusTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_rules");
        }

        private static void Near(double got, double want, double tol, string id, string what) =>
            Assert.True(System.Math.Abs(got - want) <= tol, Sources.Cite(id, $"{what}: research {want} ±{tol}, server {got}"));

        private static void Exact(double got, double want, string id, string what) =>
            Assert.True(got == want, Sources.Cite(id, $"{what}: research {want}, server {got}"));

        [Theory]
        [InlineData(1, 30)]
        [InlineData(2, 50)]
        public void SentinelDamageTaken(int tier, double percentDown)
        {
            Near(lua.One("damageTakenDown", "Status/Sentinel", tier), percentDown, 5, "BG-107403", $"Sentinel tier {tier} damage taken down %");
        }

        [Theory]
        [InlineData(97, 73)]
        [InlineData(87, 65)]
        public void BloodbathDrain(int damage, int drained)
        {
            var r = lua.Call("bloodbath", damage, Weaponskill);
            Exact(r[0], drained, "CAP-PBL", $"Bloodbath drain on a {damage} weaponskill");
            Exact(r[1], 1, "CAP-PBL", "Bloodbath consumed by that weaponskill (1 = yes)");
        }

        [Theory]
        [InlineData(758, 75)]
        [InlineData(652, 65)]
        [InlineData(644, 64)]
        [InlineData(735, 73)]
        public void BloodForBloodHpCost(int hp, int cost)
        {
            Exact(lua.Call("bloodForBlood", hp, Weaponskill)[0], cost, "CAP-CS", $"Blood for Blood HP cost at {hp} HP");
        }

        [Fact]
        public void NextAttackBuffsNotConsumedByThrowOrShot()
        {
            var bfb = lua.Call("bloodForBlood", 758, Ability);
            Exact(bfb[1], 0, "PN121-B", "Blood for Blood consumed by Throw/Light Shot (1 = yes)");
            Exact(bfb[0], 0, "PN121-B", "Blood for Blood HP cost on Throw/Light Shot");
            Exact(lua.Call("bloodbath", 97, Ability)[1], 0, "PN120-B", "Bloodbath consumed by a non-weaponskill (1 = yes)");
        }

        [Theory]
        [InlineData(56)]
        [InlineData(63)]
        public void AegisBoonBlocksAndRestores(int swing)
        {
            var r = lua.Call("aegisBoon", swing);
            Exact(r[0], 100, "CAP-PBL", $"Aegis Boon block rate against a {swing} swing");
            Exact(r[1], 1, "CAP-PBL", "Aegis Boon block reduction (1 = fully blocked, 0 damage)");
            Assert.True(r[2] >= 136 && r[2] <= 161, Sources.Cite("CAP-PBL", $"Aegis Boon HP restored after a {swing} swing: research 136-161, server {r[2]}"));
            Exact(r[3], 1, "CAP-PBL", "Aegis Boon ends on that hit (1 = yes)");
        }

        [Theory]
        [InlineData(383, false, 600)]
        [InlineData(404, false, 633)]
        [InlineData(393, true, 770)]
        public void StoneskinAbsorb(int potency, bool enhanced, double absorb)
        {
            Near(lua.One("stoneskin", potency, enhanced), absorb, absorb * 0.03, "BG-107403",
                $"Stoneskin absorb at {potency} Enhancing potency{(enhanced ? ", Enhanced Stoneskin" : "")}");
        }

        [Fact]
        public void PresenceOfMindInstantRaise()
        {
            var r = lua.Call("presenceOfMind", 10000);
            Near(r[0] / 1000, 0, 1, "RCAP-IFRIT", "Raise cast time (s) under Presence of Mind");
            Exact(r[2], 1, "PN121J", "Presence of Mind consumed by the next spell (1 = yes)");
        }

        [Fact]
        public void SpinningHeelAddsAKick()
        {
            Exact(lua.One("spinningHeel", 2), 3, "CAP-WQU2", "Hits per fist auto-attack under Spinning Heel");
        }

        [Theory]
        [InlineData(1, 140)]
        [InlineData(2, 175)]
        public void FeatherfootMpOnEvade(int tier, int mp)
        {
            var r = lua.Call("featherfoot", tier);
            Exact(r[0], mp, "VID-Q0HO", $"Featherfoot tier {tier} MP on evade");
            Exact(r[1], 1, "VID-Q0HO", "Featherfoot ends on that evade (1 = yes)");
        }

        [Theory]
        [InlineData("Status/FistsOfFire", "Attack", 1, 1.20)]
        [InlineData("Status/FistsOfFire", "Attack", 2, 1.25)]
        [InlineData("Status/FistsOfEarth", "Defense", 1, 1.20)]
        [InlineData("Status/FistsOfEarth", "Defense", 2, 1.25)]
        public void FistsStatBonus(string script, string stat, int tier, double share)
        {
            Near(lua.Call("fists", script, stat, tier, false)[0], share, 1e-9, "W2N", $"{script} tier {tier} {stat} multiplier");
        }

        [Theory]
        [InlineData("Status/FistsOfFire", false, 28)]
        [InlineData("Status/FistsOfFire", true, 25)]
        [InlineData("Status/FistsOfEarth", false, 28)]
        [InlineData("Status/FistsOfEarth", true, 25)]
        public void FistsMpUpkeep(string script, bool afBody, int mp)
        {
            Exact(lua.Call("fists", script, "Attack", 1, afBody)[1], mp, "SEF-43454", $"{script} MP per tick{(afBody ? " with the AF body" : "")}");
        }

        [Theory]
        [InlineData("Command/Magic/BalladOfMagi", 50, false, 20)]
        [InlineData("Command/Magic/PaeonOfWar", 50, false, 50)]
        [InlineData("Command/Magic/MinuetOfRigor", 50, false, 35)]
        [InlineData("Command/Magic/MinuetOfRigor", 45, false, 30)]
        public void SongMagnitude(string script, int level, bool battleVoice, int want)
        {
            Exact(lua.One("songMagnitude", script, level, battleVoice, null), want, "SEF-39924", $"{script} at Lv{level}");
        }

        [Theory]
        [InlineData("Command/Magic/BalladOfMagi", 40)]
        [InlineData("Command/Magic/PaeonOfWar", 100)]
        [InlineData("Command/Magic/MinuetOfRigor", 71)]
        public void SongUnderBattleVoice(string script, int want)
        {
            Exact(lua.One("songMagnitude", script, 50, true, null), want, "SEF-44650", $"{script} at Lv50 under Battle Voice");
        }

        [Theory]
        [InlineData("Command/Magic/BalladOfMagi")]
        [InlineData("Command/Magic/PaeonOfWar")]
        [InlineData("Command/Magic/MinuetOfRigor")]
        public void SongIgnoresPiety(string script)
        {
            double low = lua.One("songMagnitude", script, 50, false, 241);
            double high = lua.One("songMagnitude", script, 50, false, 322);
            Exact(high, low, "SEF-39924", $"{script} at 322 PIE vs 241 PIE");
        }

        [Fact]
        public void SongStatusesGiveTheirMagnitude()
        {
            Exact(lua.Call("statusMods", "Status/BalladOfMagi", 20, "Refresh", null)[0], 20, "SEF-39924", "Ballad of Magi MP per tick");
            Exact(lua.Call("statusMods", "Status/PaeonOfWar", 50, "Regain", null)[0], 50, "SEF-39924", "Paeon of War TP per tick");
            var minuet = lua.Call("statusMods", "Status/MinuetOfRigor", 35, "Accuracy", "MagicAccuracy");
            Exact(minuet[0], 35, "SEF-39924", "Minuet of Rigor accuracy");
            Exact(minuet[1], 35, "SEF-39924", "Minuet of Rigor magic accuracy");
        }

        [Theory]
        [InlineData(1, 85)]
        [InlineData(2, 113)]
        public void DivineRegenPerTick(int tier, int hp)
        {
            Exact(lua.Call("divineRegen", tier)[0], hp, "SEF-43454", $"Divine Regen HP per tick, Divine Veil tier {tier}");
            Exact(lua.Call("statusMods", "Status/DivineRegen", hp, "Regen", null)[0], hp, "SEF-43454", "Divine Regen status regen");
        }

        [Fact]
        public void InvigorateTpPerTick()
        {
            Exact(lua.Call("invigorate", false, 30, false)[0], 100, "CAP-PBL", "Invigorate TP per tick");
            Exact(lua.Call("invigorate", false, 30, true)[0], 120, "BG-107403", "Invigorate TP per tick with the AF body");
            Exact(lua.Call("statusMods", "Status/Invigorate", 100, "Regain", null)[0], 100, "CAP-PBL", "Invigorate status regain");
        }

        [Fact]
        public void InvigorateDuration()
        {
            Near(lua.Call("invigorate", false, 30, false)[1], 30, 1, "RCAP-IFRIT", "Invigorate duration (s)");
            Near(lua.Call("invigorate", true, 30, false)[1], 45, 1, "RCAP-IFRIT", "Enhanced Invigorate duration (s)");
        }

        [Fact]
        public void PoisonTickAtLevel50()
        {
            Exact(lua.One("poisonTick", 50), 14, "KAN-II", "Poison HP per tick at Lv50");
        }
    }
}
