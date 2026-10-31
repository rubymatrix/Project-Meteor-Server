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
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using Meteor.Common;
using MySql.Data.MySqlClient;
using NLog;

namespace Meteor.Map
{
    class Program
    {
        public static Logger Log = LogManager.GetLogger("Meteor.Map.Program");
        public static Server Server;
        public static Random Random = new Random();
        public static DateTime LastTick = DateTime.Now;
        public static DateTime Tick = DateTime.Now;

        private static readonly TimeSpan POSITION_SAVE_INTERVAL = TimeSpan.FromMinutes(2);
        private static Timer positionSaveTimer;
        private static PosixSignalRegistration[] stopSignals;
        private static int savedBeforeExit;

        private static void SaveBeforeExit()
        {
            if (Interlocked.Exchange(ref savedBeforeExit, 1) == 0)
                Server?.SaveAllPlayers(false);
        }

        static void Main(string[] args)
        {          
            // set up logging
            Log = LogManager.GetCurrentClassLogger();
#if DEBUG
            TextWriterTraceListener myWriter = new TextWriterTraceListener(System.Console.Out);
            Trace.Listeners.Add(myWriter); // Debug and Trace share listeners on modern .NET
#endif
            bool startServer = true;

            Log.Info("==================================");
            Log.Info("Project Meteor: Map Server");
            Log.Info("Version: 0.1");
            Log.Info("==================================");

            //Load Config
            ConfigConstants.Load();
            ConfigConstants.ApplyLaunchArgs(args);

            //Test DB Connection
            Program.Log.Info("Testing DB connection... ");
            using (MySqlConnection conn = new MySqlConnection(String.Format("Server={0}; Port={1}; Database={2}; UID={3}; Password={4}", ConfigConstants.DATABASE_HOST, ConfigConstants.DATABASE_PORT, ConfigConstants.DATABASE_NAME, ConfigConstants.DATABASE_USERNAME, ConfigConstants.DATABASE_PASSWORD)))
            {
                try
                {
                    conn.Open();
                    conn.Close();

                    Program.Log.Info("Connection ok.");
                }
                catch (MySqlException e)
                {
                    Program.Log.Error(e.ToString());
                    startServer = false; 
                }
            }
            
            //Start server if A-OK
            if (startServer)
            {
                Random = new Random();
                Server = new Server();
                Tick = DateTime.Now;
                Server.StartServer();

                // meteorctl stops the map with SIGTERM: save everyone first. Ctrl-C does the same.
                AppDomain.CurrentDomain.ProcessExit += (sender, e) => SaveBeforeExit();
                stopSignals = new[]
                {
                    PosixSignalRegistration.Create(PosixSignal.SIGTERM, ctx => SaveBeforeExit()),
                    PosixSignalRegistration.Create(PosixSignal.SIGINT, ctx => SaveBeforeExit()),
                };
                positionSaveTimer = new Timer(_ => Server.SaveAllPlayers(true), null, POSITION_SAVE_INTERVAL, POSITION_SAVE_INTERVAL);

                while (startServer)
                {
                    String input = Console.ReadLine();
                    if (input == null) // stdin closed (service/container): keep running without the console
                        System.Threading.Thread.Sleep(System.Threading.Timeout.Infinite);
                    Log.Info("[Console Input] " + input);
                    Server.GetCommandProcessor().DoCommand(input, null);
                }
            }

            Program.Log.Info("Press any key to continue...");
            if (!Console.IsInputRedirected) // no console when run as a service or in a container
                Console.ReadKey();
        }

    
    }
}
