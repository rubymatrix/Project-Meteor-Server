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
using System.IO;
using XLua;

namespace Meteor.Map.lua
{
    /// <summary>
    /// LuaJIT through xLua. One Lua state serves every script; each Load gets its own global table
    /// and module cache (what a new MoonSharp Script gave), falling back to a shared base with the
    /// standard libraries and the engine globals. Compiled chunks are cached until the file changes.
    /// The state is single-threaded: every entry point takes the engine lock (callers come from the
    /// zone threads, the network threads and LuaEngine's timer).
    /// </summary>
    sealed class XLuaEngine : ScriptEngine
    {
        internal readonly object Sync = new object();
        private readonly LuaEnv env;
        private readonly LuaFunction newScript, call, definedGlobals, coCreate, coResume;

        private const string Bootstrap = @"
local base = {}
for _, k in ipairs({
    'assert', 'collectgarbage', 'error', 'gcinfo', 'getmetatable', 'ipairs', 'next', 'pairs',
    'pcall', 'rawequal', 'rawget', 'rawset', 'select', 'setmetatable', 'tonumber', 'tostring',
    'type', 'unpack', 'xpcall', '_VERSION',
    'bit', 'coroutine', 'debug', 'io', 'jit', 'math', 'os', 'string', 'table',
}) do base[k] = _G[k] end

local stamp, log = ...

base.print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring((select(i, ...))) end
    log(table.concat(parts, '\t'))
end

-- path -> { stamp = file time, code = bytecode }
local compiled = {}
local function compile(path)
    local s = stamp(path)
    if not s then return nil, 'cannot open ' .. path end
    local c = compiled[path]
    if not c or c.stamp ~= s then
        local f, err = loadfile(path)
        if not f then return nil, err end
        c = { stamp = s, code = string.dump(f) }
        compiled[path] = c
    end
    return loadstring(c.code)
end

local function newEnv()
    local env = setmetatable({}, { __index = base })
    env._G = env
    local loaded = {}
    env.package = { loaded = loaded, path = './scripts/?;./scripts/?.lua' }
    -- Module names resolve as MoonSharp's loader did: dots become slashes, then ./scripts/?
    -- and ./scripts/?.lua. Modules run in the requiring script's environment, so their globals
    -- are that script's globals.
    env.require = function(name)
        local v = loaded[name]
        if v ~= nil then return v end
        local n = tostring(name):gsub('%.', '/')
        local path
        for _, p in ipairs({ './scripts/' .. n, './scripts/' .. n .. '.lua' }) do
            if stamp(p) then path = p; break end
        end
        if not path then error(""module '"" .. tostring(name) .. ""' not found"", 2) end
        local f, err = compile(path)
        if not f then error(err, 2) end
        setfenv(f, env)
        loaded[name] = true
        local r = f(name)
        if r ~= nil then loaded[name] = r end
        return loaded[name]
    end
    env.loadstring = function(s, chunk)
        local f, err = loadstring(s, chunk)
        if f then setfenv(f, env) end
        return f, err
    end
    env.load = env.loadstring
    env.dofile = function(path)
        local f, err = compile(path)
        if not f then error(err, 2) end
        return setfenv(f, env)()
    end
    return env
end

local function pack(...) return { n = select('#', ...), ... } end

-- What newEnv puts in every environment itself; not the script's own globals.
local provided = { _G = true, package = true, require = true, loadstring = true, load = true, dofile = true }

return base,
    -- newScript(path) -> env, error
    function(path)
        local env = newEnv()
        local f, err = compile(path)
        if not f then return env, err end
        setfenv(f, env)
        local ok, e = xpcall(f, debug.traceback)
        return env, (not ok) and e or nil
    end,
    -- call(env, name, ...) -> true, results... | false, error
    function(env, name, ...)
        local f = env[name]
        if type(f) ~= 'function' then return false, 'not a function: ' .. tostring(name) end
        return xpcall(f, debug.traceback, ...)
    end,
    -- definedGlobals(env) -> { name = lua type } for what the script defined
    function(env)
        local out = {}
        for k, v in pairs(env) do
            if type(k) == 'string' and not provided[k] then out[k] = type(v) end
        end
        return out
    end,
    -- coCreate(env, name) -> handle | nil. Threads go to C# inside a table.
    function(env, name)
        local f = env[name]
        if type(f) ~= 'function' then return nil end
        return { co = coroutine.create(f) }
    end,
    -- coResume(handle, ...) -> ok, suspended, values... | false, true, traceback
    function(h, ...)
        local co = h.co
        local r = pack(coroutine.resume(co, ...))
        if not r[1] then
            return false, true, debug.traceback(co, tostring(r[2]))
        end
        return true, coroutine.status(co) == 'suspended', unpack(r, 2, r.n)
    end
";

