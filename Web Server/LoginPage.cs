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
using System.Text.RegularExpressions;
using System.Threading.Tasks;

using Microsoft.AspNetCore.Http;
using MySql.Data.MySqlClient;

namespace Meteor.Web
{
    // ffxivlogin's page: http://account.square-enix.com/account/content/ffxivlogin, shown in an
    // embedded WebBrowser control (784x500). After each page load the login window looks for an
    // <x-sqexauth> element and, if found, starts ffxivgame.exe with its sid/lang/region/utc. The
    // window has no error signal: on failure the form stays up and the player can press Cancel.
    static class LoginPage
    {
        static readonly string[] Languages = { "ja-jp", "en-us", "en-gb", "fr-fr", "de-de" };

        public static IResult Get()
        {
            return Page("", "", null);
        }

        public static async Task<IResult> Post(HttpContext context)
        {
            IFormCollection form = await context.Request.ReadFormAsync();
            string name = form["username"].ToString().Trim();
            string password = form["password"].ToString().Trim();

            if (name.Length == 0)
                return Page(name, "You must enter a username.", null);
            if (password.Length == 0)
                return Page(name, "You must enter a password.", null);

            string sessionId;
            try
            {
                uint userId = AccountService.VerifyUser(name, password);
                if (userId == 0)
                {
                    Program.Log.Info("login: bad name or password for \"{0}\"", name);
                    return Page(name, "Incorrect username or password.", null);
                }
                sessionId = AccountService.RefreshOrCreateSession(userId);
                Program.Log.Info("login: user {0} \"{1}\" signed in", userId, name);
            }
            catch (MySqlException e)
            {
                Program.Log.Error(e.ToString());
                return Page(name, "The server can't sign you in right now.", null);
            }

            string auth = String.Format("<x-sqexauth sid=\"{0}\" lang=\"{1}\" region=\"2\" utc=\"{2}\"></x-sqexauth>",
                sessionId, LanguageFrom(context.Request.Headers.UserAgent.ToString()), DateTimeOffset.UtcNow.ToUnixTimeSeconds());
            return Page(name, "", auth);
        }

        // The login window's User-Agent is "SQEXAuthor/2.0.0(<os>; <lang>; <machine id>)".
        static string LanguageFrom(string userAgent)
        {
            Match m = Regex.Match(userAgent, @"^SQEXAuthor/[^(]*\([^;]*;\s*([a-z]{2}-[a-z]{2})\s*;");
            if (m.Success && Array.IndexOf(Languages, m.Groups[1].Value) >= 0)
                return m.Groups[1].Value;
            return "en-us";
        }

        static IResult Page(string name, string error, string auth)
        {
            string html = Template
                .Replace("{auth}", auth ?? "")
                .Replace("{name}", WebUtility.HtmlEncode(name))
                .Replace("{error}", WebUtility.HtmlEncode(error))
                .Replace("{signup}", WebUtility.HtmlEncode(ConfigConstants.SIGNUP_URL));
            return Results.Content(html, "text/html; charset=utf-8");
        }

        const string Template = @"<html><head>
<meta http-equiv=""content-type"" content=""text/html; charset=utf-8"">
<style>
html, body { font-family: Arial; font-size: 14px; margin: 0; padding: 0; width: 600px; }
html { padding: 10px; }
form { background-color: #eee; border: solid 1px #666; border-radius: 3px; margin-bottom: 0; }
table { width: 100%; height: 100%; padding: 20px; }
form input { width: 100%; border: solid 1px #222; padding: 3px; outline: none; }
form button { background-image: url(img/btLogin.gif); background-position: 0 0; background-repeat: no-repeat; border: none; width: 200px; height: 40px; }
form button:hover { background-position: 0 -40px; cursor: pointer; }
.errorText { color: red; }
.banner { margin-top: 10px; }
</style>
</head>
<body>
{auth}
<table border=""0"" cellpadding=""0"" cellspacing=""0"">
<tr>
	<td width=""50%""><img src=""img/logo.png"" class=""logo"" width=""300""></td>
	<td width=""50%"">
		<form method=""post"" action=""ffxivlogin"">
		<table border=""0"" cellpadding=""5"" cellspacing=""0"">
		<tr>
			<td width=""5%""><img src=""img/lbSQEXId_mem.gif""></td>
			<td width=""40%""><label for=""username"">Username</label></td>
			<td width=""50%""><input id=""username"" name=""username"" autocomplete=""off"" type=""text"" value=""{name}""></td>
		</tr>
		<tr>
			<td><img src=""img/lbSQEXPass_mem.gif""></td>
			<td><label for=""password"">Password</label></td>
			<td><input id=""password"" name=""password"" autocomplete=""off"" type=""password""></td>
		</tr>
		<tr><td colspan=""3"" align=""center""><p class=""errorText"">{error}</p></td></tr>
		<tr><td colspan=""3"" align=""center""><button type=""submit"" name=""login"">&nbsp;</button></td></tr>
		<tr><td colspan=""3"" align=""center""><a href=""{signup}"" target=""_blank"">Don't have an account?</a></td></tr>
		</table>
		</form>
	</td>
</tr>
<tr><td colspan=""2"" align=""center""><img src=""img/banner.png"" class=""banner"" width=""720""></td></tr>
</table>
</body></html>";
    }
}
