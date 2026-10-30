/*
===========================================================================
Copyright (C) 2015-2019 Project Meteor Dev Team

This file is part of Project Meteor Server.

Project Meteor Server is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Project Meteor Server is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with Project Meteor Server. If not, see <https:www.gnu.org/licenses/>.
===========================================================================
*/

using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.AI;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.actors.director;
using Meteor.Map.actors.group;
using Meteor.Map.Scripting;
using XLua;

namespace Meteor.Map.Content
{
    enum EncounterState { Created, Ready, Running, Ending, Closed }
    // ContentArea: bound to a private content area (the client's PrivateAreaMaster*Content and
    // Occupancy areas). World: open world, anchored to a point or actor.
    enum EncounterScope { Encounter, ContentArea, World }

    // One scripted piece of content: a boss fight, a dungeon, a hamlet battle, a caravan run.
    // It owns its actors, its time and its outcome. The Lua object (encounters, content) holds
    // the phases, tasks and triggers; this side holds what the engine checks every tick.
    class Encounter
    {
        private static int nextId;

        public const int DefaultArrivalGraceSeconds = 60;
        public const int DefaultCleanupSeconds = 10;

        public readonly int Id = ++nextId;
        public string Name { get; }
        public string Variant { get; }
        public EncounterScope Scope { get; set; }
        public Area Area { get; private set; }
        public Director Director { get; set; }
        public Encounter Parent { get; private set; }
        public int ScriptId { get; set; }
        public SeededRandom Rng { get; }
        public EncounterState State { get; private set; } = EncounterState.Created;
        public string Result { get; private set; } = "";
        public string Reason { get; private set; } = "";
        public string Phase { get; private set; } = "";
        public Vector3 Anchor { get; set; }
        public Actor AnchorActor { get; set; }

        private readonly List<Encounter> children = new List<Encounter>();
        private readonly HashSet<string> hooks = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<uint, Player> participants = new Dictionary<uint, Player>();
        private readonly HashSet<uint> arrived = new HashSet<uint>();
        private readonly Dictionary<string, List<Character>> groups = new Dictionary<string, List<Character>>(StringComparer.OrdinalIgnoreCase);
        private readonly List<Character> roster = new List<Character>();
        private readonly HashSet<Character> keep = new HashSet<Character>();
        private readonly Dictionary<Character, long> corpseUntil = new Dictionary<Character, long>();
        private readonly Dictionary<(int, int), Relation> relations = new Dictionary<(int, int), Relation>();
        private readonly List<Objective> objectives = new List<Objective>();
        private readonly List<Hazard> hazards = new List<Hazard>();
        private readonly Dictionary<string, Region> regions = new Dictionary<string, Region>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<uint, Dictionary<string, double>> scores = new Dictionary<uint, Dictionary<string, double>>();
        private readonly Dictionary<string, double> counters = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<uint, int> warnings = new Dictionary<uint, int>();
        private readonly HashSet<uint> dropped = new HashSet<uint>();

        private Shape arena;
        private string arenaOut = "push";
        private long startedAt, endsAt, endingAt, nextContributionCheck;
        private long timeLimitMs;
        private int arrivalGraceSeconds = DefaultArrivalGraceSeconds;
        private int cleanupSeconds = DefaultCleanupSeconds;
        private bool failOnWipe = true, failOnLeave = true;
        private ScriptParams contribution;
        private string partyAllyGroup;

        public Encounter(string name, string variant, Area area, EncounterScope scope, int? seed = null)
        {
            Name = name;
            Variant = variant ?? "";
            Area = area;
            Scope = scope;
            Rng = new SeededRandom(seed);
        }

        public long ElapsedMs => State == EncounterState.Running || State == EncounterState.Ending ? GameClock.NowMs - startedAt : 0;
        public bool IsRunning => State == EncounterState.Running;
        public bool IsOver => State == EncounterState.Ending || State == EncounterState.Closed;
        public IReadOnlyList<Encounter> Children => children;

        #region Script wiring

        public void SetHooks(LuaTable names)
        {
            hooks.Clear();
            foreach (var v in ScriptParams.From(names).List)
                if (v is string s)
                    hooks.Add(s);
        }

