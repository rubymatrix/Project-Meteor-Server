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
using Meteor.Map.actors.group.Work;
using Meteor.Map.DataObjects;
using Meteor.Map.packets.send.group;
using Meteor.Map.packets.send.groups;
using System;
using System.Collections.Generic;

namespace Meteor.Map.actors.group
{
    class MonsterParty : Group
    {
        public const ulong GROUP_ID_BASE = 0x2680000000000000;
        // The client's 0x0133 drops the top byte, so lookups ignore it.
        private const ulong GROUP_ID_LOOKUP_MASK = 0x00FFFFFFFFFFFFFF;
        private const uint MEMBER_LAYOUT_ID = 1001;

        private static readonly object registryLock = new object();
        private static readonly Dictionary<ulong, MonsterParty> registry = new Dictionary<ulong, MonsterParty>();
        private static ulong nextIndex = 1;
        private static ulong lastSequence = 0;

        public PartyWork partyGroupWork = new PartyWork();
        private List<uint> monsterMembers = new List<uint>();

        public ulong occupancyGroupId;

        public MonsterParty(ulong groupIndex, uint[] initialMonsterMembers)
            : base(groupIndex)
        {
            if(initialMonsterMembers != null)
                for (int i = 0; i < initialMonsterMembers.Length; i++)
                    monsterMembers.Add(initialMonsterMembers[i]);
            if (monsterMembers.Count > 0)
                SetOwner(monsterMembers[0]);
        }

        public static MonsterParty Create(uint monsterActorId)
        {
            lock (registryLock)
            {
                MonsterParty group = new MonsterParty(GROUP_ID_BASE | nextIndex++, new uint[] { monsterActorId });
                registry[group.groupIndex & GROUP_ID_LOOKUP_MASK] = group;
                return group;
            }
        }

        public static MonsterParty Find(ulong groupId)
        {
            lock (registryLock)
            {
                MonsterParty group;
                return registry.TryGetValue(groupId & GROUP_ID_LOOKUP_MASK, out group) ? group : null;
            }
        }

        public static void Unregister(MonsterParty group)
        {
            lock (registryLock)
                registry.Remove(group.groupIndex & GROUP_ID_LOOKUP_MASK);
        }

        // The client keys a group under construction by (sequenceId, locationCode); keep them unique
        // when many mobs spawn in the same millisecond.
        private static ulong NextSequence()
        {
            lock (registryLock)
            {
                ulong now = Utils.MilisUnixTimeStampUTC(GameClock.Now);
                lastSequence = Math.Max(lastSequence + 1, now);
                return lastSequence;
            }
        }

        private void SetOwner(uint actorId)
        {
            partyGroupWork._globalTemp.owner = (ulong)actorId << 32;
        }

        public List<uint> GetMembers()
        {
            return monsterMembers;
        }

        public override int GetMemberCount()
        {
            return monsterMembers.Count;
        }

        public override uint GetTypeId()
        {
            return Group.MonsterPartyGroup;
        }

        public override List<GroupMember> BuildMemberList(uint id)
        {
            List<GroupMember> groupMembers = new List<GroupMember>();
            foreach (uint charaId in monsterMembers)
                groupMembers.Add(new GroupMember(charaId, -1, 0, false, true, ""));
            return groupMembers;
        }

        public List<SubPacket> BuildSpawnPackets(uint playerActorId, uint locationCode)
        {
            ulong sequence = NextSequence();
            List<SubPacket> packets = new List<SubPacket>();
            packets.Add(GroupHeaderPacket.buildMonsterPartyPacket(playerActorId, locationCode, sequence, this));
            packets.Add(GroupMembersBeginPacket.buildPacket(playerActorId, locationCode, sequence, this));
            packets.Add(ContentMembersX08Packet.buildCompactPacket(playerActorId, locationCode, sequence, monsterMembers, MEMBER_LAYOUT_ID));
            packets.Add(GroupMembersEndPacket.buildPacket(playerActorId, locationCode, sequence, this));
            if (occupancyGroupId != 0)
                packets.Add(BuildOccupancyPacket(playerActorId, occupancyGroupId));
            return packets;
        }

        public SubPacket BuildOccupancyPacket(uint playerActorId, ulong occupyingGroupId)
        {
            return SetOccupancyGroupPacket.BuildPacket(playerActorId, groupIndex, GetTypeId(), occupyingGroupId);
        }

        public SubPacket BuildDeletePacket(uint playerActorId)
        {
            return DeleteGroupPacket.buildMonsterGroupPacket(playerActorId, groupIndex);
        }

        public override void SendGroupPackets(Session session)
        {
            Meteor.Map.Actors.Player player = session.GetActor();
            if (player == null || player.CurrentArea == null)
                return;
            session.QueuePacket(BuildSpawnPackets(session.id, player.CurrentArea.ZoneId));
        }

        public override void SendInitWorkValues(Session session)
        {
            SynchGroupWorkValuesPacket groupWork = new SynchGroupWorkValuesPacket(groupIndex);
            groupWork.addProperty(this, "partyGroupWork._globalTemp.owner");
            groupWork.setTarget("/_init");

            session.QueuePacket(groupWork.buildPacket(session.id));
        }
    }
}
