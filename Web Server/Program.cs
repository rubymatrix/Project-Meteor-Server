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
using System.IO;
using System.Net;
using System.Threading.Tasks;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Meteor.Web.Patching;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
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
            ConfigConstants.ApplyLaunchArgs(args);
            PatchCatalog.Load(Path.Combine(AppContext.BaseDirectory, "web_patches.json"),
                ConfigConstants.PATCH_BOOT_VERSION, ConfigConstants.PATCH_GAME_VERSION);
            PatchStore.Load(ConfigConstants.PATCH_DIR, ConfigConstants.PATCH_SIGNING_KEY);

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

            WebApplicationBuilder builder = WebApplication.CreateBuilder();
            builder.Logging.ClearProviders();
            builder.WebHost.ConfigureKestrel(options =>
            {
                options.AddServerHeader = false;
                options.Listen(bindIp, patchPort);
                options.Listen(bindIp, loginPort);
                options.Listen(bindIp, panelPort);
                if (PatchStore.Enabled)
                    options.Listen(bindIp, ConfigConstants.TRACKER_PORT);
            });
            if (PatchStore.Enabled)
                builder.Services.AddHostedService<PatchSeed>();

            WebApplication app = builder.Build();

            app.Use(async (context, next) =>
            {
                await next();
                Log.Info("{0} :{1} {2} {3} -> {4}", context.Connection.RemoteIpAddress,
                    context.Connection.LocalPort, context.Request.Method, context.Request.Path,
                    context.Response.StatusCode);
            });

            // Static files, one folder per port. Login page assets (img/...) sit under
            // /account/content/ beside the page.
            string webRoot = Path.Combine(AppContext.BaseDirectory, "wwwroot");
            ServeStaticFiles(app, loginPort, Path.Combine(webRoot, "login"));
            ServeStaticFiles(app, panelPort, Path.Combine(webRoot, "panel"));

            // Each port answers only its own routes.
            app.MapGet("/patch/vercheck/ffxiv/win32/release/{repo}/{version}",
                    (HttpContext context, string repo, string version) => VersionCheck.Handle(context, repo, version))
                .RequireHost("*:" + patchPort);

            if (PatchStore.Enabled)
                app.MapGet("/announce", Tracker.Announce).RequireHost("*:" + ConfigConstants.TRACKER_PORT);

            app.MapGet("/account/content/ffxivlogin", LoginPage.Get).RequireHost("*:" + loginPort);
            app.MapPost("/account/content/ffxivlogin", (Func<HttpContext, Task<IResult>>)LoginPage.Post).RequireHost("*:" + loginPort);

            app.MapGet("/signup", SignupPage.Get).RequireHost("*:" + panelPort);
            app.MapPost("/signup", (Func<HttpContext, Task<IResult>>)SignupPage.Post).RequireHost("*:" + panelPort);
            app.MapGet("/signup/done", SignupPage.Done).RequireHost("*:" + panelPort);

            app.MapGet("/", () => Results.Redirect("/panel")).RequireHost("*:" + panelPort);
            app.MapGet("/login", ControlPanel.LoginForm).RequireHost("*:" + panelPort);
            app.MapPost("/login", (Func<HttpContext, Task<IResult>>)ControlPanel.Login).RequireHost("*:" + panelPort);
            app.MapGet("/logout", ControlPanel.Logout).RequireHost("*:" + panelPort);
            app.MapGet("/panel", ControlPanel.Characters).RequireHost("*:" + panelPort);
            app.MapGet("/panel/character/{id:int}", ControlPanel.Character).RequireHost("*:" + panelPort);

            Log.Info("Listening on {0}: patch {1}, login {2}, panel {3}", bindIp, patchPort, loginPort, panelPort);
            app.Run();
        }

        static void ServeStaticFiles(WebApplication app, int port, string folder)
        {
            PhysicalFileProvider files = new PhysicalFileProvider(folder);
            app.UseWhen(context => context.Connection.LocalPort == port,
                branch => branch.UseStaticFiles(new StaticFileOptions { FileProvider = files }));
        }
    }
}
