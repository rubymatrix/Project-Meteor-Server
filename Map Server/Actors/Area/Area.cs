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
using Meteor.Map.lua;
using Meteor.Map.packets.send.actor;
using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Map.packets.send;
using Meteor.Map.actors.director;

namespace Meteor.Map.Actors
{
    class Area : Actor
    {
        public string ZoneName { get; private set; }
        public uint ZoneId { get; private set; }
        public ushort RegionId { get; private set; }
        public bool isIsolated, canStealth, isInn, canRideChocobo, isInstanceRaid;
        public ushort weatherNormal, weatherCommon, weatherRare;
        public ushort bgmDay, bgmNight, bgmBattle;

        protected string classPath;

        public int boundingGridSize = 50;
        public int minX = -5000, minY = -5000, maxX = 5000, maxY = 5000;
        protected int numXBlocks, numYBlocks;
        protected int halfWidth, halfHeight;

        private Dictionary<uint, Director> currentDirectors = new Dictionary<uint, Director>();
        private Object directorLock = new Object();
        private uint directorIdCount = 0;

        protected Director mWeatherDirector;

        protected List<SpawnLocation> mSpawnLocations = new List<SpawnLocation>();
        protected Dictionary<uint, Actor> mActorList = new Dictionary<uint, Actor>();
        protected List<Actor>[,] mActorBlock;

        LuaScript areaScript;

        public string DescribeNavMesh(float x, float y, float z)
        {
            var navMesh = utils.NavmeshUtils.GetNavMesh(this);
            return navMesh == null ? $"{ZoneName} has no navmesh loaded." : navMesh.Describe(new Vector3(x, y, z));
        }

        // Returns the position unchanged when there is no ground near it.
        public Vector3 SnapToGround(float x, float y, float z) => utils.NavmeshUtils.SnapToGround(this, x, y, z);

        // Returns "Ok", "NotFound", "VerticalMismatch" (ground far above or below y; y = 0 means
        // unknown), "SmallIsland" (stray geometry on an old mesh) or "NoMesh".
        public string ProjectToGround(float x, float y, float z, out Vector3 ground)
        {
            var navMesh = utils.NavmeshUtils.GetNavMesh(this);
            if (navMesh == null)
            {
                ground = null;
                return "NoMesh";
            }
            return navMesh.ProjectSpawn(x, y, z, out ground).ToString();
        }

        private readonly object navLock = new object();
        private navigation.NavInstanceMesh navInstanceMesh;

        // Each area has its own instance so private areas don't share doors with the zone.
        public Meteor.Navigation.NavInstance GetNavInstance() => GetNavInstanceMesh()?.Instance;

        internal navigation.NavInstanceMesh GetNavInstanceMesh()
        {
            var world = this is PrivateArea pa ? pa.GetParentZone()?.navWorld : (this as Zone)?.navWorld;
            if (world == null)
                return null;
            var current = navInstanceMesh;
            if (current != null && current.Instance.World == world)
                return current;
            lock (navLock)
            {
                if (navInstanceMesh == null || navInstanceMesh.Instance.World != world)
                {
                    string name = this is PrivateArea priv ? $"{ZoneName}/{priv.GetPrivateAreaName()}/{priv.GetPrivateAreaType()}" : ZoneName;
                    var instance = world.CreateInstance(name);
                    instance.GateChanged += (inst, gate, open) =>
                        Program.Log.Debug("Nav gate {0} in {1} {2} (version {3}).", inst.World.Gates[gate].Id, inst.Name, open ? "opened" : "closed", inst.GateVersion);
                    navInstanceMesh = new navigation.NavInstanceMesh(instance);
                }
                return navInstanceMesh;
            }
        }

        public bool HasCollision => navigation.CollisionManager.Has(ZoneName);

        public Meteor.Navigation.CollisionWorld GetCollision() => navigation.CollisionManager.Get(ZoneName);

