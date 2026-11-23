using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Every function in the formulas, stats and actions tables has a test, or a reason here why
    // it is tested elsewhere.
    [Collection("engines")]
    public sealed class FormulaCoverageTests
    {
        private static readonly Dictionary<string, string> Exempt = new Dictionary<string, string>
        {
            ["actions.setPhysicalRates"] = "fills a CommandResult; mechanism test (M3)",
            ["actions.autoAttack"] = "runs DoAction on a CommandResult; mechanism test (M3)",
            ["stats.gearTotals"] = "reads equipment and item data objects; mechanism test (M3)",
            ["stats.addMateria"] = "reads item data objects; mechanism test (M3)",
            ["stats.materiaItemId"] = "lookup used by addMateria",
            ["stats.applyMobBaseStats"] = "sets stats on a BattleNpc; mechanism test (M3)",
        };

        private readonly FormulaScript lua;

        public FormulaCoverageTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        [Fact]
        public void EveryFormulaHasATest()
        {
            var functions = lua.Names("formulaFunctions");
            var covered = typeof(FormulaCoverageTests).Assembly.GetTypes()
                .SelectMany(t => t.GetCustomAttributes<CoversAttribute>())
                .SelectMany(a => a.Functions)
                .ToHashSet();
            var untested = functions.Where(f => !covered.Contains(f) && !Exempt.ContainsKey(f)).ToList();
            Assert.True(untested.Count == 0, "No test covers: " + string.Join(", ", untested));
            var stale = covered.Concat(Exempt.Keys).Where(f => !functions.Contains(f)).ToList();
            Assert.True(stale.Count == 0, "Covers or Exempt names a function that doesn't exist: " + string.Join(", ", stale));
        }
    }
}
