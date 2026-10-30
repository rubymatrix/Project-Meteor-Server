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
using System.Linq;
using System.Text;
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.AI.Behaviors;
using Meteor.Map.actors.chara;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.chara.ai.controllers;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.packets.send.actor;
using Meteor.Map.Content;
using Meteor.Map.Scripting;
using XLua;

namespace Meteor.Map.AI
{
    // Drives a non-player character: a set of behaviors competing for channels, a blackboard they
    // share, and the actor's script object.
    class Brain : Controller
    {
        public const float DormantRange = 60f;
        private const long DormantTickMs = 2000;

        public Character Owner => owner;
        public readonly string Kind;
        public readonly Dictionary<string, object> Bb = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        public int ScriptId { get; private set; }
        public float ThinkSeconds { get; set; } = 0;

        private readonly List<Behavior> behaviors = new List<Behavior>();
        private readonly Dictionary<Channels, Behavior> channelOwners = new Dictionary<Channels, Behavior>();
        private HashSet<string> hooks = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private long order;
        private long nextThink;
        private long nextDormantTick;
        private bool updating;
        private readonly List<System.Action> deferred = new List<System.Action>();
        private SeededRandom ownRng;

        public Brain(Character owner, string kind) : base(owner)
        {
            Kind = kind;
        }

        public SeededRandom Rng => owner.content?.Rng ?? (ownRng ??= new SeededRandom());

        public IReadOnlyList<Behavior> Behaviors => behaviors;

        #region Script object

        // Resolves and applies the actor's profile. Called on spawn and on respawn.
        public void Attach(object extraProfile = null, LuaTable overrides = null)
        {
            ClearBehaviors();
            Bb.Clear();
            if (ScriptId == 0)
                ScriptId = ScriptRuntime.Instance.CallInt("rt_actor_new", owner, Kind);
            ScriptRuntime.Instance.Call("rt_actor_apply", ScriptId, extraProfile, overrides);
        }

        public void SetHooks(LuaTable names)
        {
            hooks = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var v in ScriptParams.From(names).List)
                if (v is string s)
                    hooks.Add(s);
        }

        public bool HasHook(string name) => hooks.Contains(name);

        public void Detach()
        {
            ClearBehaviors();
            if (ScriptId != 0)
                ScriptRuntime.Instance.Destroy(ScriptId);
            ScriptId = 0;
        }

        #endregion

        #region Behaviors

        public Behavior Get(string id)
        {
            foreach (var b in behaviors)
                if (string.Equals(b.Id, id, StringComparison.OrdinalIgnoreCase))
                    return b;
            return null;
        }

        public T Get<T>() where T : Behavior => behaviors.OfType<T>().FirstOrDefault();

        public bool Has(string id) => Get(id) != null;

        public string AddBehavior(string kind, string id = null, LuaTable p = null)
        {
            return Add(kind, id, ScriptParams.From(p));
        }

        public string Add(string kind, string id, ScriptParams p, double seconds = 0, ScriptCallback until = null)
        {
            Behavior b = BehaviorRegistry.Create(kind, this);
            if (b == null)
            {
                Program.Log.Warn("{0}: unknown behavior {1}.", owner.GetName(), kind);
                return null;
            }
            b.Kind = kind;
            b.Id = string.IsNullOrEmpty(id) ? kind : id;
            b.Priority = b.DefaultPriority;
            b.Bind(this);
            b.Configure(p ?? ScriptParams.Empty);
            b.Order = ++order;
            if (seconds > 0)
                b.EndsAtMs = GameClock.NowMs + (long)(seconds * 1000);
            b.Until = until;
            Later(() =>
            {
                var old = Get(b.Id);
                if (old != null)
                    RemoveNow(old, "replaced");
                behaviors.Add(b);
                b.OnAdd();
            });
            return b.Id;
        }

        public string AddScriptBehavior(string kind, string id, int objectId, int priority, int channels, LuaTable p)
        {
            var ps = ScriptParams.From(p);
            ps.Set("priority", (double)priority);
            string bid = string.IsNullOrEmpty(id) ? kind : id;
            var b = new ScriptBehavior { Kind = kind, Id = bid };
            b.Bind(objectId, priority, channels);
            b.Bind(this);
            b.Configure(ps);
            b.Order = ++order;
            Later(() =>
            {
                var old = Get(bid);
                if (old != null)
                    RemoveNow(old, "replaced");
                behaviors.Add(b);
                b.OnAdd();
            });
            return bid;
        }

