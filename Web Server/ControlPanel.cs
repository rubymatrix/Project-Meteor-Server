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
using System.Text;
using System.Threading.Tasks;

using Microsoft.AspNetCore.Http;
using MySql.Data.MySqlClient;

namespace Meteor.Web
{
    // Account control panel on the panel port: sign in, list characters, view a character sheet.
    // The panel cookie holds the account's game session id, so signing in here also refreshes the
    // session the game uses, and signing out only drops the cookie.
    static class ControlPanel
    {
        const string SessionCookie = "sessionId";

        static readonly Dictionary<long, string> Tribes = new Dictionary<long, string>
        {
            { 1, "Hyur Midlander Male" }, { 2, "Hyur Midlander Female" }, { 3, "Hyur Highlander Male" },
            { 4, "Elezen Wildwood Male" }, { 5, "Elezen Wildwood Female" }, { 6, "Elezen Duskwight Male" },
            { 7, "Elezen Duskwight Female" }, { 8, "Lalafell Plainsfolk Male" }, { 9, "Lalafell Plainsfolk Female" },
            { 10, "Lalafell Dunesfolk Male" }, { 11, "Lalafell Dunesfolk Female" }, { 12, "Miqo'te Seeker of the Sun Female" },
            { 13, "Miqo'te Keeper of the Moon Female" }, { 14, "Roegadyn Sea Wolf Male" }, { 15, "Roegadyn Hellsguard Male" },
        };

        static readonly Dictionary<long, string> Guardians = new Dictionary<long, string>
        {
            { 1, "Halone, the Fury" }, { 2, "Menphina, the Lover" }, { 3, "Thaliak, the Scholar" },
            { 4, "Nymeia, the Spinner" }, { 5, "Llymlaen, the Navigator" }, { 6, "Oschon, the Wanderer" },
            { 7, "Byregot, the Builder" }, { 8, "Rhalgr, the Destroyer" }, { 9, "Azeyma, the Warden" },
            { 10, "Nald'thal, the Traders" }, { 11, "Nophica, the Matron" }, { 12, "Althyk, the Keeper" },
        };

        static readonly Dictionary<long, string> Allegiances = new Dictionary<long, string>
        {
            { 1, "Limsa Lominsa" }, { 2, "Gridania" }, { 3, "Ul'dah" },
        };

        static readonly Dictionary<long, string> GrandCompanies = new Dictionary<long, string>
        {
            { 0, "None" }, { 1, "Maelstrom" }, { 2, "Order of the Twin Adder" }, { 3, "Immortal Flames" },
        };

        static readonly Dictionary<long, string> Heights = new Dictionary<long, string>
        {
            { 0, "Shortest" }, { 1, "Short" }, { 2, "Average" }, { 3, "Tall" }, { 4, "Tallest" },
        };

        static readonly Dictionary<long, string> YesNo = new Dictionary<long, string>
        {
            { 0, "No" }, { 1, "Yes" },
        };

        static readonly string[][] ClassColumns =
        {
            new[] { "GLA", "gla" }, new[] { "PUG", "pug" }, new[] { "MRD", "mrd" }, new[] { "LNC", "lnc" },
            new[] { "ARC", "arc" }, new[] { "CNJ", "cnj" }, new[] { "THM", "thm" },
            new[] { "CRP", "crp" }, new[] { "BSM", "bsm" }, new[] { "ARM", "arm" }, new[] { "GSM", "gsm" },
            new[] { "LTW", "ltw" }, new[] { "WVR", "wvr" }, new[] { "ALC", "alc" }, new[] { "CUL", "cul" },
            new[] { "MIN", "min" }, new[] { "BTN", "btn" }, new[] { "FSH", "fsh" },
        };

        static readonly string[][] GearColumns =
        {
            new[] { "Main Hand", "mainhand" }, new[] { "Off Hand", "offhand" }, new[] { "Head", "head" },
            new[] { "Body", "body" }, new[] { "Hands", "hands" }, new[] { "Legs", "legs" }, new[] { "Feet", "feet" },
            new[] { "Waist", "waist" }, new[] { "Neck", "neck" }, new[] { "Right Ear", "rightEar" },
            new[] { "Left Ear", "leftEar" }, new[] { "Right Finger", "rightFinger" }, new[] { "Left Finger", "leftFinger" },
            new[] { "Right Index", "rightIndex" }, new[] { "Left Index", "leftIndex" },
        };

        public static IResult LoginForm()
        {
            return LoginPage("", "");
        }

