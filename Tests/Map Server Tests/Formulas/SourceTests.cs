using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    public sealed class SourceTests
    {
        [Fact]
        public void CitedSourcesAreDocumented()
        {
            var dir = Path.Combine(AppContext.BaseDirectory, "formulas-src");
            var cited = Directory.EnumerateFiles(dir, "*.cs")
                .SelectMany(f => Regex.Matches(File.ReadAllText(f), "\"((?:CAP|CL|PN|HF|JPF|T|BG|EL|KAN|DEV|SH|CODE|2N)[A-Z0-9-]*)\"").Select(m => m.Groups[1].Value))
                .Distinct()
                .ToList();
            Assert.NotEmpty(cited);
            var missing = cited.Where(id => !Sources.Exists(id)).ToList();
            Assert.True(missing.Count == 0, "Not in Data/Docs/RPG-Systems.md: " + string.Join(", ", missing));
        }
    }
}
