using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using Meteor.Map.Actors;
using Meteor.Map.DataObjects;
using Meteor.Map.lua;
using Newtonsoft.Json.Linq;

namespace Meteor.Map.admin
{
    // Reads and writes live server objects. A target names the root: server, world, lua, gmdebug,
    // worldconn, session:ID, player:NAME|ID, actor:ID, zone:ID or type:Full.Type.Name (static members).
    // A path walks fields and properties (private ones too), [key] indexers and no-argument calls,
    // e.g. zoneList[128].mActorList or GetPlayers()[0].positionX.
    static class AdminInspector
    {
        const BindingFlags MemberFlags = BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly;
        static readonly Regex Segment = new Regex(@"\G(?:\.?([A-Za-z_][A-Za-z0-9_]*)(\(\))?|\[([^\]]*)\])");

        public class StaticRoot
        {
            public Type type;
            public StaticRoot(Type t) { type = t; }
        }

        public static object ResolveTarget(string target)
        {
            if (string.IsNullOrEmpty(target))
                throw new ArgumentException("target is required");
            string kind = target, arg = null;
            int colon = target.IndexOf(':');
            if (colon >= 0)
            {
                kind = target.Substring(0, colon);
                arg = target.Substring(colon + 1);
            }
            switch (kind.ToLowerInvariant())
            {
                case "server": return Server.GetServer();
                case "world": return Server.GetWorldManager();
                case "lua": return LuaEngine.GetInstance();
                case "worldconn": return Server.GetWorldConnection();
                case "session":
                    return Server.GetServer().GetSession(ParseUInt(arg)) ?? throw new KeyNotFoundException("no session " + arg);
                case "player":
                    return AdminServer.FindPlayer(arg) ?? throw new KeyNotFoundException("no player " + arg);
                case "actor":
                    return AdminServer.FindActor(ParseUInt(arg)) ?? throw new KeyNotFoundException("no actor " + arg);
                case "zone":
                    return (Server.GetWorldManager().GetArea(ParseUInt(arg)) as Meteor.Map.actors.area.Zone) ?? throw new KeyNotFoundException("no zone " + arg);
                case "type":
                    Type t = typeof(AdminInspector).Assembly.GetType(arg) ?? typeof(Meteor.Common.SubPacket).Assembly.GetType(arg)
                        ?? throw new KeyNotFoundException("no type " + arg);
                    return new StaticRoot(t);
                default:
                    throw new ArgumentException("unknown target kind '" + kind + "'");
            }
        }

        // Walks the path; returns the final value plus the parent/member for writes.
        public static object Walk(object root, string path, out object parent, out MemberInfo member)
        {
            parent = null;
            member = null;
            object cur = root;
            if (string.IsNullOrWhiteSpace(path))
                return cur;

            int pos = 0;
            while (pos < path.Length)
            {
                Match m = Segment.Match(path, pos);
                if (!m.Success || m.Length == 0)
                    throw new ArgumentException("bad path near '" + path.Substring(pos) + "'");
                pos += m.Length;
                if (cur == null)
                    throw new NullReferenceException("null before '" + m.Value + "'");

                parent = cur;
                if (m.Groups[3].Success)
                {
                    member = null;
                    cur = Index(cur, m.Groups[3].Value.Trim().Trim('"', '\''));
                }
                else if (m.Groups[2].Success)
                {
                    member = null;
                    cur = CallNoArgs(cur, m.Groups[1].Value);
                }
                else
                {
                    cur = GetMember(cur, m.Groups[1].Value, out member);
                }
            }
            return cur;
        }

        static IEnumerable<Type> Hierarchy(Type t)
        {
            for (; t != null; t = t.BaseType)
                yield return t;
        }

        static object GetMember(object obj, string name, out MemberInfo member)
        {
            bool isStatic = obj is StaticRoot;
            Type type = isStatic ? ((StaticRoot)obj).type : obj.GetType();
            object instance = isStatic ? null : obj;
            foreach (Type t in Hierarchy(type))
            {
                FieldInfo f = t.GetField(name, MemberFlags) ?? t.GetField("<" + name + ">k__BackingField", MemberFlags);
                if (f != null)
                {
                    member = f;
                    return f.GetValue(f.IsStatic ? null : instance);
                }
                PropertyInfo p = t.GetProperty(name, MemberFlags);
                if (p != null && p.GetIndexParameters().Length == 0)
                {
                    member = p;
                    return p.GetValue(p.GetMethod.IsStatic ? null : instance);
                }
            }
            throw new MissingMemberException(type.Name + " has no field/property '" + name + "'");
        }

