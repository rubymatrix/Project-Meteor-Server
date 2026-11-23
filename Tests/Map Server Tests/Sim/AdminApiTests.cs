using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using Meteor.Map.admin;
using Newtonsoft.Json.Linq;
using Xunit;

namespace Meteor.Map.Tests.Sim
{
    // The admin API over real HTTP, against the headless world: the routes test tools call.
    [Collection("sim")]
    public class AdminApiTests
    {
        private static readonly Lazy<string> Base = new Lazy<string>(() =>
        {
            var probe = new TcpListener(IPAddress.Loopback, 0);
            probe.Start();
            int port = ((IPEndPoint)probe.LocalEndpoint).Port;
            probe.Stop();
            ConfigConstants.ADMIN_PORT = port;
            AdminServer.Start();
            return $"http://127.0.0.1:{port}";
        });

        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };

        private static JToken Get(string path) => JToken.Parse(Http.GetStringAsync(Base.Value + path).Result);

        private static JToken Post(string path, object body) =>
            JToken.Parse(Http.PostAsync(Base.Value + path, new StringContent(Newtonsoft.Json.JsonConvert.SerializeObject(body))).Result.Content.ReadAsStringAsync().Result);

        [Fact]
        public void RoutesTheMcpUsesAnswer()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);

            var routes = Get("/")["routes"].Select(t => (string)t).ToList();
            foreach (var r in new[] { "/status", "/sessions", "/actors", "/inspect", "/lua", "/gm", "/packets", "/logs", "/telemetry", "/warp", "/spawn", "/set" })
                Assert.Contains(r, routes);

            Assert.Single(Get("/sessions"));
            var hp = Get($"/inspect?target=actor:{m.Id}&path=charaWork.parameterSave.hp[0]");
            Assert.Equal(m.GetHP(), (int)hp);
            var lua = Post("/lua", new { code = "1 + 2", flush = false });
            Assert.Equal(3.0, (double)lua["result"]);
        }

        [Fact]
        public void TelemetryFeedTailsBattleEvents()
        {
            using var w = SimWorld.Create(seed: 4);
            var p = w.AddPlayer(2, 10);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);
            SimWorld.Durable(m);

            var first = Get("/telemetry?since=0");
            Assert.True((bool)first["enabled"]);
            long since = (long)first["lastSeq"];

            w.Attack(p, m);
            w.Run(4);

            var feed = Get($"/telemetry?since={since}&kinds=action.result,roll&actor={p.Id}");
            var events = (JArray)feed["events"];
            Assert.Contains(events, e => (string)e["kind"] == "action.result" && (uint)e["actor"] == p.Id);
            Assert.All(events, e => Assert.Contains((string)e["kind"], new[] { "action.result", "roll" }));
            Assert.Empty((JArray)Get($"/telemetry?since={(long)feed["lastSeq"]}&kinds=action.result")["events"]);

            Assert.False((bool)Get("/telemetry?enabled=false")["enabled"]);
        }
    }
}