        public void AddHook(string name) => hooks.Add(name);

        public void Deliver(ActorEvent e)
        {
            if (e.Encounter == null)
                e.Encounter = this;
            OnEngineEvent(e);
            if (ScriptId != 0 && State != EncounterState.Closed && (hooks.Contains("on" + e.TypeName) || hooks.Contains("*")))
            {
                var r = ScriptRuntime.Instance.Call("rt_content_event", ScriptId, e);
                if (r != null && r.Length > 0 && r[0] as string == "handled")
                    e.Handled = true;
            }
            Parent?.Deliver(e);
        }

        private void OnEngineEvent(ActorEvent e)
        {
            switch (e.Type)
            {
                case ActorEventType.Died:
                    if (e.Actor != null && roster.Contains(e.Actor) && !(e.Actor is Player))
                        corpseUntil[e.Actor] = GameClock.NowMs + (long)(CorpseSeconds(e.Actor) * 1000);
                    break;
                case ActorEventType.Damaged:
                    if (e.Other is Player dp && e.Amount > 0)
                        AddScore(dp, "damage", e.Amount);
                    if (e.Actor is Player victim && e.Other != null)
                        AddScore(victim, "damageTaken", e.Amount);
                    break;
                case ActorEventType.Healed:
                    if (e.Other is Player hp && e.Amount > 0)
                    {
                        AddScore(hp, "healing", e.Amount);
                        if (e.Actor != null && e.Actor.HasTag("protected"))
                            AddScore(hp, "protect", e.Amount);
                    }
                    break;
                case ActorEventType.Talked:
                case ActorEventType.ItemGiven:
                    if (e.Other is Player ip)
                        AddScore(ip, "interactions", 1);
                    break;
            }
        }

        #endregion

        #region Lifecycle

        public void SetReady()
        {
            if (State == EncounterState.Created)
                State = EncounterState.Ready;
        }

        public void Start()
        {
            if (State != EncounterState.Created && State != EncounterState.Ready)
                return;
            State = EncounterState.Running;
            startedAt = GameClock.NowMs;
            endsAt = timeLimitMs > 0 ? startedAt + timeLimitMs : long.MaxValue;
            if (partyAllyGroup != null)
                ApplyPartyAllies();
            Program.Log.Info("Content {0} {1} #{2}: started (seed {3}, {4} participants, {5} actors).", Name, Variant, Id, Rng.Seed, participants.Count, roster.Count);
            if (ScriptId != 0)
                ScriptRuntime.Instance.Call("rt_content_start", ScriptId);
        }

        public void Win(string reason = "script") => Finish(true, reason);

        public void Fail(string reason = "script") => Finish(false, string.IsNullOrEmpty(reason) ? "script" : reason);

        private void Finish(bool success, string reason)
        {
            if (State != EncounterState.Running && State != EncounterState.Ready && State != EncounterState.Created)
                return;
            State = EncounterState.Ending;
            Result = success ? "win" : "fail";
            Reason = reason ?? "";
            endingAt = GameClock.NowMs + cleanupSeconds * 1000L;
            hazards.Clear();
            foreach (var c in roster.ToList())
                if (c.IsAlive() && Factions.Between(c.factionId, Factions.Player) == Relation.Hostile && !keep.Contains(c))
                {
                    c.Brain?.Add("Hold", "ending", ScriptParams.Empty);
                    c.Brain?.Disengage();
                }
            foreach (var child in children.ToList())
                child.Fail("parent");
            Program.Log.Info("Content {0} {1} #{2}: {3} ({4}).", Name, Variant, Id, Result, Reason);
            if (ScriptId != 0)
                ScriptRuntime.Instance.Call("rt_content_end", ScriptId, Result, Reason);
            EventBus.Raise(new ActorEvent(ActorEventType.EncounterEnded) { Encounter = this, Name = Name, Data = Result });
        }

