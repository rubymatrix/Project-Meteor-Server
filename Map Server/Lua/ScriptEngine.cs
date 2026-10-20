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
    /// The Lua runtime behind LuaEngine. Values crossing back to C# are engine-neutral: numbers are
    /// double, strings string, booleans bool, nil null, tables LuaTableValue, functions
    /// LuaFunctionValue, and C# objects themselves.
    /// </summary>
    abstract class ScriptEngine
    {
        public static Logger Log = LogManager.GetLogger("Meteor.Map.lua.LuaScript"); // the name NLog.config sends to the console

        private static ScriptEngine instance;
        private static readonly object instanceLock = new object();

        /// <summary>The engine named by ConfigConstants.LUA_ENGINE ("xlua" or "moonsharp").</summary>
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

        /// <summary>Replaces the configured engine (tests run LuaEngine against each one).</summary>
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
        /// Runs a script file in a fresh environment with the engine globals installed, as a new
        /// MoonSharp Script did: the file's globals and the modules it requires are its own.
        /// Null when the file does not exist. A script whose main chunk errors is still returned
        /// (with whatever it defined before the error), and the error is logged.
        /// </summary>
        public abstract LuaScript Load(string path);

        /// <summary>The functions every script sees as globals (GetWorldManager, ...).</summary>
        public static IReadOnlyDictionary<string, Delegate> Globals => LuaEngine.ScriptGlobals;
    }

    abstract class LuaScript
    {
        public static Logger Log = ScriptEngine.Log;

        public string Path { get; protected set; }

        /// <summary>The error the main chunk raised while loading, or null.</summary>
        public string LoadError { get; protected set; }

        /// <summary>Globals the script and its modules defined, by name, with their Lua type
        /// ("function", "table", "number", ...). Engine-provided globals are not included.</summary>
        public abstract SortedDictionary<string, string> DefinedGlobals();

        /// <summary>True when the global is a function.</summary>
        public abstract bool HasFunction(string name);

        /// <summary>The global's value, converted (see ScriptEngine). Null for nil.</summary>
        public abstract object GetGlobal(string name);

        /// <summary>
        /// Calls the global function with the arguments and returns its results. Null when the global
        /// is not a function or the call errors; errors are logged with the script's traceback.
        /// </summary>
        public abstract object[] Call(string name, params object[] args);

        /// <summary>A coroutine over the global function, not yet started. Null if it is not a function.</summary>
        public abstract LuaCoroutine CreateCoroutine(string name);

        /// <summary>First result of Call as an int (0 when there is none or it is not a number), the
        /// way battle and status scripts return amounts.</summary>
        public int CallForInt(string name, params object[] args)
        {
            object[] res = Call(name, args);
            return res != null && res.Length > 0 && res[0] is double d ? (int)d : 0;
        }
    }

    abstract class LuaCoroutine
    {
        /// <summary>
        /// Runs the coroutine until it yields or finishes. Throws LuaScriptException when the
        /// script errors.
        /// </summary>
        public abstract LuaResume Resume(params object[] args);

        public abstract bool IsDead { get; }
    }

    /// <summary>What a coroutine handed back: the values it yielded, or returned when it finished.</summary>
    sealed class LuaResume
    {
        public static readonly object[] None = new object[0];

        public object[] Values { get; }
        public bool Yielded { get; }

        public LuaResume(object[] values, bool yielded)
        {
            Values = values ?? None;
            Yielded = yielded;
        }

        public object this[int i] => i < Values.Length ? Values[i] : null;
        public int Count => Values.Length;
    }

    /// <summary>A Lua table copied out of the script (nested tables copied too).</summary>
    sealed class LuaTableValue
    {
        public List<KeyValuePair<object, object>> Pairs { get; } = new List<KeyValuePair<object, object>>();

        public object Get(object key)
        {
            if (key is int i) key = (double)i;
            foreach (var p in Pairs)
                if (Equals(p.Key, key))
                    return p.Value;
            return null;
        }

        /// <summary>The values at 1..n, as ipairs walks them.</summary>
        public List<object> Sequence()
        {
            var list = new List<object>();
            for (int i = 1; ; i++)
            {
                object v = Get((double)i);
                if (v == null)
                    return list;
                list.Add(v);
            }
        }
    }

    /// <summary>A Lua function returned to C#. Opaque: C# only checks for it.</summary>
    sealed class LuaFunctionValue
    {
        public static readonly LuaFunctionValue Instance = new LuaFunctionValue();
    }

    sealed class LuaScriptException : Exception
    {
        /// <summary>The script error with file, line and traceback.</summary>
        public string DecoratedMessage { get; }

        public LuaScriptException(string decorated, Exception inner = null) : base(decorated, inner)
        {
            DecoratedMessage = decorated;
        }
    }
}