        public void GiveCommand(string order, Character target)
        {
            Get<Behaviors.Command>()?.Give(order, target);
        }

        public bool Coax(int amount)
        {
            var flee = Get<Flee>();
            if (flee == null || !flee.Fleeing)
                return false;
            flee.Coax(amount);
            return true;
        }

        public void SetBb(string key, object value)
        {
            if (value == null)
                Bb.Remove(key);
            else
                Bb[key] = value;
        }

        public object GetBb(string key) => Bb.TryGetValue(key, out var v) ? v : null;

        public string PushBehavior(string kind, LuaTable p, double seconds, LuaTable untilCb)
        {
            var ps = ScriptParams.From(p);
            var until = ScriptParams.From(untilCb).Callback("fn");
            string id = ps.String("id") ?? kind + "#" + (order + 1);
            return Add(kind, id, ps, seconds, until);
        }

        public void Remove(string id, string reason = "removed")
        {
            Later(() =>
            {
                var b = Get(id);
                if (b != null)
                    RemoveNow(b, reason);
            });
        }

        private void RemoveNow(Behavior b, string reason)
        {
            behaviors.Remove(b);
            foreach (var key in channelOwners.Where(kv => kv.Value == b).Select(kv => kv.Key).ToList())
                channelOwners.Remove(key);
            if (b.Held != Channels.None)
                b.OnLose(b.Held);
            b.Held = Channels.None;
            b.OnRemove();
            EventBus.Raise(new ActorEvent(ActorEventType.BehaviorEnded, owner) { Name = b.Id, Data = reason });
        }

        public void SetParams(string id, LuaTable p)
        {
            var b = Get(id);
            if (b == null)
                return;
            var merged = new ScriptParams();
            merged.MergeFrom(b.Params);
            merged.MergeFrom(ScriptParams.From(p));
            b.Configure(merged);
        }

        public void Suspend(string id, bool suspended)
        {
            var b = Get(id);
            if (b != null)
                b.Suspended = suspended;
        }

        public void ClearBehaviors()
        {
            foreach (var b in behaviors.ToList())
            {
                if (b.Held != Channels.None)
                    b.OnLose(b.Held);
                b.OnRemove();
            }
            behaviors.Clear();
            channelOwners.Clear();
        }

        private void Later(System.Action a)
        {
            if (updating)
                deferred.Add(a);
            else
                a();
        }

        #endregion

        #region Tick

        public override void Update(DateTime tick)
        {
            lastUpdate = tick;
            if (owner.IsDead() || owner.CurrentArea == null)
                return;

            long now = GameClock.NowMs;
            if (IsDormant())
            {
                if (now < nextDormantTick)
                    return;
                nextDormantTick = now + DormantTickMs;
            }

            updating = true;
            try
            {
                if (owner.aiContainer.CanChangeState())
                    Arbitrate(now);
                if (ScriptId != 0 && HasHook("think") && ThinkSeconds > 0 && now >= nextThink)
                {
                    nextThink = now + (long)(ThinkSeconds * 1000);
                    ScriptRuntime.Instance.Call("rt_actor_think", ScriptId);
                }
            }
            finally
            {
                updating = false;
                RunDeferred();
            }
        }

        private void RunDeferred()
        {
            while (deferred.Count > 0)
            {
                var list = deferred.ToList();
                deferred.Clear();
                foreach (var a in list)
                    a();
            }
        }

        private bool IsDormant()
        {
            if (owner.content != null || owner.IsEngaged() || owner.ownerChara != null)
                return false;
            if (!(owner is BattleNpc))
                return false;
            foreach (var p in owner.CurrentArea.GetActorsAroundActor<Player>(owner, (int)DormantRange))
                if (p.playerSession != null)
                    return false;
            return true;
        }

