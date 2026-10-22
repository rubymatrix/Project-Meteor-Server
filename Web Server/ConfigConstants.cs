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
using System.Linq;
using System.Net;

using Meteor.Common;

namespace Meteor.Web
{
    class ConfigConstants
    {
        public static String OPTIONS_BINDIP;
        public static int    OPTIONS_PATCH_PORT;
        public static int    OPTIONS_LOGIN_PORT;
        public static int    OPTIONS_PANEL_PORT;

        public static String PATCH_BOOT_VERSION;
        public static String PATCH_GAME_VERSION;
        public static String PATCH_INFO_URL;
        public static String PATCH_DIR;
        public static String PATCH_SIGNING_KEY;
        public static int    TRACKER_PORT;
        public static int    TRACKER_INTERVAL;
        public static int    SEED_PORT;
        public static IPAddress SEED_ADDRESS;

        public static int    SESSION_HOURS;
        public static String SIGNUP_URL;

        public static String DATABASE_HOST;
        public static String DATABASE_PORT;
        public static String DATABASE_NAME;
        public static String DATABASE_USERNAME;
        public static String DATABASE_PASSWORD;

        public static bool Load()
        {
            Program.Log.Info("Loading web_config.ini file");

            if (!File.Exists("./web_config.ini"))
            {
                Program.Log.Error("FILE NOT FOUND!");
                Program.Log.Error("Loading defaults...");
            }

            INIFile configIni = new INIFile("./web_config.ini");

            ConfigConstants.OPTIONS_BINDIP =        configIni.GetValue("General", "server_ip", "0.0.0.0");
            ConfigConstants.OPTIONS_PATCH_PORT =    int.Parse(configIni.GetValue("General", "patch_port", "54996"));
            ConfigConstants.OPTIONS_LOGIN_PORT =    int.Parse(configIni.GetValue("General", "login_port", "80"));
            ConfigConstants.OPTIONS_PANEL_PORT =    int.Parse(configIni.GetValue("General", "panel_port", "8000"));

            ConfigConstants.PATCH_BOOT_VERSION =    configIni.GetValue("Patch", "boot_version", "2010.09.18.0000");
            ConfigConstants.PATCH_GAME_VERSION =    ReleaseVersion(configIni, configIni.GetValue("Patch", "game_version", "2012.09.19.0001"));
            ConfigConstants.PATCH_INFO_URL =        configIni.GetValue("Patch", "info_url", "http://www.example.com/");
            ConfigConstants.PATCH_DIR =             configIni.GetValue("Patch", "patch_dir", "");
            ConfigConstants.PATCH_SIGNING_KEY =     configIni.GetValue("Patch", "signing_key", "");
            ConfigConstants.TRACKER_PORT =          int.Parse(configIni.GetValue("Patch", "tracker_port", "54997"));
            ConfigConstants.TRACKER_INTERVAL =      int.Parse(configIni.GetValue("Patch", "tracker_interval", "300"));
            ConfigConstants.SEED_PORT =             int.Parse(configIni.GetValue("Patch", "seed_port", "54998"));
            ConfigConstants.SEED_ADDRESS =          IPAddress.Parse(configIni.GetValue("Patch", "seed_address", "127.0.0.1"));

            ConfigConstants.SESSION_HOURS =         int.Parse(configIni.GetValue("Login", "session_hours", "24"));
            ConfigConstants.SIGNUP_URL =            configIni.GetValue("Login", "signup_url", "http://127.0.0.1:8000/signup");

            ConfigConstants.DATABASE_HOST =         configIni.GetValue("Database", "host", "");
            ConfigConstants.DATABASE_PORT =         configIni.GetValue("Database", "port", "");
            ConfigConstants.DATABASE_NAME =         configIni.GetValue("Database", "database", "");
            ConfigConstants.DATABASE_USERNAME =     configIni.GetValue("Database", "username", "");
            ConfigConstants.DATABASE_PASSWORD =     configIni.GetValue("Database", "password", "");

            return true;
        }

        // game_version may be a game.ver string or a release name listed under [Releases].
        static String ReleaseVersion(INIFile configIni, String value)
        {
            if (System.Text.RegularExpressions.Regex.IsMatch(value, @"^\d{4}\.\d{2}\.\d{2}\.\d{4}$"))
                return value;
            String version = configIni.GetValue("Releases", value, "");
            if (version == "")
            {
                Program.Log.Error("game_version \"{0}\" is neither a version nor a name under [Releases]", value);
                return value;
            }
            Program.Log.Info("game_version {0} is {1}", value, version);
            return version;
        }

        // Same database arguments as the other servers, so run-servers.sh can pass them to all.
        public static void ApplyLaunchArgs(string[] launchArgs)
        {
            var args = (from arg in launchArgs select arg.ToLower().Trim().TrimStart('-')).ToList();

            for (var i = 0; i + 1 < args.Count; i += 2)
            {
                var arg = args[i];
                var val = args[i + 1];
                var legit = false;

                if (arg == "ip")
                {
                    IPAddress ip;
                    if (IPAddress.TryParse(val, out ip) && (legit = true))
                        OPTIONS_BINDIP = val;
                }
                else if (arg == "user" && (legit = true))
                {
                    DATABASE_USERNAME = val;
                }
                else if (arg == "p" && (legit = true))
                {
                    DATABASE_PASSWORD = val;
                }
                else if (arg == "db" && (legit = true))
                {
                    DATABASE_NAME = val;
                }
                else if (arg == "host" && (legit = true))
                {
                    DATABASE_HOST = val;
                }
                if (!legit)
                {
                    Program.Log.Error("Invalid parameter <{0}> for argument: <--{1}> or argument doesnt exist!", val, arg);
                }
            }
        }

        public static String ConnectionString()
        {
            return String.Format("Server={0}; Port={1}; Database={2}; UID={3}; Password={4}", DATABASE_HOST, DATABASE_PORT, DATABASE_NAME, DATABASE_USERNAME, DATABASE_PASSWORD);
        }
    }
}