        // Opens or closes a door, lift or wall for this area only. Returns false when there is no such gate.
        public bool SetGate(string gateId, bool open)
        {
            var instance = GetNavInstance();
            if (instance == null)
                return false;
            bool found = instance.SetGate(gateId, open);
            if (!found)
                Program.Log.Warn("SetGate: {0} has no navigation gate \"{1}\".", ZoneName, gateId);
            return found;
        }

        // Null when the gate doesn't exist.
        public bool? IsGateOpen(string gateId)
        {
            var instance = GetNavInstance();
            if (instance == null || instance.World.GateIndex(gateId) < 0)
                return null;
            return instance.IsGateOpen(gateId);
        }

        public string DescribeGates()
        {
            var mesh = GetNavInstanceMesh();
            return mesh == null ? $"{ZoneName} has no .nav world (gates need one)." : mesh.DescribeGates();
        }

        public Area(uint zoneId, string zoneName, ushort regionId, string classPath, ushort bgmDay, ushort bgmNight, ushort bgmBattle, bool isIsolated, bool isInn, bool canRideChocobo, bool canStealth, bool isInstanceRaid)
            : base((4 << 28 | zoneId << 19 | ((uint)1)))
        {
            ZoneName = zoneName;
            ZoneId = zoneId;
            RegionId = regionId;

            this.canStealth = canStealth;
            this.isIsolated = isIsolated;
            this.isInn = isInn;
            this.canRideChocobo = canRideChocobo;
            this.isInstanceRaid = isInstanceRaid;

            this.bgmDay = bgmDay;
            this.bgmNight = bgmNight;
            this.bgmBattle = bgmBattle;

            this.LocalizedDisplayName = 0;
            this.DisplayName = "_areaMaster";
            this.Name = String.Format("_areaMaster@{0:X5}", zoneId << 8);

            this.classPath = classPath;
            this.className = classPath.Substring(classPath.LastIndexOf("/") + 1);

            numXBlocks = (maxX - minX) / boundingGridSize;
            numYBlocks = (maxY - minY) / boundingGridSize;
            mActorBlock = new List<Actor>[numXBlocks, numYBlocks];
            halfWidth = numXBlocks / 2;
            halfHeight = numYBlocks / 2;

            for (int y = 0; y < numYBlocks; y++)
            {
                for (int x = 0; x < numXBlocks; x++)
                {
                    mActorBlock[x, y] = new List<Actor>();
                }
            }
        }

        public virtual string GetPrivateAreaName()
        {
            return "";
        }

        public virtual int GetPrivateAreaType()
        {
            return 0;
        }

        public virtual bool IsPublic()
        {
            return true;
        }

        public virtual bool IsPrivate()
        {
            return !IsPublic();
        }

        public override SubPacket CreateScriptBindPacket()
        {
            List<LuaParam> lParams;
            lParams = LuaUtils.CreateLuaParamList(classPath, false, true, ZoneName, "/Area/Zone/ZoneDefault", -1, (byte)1, true, false, false, false, false, false, false, false);
            return ActorInstantiatePacket.BuildPacket(Id, Name, "ZoneDefault", lParams);
        }

        public override List<SubPacket> GetSpawnPackets()
        {
            List<SubPacket> subpackets = new List<SubPacket>();
            subpackets.Add(CreateAddActorPacket(0));            
            subpackets.Add(CreateSpeedPacket());
            subpackets.Add(CreateSpawnPositonPacket(0x1));
            subpackets.Add(CreateNamePacket());
            subpackets.Add(CreateStatePacket());
            subpackets.Add(CreateIsZoneingPacket());
            subpackets.Add(CreateScriptBindPacket());
            return subpackets;
        }

        // todo: handle instance areas in derived class? (see virtuals)
        #region Actor Management

        public void AddActorToZone(Actor actor)
        {
            lock (mActorList)
            {
                if (actor is Character)
                    ((Character)actor).ResetTempVars();

                if (!mActorList.ContainsKey(actor.Id))
                    mActorList.Add(actor.Id, actor);


                int gridX = (int)actor.positionX / boundingGridSize;
                int gridY = (int)actor.positionZ / boundingGridSize;

                gridX += halfWidth;
                gridY += halfHeight;

                //Boundries
                if (gridX < 0)
                    gridX = 0;
                if (gridX >= numXBlocks)
                    gridX = numXBlocks - 1;
                if (gridY < 0)
                    gridY = 0;
                if (gridY >= numYBlocks)
                    gridY = numYBlocks - 1;

                lock (mActorBlock)
                    mActorBlock[gridX, gridY].Add(actor);
            }
        }