        private void Arbitrate(long now)
        {
            foreach (var b in behaviors.ToList())
            {
                if (b.EndsAtMs > 0 && now >= b.EndsAtMs)
                    RemoveNow(b, "expired");
                else if (b.Until != null && b.Until.Test(owner))
                    RemoveNow(b, "until");
            }

            var wanting = new List<(Behavior b, Channels wants)>();
            foreach (var b in behaviors)
            {
                if (b.Suspended)
                    continue;
                Channels w;
                try { w = b.Wants(); }
                catch (Exception e) { Program.Log.Error("{0} {1}.Wants: {2}", owner.GetName(), b.Id, e); w = Channels.None; }
                if (w != Channels.None || b.Watches)
                    wanting.Add((b, w));
            }
            wanting.Sort((x, y) => x.b.Priority != y.b.Priority ? y.b.Priority.CompareTo(x.b.Priority) : y.b.Order.CompareTo(x.b.Order));

            var grants = new Dictionary<Behavior, Channels>();
            Channels free = Channels.All;
            foreach (var (b, w) in wanting)
            {
                Channels g = w & free;
                free &= ~g;
                grants[b] = g;
            }

            foreach (var b in behaviors)
            {
                grants.TryGetValue(b, out var g);
                Channels lost = b.Held & ~g;
                if (lost != Channels.None)
                {
                    try { b.OnLose(lost); }
                    catch (Exception e) { Program.Log.Error("{0} {1}.OnLose: {2}", owner.GetName(), b.Id, e); }
                }
                b.Held = g;
            }
            channelOwners.Clear();
            foreach (var kv in grants)
                foreach (Channels c in new[] { Channels.Move, Channels.Face, Channels.Target, Channels.Act, Channels.Sense, Channels.Speak })
                    if ((kv.Value & c) != 0)
                        channelOwners[c] = kv.Key;

            foreach (var (b, _) in wanting)
            {
                if (!behaviors.Contains(b))
                    continue;
                try { b.Tick(grants[b]); }
                catch (Exception e) { Program.Log.Error("{0} {1}.Tick: {2}", owner.GetName(), b.Id, e); }
            }
        }

        public Behavior OwnerOf(Channels c) => channelOwners.TryGetValue(c, out var b) ? b : null;

        #endregion

        #region Events

        public void Deliver(ActorEvent e)
        {
            foreach (var b in behaviors.ToList())
            {
                try { b.OnEvent(e); }
                catch (Exception ex) { Program.Log.Error("{0} {1}.OnEvent: {2}", owner.GetName(), b.Id, ex); }
            }
            if (ScriptId != 0 && HasHook("on" + e.TypeName))
            {
                var r = ScriptRuntime.Instance.Call("rt_actor_event", ScriptId, e);
                if (r != null && r.Length > 0 && r[0] as string == "handled")
                    e.Handled = true;
            }
        }

        #endregion

        #region Combat (the Controller contract)

        public override bool Engage(Character target)
        {
            if (target == null || !target.IsAlive())
                return false;
            // A readied actor shows the active stance but has no attack running yet.
            if (Bb.Remove(Ready.BbKey) && owner.GetState() == SetActorStatePacket.MAIN_STATE_ACTIVE)
                owner.currentMainState = SetActorStatePacket.MAIN_STATE_PASSIVE;
            bool wasEngaged = owner.aiContainer.IsEngaged();
            var ok = owner.aiContainer.InternalEngage(target);
            if (ok)
            {
                if (owner.GetState() != SetActorStatePacket.MAIN_STATE_ACTIVE)
                    owner.ChangeState(SetActorStatePacket.MAIN_STATE_ACTIVE);
                if (!wasEngaged)
                    EventBus.Raise(ActorEventType.Engaged, owner, target);
            }
            return ok;
        }

        public override void Disengage()
        {
            var target = owner.TargetChara;
            bool was = owner.aiContainer.IsEngaged();
            owner.hateContainer?.ClearHate();
            base.Disengage();
            if (was)
                EventBus.Raise(ActorEventType.Disengaged, owner, target);
        }

        public override void ChangeTarget(Character target)
        {
            if (target == owner.TargetChara)
                return;
            var old = owner.TargetChara;
            owner.target = target;
            owner.currentLockedTarget = target?.Id ?? Actor.INVALID_ACTORID;
            owner.currentTarget = target?.Id ?? Actor.INVALID_ACTORID;
            if (owner is BattleNpc bnpc && owner.CurrentArea != null)
            {
                foreach (var player in owner.CurrentArea.GetActorsAroundActor<Player>(owner, 50))
                    player.QueuePacket(bnpc.GetHateTypePacket(player));
                bnpc.UpdateEnmityIndicator(target);
            }
            base.ChangeTarget(target);
            EventBus.Raise(ActorEventType.TargetChanged, owner, target) ;
        }

