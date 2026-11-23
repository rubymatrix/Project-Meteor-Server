using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Meteor.Map.Tests.Formulas
{
    // Rows of a seed SQL dump (Data/sql), by primary key, so tests can read the server's data
    // without a database.
    internal sealed class SeedTable
    {
        public readonly Dictionary<long, Dictionary<string, string>> Rows = new Dictionary<long, Dictionary<string, string>>();

        public SeedTable(string table)
        {
            string sql = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "sql", table + ".sql"));
            var create = Regex.Match(sql, @"CREATE TABLE `" + table + @"` \((.*?)\n\)", RegexOptions.Singleline);
            var columns = Regex.Matches(create.Groups[1].Value, @"^\s*`(\w+)`", RegexOptions.Multiline).Select(m => m.Groups[1].Value).ToList();
            foreach (Match insert in Regex.Matches(sql, @"INSERT INTO `" + table + @"` VALUES (.*?);\r?\n", RegexOptions.Singleline))
            {
                foreach (var tuple in Tuples(insert.Groups[1].Value))
                {
                    var row = new Dictionary<string, string>();
                    for (int i = 0; i < columns.Count && i < tuple.Count; i++)
                        row[columns[i]] = tuple[i];
                    Rows[long.Parse(tuple[0], CultureInfo.InvariantCulture)] = row;
                }
            }
        }

        public double Number(long id, string column) => double.Parse(Rows[id][column], CultureInfo.InvariantCulture);

        // Splits "(1,'a,b',2),(3,'c',4)" into value lists, honouring quotes and \' escapes.
        private static IEnumerable<List<string>> Tuples(string values)
        {
            var row = new List<string>();
            var cell = new StringBuilder();
            bool quoted = false, inRow = false;
            for (int i = 0; i < values.Length; i++)
            {
                char c = values[i];
                if (quoted)
                {
                    if (c == '\\' && i + 1 < values.Length) cell.Append(values[++i]);
                    else if (c == '\'') quoted = false;
                    else cell.Append(c);
                }
                else if (c == '\'') quoted = true;
                else if (c == '(' && !inRow) inRow = true;
                else if (c == ',' && inRow) { row.Add(cell.ToString()); cell.Clear(); }
                else if (c == ')' && inRow)
                {
                    row.Add(cell.ToString()); cell.Clear();
                    yield return row;
                    row = new List<string>();
                    inRow = false;
                }
                else if (inRow) cell.Append(c);
            }
        }
    }
}
