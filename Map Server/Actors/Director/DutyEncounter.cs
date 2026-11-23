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

using Meteor.Common;
using Meteor.Map.actors.area;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.actors.group;
using Meteor.Map.Actors;
using Meteor.Map.lua;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Meteor.Map.actors.director
{
    // A quest battle in a content area: enemies (now or in waves) and story allies spawned from battle
    // npc pools, won when every required enemy is dead. The quest director gets optional Lua callbacks:
    // onDutyStart, onDutyWave, onDutyMobDeath, onDutyAllyDeath, onDutyComplete(success, reason), where
    // reason is "cleared", "script", "ko" or "left".
    class DutyEncounter
    {
        public const int WAVE_DELAY_SECONDS = 3;
        public const int CORPSE_SECONDS = 12;
        public const int ARRIVAL_GRACE_SECONDS = 60;
        public const float ALLY_ASSIST_RANGE = 40f;
        public const uint TANK_PULL_ENMITY = 5000;
        public const int CONTENT_GROUP_CAPACITY = 24;

        public const ushort T_TIME_MINUTES = 25018, T_TIME_SECONDS = 25019, T_PARTY_DEFEATED = 51147, T_ALL_LEFT = 51067;

        public enum DutyState { Setup, Running, Succeeded, Failed, Ended }

        private class Entry
        {
            public BattleNpc npc;
            public bool ally, escort, required = true;
        }

        private class Pending
        {
            public uint poolId;
            public int level;
            public float x, y, z, rot;
        }

        private readonly Director director;
        private readonly Area area;
        private DutyState state = DutyState.Setup;
        private string result = "";

        private readonly Dictionary<uint, Player> participants = new Dictionary<uint, Player>();
        private readonly HashSet<uint> arrived = new HashSet<uint>();
        private readonly List<Entry> entries = new List<Entry>();
        private readonly SortedDictionary<int, List<Pending>> waves = new SortedDictionary<int, List<Pending>>();
        private readonly Dictionary<BattleNpc, DateTime> deathTimes = new Dictionary<BattleNpc, DateTime>();

        private int currentWave = 0;
        private bool winOnClear = true;
        private bool allyAggressive = true;
        private int timeLimitSeconds = 0;
        private readonly HashSet<int> timeWarnings = new HashSet<int>();
        private DateTime startTick, endTick;
        private DateTime? nextWaveAt;
        private bool packAggro;
        private BattleNpc tank, pulledMob;
        private double tankPullSeconds;
        private DateTime? tankPullAt;

        public DutyEncounter(Director director, Area area)
        {
            this.director = director;
            this.area = area;
        }

        #region Setup
        public Director GetDirector() { return director; }
        public Area GetArea() { return area; }

        public void AddPlayer(Player player)
        {
            if (player != null && !participants.ContainsKey(player.Id))
                participants[player.Id] = player;
        }

        public void AddDirectorPlayers()
        {
            foreach (Actor a in director.GetPlayerMembers())
                AddPlayer(a as Player);
        }

        // Seconds; 0 = none.
        public void SetTimeLimit(int seconds) { timeLimitSeconds = Math.Max(0, seconds); }

        // false: clearing the enemies does not win; the script calls Succeed().
        public void SetWinOnClear(bool value) { winOnClear = value; }

        // false: idle allies only join fights the players' side is already in.
        public void SetAllyAggressive(bool value) { allyAggressive = value; }

        public BattleNpc SpawnAlly(uint poolId, int level, float x, float y, float z, float rot)
        {
            return Spawn(poolId, level, x, y, z, rot, true);
        }

        // The first mob the players pull turns to this ally after the given seconds.
        public void SetTank(BattleNpc ally, double seconds)
        {
            tank = ally;
            tankPullSeconds = Math.Max(0, seconds);
        }

        public BattleNpc SpawnEscort(uint poolId, int level, float x, float y, float z, float rot)
        {
            BattleNpc npc = Spawn(poolId, level, x, y, z, rot, true);
            if (npc is Ally ally)
            {
                ally.passive = true;
                Find(npc).escort = true;
            }
            return npc;
        }

        public void SetEscortFollow(BattleNpc escort, Character leader, float gap)
        {
            if (escort is Ally ally)
            {
                ally.escortFollow = leader;
                ally.escortFollowGap = Math.Max(1f, gap);
            }
        }

        public BattleNpc SpawnEnemy(uint poolId, int level, float x, float y, float z, float rot)
        {
            return Spawn(poolId, level, x, y, z, rot, false);
        }

        public void AddWaveEnemy(int wave, uint poolId, int level, float x, float y, float z, float rot)
        {
            wave = Math.Max(1, wave);
            if (!waves.TryGetValue(wave, out var list))
                waves[wave] = list = new List<Pending>();
            list.Add(new Pending { poolId = poolId, level = level, x = x, y = y, z = z, rot = rot });
        }

        public void SetRequired(BattleNpc mob, bool required)
        {
            Entry e = Find(mob);
            if (e != null)
                e.required = required;
        }

        public void Start()
        {
            if (state != DutyState.Setup)
                return;
            if (participants.Count == 0)
                AddDirectorPlayers();
            state = DutyState.Running;
            startTick = GameClock.Now;
            endTick = timeLimitSeconds > 0 ? startTick.AddSeconds(timeLimitSeconds) : DateTime.MaxValue;
            SetPartyAllies(GetAllies().Cast<Character>().ToList());
            Program.Log.Info("Duty {0}: started ({1} players, {2} placed, {3} waves).", director.GetScriptPath(), participants.Count, entries.Count, waves.Count);
            Callback("onDutyStart");
            if (!entries.Any(e => !e.ally) && waves.Count > 0)
                SpawnNextWave();
        }

        public void Succeed()
        {
            Finish(true, "script");
        }

        public void Fail(string reason)
        {
            Finish(false, string.IsNullOrEmpty(reason) ? "script" : reason);
        }

        public void End()
        {
            if (state == DutyState.Ended)
                return;
            if (state == DutyState.Running || state == DutyState.Setup)
                state = DutyState.Failed;
            SetPartyAllies(new List<Character>());
            foreach (Entry e in entries)
                DespawnNpc(e.npc);
            entries.Clear();
            deathTimes.Clear();
            waves.Clear();
            state = DutyState.Ended;
        }
        #endregion

        #region Queries
        public bool IsRunning() { return state == DutyState.Running; }
        public bool IsOver() { return state == DutyState.Succeeded || state == DutyState.Failed || state == DutyState.Ended; }
        public bool IsSuccess() { return state == DutyState.Succeeded || (state == DutyState.Ended && result == "success"); }
        public string GetResult() { return result; }
        public int GetWave() { return currentWave; }
        public int GetSecondsLeft() { return timeLimitSeconds <= 0 || state != DutyState.Running ? 0 : Math.Max(0, (int)(endTick - GameClock.Now).TotalSeconds); }
        public int GetEnemiesLeft() { return entries.Count(e => !e.ally && e.required && Living(e.npc)); }
        public List<Player> GetPlayers() { return Participants().ToList(); }
        public List<BattleNpc> GetEnemies() { return entries.Where(e => !e.ally && Living(e.npc)).Select(e => e.npc).ToList(); }
        public List<BattleNpc> GetAllies() { return entries.Where(e => e.ally && Living(e.npc)).Select(e => e.npc).ToList(); }
        #endregion

        #region Engine
        public void Tick(DateTime tick)
        {
            PruneDead(tick);
            if (state != DutyState.Running)
                return;

            CheckParticipants(tick);
            if (state != DutyState.Running)
                return;

            CheckPackAggro(tick);
            CheckTankPull(tick);
            AssistAllies();

            if (nextWaveAt == null)
                CheckWaveCleared();
            if (state == DutyState.Running && nextWaveAt != null && tick >= nextWaveAt.Value)
            {
                nextWaveAt = null;
                SpawnNextWave();
            }

            if (state == DutyState.Running && timeLimitSeconds > 0)
                CheckTimer(tick);
        }

        private void CheckTimer(DateTime tick)
        {
            int left = (int)Math.Ceiling((endTick - tick).TotalSeconds);
            foreach (int m in new[] { 10, 5, 1 })
                if (left <= m * 60 && timeLimitSeconds > m * 60 && timeWarnings.Add(m * 60))
                    Broadcast(T_TIME_MINUTES, m);
            foreach (int s in new[] { 30, 10 })
                if (left <= s && timeLimitSeconds > s && timeWarnings.Add(s))
                    Broadcast(T_TIME_SECONDS, s);
            if (left <= 0)
                Finish(false, "time");
        }

        public void OnMobDeath(BattleNpc npc, Character killer)
        {
            Entry e = Find(npc);
            if (e == null)
                return;
            deathTimes[npc] = GameClock.Now;
            if (state != DutyState.Running)
                return;

            if (e.ally)
            {
                Callback("onDutyAllyDeath", npc);
                return;
            }
            RetargetAllies(npc);
            Callback("onDutyMobDeath", npc, killer);
            if (state == DutyState.Running)
                CheckWaveCleared();
        }

        // Allies go straight to the next enemy in the fight, so they stay in battle stance.
        private void RetargetAllies(BattleNpc dead)
        {
            var fighting = entries.Where(x => !x.ally && x.npc != dead && Living(x.npc) && x.npc.hateContainer.GetHateList().Count > 0)
                .Select(x => x.npc).ToList();
            foreach (Entry a in entries.Where(x => x.ally && !x.escort && Living(x.npc)))
            {
                BattleNpc ally = a.npc;
                if (ally.hateContainer.HasHateForTarget(dead))
                    ally.hateContainer.ClearHate(dead);
                if (ally.hateContainer.GetHateList().Keys.Any(c => c.IsAlive()) || fighting.Count == 0)
                    continue;
                BattleNpc next = fighting.FirstOrDefault(m => m.target == ally)
                    ?? fighting.OrderBy(m => Utils.Distance(ally.GetPosAsVector3(), m.GetPosAsVector3())).First();
                ally.hateContainer.AddBaseHate(next);
            }
        }

        private void CheckWaveCleared()
        {
            if (entries.Any(x => !x.ally && x.required && Living(x.npc)))
                return;
            if (waves.Keys.Any(w => w > currentWave))
            {
                if (nextWaveAt == null)
                    nextWaveAt = GameClock.Now.AddSeconds(WAVE_DELAY_SECONDS);
                return;
            }
            if (winOnClear)
                Finish(true, "cleared");
        }

        private void SpawnNextWave()
        {
            int next = waves.Keys.Where(w => w > currentWave).DefaultIfEmpty(0).Min();
            if (next == 0)
                return;
            currentWave = next;
            foreach (Pending p in waves[next])
                Spawn(p.poolId, p.level, p.x, p.y, p.z, p.rot, false);
            Callback("onDutyWave", next);
        }

        private void CheckParticipants(DateTime tick)
        {
            bool inGrace = (tick - startTick).TotalSeconds < ARRIVAL_GRACE_SECONDS;
            foreach (Player p in participants.Values.ToList())
            {
                if (p.playerSession != null && p.CurrentArea == area && area.FindActorInArea(p.Id) != null)
                {
                    arrived.Add(p.Id);
                    continue;
                }
                if (!arrived.Contains(p.Id) && inGrace)
                    continue;
                Program.Log.Info("Duty {0}: {1} left the duty.", director.GetScriptPath(), p.DisplayName);
                participants.Remove(p.Id);
                arrived.Remove(p.Id);
            }

            var present = Participants().ToList();
            if (present.Count == 0)
            {
                if (!inGrace)
                {
                    Broadcast(T_ALL_LEFT);
                    Finish(false, "left");
                }
                return;
            }
            if (present.All(p => p.IsDead()))
            {
                Broadcast(T_PARTY_DEFEATED);
                Finish(false, "ko");
            }
        }

        // The client drops ally gauges sent before it has loaded the allies, and full-HP allies send no
        // more until hit.
        public void OnZoneInComplete(Player p)
        {
            if (state == DutyState.Running && participants.ContainsKey(p.Id) && p.CurrentArea == area
                && p.playerSession != null && p.currentParty is Party party)
                party.SendGroupPackets(p.playerSession);
        }

        // The first hit on any enemy pulls the whole pack: the others go for the tank (or that player
        // when there is none), the one hit stays on the player until the tank pull.
        private void CheckPackAggro(DateTime tick)
        {
            if (packAggro)
                return;
            var enemies = entries.Where(e => !e.ally && Living(e.npc)).Select(e => e.npc).ToList();
            BattleNpc first = enemies.FirstOrDefault(m => m.hateContainer.GetHateList().Keys.Any(c => c is Player));
            if (first == null)
                return;
            packAggro = true;
            pulledMob = first;
            Character puller = first.hateContainer.GetHateList().Keys.First(c => c is Player);
            // Allies' hits must not take the first mob off the player before the tank pull.
            if (Living(tank))
                first.hateContainer.GetHateList()[puller].cumulativeEnmity += TANK_PULL_ENMITY;
            Character linkTarget = Living(tank) ? tank : puller;
            foreach (BattleNpc mob in enemies.Where(m => m != first))
            {
                mob.neutral = false;
                mob.hateContainer.AddLinkHate(linkTarget);
                if (linkTarget == tank)
                    mob.hateContainer.GetHateList()[tank].cumulativeEnmity = TANK_PULL_ENMITY;
                if (!mob.aiContainer.IsEngaged())
                    mob.Engage(linkTarget);
            }
            if (tank != null)
                tankPullAt = tick.AddSeconds(tankPullSeconds);
        }

        private void CheckTankPull(DateTime tick)
        {
            if (tankPullAt == null || tick < tankPullAt.Value)
                return;
            tankPullAt = null;
            if (!Living(tank) || !Living(pulledMob))
                return;
            uint top = pulledMob.hateContainer.GetHateList().Values.Select(h => h.cumulativeEnmity).DefaultIfEmpty(0u).Max();
            pulledMob.hateContainer.UpdateHate(tank, (int)(top + TANK_PULL_ENMITY));
            tank.hateContainer.UpdateHate(pulledMob, (int)TANK_PULL_ENMITY);
            if (!tank.aiContainer.IsEngaged())
                tank.Engage(pulledMob);
        }

        private void AssistAllies()
        {
            var enemies = entries.Where(e => !e.ally && Living(e.npc)).Select(e => e.npc).ToList();
            if (enemies.Count == 0)
                return;
            foreach (Entry a in entries.Where(e => e.ally && !e.escort && Living(e.npc)))
            {
                BattleNpc ally = a.npc;
                if (ally.aiContainer.IsEngaged())
                    continue;
                BattleNpc pick = enemies.Where(m => m.hateContainer.GetHateList().Count > 0)
                    .OrderBy(m => Utils.Distance(ally.GetPosAsVector3(), m.GetPosAsVector3())).FirstOrDefault();
                if (pick == null && allyAggressive)
                    pick = enemies.Where(m => Utils.Distance(ally.GetPosAsVector3(), m.GetPosAsVector3()) <= ALLY_ASSIST_RANGE)
                        .OrderBy(m => Utils.Distance(ally.GetPosAsVector3(), m.GetPosAsVector3())).FirstOrDefault();
                if (pick == null)
                    continue;
                ally.hateContainer.AddBaseHate(pick);
                ally.Engage(pick);
            }
        }

        private void Finish(bool success, string reason)
        {
            if (state != DutyState.Running && state != DutyState.Setup)
                return;
            state = success ? DutyState.Succeeded : DutyState.Failed;
            result = success ? "success" : reason;
            nextWaveAt = null;

            foreach (Entry e in entries.Where(x => !x.ally && Living(x.npc)).ToList())
                DespawnNpc(e.npc);

            Program.Log.Info("Duty {0}: {1} ({2}).", director.GetScriptPath(), success ? "won" : "failed", reason);
            Callback("onDutyComplete", success, reason);
        }

        private void PruneDead(DateTime tick)
        {
            foreach (var kv in deathTimes.ToList())
            {
                if ((tick - kv.Value).TotalSeconds < CORPSE_SECONDS)
                    continue;
                deathTimes.Remove(kv.Key);
                DespawnNpc(kv.Key);
            }
        }
        #endregion

        #region Helpers
        private BattleNpc Spawn(uint poolId, int level, float x, float y, float z, float rot, bool ally)
        {
            if (state == DutyState.Ended)
                return null;
            BattleNpc npc = area.SpawnDutyBattleNpc(poolId, level, x, y, z, rot, ally, this);
            if (npc == null)
                return null;
            entries.Add(new Entry { npc = npc, ally = ally });

            var group = director.GetContentGroup();
            if (group != null && (ally || group.GetMembers().Count < CONTENT_GROUP_CAPACITY))
                group.AddMember(npc);
            else if (group == null && ally)
                Program.Log.Warn("Duty ally {0} has no content group (director created without one).", npc.Id);
            return npc;
        }

        private void SetPartyAllies(List<Character> allies)
        {
            foreach (Party party in Participants().Select(p => p.currentParty).OfType<Party>().Distinct())
                party.SetNpcMembers(allies);
        }

        private Entry Find(BattleNpc npc)
        {
            return npc == null ? null : entries.FirstOrDefault(e => e.npc == npc);
        }

        private bool Living(BattleNpc npc)
        {
            return npc != null && npc.IsAlive() && npc.CurrentArea != null && area.FindActorInArea(npc.Id) != null;
        }

        private void DespawnNpc(BattleNpc npc)
        {
            if (npc == null)
                return;
            var group = director.GetContentGroup();
            if (group != null && group.GetMembers().Contains(npc.Id))
                group.RemoveMember(npc.Id);
            if (npc.CurrentArea != null && area.FindActorInArea(npc.Id) != null)
                npc.Despawn();
        }

        private IEnumerable<Player> Participants()
        {
            return participants.Values.Where(p => p.playerSession != null).ToList();
        }

        private void Broadcast(ushort textId, params object[] args)
        {
            foreach (Player p in Participants())
                p.SendGameMessage(Server.GetWorldManager().GetActor(), textId, 0x20, args);
        }

        private void Callback(string function, params object[] args)
        {
            Player lead = Participants().FirstOrDefault(p => p.CurrentArea == area) ?? Participants().FirstOrDefault();
            if (lead == null)
                return;
            object[] all = new object[args.Length + 1];
            all[0] = this;
            Array.Copy(args, 0, all, 1, args.Length);
            try
            {
                LuaEngine.GetInstance().CallLuaFunction(lead, director, function, true, all);
            }
            catch (Exception e)
            {
                Program.Log.Error("Duty callback {0} failed: {1}", function, e);
            }
        }
        #endregion
    }
}
