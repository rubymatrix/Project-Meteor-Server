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

using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;

using Microsoft.AspNetCore.Http;
using MySql.Data.MySqlClient;

namespace Meteor.Web
{
    // Account sign-up on the panel port. The game's login window links here and opens it in the
    // player's own browser.
    static class SignupPage
    {
        // users.name is varchar(45), users.email varchar(256).
        const int MaxNameLength = 45;
        const int MaxEmailLength = 256;

        public static IResult Get()
        {
            return Form("", "", "");
        }

        public static async Task<IResult> Post(HttpContext context)
        {
            IFormCollection form = await context.Request.ReadFormAsync();
            string name = form["username"].ToString().Trim();
            string password = form["password"].ToString().Trim();
            string repeatPassword = form["repeatPassword"].ToString().Trim();
            string email = form["email"].ToString().Trim();

            if (name.Length == 0)
                return Form(name, email, "You must enter a username.");
            if (name.Length > MaxNameLength)
                return Form(name, email, "Your username can be at most " + MaxNameLength + " characters.");
            if (password.Length == 0)
                return Form(name, email, "You must enter a password.");
            if (password != repeatPassword)
                return Form(name, email, "Repeated password doesn't match with entered password.");
            if (email.Length == 0 || email.Length > MaxEmailLength || !MailAddress.TryCreate(email, out _))
                return Form(name, email, "You must enter a valid e-mail address.");

            try
            {
                if (AccountService.CreateUser(name, password, email) == AccountService.CreateResult.NameTaken)
                    return Form(name, email, "That username is already taken.");
            }
            catch (MySqlException e)
            {
                Program.Log.Error(e.ToString());
                return Form(name, email, "The server can't create accounts right now.");
            }

            Program.Log.Info("signup: created \"{0}\"", name);
            return Results.Redirect("/signup/done");
        }

        public static IResult Done()
        {
            return PanelPage.Render("Account created", @"<div class=""info"">
<p>User created successfully.</p>
<p>You can now sign in from the game's login window.</p>
<p><a href=""/login"">Login to the User Control Panel</a></p>
</div>");
        }

        static IResult Form(string name, string email, string error)
        {
            return PanelPage.Render("Create New User", @"<div class=""info"">
<h2>Create New User</h2>
<br>
<form method=""post"" action=""/signup"" autocomplete=""off"">
<table class=""infoForm"">
<tr><td>Username:</td><td><input type=""text"" name=""username"" maxlength=""" + MaxNameLength + @""" value=""" + WebUtility.HtmlEncode(name) + @"""></td></tr>
<tr><td>Password:</td><td><input type=""password"" name=""password""></td></tr>
<tr><td>Repeat Password:</td><td><input type=""password"" name=""repeatPassword""></td></tr>
<tr><td>E-mail Address:</td><td><input type=""text"" name=""email"" maxlength=""" + MaxEmailLength + @""" value=""" + WebUtility.HtmlEncode(email) + @"""></td></tr>
<tr><td colspan=""2""><input type=""submit"" name=""createUser"" value=""Create User""></td></tr>
</table>
</form>
<p class=""errorMessage"">" + WebUtility.HtmlEncode(error) + @"</p>
</div>");
        }
    }
}
