using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using Xunit;

namespace Meteor.Map.Tests.Sim
{
    public class RowsTests
    {
        [Fact]
        public void EveryCitedRowIsInTheMatrix()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "Data", "Docs", "Test Coverage")))
                dir = dir.Parent;
            Assert.NotNull(dir);
            string docs = Path.Combine(dir.FullName, "Data", "Docs", "Test Coverage");
            var known = Directory.EnumerateFiles(docs, "*.md", SearchOption.AllDirectories)
                .SelectMany(f => Regex.Matches(File.ReadAllText(f), @"^\|\s*([A-Z]{2,4}-\d+[a-z]?)\s*\|", RegexOptions.Multiline))
                .Select(m => m.Groups[1].Value)
                .ToHashSet();
            Assert.NotEmpty(known);

            var cited = typeof(RowsTests).Assembly.GetTypes()
                .SelectMany(t => t.GetCustomAttributes<RowsAttribute>().Concat(t.GetMethods().SelectMany(m => m.GetCustomAttributes<RowsAttribute>())))
                .SelectMany(a => a.Ids)
                .Distinct();
            foreach (var id in cited)
                Assert.True(known.Contains(id), $"{id} is not a row in Test Coverage");
        }
    }
}
