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
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.Scripting;

namespace Meteor.Map.AI.Behaviors
{
    struct RoutePoint
    {
        public Vector3 Pos;
        public string Name;
        public float Wait;
        public string Tag;
    }

    static class BehaviorUtil
    {
        // A list of points: { x, y, z, name = , wait = , tag = } or { x = , y = , z = , ... }.
        public static List<RoutePoint> Route(ScriptParams p)
        {
            var list = new List<RoutePoint>();
            if (p == null)
                return list;
            var points = p.Table("points") ?? p;
            foreach (var v in points.List)
            {
                var pos = ScriptParams.AsPoint(v);
                if (pos == null)
                    continue;
                var t = v as ScriptParams;
                list.Add(new RoutePoint { Pos = pos, Name = t?.String("name"), Wait = t?.Float("wait") ?? 0, Tag = t?.String("tag") });
            }
            return list;
        }

        // "owner", an actor, an actor id, or a blackboard key holding one of those.
        public static Character ResolveActor(Brain brain, object spec)
        {
            switch (spec)
            {
                case Character c:
                    return c;
                case double id:
                    return brain.Owner.CurrentArea?.FindActorInArea<Character>((uint)id);
                case string s:
                    if (s == "owner")
                        return brain.Owner.ownerChara;
                    if (s == "self")
                        return brain.Owner;
                    if (s == "target")
                        return brain.Owner.TargetChara;
                    if (brain.Bb.TryGetValue(s, out var v) && !(v is string))
                        return ResolveActor(brain, v);
                    return null;
                default:
                    return null;
            }
        }

        public static float Dist(Actor a, Actor b) => Utils.Distance(a.GetPosAsVector3(), b.GetPosAsVector3());

        public static float Dist(Actor a, Vector3 p) => Utils.Distance(a.GetPosAsVector3(), p);

        public static float FlatDist(Vector3 a, Vector3 b)
        {
            float dx = a.X - b.X, dz = a.Z - b.Z;
            return (float)Math.Sqrt(dx * dx + dz * dz);
        }

        // A point offset from an actor in its own frame (forward = +z after rotation).
        public static Vector3 Offset(Actor a, float right, float back)
        {
            double r = a.rotation;
            float sin = (float)Math.Sin(r), cos = (float)Math.Cos(r);
            float x = a.positionX - back * sin + right * cos;
            float z = a.positionZ - back * cos - right * sin;
            return new Vector3(x, a.positionY, z);
        }

        public static (float right, float back) Slot(string slot, float gap)
        {
            switch (slot)
            {
                case "left": return (-gap, 0);
                case "right": return (gap, 0);
                case "rearLeft": return (-gap * 0.7f, gap * 0.7f);
                case "rearRight": return (gap * 0.7f, gap * 0.7f);
                case "front": return (0, -gap);
                default: return (0, gap);
            }
        }

        public static Vector3 Away(Actor from, Actor threat, float distance)
        {
            float dx = from.positionX - threat.positionX, dz = from.positionZ - threat.positionZ;
            float len = (float)Math.Sqrt(dx * dx + dz * dz);
            if (len < 0.01f) { dx = 1; dz = 0; len = 1; }
            return new Vector3(from.positionX + dx / len * distance, from.positionY, from.positionZ + dz / len * distance);
        }
    }
}
