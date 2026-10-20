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
using Meteor.Map.actors.director;
using Meteor.Map.Actors;
using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;

namespace Meteor.Map.lua
{
    /// <summary>The previous runtime, kept selectable ([Lua] engine=moonsharp) for comparison until xLua replaces it.</summary>
    sealed class MoonSharpEngine : ScriptEngine
    {
        static MoonSharpEngine()
        {
            UserData.RegisterType<Player>();
            UserData.RegisterType<Command>();
            UserData.RegisterType<Npc>();
            UserData.RegisterType<Quest>();
            UserData.RegisterType<WorldManager>();
            UserData.RegisterType<WorldMaster>();
            UserData.RegisterType<LuaEngine>();
        }

        public override string Name => "moonsharp";

        public override LuaScript Load(string path)
        {
            if (!System.IO.File.Exists(path))
                return null;

            var script = new Script();
            ((FileSystemScriptLoader)script.Options.ScriptLoader).ModulePaths = FileSystemScriptLoader.UnpackStringPaths("./scripts/?;./scripts/?.lua");
            foreach (var g in Globals)
                script.Globals[g.Key] = g.Value;
            // Scripts use LuaJIT's bit library. bit32 has the same functions; it returns unsigned
            // values where bit is signed, and scripts reduce with % 0x100000000 where that matters.
            script.Globals["bit"] = script.Globals["bit32"];
            script.Options.DebugPrint = s => { Log.Debug(s); };
            var provided = new HashSet<string>();
            foreach (var key in script.Globals.Keys)
                if (key.Type == DataType.String)
                    provided.Add(key.String);

            string error = null;
            try
            {
                script.DoFile(path);
            }
            catch (Exception e)
            {
                error = Describe(e);
                Log.Error("{0}: {1}", path, error);
            }
            return new MoonSharpScript(script, path, provided, error);
        }

        /// <summary>DecoratedMessage is empty for errors with no source position (e.g. "cannot convert
        /// clr type" while marshalling call arguments).</summary>
        internal static string Describe(Exception e)
        {
            string decorated = (e as InterpreterException)?.DecoratedMessage;
            return String.IsNullOrEmpty(decorated) ? e.GetType().Name + ": " + e.Message : decorated;
        }

        internal static object ToClr(DynValue v)
        {
            if (v == null)
                return null;
            switch (v.Type)
            {
                case DataType.Nil:
                case DataType.Void:
                    return null;
                case DataType.Boolean:
                    return v.Boolean;
                case DataType.Number:
                    return v.Number;
                case DataType.String:
                    return v.String;
                case DataType.Table:
                    return ToTable(v.Table, 0);
                case DataType.Function:
                case DataType.ClrFunction:
                    return LuaFunctionValue.Instance;
                case DataType.UserData:
                    return v.UserData.Object;
                case DataType.Tuple:
                    return v.Tuple.Length > 0 ? ToClr(v.Tuple[0]) : null;
                default:
                    return v.ToObject();
            }
        }

        static LuaTableValue ToTable(Table t, int depth)
        {
            var result = new LuaTableValue();
            foreach (var pair in t.Pairs)
            {
                object value = pair.Value.Type == DataType.Table
                    ? (depth < 16 ? ToTable(pair.Value.Table, depth + 1) : null)
                    : ToClr(pair.Value);
                result.Pairs.Add(new KeyValuePair<object, object>(ToClr(pair.Key), value));
            }
            return result;
        }

        internal static object[] ToClrList(DynValue v)
        {
            if (v == null || v.IsVoid())
                return LuaResume.None;
            if (v.Type == DataType.Tuple)
            {
                var list = new object[v.Tuple.Length];
                for (int i = 0; i < list.Length; i++)
                    list[i] = ToClr(v.Tuple[i]);
                return list;
            }
            return new[] { ToClr(v) };
        }
    }

    sealed class MoonSharpScript : LuaScript
    {
        private readonly Script script;
        private readonly HashSet<string> provided;

        public MoonSharpScript(Script script, string path, HashSet<string> provided, string loadError)
        {
            this.script = script;
            this.provided = provided;
            Path = path;
            LoadError = loadError;
        }

        public override SortedDictionary<string, string> DefinedGlobals()
        {
            var result = new SortedDictionary<string, string>(StringComparer.Ordinal);
            foreach (var pair in script.Globals.Pairs)
                if (pair.Key.Type == DataType.String && !provided.Contains(pair.Key.String))
                    result[pair.Key.String] = LuaTypeName(pair.Value);
            return result;
        }

        static string LuaTypeName(DynValue v)
        {
            switch (v.Type)
            {
                case DataType.Function:
                case DataType.ClrFunction: return "function";
                case DataType.Table: return "table";
                case DataType.Number: return "number";
                case DataType.String: return "string";
                case DataType.Boolean: return "boolean";
                case DataType.UserData: return "userdata";
                default: return v.Type.ToString().ToLowerInvariant();
            }
        }

        public override bool HasFunction(string name)
        {
            DynValue v = script.Globals.Get(name);
            return v.Type == DataType.Function || v.Type == DataType.ClrFunction;
        }

        public override object GetGlobal(string name) => MoonSharpEngine.ToClr(script.Globals.Get(name));

        public override object[] Call(string name, params object[] args)
        {
            if (!HasFunction(name))
                return null;
            try
            {
                return MoonSharpEngine.ToClrList(script.Call(script.Globals.Get(name), args));
            }
            catch (Exception e)
            {
                Log.Error("{0} {1}: {2}", Path, name, MoonSharpEngine.Describe(e));
                return null;
            }
        }

        public override LuaCoroutine CreateCoroutine(string name)
        {
            if (!HasFunction(name))
                return null;
            return new MoonSharpCoroutine(script.CreateCoroutine(script.Globals.Get(name)).Coroutine);
        }
    }

    sealed class MoonSharpCoroutine : LuaCoroutine
    {
        private readonly Coroutine coroutine;

        public MoonSharpCoroutine(Coroutine coroutine)
        {
            this.coroutine = coroutine;
        }

        public override bool IsDead => coroutine.State == CoroutineState.Dead;

        public override LuaResume Resume(params object[] args)
        {
            DynValue value;
            try
            {
                value = coroutine.Resume(args);
            }
            catch (InterpreterException e)
            {
                throw new LuaScriptException(MoonSharpEngine.Describe(e), e);
            }
            return new LuaResume(MoonSharpEngine.ToClrList(value), coroutine.State == CoroutineState.Suspended);
        }
    }
}
