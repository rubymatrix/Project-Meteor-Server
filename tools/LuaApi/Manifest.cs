using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Meteor.Tools.LuaApi;

sealed class ApiParam { public string Name { get; set; } = ""; public string Type { get; set; } = ""; public bool Optional { get; set; } public bool Params { get; set; } }

sealed class ApiMethod
{
    public string Name { get; set; } = "";
    public bool Static { get; set; }
    public string Returns { get; set; } = "";
    public List<ApiParam> Params { get; set; } = new();
}

sealed class ApiMember { public string Name { get; set; } = ""; public string Type { get; set; } = ""; public bool Static { get; set; } public bool Writable { get; set; } }

sealed class ApiType
{
    public string Name { get; set; } = "";
    public string FullName { get; set; } = "";
    public string? Base { get; set; }
    public bool Enum { get; set; }
    public List<string>? EnumValues { get; set; }
    public List<ApiMember> Members { get; set; } = new();
    public List<ApiMethod> Methods { get; set; } = new();
}

sealed class ApiGlobal { public string Name { get; set; } = ""; public string Returns { get; set; } = ""; public List<ApiParam> Params { get; set; } = new(); }

sealed class ApiManifest
{
    public List<ApiGlobal> Globals { get; set; } = new();
    public List<ApiType> Types { get; set; } = new();

    static readonly JsonSerializerOptions Json = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingDefault,
    };

    public string ToJson() => JsonSerializer.Serialize(this, Json) + "\n";
    public static ApiManifest FromJson(string json) => JsonSerializer.Deserialize<ApiManifest>(json, Json)!;

    // Name indexes the linter uses. A name is "instance-only" when no type declares a static of that name.
    [JsonIgnore] public HashSet<string> AllMemberNames => all ??= Types.SelectMany(t => t.Members.Select(m => m.Name).Concat(t.Methods.Select(m => m.Name))).ToHashSet(StringComparer.Ordinal);
    [JsonIgnore] public HashSet<string> MethodNames => methods ??= Types.SelectMany(t => t.Methods.Select(m => m.Name)).ToHashSet(StringComparer.Ordinal);
    [JsonIgnore] public HashSet<string> StaticNames => statics ??= Types.SelectMany(t => t.Methods.Where(m => m.Static).Select(m => m.Name).Concat(t.Members.Where(m => m.Static).Select(m => m.Name))).ToHashSet(StringComparer.Ordinal);
    [JsonIgnore] public HashSet<string> GlobalNames => globals ??= Globals.Select(g => g.Name).ToHashSet(StringComparer.Ordinal);
    HashSet<string>? all, methods, statics, globals;
}

/// <summary>Builds the manifest from the map server assembly: every type the engine can hand to Lua
/// (all Meteor types; MoonSharp and xLua both expose public members by reflection).</summary>
static class ManifestBuilder
{
    // Members every object inherits from System.Object. Lua never needs them; leaving them out keeps
    // the manifest about the server's own API.
    static readonly HashSet<string> ObjectMembers = new() { "ToString", "GetHashCode", "Equals", "GetType", "ReferenceEquals", "MemberwiseClone", "Finalize" };