        public void RemoveActorFromZone(Actor actor)
        {
            if (actor != null)
                lock (mActorList)
                {
                    mActorList.Remove(actor.Id);

                    int gridX = (int)actor.positionX / boundingGridSize;
                    int gridY = (int)actor.positionZ / boundingGridSize;

                    gridX += halfWidth;
                    gridY += halfHeight;

                    //Boundries
                    if (gridX < 0)
                        gridX = 0;
                    if (gridX >= numXBlocks)
                        gridX = numXBlocks - 1;
                    if (gridY < 0)
                        gridY = 0;
                    if (gridY >= numYBlocks)
                        gridY = numYBlocks - 1;

                    lock (mActorBlock)
                        mActorBlock[gridX, gridY].Remove(actor);
                }
        }

        public void UpdateActorPosition(Actor actor)
        {
            int gridX = (int)actor.positionX / boundingGridSize;
            int gridY = (int)actor.positionZ / boundingGridSize;

            gridX += halfWidth;
            gridY += halfHeight;

            //Boundries
            if (gridX < 0)
                gridX = 0;
            if (gridX >= numXBlocks)
                gridX = numXBlocks - 1;
            if (gridY < 0)
                gridY = 0;
            if (gridY >= numYBlocks)
                gridY = numYBlocks - 1;

            int gridOldX = (int)actor.oldPositionX / boundingGridSize;
            int gridOldY = (int)actor.oldPositionZ / boundingGridSize;

            gridOldX += halfWidth;
            gridOldY += halfHeight;

            //Boundries
            if (gridOldX < 0)
                gridOldX = 0;
            if (gridOldX >= numXBlocks)
                gridOldX = numXBlocks - 1;
            if (gridOldY < 0)
                gridOldY = 0;
            if (gridOldY >= numYBlocks)
                gridOldY = numYBlocks - 1;

            //Still in same block
            if (gridX == gridOldX && gridY == gridOldY)
                return;

            lock (mActorBlock)
            {
                mActorBlock[gridOldX, gridOldY].Remove(actor);
                mActorBlock[gridX, gridY].Add(actor);
            }
        }

        public virtual List<T> GetActorsAroundPoint<T>(float x, float y, int checkDistance) where T : Actor
        {
            checkDistance /= boundingGridSize;

            int gridX = (int)x / boundingGridSize;
            int gridY = (int)y / boundingGridSize;

            gridX += halfWidth;
            gridY += halfHeight;

            //Boundries
            if (gridX < 0)
                gridX = 0;
            if (gridX >= numXBlocks)
                gridX = numXBlocks - 1;
            if (gridY < 0)
                gridY = 0;
            if (gridY >= numYBlocks)
                gridY = numYBlocks - 1;

            List<T> result = new List<T>();

            lock (mActorBlock)
            {
                for (int gx = gridX - checkDistance; gx <= gridX + checkDistance; gx++)
                {
                    for (int gy = gridY - checkDistance; gy <= gridY + checkDistance; gy++)
                    {
                        result.AddRange(mActorBlock[gx, gy].OfType<T>());
                    }
                }
            }

            //Remove players if isolation zone
            if (isIsolated)
            {
                for (int i = 0; i < result.Count; i++)
                {
                    if (result[i] is Player)
                        result.RemoveAt(i);
                }
            }
            return result;
        }

        public virtual List<Actor> GetActorsAroundPoint(float x, float y, int checkDistance)
        {
            return GetActorsAroundPoint<Actor>(x, y, checkDistance);
        }

        public virtual List<Actor> GetActorsAroundActor(Actor actor, int checkDistance)
        {
            return GetActorsAroundActor<Actor>(actor, checkDistance);
        }

