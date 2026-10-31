using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Meteor.Map.Actors;
using Meteor.Map.actors.chara;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.lua;
using Meteor.Map.packets.send.actor.battle;
using Xunit;
using Xunit.Abstractions;

namespace Meteor.Map.Tests.Formulas
{
    // The battle command rows as the server loads them: server_battle_commands.sql, then the monster
    // move seeds in Data/sql/seed in file order.
    internal static class CommandRows
    {
        private const string Columns = "id,name,classJob,lvl,requirements,mainTarget,validTarget,aoeType,aoeRange,aoeMinRange,aoeConeAngle,aoeRotateAngle,aoeTarget,basePotency,numHits,positionBonus,procRequirement,range,minRange,bestRange,rangeHeight,rangeWidth,statusId,statusDuration,statusChance,castType,castTime,recastTime,mpCost,tpCost,animationType,effectAnimation,modelAnimation,animationDuration,battleAnimation,validUser,comboId1,comboId2,comboStep,accuracyMod,worldMasterTextId,commandType,actionType,actionProperty,isRanged";
        private static readonly string[] Cols = Columns.Split(',');

        private static readonly Lazy<Dictionary<int, Dictionary<string, string>>> rows = new Lazy<Dictionary<int, Dictionary<string, string>>>(Load);

        public static IEnumerable<int> Ids => rows.Value.Keys.OrderBy(i => i);

        private static Dictionary<int, Dictionary<string, string>> Load()
        {
            var dir = EngineHarness.SeedDir();
            var all = new Dictionary<int, Dictionary<string, string>>();
            var files = new[] { Path.Combine(dir, "server_battle_commands.sql") }
                .Concat(Directory.GetFiles(Path.Combine(dir, "seed"), "seed_mobskill_*.sql")
                    .Where(f => !f.EndsWith("_rollback.sql", StringComparison.Ordinal))
                    .OrderBy(f => f, StringComparer.Ordinal));
            var update = new Regex(@"^UPDATE `?server_battle_commands`? SET (.+) WHERE `?id`? = (\d+);");
            var delete = new Regex(@"^DELETE FROM `?server_battle_commands`? WHERE `?id`? BETWEEN (\d+) AND (\d+)(?: AND `?id`? NOT IN \(([\d,]+)\))?;");
            foreach (var file in files)
            {
                foreach (var line in File.ReadLines(file))
                {
                    Match m;
                    if ((m = delete.Match(line)).Success)
                    {
                        int lo = int.Parse(m.Groups[1].Value), hi = int.Parse(m.Groups[2].Value);
                        var keep = m.Groups[3].Success ? m.Groups[3].Value.Split(',').Select(int.Parse).ToHashSet() : new HashSet<int>();
                        foreach (var id in all.Keys.Where(k => k >= lo && k <= hi && !keep.Contains(k)).ToList())
                            all.Remove(id);
                    }
                    else if ((m = update.Match(line)).Success)
                    {
                        var row = all[int.Parse(m.Groups[2].Value)];
                        foreach (var set in m.Groups[1].Value.Split(','))
                        {
                            var kv = set.Split('=');
                            row[kv[0].Trim().Trim('`')] = kv[1].Trim();
                        }
                    }
                    else if (line.StartsWith("INSERT", StringComparison.Ordinal))
                    {
                        int start = line.IndexOf("VALUES (", StringComparison.Ordinal);
                        var v = Split(line.Substring(start + 8, line.LastIndexOf(')') - start - 8));
                        var row = new Dictionary<string, string>();
                        for (int i = 0; i < Cols.Length && i < v.Count; i++)
                            row[Cols[i]] = v[i];
                        all[int.Parse(row["id"])] = row;
                    }
                }
            }
            return all;
        }

        private static List<string> Split(string s)
        {
            var parts = new List<string>();
            var cur = new System.Text.StringBuilder();
            bool quoted = false;
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (c == '\'')
                {
                    if (quoted && i + 1 < s.Length && s[i + 1] == '\'') { cur.Append('\''); i++; }
                    else quoted = !quoted;
                }
                else if (c == ',' && !quoted) { parts.Add(cur.ToString()); cur.Clear(); }
                else cur.Append(c);
            }
            parts.Add(cur.ToString());
            return parts;
        }

