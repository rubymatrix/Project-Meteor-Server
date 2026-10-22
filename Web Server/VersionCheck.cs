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

using Microsoft.AspNetCore.Http;

namespace Meteor.Web
{
    // ffxivboot's patch check: GET /patch/vercheck/ffxiv/win32/release/{boot|game}/{version}.
    // It checks boot first, then game, then starts ffxivlogin.
    static class VersionCheck
    {
        public static IResult Handle(HttpContext context, string repo, string version)
        {
            if (repo != "boot" && repo != "game")
                return Results.NotFound();

            string target = PatchCatalog.Target(repo);
            switch (PatchCatalog.Compare(repo, version))
            {
                case PatchCatalog.Standing.Behind:
                    // Patch downloads (200 with signed torrents) aren't served yet. Boot shows its
                    // generic error for a 404.
                    Program.Log.Info("vercheck {0}: {1} is behind {2}, no patch served", repo, version, target);
                    return Results.NotFound();
                case PatchCatalog.Standing.Ahead:
                    // Newer than this server supports, and patches only go forward. Boot has its
                    // own error message for 410.
                    Program.Log.Info("vercheck {0}: {1} is newer than {2}", repo, version, target);
                    return Results.StatusCode(StatusCodes.Status410Gone);
                case PatchCatalog.Standing.Unknown:
                    Program.Log.Info("vercheck {0}: {1} isn't a known version", repo, version);
                    return Results.NotFound();
            }

            // Boot throws if any of these four headers is missing, even on 204.
            HttpResponse response = context.Response;
            response.Headers["X-Repository"] = "ffxiv/win32/release/" + repo;
            response.Headers["X-Patch-Module"] = "ZiPatch";
            response.Headers["X-Protocol"] = "torrent";
            response.Headers["X-Info-Url"] = ConfigConstants.PATCH_INFO_URL;
            response.Headers["X-Latest-Version"] = target;

            Program.Log.Info("vercheck {0}: {1} is up to date", repo, version);
            return Results.StatusCode(StatusCodes.Status204NoContent);
        }
    }
}
