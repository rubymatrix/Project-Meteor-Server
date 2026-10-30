using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Meteor.Map.lua;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    internal sealed class FormulaScript
    {
        private readonly LuaScript script;

        // name: a harness file in Lua/ (without .lua).
        public FormulaScript(EngineFixture engines, string name = "formulas")
        {
            script = engines.Engine.Load($"./scripts/__tests/{name}.lua");
            Assert.Null(script.LoadError);
        }

        public double[] Call(string function, params object[] args) =>
            script.Call(function, args).Select(v => Convert.ToDouble(v, CultureInfo.InvariantCulture)).ToArray();

        public double One(string function, params object[] args) => Call(function, args)[0];
    }

    // The sources in Data/Docs/RPG-Systems.md. Every expected value in these tests names one, so a
    // failure says where the number came from.
    internal static class Sources
    {
        public static readonly string Doc = Path.Combine(AppContext.BaseDirectory, "docs", "RPG-Systems.md");

        private static readonly Lazy<HashSet<string>> ids = new Lazy<HashSet<string>>(() =>
            Regex.Matches(File.ReadAllText(Doc), "<a id=\"([a-z0-9-]+)\"></a>")
                .Select(m => m.Groups[1].Value.ToUpperInvariant())
                .ToHashSet());

        public static bool Exists(string id) => ids.Value.Contains(id);

        public static string Cite(string id, string what) => $"{what} [{id}]";
    }
}