        public XLuaEngine()
        {
            env = new LuaEnv();
            Func<string, object> stamp = path =>
            {
                var info = new FileInfo(path);
                return info.Exists ? (object)(double)(info.LastWriteTimeUtc.Ticks / TimeSpan.TicksPerMillisecond) : null;
            };
            Action<string> log = s => Log.Debug(s);

            var init = env.LoadString(Bootstrap, "=meteor-bootstrap");
            object[] parts = init.Call(stamp, log);
            init.Dispose();

            using (var baseTable = (LuaTable)parts[0])
            {
                foreach (var g in Globals)
                    baseTable.Set(g.Key, g.Value);
            }
            newScript = (LuaFunction)parts[1];
            call = (LuaFunction)parts[2];
            definedGlobals = (LuaFunction)parts[3];
            coCreate = (LuaFunction)parts[4];
            coResume = (LuaFunction)parts[5];
        }

        public override string Name => "xlua";

        public override LuaScript Load(string path)
        {
            if (!File.Exists(path))
                return null;
            lock (Sync)
            {
                object[] r = newScript.Call(path);
                var scriptEnv = (LuaTable)r[0];
                string err = r.Length > 1 ? r[1] as string : null;
                if (err != null)
                    Log.Error("{0}: {1}", path, err);
                return new XLuaScript(this, scriptEnv, path, err);
            }
        }

        /// <summary>Releases Lua references whose C# wrappers were collected. LuaEngine's timer calls it.</summary>
        public void Tick()
        {
            lock (Sync)
                env.Tick();
        }

        internal object[] CallRaw(LuaTable scriptEnv, string name, object[] args)
        {
            var callArgs = new object[args.Length + 2];
            callArgs[0] = scriptEnv;
            callArgs[1] = name;
            Array.Copy(args, 0, callArgs, 2, args.Length);
            return call.Call(callArgs);
        }

        internal SortedDictionary<string, string> DefinedGlobals(LuaTable scriptEnv)
        {
            var result = new SortedDictionary<string, string>(StringComparer.Ordinal);
            if (ToClr(definedGlobals.Call(scriptEnv)[0]) is LuaTableValue t)
                foreach (var p in t.Pairs)
                    result[(string)p.Key] = (string)p.Value;
            return result;
        }

        internal LuaTable CreateCoroutine(LuaTable scriptEnv, string name)
        {
            object[] r = coCreate.Call(scriptEnv, name);
            return r.Length > 0 ? r[0] as LuaTable : null;
        }

        internal object[] ResumeRaw(LuaTable handle, object[] args)
        {
            var callArgs = new object[args.Length + 1];
            callArgs[0] = handle;
            Array.Copy(args, 0, callArgs, 1, args.Length);
            return coResume.Call(callArgs);
        }

