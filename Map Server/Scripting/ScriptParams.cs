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
using System.Globalization;
using Meteor.Common;
using Meteor.Map.lua;
using XLua;

namespace Meteor.Map.Scripting
{
    // A Lua function kept by the script runtime. The runtime swaps each function in a table handed
    // to C# for { __cb = id } and frees the id when its owner ends.
    sealed class ScriptCallback
    {
        public int Id { get; }

        public ScriptCallback(int id)
        {
            Id = id;
        }

        public object[] Invoke(params object[] args)
        {
            var all = new object[args.Length + 1];
            all[0] = Id;
            Array.Copy(args, 0, all, 1, args.Length);
            return ScriptRuntime.Instance.Call("rt_invoke", all) ?? LuaResume.None;
        }

        public bool Test(params object[] args)
        {
            var r = Invoke(args);
            return r.Length > 0 && r[0] is bool b && b;
        }
    }

    // Behavior and content parameters from a Lua table.
    sealed class ScriptParams
    {
        public static readonly ScriptParams Empty = new ScriptParams();

        private readonly Dictionary<string, object> map = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        private readonly List<object> list = new List<object>();

        public IReadOnlyList<object> List => list;
        public IEnumerable<string> Keys => map.Keys;

        public ScriptParams() { }

        public static ScriptParams From(object value)
        {
            if (value is ScriptParams p)
                return p;
            if (value is LuaTable t)
                value = XLuaEngine.ToClr(t);
            var result = new ScriptParams();
            if (value is LuaTableValue tv)
            {
                foreach (var kv in tv.Pairs)
                {
                    if (kv.Key is double d && d == Math.Floor(d) && d >= 1)
                    {
                        int i = (int)d - 1;
                        while (result.list.Count <= i)
                            result.list.Add(null);
                        result.list[i] = Wrap(kv.Value);
                    }
                    else if (kv.Key != null)
                        result.map[Convert.ToString(kv.Key, CultureInfo.InvariantCulture)] = Wrap(kv.Value);
                }
            }
            return result;
        }

        private static object Wrap(object v)
        {
            if (v is LuaTableValue tv)
            {
                foreach (var kv in tv.Pairs)
                    if (kv.Key as string == "__cb" && kv.Value is double id)
                        return new ScriptCallback((int)id);
                return From(tv);
            }
            return v;
        }

        public bool Has(string key) => map.ContainsKey(key);

        public object Get(string key) => map.TryGetValue(key, out var v) ? v : null;

        public void Set(string key, object value) => map[key] = value;

        public void MergeFrom(ScriptParams other)
        {
            if (other == null)
                return;
            foreach (var kv in other.map)
                map[kv.Key] = kv.Value;
            for (int i = 0; i < other.list.Count; i++)
            {
                while (list.Count <= i)
                    list.Add(null);
                list[i] = other.list[i];
            }
        }

        public float Float(string key, float def = 0)
        {
            var v = Get(key);
            return v is double d ? (float)d : v is bool b ? (b ? 1 : 0) : def;
        }

        public int Int(string key, int def = 0)
        {
            var v = Get(key);
            return v is double d ? (int)d : def;
        }

        public bool Bool(string key, bool def = false)
        {
            var v = Get(key);
            return v is bool b ? b : v is double d ? d != 0 : def;
        }

        public string String(string key, string def = null)
        {
            var v = Get(key);
            return v is string s ? s : v is double d ? d.ToString(CultureInfo.InvariantCulture) : def;
        }

        public ScriptParams Table(string key) => Get(key) as ScriptParams;

        public ScriptCallback Callback(string key) => Get(key) as ScriptCallback;

        // A number, or { min, max }: a random value in the range.
        public float Range(string key, SeededRandom rng, float def)
        {
            var v = Get(key);
            if (v is double d)
                return (float)d;
            if (v is ScriptParams p && p.list.Count >= 2 && p.list[0] is double a && p.list[1] is double b)
                return (float)(rng?.Range(a, b) ?? (a + b) / 2);
            return def;
        }

        // { x, y, z } or { x = , y = , z = }.
        public Vector3 Point(string key)
        {
            return AsPoint(Get(key));
        }

        public static Vector3 AsPoint(object v)
        {
            if (v is Vector3 vec)
                return vec;
            if (v is ScriptParams p)
            {
                if (p.list.Count >= 3 && p.list[0] is double x && p.list[1] is double y && p.list[2] is double z)
                    return new Vector3((float)x, (float)y, (float)z);
                if (p.Has("x"))
                    return new Vector3(p.Float("x"), p.Float("y"), p.Float("z"));
            }
            return null;
        }

        public float Number(int index, float def = 0) => index < list.Count && list[index] is double d ? (float)d : def;
    }
}