        public virtual List<T> GetActorsAroundActor<T>(Actor actor, int checkDistance) where T : Actor
        {
            checkDistance /= boundingGridSize;

            int gridX = (int)actor.positionX / boundingGridSize;
            int gridY = (int)actor.positionZ / boundingGridSize;

            gridX += halfWidth;
            gridY += halfHeight;

            //Boundries
            if (gridX < 0)
                gridX = 0;
            if (gridX >= numXBlocks)
                gridX = numXBlocks - 1;
            if (gridY < 0)
                gridY = 0;
            if (gridY >= numYBlocks)
                gridY = numYBlocks - 1;

            var result = new List<T>();

            lock (mActorBlock)
            {
                for (int gy = ((gridY - checkDistance) < 0 ? 0 : (gridY - checkDistance)); gy <= ((gridY + checkDistance) >= numYBlocks ? numYBlocks - 1 : (gridY + checkDistance)); gy++)
                {
                    for (int gx = ((gridX - checkDistance) < 0 ? 0 : (gridX - checkDistance)); gx <= ((gridX + checkDistance) >= numXBlocks ? numXBlocks - 1 : (gridX + checkDistance)); gx++)
                    {
                        result.AddRange(mActorBlock[gx, gy].OfType<T>());
                    }
                }
            }

            //Remove players if isolation zone
            if (isIsolated)
            {
                for (int i = 0; i < result.Count; i++)
                {
                    if (result[i] is Player)
                        result.RemoveAt(i);
                }
            }

            return result;
        }

        #endregion

        public Actor FindActorInArea(uint id)
        {
            lock (mActorList)
            {
                if (!mActorList.ContainsKey(id))
                    return null;
                return mActorList[id];
            }
        }

        public T FindActorInArea<T>(uint id) where T : Actor
        {
            return FindActorInArea(id) as T;
        }

        public Actor FindActorInZoneByUniqueID(string uniqueId)
        {
            lock (mActorList)
            {
                foreach (Actor a in mActorList.Values)
                {
                    if (a is Npc)
                    {
                        if (((Npc)a).GetUniqueId().ToLower().Equals(uniqueId))
                            return a;
                    }
                }
            }
            return null;
        }

        public Player FindPCInZone(string name)
        {
            lock (mActorList)
            {
                foreach (Player player in mActorList.Values.OfType<Player>())
                {
                    if (player.DisplayName.ToLower().Equals(name.ToLower()))
                        return player;
                }
                return null;
            }
        }

        public Player FindPCInZone(uint id)
        {
            lock (mActorList)
            {
                if (!mActorList.ContainsKey(id))
                    return null;
                return (Player)mActorList[id];
            }
        }

        public void Clear()
        {
            lock (mActorList)
            {
                //Clear All
                mActorList.Clear();
                lock (mActorBlock)
                {
                    for (int y = 0; y < numYBlocks; y++)
                    {
                        for (int x = 0; x < numXBlocks; x++)
                        {
                            mActorBlock[x, y].Clear();
                        }
                    }
                }
            }
        }

        // todo: for zones override this to search contentareas (assuming flag is passed)
        public virtual List<T> GetAllActors<T>() where T : Actor
        {
            lock (mActorList)
            {
                List<T> actorList = new List<T>(mActorList.Count);
                actorList.AddRange(mActorList.Values.OfType<T>());
                return actorList;
            }
        }

        // The counter only moves forward, so a despawned actor's number isn't reused while clients may
        // still hold it. A private area shares its parent zone's ids, so it also skips the parent's.
        private int nextActorNumber = 1;
        private const int ACTOR_NUMBER_LAST = (1 << 19) - 6;

        public int AllocateActorNumber()
        {
            lock (mActorList)
            {
                for (int tries = 0; tries < ACTOR_NUMBER_LAST; tries++)
                {
                    int n = nextActorNumber++;
                    if (nextActorNumber > ACTOR_NUMBER_LAST)
                        nextActorNumber = 1;
                    uint id = NpcActorId(n);
                    if (!mActorList.ContainsKey(id) && !ActorIdTakenOutside(id))
                        return n;
                }
                throw new InvalidOperationException(String.Format("Area {0}: no free actor numbers.", ZoneId));
            }
        }

