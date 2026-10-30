using Meteor.Map.actors.chara.ai;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // TargetFind: how many enemies an area attack can hit.
    [Collection("engines")]
    public sealed class EngineAoeTests : EngineHarness
    {
        public EngineAoeTests(EngineFixture engines) { }

        [Fact]
        public void AnAreaAttackHitsAtMost8Of10Enemies()
        {
            var pc = Pc(50);
            var first = Mob(50, x: 3);
            for (int i = 1; i < 10; i++)
                Mob(50, x: 3 + (i % 3) * 0.5f, z: (i / 3) * 0.5f);

            var find = new TargetFind(pc, first);
            find.SetAOEType(ValidTarget.Enemy, TargetFindAOEType.Circle, TargetFindAOETarget.Target, 10, 0, 10, 0, 0);
            find.FindWithinArea(first, ValidTarget.Enemy, TargetFindAOETarget.Target);

            int hit = find.GetTargets().Count;
            Assert.True(hit >= 1 && hit <= 8, Sources.Cite("BG-107403", $"an AoE with 10 enemies in it hits at most 8, got {hit}"));
        }
    }
}
