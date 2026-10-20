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

1. Install the [.NET 10 SDK](https://dotnet.microsoft.com/download), MariaDB and PHP.
   On macOS: `brew install --cask dotnet-sdk` and `brew install mariadb php`.
2. Create the database and import the schema into an empty database:
   ```bash
   mysql -u root -p -e "CREATE DATABASE ffxiv_server"
   for f in Data/sql/*.sql; do mysql -u root -p<password> ffxiv_server < "$f"; done
   ```
3. Build: `dotnet build Meteor.sln`. Each server's output goes to `<Server>/bin/Debug/`.
   The Map server's `scripts/` folder and `staticactors.bin` are copied there by the build.
   Each `*_config.ini` is copied from `Data/` only if the server doesn't have one yet,
   so set your database password in `<Server>/bin/Debug/*_config.ini`, or pass it at launch.
4. Run all three servers: `./run-servers.sh` (or `METEOR_DB_PASSWORD=<password> ./run-servers.sh`).
   It starts Map, then World, then Lobby, and stops them all on Ctrl+C.
5. Serve the login pages: `php -S 127.0.0.1:8000 -t Data/www`.

The game client itself is a Windows program. Point a Windows machine or VM at the server's IP.

Navigation
========
`Navigation/` (`Meteor.Navigation`) loads navmeshes (`.nav`) and collision (`.xcol`) built by
[navgen](https://github.com/rubymatrix/navgen), a separate C++ tool. The file formats are in
navgen's [docs/FORMATS.md](https://github.com/rubymatrix/navgen/blob/main/docs/FORMATS.md).
Meshes and collision come from game data, so they stay local and are never committed.
Tests: `dotnet test "tests/Navigation Tests"`.

Pull Requests
========
Commits should contain a descriptive name for what you are modifying

Remember to check back for any feedback, and drop a comment once requested changes have been made (if there are any).

Please *test your code* before committing changes/submitting a pull request.