        protected virtual bool ActorIdTakenOutside(uint id)
        {
            return false;
        }

        public bool HasActorId(uint id)
        {
            lock (mActorList)
                return mActorList.ContainsKey(id);
        }

        private uint NpcActorId(int actorNumber)
        {
            return (uint)(4 << 28 | ZoneId << 19 | ((uint)actorNumber + 5));
        }

        public int GetActorCount()
        {
            lock (mActorList)
            {
                return mActorList.Count;
            }
        }

        public virtual List<Actor> GetAllActors()
        {
            return GetAllActors<Actor>();
        }

        public virtual List<Player> GetPlayers()
        {
            return GetAllActors<Player>();
        }

        public virtual List<BattleNpc> GetMonsters()
        {
            return GetAllActors<BattleNpc>();
        }

        public virtual List<Ally> GetAllies()
        {
            return GetAllActors<Ally>();
        }

        public void BroadcastPacketsAroundActor(Actor actor, List<SubPacket> packets)
        {
            foreach (SubPacket packet in packets)
                BroadcastPacketAroundActor(actor, packet);
        }

        public void BroadcastPacketAroundActor(Actor actor, SubPacket packet)
        {
            if (isIsolated)
                return;

            List<Actor> aroundActor = GetActorsAroundActor(actor, 50);
            foreach (Actor a in aroundActor)
            {                
                if (a is Player)
                {
                    if (isIsolated)
                        continue;

                    SubPacket clonedPacket = new SubPacket(packet, a.Id);
                    Player p = (Player)a;                        
                    p.QueuePacket(clonedPacket);
                }
            }            
        }

        public void BroadcastPacketAroundPoint(float x, float y, SubPacket packet)
        {
            if (isIsolated)
                return;

            List<Actor> aroundActor = GetActorsAroundPoint(x, y, 50);
            foreach (Actor a in aroundActor)
            {
                if (a is Player)
                {
                    if (isIsolated)
                        continue;

                    SubPacket clonedPacket = new SubPacket(packet, a.Id);
                    Player p = (Player)a;
                    p.QueuePacket(clonedPacket);
                }
            }
        }

        public void SpawnActor(SpawnLocation location)
        {
            lock (mActorList)
            {
                ActorClass actorClass = Server.GetWorldManager().GetActorClass(location.classId);

                if (actorClass == null)
                    return;

                Npc npc = new Npc(AllocateActorNumber(), actorClass, location.uniqueId, this, location.x, location.y, location.z, location.rot, 0, location.motionPack, null, location.mapObjLayoutId, location.mapObjInstanceId);

                npc.LoadEventConditions(location.eventConditions ?? actorClass.eventConditions);
                npc.questGates = location.questGates;

                AddActorToZone(npc);
            }
        }

        public Npc SpawnActor(uint classId, string uniqueId, float x, float y, float z, float rot = 0, ushort state = 0, uint animId = 0, bool isMob = false)
        {
            lock (mActorList)
            {
                ActorClass actorClass = Server.GetWorldManager().GetActorClass(classId);

                if (actorClass == null)
                    return null;

                Npc npc;
                if (isMob)
                    npc = new BattleNpc(AllocateActorNumber(), actorClass, uniqueId, this, x, y, z, rot, state, animId, null);
                else
                    npc = new Npc(AllocateActorNumber(), actorClass, uniqueId, this, x, y, z, rot, state, animId, null);

                npc.LoadEventConditions(actorClass.eventConditions);
                npc.SetMaxHP(100);
                npc.SetHP(100);
                npc.ResetMoveSpeeds();

                AddActorToZone(npc);

                return npc;
            }
        }

        public Npc SpawnActor(uint classId, string uniqueId, float x, float y, float z, uint regionId, uint layoutId)
        {
            lock (mActorList)
            {
                ActorClass actorClass = Server.GetWorldManager().GetActorClass(classId);

                if (actorClass == null)
                    return null;

                Npc npc = new Npc(AllocateActorNumber(), actorClass, uniqueId, this, x, y, z, 0, regionId, layoutId);

                npc.LoadEventConditions(actorClass.eventConditions);

                AddActorToZone(npc);

                return npc;
            }
        }