        static object CallNoArgs(object obj, string name)
        {
            bool isStatic = obj is StaticRoot;
            Type type = isStatic ? ((StaticRoot)obj).type : obj.GetType();
            foreach (Type t in Hierarchy(type))
            {
                MethodInfo mi = t.GetMethods(MemberFlags).FirstOrDefault(x => x.Name == name && x.GetParameters().Length == 0 && !x.IsGenericMethodDefinition);
                if (mi != null)
                    return mi.Invoke(mi.IsStatic ? null : obj, null);
            }
            throw new MissingMethodException(type.Name + " has no zero-arg method '" + name + "'");
        }

        static object Index(object obj, string key)
        {
            if (obj is IDictionary dict)
            {
                foreach (DictionaryEntry e in dict)
                    if (KeyMatches(e.Key, key))
                        return e.Value;
                throw new KeyNotFoundException("key '" + key + "' not found (" + dict.Count + " entries)");
            }
            int idx = (int)ParseUInt(key);
            if (obj is IList list)
                return list[idx];
            if (obj is IEnumerable en)
                return en.Cast<object>().ElementAt(idx);
            throw new ArgumentException(obj.GetType().Name + " is not indexable");
        }

        static bool KeyMatches(object k, string key)
        {
            if (k == null)
                return false;
            if (string.Equals(k.ToString(), key, StringComparison.OrdinalIgnoreCase))
                return true;
            if (k is IConvertible && !(k is string) && TryParseULong(key, out ulong n))
            {
                try { return System.Convert.ToUInt64(k) == n; } catch { return false; }
            }
            return false;
        }

        public static object SetValue(object root, string path, JToken value)
        {
            object parent;
            MemberInfo member;
            Walk(root, path, out parent, out member);
            if (member == null)
                throw new ArgumentException("path must end in a field or property");
            object instance = parent is StaticRoot ? null : parent;
            if (member is FieldInfo f)
            {
                if (f.IsLiteral || f.IsInitOnly)
                    throw new InvalidOperationException(f.Name + " is const/readonly");
                f.SetValue(instance, Convert(value, f.FieldType));
                return f.GetValue(instance);
            }
            var p = (PropertyInfo)member;
            if (!p.CanWrite)
                throw new InvalidOperationException(p.Name + " has no setter");
            p.SetValue(instance, Convert(value, p.PropertyType));
            return p.GetValue(instance);
        }

        public static object Convert(JToken value, Type type)
        {
            if (value == null || value.Type == JTokenType.Null)
                return null;
            Type t = Nullable.GetUnderlyingType(type) ?? type;
            if (value.Type == JTokenType.String)
            {
                string s = value.ToString();
                if (t.IsEnum)
                    return TryParseULong(s, out ulong ev) ? Enum.ToObject(t, ev) : Enum.Parse(t, s, true);
                if (TryParseULong(s, out ulong n))
                {
                    object i = CastInteger(n, t);
                    if (i != null)
                        return i;
                }
            }
            return value.ToObject(t);
        }

        // Unchecked integer cast so "0xFFFFFFFF" fits an int, etc. Null for non-integer types.
        static object CastInteger(ulong n, Type t)
        {
            unchecked
            {
                if (t == typeof(byte)) return (byte)n;
                if (t == typeof(sbyte)) return (sbyte)n;
                if (t == typeof(short)) return (short)n;
                if (t == typeof(ushort)) return (ushort)n;
                if (t == typeof(int)) return (int)n;
                if (t == typeof(uint)) return (uint)n;
                if (t == typeof(long)) return (long)n;
                if (t == typeof(ulong)) return n;
            }
            return null;
        }

        public class DumpOptions
        {
            public int depth = 2;
            public int maxItems = 50;
            public int maxBytes = 256;
        }

