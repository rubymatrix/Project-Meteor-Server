using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.actors.area;
using Meteor.Map.DataObjects;
using Meteor.Map.lua;
using Meteor.Map.packets.send;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Meteor.Map.admin
{
    // Localhost-only JSON API for tests and debugging tools. Off unless admin_port is set in
    // map_config.ini or METEOR_ADMIN_PORT in the environment ("0" or "off" turns it off).
    // Calls that change state run under the zone-loop lock, so they never interleave with a tick.
    static class AdminServer
    {

        static HttpListener listener;
        static TelemetryRing telemetry;
        static IDisposable telemetryAttach;

        static void SetTelemetry(bool on)
        {
            lock (routes)
            {
                if (on && telemetry == null)
                {
                    telemetry = new TelemetryRing();
                    telemetryAttach = Telemetry.Attach(telemetry);
                }
                else if (!on && telemetry != null)
                {
                    telemetryAttach.Dispose();
                    telemetry = null;
                }
            }
        }
        static readonly DateTime startedAt = DateTime.Now;
        static readonly Dictionary<string, Func<Req, JToken>> routes = new Dictionary<string, Func<Req, JToken>>(StringComparer.OrdinalIgnoreCase);

        class Req
        {
            public string Method;
            public JObject Body = new JObject();
            public NameValueCollection Query;

            public bool Has(string k) { return Body[k] != null && Body[k].Type != JTokenType.Null || Query[k] != null; }
            public string Str(string k, string def = null)
            {
                JToken t = Body[k];
                if (t != null && t.Type != JTokenType.Null)
                    return t.Type == JTokenType.String ? (string)t : t.ToString(Formatting.None);
                return Query[k] ?? def;
            }
            public uint UInt(string k) { return AdminInspector.ParseUInt(Required(k)); }
            public uint UInt(string k, uint def) { return Has(k) ? UInt(k) : def; }
            public int Int(string k, int def) { return Has(k) ? (int)AdminInspector.ParseUInt(Str(k)) : def; }
            public long Long(string k, long def) { return Has(k) && AdminInspector.TryParseULong(Str(k), out ulong v) ? (long)v : def; }
            public float Float(string k, float def) { return Has(k) ? float.Parse(Str(k), System.Globalization.CultureInfo.InvariantCulture) : def; }
            public bool Bool(string k, bool def = false)
            {
                if (!Has(k)) return def;
                string s = Str(k).ToLowerInvariant();
                return s == "true" || s == "1" || s == "yes";
            }
            public string Required(string k)
            {
                string s = Str(k);
                if (string.IsNullOrEmpty(s))
                    throw new ArgumentException("missing parameter '" + k + "'");
                return s;
            }
        }

        public static void Start()
        {
            string portEnv = Environment.GetEnvironmentVariable("METEOR_ADMIN_PORT");
            int port = ConfigConstants.ADMIN_PORT;
            if (portEnv != null)
                port = portEnv.Equals("off", StringComparison.OrdinalIgnoreCase) ? 0 : int.Parse(portEnv);
            if (port <= 0)
                return;

            AdminCapture.PacketsEnabled = true;
            AdminCapture.InstallLogTarget();
            RegisterRoutes();

            try
            {
                listener = new HttpListener();
                listener.Prefixes.Add(String.Format("http://127.0.0.1:{0}/", port));
                listener.Start();
            }
            catch (Exception e)
            {
                Program.Log.Error("Admin API failed to start on 127.0.0.1:{0}: {1}", port, e.Message);
                return;
            }

            var thread = new Thread(AcceptLoop) { IsBackground = true, Name = "AdminApi" };
            thread.Start();
            Program.Log.Info("Admin API listening @ http://127.0.0.1:{0}/", port);
        }

        static void AcceptLoop()
        {
            while (listener.IsListening)
            {
                HttpListenerContext ctx;
                try { ctx = listener.GetContext(); }
                catch (Exception) { if (!listener.IsListening) return; continue; }
                ThreadPool.QueueUserWorkItem(_ => Handle(ctx));
            }
        }

        static void Handle(HttpListenerContext ctx)
        {
            int status = 200;
            JToken result;
            try
            {
                var req = new Req { Method = ctx.Request.HttpMethod, Query = ctx.Request.QueryString };
                if (ctx.Request.HasEntityBody)
                {
                    string text;
                    using (var r = new StreamReader(ctx.Request.InputStream, Encoding.UTF8))
                        text = r.ReadToEnd();
                    if (!string.IsNullOrWhiteSpace(text))
                        req.Body = JObject.Parse(text);
                }
                string path = ctx.Request.Url.AbsolutePath.TrimEnd('/');
                if (path == "")
                    path = "/";
                if (!routes.TryGetValue(path, out var handler))
                {
                    status = 404;
                    result = new JObject { ["error"] = "no route " + path, ["routes"] = new JArray(routes.Keys.OrderBy(k => k)) };
                }
                else
                {
                    result = handler(req);
                }
            }
            catch (Exception e)
            {
                Exception b = e is System.Reflection.TargetInvocationException && e.InnerException != null ? e.InnerException : e;
                status = b is ArgumentException || b is FormatException || b is KeyNotFoundException || b is MissingMemberException || b is JsonException ? 400 : 500;
                result = new JObject { ["error"] = b.GetType().Name + ": " + b.Message };
                if (status == 500)
                    result["stack"] = b.StackTrace;
            }

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(result.ToString(Formatting.Indented));
                ctx.Response.StatusCode = status;
                ctx.Response.ContentType = "application/json; charset=utf-8";
                ctx.Response.ContentLength64 = bytes.Length;
                ctx.Response.OutputStream.Write(bytes, 0, bytes.Length);
                ctx.Response.OutputStream.Close();
            }
            catch (Exception) { }
        }

        static T Locked<T>(Func<T> fn)
        {
            lock (WorldManager.ZoneLock)
                return fn();
        }

        public static Player FindPlayer(string nameOrId)
        {
            if (string.IsNullOrEmpty(nameOrId))
                return null;
            var sessions = Server.GetServer().GetSessionList();
            if (AdminInspector.TryParseULong(nameOrId, out ulong id))
            {
                Session s = Server.GetServer().GetSession((uint)id);
                if (s != null)
                    return s.GetActor();
            }
            foreach (Session s in sessions.Values.ToList())
            {
                Player p = s.GetActor();
                if (p == null)
                    continue;
                if (string.Equals(p.DisplayName, nameOrId, StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(p.Name, nameOrId, StringComparison.OrdinalIgnoreCase))
                    return p;
            }
            return null;
        }

        static Player RequirePlayer(Req r, bool allowDefault = true)
        {
            string who = r.Str("player");
            if (string.IsNullOrEmpty(who))
            {
                if (!allowDefault)
                    throw new ArgumentException("missing parameter 'player'");
                var all = Server.GetServer().GetSessionList().Values.ToList();
                if (all.Count == 1)
                    return all[0].GetActor();
                throw new ArgumentException(all.Count == 0 ? "no players online" : "several players online; pass 'player'");
            }
            return FindPlayer(who) ?? throw new KeyNotFoundException("no player '" + who + "' online");
        }

        public static Actor FindActor(uint id)
        {
            Actor a = Server.GetWorldManager().GetActorInWorld(id);
            if (a != null)
                return a;
            Session s = Server.GetServer().GetSession(id);
            if (s != null)
                return s.GetActor();
            return Server.GetStaticActors(id);
        }

        static JObject ActorSummary(Actor a)
        {
            var o = new JObject
            {
                ["actorId"] = AdminCapture.Hex(a.Id, 8),
                ["kind"] = a.GetType().Name,
                ["actorName"] = a.Name,
            };
            if (!string.IsNullOrEmpty(a.DisplayName))
                o["customDisplayName"] = a.DisplayName;
            if (a.LocalizedDisplayName != -1)
                o["displayNameId"] = a.LocalizedDisplayName;
            if (a is Npc npc)
            {
                o["uniqueId"] = npc.GetUniqueId();
                o["actorClassId"] = npc.GetActorClassId();
            }
            if (a.className != null)
                o["className"] = a.className;
            o["pos"] = new JArray(Math.Round(a.positionX, 3), Math.Round(a.positionY, 3), Math.Round(a.positionZ, 3));
            o["rot"] = Math.Round(a.rotation, 3);
            o["mainState"] = a.currentMainState;
            if (a.CurrentArea != null)
                o["zone"] = a.CurrentArea.ZoneId + " " + a.CurrentArea.ZoneName;
            if (a.CurrentArea != null && a.CurrentArea.IsPrivate())
                o["privateArea"] = a.CurrentArea.GetPrivateAreaName() + "#" + a.CurrentArea.GetPrivateAreaType();
            return o;
        }

        static JObject PlayerSummary(Session s)
        {
            Player p = s.GetActor();
            JObject o = p != null ? ActorSummary(p) : new JObject();
            o["sessionId"] = AdminCapture.Hex(s.id, 8);
            if (p != null)
            {
                o["isGM"] = p.isGM;
                o["isZoning"] = p.IsZoneing;
                if (p.CurrentArea != null)
                    o["zoneId"] = p.CurrentArea.ZoneId;
            }
            o["updatesLocked"] = s.isUpdatesLocked;
            return o;
        }

        static object ResolveTargetForReq(Req r)
        {
            string t = r.Str("target");
            if (string.IsNullOrEmpty(t) && r.Has("player"))
                return RequirePlayer(r);
            return AdminInspector.ResolveTarget(t);
        }

        // Which zones have a navmesh and collision loaded.
        static JObject NavSummary(bool detail)
        {
            int withMesh = 0, total = 0;
            var zones = new JArray();
            foreach (var z in Server.GetWorldManager().GetZones())
            {
                total++;
                bool mesh = z.navMesh != null || z.navWorld != null;
                if (mesh)
                    withMesh++;
                if (detail)
                    zones.Add(new JObject { ["zone"] = z.ZoneName, ["navMesh"] = mesh, ["collision"] = z.HasCollision });
            }
            var o = new JObject { ["zones"] = total, ["withNavMesh"] = withMesh };
            if (detail)
                o["detail"] = zones;
            return o;
        }

        static void RegisterRoutes()
        {
            routes["/"] = r => new JObject
            {
                ["service"] = "meteor map server admin api",
                ["routes"] = new JArray(routes.Keys.OrderBy(k => k)),
            };

            routes["/status"] = r =>
            {
                ZoneConnection wc = Server.GetWorldConnection();
                return new JObject
                {
                    ["uptimeSec"] = (int)(DateTime.Now - startedAt).TotalSeconds,
                    ["worldConnected"] = wc != null && wc.socket != null && wc.socket.Connected,
                    ["worldAddress"] = wc?.socket != null && wc.socket.Connected ? wc.GetAddress() : null,
                    ["sessions"] = Server.GetServer().GetSessionList().Count,
                    ["zones"] = Server.GetWorldManager().GetZones().Count,
                    ["lastTick"] = Program.LastTick.ToString("HH:mm:ss.fff"),
                    ["packetCapture"] = new JObject { ["enabled"] = AdminCapture.PacketsEnabled, ["buffered"] = AdminCapture.PacketCount, ["lastSeq"] = AdminCapture.PacketSeq, ["capacity"] = AdminCapture.PacketCapacity },
                    ["lastLogSeq"] = AdminCapture.LogSeq,
                    ["nav"] = NavSummary(false),
                };
            };

            // Pathfinding query counts per zone.
            routes["/nav"] = r =>
            {
                return NavSummary(true);
            };

            routes["/sessions"] = r => new JArray(Server.GetServer().GetSessionList().Values.ToList().Select(PlayerSummary));

            routes["/zones"] = r => Locked(() =>
            {
                bool all = r.Bool("all");
                var arr = new JArray();
                foreach (var z in Server.GetWorldManager().GetZones())
                {
                    int players = z.GetPlayers().Count;
                    if (!all && players == 0 && !r.Has("id"))
                        continue;
                    if (r.Has("id") && z.ZoneId != r.UInt("id"))
                        continue;
                    arr.Add(new JObject
                    {
                        ["zoneId"] = z.ZoneId,
                        ["name"] = z.ZoneName,
                        ["regionId"] = z.RegionId,
                        ["classPath"] = z.className,
                        ["actors"] = z.GetActorCount(),
                        ["players"] = players,
                        ["weather"] = new JArray(z.weatherNormal, z.weatherCommon, z.weatherRare),
                        ["isIsolated"] = z.isIsolated,
                        ["isInn"] = z.isInn,
                    });
                }
                return arr;
            });

            routes["/actors"] = r => Locked(() =>
            {
                List<Area> areas = new List<Area>();
                Player near = null;
                if (r.Has("zone"))
                    areas.Add((Server.GetWorldManager().GetArea(r.UInt("zone")) as Meteor.Map.actors.area.Zone) ?? throw new KeyNotFoundException("no zone " + r.Str("zone")));
                else if (r.Has("player") || Server.GetServer().GetSessionList().Count == 1)
                {
                    near = RequirePlayer(r);
                    if (near.CurrentArea != null)
                        areas.Add(near.CurrentArea);
                }
                else
                    throw new ArgumentException("pass 'zone' or 'player'");

                float radius = r.Float("radius", 0);
                string kind = r.Str("kind");
                string name = r.Str("name");
                int limit = r.Int("limit", 200);
                var list = new List<(float d, Actor a)>();
                foreach (Area area in areas)
                    foreach (Actor a in area.GetAllActors())
                    {
                        if (kind != null && !a.GetType().Name.Equals(kind, StringComparison.OrdinalIgnoreCase))
                            continue;
                        if (name != null && (a.Name ?? "").IndexOf(name, StringComparison.OrdinalIgnoreCase) < 0 &&
                            (a.DisplayName ?? "").IndexOf(name, StringComparison.OrdinalIgnoreCase) < 0 &&
                            !(a is Npc n && (n.GetUniqueId() ?? "").IndexOf(name, StringComparison.OrdinalIgnoreCase) >= 0))
                            continue;
                        float d = near == null ? 0 : (float)Math.Sqrt(Math.Pow(a.positionX - near.positionX, 2) + Math.Pow(a.positionY - near.positionY, 2) + Math.Pow(a.positionZ - near.positionZ, 2));
                        if (radius > 0 && near != null && d > radius)
                            continue;
                        list.Add((d, a));
                    }
                var arr = new JArray();
                foreach (var (d, a) in list.OrderBy(x => x.d).Take(limit))
                {
                    JObject o = ActorSummary(a);
                    if (near != null)
                        o["dist"] = Math.Round(d, 2);
                    arr.Add(o);
                }
                return new JObject { ["count"] = list.Count, ["actors"] = arr };
            });

            routes["/inspect"] = r => Locked(() =>
            {
                object root = ResolveTargetForReq(r);
                object value = AdminInspector.Walk(root, r.Str("path"), out _, out _);
                if (r.Bool("members"))
                    return value == null ? JValue.CreateNull() : AdminInspector.Describe(value);
                var opt = new AdminInspector.DumpOptions { depth = r.Int("depth", 1), maxItems = r.Int("maxItems", 50), maxBytes = r.Int("maxBytes", 256) };
                return AdminInspector.Dump(value, opt);
            });

            routes["/set"] = r => Locked(() =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                object root = ResolveTargetForReq(r);
                JToken value = r.Body["value"] ?? (r.Query["value"] != null ? (JToken)r.Query["value"] : throw new ArgumentException("missing 'value'"));
                object after = AdminInspector.SetValue(root, r.Required("path"), value);
                return new JObject { ["ok"] = true, ["value"] = AdminInspector.Dump(after, new AdminInspector.DumpOptions { depth = 0 }) };
            });

            routes["/gm"] = r =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                Player player = RequirePlayer(r);
                List<string> parts = new List<string>();
                if (r.Body["args"] is JArray args)
                {
                    parts.Add(r.Required("command").TrimStart('!'));
                    parts.AddRange(args.Select(a => a.Type == JTokenType.String ? (string)a : a.ToString(Formatting.None)));
                }
                else
                {
                    parts.AddRange(SplitCommand(r.Required("command").TrimStart('!')));
                }
                if (parts.Count == 0)
                    throw new ArgumentException("empty command");

                return Observe(player, r.Bool("flush", true), () => Locked(() =>
                {
                    // Full GM rights for this command only; the saved level is left alone.
                    ushort wasLevel = player.gmLevel;
                    player.gmLevel = ushort.MaxValue;
                    try { LuaEngine.RunGMCommand(player, parts[0], parts.ToArray()); }
                    finally { player.gmLevel = wasLevel; }
                    return (JToken)new JObject { ["command"] = string.Join(" ", parts) };
                }));
            };

            routes["/lua"] = r =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                string code = r.Required("code");
                Player player = null;
                if (r.Has("player") || Server.GetServer().GetSessionList().Count == 1)
                    player = RequirePlayer(r);
                return Observe(player, r.Bool("flush", true), () => Locked(() =>
                {
                    // A one-line expression runs as `return <expr>` so its value comes back. Anything else
                    // runs as written.
                    bool expression = !code.Contains('\n') && !System.Text.RegularExpressions.Regex.IsMatch(code.TrimStart(), @"^(local|return|if|for|while|function|do|repeat)\b");
                    LuaScript script = expression ? LoadEval("return " + code) : null;
                    if (script == null || script.LoadError != null)
                        script = LoadEval(code);
                    if (script == null || script.LoadError != null)
                        return (JToken)new JObject { ["error"] = script?.LoadError ?? "could not load" };
                    object v;
                    try
                    {
                        LuaResume res = script.CreateCoroutine("__adminEval").Resume(player, player?.CurrentArea);
                        v = res.Count > 0 ? res[0] : null;
                    }
                    catch (LuaScriptException e)
                    {
                        return (JToken)new JObject { ["error"] = e.DecoratedMessage ?? e.Message };
                    }
                    JToken result;
                    if (v == null)
                        result = JValue.CreateNull();
                    else if (v is LuaTableValue t)
                        result = LuaTable(t, 3);
                    else if (v is string || v is double || v is bool)
                        result = JToken.FromObject(v);
                    else
                        result = AdminInspector.Dump(v, new AdminInspector.DumpOptions { depth = r.Int("depth", 1) });
                    return (JToken)new JObject { ["result"] = result, ["luaType"] = v?.GetType().Name ?? "nil" };
                }));
            };

            routes["/packet/send"] = r =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                Player player = RequirePlayer(r);
                SubPacket sp;
                if (r.Has("raw"))
                {
                    byte[] raw = AdminCapture.FromHex(r.Str("raw"));
                    int off = 0;
                    sp = new SubPacket(raw, ref off);
                    if (r.Has("source"))
                        sp.header.sourceId = r.UInt("source");
                }
                else
                {
                    ushort opcode = (ushort)r.UInt("opcode");
                    uint source = r.UInt("source", player.Id);
                    byte[] payload = AdminCapture.FromHex(r.Str("payload", ""));
                    int pad = r.Int("padTo", 0);
                    if (pad > payload.Length)
                        Array.Resize(ref payload, pad);
                    sp = new SubPacket(opcode, source, payload);
                }
                return Observe(player, r.Bool("flush", true), () =>
                {
                    player.playerSession.QueuePacket(sp);
                    return new JObject { ["queued"] = AdminCapture.ToHex(sp.GetBytes()) };
                });
            };

            routes["/packet/file"] = r =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                Player player = RequirePlayer(r);
                string file = r.Required("path");
                return Observe(player, r.Bool("flush", true), () => Locked(() =>
                {
                    player.SendPacket(file);
                    return (JToken)new JObject { ["sent"] = file };
                }));
            };

            routes["/message"] = r =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                Player player = RequirePlayer(r);
                return Observe(player, true, () =>
                {
                    player.QueuePacket(SendMessagePacket.BuildPacket(player.Id, (uint)r.UInt("type", SendMessagePacket.MESSAGE_TYPE_SYSTEM), r.Str("sender", ""), r.Required("text")));
                    return new JObject { ["ok"] = true };
                });
            };

            routes["/spawn"] = r =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                Player player = r.Has("player") || !r.Has("zone") ? RequirePlayer(r) : null;
                Area area = r.Has("zone") ? (Server.GetWorldManager().GetArea(r.UInt("zone")) as Meteor.Map.actors.area.Zone) : player.CurrentArea;
                if (area == null) throw new KeyNotFoundException("no zone to spawn in");
                uint classId = r.UInt("classId");
                return Observe(player, true, () => Locked(() =>
                {
                    Npc npc = area.SpawnActor(classId, r.Str("uniqueId", "admin_" + DateTime.Now.Ticks.ToString("x")),
                        r.Float("x", player?.positionX ?? 0), r.Float("y", player?.positionY ?? 0), r.Float("z", player?.positionZ ?? 0),
                        r.Float("rot", player?.rotation ?? 0), (ushort)r.UInt("state", 0), r.UInt("animId", 0), r.Bool("isMob"));
                    if (npc == null)
                        throw new KeyNotFoundException("no actor class " + classId);
                    return (JToken)ActorSummary(npc);
                }));
            };

            routes["/despawn"] = r =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                return Locked(() =>
                {
                    Actor a = FindActor(r.UInt("actorId")) ?? throw new KeyNotFoundException("no actor " + r.Str("actorId"));
                    if (a is Player) throw new ArgumentException("refusing to despawn a player");
                    a.CurrentArea.DespawnActor(a);
                    return (JToken)new JObject { ["despawned"] = ActorSummary(a) };
                });
            };

            routes["/warp"] = r =>
            {
                if (r.Method != "POST") throw new ArgumentException("POST required");
                Player player = RequirePlayer(r);
                return Observe(player, true, () => Locked(() => Warp(player, r)));
            };

            routes["/places"] = r => Locked(() =>
            {
                string q = r.Str("query");
                bool actors = r.Bool("actors", true);
                var names = PlaceNames();
                var landings = AetheryteLandings();
                var arr = new JArray();
                foreach (var z in Server.GetWorldManager().GetZones().OrderBy(z => z.ZoneId))
                {
                    names.TryGetValue(z.ZoneId, out string place);
                    var landmarks = actors ? z.GetAllActors<Npc>().Where(IsLandmark).ToList() : new List<Npc>();
                    bool zoneMatch = q == null || Matches(q, z.ZoneName, place, z.ZoneId.ToString());
                    if (q != null && !zoneMatch)
                        landmarks = landmarks.Where(a => Matches(q, a.Name, a.DisplayName, a.GetUniqueId(), a.classPath)).ToList();
                    if (!zoneMatch && landmarks.Count == 0)
                        continue;
                    var o = new JObject { ["zoneId"] = z.ZoneId, ["zoneName"] = z.ZoneName, ["placeName"] = place, ["players"] = z.GetPlayers().Count };
                    var zoneLandings = landings.Where(kv => (uint)kv.Value[0] == z.ZoneId).OrderBy(kv => kv.Key).ToList();
                    if (zoneLandings.Count > 0)
                        o["aetherytes"] = new JArray(zoneLandings.Select(kv => new JObject
                        {
                            ["id"] = kv.Key,
                            ["pos"] = new JArray(kv.Value[1], kv.Value[2], kv.Value[3]),
                        }));
                    if (landmarks.Count > 0)
                        o["landmarks"] = new JArray(landmarks.Take(40).Select(a => new JObject
                        {
                            ["actorId"] = AdminCapture.Hex(a.Id, 8),
                            ["uniqueId"] = a.GetUniqueId(),
                            ["class"] = a.className,
                            ["pos"] = new JArray(Math.Round(a.positionX, 2), Math.Round(a.positionY, 2), Math.Round(a.positionZ, 2)),
                        }));
                    arr.Add(o);
                }
                return arr;
            });

            routes["/packets"] = r =>
            {
                long since = r.Long("since", 0);
                int limit = r.Int("limit", 100);
                bool full = r.Bool("full");
                string dir = r.Str("dir");
                uint? actor = r.Has("actor") ? r.UInt("actor") : (uint?)null;
                HashSet<ushort> opcodes = r.Has("opcode") ? new HashSet<ushort>(r.Str("opcode").Split(',').Select(s => (ushort)AdminInspector.ParseUInt(s))) : null;
                HashSet<ushort> exclude = r.Has("exclude") ? new HashSet<ushort>(r.Str("exclude").Split(',').Select(s => (ushort)AdminInspector.ParseUInt(s))) : null;
                string contains = r.Str("contains")?.ToLowerInvariant().Replace(" ", "");
                var list = AdminCapture.GetPackets(since, limit, p =>
                    (dir == null || p.dir == dir) &&
                    (opcodes == null || p.type == 0x03 && opcodes.Contains(p.opcode)) &&
                    (exclude == null || !(p.type == 0x03 && exclude.Contains(p.opcode))) &&
                    (actor == null || p.source == actor || p.target == actor) &&
                    (contains == null || AdminCapture.ToHex(p.bytes).Contains(contains)),
                    r.Bool("newest"));
                return new JObject
                {
                    ["lastSeq"] = AdminCapture.PacketSeq,
                    ["count"] = list.Count,
                    ["packets"] = new JArray(list.Select(p => AdminCapture.PacketToJson(p, full))),
                };
            };

            routes["/packets/config"] = r =>
            {
                if (r.Has("enabled")) AdminCapture.PacketsEnabled = r.Bool("enabled");
                if (r.Has("capacity")) AdminCapture.PacketCapacity = r.Int("capacity", AdminCapture.PacketCapacity);
                if (r.Bool("clear")) AdminCapture.ClearPackets();
                return new JObject { ["enabled"] = AdminCapture.PacketsEnabled, ["capacity"] = AdminCapture.PacketCapacity, ["buffered"] = AdminCapture.PacketCount, ["lastSeq"] = AdminCapture.PacketSeq };
            };

            // Battle telemetry. The ring attaches on the first call (or enabled=true) and detaches with
            // enabled=false, so the server pays for events only while someone reads them.
            routes["/telemetry"] = r =>
            {
                if (r.Has("enabled"))
                    SetTelemetry(r.Bool("enabled"));
                else
                    SetTelemetry(true);
                if (telemetry == null)
                    return new JObject { ["enabled"] = false };
                var kinds = r.Has("kinds") ? new HashSet<string>(r.Str("kinds").Split(',').Select(k => k.Trim())) : null;
                var actor = r.Has("actor") ? r.UInt("actor") : (uint?)null;
                int limit = r.Int("limit", 500);
                var list = telemetry.Since(r.Long("since", 0), kinds, Math.Min(r.Int("wait", 0), 30000))
                    .Where(e => actor == null || e.Actor == actor || e.Target == actor)
                    .Take(limit)
                    .ToList();
                return new JObject
                {
                    ["enabled"] = true,
                    ["lastSeq"] = list.Count > 0 ? list[list.Count - 1].Seq : r.Long("since", 0),
                    ["count"] = list.Count,
                    ["events"] = new JArray(list.Select(e => JObject.Parse(e.ToJson()))),
                };
            };

            routes["/opcodes"] = r =>
            {
                var o = new JObject();
                foreach (var kv in AdminCapture.SendOpcodeNames.OrderBy(k => k.Key))
                    o[AdminCapture.Hex(kv.Key, 4)] = string.Join("|", kv.Value);
                return o;
            };

            routes["/logs"] = r =>
            {
                long since = r.Long("since", 0);
                string contains = r.Str("contains");
                string logger = r.Str("logger");
                string minLevel = r.Str("level");
                int minOrdinal = minLevel != null ? NLog.LogLevel.FromString(minLevel).Ordinal : 0;
                var list = AdminCapture.GetLogs(since, r.Int("limit", 200), l =>
                    NLog.LogLevel.FromString(l.level).Ordinal >= minOrdinal &&
                    (contains == null || l.message.IndexOf(contains, StringComparison.OrdinalIgnoreCase) >= 0) &&
                    (logger == null || (l.logger ?? "").IndexOf(logger, StringComparison.OrdinalIgnoreCase) >= 0),
                    r.Bool("newest"));
                return new JObject
                {
                    ["lastSeq"] = AdminCapture.LogSeq,
                    ["logs"] = new JArray(list.Select(LogJson)),
                };
            };

            routes["/commands"] = r =>
            {
                var arr = new JArray();
                foreach (string file in Directory.GetFiles(ConfigConstants.OPTIONS_SCRIPTPATH + "/commands/gm/", "*.lua").OrderBy(f => f))
                {
                    var o = new JObject { ["name"] = Path.GetFileNameWithoutExtension(file) };
                    try
                    {
                        if (ScriptEngine.Instance.Load(file)?.GetGlobal("properties") is LuaTableValue props)
                            foreach (var pair in props.Pairs)
                                o[Convert.ToString(pair.Key, System.Globalization.CultureInfo.InvariantCulture)] = Convert.ToString(pair.Value, System.Globalization.CultureInfo.InvariantCulture);
                    }
                    catch (Exception) { }
                    arr.Add(o);
                }
                return arr;
            };
        }

        static Dictionary<uint, string> placeNames;

        // server_zones.placeName (e.g. 133 -> "Limsa Lominsa"); the Zone objects only keep zoneName.
        static Dictionary<uint, string> PlaceNames()
        {
            if (placeNames != null)
                return placeNames;
            var map = new Dictionary<uint, string>();
            try
            {
                using (var conn = new MySql.Data.MySqlClient.MySqlConnection(String.Format("Server={0}; Port={1}; Database={2}; UID={3}; Password={4}",
                    ConfigConstants.DATABASE_HOST, ConfigConstants.DATABASE_PORT, ConfigConstants.DATABASE_NAME, ConfigConstants.DATABASE_USERNAME, ConfigConstants.DATABASE_PASSWORD)))
                {
                    conn.Open();
                    using (var cmd = new MySql.Data.MySqlClient.MySqlCommand("SELECT id, placeName FROM server_zones", conn))
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                            map[rd.GetUInt32(0)] = rd.IsDBNull(1) ? null : rd.GetString(1);
                }
            }
            catch (Exception e)
            {
                Program.Log.Warn("Admin API: could not load place names: {0}", e.Message);
            }
            return placeNames = map;
        }

        static bool Matches(string q, params string[] fields)
        {
            foreach (string f in fields)
                if (f != null && f.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0)
                    return true;
            return false;
        }

        // Aetheryte class id -> {zoneId, x, y, z}, read from aetheryte.lua's aetheryteTeleportPositions:
        // the landing points TeleportCommand and AetheryteParent use. Read per call, so script edits apply.
        static Dictionary<uint, float[]> AetheryteLandings()
        {
            var result = new Dictionary<uint, float[]>();
            string errorMsg = "";
            LuaScript script = LuaEngine.LoadScript(ConfigConstants.OPTIONS_SCRIPTPATH + "/aetheryte.lua", ref errorMsg);
            if (!(script?.GetGlobal("aetheryteTeleportPositions") is LuaTableValue table))
                return result;
            foreach (var pair in table.Pairs)
            {
                if (!(pair.Key is double key) || !(pair.Value is LuaTableValue t))
                    continue;
                var nums = new Dictionary<double, double>();
                foreach (var e in t.Pairs)
                    if (e.Key is double k && e.Value is double v)
                        nums[k] = v;
                if (!nums.ContainsKey(1) || !nums.ContainsKey(2) || !nums.ContainsKey(3) || !nums.ContainsKey(4))
                    continue;
                result[(uint)key] = new float[] { (float)nums[1], (float)nums[2], (float)nums[3], (float)nums[4] };
            }
            return result;
        }

        // Actors worth warping to by name: aetherytes, gates, doors, NPCs with a display name.
        static bool IsLandmark(Npc a)
        {
            string s = (a.className ?? "") + " " + (a.classPath ?? "");
            return s.IndexOf("aetheryte", StringComparison.OrdinalIgnoreCase) >= 0 ||
                   s.IndexOf("gate", StringComparison.OrdinalIgnoreCase) >= 0 ||
                   s.IndexOf("guild", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        // Zone by id, zoneName or placeName (exact match preferred, then substring).
        static Area FindZone(string q)
        {
            var zones = Server.GetWorldManager().GetZones();
            if (AdminInspector.TryParseULong(q, out ulong id))
                return zones.FirstOrDefault(z => z.ZoneId == id) ?? throw new KeyNotFoundException("zone " + q + " is not on this map server");
            var names = PlaceNames();
            Func<Area, string> place = z => names.TryGetValue(z.ZoneId, out string p) ? p : null;
            var exact = zones.Where(z => string.Equals(z.ZoneName, q, StringComparison.OrdinalIgnoreCase) || string.Equals(place(z), q, StringComparison.OrdinalIgnoreCase)).ToList();
            var hits = exact.Count > 0 ? exact : zones.Where(z => Matches(q, z.ZoneName, place(z))).ToList();
            if (hits.Count == 1)
                return hits[0];
            if (hits.Count == 0)
                throw new KeyNotFoundException("no zone matching '" + q + "' (see meteor_places)");
            throw new ArgumentException("ambiguous zone '" + q + "': " + string.Join(", ", hits.Select(z => z.ZoneId + " " + z.ZoneName + " (" + place(z) + ")")));
        }

        // An actor anywhere on this server by id, player name, or name/uniqueId/class substring.
        static Actor FindActorAnywhere(string q, Area preferZone)
        {
            if (AdminInspector.TryParseULong(q, out ulong id))
                return FindActor((uint)id) ?? throw new KeyNotFoundException("no actor " + q);
            Player p = FindPlayer(q);
            if (p != null)
                return p;
            var zones = Server.GetWorldManager().GetZones();
            if (preferZone is Meteor.Map.actors.area.Zone pz)
                zones = new[] { pz }.Concat(zones.Where(z => z != pz)).ToList();
            var hits = new List<Actor>();
            foreach (var z in zones)
                foreach (Actor a in z.GetAllActors())
                    if (string.Equals((a as Npc)?.GetUniqueId(), q, StringComparison.OrdinalIgnoreCase))
                        return a;
                    else if (Matches(q, a.Name, a.DisplayName, (a as Npc)?.GetUniqueId(), a.className))
                        hits.Add(a);
            if (hits.Count == 0)
                throw new KeyNotFoundException("no actor matching '" + q + "' (see meteor_places / meteor_actors)");
            return hits[0];
        }

        // The first destination given wins: to (an actor, NPC or player), entrance (an aetheryte
        // class id; lands where Teleport and Return land), zone (id or name; without x/y/z, its first
        // aetheryte landing, else a landmark actor), or x/y/z in the current zone. dx/dy/dz shift it.
        // Landing points come from aetheryte.lua, the table the game's own teleports use.
        static JToken Warp(Player player, Req r)
        {
            uint zoneId = player.CurrentArea.ZoneId;
            string privateArea = r.Str("privateArea");
            int privateAreaType = r.Int("privateAreaType", 0);
            float x = player.positionX, y = player.positionY, z = player.positionZ, rot = player.rotation;
            string via;

            if (r.Has("to"))
            {
                Actor target = FindActorAnywhere(r.Str("to"), player.CurrentArea);
                if (target == player)
                    throw new ArgumentException("can't warp a player to themselves");
                Area area = target.CurrentArea ?? throw new InvalidOperationException("target has no zone");
                if (area is PrivateArea pa)
                {
                    zoneId = pa.GetParentZone().ZoneId;
                    privateArea = pa.GetPrivateAreaName();
                    privateAreaType = (int)pa.GetPrivateAreaType();
                }
                else
                    zoneId = area.ZoneId;
                x = target.positionX; y = target.positionY; z = target.positionZ; rot = target.rotation;
                via = "actor " + AdminCapture.Hex(target.Id, 8) + " " + target.Name;
            }
            else if (r.Has("entrance"))
            {
                uint id = r.UInt("entrance");
                if (!AetheryteLandings().TryGetValue(id, out float[] landing))
                    throw new KeyNotFoundException("no aetheryte landing " + id + " (entrance now takes an aetheryte class id from meteor_places; " +
                        "the old server_zones_spawnlocations ids were removed with the quest_system merge)");
                zoneId = (uint)landing[0];
                privateArea = null; privateAreaType = 0;
                x = landing[1]; y = landing[2]; z = landing[3];
                via = "aetheryte landing " + id;
            }
            else if (r.Has("zone"))
            {
                Area area = FindZone(r.Str("zone"));
                zoneId = area.ZoneId;
                if (r.Has("x") || r.Has("y") || r.Has("z"))
                {
                    x = r.Float("x", x); y = r.Float("y", y); z = r.Float("z", z);
                    via = "coords";
                }
                else
                {
                    var landing = AetheryteLandings().Where(kv => (uint)kv.Value[0] == zoneId).OrderBy(kv => kv.Key).FirstOrDefault();
                    if (landing.Value != null)
                    {
                        x = landing.Value[1]; y = landing.Value[2]; z = landing.Value[3];
                        via = "aetheryte landing " + landing.Key;
                    }
                    else
                    {
                        Npc mark = (area as Zone)?.GetAllActors<Npc>().Where(IsLandmark)
                            .OrderBy(a => (a.className ?? "").IndexOf("aetheryte", StringComparison.OrdinalIgnoreCase) >= 0 ? 0 : 1)
                            .ThenBy(a => a.Id).FirstOrDefault();
                        if (mark == null)
                            throw new ArgumentException("zone " + zoneId + " has no aetheryte landing or landmark actor; pass x/y/z or use 'to' with an actor there");
                        x = mark.positionX; y = mark.positionY; z = mark.positionZ;
                        via = "landmark " + AdminCapture.Hex(mark.Id, 8) + " " + mark.Name;
                    }
                }
            }
            else if (r.Has("x") || r.Has("y") || r.Has("z"))
            {
                x = r.Float("x", x); y = r.Float("y", y); z = r.Float("z", z);
                via = "coords";
                // A move within the current area keeps the player in their private area.
                if (privateArea == null && player.CurrentArea is PrivateArea cur)
                {
                    zoneId = cur.GetParentZone().ZoneId;
                    privateArea = cur.GetPrivateAreaName();
                    privateAreaType = (int)cur.GetPrivateAreaType();
                }
            }
            else
                throw new ArgumentException("pass one of: to, entrance, zone, x/y/z");

            x += r.Float("dx", 0); y += r.Float("dy", 0); z += r.Float("dz", 0);
            rot = r.Float("rot", rot);

            Area current = player.CurrentArea;
            string currentPrivate = current.IsPrivate() ? current.GetPrivateAreaName() : null;
            bool sameArea = zoneId == current.ZoneId && (privateArea ?? "") == (currentPrivate ?? "") && (privateArea == null || privateAreaType == current.GetPrivateAreaType());
            if (sameArea)
                Server.GetWorldManager().DoPlayerMoveInZone(player, x, y, z, rot, (byte)r.UInt("spawnType", 0x00));
            else
                Server.GetWorldManager().DoZoneChange(player, zoneId, privateArea, privateAreaType, (byte)r.UInt("spawnType", 0x02), x, y, z, rot);

            PlaceNames().TryGetValue(zoneId, out string placeName);
            return new JObject
            {
                ["via"] = via,
                ["zoneId"] = zoneId,
                ["placeName"] = placeName,
                ["privateArea"] = privateArea,
                ["pos"] = new JArray(Math.Round(x, 3), Math.Round(y, 3), Math.Round(z, 3)),
                ["rot"] = Math.Round(rot, 3),
                ["zoneChange"] = !sameArea,
            };
        }

        static JObject LogJson(AdminCapture.LogRecord l)
        {
            return new JObject { ["seq"] = l.seq, ["time"] = l.time.ToString("HH:mm:ss.fff"), ["level"] = l.level, ["logger"] = l.logger, ["msg"] = l.message };
        }

        // Runs an action and reports what it caused: log lines emitted and packets queued to the
        // player while it ran. Flushes the world connection so packets reach the client now.
        static JToken Observe(Player player, bool flush, Func<JToken> action)
        {
            long logBefore = AdminCapture.LogSeq;
            long pktBefore = AdminCapture.PacketSeq;
            JToken result = action();
            if (flush)
                Server.GetWorldConnection()?.FlushQueuedSendPackets();
            var o = result as JObject ?? new JObject { ["result"] = result };
            o["logs"] = new JArray(AdminCapture.GetLogs(logBefore, 100, null, false).Select(LogJson));
            uint? sid = player?.Id;
            o["packets"] = new JArray(AdminCapture.GetPackets(pktBefore, 100, p => p.dir == "out" && (sid == null || p.target == sid), false)
                .Select(p => AdminCapture.PacketToJson(p, false)));
            return o;
        }

        static JToken LuaTable(LuaTableValue t, int depth)
        {
            var o = new JObject();
            foreach (var pair in t.Pairs)
            {
                string k = Convert.ToString(pair.Key, System.Globalization.CultureInfo.InvariantCulture);
                object v = pair.Value;
                if (v is LuaTableValue inner && depth > 0)
                    o[k] = LuaTable(inner, depth - 1);
                else if (v == null || v is string || v is double || v is bool)
                    o[k] = v == null ? JValue.CreateNull() : JToken.FromObject(v);
                else
                    o[k] = AdminInspector.Ref(v);
            }
            return o;
        }

        // The engine only runs files, so admin Lua goes into a scratch script as a function.
        static int evalCount;
        static LuaScript LoadEval(string body)
        {
            string dir = ConfigConstants.OPTIONS_SCRIPTPATH + "/__admin";
            Directory.CreateDirectory(dir);
            string path = dir + "/eval_" + Interlocked.Increment(ref evalCount) + ".lua";
            File.WriteAllText(path, "require(\"global\")\nfunction __adminEval(player, zone)\n" + body + "\nend\n");
            try
            {
                return ScriptEngine.Instance.Load(path);
            }
            finally
            {
                File.Delete(path);
            }
        }

        // Pulls just the `properties = {...}` table out of a gm command script.
        static string ExtractProperties(string src)
        {
            int i = src.IndexOf("properties");
            if (i < 0) return "";
            int start = src.IndexOf('{', i);
            if (start < 0) return "";
            int depth = 0;
            for (int j = start; j < src.Length; j++)
            {
                if (src[j] == '{') depth++;
                else if (src[j] == '}' && --depth == 0)
                    return "properties = " + src.Substring(start, j - start + 1);
            }
            return "";
        }

        // Same quoting rules as CommandProcessor.DoCommand.
        static string[] SplitCommand(string input)
        {
            return input.Split('"')
                .Select((s, i) => i % 2 == 0 ? s.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries) : new[] { s })
                .SelectMany(s => s).ToArray();
        }
    }
}