    public static ApiManifest Build(string repoRoot)
    {
        var asm = Assembly.Load("Map Server");
        var assemblies = new[] { asm }.Concat(asm.GetReferencedAssemblies()
            .Where(a => a.Name == "Common Class Lib").Select(Assembly.Load)).ToList();

        var types = assemblies.SelectMany(LoadableTypes)
            .Where(t => t.Namespace != null && t.Namespace.StartsWith("Meteor", StringComparison.Ordinal))
            .Where(t => !t.Name.Contains('<') && !typeof(Delegate).IsAssignableFrom(t) && !t.IsGenericTypeDefinition)
            .Where(t => !IsCompilerGenerated(t))
            .ToList();

        // Short names collide across namespaces (e.g. two Command types); qualify only those.
        var collisions = types.GroupBy(t => t.Name).Where(g => g.Count() > 1).Select(g => g.Key).ToHashSet();
        string LuaName(Type t) => collisions.Contains(t.Name) ? t.FullName!.Replace('+', '.') : t.Name;
        var known = types.ToDictionary(t => t, LuaName);

        var manifest = new ApiManifest();
        foreach (var t in types.OrderBy(t => t.FullName, StringComparer.Ordinal))
        {
            var at = new ApiType { Name = known[t], FullName = t.FullName!.Replace('+', '.') };
            if (t.IsEnum)
            {
                at.Enum = true;
                at.EnumValues = Enum.GetNames(t).ToList();
                manifest.Types.Add(at);
                continue;
            }
            if (t.BaseType != null && known.TryGetValue(t.BaseType, out var bn)) at.Base = bn;

            const BindingFlags flags = BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;
            foreach (var f in t.GetFields(flags).Where(f => !f.IsSpecialName).OrderBy(f => f.Name, StringComparer.Ordinal))
                at.Members.Add(new ApiMember { Name = f.Name, Type = TypeName(f.FieldType, known), Static = f.IsStatic, Writable = !f.IsInitOnly && !f.IsLiteral });
            foreach (var p in t.GetProperties(flags).Where(p => p.GetIndexParameters().Length == 0).OrderBy(p => p.Name, StringComparer.Ordinal))
            {
                var getter = p.GetGetMethod();
                if (getter == null) continue;
                at.Members.Add(new ApiMember { Name = p.Name, Type = TypeName(p.PropertyType, known), Static = getter.IsStatic, Writable = p.GetSetMethod() != null });
            }
            foreach (var m in t.GetMethods(flags).Where(m => !m.IsSpecialName && !ObjectMembers.Contains(m.Name))
                         .OrderBy(m => m.Name, StringComparer.Ordinal).ThenBy(m => m.GetParameters().Length).ThenBy(m => string.Join(",", m.GetParameters().Select(p => p.ParameterType.FullName)), StringComparer.Ordinal))
            {
                at.Methods.Add(new ApiMethod
                {
                    Name = m.Name,
                    Static = m.IsStatic,
                    Returns = TypeName(m.ReturnType, known),
                    Params = m.GetParameters().Select(p => new ApiParam
                    {
                        Name = p.Name ?? "arg",
                        Type = TypeName(p.ParameterType, known),
                        Optional = p.IsOptional,
                        Params = p.IsDefined(typeof(ParamArrayAttribute)),
                    }).ToList(),
                });
            }
            manifest.Types.Add(at);
        }

        manifest.Globals = GlobalsFromEngine(repoRoot);
        return manifest;
    }

    /// <summary>The functions the engine installs as Lua globals (LuaEngine.LoadGlobals). Read from the
    /// source, since they are delegates assigned at script creation, not reflectable members.</summary>
    static List<ApiGlobal> GlobalsFromEngine(string repoRoot)
    {
        var src = File.ReadAllText(Path.Combine(repoRoot, "Map Server", "Lua", "LuaEngine.cs"));
        var re = new System.Text.RegularExpressions.Regex(@"Globals\[""(\w+)""\]\s*=\s*\((?:System\.)?(Func|Action)<?([^>)]*)>?\)");
        var list = new List<ApiGlobal>();
        foreach (System.Text.RegularExpressions.Match m in re.Matches(src))
        {
            var args = m.Groups[3].Value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();
            string ret = "nil";
            if (m.Groups[2].Value == "Func" && args.Count > 0) { ret = LuaPrim(args[^1]); args.RemoveAt(args.Count - 1); }
            list.Add(new ApiGlobal
            {
                Name = m.Groups[1].Value,
                Returns = ret,
                Params = args.Select((a, i) => new ApiParam { Name = "arg" + (i + 1), Type = LuaPrim(a) }).ToList(),
            });
        }
        return list.GroupBy(g => g.Name).Select(g => g.First()).OrderBy(g => g.Name, StringComparer.Ordinal).ToList();
    }

    static string LuaPrim(string cs) => cs switch
    {
        "bool" => "boolean",
        "string" => "string",
        "int" or "uint" or "short" or "ushort" or "byte" or "sbyte" or "long" or "ulong" or "float" or "double" => "number",
        _ => cs.Split('.').Last(),
    };