        public static JToken Dump(object o, DumpOptions opt)
        {
            return Dump(o, opt.depth, opt, new HashSet<object>(ReferenceEqualityComparer.Instance));
        }

        static bool IsScalar(Type t)
        {
            return t.IsPrimitive || t.IsEnum || t == typeof(string) || t == typeof(decimal) || t == typeof(DateTime) || t == typeof(TimeSpan) || t == typeof(Guid);
        }

        static JToken Scalar(object o)
        {
            switch (o)
            {
                case Enum e: return e.ToString() + " (" + System.Convert.ToInt64(e).ToString(CultureInfo.InvariantCulture) + ")";
                case DateTime d: return d.ToString("o");
                case TimeSpan ts: return ts.ToString();
                case Guid g: return g.ToString();
                case float f when float.IsNaN(f) || float.IsInfinity(f): return f.ToString(CultureInfo.InvariantCulture);
                case double d2 when double.IsNaN(d2) || double.IsInfinity(d2): return d2.ToString(CultureInfo.InvariantCulture);
                default: return JToken.FromObject(o);
            }
        }

        public static JObject Ref(object o)
        {
            var r = new JObject { ["$type"] = o.GetType().Name };
            switch (o)
            {
                case Actor a:
                    r["$ref"] = "actor:" + AdminCapture.Hex(a.Id, 8);
                    r["actorName"] = a.Name;
                    if (!string.IsNullOrEmpty(a.DisplayName))
                        r["customDisplayName"] = a.DisplayName;
                    break;
                case Session s:
                    r["$ref"] = "session:" + AdminCapture.Hex(s.id, 8);
                    break;
                default:
                    string str = SafeToString(o);
                    if (str != null && str != o.GetType().FullName && str != o.GetType().ToString())
                        r["$str"] = str;
                    if (o is ICollection c)
                        r["$count"] = c.Count;
                    break;
            }
            return r;
        }

        static string SafeToString(object o)
        {
            try { return o.ToString(); } catch { return null; }
        }

        static JToken Dump(object o, int depth, DumpOptions opt, HashSet<object> seen)
        {
            if (o == null)
                return JValue.CreateNull();
            Type t = o.GetType();
            if (IsScalar(t))
                return Scalar(o);
            if (o is StaticRoot sr)
                return DumpMembers(null, sr.type, depth, opt, seen, true);
            if (o is byte[] bytes)
                return AdminCapture.ToHex(bytes, opt.maxBytes);
            if (o is Delegate del)
                return "delegate " + del.Method.DeclaringType?.Name + "." + del.Method.Name;
            if (o is Type ty)
                return "type " + ty.FullName;
            if (o is LuaTableValue lt)
                return new JArray(lt.Pairs.Select(pair => new JArray(Dump(pair.Key, depth - 1, opt, seen), Dump(pair.Value, depth - 1, opt, seen))));

            bool valueType = t.IsValueType;
            if (!valueType && (depth <= 0 || seen.Contains(o)))
                return Ref(o);
            if (!valueType)
                seen.Add(o);

            try
            {
                if (o is IDictionary dict)
                {
                    var jo = new JObject { ["$type"] = FriendlyName(t), ["$count"] = dict.Count };
                    int n = 0;
                    // Generic dictionaries enumerate KeyValuePair, not DictionaryEntry, so read them through Keys.
                    foreach (object k in dict.Keys.Cast<object>().ToList())
                    {
                        if (n++ >= opt.maxItems) { jo["$truncated"] = true; break; }
                        string key = IsInteger(k) && !(k is sbyte || k is short || k is int || k is long)
                            ? k + " (" + AdminCapture.Hex(System.Convert.ToUInt64(k), 0) + ")"
                            : SafeToString(k);
                        jo[key ?? "null"] = Dump(dict[k], depth - 1, opt, seen);
                    }
                    return jo;
                }
                if (o is IEnumerable en)
                {
                    var arr = new JArray();
                    int n = 0, total = 0;
                    foreach (object item in en.Cast<object>().ToList())
                    {
                        total++;
                        if (n < opt.maxItems) { arr.Add(Dump(item, depth - 1, opt, seen)); n++; }
                    }
                    if (total > n)
                        arr.Add("... " + (total - n) + " more (" + total + " total)");
                    return arr;
                }
                return DumpMembers(o, t, depth, opt, seen, false);
            }
            finally
            {
                if (!valueType)
                    seen.Remove(o);
            }
        }

