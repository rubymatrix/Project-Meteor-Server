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
using Meteor.Map.lua;

namespace Meteor.Map.Scripting
{
    // The Lua side of AI and content: ai/runtime/core.lua, loaded once. It keeps every actor,
    // behavior, encounter and campaign object, their tasks and callbacks. C# refers to an object
    // by the integer id the runtime gives it.
    sealed class ScriptRuntime
    {
        public const string CorePath = "/ai/runtime/core.lua";

        private static ScriptRuntime instance;
        private LuaScript script;

        public static ScriptRuntime Instance => instance ??= new ScriptRuntime();
        public static bool Loaded => instance?.script != null;

        public RuntimeHost Host { get; } = new RuntimeHost();

        private ScriptRuntime()
        {
            string path = (ConfigConstants.OPTIONS_SCRIPTPATH ?? "./scripts") + CorePath;
            if (!File.Exists(path))
            {
                Program.Log.Error("Script runtime {0} is missing; AI and content scripts are off.", path);
                return;
            }
            script = ScriptEngine.Instance.Load(path);
            if (script?.LoadError != null)
                Program.Log.Error("Script runtime failed to load: {0}", script.LoadError);
            script?.Call("rt_init", Host);
        }

        // Drops the runtime and every script object; the next use loads it again.
        public static void Reset()
        {
            instance = null;
        }

        public object[] Call(string fn, params object[] args)
        {
            return script?.Call(fn, args);
        }

        public int CallInt(string fn, params object[] args)
        {
            var r = Call(fn, args);
            return r != null && r.Length > 0 && r[0] is double d ? (int)d : 0;
        }

        public bool CallBool(string fn, params object[] args)
        {
            var r = Call(fn, args);
            return r != null && r.Length > 0 && r[0] is bool b && b;
        }

        public void Tick()
        {
            Call("rt_tick", (double)GameClock.NowMs);
        }

        public void Destroy(int id)
        {
            if (id > 0)
                Call("rt_destroy", id);
        }
    }
}