        // Ends at once: despawns the roster and releases the script object.
        public void Close()
        {
            if (State == EncounterState.Closed)
                return;
            if (State != EncounterState.Ending)
            {
                Result = string.IsNullOrEmpty(Result) ? "aborted" : Result;
                State = EncounterState.Ending;
                if (ScriptId != 0)
                    ScriptRuntime.Instance.Call("rt_content_end", ScriptId, Result, "closed");
            }
            foreach (var child in children.ToList())
                child.Close();
            ClearPartyAllies();
            foreach (var c in roster.ToList())
                if (!keep.Contains(c))
                    DespawnActor(c);
            roster.Clear();
            groups.Clear();
            hazards.Clear();
            State = EncounterState.Closed;
            if (ScriptId != 0)
                ScriptRuntime.Instance.Destroy(ScriptId);
            ScriptId = 0;
            Parent?.children.Remove(this);
            ContentManager.Remove(this);
        }

        public void SetCleanupSeconds(int seconds) => cleanupSeconds = Math.Max(0, seconds);
        public void SetArrivalGrace(int seconds) => arrivalGraceSeconds = Math.Max(0, seconds);
        public void SetFailOnWipe(bool value) => failOnWipe = value;
        public void SetFailOnLeave(bool value) => failOnLeave = value;

        public void SetTimeLimit(double seconds)
        {
            timeLimitMs = (long)(Math.Max(0, seconds) * 1000);
            if (State == EncounterState.Running)
                endsAt = timeLimitMs > 0 ? startedAt + timeLimitMs : long.MaxValue;
        }

        public double Elapsed() => ElapsedMs / 1000.0;

        public double Remaining() => timeLimitMs <= 0 || State != EncounterState.Running ? 0 : Math.Max(0, (endsAt - GameClock.NowMs) / 1000.0);

        public void SetPhase(string name)
        {
            string old = Phase;
            Phase = name ?? "";
            EventBus.Raise(new ActorEvent(ActorEventType.PhaseChanged) { Encounter = this, Name = Phase, Data = old });
        }

        // Runs the script's phase change (exit, enter, scoped tasks), not just the name.
        public void GotoPhase(string name)
        {
            if (ScriptId != 0)
                ScriptRuntime.Instance.Call("rt_content_goto", ScriptId, name);
            else
                SetPhase(name);
        }

        public Encounter AddChild(Encounter child)
        {
            child.Parent = this;
            child.Director = child.Director ?? Director;
            foreach (var p in participants.Values)
                child.AddParticipant(p);
            children.Add(child);
            return child;
        }

        #endregion

        #region Tick

        public void Tick()
        {
            long now = GameClock.NowMs;
            CleanCorpses(now);
            if (State == EncounterState.Ending)
            {
                if (now >= endingAt)
                    Close();
                return;
            }
            if (State != EncounterState.Running)
                return;

            CheckParticipants(now);
            if (State != EncounterState.Running)
                return;
            if (now >= endsAt)
            {
                Fail("time");
                return;
            }
            TickRegions();
            TickArena();
            TickHazards(now);
            if (contribution != null && now >= nextContributionCheck)
                CheckContribution(now);
            EvaluateObjectives(now);
        }

        private void CheckParticipants(long now)
        {
            if (participants.Count == 0 && arrived.Count == 0)
                return;
            bool inGrace = now - startedAt < arrivalGraceSeconds * 1000L;
            foreach (var p in participants.Values.ToList())
            {
                bool here = p.playerSession != null && p.CurrentArea == Area && Area.FindActorInArea(p.Id) != null;
                if (here)
                {
                    arrived.Add(p.Id);
                    continue;
                }
                if (Scope == EncounterScope.World && p.playerSession != null)
                    continue;
                if (!arrived.Contains(p.Id) && inGrace)
                    continue;
                participants.Remove(p.Id);
                arrived.Remove(p.Id);
                if (ScriptId != 0)
                    ScriptRuntime.Instance.Call("rt_content_leave", ScriptId, p);
            }
            var present = participants.Values.Where(p => p.playerSession != null).ToList();
            if (present.Count == 0)
            {
                if (!inGrace && failOnLeave)
                    Fail("left");
                return;
            }
            if (failOnWipe && present.All(p => p.IsDead()))
                Fail("ko");
        }