        static bool IsInteger(object o)
        {
            return o is byte || o is sbyte || o is short || o is ushort || o is int || o is uint || o is long || o is ulong;
        }

        static JObject DumpMembers(object o, Type t, int depth, DumpOptions opt, HashSet<object> seen, bool staticOnly)
        {
            var jo = new JObject { ["$type"] = FriendlyName(t) };
            foreach (Type ht in Hierarchy(t).Reverse())
            {
                foreach (FieldInfo f in ht.GetFields(MemberFlags))
                {
                    if (f.IsStatic != staticOnly || f.IsLiteral && !staticOnly)
                        continue;
                    if (f.IsDefined(typeof(CompilerGeneratedAttribute)) && !f.Name.EndsWith("k__BackingField"))
                        continue;
                    string name = f.Name.StartsWith("<") ? f.Name.Substring(1, f.Name.IndexOf('>') - 1) : f.Name;
                    if (jo.ContainsKey(name))
                        name = ht.Name + "." + name;
                    try { jo[name] = Dump(f.IsLiteral ? f.GetRawConstantValue() : f.GetValue(o), depth - 1, opt, seen); }
                    catch (Exception e) { jo[name] = "$error: " + e.GetBaseException().Message; }
                }
            }
            return jo;
        }

        static string FriendlyName(Type t)
        {
            if (!t.IsGenericType)
                return t.Name;
            string n = t.Name.Substring(0, t.Name.IndexOf('`'));
            return n + "<" + string.Join(",", t.GetGenericArguments().Select(FriendlyName)) + ">";
        }

        // A type's members, private ones too: what a path can name.
        public static JObject Describe(object o)
        {
            bool isStatic = o is StaticRoot;
            Type type = isStatic ? ((StaticRoot)o).type : o.GetType();
            var fields = new JArray();
            var props = new JArray();
            var methods = new JArray();
            foreach (Type ht in Hierarchy(type))
            {
                if (ht == typeof(object))
                    break;
                foreach (FieldInfo f in ht.GetFields(MemberFlags))
                    if (!f.IsDefined(typeof(CompilerGeneratedAttribute)))
                        fields.Add((f.IsStatic ? "static " : "") + FriendlyName(f.FieldType) + " " + f.Name + (ht != type ? "  [" + ht.Name + "]" : ""));
                foreach (PropertyInfo p in ht.GetProperties(MemberFlags))
                    props.Add(FriendlyName(p.PropertyType) + " " + p.Name + (ht != type ? "  [" + ht.Name + "]" : ""));
                foreach (MethodInfo m in ht.GetMethods(MemberFlags))
                {
                    if (m.IsSpecialName || m.IsDefined(typeof(CompilerGeneratedAttribute)))
                        continue;
                    methods.Add((m.IsStatic ? "static " : "") + FriendlyName(m.ReturnType) + " " + m.Name + "(" +
                        string.Join(", ", m.GetParameters().Select(p => FriendlyName(p.ParameterType) + " " + p.Name)) + ")" + (ht != type ? "  [" + ht.Name + "]" : ""));
                }
            }
            return new JObject { ["$type"] = type.FullName, ["fields"] = fields, ["properties"] = props, ["methods"] = methods };
        }

        public static bool TryParseULong(string s, out ulong v)
        {
            v = 0;
            if (string.IsNullOrWhiteSpace(s))
                return false;
            s = s.Trim();
            if (s.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
                return ulong.TryParse(s.Substring(2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out v);
            if (s.StartsWith("-") && long.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, out long neg))
            {
                v = unchecked((ulong)neg);
                return true;
            }
            return ulong.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, out v);
        }

        public static uint ParseUInt(string s)
        {
            if (!TryParseULong(s, out ulong v))
                throw new FormatException("not a number: '" + s + "'");
            return unchecked((uint)v);
        }
    }
}
