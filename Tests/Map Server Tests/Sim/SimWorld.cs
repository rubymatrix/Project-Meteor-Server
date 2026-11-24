using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Meteor.Map.actors.area;
using Meteor.Map.Actors;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.DataObjects;
using Meteor.Map.actors.group;
using Meteor.Map.Tests.Formulas;
using Xunit;
using Meteor.Common;

namespace Meteor.Map.Tests.Sim
{
    // A map server with one zone and no database: battle data comes from the seed SQL, time
    // from a ManualClock and rolls from a seeded Dice.Shared. Packets and telemetry are recorded.
    internal sealed class SimWorld : IDisposable
    {
        public static readonly DateTime Start = new DateTime(2012, 9, 1, 12, 0, 0, DateTimeKind.Utc);
        public readonly ManualClock Clock;
        public readonly Zone Zone;
        public readonly RecordingPacketSink Packets = new RecordingPacketSink();
        public readonly TelemetryRecorder Events = new TelemetryRecorder();
        private readonly IDisposable attached;
        private uint nextSession = 1;
        private readonly List<uint> sessions = new List<uint>();

        private static bool loaded;
        private static WorldManager worldManager;
        private static readonly object Gate = new object();

        private SimWorld(ulong seed, uint zoneId)
        {
            Clock = new ManualClock(Start);
            GameClock.Use(() => Clock.Now);
            Program.Tick = Clock.Now;
            Dice.Shared.Reseed(seed);
            LoadStaticData();
            attached = Telemetry.Attach(Events);
            Zone = new Zone(zoneId, "simZone" + zoneId, 101, "/Area/Zone/ZoneMasterSeaS0", 0, 0, 0, false, false, false, false, false);
            worldManager.AddZone(Zone);
        }

        public static SimWorld Create(ulong seed = 1, uint zoneId = 128) => new SimWorld(seed, zoneId);

        private static void LoadStaticData()
        {
            lock (Gate)
            {
                if (loaded)
                    return;
                Directory.SetCurrentDirectory(AppContext.BaseDirectory);
                ConfigConstants.OPTIONS_SCRIPTPATH = "./scripts";
                // Nothing listens on port 1, so any database call fails at once and the caller
                // logs it and goes on.
                ConfigConstants.DATABASE_HOST = "127.0.0.1";
                ConfigConstants.DATABASE_PORT = "1";
                ConfigConstants.DATABASE_NAME = "none";
                ConfigConstants.DATABASE_USERNAME = "none";
                ConfigConstants.DATABASE_PASSWORD = "none";

                Program.Log = Program.Log ?? NLog.LogManager.GetLogger("sim");
                new Server();
                worldManager = new WorldManager(Server.GetServer());
                Server.UseWorldManager(worldManager);
                Server.UseGamedata(new Dictionary<uint, ItemData>());

                foreach (var row in new SeedTable("server_statuseffects").Rows.Values)
                    worldManager.AddStatusEffect(Database.ReadStatusEffect(c => row[c]));
                foreach (var row in new SeedTable("server_battle_commands").Rows.Values)
                    worldManager.AddBattleCommand(Database.ReadBattleCommand(c => row[c]));
                loaded = true;
            }
        }

        public Player AddPlayer(byte classId, short level, float x = 0, float z = 0)
        {
            var session = new Session(nextSession++, Packets);
            Server.GetServer().GetSessionList()[session.id] = session;
            sessions.Add(session.id);
            // Zone-in done: the server unlocks updates once the client has loaded the zone.
            session.isUpdatesLocked = false;
            var player = session.GetActor();
            player.charaWork.parameterSave.state_mainSkill[0] = classId;
            player.charaWork.battleSave.skillLevel[classId - 1] = level;
            player.charaWork.parameterSave.state_mainSkillLevel = level;
            // Every player is in a party, a party of one when solo.
            player.SetParty(new Party(0x8000_0000_0000_0000UL | player.Id, player.Id));
            Place(player, x, z);
            player.CalculateBaseStats();
            player.SetHP((uint)player.GetMaxHP());
            player.SetMP((uint)player.GetMaxMP());
            return player;
        }

        public BattleNpc AddMob(uint actorClassId, string classPath, short level, float x = 0, float z = 2)
        {
            var actorClass = new ActorClass(actorClassId, classPath, 0, 0, "{}", 0, 0, 0);
            var mob = new BattleNpc(Zone.AllocateActorNumber(), actorClass, "simMob", Zone, x, 0, z, 0, 0, 0, null);
            mob.charaWork.parameterSave.state_mainSkillLevel = level;
            Zone.AddActorToZone(mob);
            mob.CalculateBaseStats();
            mob.SetHP((uint)mob.GetMaxHP());
            return mob;
        }

        // What the world server's party sync does when these players form a party.
        public static Party Party(params Player[] members)
        {
            var party = new Party(0x8000_0000_0000_0000UL | members[0].Id, members[0].Id);
            party.members = members.Select(m => m.Id).ToList();
            foreach (var m in members)
                m.SetParty(party);
            return party;
        }

        // What the client's target and lock-on packets set before an attack command.
        public void Lock(Character who, Character target)
        {
            who.currentTarget = target.Id;
            who.currentLockedTarget = target.Id;
        }

        public void Attack(Character who, Character target)
        {
            Lock(who, target);
            who.Engage(target);
        }

        // Enough HP to outlast a long test without changing the fight's numbers.
        public static void Durable(Character c, short hp = 30000)
        {
            c.SetMaxHP((uint)hp);
            c.SetHP((uint)hp);
        }

        public List<TelemetryEvent> Of(string kind, Character actor = null) =>
            Events.Of(kind).Where(e => actor == null || e.Actor == actor.Id).ToList();

        public double Seconds(TelemetryEvent e) => (e.Time - Start).TotalSeconds;

        public double Now => (Clock.Now - Start).TotalSeconds;

        private void Place(Character c, float x, float z)
        {
            c.positionX = x;
            c.positionY = 0;
            c.positionZ = z;
            c.CurrentArea = Zone;
            Zone.AddActorToZone(c);
        }

        // Runs the zone loop for the given time at the server's 100 ms step.
        public void Run(double seconds, double step = 0.1)
        {
            for (double t = 0; t < seconds - 1e-9; t += step)
            {
                Clock.Advance(step);
                Program.Tick = Clock.Now;
                Zone.Update(Program.Tick);
                Program.LastTick = Program.Tick;
                lua.LuaEngine.GetInstance().PulseSleepingOnTime(null);
            }
        }

        public void Dispose()
        {
            attached.Dispose();
            foreach (var id in sessions)
                Server.GetServer().RemoveSession(id);
            GameClock.Use(null);
        }
    }

    [CollectionDefinition("sim", DisableParallelization = true)]
    public sealed class SimCollection { }
}