        private void TickRegions()
        {
            if (regions.Count == 0)
                return;
            var movers = roster.Concat(participants.Values).Where(c => c != null && c.IsAlive() && c.CurrentArea == Area).ToList();
            foreach (var r in regions.Values)
            {
                foreach (var c in movers)
                {
                    bool inside = r.Shape.Contains(c.GetPosAsVector3());
                    if (r.Blocks)
                    {
                        if (inside && c is Player)
                            PushOut(c, r.Shape);
                        continue;
                    }
                    if (inside && r.Inside.Add(c.Id))
                        EventBus.Raise(new ActorEvent(ActorEventType.EnteredRegion, c) { Name = r.Name, Encounter = this });
                    else if (!inside && r.Inside.Remove(c.Id))
                        EventBus.Raise(new ActorEvent(ActorEventType.LeftRegion, c) { Name = r.Name, Encounter = this });
                }
            }
        }

        private void PushOut(Character c, Shape s)
        {
            var centre = s.CurrentCentre;
            var p = c.GetPosAsVector3();
            float dx = p.X - centre.X, dz = p.Z - centre.Z;
            float len = (float)Math.Sqrt(dx * dx + dz * dz);
            if (len < 0.01f) { dx = 1; len = 1; }
            var dest = new Vector3(centre.X + dx / len * (s.Radius + 1.5f), p.Y, centre.Z + dz / len * (s.Radius + 1.5f));
            Warp(c, dest);
        }

        private void TickArena()
        {
            if (arena == null || arenaOut == "none")
                return;
            foreach (var p in participants.Values)
            {
                if (p.CurrentArea != Area || p.IsDead() || arena.Contains(p.GetPosAsVector3()))
                    continue;
                if (arenaOut == "ko")
                    p.DelHP(p.GetHP());
                else
                    Warp(p, arena.ClampInside(p.GetPosAsVector3(), 2));
            }
        }

        private static void Warp(Character c, Vector3 dest)
        {
            if (c is Player pl)
                pl.SetPos(dest.X, dest.Y, dest.Z, pl.rotation, true);
            else
                c.aiContainer?.mover?.Teleport(dest, c.rotation);
        }

        private void TickHazards(long now)
        {
            foreach (var h in hazards.ToList())
            {
                if (!h.Resolved && now >= h.GoesOffAt)
                {
                    var candidates = participants.Values.Cast<Character>().Concat(roster).Where(c => c.CurrentArea == Area).Distinct();
                    var hits = h.Resolve(candidates);
                    EventBus.Raise(new ActorEvent(ActorEventType.HazardResolved, h.Source) { Encounter = this, Name = h.Name, Data = hits, Amount = hits.Count });
                    h.OnResolve?.Invoke(hits.ToArray());
                }
                if (h.Resolved && now >= h.LingerUntil)
                    hazards.Remove(h);
            }
        }

        private void CleanCorpses(long now)
        {
            foreach (var kv in corpseUntil.ToList())
            {
                if (now < kv.Value)
                    continue;
                corpseUntil.Remove(kv.Key);
                if (!keep.Contains(kv.Key) && kv.Key.IsDead())
                    DespawnActor(kv.Key, false);
            }
        }

        private void EvaluateObjectives(long now)
        {
            foreach (var o in objectives)
            {
                if (o.State != ObjectiveState.Pending && o.Kind != "protect")
                    continue;
                var before = o.State;
                o.State = Evaluate(o, now);
                if (o.State != before)
                    EventBus.Raise(new ActorEvent(ActorEventType.ObjectiveChanged) { Encounter = this, Name = o.Name, Data = o.State.ToString() });
            }
            foreach (var o in objectives)
            {
                if (o.Role == ObjectiveRole.Fails && o.State == ObjectiveState.Failed) { Fail(o.Name); return; }
                if (o.Role == ObjectiveRole.Wins && o.State == ObjectiveState.Complete) { Win(o.Name); return; }
            }
            var required = objectives.Where(o => o.Role == ObjectiveRole.Required).ToList();
            if (required.Count > 0 && required.All(o => o.State == ObjectiveState.Complete))
                Win(required.Count == 1 ? required[0].Name : "cleared");
        }

