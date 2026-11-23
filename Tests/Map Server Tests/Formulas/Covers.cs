using System;

namespace Meteor.Map.Tests.Formulas
{
    // Names the formula functions ("formulas.hitRate", "stats.baseHp") a test class checks.
    // FormulaCoverageTests fails when a function has no test and no stated exemption.
    [AttributeUsage(AttributeTargets.Class, AllowMultiple = true)]
    internal sealed class CoversAttribute : Attribute
    {
        public readonly string[] Functions;

        public CoversAttribute(params string[] functions)
        {
            Functions = functions;
        }
    }
}