        public override void Cast(Character target, uint spellId)
        {
            if (owner.aiContainer.CanChangeState())
                owner.aiContainer.InternalCast(target, spellId);
        }

        public override void Ability(Character target, uint abilityId)
        {
            if (owner.aiContainer.CanChangeState())
                owner.aiContainer.InternalAbility(target, abilityId);
        }

        public override void WeaponSkill(Character target, uint weaponSkillId)
        {
            if (owner.aiContainer.CanChangeState())
                owner.aiContainer.InternalWeaponSkill(target, weaponSkillId);
        }

        public override void RangedAttack(Character target) { }

        public bool CanUse(uint actionId, Character target)
        {
            var command = Server.GetWorldManager().GetBattleCommand(actionId);
            return command != null && target != null && owner.CanUse(target, command)
                && owner.GetTP() >= command.CalculateTpCost(owner) && owner.GetMP() >= command.CalculateMpCost(owner)
                && !(owner is BattleNpc mob && PartBreak.IsSkillDisabled(mob, command));
        }

        // Starts a battle command of any type. force interrupts what can be interrupted first.
        public bool UseAction(uint actionId, Character target, bool force = false)
        {
            var command = Server.GetWorldManager().GetBattleCommand(actionId);
            if (command == null || target == null)
                return false;
            if (force)
                owner.aiContainer.InterruptStates();
            if (!owner.aiContainer.CanChangeState())
                return false;
            switch (command.commandType)
            {
                case CommandType.Spell:
                    owner.aiContainer.InternalCast(target, actionId);
                    break;
                case CommandType.Ability:
                    owner.aiContainer.InternalAbility(target, actionId);
                    break;
                default:
                    owner.aiContainer.InternalWeaponSkill(target, actionId);
                    break;
            }
            return true;
        }

        #endregion

        #region Movement helpers for behaviors

        public Mover Mover => owner.aiContainer.mover;

        public bool CanMove()
        {
            if (owner.GetSpeed() == 0 || Mover == null)
                return false;
            if (owner.statusEffects.HasStatusEffectsByFlag(StatusEffectFlags.PreventMovement))
                return false;
            return owner.aiContainer.CanFollowPath();
        }

        public void Face(Actor target)
        {
            if (target == null || owner.statusEffects.HasStatusEffectsByFlag(StatusEffectFlags.PreventTurn))
                return;
            owner.LookAt(target);
        }

        public Vector3 Home => new Vector3(owner.spawnX, owner.spawnY, owner.spawnZ);

        public static ushort Pace(string pace) => pace == "run" ? Mover.MOVE_STATE_RUN : Mover.MOVE_STATE_WALK;

        #endregion

        public string Describe()
        {
            var sb = new StringBuilder();
            sb.Append(Kind).Append(" script=").Append(ScriptId).Append('\n');
            foreach (var b in behaviors.OrderByDescending(x => x.Priority))
                sb.AppendFormat("  {0} [{1}] p={2} held={3}{4} {5}\n", b.Id, b.Kind, b.Priority, b.Held, b.Suspended ? " suspended" : "", b.Describe());
            foreach (var kv in Bb)
                sb.AppendFormat("  bb.{0} = {1}\n", kv.Key, kv.Value is Actor a ? a.GetName() + "#" + a.Id : kv.Value);
            return sb.ToString();
        }

        public object Snapshot()
        {
            return new
            {
                kind = Kind,
                script = ScriptId,
                faction = Factions.Name(owner.factionId),
                tags = owner.tags.ToList(),
                behaviors = behaviors.OrderByDescending(x => x.Priority).Select(b => new
                {
                    id = b.Id, kind = b.Kind, priority = b.Priority, wants = SafeWants(b).ToString(), held = b.Held.ToString(),
                    suspended = b.Suspended, detail = b.Describe(),
                }).ToList(),
                channels = channelOwners.ToDictionary(kv => kv.Key.ToString(), kv => kv.Value.Id),
                blackboard = Bb.ToDictionary(kv => kv.Key, kv => kv.Value is Actor a ? (object)(a.GetName() + "#" + a.Id) : kv.Value?.ToString()),
                hate = owner.hateContainer?.Describe(),
            };
        }

        private static Channels SafeWants(Behavior b)
        {
            try { return b.Wants(); } catch { return Channels.None; }
        }
    }
}
