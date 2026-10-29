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
    // Runs scripts on LuaJIT through xLua. One Lua instance serves every script. Each loaded script
    // gets its own set of globals; anything it doesn't set itself (the standard Lua libraries and the
    // server functions such as GetWorldManager) is looked up in a shared set. A script file is
    // compiled once and reused until the file changes on disk.
    // Lua can only run one thing at a time, and scripts are started from several threads (zone
    // updates, incoming packets, the wait timer), so every method here takes the Sync lock first.
    // Sync is the world's zone lock: the zone update already holds it while it runs mob scripts,
    // and a script often asks the world for a zone or actor, which takes that same lock. With two
    // separate locks, a script on one thread and a zone update on another could each end up
    // waiting for the other's lock forever.
    sealed class XLuaEngine : ScriptEngine
    {
        internal object Sync => WorldManager.ZoneLock;
        private readonly LuaEnv env;
        private readonly LuaFunction newScript, call, definedGlobals, coCreate, coResume;

        private const string Bootstrap = @"
local base = {}
for _, k in ipairs({
    'assert', 'collectgarbage', 'error', 'gcinfo', 'getfenv', 'getmetatable', 'ipairs', 'next', 'pairs',
    'pcall', 'rawequal', 'rawget', 'rawset', 'select', 'setmetatable', 'tonumber', 'tostring',
    'setfenv', 'type', 'unpack', 'xpcall', '_VERSION',
    'bit', 'coroutine', 'debug', 'io', 'jit', 'math', 'os', 'string', 'table',
}) do base[k] = _G[k] end

-- Arguments from C#: stamp(path) gives the file's last-modified time (nil if it doesn't exist),
-- log(text) writes to the server log, root is the scripts folder (script_path in the config).
local stamp, log, root = ...

base.print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring((select(i, ...))) end
    log(table.concat(parts, '\t'))
end

-- Compiled scripts by path, with the file time they were compiled from.
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
    env.package = { loaded = loaded, path = root .. '/?;' .. root .. '/?.lua' }
    -- require('battle.actions') loads <root>/battle/actions or <root>/battle/actions.lua.
    -- The file runs with the requiring script's globals, so what it defines becomes part of that
    -- script, and it runs only once per script.
    env.require = function(name)
        local v = loaded[name]
        if v ~= nil then return v end
        local n = tostring(name):gsub('%.', '/')
        local path
        for _, p in ipairs({ root .. '/' .. n, root .. '/' .. n .. '.lua' }) do
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

-- Globals newEnv gives every script; DefinedGlobals leaves them out.
local provided = { _G = true, package = true, require = true, loadstring = true, load = true, dofile = true }

return base,
    -- newScript(path): runs the file in a new set of globals. Returns the globals and any error.
    function(path)
        local env = newEnv()
        local f, err = compile(path)
        if not f then return env, err end
        setfenv(f, env)
        local ok, e = xpcall(f, debug.traceback)
        return env, (not ok) and e or nil
    end,
    -- call(env, name, ...): calls a script function. Returns true and its results, false and
    -- the error with the script line it happened on, or nil if there is no such function.
    function(env, name, ...)
        local f = env[name]
        if type(f) ~= 'function' then return nil end
        return xpcall(f, debug.traceback, ...)
    end,
    -- definedGlobals(env): the names the script defined, with their Lua type.
    function(env)
        local out = {}
        for k, v in pairs(env) do
            if type(k) == 'string' and not provided[k] then out[k] = type(v) end
        end
        return out
    end,
    -- coCreate(env, name): prepares a script function as a coroutine. It is returned inside a
    -- table because xLua cannot hand a coroutine to C# directly.
    function(env, name)
        local f = env[name]
        if type(f) ~= 'function' then return nil end
        return { co = coroutine.create(f) }
    end,
    -- coResume(handle, ...): runs the coroutine until it pauses or ends. Returns true, whether it
    -- paused, and the values it paused or ended with; or false, true and the error.
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
            object[] parts = init.Call(stamp, log, ConfigConstants.OPTIONS_SCRIPTPATH ?? "./scripts");
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

        // Frees Lua values whose C# handles have been garbage collected. LuaEngine's timer
        // calls this every 50 ms.
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

        // Converts a value from Lua into the form described on ScriptEngine. Lua tables and
        // functions are copied or replaced, and xLua's handle to them is freed.
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

        // Frees xLua's handles among values that are not needed.
        internal static void Release(object[] values)
        {
            foreach (object v in values)
                (v as LuaBase)?.Dispose();
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
                (v as LuaBase)?.Dispose();
                return v is LuaFunction;
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
                if (r.Length == 0 || r[0] == null)
                    return null;
                if (!(r[0] is bool ok) || !ok)
                {
                    Log.Error("{0} {1}: {2}", Path, name, r.Length > 1 ? r[1] : "error");
                    XLuaEngine.Release(r);
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
                    throw new LuaScriptException(where + ": the function has already ended");
                object[] r;
                try
                {
                    r = engine.ResumeRaw(handle, args ?? LuaResume.None);
                }
                catch (LuaException e)
                {
                    End();
                    throw new LuaScriptException(where + ": " + e.Message, e);
                }
                bool ok = r.Length > 0 && r[0] is bool b && b;
                bool suspended = r.Length > 1 && r[1] is bool s && s;
                if (!ok)
                {
                    End();
                    throw new LuaScriptException(r.Length > 2 ? r[2] as string : where + ": error");
                }
                if (!suspended)
                    End();
                return new LuaResume(XLuaEngine.ToClrList(r, 2), suspended);
            }
        }

        // Frees the Lua side as soon as the function is over, rather than when .NET collects this.
        private void End()
        {
            dead = true;
            handle.Dispose();
        }
    }
}
