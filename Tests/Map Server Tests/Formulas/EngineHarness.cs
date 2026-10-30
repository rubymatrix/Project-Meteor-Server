using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using Meteor.Map.Actors;
using Meteor.Map.actors.area;
using Meteor.Map.actors.chara;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.AI;
using Meteor.Map.DataObjects.chara;
using Meteor.Map.Actors.Chara;

namespace Meteor.Map.Tests.Formulas
{
    // A player-side character with no session or database: everything a player gets from Character.
    internal sealed class EnginePc : Character
    {
        public EnginePc(uint id, Zone zone, short level, short classId = 0, float x = 0, float z = 0) : base(id)
        {
            Name = "enginePc" + id;
            DisplayName = Name;
            CurrentArea = zone;
            positionX = x;
            positionZ = z;
            aiContainer = new AIContainer(this, null, null, new TargetFind(this));
            factionId = Factions.Player;
            charaWork.parameterSave.state_mainSkill[0] = (byte)classId;
            charaWork.parameterSave.state_mainSkillLevel = level;
            SetMaxHP(3000);
            SetHP(3000);
            SetMaxMP(3000);
            SetMP(1000);
            zone.AddActorToZone(this);
        }

        public void SetTp(int tp)
        {
            AddTP(-GetTP());
            AddTP(tp);
        }
    }

    // A zone, a WorldManager holding it and the seed status rows, and actor builders.
    public abstract class EngineHarness : ContentHarness
    {
        private static readonly FieldInfo worldField = typeof(Server).GetField("WorldManager", BindingFlags.NonPublic | BindingFlags.Static);
        private readonly object savedWorld;
        private uint nextPcId = 0xA1000001;

        protected EngineHarness()
        {
            savedWorld = worldField.GetValue(null);
            var world = new WorldManager(null);
            typeof(WorldManager).GetField("zoneList", BindingFlags.NonPublic | BindingFlags.Instance)
                .SetValue(world, new Dictionary<uint, Zone> { { zone.ZoneId, zone } });
            var statuses = (Dictionary<uint, StatusEffect>)typeof(WorldManager)
                .GetField("statusEffectList", BindingFlags.NonPublic | BindingFlags.Instance).GetValue(world);
            foreach (var s in SeedStatuses())
                statuses[(uint)s.GetStatusEffectId()] = s;
            worldField.SetValue(null, world);
        }

        public override void Dispose()
        {
            worldField.SetValue(null, savedWorld);
            base.Dispose();
        }

        internal EnginePc Pc(short level, short classId = 0, float x = 0, float z = 0) =>
            new EnginePc(nextPcId++, zone, level, classId, x, z);

        internal BattleNpc Mob(short level, int maxHp = 30000, float x = 0, float z = 0)
        {
            var cls = new ActorClass(2104102, "/Chara/Npc/Monster/Bat/BatNormalStandard", 0, 0, null, 0, 0, 0);
            var npc = new BattleNpc(zone.AllocateActorNumber(), cls, "engineMob", zone, x, 0, z, 0, 0, 0, null);
            npc.charaWork.parameterSave.state_mainSkillLevel = level;
            npc.SetMaxHP((uint)maxHp);
            npc.SetHP((uint)maxHp);
            zone.AddActorToZone(npc);
            return npc;
        }

        internal static void SetTp(Character c, int tp)
        {
            c.AddTP(-c.GetTP());
            c.AddTP(tp);
        }

        // A Player shell with no session or database, for the Player members that only read its own
        // work fields.
        internal static Player PlayerShell(uint id, short level)
        {
            var p = (Player)RuntimeHelpers.GetUninitializedObject(typeof(Player));
            p.Id = id;
            p.charaWork = new CharaWork();
            p.playerWork = new PlayerWork();
            p.charaWork.parameterSave.state_mainSkillLevel = level;
            return p;
        }

        internal static IEnumerable<StatusEffect> SeedStatuses()
        {
            var sql = File.ReadAllText(Path.Combine(SeedDir(), "server_statuseffects.sql"));
            foreach (Match m in Regex.Matches(sql, @"VALUES \((\d+),'([^']*)',(\d+),(\d+),(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)"))
            {
                uint U(int i) => uint.Parse(m.Groups[i].Value);
                yield return new StatusEffect(U(1), m.Groups[2].Value, U(3), U(4), U(5), U(6) != 0, U(7) != 0, U(8) != 0, (ushort)U(9), (ushort)U(10));
            }
        }

        // The repository's Data/sql, found from the test binaries.
        internal static string SeedDir()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "Data", "sql")))
                dir = dir.Parent;
            return Path.Combine(dir.FullName, "Data", "sql");
        }
    }
}
