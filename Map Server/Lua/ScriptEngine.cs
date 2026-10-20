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
using NLog;

namespace Meteor.Map.lua
{
    /// <summary>
    /// Runs the server's Lua scripts. There are two implementations: xLua (LuaJIT, the default) and
    /// MoonSharp (the old one, kept for comparison until it is removed). Whatever a script hands back
    /// to C# arrives in the same form from either: numbers as double, text as string, true/false as
    /// bool, nil as null, Lua tables as LuaTableValue, Lua functions as LuaFunctionValue, and server
    /// objects as themselves.
    /// </summary>
    abstract class ScriptEngine
    {
        // NLog.config only shows loggers named Meteor.Map.lua.* in the console.
        public static Logger Log = LogManager.GetLogger("Meteor.Map.lua.LuaScript");

        private static ScriptEngine instance;
        private static readonly object instanceLock = new object();

        /// <summary>The engine chosen in map_config.ini ([Lua] engine = xlua or moonsharp).</summary>
        public static ScriptEngine Instance
        {
            get
            {
                if (instance == null)
                    lock (instanceLock)
                        if (instance == null)
                            instance = Create(ConfigConstants.LUA_ENGINE);
                return instance;
            }
        }

        /// <summary>Switches engines. Only the tests use this, to run the same checks on both.</summary>
        internal static void Use(ScriptEngine engine)
        {
            lock (instanceLock)
                instance = engine;
        }

        public static ScriptEngine Create(string name)
        {
            switch ((name ?? "").ToLowerInvariant())
            {
                case "moonsharp":
                    return new MoonSharpEngine();
                case "":
                case "xlua":
                    return new XLuaEngine();
                default:
                    throw new ArgumentException("Unknown Lua engine '" + name + "' (use xlua or moonsharp)");
            }
        }

        public abstract string Name { get; }

        /// <summary>
        /// Loads and runs a script file. Each loaded script gets its own set of globals, and so do the
        /// files it pulls in with require, so two scripts never see each other's variables.
        /// Returns null when the file does not exist. If the file stops with an error, the error is
        /// logged and the script is still returned with whatever it set up before the error.
        /// </summary>
        public abstract LuaScript Load(string path);

        /// <summary>The C# functions every script can call by name (GetWorldManager, ...).</summary>
        public static IReadOnlyDictionary<string, Delegate> Globals => LuaEngine.ScriptGlobals;
    }

    /// <summary>One loaded script file.</summary>
    abstract class LuaScript
    {
        public static Logger Log = ScriptEngine.Log;

        public string Path { get; protected set; }

        /// <summary>The error the file stopped with while loading, or null.</summary>
        public string LoadError { get; protected set; }

        /// <summary>The globals the script set up (name and Lua type, e.g. "function"), leaving out
        /// the ones every script starts with. The tests compare this between engines.</summary>
        public abstract SortedDictionary<string, string> DefinedGlobals();

        /// <summary>True when the script has a function with this name.</summary>
        public abstract bool HasFunction(string name);

        /// <summary>The value of a global, or null when it is not set.</summary>
        public abstract object GetGlobal(string name);

        /// <summary>
        /// Calls the script's function and returns what it returned. Returns null when there is no
        /// such function or the call fails; failures are logged with the script line that failed.
        /// </summary>
        public abstract object[] Call(string name, params object[] args);

        /// <summary>
        /// Prepares the script's function to run as a coroutine: a function that can pause partway,
        /// for example to wait for the player's reply, and carry on later. Null if there is no such
        /// function. Nothing runs until the first Resume.
        /// </summary>
        public abstract LuaCoroutine CreateCoroutine(string name);
    }

    /// <summary>A script function that can pause and carry on later (see CreateCoroutine).</summary>
    abstract class LuaCoroutine
    {
        /// <summary>
        /// Runs the function until it pauses or ends; the arguments are what the function receives.
        /// Throws LuaScriptException when the script fails.
        /// </summary>
        public abstract LuaResume Resume(params object[] args);

        /// <summary>True once the function has ended or failed; it cannot be resumed again.</summary>
        public abstract bool IsDead { get; }
    }

    /// <summary>What a coroutine handed back: the values it paused with, or returned at its end.</summary>
    sealed class LuaResume
    {
        public static readonly object[] None = new object[0];

        public object[] Values { get; }

        /// <summary>True when the function paused (and can be resumed); false when it ended.</summary>
        public bool Yielded { get; }

        public LuaResume(object[] values, bool yielded)
        {
            Values = values ?? None;
            Yielded = yielded;
        }

        public object this[int i] => i < Values.Length ? Values[i] : null;
        public int Count => Values.Length;
    }

    /// <summary>A copy of a Lua table (tables inside it are copied too).</summary>
    sealed class LuaTableValue
    {
        public List<KeyValuePair<object, object>> Pairs { get; } = new List<KeyValuePair<object, object>>();
    }

    /// <summary>Stands in for a Lua function handed back to C#; C# only checks that it is one.</summary>
    sealed class LuaFunctionValue
    {
        public static readonly LuaFunctionValue Instance = new LuaFunctionValue();
    }

    sealed class LuaScriptException : Exception
    {
        /// <summary>The script's error message with its file, line and call chain.</summary>
        public string DecoratedMessage { get; }

        public LuaScriptException(string decorated, Exception inner = null) : base(decorated, inner)
        {
            DecoratedMessage = decorated;
        }
    }
}
