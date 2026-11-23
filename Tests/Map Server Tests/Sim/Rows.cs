using System;

namespace Meteor.Map.Tests.Sim
{
    // Rows of Data/Docs/Test Coverage a test checks. RowsTests fails on an ID the matrix lacks.
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
    internal sealed class RowsAttribute : Attribute
    {
        public readonly string[] Ids;

        public RowsAttribute(params string[] ids)
        {
            Ids = ids;
        }
    }
}