        private ObjectiveState Evaluate(Objective o, long now)
        {
            switch (o.Kind)
            {
                case "kill":
                {
                    var g = Group(o.Group);
                    return g.Count > 0 && g.All(c => c.IsDead() || c.CurrentArea == null) && !HasPendingSpawns(o.Group) ? ObjectiveState.Complete : ObjectiveState.Pending;
                }
                case "protect":
                {
                    var g = Group(o.Group);
                    if (g.Count == 0)
                        return o.State;
                    return g.Count(c => c.IsAlive() && c.CurrentArea != null) < o.Min ? ObjectiveState.Failed : ObjectiveState.Pending;
                }
                case "reach":
                {
                    foreach (var c in Group(o.Group))
                        if (c.IsAlive() && o.Point != null && Meteor.Common.Utils.Distance(c.GetPosAsVector3(), o.Point) <= o.Radius)
                            o.Reached.Add(c.Id);
                    return o.Reached.Count >= o.Min ? ObjectiveState.Complete : ObjectiveState.Pending;
                }
                case "survive":
                    return ElapsedMs >= o.Seconds * 1000 ? ObjectiveState.Complete : ObjectiveState.Pending;
                case "hold":
                {
                    if (!regions.TryGetValue(o.Region ?? "", out var r))
                        return ObjectiveState.Pending;
                    bool held = participants.Values.Any(p => p.IsAlive() && r.Shape.Contains(p.GetPosAsVector3()))
                        && !roster.Any(c => c.IsAlive() && Factions.IsHostile(c, participants.Values.FirstOrDefault()) && r.Shape.Contains(c.GetPosAsVector3()));
                    if (!held) { o.HeldSince = 0; return ObjectiveState.Pending; }
                    if (o.HeldSince == 0) o.HeldSince = now;
                    return now - o.HeldSince >= o.Seconds * 1000 ? ObjectiveState.Complete : ObjectiveState.Pending;
                }
                case "count":
                    return Counter(o.Counter) >= o.N ? ObjectiveState.Complete : ObjectiveState.Pending;
                case "custom":
                {
                    var r = o.Fn?.Invoke(this);
                    if (r != null && r.Length > 0)
                    {
                        if (r[0] is bool b) return b ? ObjectiveState.Complete : ObjectiveState.Pending;
                        if (r[0] as string == "failed") return ObjectiveState.Failed;
                        if (r[0] as string == "complete") return ObjectiveState.Complete;
                    }
                    return ObjectiveState.Pending;
                }
                default:
                    return ObjectiveState.Pending;
            }
        }

        private readonly Dictionary<string, int> pendingSpawns = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        public void SetPendingSpawns(string group, int count)
        {
            pendingSpawns[group] = Math.Max(0, count);
        }

        private bool HasPendingSpawns(string group) => group != null && pendingSpawns.TryGetValue(group, out int n) && n > 0;

        private void CheckContribution(long now)
        {
            nextContributionCheck = now + (long)(contribution.Float("check", 120) * 1000);
            if (ElapsedMs < contribution.Float("grace", 120) * 1000)
                return;
            string key = contribution.String("key");
            double min = contribution.Float("min", 1);
            int maxWarnings = contribution.Int("warnings", 3);
            foreach (var p in participants.Values)
            {
                if (dropped.Contains(p.Id))
                    continue;
                double total = key != null ? Score(p, key) : Contribution(p);
                double expected = min * ElapsedMs / 60000.0;
                if (total >= expected)
                    continue;
                warnings.TryGetValue(p.Id, out int w);
                warnings[p.Id] = ++w;
                EventBus.Raise(new ActorEvent(ActorEventType.Signal, p) { Encounter = this, Name = "contributionWarning", Amount = w });
                if (w >= maxWarnings)
                {
                    dropped.Add(p.Id);
                    EventBus.Raise(new ActorEvent(ActorEventType.Signal, p) { Encounter = this, Name = "contributionDropped", Amount = w });
                }
            }
        }

        #endregion

        #region Participants

        public void AddParticipant(Player p)
        {
            if (p == null || participants.ContainsKey(p.Id))
                return;
            participants[p.Id] = p;
            foreach (var child in children)
                child.AddParticipant(p);
            if (ScriptId != 0 && State == EncounterState.Running)
                ScriptRuntime.Instance.Call("rt_content_join", ScriptId, p);
        }