    static string TypeName(Type t, Dictionary<Type, string> known)
    {
        if (t.IsByRef) t = t.GetElementType()!;
        var u = Nullable.GetUnderlyingType(t);
        if (u != null) return TypeName(u, known) + "?";
        if (t == typeof(void)) return "nil";
        if (t == typeof(bool)) return "boolean";
        if (t == typeof(string) || t == typeof(char)) return "string";
        if (t.IsPrimitive || t == typeof(decimal)) return "number";
        if (known.TryGetValue(t, out var n)) return n;
        if (t.IsArray) return TypeName(t.GetElementType()!, known) + "[]";
        if (t.IsGenericType)
        {
            var def = t.GetGenericTypeDefinition();
            var args = t.GetGenericArguments();
            if (def == typeof(List<>) || def == typeof(IList<>) || def == typeof(IEnumerable<>) || def == typeof(HashSet<>) || def == typeof(ICollection<>) || def == typeof(IReadOnlyList<>))
                return TypeName(args[0], known) + "[]";
            if (def == typeof(Dictionary<,>) || def == typeof(IDictionary<,>) || def == typeof(IReadOnlyDictionary<,>))
                return $"table<{TypeName(args[0], known)}, {TypeName(args[1], known)}>";
            if (known.TryGetValue(def, out var gn)) return gn;
        }
        return "any";
    }

    static bool IsCompilerGenerated(Type t) =>
        t.IsDefined(typeof(System.Runtime.CompilerServices.CompilerGeneratedAttribute), false) || (t.DeclaringType != null && IsCompilerGenerated(t.DeclaringType));

    static IEnumerable<Type> LoadableTypes(Assembly a)
    {
        try { return a.GetTypes(); }
        catch (ReflectionTypeLoadException e) { return e.Types.Where(t => t != null)!; }
    }

    /// <summary>lua-language-server definitions (---@meta) for editor completion and `--check` in CI.</summary>
    public static string ToLuaLs(ApiManifest m)
    {
        var sb = new StringBuilder();
        sb.AppendLine("---@meta");
        sb.AppendLine("-- Generated by tools/LuaApi from the map server's types. Do not edit; run");
        sb.AppendLine("-- `dotnet run --project tools/LuaApi -- manifest` after changing C# that scripts use.");
        sb.AppendLine();
        foreach (var g in m.Globals)
        {
            foreach (var p in g.Params) sb.AppendLine($"---@param {p.Name} {p.Type}");
            sb.AppendLine($"---@return {g.Returns}");
            sb.AppendLine($"function {g.Name}({string.Join(", ", g.Params.Select(p => p.Name))}) end");
            sb.AppendLine();
        }
        foreach (var t in m.Types)
        {
            string id = t.Name;
            if (t.Enum)
            {
                sb.AppendLine($"---@enum {id}");
                sb.AppendLine($"{LuaIdent(id)} = {{}}");
                sb.AppendLine();
                continue;
            }
            sb.AppendLine(t.Base != null ? $"---@class {id} : {t.Base}" : $"---@class {id}");
            foreach (var mem in t.Members)
                sb.AppendLine($"---@field {mem.Name} {mem.Type}");
            sb.AppendLine($"local {LuaIdent(id)} = {{}}");
            foreach (var group in t.Methods.GroupBy(x => x.Name))
            {
                var first = group.First();
                foreach (var overload in group.Skip(1))
                    sb.AppendLine($"---@overload fun({(overload.Static ? "" : "self: " + id + (overload.Params.Count > 0 ? ", " : ""))}{string.Join(", ", overload.Params.Select(Param))}): {overload.Returns}");
                foreach (var p in first.Params)
                    sb.AppendLine(p.Params ? $"---@param ... {Elem(p.Type)}" : $"---@param {SafeParam(p.Name)}{(p.Optional ? "?" : "")} {p.Type}");
                if (first.Returns != "nil") sb.AppendLine($"---@return {first.Returns}");
                string sep = first.Static ? "." : ":";
                sb.AppendLine($"function {LuaIdent(id)}{sep}{first.Name}({string.Join(", ", first.Params.Select(p => p.Params ? "..." : SafeParam(p.Name)))}) end");
            }
            sb.AppendLine();
        }
        return sb.ToString();

        static string Param(ApiParam p) => p.Params ? $"...: {Elem(p.Type)}" : $"{SafeParam(p.Name)}{(p.Optional ? "?" : "")}: {p.Type}";
        static string Elem(string type) => type.EndsWith("[]") ? type[..^2] : type;
    }

    static readonly HashSet<string> LuaKeywords = new() { "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while" };
    static string SafeParam(string n) => LuaKeywords.Contains(n) ? n + "_" : n;
    static string LuaIdent(string typeName) => "__" + typeName.Replace('.', '_');
}