        // A fresh BattleCommand each call, so a test may change it.
        public static BattleCommand Get(int id)
        {
            var r = rows.Value[id];
            double D(string c) => double.Parse(r[c], CultureInfo.InvariantCulture);
            uint U(string c) => (uint)D(c);
            var cmd = new BattleCommand((ushort)id, r["name"])
            {
                job = (byte)U("classJob"),
                level = (byte)U("lvl"),
                requirements = (BattleCommandRequirements)U("requirements"),
                mainTarget = (ValidTarget)U("mainTarget"),
                validTarget = (ValidTarget)U("validTarget"),
                aoeType = (TargetFindAOEType)U("aoeType"),
                basePotency = (ushort)U("basePotency"),
                numHits = (byte)U("numHits"),
                positionBonus = (BattleCommandPositionBonus)U("positionBonus"),
                procRequirement = (BattleCommandProcRequirement)U("procRequirement"),
                range = (float)D("range"),
                minRange = (float)D("minRange"),
                rangeHeight = (int)D("rangeHeight"),
                rangeWidth = (int)D("rangeWidth"),
                statusId = U("statusId"),
                statusDuration = U("statusDuration"),
                statusChance = (float)D("statusChance"),
                castType = (byte)U("castType"),
                castTimeMs = U("castTime"),
                maxRecastTimeSeconds = U("recastTime"),
                mpCost = (short)D("mpCost"),
                tpCost = (short)D("tpCost"),
                animationType = (byte)U("animationType"),
                effectAnimation = (ushort)U("effectAnimation"),
                modelAnimation = (ushort)U("modelAnimation"),
                aoeRange = (float)D("aoeRange"),
                aoeMinRange = (float)D("aoeMinRange"),
                aoeConeAngle = (float)D("aoeConeAngle"),
                aoeRotateAngle = (float)D("aoeRotateAngle"),
                aoeTarget = (TargetFindAOETarget)U("aoeTarget"),
                battleAnimation = U("battleAnimation"),
                validUser = (BattleCommandValidUser)U("validUser"),
                comboStep = (short)D("comboStep"),
                commandType = (CommandType)U("commandType"),
                actionProperty = (ActionProperty)U("actionProperty"),
                actionType = (ActionType)U("actionType"),
                accuracyModifier = (float)D("accuracyMod"),
                worldMasterTextId = (ushort)U("worldMasterTextId"),
            };
            cmd.recastTimeMs = cmd.maxRecastTimeSeconds * 1000;
            cmd.comboNextCommandId[0] = (int)D("comboId1");
            cmd.comboNextCommandId[1] = (int)D("comboId2");
            return cmd;
        }

        public static string Folder(CommandType type) => type switch
        {
            CommandType.WeaponSkill => "weaponskill",
            CommandType.Ability => "ability",
            CommandType.Spell => "magic",
            _ => null,
        };

