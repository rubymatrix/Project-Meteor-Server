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
using System.Net;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using MySql.Data.MySqlClient;
using NLog;

namespace Meteor.Web
{
    // Serves what the retail executables ask for over HTTP: ffxivboot's version check and
    // ffxivlogin's login page, plus account sign-up and the control panel.
    class Program
    {
        public static Logger Log;

        static void Main(string[] args)
        {
            Log = LogManager.GetCurrentClassLogger();
            Log.Info("==================================");
            Log.Info("Project Meteor: Web Server");
            Log.Info("Version: 0.1");
            Log.Info("==================================");

            ConfigConstants.Load();

            // The version check works without the database, so a bad connection is logged
            // but doesn't stop the server.
            Program.Log.Info("Testing DB connection to \"{0}\"... ", ConfigConstants.DATABASE_HOST);
            using (MySqlConnection conn = new MySqlConnection(ConfigConstants.ConnectionString()))
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
                }
            }

            IPAddress bindIp = IPAddress.Parse(ConfigConstants.OPTIONS_BINDIP);
            int patchPort = ConfigConstants.OPTIONS_PATCH_PORT;
            int loginPort = ConfigConstants.OPTIONS_LOGIN_PORT;
            int panelPort = ConfigConstants.OPTIONS_PANEL_PORT;

            WebApplicationBuilder builder = WebApplication.CreateBuilder(args);
            builder.Logging.ClearProviders();
            builder.WebHost.ConfigureKestrel(options =>
            {
                options.AddServerHeader = false;
                options.Listen(bindIp, patchPort);
                options.Listen(bindIp, loginPort);
                options.Listen(bindIp, panelPort);
            });

            WebApplication app = builder.Build();

            app.Use(async (context, next) =>
            {
                await next();
                Log.Info("{0} :{1} {2} {3} -> {4}", context.Connection.RemoteIpAddress,
                    context.Connection.LocalPort, context.Request.Method, context.Request.Path,
                    context.Response.StatusCode);
            });

            // Each port answers only its own routes.
            app.MapGet("/patch/vercheck/ffxiv/win32/release/{repo}/{version}",
                    (HttpContext context, string repo, string version) => VersionCheck.Handle(context, repo, version))
                .RequireHost("*:" + patchPort);

            Log.Info("Listening on {0}: patch {1}, login {2}, panel {3}", bindIp, patchPort, loginPort, panelPort);
            app.Run();
        }
    }
}
