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

using Microsoft.AspNetCore.Http;

namespace Meteor.Web
{
    // Shared frame for the pages on the panel port (sign-up, control panel).
    static class PanelPage
    {
        public static IResult Render(string title, string body)
        {
            string html = @"<!DOCTYPE html>
<html>
<head>
<meta charset=""utf-8"">
<title>" + WebUtility.HtmlEncode(title) + @"</title>
<link rel=""stylesheet"" type=""text/css"" href=""/css/reset.css"">
<link rel=""stylesheet"" type=""text/css"" href=""/css/global.css"">
</head>
<body>
<header class=""top""></header>
" + body + @"
</body>
</html>";
            return Results.Content(html, "text/html; charset=utf-8");
        }
    }
}