        public BattleNpc GetBattleNpcById(uint id)
        {
            foreach (var bnpc in GetAllActors<BattleNpc>())
            {
                if (bnpc.GetBattleNpcId() == id)
                    return bnpc;
            }
            return null;
        }

        public void DespawnActor(string uniqueId)
        {
            RemoveActorFromZone(FindActorInZoneByUniqueID(uniqueId));
        }

        public void DespawnActor(Actor actor)
        {
            RemoveActorFromZone(actor);
        }

        public Director GetWeatherDirector()
        {
            return mWeatherDirector;
        }

        public void ChangeWeather(ushort weather, ushort transitionTime, Player player, bool zoneWide = false)
        {
            weatherNormal = weather;

            if (player != null && !zoneWide)
            {
                player.QueuePacket(SetWeatherPacket.BuildPacket(player.Id, weather, transitionTime));
            }
            if (zoneWide)
            {
                lock (mActorList)
                {
                    foreach (var actor in mActorList)
                    {
                        if (actor.Value is Player)
                        {
                            player = ((Player)actor.Value);
                            player.QueuePacket(SetWeatherPacket.BuildPacket(player.Id, weather, transitionTime));
                        }
                    }
                }
            }
        }                

        public Director CreateDirector(string path, bool hasContentGroup, params object[] args)
        {
            lock (directorLock)
            {
                Director director = new Director(directorIdCount, this, path, hasContentGroup, args);
                currentDirectors.Add(director.Id, director);
                directorIdCount++;
                return director;
            }
        }

        public Director CreateGuildleveDirector(uint glid, byte difficulty, Player owner, params object[] args)
        {
            String directorScriptPath = "";

            uint type = Server.GetGuildleveGamedata(glid).plateId;

            if (glid == 10801 || glid == 12401 || glid == 11601)
                directorScriptPath = "Guildleve/PrivateGLBattleTutorial";
            else
            {
                switch (type)
                {
                    case 20021:
                        directorScriptPath = "Guildleve/PrivateGLBattleSweepNormal";
                        break;
                    case 20022:
                        directorScriptPath = "Guildleve/PrivateGLBattleChaseNormal";
                        break;
                    case 20023:
                        directorScriptPath = "Guildleve/PrivateGLBattleOrbNormal";
                        break;
                    case 20024:
                        directorScriptPath = "Guildleve/PrivateGLBattleHuntNormal";
                        break;
                    case 20025:
                        directorScriptPath = "Guildleve/PrivateGLBattleGatherNormal";
                        break;
                    case 20026:
                        directorScriptPath = "Guildleve/PrivateGLBattleRoundNormal";
                        break;
                    case 20027:
                        directorScriptPath = "Guildleve/PrivateGLBattleSurviveNormal";
                        break;
                    case 20028:
                        directorScriptPath = "Guildleve/PrivateGLBattleDetectNormal";
                        break;                   
                }
            }

            lock (directorLock)
            {
                GuildleveDirector director = new GuildleveDirector(directorIdCount, this, directorScriptPath, glid, difficulty, owner, args);
                currentDirectors.Add(director.Id, director);
                directorIdCount++;
                return director;
            }
        }

        public void DeleteDirector(uint id)
        {
            lock (directorLock)
            {
                if (currentDirectors.ContainsKey(id))
                {
                    if (!currentDirectors[id].IsDeleted())
                        currentDirectors[id].EndDirector();
                    currentDirectors.Remove(id);
                }
            }
        }

        public Director GetDirectorById(uint id)
        {
            if (currentDirectors.ContainsKey(id))
                return currentDirectors[id];
            return null;
        }

        public override void Update(DateTime tick)
        {
            lock (mActorList)
            {
                foreach (Actor a in mActorList.Values.ToList())
                    a.Update(tick);

            }

            Meteor.Map.Content.ContentManager.TickArea(this);
        }

    }
}
