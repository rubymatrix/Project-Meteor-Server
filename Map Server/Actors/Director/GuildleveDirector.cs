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
using Meteor.Map.actors.chara.ai.utils;
using Meteor.Map.actors.director.Work;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.actors.chara.player;
using Meteor.Map.actors.group;
using Meteor.Map.Actors;
using Meteor.Map.Actors.Chara;
using Meteor.Map.DataObjects;
using Meteor.Map.utils;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Meteor.Map.actors.director
{
    // Regional battlecraft leve runtime. The client's PrivateGLBattle* classes are stubs: all it shows
    // comes from GuildleveBaseClass reading guildleveWork (and work/info for Survive and Round).
    // GuildlevePlan says what spawns; this class runs start, participants, enemy level, markers, kill
    // credit, timer, leash, success or failure, teardown and rewards.
    class GuildleveDirector : Director
    {
        public const int LEVE_KILL_EXP_BONUS_PERCENT = 50;   // leve kills give x1.5 EXP
        public const int ENEMY_LEVEL_PER_STAR = 3;
        public const float LEASH_WARN = 400f;   // 50083
        public const float LEASH_FAIL = 450f;   // 50104
        public const float SURVIVE_LEASH = 60f;                 // Survive: from the defense point
        public const float ANCHOR_MIN = 80f, ANCHOR_MAX = 300f;
        public const float ANCHOR_SPACING = 40f;
        public const int ANCHOR_COUNT = 12;
        public const float GROUP_JITTER = 5f;
        public const int START_DELAY_SECONDS = 3;
        // Begin only says 50036 and 50011. "Activated!", the time left and the timer follow a few
        // seconds after the targets and markers are out, as on retail, or sooner when a participant
        // engages a target, walks this far out from the aetheryte or comes this close to an objective.
        public const float ACTIVATE_DISTANCE = 60f;
        public const float ACTIVATE_OBJECTIVE_RADIUS = 50f;
        public const int ACTIVATE_DELAY_SECONDS = 4;
        // 50023 comes a few seconds after the last objective.
        public const int COMPLETE_DELAY_SECONDS = 7;
        // Drop variant: a page comes with the last kill of a carrier group, 2 in 3, and always after 2
        // empty groups in a row.
        public const int ORB_PAGE_ODDS_IN_3 = 2;
        public const int ORB_PAGE_PITY = 2;
        // Gather: each kill gives the item at this chance, and always after 2 empty kills in a row so a run
        // cannot stall.
        public const int GATHER_ITEM_PERCENT = 50;
        public const int GATHER_ITEM_PITY = 2;
        // The bonus treasure box is a plain talk event on the client.
        public const uint GUILDLEVE_BONUS_BOX = 1200161;
        public const int BONUS_BOX_PERCENT = 10;
        public const int FAIL_TEARDOWN_SECONDS = 20;
        public const int NODE_LIFETIME_SECONDS = 30;   // 50032 "will dissipate in 30 seconds"
        public const int FLEE_HP_PERCENT = 50;
        public const int CORPSE_SECONDS = 12;   // despawnTime 10 s + margin
        public const float ROUND_REACH = 8f;
        public const float SURVIVE_REACH = 15f;
        public const int SURVIVE_WAVE_SECONDS = 45;
        public const float SPEED_BONUS_FRACTION = 0.5f;
        public const uint GUILDLEVE_WARP_POINT = 1200040;
        // The client has no class id for /Chara/Npc/Object/GuildleveSearchPoint;
        // seed_leve_04_execution.sql binds this unused leve-object class (model 20930) to it.
        public const uint GUILDLEVE_SEARCH_POINT = 1200168;
        public const uint ITEM_GIL = 1000001;
        public const uint ITEM_NECROLOGOS = 12000004;

        // worldMaster text ids
        private const ushort T_ACTIVATED = 50022, T_COMPLETE = 50023, T_ABORTED = 50024, T_TIME_UP = 50025,
            T_TIME_LEFT = 50026, T_TIME_WARN = 50027, T_NODE = 50029, T_NODE_30S = 50032, T_NODE_FADES = 50033,
            T_DEFEATED_NAMED = 50041, T_DEFEATED = 50042, T_OBTAIN = 50043, T_APPEARS = 50045, T_SUMMONED = 50046,
            T_UNEXPECTED = 50047, T_FLEE = 50048, T_TRUE_FORM = 50049, T_NOTHING = 50051, T_MONSTER_APPEARS = 50053,
            T_LOST_SIGHT = 50058, T_PATROL = 50066, T_ARRIVED = 50067, T_LEFT = 50068, T_DESTROY_BOOK = 50071,
            T_DIFFICULTY_SET = 50081, T_LEASH_WARN = 50083, T_EXP_BONUS = 50130, T_FACTION_BONUS = 50131,
            T_FACTION_EARN = 50132, T_UNCLAIMED = 50040,
            T_GROUP_ENGAGED = 30118, T_GROUP_DEFEATED = 30119;

        public uint guildleveId;
        public Player guildleveOwner;
        public byte selectedDifficulty;

        public GuildleveData guildleveData;
        public GuildleveWork guildleveWork = new GuildleveWork();
        // Director work table, sync tag "info": the 5th UI row of Survive and Round.
        public GuildleveInfoWork work = new GuildleveInfoWork();

        public bool isEnded = false;
        public uint completionTime = 0;

        // Waiting: targets and map markers are out, the leve is not activated yet (no timer)
        private enum LeveState { Created, Starting, Waiting, Running, Succeeded, Failed, Closed }
        private LeveState state = LeveState.Created;
        private GuildlevePlan plan;
        private Random rng;
        private DateTime startTick, endTick, nextSpawnTick, nextSurviveWave, activateBy;
        private DateTime? completeAt;   // objectives done; 50023 waits COMPLETE_DELAY_SECONDS
        private uint doneSeconds;
        private int enemyLevel;
        private Vector3 origin;
        private readonly List<Vector3> anchors = new List<Vector3>();
        private readonly List<uint> participants = new List<uint>();
        private readonly Dictionary<uint, Player> participantRefs = new Dictionary<uint, Player>();
        private readonly HashSet<uint> leashWarned = new HashSet<uint>();
        private readonly HashSet<int> timeWarnings = new HashSet<int>();
        private readonly List<LeveGroup> groups = new List<LeveGroup>();
        private readonly int[] toSpawn = new int[4];
        private Vector3 lastObjectivePos;
        private readonly Dictionary<uint, LeveReward> unclaimed = new Dictionary<uint, LeveReward>();
        private Npc warpNode;
        private readonly Dictionary<BattleNpc, DateTime> deathTimes = new Dictionary<BattleNpc, DateTime>();

        private int stage;                     // chase stage / round stop index
        private int hitsDone, decoyMisses;     // detect / hunt
        private int orbMisses;                 // orb drop variant: empty carrier groups in a row
        private readonly int[] gatherMisses = new int[4];
        private Npc bonusBox;
        private readonly List<Npc> searchPoints = new List<Npc>();
        private readonly HashSet<uint> hitPoints = new HashSet<uint>();
        private readonly int[] pagesDone = new int[4];
        private int booksDestroyed;
        private bool surviveStarted, surviveDone;
        private Vector3 defensePoint;

        private class LeveGroup
        {
            public List<BattleNpc> mobs = new List<BattleNpc>();
            public string role;          // target, decoy, hit, carrier, summon, miss, wave, horde, boss
            public int creditSlot = -1;  // slot all members credit (-1: by pool match)
            public int anchor = -1;
            public int stage = -1;
            public int pageSlot = -1;
            public bool fleeArmed, fled, rolled, addSpawned;
            public bool engaged;   // 30118 sent; the whole group fights
            public Vector3 center;   // its map marker
            public HashSet<BattleNpc> killed = new HashSet<BattleNpc>();
            // Dead from OnLeveMobDeath on: that hook runs inside BattleNpc.Die before InternalDie, while
            // IsAlive() is still true.
            public bool Living(BattleNpc m) => !killed.Contains(m) && m.IsAlive() && m.CurrentArea != null;
            public bool Alive => mobs.Any(Living);
        }

        // A completed leve's payout for one participant (the eventGLReward arguments).
        public class LeveReward
        {
            public uint glId, clearSeconds, missionBonus, difficultyBonus, faction, factionBonus, factionCredit, gil, item2, qty2;
            public byte stars;
        }

        public GuildleveDirector(uint id, Area zone, string directorPath, uint guildleveId, byte selectedDifficulty, Player guildleveOwner, params object[] args)
            : base(id, zone, directorPath, true, args)
        {
            this.guildleveId = guildleveId;
            // eventGLStart returns the star count 1-5
            this.selectedDifficulty = (byte)Math.Max(1, Math.Min(5, (int)selectedDifficulty));
            this.guildleveData = Server.GetGuildleveGamedata(guildleveId);
            this.guildleveOwner = guildleveOwner;

            for (int i = 0; i < 4; i++)
            {
                guildleveWork.aimNum[i] = guildleveData.aimNum[i];
                guildleveWork.aimNumNow[i] = 0;
                guildleveWork.uiState[i] = (sbyte)(guildleveData.aimNum[i] != 0 ? 1 : 0);
            }
        }

        #region Script-facing info
        // Client director class for this leve, by objective; border 20004 (urgent) picks the Special
        // class where the client has one. Names are the client's _defineClass names. Cosmetic only.
        public string GetClientClassPath()
        {
            string type;
            switch (guildleveData.objective)
            {
                case 10021: case 12010: type = "Gather"; break;
                case 10031: case 12006: case 12008: case 12009: type = "Chase"; break;
                case 10041: case 10042: case 10043: type = "Detect"; break;
                case 10051: type = "Orb"; break;
                case 10061: type = "Survive"; break;
                case 10071: type = "Hunt"; break;
                case 10081: type = "Round"; break;
                default: type = "Sweep"; break;
            }
            if (IsTutorial())
                return "/Director/Guildleve/PrivateGLBattleTutorial";
            bool urgent = guildleveData.borderId == 20004;
            if (urgent && (type == "Sweep" || type == "Chase" || type == "Gather"))
                return "/Director/Guildleve/PrivateGLBattle" + type + "Special";
            return "/Director/Guildleve/PrivateGLBattle" + type + "Normal";
        }

        public bool IsTutorial()
        {
            return guildleveId == 10801 || guildleveId == 11601 || guildleveId == 12401;
        }

        public int GetEnemyLevel()
        {
            return enemyLevel;
        }

        public bool IsParticipant(Actor actor)
        {
            if (actor is Pet || actor is Ally)
                return true;
            return actor != null && participants.Contains(actor.Id);
        }

        public bool IsRunning()
        {
            return state == LeveState.Running;
        }
        #endregion

        #region Start
        public void LoadGuildleve()
        {
            plan = GuildlevePlan.Get(guildleveId);
            rng = new Random(unchecked((int)(guildleveId * 2654435761u ^ (guildleveOwner?.Id ?? 0))));
            startTick = Program.Tick.AddSeconds(START_DELAY_SECONDS);
            state = LeveState.Starting;
        }

        // After the start delay: party, anchors and the first targets go out, but the leve is not
        // activated yet (Activate).
        public void StartGuildleve()
        {
            if (state != LeveState.Starting && state != LeveState.Created)
                return;

            if (plan == null)
            {
                foreach (Player p in GetPlayerMembers().OfType<Player>())
                    p.SendMessage(0x20, "", "This levequest cannot be undertaken yet (no encounter data). It stays in your journal.");
                Program.Log.Warn("Guildleve {0} started without a plan (server_guildleve_scripts row missing).", guildleveId);
                state = LeveState.Closed;
                EndDirector();
                return;
            }

            enemyLevel = guildleveData.level + ENEMY_LEVEL_PER_STAR * (selectedDifficulty - 1);
            origin = FindAetherytePosition();
            BuildAnchors();
            LinkParty();

            foreach (Player player in GetPlayerMembers().OfType<Player>())
            {
                // Journal: retained -> active (done 0, checked 1)
                if (player.HasGuildleve(guildleveId))
                    player.SetGuildleveActive(guildleveId);
            }

            state = LeveState.Waiting;
            activateBy = Program.Tick.AddSeconds(ACTIVATE_DELAY_SECONDS);
            foreach (Player player in Participants())
                player.StartLeveMusic();
            BeginPlan();
            MaybeSpawnBonusBox();
            Program.Log.Info("Guildleve {0} ({1}, {2}) placed: {3} star(s), enemy level {4}, {5} participant(s), {6} anchors; waiting for activation.",
                guildleveId, plan.kind, plan.source, selectedDifficulty, enemyLevel, participants.Count, anchors.Count);
        }

        // "Activated!", the time left and the timer start now. The markers are already out from Begin.
        private void Activate()
        {
            if (state != LeveState.Waiting)
                return;

            foreach (Player player in Participants())
            {
                player.SendGameMessage(WorldMaster(), T_ACTIVATED, 0x20, (object)(int)guildleveId, (object)(int)selectedDifficulty);
                player.SendDataPacket("attention", WorldMaster(), "", T_ACTIVATED, (object)(int)guildleveId, (object)(int)selectedDifficulty);
                player.SendGameMessage(WorldMaster(), T_TIME_LEFT, 0x20, (object)(int)guildleveData.timeLimit);
                if (IsTutorial())
                {
                    player.SendGameMessage(WorldMaster(), 50101, 0x20);
                    player.SendGameMessage(WorldMaster(), 50107, 0x20, (object)(int)guildleveData.aimNum[0]);
                    player.SendGameMessage(WorldMaster(), 50108, 0x20);
                }
            }

            guildleveWork.startTime = Utils.UnixTimeStampUTC();
            endTick = Program.Tick.AddMinutes(guildleveData.timeLimit);
            state = LeveState.Running;

            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("guildleveWork/start", this);
            propertyBuilder.AddProperty("guildleveWork.startTime");
            SendPacketsToPlayers(propertyBuilder.Done());
            SyncAllInfo();
            UpdateObjectiveMarkers();
            Program.Log.Info("Guildleve {0} activated.", guildleveId);
        }

        // The delay ran out, a target was engaged, or a participant walked into the leve area.
        private bool ShouldActivate(DateTime tick)
        {
            if (tick >= activateBy || groups.Any(g => g.engaged))
                return true;
            var points = ObjectivePoints(int.MaxValue);
            foreach (Player p in Participants())
            {
                if (Utils.XZDistance(p.positionX, p.positionZ, origin.X, origin.Z) >= ACTIVATE_DISTANCE)
                    return true;
                if (points.Any(o => Utils.XZDistance(p.positionX, p.positionZ, o.X, o.Z) <= ACTIVATE_OBJECTIVE_RADIUS))
                    return true;
            }
            return false;
        }

        private static Actor WorldMaster()
        {
            return Server.GetWorldManager().GetActor();
        }

        // The start aetheryte in this zone, else the owner's position.
        private Vector3 FindAetherytePosition()
        {
            foreach (Actor a in CurrentArea.GetAllActors())
            {
                if (a is Npc npc && npc.GetActorClassId() == guildleveData.aetheryte)
                    return new Vector3(npc.positionX, npc.positionY, npc.positionZ);
            }
            if (guildleveOwner != null)
                return new Vector3(guildleveOwner.positionX, guildleveOwner.positionY, guildleveOwner.positionZ);
            return new Vector3();
        }

        // Spawn anchors: a layout seeded by leve id and character id, 80-300 from the aetheryte, at least
        // 40 apart, on ground walkable from the aetheryte.
        private void BuildAnchors()
        {
            var navMesh = NavmeshUtils.GetNavMesh(CurrentArea);
            for (int attempt = 0; attempt < 400 && anchors.Count < ANCHOR_COUNT; attempt++)
            {
                double ang = rng.NextDouble() * Math.PI * 2;
                double r = ANCHOR_MIN + rng.NextDouble() * (ANCHOR_MAX - ANCHOR_MIN);
                float x = origin.X + (float)(Math.Cos(ang) * r), z = origin.Z + (float)(Math.Sin(ang) * r);
                Vector3 p = new Vector3(x, origin.Y, z);
                if (navMesh != null)
                {
                    if (!navMesh.TrySnapToGround(x, origin.Y, z, out Vector3 snapped))
                        continue;
                    if (Utils.XZDistance(snapped.X, snapped.Z, x, z) > 15f || Math.Abs(snapped.Y - origin.Y) > 60f)
                        continue;
                    if (!navMesh.IsReachable(origin, snapped))
                        continue;
                    p = snapped;
                }
                if (anchors.Any(a => Utils.XZDistance(a.X, a.Z, p.X, p.Z) < ANCHOR_SPACING))
                    continue;
                anchors.Add(p);
            }
            anchors.Sort((a, b) => Utils.XZDistance(a.X, a.Z, origin.X, origin.Z).CompareTo(Utils.XZDistance(b.X, b.Z, origin.X, origin.Z)));
            if (anchors.Count == 0)
                anchors.Add(new Vector3(origin.X + ANCHOR_MIN, origin.Y, origin.Z));
        }

        // Party members near the owner at initiation take part. Members holding the leve get its rewards;
        // the others are leve sharing (50037) and get kill EXP.
        private void LinkParty()
        {
            if (guildleveOwner != null && !participants.Contains(guildleveOwner.Id))
            {
                participants.Add(guildleveOwner.Id);
                participantRefs[guildleveOwner.Id] = guildleveOwner;
            }
            if (guildleveOwner?.currentParty is Party party)
            {
                foreach (uint memberId in party.members)
                {
                    if (memberId == guildleveOwner.Id || participants.Contains(memberId))
                        continue;
                    Player member = CurrentArea.FindActorInArea(memberId) as Player;
                    if (member == null || member.GetGuildleveDirector() != null)
                        continue;
                    if (Utils.Distance(member.positionX, member.positionY, member.positionZ, guildleveOwner.positionX, guildleveOwner.positionY, guildleveOwner.positionZ) > 50f)
                        continue;
                    participants.Add(member.Id);
                    participantRefs[member.Id] = member;
                    member.AddDirector(this);
                    member.QueuePackets(GetSpawnPackets());
                    member.QueuePackets(GetInitPackets());
                    ushort text = member.HasGuildleve(guildleveId) ? (ushort)50038 : (ushort)50037;
                    foreach (Player p in GetPlayerMembers().OfType<Player>())
                        p.SendGameMessage(WorldMaster(), text, 0x20, (object)member, (object)(int)guildleveId);
                }
            }
            foreach (Player p in GetPlayerMembers().OfType<Player>())
            {
                if (!participants.Contains(p.Id))
                    participants.Add(p.Id);
                participantRefs[p.Id] = p;
            }
        }
        #endregion

        #region Plan
        private void BeginPlan()
        {
            for (int i = 0; i < 4; i++)
                toSpawn[i] = guildleveData.aimNum[i] > 0 ? guildleveData.aimNum[i] : 0;

            switch (plan.kind)
            {
                case "orb":
                    if (plan.points > 0)
                        SpawnSearchPoints(plan.points, plan.hits);
                    break;
                case "hunt":
                    SpawnSearchPoints(plan.points > 0 ? plan.points : plan.hits + 2, plan.hits);
                    break;
                case "round":
                    work.roundNumber = 0;
                    work.roundNumberMax = (sbyte)plan.stops.Count;
                    SyncInfoWork("work.roundNumber", "work.roundNumberMax");
                    break;
                case "survive":
                    defensePoint = anchors[0];
                    work.surviveTime = (short)plan.defense;
                    work.surviveStartTime = 0;
                    work.surviveStop = true;   // frozen at the full time until the defense begins
                    SyncInfoWork("work.surviveTime", "work.surviveStartTime", "work.surviveStop");
                    break;
            }
            nextSpawnTick = Program.Tick;
            UpdateObjectiveMarkers();
        }

        private GuildlevePlan.Slot SlotSpec(int slot)
        {
            return plan.slots.FirstOrDefault(s => s.slot == slot);
        }

        // Default waves: groups of 2 when the slot needs 4 or more, else 1; up to 3 groups alive. Parsed
        // wave sizes override.
        private int GroupSize(int slot, int fallbackSlot = -1)
        {
            var spec = SlotSpec(slot);
            int? size = spec?.size;
            if (size == null && fallbackSlot >= 0)
                size = SlotSpec(fallbackSlot)?.size;
            return Math.Max(1, size ?? (guildleveData.aimNum[slot] >= 4 ? 2 : 1));
        }

        private int Concurrency(int slot)
        {
            var spec = SlotSpec(slot);
            if (spec?.concurrent != null)
                return Math.Max(1, Math.Min(5, spec.concurrent.Value));
            return Math.Min(3, (int)Math.Ceiling(guildleveData.aimNum[slot] / (double)GroupSize(slot)));
        }

        private void RunPlan(DateTime tick)
        {
            if (tick < nextSpawnTick)
                return;
            nextSpawnTick = tick.AddSeconds(1);
            RunPlanStep(tick);
            UpdateObjectiveMarkers();   // only sends when a marker changed
        }

        private void RunPlanStep(DateTime tick)
        {

            switch (plan.kind)
            {
                case "sweep":
                case "tutorial":
                    foreach (var s in plan.slots)
                        FillSlot(s.slot, Concurrency(s.slot), GroupSize(s.slot), "target");
                    break;
                case "chase":
                    RunChase();
                    break;
                case "detect":
                    RunDetect();
                    break;
                case "gather":
                    RunGather();
                    break;
                case "orb":
                    RunOrb();
                    break;
                case "hunt":
                    if (searchPoints.Count(p => p.CurrentArea != null) == 0 && !AllSlotsDone() && !groups.Any(g => g.Alive))
                        SpawnSearchPoints(plan.hits + 2, Math.Max(1, plan.hits - hitsDone));
                    break;
                case "round":
                    RunRound();
                    break;
                case "survive":
                    RunSurvive(tick);
                    break;
            }
        }

        // Keeps up to `concurrent` groups of a target slot alive until its total is spawned.
        private void FillSlot(int slot, int concurrent, int size, string role, int stageTag = -1)
        {
            var spec = SlotSpec(slot);
            if (spec == null || spec.pool == 0)
                return;
            while (toSpawn[slot] > 0 && groups.Count(g => g.creditSlot == slot && g.role == role && g.Alive) < concurrent)
            {
                int n = Math.Min(size, toSpawn[slot]);
                toSpawn[slot] -= n;
                var g = SpawnGroup(Enumerable.Repeat(spec.pool, n).ToList(), role, slot, FreeAnchor());
                if (g == null)
                    break;
                g.stage = stageTag;
                if (stageTag >= 0 && toSpawn[slot] == 0 && n >= 2)
                    g.fleeArmed = true;
            }
        }

        // Chase: stages are the target slots in order. In every stage but the last, one member of the last
        // group flees once one of them is below half HP or dead. A fled monster counts for nothing and the
        // next spawn appears at a new anchor, where it ran.
        private void RunChase()
        {
            var stages = plan.slots.Select(s => s.slot).ToList();
            while (stage < stages.Count && IsSlotDone(stages[stage]))
            {
                stage++;
                if (stage < stages.Count)
                    Broadcast(T_APPEARS);
            }
            if (stage >= stages.Count)
                return;
            int slot = stages[stage];
            bool finalStage = stage == stages.Count - 1;
            FillSlot(slot, SlotSpec(slot)?.concurrent ?? 1, GroupSize(slot, stages[0]), "target", finalStage ? -1 : stage);

            foreach (var g in groups.Where(x => x.fleeArmed && !x.fled && x.Alive).ToList())
            {
                var living = g.mobs.Where(m => m.IsAlive()).ToList();
                bool hurt = g.mobs.Any(m => !m.IsAlive() || m.GetHP() * 100 < m.GetMaxHP() * FLEE_HP_PERCENT);
                if (!hurt || living.Count < 2)
                    continue;
                BattleNpc runner = living.OrderByDescending(m => m.GetHP()).First();
                g.fled = true;
                g.mobs.Remove(runner);
                Broadcast(T_FLEE);
                DespawnMob(runner);
                toSpawn[slot] += 1;
                lastObjectivePos = new Vector3(runner.positionX, runner.positionY, runner.positionZ);
                foreach (Player p in Participants())
                    p.SendGameMessage(WorldMaster(), T_LOST_SIGHT, 0x20, (object)runner.LocalizedDisplayName);
            }
        }

        // Detect: decoy groups; engaging one rolls a hit, certain on the 3rd miss. A hit turns the group
        // into its true form (50049) on the spot. Only true-form kills count.
        private void RunDetect()
        {
            if (hitsDone < plan.hits)
            {
                while (groups.Count(g => g.role == "decoy" && g.Alive && !g.rolled) < 3)
                {
                    if (SpawnGroup(plan.decoy, "decoy", -2, FreeAnchor()) == null)
                        break;
                }
            }
            foreach (var g in groups.Where(x => x.role == "decoy" && !x.rolled && x.Alive).ToList())
            {
                if (!g.mobs.Any(m => m.aiContainer.IsEngaged() || m.hateContainer.GetHateList().Count > 0 || !m.IsAlive()))
                    continue;
                g.rolled = true;
                bool hit = decoyMisses >= 2 || rng.Next(3) == 0;
                if (!hit || hitsDone >= plan.hits)
                {
                    decoyMisses++;
                    continue;
                }
                decoyMisses = 0;
                hitsDone++;
                BattleNpc first = g.mobs.FirstOrDefault(m => m.IsAlive()) ?? g.mobs[0];
                var pos = new Vector3(first.positionX, first.positionY, first.positionZ);
                Character aggro = first.hateContainer.GetMostHatedTarget();
                foreach (var m in g.mobs.ToList())
                    if (m.IsAlive())
                        DespawnMob(m);
                g.mobs.Clear();
                Broadcast(T_TRUE_FORM);
                var hitGroup = SpawnGroupAt(plan.hit, "hit", -1, pos);
                if (hitGroup != null && aggro != null)
                    foreach (var m in hitGroup.mobs)
                        m.hateContainer.AddBaseHate(aggro);
            }
        }

        // Gather: carrier groups keep spawning; carrier kills give items until the slot count is held.
        // The items are removed at the end.
        private void RunGather()
        {
            foreach (var c in plan.carriers)
            {
                if (IsSlotDone(c.slot) || c.groups.Count == 0)
                    continue;
                while (groups.Count(g => g.role == "carrier" && g.creditSlot == c.slot && g.Alive) < Math.Min(3, c.groups.Count + 1))
                {
                    var comp = c.groups[rng.Next(c.groups.Count)];
                    if (SpawnGroup(comp, "carrier", c.slot, FreeAnchor()) == null)
                        break;
                }
            }
        }

        // Orb (Necrologos): search points; hits give pages, misses spawn the miss group; a full page slot
        // summons that slot's creatures from the book. The drop variant uses carriers.
        private void RunOrb()
        {
            if (plan.points == 0 && plan.carrier.Count > 0)
            {
                bool pagesLeft = plan.pages.Any(pg => pagesDone[pg.slot] < guildleveData.aimNum[pg.slot]);
                if (pagesLeft)
                    while (groups.Count(g => g.role == "carrier" && g.Alive) < 3)
                        if (SpawnGroup(plan.carrier, "carrier", -2, FreeAnchor()) == null)
                            break;
            }
            else if (searchPoints.Count(p => p.CurrentArea != null) == 0 && plan.pages.Any(pg => pagesDone[pg.slot] < guildleveData.aimNum[pg.slot]))
            {
                int missing = plan.pages.Sum(pg => guildleveData.aimNum[pg.slot] - pagesDone[pg.slot]);
                SpawnSearchPoints(missing + 2, missing);
            }
            CheckOrbDone();
        }

        // Round: an ordered patrol. Reaching stop i (8 units) says 50066 and spawns its wave; the last
        // stop's wave brings its add once engaged.
        private void RunRound()
        {
            if (state != LeveState.Running)
                return;   // stops count from activation on
            if (stage < plan.stops.Count)
            {
                Vector3 stop = anchors[stage % anchors.Count];
                foreach (Player p in Participants())
                {
                    if (Utils.XZDistance(p.positionX, p.positionZ, stop.X, stop.Z) > ROUND_REACH)
                        continue;
                    var st = plan.stops[stage];
                    stage++;
                    work.roundNumber = (sbyte)stage;
                    SyncInfoWork("work.roundNumber");
                    Broadcast(T_PATROL, stage, plan.stops.Count);
                    var g = SpawnGroupAt(st.wave, stage == plan.stops.Count ? "final" : "wave", -1, stop);
                    if (g != null)
                        foreach (var m in g.mobs)
                            m.hateContainer.AddBaseHate(p);
                    lastObjectivePos = stop;
                    UpdateObjectiveMarkers();
                    break;
                }
            }
            // adds for the final stop, and a refill if targets are still short once it is clear
            foreach (var g in groups.Where(x => x.role == "final" && !x.addSpawned).ToList())
            {
                if (!g.mobs.Any(m => !m.IsAlive() || m.aiContainer.IsEngaged()))
                    continue;
                g.addSpawned = true;
                var st = plan.stops[plan.stops.Count - 1];
                if (st.add.Count > 0)
                {
                    BattleNpc any = g.mobs[0];
                    SpawnGroupAt(st.add, "add", -1, new Vector3(any.positionX, any.positionY, any.positionZ));
                    Broadcast(T_UNEXPECTED);
                }
            }
            if (stage >= plan.stops.Count && !AllSlotsDone() && !groups.Any(g => g.Alive))
            {
                var st = plan.stops[plan.stops.Count - 1];
                var refill = st.add.Count > 0 ? st.add : st.wave;
                SpawnGroup(refill, "add", -1, FreeAnchor());
            }
        }

        // Survive: the defense clock (work.surviveTime/StartTime/Stop) starts when a participant reaches
        // the defense point; hordes every 45 s at 30-60 units; at 0:00 the boss.
        private void RunSurvive(DateTime tick)
        {
            if (state != LeveState.Running)
                return;   // the defense clock is relative to guildleveWork.startTime
            if (!surviveStarted)
            {
                if (Participants().Any(p => Utils.XZDistance(p.positionX, p.positionZ, defensePoint.X, defensePoint.Z) <= SURVIVE_REACH))
                {
                    surviveStarted = true;
                    work.surviveStartTime = (short)(Utils.UnixTimeStampUTC() - guildleveWork.startTime);
                    work.surviveStop = false;
                    SyncInfoWork("work.surviveTime", "work.surviveStartTime", "work.surviveStop");
                    Broadcast(T_ARRIVED);
                    nextSurviveWave = tick;
                }
                return;
            }
            if (!surviveDone)
            {
                long elapsed = Utils.UnixTimeStampUTC() - guildleveWork.startTime - work.surviveStartTime;
                if (elapsed >= plan.defense)
                {
                    surviveDone = true;
                    work.surviveTime = 0;   // the row shows cleared at 0
                    work.surviveStop = true;
                    SyncInfoWork("work.surviveTime", "work.surviveStop");
                    foreach (var g in groups.Where(x => x.role == "horde"))
                        foreach (var m in g.mobs.Where(m => m.IsAlive()).ToList())
                            DespawnMob(m);
                    if (plan.boss.Count > 0)
                    {
                        var b = SpawnGroupAt(plan.boss, "boss", -1, defensePoint);
                        Broadcast(T_APPEARS);
                        AggroNearest(b);
                    }
                    CheckSuccess();
                    return;
                }
                if (tick >= nextSurviveWave && plan.horde.Count > 0)
                {
                    nextSurviveWave = tick.AddSeconds(SURVIVE_WAVE_SECONDS);
                    var h = plan.horde[rng.Next(plan.horde.Count)];
                    int n = rng.Next(Math.Max(1, h.min), h.pools.Count + 1);
                    double ang = rng.NextDouble() * Math.PI * 2;
                    float r = 30f + (float)rng.NextDouble() * 30f;
                    var at = SnapOrRaw(defensePoint.X + (float)Math.Cos(ang) * r, defensePoint.Y, defensePoint.Z + (float)Math.Sin(ang) * r);
                    var g = SpawnGroupAt(h.pools.Take(n).ToList(), "horde", -2, at);
                    Broadcast(T_MONSTER_APPEARS);
                    AggroNearest(g);
                }
            }
        }

        private void AggroNearest(LeveGroup g)
        {
            if (g == null)
                return;
            foreach (var m in g.mobs)
            {
                Player near = Participants().OrderBy(p => Utils.XZDistance(p.positionX, p.positionZ, m.positionX, m.positionZ)).FirstOrDefault();
                if (near != null)
                    m.hateContainer.AddBaseHate(near);
            }
        }
        #endregion

        #region Search points (Orb / Hunt)
        private void SpawnSearchPoints(int count, int hits)
        {
            var free = Enumerable.Range(0, anchors.Count).OrderBy(_ => rng.Next()).Take(count).ToList();
            var newPoints = new List<Npc>();
            foreach (int a in free)
            {
                Vector3 p = anchors[a];
                Npc npc = CurrentArea.SpawnLeveObject(GUILDLEVE_SEARCH_POINT, string.Format("glsearch_{0}_{1}", Id, searchPoints.Count + newPoints.Count), p.X, p.Y, p.Z);
                if (npc == null)
                    break;
                newPoints.Add(npc);
            }
            foreach (Npc npc in newPoints.OrderBy(_ => rng.Next()).Take(hits))
                hitPoints.Add(npc.Id);
            searchPoints.AddRange(newPoints);
            UpdateObjectiveMarkers();
        }

        // A participant searched a GuildleveSearchPoint (its talk event). The client class has no UI.
        public void OnSearchPoint(Player player, Npc point)
        {
            if (state == LeveState.Waiting && IsParticipant(player))
                Activate();
            if (state != LeveState.Running || completeAt != null || !searchPoints.Contains(point) || point.CurrentArea == null || !IsParticipant(player))
                return;
            var pos = new Vector3(point.positionX, point.positionY, point.positionZ);
            bool hit = hitPoints.Remove(point.Id);
            point.Despawn();
            lastObjectivePos = pos;

            if (plan.kind == "orb")
            {
                if (hit)
                {
                    var page = plan.pages.FirstOrDefault(pg => pagesDone[pg.slot] < guildleveData.aimNum[pg.slot]);
                    if (page != null)
                        GivePage(player, page, pos);
                }
                else
                    SpawnMiss(pos, player);
            }
            else
            {
                if (hit && hitsDone < plan.hits)
                {
                    hitsDone++;
                    var g = SpawnGroupAt(plan.hit, "hit", -1, pos);
                    Broadcast(T_MONSTER_APPEARS);
                    if (g != null)
                        foreach (var m in g.mobs)
                            m.hateContainer.AddBaseHate(player);
                }
                else
                    SpawnMiss(pos, player);
            }
            UpdateObjectiveMarkers();
        }

        private void SpawnMiss(Vector3 pos, Player player)
        {
            if (plan.miss.Count == 0)
            {
                player.SendGameMessage(WorldMaster(), T_NOTHING, 0x20);
                return;
            }
            var g = SpawnGroupAt(plan.miss, "miss", -2, pos);
            Broadcast(T_UNEXPECTED);
            if (g != null)
                foreach (var m in g.mobs)
                    m.hateContainer.AddBaseHate(player);
        }

        private void GivePage(Player player, GuildlevePlan.Page page, Vector3 pos)
        {
            pagesDone[page.slot]++;
            GiveLeveItem(player, page.item);
            SetAimNow(page.slot, pagesDone[page.slot]);
            if (pagesDone[page.slot] >= guildleveData.aimNum[page.slot] && page.summon.Count > 0)
            {
                // the gathered pages summon the slot's creatures from the book (50046)
                foreach (Player p in Participants())
                    p.SendGameMessage(WorldMaster(), T_SUMMONED, 0x20, (object)(int)ITEM_NECROLOGOS);
                var g = SpawnGroupAt(page.summon, "summon", -2, pos);
                if (g != null)
                {
                    g.pageSlot = page.slot;
                    foreach (var m in g.mobs)
                        m.hateContainer.AddBaseHate(player);
                }
                // a slot is "cleared" only once its summons are destroyed
                guildleveWork.uiState[page.slot] = 1;
            }
        }

        private void CheckOrbDone()
        {
            foreach (var g in groups.Where(x => x.role == "summon" && x.pageSlot >= 0 && !x.rolled).ToList())
            {
                if (g.Alive)
                    continue;
                g.rolled = true;
                booksDestroyed++;
                Broadcast(T_DESTROY_BOOK, booksDestroyed, plan.pages.Count);
                UpdateUiState(g.pageSlot, 2);
            }
            CheckSuccess();
        }
        #endregion

        #region Bonus treasure box
        // Chance per leve of a box on a free anchor. The first participant to open it gets gil of about
        // 12.5 x leve level (+-10%) and 2 potions of the leve's tier (hi-potion from Lv30), then it goes.
        public const uint ITEM_POTION = 3020001, ITEM_HI_POTION = 3020002;

        private void MaybeSpawnBonusBox()
        {
            if (rng.Next(100) >= BONUS_BOX_PERCENT || anchors.Count == 0)
                return;
            Vector3 at = anchors[rng.Next(anchors.Count)];
            Vector3 p = SnapOrRaw(at.X + 6f, at.Y, at.Z + 6f);
            bonusBox = CurrentArea.SpawnLeveObject(GUILDLEVE_BONUS_BOX, string.Format("glbox_{0}", Id), p.X, p.Y, p.Z);
            if (bonusBox != null)
                Program.Log.Info("Guildleve {0}: bonus treasure box at ({1:0.0}, {2:0.0}, {3:0.0}).", guildleveId, p.X, p.Y, p.Z);
        }

        // A participant opened the bonus box (its talk event). The client class has no UI: talk, server
        // messages, EndEvent.
        public void OnBonusBox(Player player, Npc box)
        {
            if (box != bonusBox || box.CurrentArea == null || !IsParticipant(player) || state == LeveState.Closed)
                return;
            bonusBox = null;
            box.Despawn();
            int level = Math.Max(1, (int)guildleveData.level);
            int gil = (int)Math.Round(level * 12.5 * (0.9 + 0.2 * rng.NextDouble()));
            BattleNpc.GiveLoot(player, new DropResult { itemId = ITEM_GIL, quantity = gil, quality = 1 });
            BattleNpc.GiveLoot(player, new DropResult { itemId = level >= 30 ? ITEM_HI_POTION : ITEM_POTION, quantity = 2, quality = 1 });
        }
        #endregion

        #region Spawning
        private int FreeAnchor()
        {
            var busy = new HashSet<int>(groups.Where(g => g.Alive).Select(g => g.anchor));
            var free = Enumerable.Range(0, anchors.Count).Where(i => !busy.Contains(i)).ToList();
            if (free.Count == 0)
                return rng.Next(anchors.Count);
            // nearest free anchors first, a little shuffled
            return free.Take(3).OrderBy(_ => rng.Next()).First();
        }

        private Vector3 SnapOrRaw(float x, float y, float z)
        {
            var navMesh = NavmeshUtils.GetNavMesh(CurrentArea);
            if (navMesh != null && navMesh.TrySnapToGround(x, y, z, out Vector3 s) && Utils.XZDistance(s.X, s.Z, x, z) < 10f)
                return s;
            return new Vector3(x, y, z);
        }

        private LeveGroup SpawnGroup(List<uint> pools, string role, int creditSlot, int anchor)
        {
            var g = SpawnGroupAt(pools, role, creditSlot, anchors[Math.Max(0, anchor) % anchors.Count]);
            if (g != null)
                g.anchor = anchor;
            return g;
        }

        // creditSlot: >= 0 every member credits that slot; -1 credit by pool match; -2 none.
        private LeveGroup SpawnGroupAt(List<uint> pools, string role, int creditSlot, Vector3 at)
        {
            if (pools == null || pools.Count == 0)
                return null;
            var g = new LeveGroup { role = role, creditSlot = creditSlot, center = at };
            foreach (uint pool in pools)
            {
                double ang = rng.NextDouble() * Math.PI * 2;
                float r = 3f + (float)rng.NextDouble() * (GROUP_JITTER - 2f);
                Vector3 p = SnapOrRaw(at.X + (float)Math.Cos(ang) * r, at.Y, at.Z + (float)Math.Sin(ang) * r);
                BattleNpc mob = CurrentArea.SpawnLeveBattleNpc(pool, enemyLevel, p.X, p.Y, p.Z, this);
                if (mob != null)
                    g.mobs.Add(mob);
            }
            if (g.mobs.Count == 0)
                return null;
            groups.Add(g);
            UpdateObjectiveMarkers();
            return g;
        }

        private int CreditSlotFor(LeveGroup g, BattleNpc mob)
        {
            if (g.creditSlot >= 0)
                return g.creditSlot;
            if (g.creditSlot == -2)
                return -1;
            foreach (var s in plan.slots)
                if (s.pool == mob.poolId && !IsSlotDone(s.slot))
                    return s.slot;
            return -1;
        }
        #endregion

        #region Kill credit
        // BattleNpc.Die hook for leve monsters.
        public void OnLeveMobDeath(BattleNpc mob, Character killer)
        {
            deathTimes[mob] = Program.Tick;
            RemoveTargetMember(mob);
            if (state == LeveState.Waiting)
                Activate();
            if (state != LeveState.Running)
                return;
            LeveGroup g = groups.FirstOrDefault(x => x.mobs.Contains(mob));
            if (g == null)
                return;
            g.killed.Add(mob);
            lastObjectivePos = new Vector3(mob.positionX, mob.positionY, mob.positionZ);

            if (g.role == "carrier")
            {
                Player taker = (killer as Player) ?? Participants().FirstOrDefault();
                if (plan.kind == "gather" && g.creditSlot >= 0 && !IsSlotDone(g.creditSlot) && taker != null)
                {
                    int slot = g.creditSlot;
                    if (gatherMisses[slot] >= GATHER_ITEM_PITY || rng.Next(100) < GATHER_ITEM_PERCENT)
                    {
                        gatherMisses[slot] = 0;
                        var c = plan.carriers.First(x => x.slot == slot);
                        GiveLeveItem(taker, c.item);
                        SetAimNow(slot, guildleveWork.aimNumNow[slot] + 1);
                    }
                    else
                        gatherMisses[slot]++;
                }
                else if (plan.kind == "orb" && taker != null && !g.Alive)
                {
                    // the page comes with the last kill of a group, and not every group has one
                    var page = plan.pages.FirstOrDefault(pg => pagesDone[pg.slot] < guildleveData.aimNum[pg.slot]);
                    if (page != null)
                    {
                        if (orbMisses >= ORB_PAGE_PITY || rng.Next(3) < ORB_PAGE_ODDS_IN_3)
                        {
                            orbMisses = 0;
                            GivePage(taker, page, lastObjectivePos);
                        }
                        else
                            orbMisses++;
                    }
                }
            }
            else
            {
                int slot = CreditSlotFor(g, mob);
                if (slot >= 0 && !IsSlotDone(slot))
                {
                    int now = guildleveWork.aimNumNow[slot] + 1;
                    SetAimNow(slot, now);
                    // 50041 "<name> is defeated. (n of m)"
                    foreach (Player p in Participants())
                        p.SendGameMessage(WorldMaster(), T_DEFEATED_NAMED, 0x20, (object)mob.LocalizedDisplayName, (object)now, (object)(int)guildleveData.aimNum[slot]);
                }
            }

            // 30119 "<target>'s group is defeated.", for groups of 2 or more
            if (g.engaged && g.mobs.Count >= 2 && !g.Alive)
                Broadcast(T_GROUP_DEFEATED, mob);

            if (plan.kind == "orb")
                CheckOrbDone();
            UpdateObjectiveMarkers();
            CheckSuccess();
        }

        // Engaging one enemy of a group claims the whole group: the first member with hate passes its
        // target to the rest, and groups of 2 or more tell participants 30118 "<target>'s group is
        // engaged."
        private void CheckGroupEngage()
        {
            foreach (var g in groups.Where(x => !x.engaged && x.Alive).ToList())
            {
                BattleNpc first = g.mobs.FirstOrDefault(m => g.Living(m) && (m.aiContainer.IsEngaged() || m.hateContainer.GetHateList().Count > 0));
                if (first == null)
                    continue;
                g.engaged = true;
                Character engager = first.hateContainer.GetMostHatedTarget();
                if (engager != null)
                    foreach (var m in g.mobs.Where(x => x != first && g.Living(x)))
                        m.hateContainer.AddBaseHate(engager);
                if (g.mobs.Count >= 2)
                    Broadcast(T_GROUP_ENGAGED, first);
            }
        }

        private bool IsSlotDone(int slot)
        {
            return guildleveData.aimNum[slot] <= 0 || guildleveWork.aimNumNow[slot] >= guildleveData.aimNum[slot];
        }

        private bool AllSlotsDone()
        {
            for (int i = 0; i < 4; i++)
                if (!IsSlotDone(i))
                    return false;
            return true;
        }

        private void SetAimNow(int slot, int value)
        {
            guildleveWork.aimNumNow[slot] = (sbyte)Math.Min(127, value);
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("guildleveWork/infoVariable", this);
            propertyBuilder.AddProperty(string.Format("guildleveWork.aimNumNow[{0}]", slot));
            bool orbWaiting = plan.kind == "orb" && plan.pages.Any(pg => pg.slot == slot && pg.summon.Count > 0);
            if (value >= guildleveData.aimNum[slot] && !orbWaiting && guildleveWork.uiState[slot] != 2)
            {
                guildleveWork.uiState[slot] = 2;   // cleared
                propertyBuilder.AddProperty(string.Format("guildleveWork.uiState[{0}]", slot));
            }
            SendPacketsToPlayers(propertyBuilder.Done());
        }

        private void CheckSuccess()
        {
            if (state != LeveState.Running)
                return;
            bool done = AllSlotsDone();
            if (plan.kind == "orb")
                done = done && booksDestroyed >= plan.pages.Count(pg => pg.summon.Count > 0);
            if (plan.kind == "survive")
                done = surviveDone && done;
            if (done && completeAt == null)
            {
                completeAt = Program.Tick.AddSeconds(COMPLETE_DELAY_SECONDS);
                doneSeconds = Utils.UnixTimeStampUTC() - guildleveWork.startTime;   // clear time = objectives done
            }
        }
        #endregion

        #region Tick
        public void Tick(DateTime tick)
        {
            switch (state)
            {
                case LeveState.Starting:
                    if (tick >= startTick)
                    {
                        // A throw here would retry every tick and resend the start messages; close instead.
                        try { StartGuildleve(); }
                        catch (Exception e)
                        {
                            Program.Log.Error(e, "Guildleve {0} failed to start; closing it.", guildleveId);
                            foreach (Player p in GetPlayerMembers().OfType<Player>())
                                p.SendMessage(0x20, "", "This levequest could not be started. It stays in your journal.");
                            state = LeveState.Closed;
                            EndDirector();
                        }
                    }
                    return;
                case LeveState.Waiting:
                    CheckParticipants();
                    if (state != LeveState.Waiting)
                        return;
                    CheckGroupEngage();
                    if (ShouldActivate(tick))
                        Activate();
                    RunPlan(tick);
                    PruneDead(tick);
                    return;
                case LeveState.Running:
                    CheckParticipants();
                    if (state != LeveState.Running)
                        return;
                    CheckTimer(tick);
                    if (state != LeveState.Running)
                        return;
                    if (completeAt != null)
                    {
                        // objectives done: 50023 after the delay, no new spawns meanwhile
                        if (tick >= completeAt.Value)
                            EndGuildleve(true);
                        PruneDead(tick);
                        return;
                    }
                    CheckGroupEngage();
                    RunPlan(tick);
                    PruneDead(tick);
                    return;
                case LeveState.Succeeded:
                case LeveState.Failed:
                    PruneDead(tick);
                    if (tick >= endTick)
                        CloseLeve();
                    return;
            }
        }

        // The leve's battle track plays from Begin until the leve ends for that participant (fanfare 81
        // on success, field music otherwise); fights and KO don't switch it. By guildleveData.location:
        // La Noscea 22, Shroud 14, Thanalan 26, Coerthas 16, the region's second battle track. Location
        // 0 uses the zone's battle track + 1.
        public ushort GetLeveMusic(Player p)
        {
            if ((state != LeveState.Waiting && state != LeveState.Running) || !participants.Contains(p.Id))
                return 0;
            switch (guildleveData.location)
            {
                case 1: return 22;
                case 2: return 14;
                case 3: return 26;
                case 4: return 16;
                default: return CurrentArea != null && CurrentArea.bgmBattle != 0 ? (ushort)(CurrentArea.bgmBattle + 1) : (ushort)0;
            }
        }

        private IEnumerable<Player> Participants()
        {
            foreach (Actor a in GetPlayerMembers())
                if (a is Player p && participants.Contains(p.Id) && p.playerSession != null)
                    yield return p;
        }

        // Zoning, logging out or leaving the leash fails that participant only; the leve fails when
        // nobody is left.
        private void CheckParticipants()
        {
            foreach (Player p in participantRefs.Values.Where(x => participants.Contains(x.Id)).ToList())
            {
                // zoning removes the director from the player (WorldManager.DoZoneChange), so a
                // participant who is no longer a member has left too
                bool gone = !GetPlayerMembers().Contains(p) || p.CurrentArea != CurrentArea || CurrentArea.FindActorInArea(p.Id) == null || p.playerSession == null;
                if (!gone)
                {
                    Vector3 c = plan.kind == "survive" && surviveStarted ? defensePoint : origin;
                    float warn = plan.kind == "survive" && surviveStarted ? SURVIVE_LEASH - 10f : LEASH_WARN;
                    float fail = plan.kind == "survive" && surviveStarted ? SURVIVE_LEASH : LEASH_FAIL;
                    float d = Utils.XZDistance(p.positionX, p.positionZ, c.X, c.Z);
                    if (d > fail)
                        gone = true;
                    else if (d > warn)
                    {
                        if (leashWarned.Add(p.Id))
                            p.SendGameMessage(WorldMaster(), T_LEASH_WARN, 0x20);
                    }
                    else
                        leashWarned.Remove(p.Id);
                }
                if (gone)
                    FailParticipant(p);
            }
            if ((state == LeveState.Running || state == LeveState.Waiting) && !Participants().Any())
                EndGuildleve(false);
        }

        private void FailParticipant(Player p)
        {
            participants.Remove(p.Id);
            if (p.HasGuildleve(guildleveId))
                p.SetGuildleveFailed(guildleveId);
            RemoveLeveItems(p);
            if (p.playerSession != null && p.CurrentArea == CurrentArea)
            {
                p.SendGameMessage(WorldMaster(), T_ABORTED, 0x20, (object)(int)guildleveId);
                p.RestoreFieldMusic();
            }
            if (GetPlayerMembers().Contains(p))
            {
                if (p.playerSession != null)
                    p.RemoveDirector(this);
                else
                    RemoveMember(p);
            }
        }

        // The client counts down from startTime itself; the server warns at 10, 5 and 1 minutes and fails
        // the leve at 0.
        private void CheckTimer(DateTime tick)
        {
            double left = (endTick - tick).TotalMinutes;
            foreach (int warnAt in new[] { 10, 5, 1 })
            {
                if (left <= warnAt && guildleveData.timeLimit > warnAt && timeWarnings.Add(warnAt))
                    Broadcast(T_TIME_WARN, warnAt);
            }
            if (left <= 0 && completeAt != null)
            {
                EndGuildleve(true);   // objectives were done; only 50023 was pending
                return;
            }
            if (left <= 0)
            {
                Broadcast(T_TIME_UP, (int)guildleveId);
                EndGuildleve(false);
            }
        }

        // Dead leve monsters leave the zone once the corpse has faded: with respawnTime 0 they would stay
        // in the actor list.
        private void PruneDead(DateTime tick)
        {
            foreach (var kv in deathTimes.ToList())
            {
                if ((tick - kv.Value).TotalSeconds < CORPSE_SECONDS)
                    continue;
                deathTimes.Remove(kv.Key);
                if (kv.Key.CurrentArea != null && CurrentArea.FindActorInArea(kv.Key.Id) != null)
                    DespawnMob(kv.Key);
            }
        }
        #endregion

        #region End
        // Success or failure: signal -1 and startTime 0; remaining targets vanish (50126); success spawns
        // the warp node at the last objective (50029, 50032).
        public void EndGuildleve(bool wasCompleted)
        {
            if (isEnded)
                return;
            isEnded = true;
            completionTime = completeAt != null ? doneSeconds : Utils.UnixTimeStampUTC() - guildleveWork.startTime;
            state = wasCompleted ? LeveState.Succeeded : LeveState.Failed;

            if (wasCompleted)
            {
                foreach (Player player in Participants().ToList())
                {
                    player.PlayAnimation(0x02000002, true);
                    player.ChangeMusic(81);
                    player.SendGameMessage(WorldMaster(), T_COMPLETE, 0x20, (object)(int)guildleveId);
                    player.SendDataPacket("attention", WorldMaster(), "", T_COMPLETE, (object)(int)guildleveId);
                    if (player.HasGuildleve(guildleveId))
                    {
                        player.SetGuildleveCompleted(guildleveId);
                        player.RecordGuildleveCompletion(guildleveId);
                        unclaimed[player.Id] = PayCompletion(player);
                    }
                    RemoveLeveItems(player);
                }
            }
            else
            {
                foreach (Player player in Participants().ToList())
                {
                    if (player.HasGuildleve(guildleveId))
                        player.SetGuildleveFailed(guildleveId);
                    RemoveLeveItems(player);
                    player.RestoreFieldMusic();   // state is Failed: the leve track is off
                }
            }

            DespawnLeveActors();

            guildleveWork.startTime = 0;
            guildleveWork.signal = -1;
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("guildleveWork/signal", this);
            propertyBuilder.AddProperty("guildleveWork.signal");
            propertyBuilder.NewTarget("guildleveWork/start");
            propertyBuilder.AddProperty("guildleveWork.startTime");
            SendPacketsToPlayers(propertyBuilder.Done());

            if (wasCompleted)
            {
                Vector3 at = lastObjectivePos ?? (guildleveOwner != null ? new Vector3(guildleveOwner.positionX, guildleveOwner.positionY, guildleveOwner.positionZ) : origin);
                warpNode = CurrentArea.SpawnLeveObject(GUILDLEVE_WARP_POINT, String.Format("glwarp_{0}", Id), at.X, at.Y, at.Z);
                foreach (Player player in Participants())
                {
                    player.SendGameMessage(WorldMaster(), T_NODE, 0x20);
                    player.SendGameMessage(WorldMaster(), T_NODE_30S, 0x20);
                    if (IsTutorial())
                        player.SendGameMessage(WorldMaster(), 50112, 0x20);
                }
                endTick = Program.Tick.AddSeconds(NODE_LIFETIME_SECONDS);
            }
            else
                endTick = Program.Tick.AddSeconds(FAIL_TEARDOWN_SECONDS);
        }

        // Remaining targets vanish (50126). Corpses, including the killing blow's target still inside
        // BattleNpc.Die, are left to fade unless includeCorpses.
        private void DespawnLeveActors(bool includeCorpses = false)
        {
            foreach (var g in groups)
                foreach (var m in g.mobs)
                    if (!deathTimes.ContainsKey(m) && m.CurrentArea != null && CurrentArea.FindActorInArea(m.Id) != null)
                        DespawnMob(m);
            if (includeCorpses)
            {
                foreach (var m in deathTimes.Keys)
                    if (m.CurrentArea != null && CurrentArea.FindActorInArea(m.Id) != null)
                        DespawnMob(m);
                deathTimes.Clear();
            }
            groups.Clear();
            foreach (Npc p in searchPoints)
                if (p.CurrentArea != null && CurrentArea.FindActorInArea(p.Id) != null)
                    p.Despawn();
            searchPoints.Clear();
            if (bonusBox != null && bonusBox.CurrentArea != null && CurrentArea.FindActorInArea(bonusBox.Id) != null)
                bonusBox.Despawn();
            bonusBox = null;
            ClearMarkers();
        }

        // Node faded or fail teardown: unclaimed rewards become pending (paid at any aetheryte, 50082,
        // 50040), then the director goes (content group 0x0143, RemoveActor).
        private void CloseLeve()
        {
            if (state == LeveState.Closed)
                return;
            bool succeeded = state == LeveState.Succeeded;
            state = LeveState.Closed;
            if (succeeded)
            {
                foreach (Player p in Participants())
                    p.SendGameMessage(WorldMaster(), T_NODE_FADES, 0x20);
            }
            StorePendingRewards();
            DespawnLeveActors(true);
            if (warpNode != null && warpNode.CurrentArea != null && CurrentArea.FindActorInArea(warpNode.Id) != null)
                warpNode.Despawn();
            if (!IsDeleted())
                EndDirector();
        }

        private void StorePendingRewards()
        {
            foreach (var kv in unclaimed.ToList())
                Database.AddPendingGuildleveReward(kv.Key, kv.Value);
            unclaimed.Clear();
        }

        // Abort from the aetheryte (eventGLPlay choice 6) or Break from the journal: 50024, fail, teardown.
        public void AbandonGuildleve()
        {
            if (state == LeveState.Starting || state == LeveState.Created)
            {
                foreach (Player player in GetPlayerMembers().OfType<Player>())
                    player.SendGameMessage(WorldMaster(), T_ABORTED, 0x20, (object)(int)guildleveId);
                state = LeveState.Closed;
                EndDirector();
                return;
            }
            if (state == LeveState.Running || state == LeveState.Waiting)
            {
                foreach (Player player in Participants())
                    player.SendGameMessage(WorldMaster(), T_ABORTED, 0x20, (object)(int)guildleveId);
                EndGuildleve(false);
            }
            CloseLeve();
        }

        //Delete ContentGroup, change music back
        public void EndGuildleveDirector()
        {
            if (state != LeveState.Closed)
            {
                if (state == LeveState.Running || state == LeveState.Waiting)
                    EndGuildleve(false);
                state = LeveState.Closed;
                StorePendingRewards();
                DespawnLeveActors(true);
                if (warpNode != null && warpNode.CurrentArea != null && CurrentArea.FindActorInArea(warpNode.Id) != null)
                    warpNode.Despawn();
            }
            foreach (Actor p in GetPlayerMembers())
            {
                Player player = (Player)p;
                if (player.playerSession != null && player.CurrentArea != null)
                    player.RestoreFieldMusic();
            }
        }

        // Lowering the difficulty mid-leve (eventGLPlay choice 4, 50081) sets a new enemy level for
        // monsters alive and not engaged. Only lowering is allowed (50014).
        public void SetDifficulty(byte stars)
        {
            if ((state != LeveState.Running && state != LeveState.Waiting) || stars < 1 || stars >= selectedDifficulty)
                return;
            selectedDifficulty = stars;
            enemyLevel = guildleveData.level + ENEMY_LEVEL_PER_STAR * (stars - 1);
            foreach (var g in groups)
            {
                foreach (var m in g.mobs.Where(m => m.IsAlive() && !m.aiContainer.IsEngaged()))
                {
                    m.charaWork.parameterSave.state_mainSkillLevel = (short)enemyLevel;
                    m.CalculateBaseStats();
                    m.RecalculateStats();
                }
            }
            foreach (Player p in Participants())
                p.SendGameMessage(WorldMaster(), T_DIFFICULTY_SET, 0x20, (object)(int)stars);
        }
        #endregion

        #region Rewards
        // Gil at the node: the card's figure plus this much per star above 1.
        public const double GIL_PER_STAR = 0.095;

        // Completion payout for a participant who holds the leve, in the client's log order: faction
        // bonus, credits, EXP bonus, EXP. Mission bonus = sum(aimNum x max kill EXP) x 0.5, +15% per star
        // above 1, +25% when cleared in half the limit; no rested bonus, no guild marks. Gil waits for
        // the warp node (eventGLReward) or an aetheryte.
        private LeveReward PayCompletion(Player player)
        {
            var r = new LeveReward { glId = guildleveId, clearSeconds = completionTime, stars = selectedDifficulty };
            bool speed = completionTime <= guildleveData.timeLimit * 60 * SPEED_BONUS_FRACTION;

            r.faction = (uint)Player.GetGuildleveEvaluationFaction(guildleveId);
            if (r.faction != 0)
            {
                Player.GetGuildleveFactionCredits(guildleveId, selectedDifficulty, speed, out int credits, out int bonus);
                r.factionCredit = (uint)credits;
                r.factionBonus = (uint)bonus;
                if (bonus > 0)
                    player.SendGameMessage(WorldMaster(), T_FACTION_BONUS, 0x20, (object)(selectedDifficulty > 1 ? 1 : 0), (object)(speed ? 1 : 0));
                int gained = player.AddFactionCredits((int)r.faction, credits + bonus);
                // 50132 {switch:int1,...} is 1-based: int1 = faction 1-3
                player.SendGameMessage(WorldMaster(), T_FACTION_EARN, 0x20, (object)(int)r.faction, (object)gained);
            }

            int lvl = Math.Max(1, Math.Min(enemyLevel, BattleUtils.BASEEXP.Length));
            double maxKill = BattleUtils.BASEEXP[lvl - 1] * BattleUtils.GetLevelDifferenceCap(lvl);
            int aimTotal = guildleveData.aimNum.Sum(a => Math.Max(0, (int)a));
            if (aimTotal == 0)
                aimTotal = 10;   // Survive with no target slot: a 5-minute defense, about 10 kills
            double baseExp = aimTotal * maxKill * 0.5;
            double diffExp = baseExp * 0.15 * (selectedDifficulty - 1);
            double speedExp = speed ? baseExp * 0.25 : 0;
            r.missionBonus = (uint)Math.Round(baseExp + speedExp);
            r.difficultyBonus = (uint)Math.Round(diffExp);
            int totalExp = (int)(r.missionBonus + r.difficultyBonus);
            if (totalExp > 0)
            {
                if (diffExp > 0 || speed)
                    player.SendGameMessage(WorldMaster(), T_EXP_BONUS, 0x20, (object)(diffExp > 0 ? 1 : 0), (object)(speed ? 1 : 0));
                // completion EXP goes to the active class, without rested bonus
                var results = player.AddExp(totalExp, (byte)player.GetClass(), 0);
                player.DoBattleAction(0, 0, results);
            }

            int cardGil = Player.GetGuildleveBaseGil(guildleveId);
            r.gil = (uint)Math.Round(cardGil * (1 + GIL_PER_STAR * (selectedDifficulty - 1)));
            return r;
        }

        // GuildleveWarpPoint talk: the reward window args for this player, once; null if none.
        public LeveReward ClaimReward(Player player)
        {
            if (!unclaimed.TryGetValue(player.Id, out LeveReward r))
                return null;
            unclaimed.Remove(player.Id);
            GiveRewardItems(player, r);
            return r;
        }

        public static void GiveRewardItems(Player player, LeveReward r)
        {
            if (r.gil > 0)
                player.GetItemPackage(ItemPackage.CURRENCY_CRYSTALS).AddItem(ITEM_GIL, (int)r.gil, 1);
            if (r.item2 != 0 && r.qty2 > 0)
            {
                var pkg = player.GetItemPackage(player.GetPackageForItem(r.item2));
                pkg?.AddItem(r.item2, (int)r.qty2, 1);
            }
        }

        private void GiveLeveItem(Player player, uint itemId)
        {
            if (itemId == 0)
                return;
            var pkg = player.GetItemPackage(player.GetPackageForItem(itemId));
            pkg?.AddItem(itemId, 1, 1);
            player.SendGameMessage(WorldMaster(), T_OBTAIN, 0x20, (object)(int)itemId, (object)1);
        }

        // Leve items (pages, gathered goods) exist only for the leve.
        private void RemoveLeveItems(Player player)
        {
            var items = new HashSet<uint>();
            foreach (var c in plan?.carriers ?? new List<GuildlevePlan.Carrier>()) items.Add(c.item);
            foreach (var pg in plan?.pages ?? new List<GuildlevePlan.Page>()) items.Add(pg.item);
            foreach (uint item in items.Where(i => i != 0))
            {
                var pkg = player.GetItemPackage(player.GetPackageForItem(item));
                while (pkg != null && pkg.HasItem(item))
                    pkg.RemoveItem(item, 1);
            }
        }
        #endregion

        #region Sync
        private void Broadcast(ushort textId, params object[] args)
        {
            object[] boxed = args.Select(a => a is int i ? (object)i : a).ToArray();
            foreach (Player p in Participants())
                p.SendGameMessage(WorldMaster(), textId, 0x20, boxed);
        }

        // Markers are the positions of up to 3 live objectives; unused markers are 0.
        private List<Vector3> ObjectivePoints(int max)
        {
            var points = new List<Vector3>();
            if (plan != null && plan.kind == "round" && stage < plan.stops.Count)
                points.Add(anchors[stage % anchors.Count]);
            if (plan != null && plan.kind == "survive" && !surviveDone && !surviveStarted)
                points.Add(defensePoint);
            foreach (Npc sp in searchPoints.Where(s => s.CurrentArea != null))
                if (points.Count < max) points.Add(new Vector3(sp.positionX, sp.positionY, sp.positionZ));
            // a group's marker is its placement point and goes away when its last member dies
            foreach (var g in groups.Where(g => g.Alive))
            {
                if (points.Count >= max)
                    break;
                points.Add(g.center);
            }
            return points;
        }

        private void UpdateObjectiveMarkers()
        {
            // Markers go out from Begin on, not at activation: the player needs them to find the leve area,
            // and entering it is what activates the leve. guildleveWork.markerX/Y/Z (tag "marker") drive both
            // the minimap and the full map.
            if (state == LeveState.Created || state == LeveState.Starting)
                return;
            var points = ObjectivePoints(3);
            bool changed = false;
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("guildleveWork/marker", this);
            for (int i = 0; i < 3; i++)
            {
                Vector3 p = i < points.Count ? points[i] : new Vector3();
                if (guildleveWork.markerX[i] == p.X && guildleveWork.markerY[i] == p.Y && guildleveWork.markerZ[i] == p.Z)
                    continue;
                guildleveWork.markerX[i] = p.X;
                guildleveWork.markerY[i] = p.Y;
                guildleveWork.markerZ[i] = p.Z;
                propertyBuilder.AddProperty(string.Format("guildleveWork.markerX[{0}]", i));
                propertyBuilder.AddProperty(string.Format("guildleveWork.markerY[{0}]", i));
                propertyBuilder.AddProperty(string.Format("guildleveWork.markerZ[{0}]", i));
                changed = true;
            }
            if (changed)
                SendPacketsToPlayers(propertyBuilder.Done());
        }

        // The client's DepictionJudge:judgeNameplate puts the leve icon on a chara that is a member of the
        // viewer's content group with property[2] set. Dead targets leave the group at once, which keeps
        // it under 24 members.
        public void AddTargetMember(BattleNpc mob)
        {
            // a full party (8, trusts included) leaves 16 slots for live targets; past that the mob still
            // fights, it just shows no leve icon
            var group = GetContentGroup();
            if (group == null)
                return;
            // the director fills one slot
            if (group.GetMembers().Count + 1 >= CONTENT_GROUP_CAPACITY)
            {
                Program.Log.Warn("Leve content group full ({0}): {1} gets no leve icon.", CONTENT_GROUP_CAPACITY, mob.Id);
                return;
            }
            group.AddMember(mob);
        }

        private const int CONTENT_GROUP_CAPACITY = 24;

        private void RemoveTargetMember(BattleNpc mob)
        {
            var group = GetContentGroup();
            if (group != null && group.GetMembers().Contains(mob.Id))
                group.RemoveMember(mob.Id);
        }

        private void DespawnMob(BattleNpc mob)
        {
            RemoveTargetMember(mob);
            if (mob.CurrentArea != null && CurrentArea.FindActorInArea(mob.Id) != null)
                mob.Despawn();
        }

        private void ClearMarkers()
        {
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("guildleveWork/marker", this);
            for (int i = 0; i < 3; i++)
            {
                guildleveWork.markerX[i] = guildleveWork.markerY[i] = guildleveWork.markerZ[i] = 0;
                propertyBuilder.AddProperty(string.Format("guildleveWork.markerX[{0}]", i));
                propertyBuilder.AddProperty(string.Format("guildleveWork.markerY[{0}]", i));
                propertyBuilder.AddProperty(string.Format("guildleveWork.markerZ[{0}]", i));
            }
            SendPacketsToPlayers(propertyBuilder.Done());
        }

        private void SyncInfoWork(params string[] fields)
        {
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("work/info", this);
            foreach (string f in fields)
                propertyBuilder.AddProperty(f);
            SendPacketsToPlayers(propertyBuilder.Done());
        }

        public void SyncAllInfo()
        {
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("guildleveWork/infoVariable", this);
            for (int i = 0; i < 4; i++)
            {
                if (guildleveWork.aimNum[i] != 0)
                    propertyBuilder.AddProperty(string.Format("guildleveWork.aimNum[{0}]", i));
                if (guildleveWork.aimNumNow[i] != 0)
                    propertyBuilder.AddProperty(string.Format("guildleveWork.aimNumNow[{0}]", i));
                if (guildleveWork.uiState[i] != 0)
                    propertyBuilder.AddProperty(string.Format("guildleveWork.uiState[{0}]", i));
            }
            SendPacketsToPlayers(propertyBuilder.Done());
        }

        public void UpdateAimNumNow(int index, sbyte value)
        {
            SetAimNow(index, value);
        }

        public void UpdateUiState(int index, sbyte value)
        {
            guildleveWork.uiState[index] = value;
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("guildleveWork/infoVariable", this);
            propertyBuilder.AddProperty(string.Format("guildleveWork.uiState[{0}]", index));
            SendPacketsToPlayers(propertyBuilder.Done());
        }

        public void UpdateMarkers(int markerIndex, float x, float y, float z)
        {
            guildleveWork.markerX[markerIndex] = x;
            guildleveWork.markerY[markerIndex] = y;
            guildleveWork.markerZ[markerIndex] = z;
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("guildleveWork/marker", this);
            propertyBuilder.AddProperty(string.Format("guildleveWork.markerX[{0}]", markerIndex));
            propertyBuilder.AddProperty(string.Format("guildleveWork.markerY[{0}]", markerIndex));
            propertyBuilder.AddProperty(string.Format("guildleveWork.markerZ[{0}]", markerIndex));
            SendPacketsToPlayers(propertyBuilder.Done());
        }

        public void SendPacketsToPlayers(List<SubPacket> packets)
        {
            List<Actor> players = GetPlayerMembers();
            foreach (Actor p in players)
            {
                if (((Player)p).playerSession != null)
                    ((Player)p).QueuePackets(packets);
            }
        }

        // One-line state for debugging.
        public string Describe()
        {
            return string.Format("leve {0} {1}/{2} state {3} stars {4} lvl {5} aims [{6}] now [{7}] groups {8} alive {9} anchors {10} participants {11} stage {12} hits {13} pages [{14}] books {15} survive {16}/{17}",
                guildleveId, plan?.kind, plan?.source, state, selectedDifficulty, enemyLevel,
                string.Join(",", guildleveData.aimNum), string.Join(",", guildleveWork.aimNumNow), groups.Count, groups.Count(g => g.Alive),
                anchors.Count, participants.Count, stage, hitsDone, string.Join(",", pagesDone), booksDestroyed, surviveStarted, surviveDone);
        }
        #endregion

        public static uint GlBorderIconIDToAnimID(uint iconId)
        {
            return iconId - 20000;
        }

        public static uint GlPlateIconIDToAnimID(uint iconId)
        {
            return iconId - 20020;
        }

        public static uint GetGLStartAnimationFromSheet(uint border, uint plate, bool isBoost)
        {
            return GetGLStartAnimation(GlBorderIconIDToAnimID(border), GlPlateIconIDToAnimID(plate), isBoost);
        }

        public static uint GetGLStartAnimation(uint border, uint plate, bool isBoost)
        {
            uint borderBits = border;
            uint plateBits = plate << 7;
            uint boostBits = isBoost ? (uint)0x8000 : (uint)0;
            return 0x0B000000 | boostBits | plateBits | borderBits;
        }
    }
}
