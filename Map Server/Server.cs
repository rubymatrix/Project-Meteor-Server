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
using System.Net;
using System.Net.Sockets;
using Meteor.Map.DataObjects;

using Meteor.Common;
using Meteor.Map.Actors;
using System.Linq;

namespace Meteor.Map
{
    class Server
    {
        public const int FFXIV_MAP_PORT = 54992;
        public const int BUFFER_SIZE = 0xFFFF; //Max basepacket size is 0xFFFF
        public const int BACKLOG = 100;

        public const string STATIC_ACTORS_PATH = "./staticactors.bin";

        private static Server _Self;

        private Socket ServerSocket;

        private Dictionary<uint, Session> SessionList = new Dictionary<uint, Session>();        
     
        private static CommandProcessor CommandProcessor = new CommandProcessor();
        private static ZoneConnection WorldConnection = new ZoneConnection();
        private static WorldManager WorldManager;
        private static Dictionary<uint, ItemData> GamedataItems;
        private static Dictionary<uint, List<QuestRewardSlot>> GamedataQuestRewards;
        private static Dictionary<int, sbyte[]> GamedataItemCompatibility;
        private static Dictionary<int, MateriaData> GamedataMateria;
        private static Dictionary<uint, GuildleveData> GamedataGuildleves;
        private static Dictionary<uint, PassiveGuildleveData> GamedataPassiveGL;
        private static RecipeResolver GamedataRecipeResolver;
        private static Dictionary<uint, QuestGameData> GamedataQuests;
        private static StaticActors StaticActors;

        private PacketProcessor mProcessor;        

        public Server()
        {
            _Self = this;
        }
        
