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
using Meteor.Map.actors.director;
using Meteor.Map.actors.group.Work;
using Meteor.Map.Actors;
using Meteor.Map.DataObjects;
using Meteor.Map.packets.send.group;
using Meteor.Map.packets.send.groups;
using System.Collections.Generic;

namespace Meteor.Map.actors.group
{
    class ContentGroup : Group
    {
        private const ushort TEXT_BOUND_BY_DUTY = 50011;
        private const ushort TEXT_UNBOUND_FROM_DUTY = 50012;

        public ContentGroupWork contentGroupWork = new ContentGroupWork();
        private Director director;
        private List<uint> members = new List<uint>();
        private bool isStarted = false;
        private bool isBoundByDuty = false;

        public ContentGroup(ulong groupIndex, Director director, uint[] initialMembers) : base(groupIndex)
        {
            if (initialMembers != null)
            {
                for (int i = 0; i < initialMembers.Length; i++)
                {
                    Session s = Server.GetServer().GetSession(initialMembers[i]);
                    if (s != null)
                        s.GetActor().SetCurrentContentGroup(this);

                    members.Add(initialMembers[i]);
                }
            }

            this.director = director;
            // Actor id in the high word plus the 0xB36F92 member tag (as Party sends for its owner); with a
            // 0 low word the client does not resolve the group's director.
            contentGroupWork._globalTemp.director = ((ulong)director.Id << 32) | 0xB36F92;
        }

        public void Start()
        {
            isStarted = true;
            
            SendGroupPacketsAll(members);

            // Guildleves run content groups too; only a content area is a duty.
            if (director.CurrentArea is PrivateAreaContent)
            {
                isBoundByDuty = true;
                SendToPlayers(TEXT_BOUND_BY_DUTY);
            }
        }

        private void SendToPlayers(ushort textId)
        {
            foreach (uint memberId in members)
                SendToPlayer(memberId, textId);
        }

        private void SendToPlayer(uint memberId, ushort textId)
        {
            Session s = Server.GetServer().GetSession(memberId);
            if (s != null)
                s.GetActor().SendGameMessage(Server.GetWorldManager().GetActor(), textId, 0x20);
        }

        public void AddMember(Actor actor)
        {
            if (actor == null)
                return;
            
            if(!members.Contains(actor.Id))
            {
                members.Add(actor.Id);
                if (isBoundByDuty)
                    SendToPlayer(actor.Id, TEXT_BOUND_BY_DUTY);
            }

            if (actor is Character)            
                ((Character)actor).SetCurrentContentGroup(this);

            if (isStarted)
                SendGroupPacketsAll(members);
        }
        
        public void RemoveMember(uint memberId)
        {
            if (isBoundByDuty && members.Contains(memberId))
                SendToPlayer(memberId, TEXT_UNBOUND_FROM_DUTY);
            members.Remove(memberId);
            if (isStarted)
                SendGroupPacketsAll(members);
            CheckDestroy();
        }

        public override List<GroupMember> BuildMemberList(uint id)
        {
            List<GroupMember> groupMembers = new List<GroupMember>();
            groupMembers.Add(new GroupMember(id, -1, 0, false, true, ""));
            foreach (uint charaId in members)
            {
                if (charaId != id)
                    groupMembers.Add(new GroupMember(charaId, -1, 0, false, true, ""));
            }
            return groupMembers;
        }

        public override int GetMemberCount()
        {
            return members.Count;
        }

        public override void SendInitWorkValues(Session session)
        {
            SynchGroupWorkValuesPacket groupWork = new SynchGroupWorkValuesPacket(groupIndex);
            groupWork.addProperty(this, "contentGroupWork._globalTemp.director");
            groupWork.addByte(Utils.MurmurHash2("contentGroupWork.property[0]", 0), 1);
            groupWork.setTarget("/_init");

            SubPacket test = groupWork.buildPacket(session.id);
            test.DebugPrintSubPacket();
            session.QueuePacket(test);
        }

        public override void SendGroupPackets(Session session)
        {
            ulong time = Utils.MilisUnixTimeStampUTC();
            List<GroupMember> members = BuildMemberList(session.id);

            session.QueuePacket(GroupHeaderPacket.buildPacket(session.id, session.GetActor().CurrentArea.ZoneId, time, this));
            session.QueuePacket(GroupMembersBeginPacket.buildPacket(session.id, session.GetActor().CurrentArea.ZoneId, time, this));

            int currentIndex = 0;

            while (true)
            {
                if (GetMemberCount() - currentIndex >= 64)
                    session.QueuePacket(ContentMembersX64Packet.buildPacket(session.id, session.GetActor().CurrentArea.ZoneId, time, members, ref currentIndex));
                else if (GetMemberCount() - currentIndex >= 32)
                    session.QueuePacket(ContentMembersX32Packet.buildPacket(session.id, session.GetActor().CurrentArea.ZoneId, time, members, ref currentIndex));
                else if (GetMemberCount() - currentIndex >= 16)
                    session.QueuePacket(ContentMembersX16Packet.buildPacket(session.id, session.GetActor().CurrentArea.ZoneId, time, members, ref currentIndex));
                else if (GetMemberCount() - currentIndex > 0)
                    session.QueuePacket(ContentMembersX08Packet.buildPacket(session.id, session.GetActor().CurrentArea.ZoneId, time, members, ref currentIndex));
                else
                    break;
            }

            session.QueuePacket(GroupMembersEndPacket.buildPacket(session.id, session.GetActor().CurrentArea.ZoneId, time, this));
        }

        public override uint GetTypeId()
        {
            return Group.ContentGroup_SimpleContentGroup24B;
        }


        public void SendAll()
        {
            SendGroupPacketsAll(members);            
        }

        public void DeleteGroup()
        {
            if (isBoundByDuty)
            {
                isBoundByDuty = false;
                SendToPlayers(TEXT_UNBOUND_FROM_DUTY);
            }
            SendDeletePackets(members);
            for (int i = 0; i < members.Count; i++)
            {
                Session s = Server.GetServer().GetSession(members[i]);
                if (s != null)
                    s.GetActor().SetCurrentContentGroup(null);
                Actor a = director.CurrentArea.FindActorInArea(members[i]);
                if (a is Npc)
                    ((Npc)a).Despawn();
                members.Remove(members[i]);
                i--;
            }
            Server.GetWorldManager().DeleteContentGroup(groupIndex);
        }

        public void CheckDestroy()
        {
            bool foundSession = false;
            foreach (uint memberId in members)
            {
                Session session = Server.GetServer().GetSession(memberId);
                if (session != null)
                {
                    foundSession = true;
                    break;
                }
            }

            if (!foundSession)
                DeleteGroup();
        }

        public List<uint> GetMembers()
        {
            return members;
        }
    }
}
