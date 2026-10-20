using System.IO;
using Xunit;

namespace Meteor.Navigation.Tests
{
    public class NavManifestTests
    {
        private const string Json = @"{ ""version"": 2, ""zones"": {
            ""sea0Town01"":   { ""file"": ""sea0Town01.nav"", ""hashes"": {}, ""stats"": {}, ""valid"": true },
            ""fst0Field01"":  { ""file"": ""fst0Field01.nav"", ""valid"": false },
            ""fst0Battle01"": { ""sameAs"": ""fst0Field01"" },
            ""fst0Battle02"": { ""sameAs"": ""fst0Battle01"" },
            ""loopA"": { ""sameAs"": ""loopB"" }, ""loopB"": { ""sameAs"": ""loopA"" } } }";

        [Fact]
        public void ResolvesFilesAndSameAs()
        {
            var m = NavManifest.Parse(Json);
            m.Directory = "/nav";
            Assert.Equal(Path.Combine("/nav", "sea0Town01.nav"), m.ResolveFile("SEA0TOWN01"));
            Assert.Equal(Path.Combine("/nav", "fst0Field01.nav"), m.ResolveFile("fst0Battle01"));
            Assert.Equal(Path.Combine("/nav", "fst0Field01.nav"), m.ResolveFile("fst0Battle02"));
            Assert.Equal(false, m.Resolve("fst0Battle01").Valid);
            Assert.Null(m.ResolveFile("loopA"));
            Assert.Null(m.ResolveFile("unknown"));
        }

        [Fact]
        public void RejectsOtherVersions()
        {
            Assert.Throws<InvalidDataException>(() => NavManifest.Parse(@"{ ""version"": 1, ""zones"": {} }"));
            Assert.Throws<InvalidDataException>(() => NavManifest.Parse(@"[ { ""name"": ""x"", ""file"": ""x.bin"" } ]"));
        }
    }
}