        /// <summary>Converts a value xLua handed back to the engine-neutral form, releasing table and
        /// function references.</summary>
        internal static object ToClr(object v, int depth = 0)
        {
            switch (v)
            {
                case null:
                    return null;
                case double _:
                case string _:
                case bool _:
                    return v;
                case long l:
                    return (double)l;
                case int i:
                    return (double)i;
                case LuaTable t:
                    using (t)
                    {
                        var result = new LuaTableValue();
                        if (depth >= 16)
                            return result;
                        t.ForEach<object, object>((key, value) =>
                            result.Pairs.Add(new KeyValuePair<object, object>(ToClr(key, depth + 1), ToClr(value, depth + 1))));
                        return result;
                    }
                case LuaFunction f:
                    f.Dispose();
                    return LuaFunctionValue.Instance;
                default:
                    return v;
            }
        }

        internal static object[] ToClrList(object[] values, int from)
        {
            if (values == null || values.Length <= from)
                return LuaResume.None;
            var list = new object[values.Length - from];
            for (int i = 0; i < list.Length; i++)
                list[i] = ToClr(values[i + from]);
            return list;
        }
    }

    sealed class XLuaScript : LuaScript
    {
        private readonly XLuaEngine engine;
        private readonly LuaTable env;

        public XLuaScript(XLuaEngine engine, LuaTable env, string path, string loadError)
        {
            this.engine = engine;
            this.env = env;
            Path = path;
            LoadError = loadError;
        }

        public override SortedDictionary<string, string> DefinedGlobals()
        {
            lock (engine.Sync)
                return engine.DefinedGlobals(env);
        }

        public override bool HasFunction(string name)
        {
            lock (engine.Sync)
            {
                object v = env.Get<string, object>(name);
                if (v is LuaFunction f)
                {
                    f.Dispose();
                    return true;
                }
                XLuaEngine.ToClr(v);
                return false;
            }
        }

        public override object GetGlobal(string name)
        {
            lock (engine.Sync)
                return XLuaEngine.ToClr(env.Get<string, object>(name));
        }

        public override object[] Call(string name, params object[] args)
        {
            lock (engine.Sync)
            {
                if (!HasFunction(name))
                    return null;
                object[] r;
                try
                {
                    r = engine.CallRaw(env, name, args ?? LuaResume.None);
                }
                catch (LuaException e)
                {
                    Log.Error("{0} {1}: {2}", Path, name, e.Message);
                    return null;
                }
                if (r.Length == 0 || !(r[0] is bool ok) || !ok)
                {
                    Log.Error("{0} {1}: {2}", Path, name, r.Length > 1 ? r[1] : "error");
                    XLuaEngine.ToClrList(r, 1);
                    return null;
                }
                return XLuaEngine.ToClrList(r, 1);
            }
        }

        public override LuaCoroutine CreateCoroutine(string name)
        {
            lock (engine.Sync)
            {
                LuaTable handle = engine.CreateCoroutine(env, name);
                return handle == null ? null : new XLuaCoroutine(engine, handle, Path + " " + name);
            }
        }
    }

    sealed class XLuaCoroutine : LuaCoroutine
    {
        private readonly XLuaEngine engine;
        private readonly LuaTable handle;
        private readonly string where;
        private bool dead;

        public XLuaCoroutine(XLuaEngine engine, LuaTable handle, string where)
        {
            this.engine = engine;
            this.handle = handle;
            this.where = where;
        }

        public override bool IsDead => dead;

        public override LuaResume Resume(params object[] args)
        {
            lock (engine.Sync)
            {
                if (dead)
                    throw new LuaScriptException(where + ": cannot resume dead coroutine");
                object[] r;
                try
                {
                    r = engine.ResumeRaw(handle, args ?? LuaResume.None);
                }
                catch (LuaException e)
                {
                    dead = true;
                    throw new LuaScriptException(where + ": " + e.Message, e);
                }
                bool ok = r.Length > 0 && r[0] is bool b && b;
                bool suspended = r.Length > 1 && r[1] is bool s && s;
                if (!ok)
                {
                    dead = true;
                    throw new LuaScriptException(r.Length > 2 ? r[2] as string : where + ": error");
                }
                if (!suspended)
                    dead = true;
                return new LuaResume(XLuaEngine.ToClrList(r, 2), suspended);
            }
        }
    }
}
