using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Enmity the action and status scripts generate, against the retail enmity tests.
    [Collection("engines")]
    public sealed class RulesEnmityTests
    {
        private const int Sentinel = 223062;

        private readonly FormulaScript lua;

        public RulesEnmityTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_rules");
        }

        private static void InBand(double got, double low, double high, string id, string what) =>
            Assert.True(got >= low && got <= high, Sources.Cite(id, $"{what}: research {low}-{high}, server {got}"));

        private static void Near(double got, double want, double tol, string id, string what) =>
            Assert.True(System.Math.Abs(got - want) <= tol, Sources.Cite(id, $"{what}: research {want} ±{tol}, server {got}"));

        [Fact]
        public void HealEnmityPerHp()
        {
            var r = lua.Call("healEnmity", 1000, 3000, false);
            InBand(r[0] / r[1], 0.55, 0.65, "T-36468", "Enmity per HP healed");
        }

        [Fact]
        public void CureOnFullHpTargetMakesNoEnmity()
        {
            var r = lua.Call("healEnmity", 1000, 0, false);
            Assert.True(r[0] == 0, Sources.Cite("PN121-B", $"Cure on a full-HP target: research 0 enmity, server {r[0]}"));
        }

        [Fact]
        public void ProvokeAtLevel50()
        {
            InBand(lua.One("abilityEnmity", "Command/Ability/Provoke", 50), 550, 571, "T-36468", "Provoke at Lv50");
        }

        [Fact]
        public void FlashAtLevel50()
        {
            InBand(lua.One("abilityEnmity", "Command/Ability/Flash", 50), 375, 400, "T-36468", "Flash at Lv50, per enemy hit");
        }

        [Fact]
        public void RampartAtLevel50()
        {
            Near(lua.One("abilityEnmity", "Command/Ability/Rampart", 50), 190, 190 * 0.05, "T-36468", "Rampart at Lv50, per player hit");
        }

        [Fact]
        public void WarDrumFlatEnmity()
        {
            Near(lua.One("flatWeaponskillEnmity", "Command/WeaponSkill/WarDrum", 50), 380, 380 * 0.05, "T-36468",
                "War Drum at Lv50, enmity on top of its damage");
        }

        [Fact]
        public void HallowedGroundOnUse()
        {
            Near(lua.One("singleMobEnmity", "Command/Ability/HallowedGround", 50), 1140, 1140 * 0.05, "T-36468",
                "Hallowed Ground at Lv50 on one enemy");
        }

        [Fact]
        public void ChameleonNotSplitBetweenEnemies()
        {
            var r = lua.Call("areaEnmity", "Command/Ability/Chameleon", 50);
            Near(r[0], -840, 840 * 0.05, "T-36468", "Chameleon at Lv50, first of two enemies");
            Near(r[1], -840, 840 * 0.05, "T-36468", "Chameleon at Lv50, second of two enemies");
        }

        [Fact]
        public void FreezeEnmity()
        {
            var r = lua.Call("freezeEnmity", 50);
            Assert.True(r[0] == 0, Sources.Cite("T-36468", $"Freeze damage enmity: research 0, server {r[0]}"));
            Near(r[1], -720, 720 * 0.05, "T-36468", "Freeze enmity cut at Lv50");
        }

        [Fact]
        public void ProvokeSlopeNearLevel50()
        {
            double diff = lua.One("abilityEnmity", "Command/Ability/Provoke", 50) - lua.One("abilityEnmity", "Command/Ability/Provoke", 48);
            InBand(diff, 27, 36, "T-36468", "Provoke(Lv50) - Provoke(Lv48)");
        }

        [Theory]
        [InlineData("Command/WeaponSkill/FlatBlade", 5.5)]
        [InlineData("Command/WeaponSkill/SkullSunder", 2.75)]
        [InlineData("Command/WeaponSkill/SpiritsWithin", 2.5)]
        public void ComboEnmityMultiplier(string script, double want)
        {
            Near(lua.Call("comboEnmityRatio", script, null)[0], want, 0.1, "T-36468", $"{script} comboed, enmity per damage");
        }

        [Fact]
        public void FlatBladeMultiplierIgnoresMind()
        {
            double at240 = lua.Call("comboEnmityRatio", "Command/WeaponSkill/FlatBlade", 240)[0];
            double at320 = lua.Call("comboEnmityRatio", "Command/WeaponSkill/FlatBlade", 320)[0];
            Near(at320, at240, 0.1, "T-50479", "Flat Blade combo multiplier at 320 MND vs 240 MND");
        }

        [Fact]
        public void SentinelScalesDamageEnmity()
        {
            Near(lua.One("enmityScale", true, 0, 0), 1.2, 0.02, "T-36468", "Sentinel enmity multiplier");
        }

        [Fact]
        public void SentinelScalesFlash()
        {
            double plain = lua.One("abilityEnmity", "Command/Ability/Flash", 50, 0);
            double with = lua.One("abilityEnmity", "Command/Ability/Flash", 50, Sentinel);
            Near(with / plain, 1.2, 0.02, "T-36468", "Flash enmity under Sentinel, as a multiple of without");
        }

        [Fact]
        public void SentinelDoesNotScaleHeals()
        {
            double plain = lua.Call("healEnmity", 1000, 3000, false)[0];
            double with = lua.Call("healEnmity", 1000, 3000, true)[0];
            Near(with / plain, 1.0, 0.02, "T-36468", "Heal enmity under Sentinel, as a multiple of without");
        }

        [Fact]
        public void SentinelDoesNotScaleRampart()
        {
            double plain = lua.One("abilityEnmity", "Command/Ability/Rampart", 50, 0);
            double with = lua.One("abilityEnmity", "Command/Ability/Rampart", 50, Sentinel);
            Near(with / plain, 1.0, 0.02, "T-36468", "Rampart enmity under Sentinel, as a multiple of without");
        }

        [Theory]
        [InlineData(1, 1.5)]
        [InlineData(2, 1.65)]
        public void AntagonizeMultiplier(int tier, double want)
        {
            Near(lua.One("enmityScale", false, tier, 0), want, 0.02, "BG-107403", $"Antagonize tier {tier} enmity multiplier");
        }

        [Fact]
        public void EnmityGearPerPoint()
        {
            Near(lua.One("enmityScale", false, 0, 100), 1.10, 0.02, "PN122", "+100 Enmity from gear, enmity multiplier");
        }

        [Fact]
        public void ShroudOfSaintsHalvesEnmity()
        {
            Near(lua.One("shroudEnmity", 1000) / 1000, 0.5, 0.05, "PN120A", "Shroud of Saints enmity multiplier");
        }
    }
}
