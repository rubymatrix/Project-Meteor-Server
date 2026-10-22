Project Meteor Server
========
Compile and install instructions: http://ffxivclassic.fragmenterworks.com/wiki/index.php/Setting_up_the_project

Welcome to the Project Meteor Server; a server emulator for FFXIV 1.23b.
If you wish to discuss and help please join the Discord server.

**Discord Server Invite**

https://discord.gg/fBmGkSZbaD

Building and running (Windows, macOS, Linux)
========
The servers target .NET 10 and build with the `dotnet` CLI on any OS.

1. Install the [.NET 10 SDK](https://dotnet.microsoft.com/download) and MariaDB.
   On macOS: `brew install --cask dotnet-sdk` and `brew install mariadb`.
2. Create the database and import the schema into an empty database:
   ```bash
   mysql -u root -p -e "CREATE DATABASE ffxiv_server"
   for f in Data/sql/*.sql; do mysql -u root -p<password> ffxiv_server < "$f"; done
   ```
3. Build: `dotnet build Meteor.sln`. Each server's output goes to `<Server>/bin/Debug/`.
   The Map server's `scripts/` folder and `staticactors.bin` are copied there by the build.
   Each `*_config.ini` is copied from `Data/` only if the server doesn't have one yet,
   so set your database password in `<Server>/bin/Debug/*_config.ini`, or pass it at launch.
4. Run the servers: `./run-servers.sh` (or `METEOR_DB_PASSWORD=<password> ./run-servers.sh`).
   It starts Map, then World, Lobby and Web, and stops them all on Ctrl+C.
   The Web server answers the retail launcher's version check (port 54996), serves the
   game's login page (port 80) and the account sign-up and control panel (port 8000,
   `/signup`, `/login`). Ports are set in `web_config.ini`.

The game client itself is a Windows program. Point a Windows machine or VM at the server's IP.

Pull Requests
========
Commits should contain a descriptive name for what you are modifying

Remember to check back for any feedback, and drop a comment once requested changes have been made (if there are any).

Please *test your code* before committing changes/submitting a pull request.