        public bool StartServer()
        {           
            StaticActors = new StaticActors(STATIC_ACTORS_PATH);

            Program.Log.Info("Loading gamedata...");
            GamedataItems = Database.GetItemGamedata();
            Program.Log.Info("Loaded {0} items.", GamedataItems.Count);
            GamedataQuestRewards = Database.GetQuestRewardGamedata();
            Program.Log.Info("Loaded rewards for {0} quests.", GamedataQuestRewards.Count);
            GamedataItemCompatibility = Database.GetItemCompatibilityGamedata();
            Program.Log.Info("Loaded {0} item compatibility keys.", GamedataItemCompatibility.Count);
            GamedataMateria = Database.GetMateriaGamedata();
            Program.Log.Info("Loaded {0} materia types.", GamedataMateria.Count);
            ModelSize.Load(Database.GetModelSizeGamedata());
            Program.Log.Info("Loaded {0} model sizes.", ModelSize.Count);
            GamedataGuildleves = Database.GetGuildleveGamedata();
            Program.Log.Info("Loaded {0} guildleves.", GamedataGuildleves.Count);
            GamedataQuests = Database.GetQuestGamedata();
            int scripted = 0;
            foreach (QuestGameData quest in GamedataQuests.Values)
            {
                if (quest.ClassName.Length < 3)
                    continue;
                string path = ConfigConstants.OPTIONS_SCRIPTPATH + String.Format(lua.LuaEngine.FILEPATH_QUEST, quest.ClassName.Substring(0, 3), quest.ClassName);
                quest.HasScript = System.IO.File.Exists(path);
                if (quest.HasScript)
                    scripted++;
            }
            Program.Log.Info("Loaded {0} quests ({1} with scripts).", GamedataQuests.Count, scripted);
            GamedataPassiveGL = Database.GetPassiveGuildleveGamedata();
            Program.Log.Info("Loaded {0} local guildleves.", GamedataPassiveGL.Count);
            GamedataRecipeResolver = RecipeResolver.Init();
            Program.Log.Info("Loaded {0} crafting recipes.", GamedataRecipeResolver.GetNumRecipes());

            WorldManager = new WorldManager(this);
            WorldManager.LoadZoneList();
            WorldManager.LoadNavMeshes();
            WorldManager.LoadSeamlessBoundryList();
            WorldManager.LoadActorClasses();
            WorldManager.LoadENPCs();
            WorldManager.LoadBattleNpcs();
            WorldManager.LoadStatusEffects();
            WorldManager.LoadBattleNpcDropLists();
            WorldManager.LoadBattleCommands();
            WorldManager.LoadBattleTraits();
            WorldManager.SpawnAllActors();
            WorldManager.StartContent();
            WorldManager.StartZoneThread();

            IPEndPoint serverEndPoint = new IPEndPoint(IPAddress.Parse(ConfigConstants.OPTIONS_BINDIP), int.Parse(ConfigConstants.OPTIONS_PORT));

            try
            {
                ServerSocket = new Socket(serverEndPoint.Address.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
            }
            catch (Exception e)
            {
                throw new ApplicationException("Could not Create socket, check to make sure not duplicating port", e);
            }
            try
            {
                ServerSocket.Bind(serverEndPoint);
                ServerSocket.Listen(BACKLOG);
            }
            catch (Exception e)
            {
                throw new ApplicationException("Error occured while binding socket, check inner exception", e);
            }
            try
            {
                ServerSocket.BeginAccept(new AsyncCallback(AcceptCallback), ServerSocket);
            }
            catch (Exception e)
            {
                throw new ApplicationException("Error occured starting listeners, check inner exception", e);
            }

            Console.ForegroundColor = ConsoleColor.White;
            Program.Log.Info("Map Server has started @ {0}:{1}", (ServerSocket.LocalEndPoint as IPEndPoint).Address, (ServerSocket.LocalEndPoint as IPEndPoint).Port);
            Console.ForegroundColor = ConsoleColor.Gray;

            mProcessor = new PacketProcessor(this);

            //mGameThread = new Thread(new ThreadStart(mProcessor.update));
            //mGameThread.Start();
            return true;
        }

        #region Session Handling

        public Session AddSession(uint id)
        {
            if (SessionList.ContainsKey(id))
            {
                SessionList[id].ClearInstance();
                return SessionList[id];
            }

            Session session = new Session(id);
            SessionList.Add(id, session);
            return session;
        }

        public void RemoveSession(uint id)
        {
            if (SessionList.ContainsKey(id))
            {
                SessionList.Remove(id);                
            }
        }

        public Session GetSession(uint id)
        {
            if (SessionList.ContainsKey(id))
                return SessionList[id];
            else
                return null;
        }

        public Session GetSession(string name)
        {
            foreach (Session s in SessionList.Values)
            {
                if (s.GetActor().DisplayName.ToLower().Equals(name.ToLower()))
                    return s;
            }
            return null;
        }

        public Dictionary<uint, Session> GetSessionList()
        {
            return SessionList;
        }

        #endregion

        #region Socket Handling
        private void AcceptCallback(IAsyncResult result)
        {
            ZoneConnection conn = null;
            Socket socket = (System.Net.Sockets.Socket)result.AsyncState;

            try
            {

                conn = new ZoneConnection();
                conn.socket = socket.EndAccept(result);
                conn.buffer = new byte[BUFFER_SIZE];

                WorldConnection = conn;
                
                Program.Log.Info("Connection {0}:{1} has connected.", (conn.socket.RemoteEndPoint as IPEndPoint).Address, (conn.socket.RemoteEndPoint as IPEndPoint).Port);
                //Queue recieving of data from the connection
                conn.socket.BeginReceive(conn.buffer, 0, conn.buffer.Length, SocketFlags.None, new AsyncCallback(ReceiveCallback), conn);
                //Queue the accept of the next incomming connection
                ServerSocket.BeginAccept(new AsyncCallback(AcceptCallback), ServerSocket);
            }
            catch (SocketException)
            {
                if (conn != null)
                {
                    WorldConnection = null;
                }
                ServerSocket.BeginAccept(new AsyncCallback(AcceptCallback), ServerSocket);
            }
            catch (Exception)
            {
                if (conn != null)
                {
                    WorldConnection = null;
                }
                ServerSocket.BeginAccept(new AsyncCallback(AcceptCallback), ServerSocket);
            }
        }
        
        // Receive Callback. Reads in incoming data, converting them to base packets. Base packets are sent to be parsed. If not enough data at the end to build a basepacket, move to the beginning and prepend.
        private void ReceiveCallback(IAsyncResult result)
        {
            ZoneConnection conn = (ZoneConnection)result.AsyncState;

            //Check if disconnected
            if ((conn.socket.Poll(1, SelectMode.SelectRead) && conn.socket.Available == 0))
            {
                WorldConnection = null;
                Program.Log.Info("Disconnected from world server!");
            }

            try
            {
                int bytesRead = conn.socket.EndReceive(result);

                bytesRead += conn.lastPartialSize;

                if (bytesRead >= 0)
                {
                    int offset = 0;

                    //Build packets until can no longer or out of data
                    while (true)
                    {
                        SubPacket subPacket = SubPacket.CreatePacket(ref offset, conn.buffer, bytesRead);

                        //If can't build packet, break, else process another
                        if (subPacket == null)
                            break;
                        else
                            mProcessor.ProcessPacket(conn, subPacket);
                    }

                    //Not all bytes consumed, transfer leftover to beginning
                    if (offset < bytesRead)
                        Array.Copy(conn.buffer, offset, conn.buffer, 0, bytesRead - offset);

                    conn.lastPartialSize = bytesRead - offset;

                    //Build any queued subpackets into basepackets and send
                    conn.FlushQueuedSendPackets();

                    if (offset < bytesRead)
                        //Need offset since not all bytes consumed
                        conn.socket.BeginReceive(conn.buffer, bytesRead - offset, conn.buffer.Length - (bytesRead - offset), SocketFlags.None, new AsyncCallback(ReceiveCallback), conn);
                    else
                        //All bytes consumed, full buffer available
                        conn.socket.BeginReceive(conn.buffer, 0, conn.buffer.Length, SocketFlags.None, new AsyncCallback(ReceiveCallback), conn);
                }
                else
                {
                    WorldConnection = null;
                    Program.Log.Info("Disconnected from world server!");
                }
            }
            catch (SocketException)
            {
                if (conn.socket != null)
                {
                    WorldConnection = null;
                    Program.Log.Info("Disconnected from world server!");
                }
            }
        }

        #endregion

        public static ZoneConnection GetWorldConnection()
        {
            return WorldConnection;
        }

        public static Server GetServer()
        {
            return _Self;
        }

        public static CommandProcessor GetCommandProcessor()
        {
            return CommandProcessor;
        }        

        public static WorldManager GetWorldManager()
        {
            return WorldManager;
        }
        
        public static Dictionary<uint, ItemData> GetGamedataItems()
        {
            return GamedataItems;
        }

        public static Actor GetStaticActors(uint id)
        {
            return StaticActors.GetActor(id);
        }

        public static Actor GetStaticActors(string name)
        {
            return StaticActors.FindStaticActor(name);
        }

        public static List<QuestRewardSlot> GetQuestRewards(uint questId)
        {
            if (GamedataQuestRewards != null && GamedataQuestRewards.TryGetValue(questId, out List<QuestRewardSlot> slots))
                return slots;
            return new List<QuestRewardSlot>();
        }

        public static ItemData GetItemGamedata(uint id)
        {
            if (GamedataItems.ContainsKey(id))
                return GamedataItems[id];
            else
                return null;
        }

        // -1 when the key isn't loaded.
        public static int GetItemCompatibility(int key, int classId)
        {
            if (GamedataItemCompatibility == null || !GamedataItemCompatibility.TryGetValue(key, out sbyte[] values))
                return -1;
            return classId >= 0 && classId < values.Length ? values[classId] : 0;
        }

        public static MateriaData GetMateriaGamedata(int type)
        {
            if (GamedataMateria != null && GamedataMateria.TryGetValue(type, out MateriaData materia))
                return materia;
            return null;
        }

        public static GuildleveData GetGuildleveGamedata(uint id)
        {
            if (GamedataGuildleves.ContainsKey(id))
                return GamedataGuildleves[id];
            else
                return null;
        }

        public static PassiveGuildleveData GetPassiveGLGamedata(uint id)
        {
            if (GamedataPassiveGL.ContainsKey(id))
                return GamedataPassiveGL[id];
            else
                return null;
        }

        public static QuestGameData GetQuestGamedata(uint id)
        {
            if (GamedataQuests.ContainsKey(id))
                return GamedataQuests[id];
            else
                return null;
        }


        public static IEnumerable<QuestGameData> GetAllQuestGamedata()
        {
            return GamedataQuests.Values;
        }

        public static QuestGameData[] GetQuestGamedataByMaxLvl(int lvl, bool all = false)
        {
            if (all)
                return GamedataQuests.Values.Where(quest => quest.MinLevel > 0 && quest.MinLevel <= lvl).ToArray();
            else
                return GamedataQuests.Values.Where(quest => quest.MinLevel > 0 && quest.MinLevel == lvl).ToArray();
        }

        public static QuestGameData[] GetQuestGamedataByPrerequisite(uint questId)
        {
            return GamedataQuests.Values.Where(quest => quest.PrerequisiteQuest == questId).ToArray();
        }

        public static QuestGameData[] GetQuestGamedataAllPrerequisite()
        {
            return GamedataQuests.Values.Where(quest => quest.PrerequisiteQuest != 0).ToArray();
        }

        public static QuestGameData[] GetQuestGamedataAllGCRanked()
        {
            return GamedataQuests.Values.Where(quest => quest.MinGCRank != 0).ToArray();
        }

        //public static QuestData[] GetQuestGamedataByGCRank(int gc, int rank, bool all = false)
        //{
        // return GamedataQuests.Values.Where(quest => all ? quest.MinLevel == lvl : quest.MinLevel <= lvl).ToArray();
        //}

        public static RecipeResolver ResolveRecipe()
        {
            return GamedataRecipeResolver;
        }
    }
}