        public void RemoveParticipant(Player p)
        {
            if (p != null && participants.Remove(p.Id))
            {
                arrived.Remove(p.Id);
                if (ScriptId != 0)
                    ScriptRuntime.Instance.Call("rt_content_leave", ScriptId, p);
            }
        }

        public bool IsParticipant(Character c) => c is Player && participants.ContainsKey(c.Id);

        public List<Player> ParticipantList() => participants.Values.Where(p => p.playerSession != null).ToList();

        public bool IsDropped(Player p) => p != null && dropped.Contains(p.Id);

        #endregion

        #region Roster

        // Tests replace this to spawn without the database.
        public static Func<uint, Area, float, float, float, float, int, string, SpawnLook, BattleNpc> SpawnFactory =
            (pool, area, x, y, z, rot, level, kind, look) => Server.GetWorldManager().CreateBattleNpcFromPool(pool, area, x, y, z, rot, level, kind, look);

        public BattleNpc SpawnActor(LuaTable specTable)
        {
            var spec = ScriptParams.From(specTable);
            return Spawn(spec);
        }

        public BattleNpc Spawn(ScriptParams spec)
        {
            if (State == EncounterState.Closed || Area == null)
                return null;
            var at = spec.Point("at") ?? Anchor ?? new Vector3(0, 0, 0);
            float rot = spec.Float("rot", spec.Table("at")?.Float("rot", spec.Table("at")?.Number(3) ?? 0) ?? 0);
            string kind = spec.String("kind", "BattleNpc");
            SpawnLook look = null;
            if (spec.Has("classId") || spec.Has("classPath") || spec.Has("name"))
                look = new SpawnLook { ClassId = (uint)spec.Int("classId", 0), ClassPath = spec.String("classPath"), Name = spec.String("name") };
            var npc = SpawnFactory((uint)spec.Int("pool"), Area, at.X, at.Y, at.Z, rot, spec.Int("level", 1), kind, look);
            if (npc == null)
                return null;
            npc.content = this;
            npc.deferAttach = true;
            // Hit points are 16-bit in the client's character work.
            if (spec.Has("hp"))
                npc.SetMod((uint)actors.chara.Modifier.Hp, Math.Min(spec.Int("hp"), short.MaxValue));
            string faction = spec.String("faction");
            if (faction != null)
                npc.factionId = Factions.Define(faction);
            var tags = spec.Table("tags");
            if (tags != null)
                foreach (var t in tags.List)
                    if (t is string s)
                        npc.tags.Add(s);
            if (spec.Get("owner") is Character owner)
                npc.ownerChara = owner;
            npc.CalculateBaseStats();
            npc.RecalculateStats();
            if (spec.Has("hp"))
                npc.SetHP((uint)npc.GetMaxHP());
            roster.Add(npc);
            foreach (var g in GroupNames(spec))
                AddToGroup(npc, g);
            if (spec.Get("corpse") as string == "keep" || spec.Bool("keep", false))
                keep.Add(npc);
            if (spec.Has("corpse") && spec.Get("corpse") is double cs)
                corpseSeconds[npc] = cs;
            Area.AddActorToZone(npc);
            return npc;
        }

        private readonly Dictionary<Character, double> corpseSeconds = new Dictionary<Character, double>();

        private double CorpseSeconds(Character c) => corpseSeconds.TryGetValue(c, out var s) ? s : 12;

        private static IEnumerable<string> GroupNames(ScriptParams spec)
        {
            var g = spec.Get("group");
            if (g is string s)
                yield return s;
            else if (g is ScriptParams list)
                foreach (var v in list.List)
                    if (v is string name)
                        yield return name;
        }

        // Puts an actor that was not spawned by this encounter (a world spawn, a player's pet)
        // under it.
        public void Adopt(Character c, string group)
        {
            if (c == null)
                return;
            c.content = this;
            if (!roster.Contains(c))
                roster.Add(c);
            if (group != null)
                AddToGroup(c, group);
        }

        public void AddToGroup(Character c, string group)
        {
            if (!groups.TryGetValue(group, out var list))
                groups[group] = list = new List<Character>();
            if (!list.Contains(c))
                list.Add(c);
        }

        public List<Character> Group(string name)
        {
            if (name == null)
                return roster.ToList();
            if (name == "participants")
                return participants.Values.Cast<Character>().ToList();
            return groups.TryGetValue(name, out var list) ? list.ToList() : new List<Character>();
        }