        public static bool IsMonster(BattleCommand c) => c.validUser == BattleCommandValidUser.Monster || (c.id >= 23000 && c.id < 24000);
    }

    // Runs every battle command's script on test actors: each must run without a script error, a move
    // that applies a status must name a real one and land it, and a monster move must hit in
    // proportion to the monster's own swing.
    [Collection("engines")]
    public sealed class EngineCommandSweepTests : EngineHarness
    {
        private readonly EngineFixture engines;
        private readonly ITestOutputHelper output;

        public EngineCommandSweepTests(EngineFixture engines, ITestOutputHelper output)
        {
            this.engines = engines;
            this.output = output;
        }

        public static IEnumerable<object[]> Commands =>
            CommandRows.Ids.Where(id => CommandRows.Folder(CommandRows.Get(id).commandType) != null).Select(id => new object[] { id });

        public static IEnumerable<object[]> StatusCommands =>
            CommandRows.Ids.Where(id => CommandRows.Get(id).statusId != 0 && CommandRows.Folder(CommandRows.Get(id).commandType) != null)
                .Select(id => new object[] { id });

        // Field monster moves: the shared Default script at the seed's neutral potency. Primal moves have
        // their own scripts and potencies, fit to their fights.
        public static IEnumerable<object[]> MonsterDamageMoves =>
            CommandRows.Ids.Select(CommandRows.Get)
                .Where(c => CommandRows.IsMonster(c) && c.tpCost > 0 && c.basePotency == 100
                    && (c.actionType == ActionType.Physical || c.actionType == ActionType.Magic)
                    && CommandRows.Folder(c.commandType) != null && UsesDefaultScript(c))
                .Select(c => new object[] { (int)c.id });

        // Test data is listed before the fixture sets the script path, so the folder is spelled out.
        private static bool UsesDefaultScript(BattleCommand c)
        {
            string folder = c.commandType switch
            {
                CommandType.WeaponSkill => "WeaponSkill",
                CommandType.Ability => "Ability",
                _ => "Magic",
            };
            return !File.Exists(Path.Combine(EngineFixture.ScriptsDir, "Command", folder, LuaEngine.ScriptName(c.name) + ".lua"));
        }

        public static IEnumerable<object[]> Statuses => SeedStatuses().Select(s => new object[] { (uint)s.GetStatusEffectId() });

        private sealed class Cast
        {
            public Character Caster, Target;
        }

        // A caster of the command's class and level and a target of the kind its main target names.
        private Cast Setup(BattleCommand cmd, short level = 0)
        {
            short lvl = level > 0 ? level : (short)Math.Max(1, (int)cmd.level);
            Character caster, foe;
            if (CommandRows.IsMonster(cmd))
            {
                caster = Mob(lvl);
                foe = Pc(lvl, Character.CLASSID_GLA, 0, 2);
            }
            else
            {
                caster = Pc(lvl, cmd.job);
                foe = Mob(lvl, 30000, 0, 2);
            }
            caster.LookAt(foe);
            foe.LookAt(caster);
            Character target = cmd.mainTarget.HasFlag(ValidTarget.Enemy) ? foe : caster;
            return new Cast { Caster = caster, Target = target };
        }

        private LuaScript Script(BattleCommand cmd)
        {
            string folder = CommandRows.Folder(cmd.commandType);
            string path = LuaEngine.BattleCommandPath(folder, LuaEngine.ScriptName(cmd.name));
            if (!File.Exists(path))
                path = LuaEngine.BattleCommandPath(folder, "Default");
            var script = engines.Engine.Load(path);
            Assert.True(script.LoadError == null, $"{cmd.id} {cmd.name}: {path} does not load: {script.LoadError}");
            return script;
        }

        // Calls a script function the way the server does, but throws on a script error instead of
        // only logging it.
        private static void Run(LuaScript script, string fn, params object[] args)
        {
            if (script.HasFunction(fn))
                script.CreateCoroutine(fn).Resume(args);
        }

        private CommandResult Finish(BattleCommand cmd, Cast c, CommandResultContainer container = null)
        {
            var script = Script(cmd);
            cmd.targetFind = new TargetFind(c.Caster, c.Target);
            var action = new CommandResult(c.Target.Id, cmd, (byte)HitDirection.None, 1);
            Run(script, "onSkillFinish", c.Caster, c.Target, cmd, action, container ?? new CommandResultContainer());
            return action;
        }

        [Theory]
        [MemberData(nameof(Commands))]
        public void EveryCommandScriptRuns(int id)
        {
            var cmd = CommandRows.Get(id);
            var c = Setup(cmd);
            var script = Script(cmd);
            foreach (var fn in new[] { "onSkillPrepare", "onSkillStart", "onMagicPrepare", "onMagicStart", "onAbilityPrepare", "onAbilityStart" })
            {
                var e = Record.Exception(() => Run(script, fn, c.Caster, c.Target, cmd));
                Assert.True(e == null, $"{id} {cmd.name} {fn}: {e?.Message}");
            }
            var err = Record.Exception(() => Finish(cmd, c));
            Assert.True(err == null, $"{id} {cmd.name} onSkillFinish: {err?.Message}");
        }

        [Theory]
        [MemberData(nameof(StatusCommands))]
        public void EveryCommandStatusExists(int id)
        {
            var cmd = CommandRows.Get(id);
            Assert.True(Server.GetWorldManager().GetStatusEffect(cmd.statusId) != null,
                Sources.Cite("CL-SCHEMA", $"{id} {cmd.name}: status {cmd.statusId} has no server_statuseffects row"));
        }

        // A sure chance must land the status within a few tries (damage moves can miss).
        [Theory]
        [MemberData(nameof(StatusCommands))]
        public void StatusMovesLandTheirStatus(int id)
        {
            var probe = CommandRows.Get(id);
            if (!CommandRows.IsMonster(probe))
                return;
            for (int i = 0; i < 20; i++)
            {
                var cmd = CommandRows.Get(id);
                cmd.statusChance = 1;
                var c = Setup(cmd);
                Finish(cmd, c);
                if (c.Target.statusEffects.HasStatusEffect(cmd.statusId))
                    return;
            }
            Assert.Fail(Sources.Cite("CL-SCHEMA", $"{id} {probe.name}: status {probe.statusId} never landed at chance 1"));
        }

        // Average damage of a command over many casts, so the random spread and misses even out.
        private double MeanDamage(Func<BattleCommand> make, short level, int casts = 40)
        {
            double sum = 0;
            int landed = 0;
            for (int i = 0; i < casts; i++)
            {
                var cmd = make();
                var c = Setup(cmd, level);
                var action = Finish(cmd, c);
                if (action.ActionLanded() && action.amount > 0)
                {
                    sum += action.amount;
                    landed++;
                }
            }
            return landed == 0 ? 0 : sum / landed;
        }

        // The monster's own auto-attack, as AttackState builds it.
        private static BattleCommand MonsterSwing()
        {
            var swing = new BattleCommand(22104, "Attack")
            {
                range = 5, rangeHeight = 10, worldMasterTextId = 0x765D,
                mainTarget = (ValidTarget)768, validTarget = (ValidTarget)17152,
                commandType = CommandType.AutoAttack, numHits = 1, basePotency = 100,
                actionProperty = ActionProperty.Slashing, actionType = ActionType.Physical,
                validUser = BattleCommandValidUser.Monster,
            };
            return swing;
        }

        private static readonly Dictionary<short, double> swings = new Dictionary<short, double>();

        private double MeanSwing(short level)
        {
            lock (swings)
                if (swings.TryGetValue(level, out var cached))
                    return cached;
            double mean = MeasureSwing(level);
            lock (swings)
                swings[level] = mean;
            return mean;
        }

        private double MeasureSwing(short level)
        {
            double sum = 0;
            int landed = 0;
            for (int i = 0; i < 40; i++)
            {
                var swing = MonsterSwing();
                var mob = Mob(level);
                var pc = Pc(level, Character.CLASSID_GLA, 0, 2);
                mob.LookAt(pc);
                var script = engines.Engine.Load(LuaEngine.BattleCommandPath("autoattack", "Default"));
                swing.targetFind = new TargetFind(mob, pc);
                var action = new CommandResult(pc.Id, swing, (byte)HitDirection.None, 1);
                Run(script, "onSkillFinish", mob, pc, swing, action, new CommandResultContainer());
                if (action.ActionLanded() && action.amount > 0) { sum += action.amount; landed++; }
            }
            return landed == 0 ? 0 : sum / landed;
        }

        // A field monster's TP move against its own swing on the same target, retail 1.2-2.1x (1.8 typical).
        public const double MONSTER_MOVE_MIN_SWINGS = 1.2, MONSTER_MOVE_MAX_SWINGS = 2.1;

        [Theory]
        [MemberData(nameof(MonsterDamageMoves))]
        public void MonsterMovesHitInProportionToTheSwing(int id)
        {
            var name = CommandRows.Get(id).name;
            foreach (short level in new short[] { 5, 25, 50 })
            {
                double swing = MeanSwing(level);
                double move = MeanDamage(() => CommandRows.Get(id), level);
                Assert.True(swing > 0, $"Lv{level} monster swing does no damage");
                double ratio = move / swing;
                output.WriteLine($"{id} {name} Lv{level}: move {move:F0} swing {swing:F0} = {ratio:F2}x");
                Assert.True(ratio >= MONSTER_MOVE_MIN_SWINGS && ratio <= MONSTER_MOVE_MAX_SWINGS,
                    Sources.Cite("CAP-MOBTP", $"{id} {name} Lv{level} on Lv{level}: {move:F0} = {ratio:F2}x the swing {swing:F0}, retail {MONSTER_MOVE_MIN_SWINGS}-{MONSTER_MOVE_MAX_SWINGS}x"));
            }
        }

        // Retail hits through each command's own script: Ifrit (L58) on a Lv50, and Second Wind at the
        // levels it was captured.
        [Theory]
        [InlineData(23361, 58, 50, 239, 396, "RCAP-IFRIT")]    // Sear
        [InlineData(23362, 58, 50, 565, 626, "RCAP-IFRIT")]    // Vulcan Burst
        [InlineData(23363, 58, 50, 375, 1234, "RCAP-IFRIT")]   // Incinerate
        [InlineData(23374, 58, 50, 1356, 1936, "RCAP-IFRIT")]  // Eruption
        [InlineData(23376, 58, 50, 1158, 1882, "RCAP-IFRIT")]  // Radiant Plume
        [InlineData(23365, 58, 50, 1700, 2100, "RCAP-IFRIT")]  // Crimson Cyclone, one hit of 1906
        [InlineData(23409, 58, 50, 1410, 1994, "RCAP-IFRIT")]  // Hellfire
        public void BossMovesHitAsRetail(int id, short casterLevel, short targetLevel, double min, double max, string source)
        {
            var name = CommandRows.Get(id).name;
            double mean = MeanDamageAt(id, casterLevel, targetLevel);
            output.WriteLine($"{id} {name}: mean {mean:F0}");
            Assert.True(mean >= min && mean <= max,
                Sources.Cite(source, $"{id} {name} Lv{casterLevel} on Lv{targetLevel}: retail {min}-{max}, server mean {mean:F0}"));
        }

        private double MeanDamageAt(int id, short casterLevel, short targetLevel)
        {
            double sum = 0;
            int landed = 0;
            for (int i = 0; i < 40; i++)
            {
                var cmd = CommandRows.Get(id);
                var mob = Mob(casterLevel);
                var pc = Pc(targetLevel, Character.CLASSID_GLA, 0, 2);
                mob.LookAt(pc);
                var action = Finish(cmd, new Cast { Caster = mob, Target = pc });
                if (action.ActionLanded() && action.amount > 0) { sum += action.amount; landed++; }
            }
            return landed == 0 ? 0 : sum / landed;
        }

        [Theory]
        [InlineData(26, Character.CLASSID_MRD, 199, 201)]
        [InlineData(27, Character.CLASSID_GLA, 204, 215)]
        [InlineData(30, Character.CLASSID_MRD, 236, 246)]
        [InlineData(50, Character.CLASSID_MRD, 565, 606)]
        public void SecondWindHealsAsRetail(short level, short classId, double min, double max)
        {
            double sum = 0;
            for (int i = 0; i < 40; i++)
            {
                var cmd = CommandRows.Get(27100);
                var pc = Pc(level, classId);
                pc.SetHP(1);
                var action = Finish(cmd, new Cast { Caster = pc, Target = pc });
                sum += action.amount;
            }
            double mean = Math.Round(sum / 40);
            Assert.True(mean >= min && mean <= max,
                Sources.Cite("CAP-SW", $"Lv{level} Second Wind: retail {min}-{max}, server mean {mean:F0}"));
        }

        // Every status: its script loads and its gain, tick and loss hooks run on a test actor.
        [Theory]
        [MemberData(nameof(Statuses))]
        public void EveryStatusScriptRuns(uint id)
        {
            var effect = Server.GetWorldManager().GetStatusEffect(id);
            Assert.NotNull(effect);
            string path = $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Status/{LuaEngine.ScriptName(effect.GetName())}.lua";
            if (!File.Exists(path))
                path = $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Status/Default.lua";
            var script = engines.Engine.Load(path);
            Assert.True(script.LoadError == null, $"{id} {effect.GetName()}: {path} does not load: {script.LoadError}");

            var pc = Pc(50);
            var mob = Mob(50, 30000, 0, 2);
            var container = new CommandResultContainer();
            effect.SetDuration(30);
            var gain = Record.Exception(() => Run(script, "onGain", pc, effect, container));
            Assert.True(gain == null, $"{id} {effect.GetName()} onGain: {gain?.Message}");

            // Tick and loss run on the copy the actor holds, as the server's would.
            pc.statusEffects.AddStatusEffect(effect, mob);
            var held = pc.statusEffects.GetStatusEffectById(id);
            if (held == null)
                return;
            foreach (var fn in new[] { "onTick", "onLose" })
            {
                var e = Record.Exception(() => Run(script, fn, pc, held, container));
                Assert.True(e == null, $"{id} {effect.GetName()} {fn}: {e?.Message}");
            }
        }
    }
}
