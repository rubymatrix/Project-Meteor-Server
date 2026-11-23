using System.Linq;
using Meteor.Map.actors.chara;
using Xunit;

namespace Meteor.Map.Tests.Sim
{
    [Collection("sim")]
    [Rows("PGL-16", "PGL-46")]
    public class StatusLifetimeTests
    {
        private const uint FeatherfootStatus = 223075;

        [Fact]
        public void StatusLastsItsDurationThenClearsItsSlotAndMods()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            double evadeBefore = p.GetMod(Modifier.RawEvadeRate);

            p.statusEffects.AddStatusEffect(FeatherfootStatus, 1, 0, 30, 0);
            ushort icon = (ushort)(FeatherfootStatus - 200000);
            Assert.Contains(icon, p.charaWork.status);
            Assert.Equal(evadeBefore + 15, p.GetMod(Modifier.RawEvadeRate));

            w.Run(29.9);
            Assert.True(p.statusEffects.HasStatusEffect(FeatherfootStatus));

            w.Run(0.2);
            var expire = w.Of("status.expire", p).Single();
            Assert.Equal(FeatherfootStatus, (uint)expire.Number("id"));
            Assert.InRange(expire.Number("elapsed"), 29.999, 30.101);
            Assert.False(p.statusEffects.HasStatusEffect(FeatherfootStatus));
            Assert.DoesNotContain(icon, p.charaWork.status);
            Assert.Equal(evadeBefore, p.GetMod(Modifier.RawEvadeRate));
        }

        [Fact]
        public void RemovingEarlyIsARemoveNotAnExpiry()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            p.statusEffects.AddStatusEffect(FeatherfootStatus, 1, 0, 30, 0);
            w.Run(5);

            p.statusEffects.RemoveStatusEffect(FeatherfootStatus);
            w.Run(30);

            Assert.Single(w.Of("status.remove", p));
            Assert.Empty(w.Of("status.expire", p));
        }

        [Fact]
        public void AbilityStatusLastsTheCommandsDuration()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            p.EquipAbility(2, 27103, 32, false);
            w.Run(60);

            p.Ability(27103, p.Id);
            w.Run(31);

            var apply = w.Of("status.apply", p).Single();
            Assert.Equal(30, apply.Number("duration"));
            Assert.InRange(w.Seconds(w.Of("status.expire", p).Single()) - w.Seconds(apply), 29.999, 30.101);
        }
    }
}