        public int GroupAlive(string name) => Group(name).Count(c => c.IsAlive() && c.CurrentArea != null);

        public bool SharesGroup(Character a, Character b) => groups.Values.Any(g => g.Contains(a) && g.Contains(b));

        public List<string> GroupsOf(Character c) => groups.Where(kv => kv.Value.Contains(c)).Select(kv => kv.Key).ToList();

        public List<Character> Roster() => roster.ToList();

        public void Keep(Character c, bool value)
        {
            if (value) keep.Add(c); else keep.Remove(c);
        }

        public void DespawnActor(Character c, bool forget = true)
        {
            if (c == null)
                return;
            if (forget)
            {
                roster.Remove(c);
                foreach (var g in groups.Values)
                    g.Remove(c);
                corpseUntil.Remove(c);
            }
            c.Brain?.Detach();
            if (c is Npc npc && npc.CurrentArea != null && npc.CurrentArea.FindActorInArea(npc.Id) != null)
                npc.Despawn();
            if (c.content == this && forget)
                c.content = null;
        }

        // Shows the group's actors in participants' party lists (story allies).
        // The client's nameplate and selection switch is charaWork.property[0].
        public void SetTargetable(Character chara, bool targetable)
        {
            if (chara == null)
                return;
            byte want = (byte)(targetable ? 1 : 0);
            if (chara.charaWork.property[0] == want)
                return;
            chara.charaWork.property[0] = want;
            if (chara.CurrentArea != null)
            {
                var util = new Meteor.Map.utils.ActorPropertyPacketUtil("charaWork/property", chara);
                util.AddProperty("charaWork.property[0]");
                chara.CurrentArea.BroadcastPacketsAroundActor(chara, util.Done());
            }
        }

        public void SetPartyAllies(string group)
        {
            partyAllyGroup = group;
            if (State == EncounterState.Running)
                ApplyPartyAllies();
        }

        private void ApplyPartyAllies()
        {
            var allies = Group(partyAllyGroup).Where(c => c.IsAlive()).ToList();
            foreach (Party party in ParticipantList().Select(p => p.currentParty).OfType<Party>().Distinct())
                party.SetNpcMembers(allies);
        }

        // The client drops ally gauges sent before it has loaded the allies, and full-HP allies send no
        // more until hit.
        public void OnZoneInComplete(Player p)
        {
            if (State == EncounterState.Running && partyAllyGroup != null && IsParticipant(p)
                && p.playerSession != null && p.currentParty is Party party)
                party.SendGroupPackets(p.playerSession);
        }

        private void ClearPartyAllies()
        {
            if (partyAllyGroup == null)
                return;
            foreach (Party party in participants.Values.Select(p => p.currentParty).OfType<Party>().Distinct())
                party.SetNpcMembers(new List<Character>());
        }

        #endregion

        #region Relations, objectives, arena

        public void SetRelation(string a, string b, string relation)
        {
            int ia = Factions.Define(a), ib = Factions.Define(b);
            var r = Factions.Parse(relation);
            relations[(ia, ib)] = r;
            relations[(ib, ia)] = r;
        }

        public Relation? RelationOverride(int a, int b)
        {
            if (relations.Count > 0 && relations.TryGetValue((a, b), out var r))
                return r;
            return Parent?.RelationOverride(a, b);
        }

        public void AddObjective(string name, string kind, LuaTable spec, string role)
        {
            objectives.RemoveAll(o => o.Name == name);
            objectives.Add(Objective.From(name, kind, ScriptParams.From(spec), role));
        }

        public string GetObjectiveState(string name) => objectives.FirstOrDefault(o => o.Name == name)?.State.ToString();

        public void SetArena(LuaTable spec)
        {
            var p = ScriptParams.From(spec);
            arena = Shape.From(p);
            arenaOut = p.String("out", "push");
        }

        public Shape Arena => arena;

        public void AddRegion(string name, LuaTable spec)
        {
            var p = ScriptParams.From(spec);
            regions[name] = new Region
            {
                Name = name,
                Shape = Shape.From(p),
                Blocks = p.Bool("blocks", false),
                OpenAnimation = p.String("openAnimation"),
                MapObjectId = (uint)p.Int("object"),
            };
        }

