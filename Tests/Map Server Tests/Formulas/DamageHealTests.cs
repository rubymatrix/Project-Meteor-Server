using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Heals: Cure magnitude 1000, Cura 2000.
    [Collection("engines")]
    public sealed class DamageHealTests
    {
        private const int Gladiator = 3;
        private const int Thaumaturge = 22;
        private const int Conjurer = 23;

        private readonly FormulaScript lua;

        public DamageHealTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        private double Heal(int classId, int level, int magnitude, double? hmp, double? mnd, double? vit, double? roll = null) =>
            lua.One("healAmount", classId, level, magnitude, hmp, mnd, vit, roll);

        [Fact]
        public void CureFromGearedWhiteMage()
        {
            double got = Heal(Conjurer, 50, 1000, 484, 303, 186);
            Assert.True(got >= 601 && got <= 635,
                Sources.Cite("BG-285", $"Lv50 WHM Cure, 484 HMP / 303 MND / 186 VIT: retail 601-635, server {got}"));
        }

        [Fact]
        public void CuraFromGearedWhiteMage()
        {
            double got = Heal(Conjurer, 50, 2000, 484, 303, 186);
            Assert.True(got >= 1222 && got <= 1275,
                Sources.Cite("BG-285", $"Lv50 WHM Cura, 484 HMP / 303 MND / 186 VIT: retail 1222-1275, server {got}"));
        }

        // Per-point Cure slopes, measured over 10000 points; low/high carry one HP of rounding.
        [Theory]
        [InlineData(Conjurer, "HMP", 1.25)]
        [InlineData(Conjurer, "MND", 0.25)]
        [InlineData(Thaumaturge, "HMP", 1.10)]
        [InlineData(Thaumaturge, "MND", 0.0)]
        public void CurePerPoint(int classId, string stat, double expected)
        {
            const int step = 10000;
            double baseline = Heal(classId, 50, 1000, 400, 300, 186);
            double raised = stat == "HMP" ? Heal(classId, 50, 1000, 400 + step, 300, 186) : Heal(classId, 50, 1000, 400, 300 + step, 186);
            double perPoint = (raised - baseline) / step;
            Assert.True(perPoint >= expected - 0.1 - 1.0 / step && perPoint <= expected + 0.1 + 1.0 / step,
                Sources.Cite("KAN-I", $"class {classId} Cure per +1 {stat}: retail {expected} +-0.1, server {perPoint:F3}"));
        }

        [Fact]
        public void CurePerVitalityPoint()
        {
            const int step = 10000;
            double perPoint = (Heal(Conjurer, 50, 1000, 400, 300, 186 + step) - Heal(Conjurer, 50, 1000, 400, 300, 186)) / step;
            Assert.True(perPoint >= 0.0 - 1.0 / step && perPoint <= 0.25 + 1.0 / step,
                Sources.Cite("KAN-I", $"Cure per +1 VIT: retail 0.1-0.15 +-0.1, server {perPoint:F3}"));
        }

        [Fact]
        public void CureSpread()
        {
            double low = Heal(Conjurer, 50, 1000, 20000, 300, 186, 0.0);
            double mid = Heal(Conjurer, 50, 1000, 20000, 300, 186, 0.5);
            double high = Heal(Conjurer, 50, 1000, 20000, 300, 186, 1.0);
            Assert.True(System.Math.Abs(low / mid - 0.97) < 0.001 && System.Math.Abs(high / mid - 1.03) < 0.001,
                Sources.Cite("KAN-I", $"Cure spread: retail +-3%, server {low / mid:F4} to {high / mid:F4}"));
        }

        [Fact]
        public void CureCritBonus()
        {
            double got = lua.One("healCritMultiplier", Conjurer, 50, 0);
            Assert.True(got >= 1.22 && got <= 1.23,
                Sources.Cite("KAN-I", $"Cure crit at dLVL 0: retail +22-23%, server x{got:F3}"));
        }

        [Theory]
        [InlineData(Conjurer, 7.7)]
        [InlineData(Thaumaturge, 10.8)]
        public void CureCritRate(int classId, double expected)
        {
            double got = lua.One("healCritRate", classId, 50);
            Assert.True(got >= expected - 1.5 && got <= expected + 1.5,
                Sources.Cite("KAN-I", $"class {classId} Cure crit rate: retail {expected}% +-1.5, server {got:F2}%"));
        }

        // Crit bonus 123.7% with no potency, 133.85% with +58 magic crit potency.
        [Theory]
        [InlineData(0, 1.237)]
        [InlineData(58, 1.3385)]
        public void CureCritPotency(int potency, double expected)
        {
            double got = lua.One("healCritMultiplier", Conjurer, 50, potency);
            Assert.True(got >= expected - 0.01 && got <= expected + 0.01,
                Sources.Cite("KAN-I", $"Cure crit with +{potency} magic crit potency: retail x{expected} +-0.01, server x{got:F4}"));
        }

        [Fact]
        public void CrossClassCureAtLevel27()
        {
            double got = Heal(Gladiator, 27, 1000, null, null, null);
            Assert.True(got >= 151 && got <= 166,
                Sources.Cite("CAP-CURE", $"Lv27 GLA cross-class Cure: retail 151-166, server {got}"));
        }
    }
}