        public static async Task<IResult> Login(HttpContext context)
        {
            IFormCollection form = await context.Request.ReadFormAsync();
            string name = form["username"].ToString().Trim();
            string password = form["password"].ToString().Trim();

            if (name.Length == 0)
                return LoginPage(name, "You must enter a username.");
            if (password.Length == 0)
                return LoginPage(name, "You must enter a password.");

            string sessionId;
            try
            {
                uint userId = AccountService.VerifyUser(name, password);
                if (userId == 0)
                    return LoginPage(name, "Incorrect username or password.");
                sessionId = AccountService.RefreshOrCreateSession(userId);
                Program.Log.Info("panel: user {0} \"{1}\" signed in", userId, name);
            }
            catch (MySqlException e)
            {
                Program.Log.Error(e.ToString());
                return LoginPage(name, "The server can't sign you in right now.");
            }

            context.Response.Cookies.Append(SessionCookie, sessionId, new CookieOptions
            {
                HttpOnly = true,
                SameSite = SameSiteMode.Lax,
                Path = "/",
                MaxAge = TimeSpan.FromHours(ConfigConstants.SESSION_HOURS),
            });
            return Results.Redirect("/panel");
        }

        public static IResult Logout(HttpContext context)
        {
            context.Response.Cookies.Delete(SessionCookie, new CookieOptions { Path = "/" });
            return Results.Redirect("/login");
        }