        public void SetDoor(string name, bool open)
        {
            if (!regions.TryGetValue(name, out var r))
                return;
            bool wasBlocking = r.Blocks;
            r.Blocks = !open;
            if (open && wasBlocking && r.MapObjectId != 0 && Area.FindActorInArea(r.MapObjectId) is Npc obj && r.OpenAnimation != null)
                foreach (var p in ParticipantList())
                    obj.PlayMapObjAnimation(p, r.OpenAnimation);
        }

        public bool IsDoorOpen(string name) => regions.TryGetValue(name, out var r) && !r.Blocks;

        public int AddHazard(LuaTable spec, Character source)
        {
            var h = Hazard.From(ScriptParams.From(spec), source);
            if (h.Shape == null)
                return 0;
            hazards.Add(h);
            return h.Id;
        }

        public void ClearHazard(int id) => hazards.RemoveAll(h => h.Id == id);

        public void ClearHazards() => hazards.Clear();

        public Hazard HazardAt(Vector3 p, Character who) => hazards.FirstOrDefault(h => !h.Resolved && h.Covers(p, who));

        #endregion

        #region Scores

        public void AddScore(Player p, string key, double n)
        {
            if (p == null)
                return;
            if (!scores.TryGetValue(p.Id, out var s))
                scores[p.Id] = s = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            s.TryGetValue(key, out double v);
            s[key] = v + n;
        }

        public double Score(Player p, string key)
        {
            return p != null && scores.TryGetValue(p.Id, out var s) && s.TryGetValue(key, out var v) ? v : 0;
        }

        public double Contribution(Player p)
        {
            return Score(p, "damage") + Score(p, "healing") + Score(p, "protect") * 2 + Score(p, "interactions") * 100 + Score(p, "bonus");
        }

        public double Counter(string name) => counters.TryGetValue(name ?? "", out var v) ? v : 0;

        public double AddCounter(string name, double n)
        {
            counters.TryGetValue(name, out double v);
            counters[name] = v + n;
            return v + n;
        }

        public void SetContributionRule(LuaTable spec)
        {
            contribution = ScriptParams.From(spec);
            nextContributionCheck = GameClock.NowMs + (long)(contribution.Float("check", 120) * 1000);
        }

        #endregion

        public void Broadcast(ushort textId, params object[] args)
        {
            foreach (var p in ParticipantList())
                p.SendGameMessage(Server.GetWorldManager().GetActor(), textId, 0x20, args);
        }

        public void Music(ushort id)
        {
            foreach (var p in ParticipantList())
                p.ChangeMusic(id);
        }

        public object Snapshot()
        {
            return new
            {
                id = Id, name = Name, variant = Variant, scope = Scope.ToString(), state = State.ToString(), phase = Phase,
                result = Result, reason = Reason, seed = Rng.Seed, area = Area?.ZoneName, elapsed = Elapsed(), remaining = Remaining(),
                parent = Parent?.Id, children = children.Select(c => c.Id).ToList(),
                participants = participants.Values.Select(p => p.DisplayName).ToList(),
                groups = groups.ToDictionary(kv => kv.Key, kv => kv.Value.Select(c => c.GetName() + "#" + c.Id + (c.IsDead() ? " (dead)" : "")).ToList()),
                objectives = objectives.Select(o => o.Snapshot()).ToList(),
                hazards = hazards.Select(h => new { h.Id, h.Name, kind = h.Shape.Kind, inMs = h.GoesOffAt - GameClock.NowMs, h.Resolved }).ToList(),
                regions = regions.Values.Select(r => new { r.Name, r.Blocks, inside = r.Inside.Count }).ToList(),
                counters,
                scores = scores.ToDictionary(kv => kv.Key.ToString(), kv => kv.Value),
                tasks = ScriptId != 0 ? ScriptRuntime.Instance.Call("rt_content_describe", ScriptId)?.FirstOrDefault() : null,
            };
        }
    }

    // Spawns that look like something other than their pool: a story character's own class or name.
    class SpawnLook
    {
        public uint ClassId;
        public string ClassPath;
        public string Name;
    }
}
