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

using Meteor.Map.Actors;
using Meteor.Map.packets.send.actor;
using System.Collections.Generic;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.Actors.QuestNS;
using static Meteor.Map.Actors.QuestNS.QuestState;

namespace Meteor.Map.DataObjects
{
    class Session
    {
        public uint id = 0;
        Player playerActor;
        public List<Actor> actorInstanceList = new List<Actor>();
        public uint languageCode = 1;        
        private uint lastPingPacket = Utils.UnixTimeStampUTC();

        public bool isUpdatesLocked = true;

        public string errorMessage = "";

        public Session(uint sessionId)
        {
            this.id = sessionId;
            playerActor = new Player(this, sessionId);
        }

        public void QueuePacket(List<SubPacket> packets)
        {
            foreach (SubPacket s in packets)
                QueuePacket(s);
        }

        public void QueuePacket(SubPacket subPacket)
        {
            ////if (subPacket.gameMessage.opcode != 1)
                //subPacket.DebugPrintSubPacket();
            subPacket.SetTargetId(id);
            Server.GetWorldConnection().QueuePacket(subPacket);
        }

        public Player GetActor()
        {
            return playerActor;
        }

        public void Ping()
        {
            lastPingPacket = Utils.UnixTimeStampUTC();
        }

        public bool CheckIfDCing()
        {
            uint currentTime = Utils.UnixTimeStampUTC();
            if (currentTime - lastPingPacket >= 5000) //Show D/C flag
                playerActor.SetDCFlag(true);
            else if (currentTime - lastPingPacket >= 30000) //DCed
                return true;
            else
                playerActor.SetDCFlag(false);
            return false;
        }

        public void UpdatePlayerActorPosition(float x, float y, float z, float rot, ushort moveState)
        {
            if (isUpdatesLocked)
                return;

            if (playerActor.positionX == x && playerActor.positionY == y && playerActor.positionZ == z && playerActor.rotation == rot)
                return;

            /*
            playerActor.oldPositionX = playerActor.positionX;
            playerActor.oldPositionY = playerActor.positionY;
            playerActor.oldPositionZ = playerActor.positionZ;
            playerActor.oldRotation = playerActor.rotation;
            
            playerActor.positionX = x;
            playerActor.positionY = y;
            playerActor.positionZ = z;
            */
            playerActor.rotation = rot;
            playerActor.moveState = moveState;

            //GetActor().GetZone().UpdateActorPosition(GetActor());
            playerActor.QueuePositionUpdate(new Vector3(x,y,z));
        }

        // Ids of the actors this client has spawned, for broadcasts from the zone thread. Its own lock is
        // never held while taking another, so it can't deadlock against the zone's actor locks.
        private readonly HashSet<uint> spawnedIds = new HashSet<uint>();

        public bool HasSpawned(Actor actor)
        {
            lock (spawnedIds)
                return spawnedIds.Contains(actor.Id);
        }

        private void SetSpawned(Actor actor, bool spawned)
        {
            lock (spawnedIds)
            {
                if (spawned)
                    spawnedIds.Add(actor.Id);
                else
                    spawnedIds.Remove(actor.Id);
            }
        }

        public void UpdateInstance(List<Actor> list, bool force = false)
        {
            if (isUpdatesLocked && !force)
                return;

            for (int i = actorInstanceList.Count - 1; i >= 0; i--)
            {
                //Retainer Instance
                if (actorInstanceList[i] is Retainer && playerActor.currentSpawnedRetainer == null)
                {
                    QueuePacket(RemoveActorPacket.BuildPacket(actorInstanceList[i].Id));
                    SetSpawned(actorInstanceList[i], false);
                    actorInstanceList.RemoveAt(i);
                }
                else if (!list.Contains(actorInstanceList[i]) && !(actorInstanceList[i] is Retainer))
                {
                    QueuePacket(RemoveActorPacket.BuildPacket(actorInstanceList[i].Id));
                    SetSpawned(actorInstanceList[i], false);
                    actorInstanceList.RemoveAt(i);
                }
            }

            //Retainer Instance
            if (playerActor.currentSpawnedRetainer != null && !playerActor.sentRetainerSpawn)
            {
                Actor actor = playerActor.currentSpawnedRetainer;
                QueuePacket(actor.GetSpawnPackets(playerActor, 1));
                QueuePacket(actor.GetInitPackets());
                QueuePacket(actor.GetSetEventStatusPackets());
                actorInstanceList.Add(actor);
                SetSpawned(actor, true);
                ((Npc)actor).DoOnActorSpawn(playerActor);
                playerActor.sentRetainerSpawn = true;
            }

            //Add new actors or move
            for (int i = 0; i < list.Count; i++)
            {
                Actor actor = list[i];

                if (actor.Id == playerActor.Id)
                    continue;

                if (actorInstanceList.Contains(actor))
                {

                }
                else
                {
                    QueuePacket(actor.GetSpawnPackets(playerActor, 1));
                    QueuePacket(actor.GetInitPackets());
                    QueuePacket(actor.GetSetEventStatusPackets());

                    if (actor is Npc npc)
                    {
                        npc.DoOnActorSpawn(playerActor);

                        // Quest Instance related
                        Quest[] quests = playerActor.GetQuestsForNpc(npc);
                        if (quests.Length != 0)
                        {
                            QuestENpc questInstance = quests[0].GetQuestState().GetENpc(npc.GetActorClassId());
                            QueuePacket(npc.GetSetEventStatusPackets(questInstance.isTalkEnabled, questInstance.isEmoteEnabled, questInstance.isPushEnabled));
                            QueuePacket(SetActorQuestGraphicPacket.BuildPacket(npc.Id, questInstance.questFlagType));                            
                        }
                    }


                    actorInstanceList.Add(actor);
                    SetSpawned(actor, true);
                }
            }
        }

        public void UpdateQuestNpcInInstance(QuestENpc questInstance, bool clearInstance = false)
        {
            LockUpdates(true);
            Actor actor = actorInstanceList.Find(x => x is Npc npc && npc.GetActorClassId().Equals(questInstance.actorClassId));
            if (actor != null)
            {
                if (!clearInstance)
                {
                    QueuePacket(actor.GetSetEventStatusPackets(questInstance.isTalkEnabled, questInstance.isEmoteEnabled, questInstance.isPushEnabled));
                    QueuePacket(SetActorQuestGraphicPacket.BuildPacket(actor.Id, questInstance.questFlagType));
                }
                else
                {
                    QueuePacket(actor.GetSetEventStatusPackets());
                    QueuePacket(SetActorQuestGraphicPacket.BuildPacket(actor.Id, 0));
                }
            }
            LockUpdates(false);
        }

        public void ClearInstance()
        {
            actorInstanceList.Clear();
            lock (spawnedIds)
                spawnedIds.Clear();
        }

        public void LockUpdates(bool f)
        {
            isUpdatesLocked = f;
        }
    }
}