        public static IResult Characters(HttpContext context)
        {
            uint userId = SignedInUser(context);
            if (userId == 0)
                return Results.Redirect("/login");

            StringBuilder rows = new StringBuilder();
            foreach (CharacterData.CharacterSummary character in CharacterData.GetCharacters(userId))
            {
                rows.Append("<tr><td>").Append(WebUtility.HtmlEncode(character.Name))
                    .Append("</td><td><a href=\"/panel/character/").Append(character.Id).Append("\">View</a></td></tr>\n");
            }

            return PanelPage.Render("Characters", Header(userId) + @"<div class=""edit"">
<h2>Characters</h2>
<br>
<table class=""editForm"">
<tr><th>Name</th><th>Action</th></tr>
" + rows + @"</table>
</div>");
        }

        public static IResult Character(HttpContext context, uint id)
        {
            uint userId = SignedInUser(context);
            if (userId == 0)
                return Results.Redirect("/login");

            CharacterData.CharacterSheet sheet = CharacterData.GetSheet(userId, id);
            if (sheet == null)
                return Results.Redirect("/panel");

            Dictionary<string, object> p = sheet.Profile;
            Dictionary<string, object> a = sheet.Appearance;
            StringBuilder body = new StringBuilder();
            body.Append(Header(userId)).Append("<div class=\"edit\">\n<h2>").Append(WebUtility.HtmlEncode(Text(p, "name"))).Append("</h2>\n");

            body.Append(Section("Profile", new[]
            {
                Field("Name", Text(p, "name")),
                Field("Legacy Character", Named(p, "isLegacy", YesNo)),
                Field("Creation Date", Text(p, "creationDate")),
                Field("Play Time", Text(p, "playTime")),
                Field("Guardian", Named(p, "guardian", Guardians)),
                Field("Birth Month", Text(p, "birthMonth")),
                Field("Birth Day", Text(p, "birthDay")),
                Field("Allegiance", Named(p, "initialTown", Allegiances)),
                Field("Achievement Points", Text(p, "achievementPoints")),
            }));

            body.Append(Section("Grand Company", new[]
            {
                Field("Current GC", Named(p, "gcCurrent", GrandCompanies)),
                Field("Maelstrom Rank", Text(p, "gcLimsaRank")),
                Field("Twin Adder Rank", Text(p, "gcGridaniaRank")),
                Field("Immortal Flames Rank", Text(p, "gcUldahRank")),
            }));

            if (sheet.ClassLevels != null)
            {
                List<string[]> levels = new List<string[]>();
                foreach (string[] c in ClassColumns)
                    levels.Add(Field(c[0], Text(sheet.ClassLevels, c[1])));
                body.Append(Section("Class Levels", levels.ToArray()));
            }

            if (sheet.Chocobo != null)
            {
                body.Append(Section("Chocobo", new[]
                {
                    Field("Chocobo Unlocked", Named(sheet.Chocobo, "hasChocobo", YesNo)),
                    Field("Goobbue Unlocked", Named(sheet.Chocobo, "hasGoobbue", YesNo)),
                    Field("Chocobo Appearance", Text(sheet.Chocobo, "chocoboAppearance")),
                    Field("Chocobo Name", Text(sheet.Chocobo, "chocoboName")),
                }));
            }

            if (a != null)
            {
                body.Append(Section("Appearance", new[]
                {
                    Field("Tribe", Named(p, "tribe", Tribes)),
                    Field("Height", Named(a, "size", Heights)),
                    Field("Voice", Text(a, "voice")),
                    Field("Skin Tone", Text(a, "skinColor")),
                    Field("Hairstyle", Text(a, "hairStyle")),
                    Field("Variation", Text(a, "hairVariation")),
                    Field("Hair Color", Text(a, "hairColor")),
                    Field("Highlights", Text(a, "hairHighlightColor")),
                    Field("Face Type", Text(a, "faceType")),
                    Field("Eyebrows", Text(a, "faceEyebrows")),
                    Field("Eye Shape", Text(a, "faceEyeShape")),
                    Field("Iris Size", Text(a, "faceIrisSize")),
                    Field("Eye Color", Text(a, "eyeColor")),
                    Field("Nose", Text(a, "faceNose")),
                    Field("Mouth", Text(a, "faceMouth")),
                    Field("Features", Text(a, "faceFeatures")),
                    Field("Characteristic", Text(a, "characteristics")),
                    Field("Characteristic Color", Text(a, "characteristicsColor")),
                    Field("Ears", Text(a, "ears")),
                }));

                List<string[]> gear = new List<string[]>();
                foreach (string[] g in GearColumns)
                    gear.Add(Field(g[0], Text(a, g[1])));
                body.Append(Section("Gear", gear.ToArray()));
            }

            body.Append("<p><a href=\"/panel\">Back to characters</a></p>\n</div>");
            return PanelPage.Render(Text(p, "name"), body.ToString());
        }

        static uint SignedInUser(HttpContext context)
        {
            string sessionId = context.Request.Cookies[SessionCookie];
            if (String.IsNullOrEmpty(sessionId))
                return 0;
            try
            {
                return AccountService.GetUserIdFromSession(sessionId);
            }
            catch (MySqlException e)
            {
                Program.Log.Error(e.ToString());
                return 0;
            }
        }

        static string Header(uint userId)
        {
            return "<p>Welcome, " + WebUtility.HtmlEncode(AccountService.GetUserName(userId)) + ". <a href=\"/logout\">(Logout)</a></p>\n";
        }

        static IResult LoginPage(string name, string error)
        {
            return PanelPage.Render("Login", @"<div class=""info"">
<h2>Login</h2>
<br>
<form method=""post"" action=""/login"" autocomplete=""off"">
<table class=""infoForm"">
<tr><td>Username:</td><td><input type=""text"" name=""username"" value=""" + WebUtility.HtmlEncode(name) + @"""></td></tr>
<tr><td>Password:</td><td><input type=""password"" name=""password""></td></tr>
<tr><td colspan=""2""><input type=""submit"" name=""login"" value=""Login""></td></tr>
</table>
</form>
<p class=""errorMessage"">" + WebUtility.HtmlEncode(error) + @"</p>
</div>
<div class=""infoFooter""><a href=""/signup"">Create User</a></div>");
        }

        static string[] Field(string label, string value)
        {
            return new[] { label, value };
        }

        static string Section(string title, string[][] fields)
        {
            StringBuilder html = new StringBuilder();
            html.Append("<h3>").Append(WebUtility.HtmlEncode(title)).Append("</h3>\n<table class=\"editForm\">\n");
            foreach (string[] field in fields)
            {
                html.Append("<tr><td>").Append(WebUtility.HtmlEncode(field[0])).Append(":</td><td>")
                    .Append(WebUtility.HtmlEncode(field[1])).Append("</td></tr>\n");
            }
            html.Append("</table>\n<br>\n");
            return html.ToString();
        }

        static string Text(Dictionary<string, object> row, string column)
        {
            if (row == null || !row.TryGetValue(column, out object value) || value == null)
                return "";
            if (value is DateTime date)
                return date.ToString("yyyy-MM-dd HH:mm:ss");
            return Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture);
        }

        static string Named(Dictionary<string, object> row, string column, Dictionary<long, string> names)
        {
            string raw = Text(row, column);
            if (long.TryParse(raw, out long key) && names.TryGetValue(key, out string name))
                return name;
            return raw;
        }
    }
}
