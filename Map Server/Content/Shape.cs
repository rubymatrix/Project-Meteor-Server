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

namespace Meteor.Map.Content
{
    // A flat area on the ground: circle, donut, cone, line (a box along a segment) or polygon.
    // Centred on a point, or on an actor so it moves with it.
    class Shape
    {
        public string Kind = "circle";
        public Vector3 Centre;
        public Actor Anchor;
        public float Radius = 5, Inner = 0;
        public float Angle = 90;          // cone width, degrees
        public float Facing;              // radians; cones and lines
        public bool FaceAnchor = true;    // take Facing from the anchor's rotation
        public Vector3 To;                // line end
        public float HalfWidth = 2;
        public List<Vector3> Points;      // polygon

        public static Shape From(ScriptParams p)
        {
            if (p == null)
                return null;
            var s = new Shape();
            foreach (var kind in new[] { "circle", "donut", "cone", "line", "poly" })
            {
                var t = p.Table(kind);
                if (t != null)
                {
                    s.Kind = kind;
                    p = t;
                    break;
                }
            }
            if (p.Has("kind"))
                s.Kind = p.String("kind");
            s.Anchor = p.Get("on") as Actor ?? p.Get("anchor") as Actor;
            s.Centre = p.Point("centre") ?? p.Point("at") ?? p.Point("from") ?? s.Anchor?.GetPosAsVector3();
            s.Radius = p.Float("radius", s.Radius);
            s.Inner = p.Float("inner", s.Inner);
            s.Angle = p.Float("angle", s.Angle);
            if (p.Has("facing"))
            {
                s.Facing = p.Float("facing");
                s.FaceAnchor = false;
            }
            s.To = p.Point("to");
            if (s.Kind == "line" && p.Has("length") && s.To == null)
                s.Radius = p.Float("length", 20);
            s.HalfWidth = p.Float("width", s.HalfWidth * 2) / 2;
            if (s.Kind == "poly")
            {
                s.Points = new List<Vector3>();
                foreach (var v in (p.Table("points") ?? p).List)
                    if (ScriptParams.AsPoint(v) is Vector3 pt)
                        s.Points.Add(pt);
            }
            if (s.Anchor != null && s.FaceAnchor)
                s.Facing = s.Anchor.rotation;
            return s;
        }

        public Vector3 CurrentCentre => Anchor != null ? Anchor.GetPosAsVector3() : Centre;

        public bool Contains(Vector3 p)
        {
            if (p == null)
                return false;
            var c = CurrentCentre;
            float facing = Anchor != null && FaceAnchor ? Anchor.rotation : Facing;
            switch (Kind)
            {
                case "donut":
                {
                    float d = Flat(c, p);
                    return d <= Radius && d >= Inner;
                }
                case "cone":
                {
                    float d = Flat(c, p);
                    if (d > Radius)
                        return false;
                    if (d < 0.01f)
                        return true;
                    double dir = Math.Atan2(p.X - c.X, p.Z - c.Z);
                    double diff = Math.Abs(Normalize(dir - facing));
                    return diff <= Angle * Math.PI / 360.0;
                }
                case "line":
                {
                    Vector3 end = To ?? new Vector3(c.X + (float)Math.Sin(facing) * Radius, c.Y, c.Z + (float)Math.Cos(facing) * Radius);
                    float vx = end.X - c.X, vz = end.Z - c.Z;
                    float len2 = vx * vx + vz * vz;
                    if (len2 < 0.0001f)
                        return Flat(c, p) <= HalfWidth;
                    float t = ((p.X - c.X) * vx + (p.Z - c.Z) * vz) / len2;
                    if (t < 0 || t > 1)
                        return false;
                    float px = c.X + vx * t - p.X, pz = c.Z + vz * t - p.Z;
                    return px * px + pz * pz <= HalfWidth * HalfWidth;
                }
                case "poly":
                    return InPolygon(p);
                default:
                    return Flat(c, p) <= Radius;
            }
        }

        // The closest point inside (circle and polygon arenas push actors back to it).
        public Vector3 ClampInside(Vector3 p, float margin = 1)
        {
            var c = CurrentCentre;
            if (Kind == "poly" || c == null)
                return Points != null && Points.Count > 0 ? Centroid() : p;
            float d = Flat(c, p);
            float r = Math.Max(0, Radius - margin);
            if (d <= r || d < 0.01f)
                return p;
            return new Vector3(c.X + (p.X - c.X) / d * r, p.Y, c.Z + (p.Z - c.Z) / d * r);
        }

        private Vector3 Centroid()
        {
            float x = 0, y = 0, z = 0;
            foreach (var v in Points) { x += v.X; y += v.Y; z += v.Z; }
            return new Vector3(x / Points.Count, y / Points.Count, z / Points.Count);
        }

        private bool InPolygon(Vector3 p)
        {
            if (Points == null || Points.Count < 3)
                return false;
            bool inside = false;
            for (int i = 0, j = Points.Count - 1; i < Points.Count; j = i++)
            {
                var a = Points[i];
                var b = Points[j];
                if ((a.Z > p.Z) != (b.Z > p.Z) && p.X < (b.X - a.X) * (p.Z - a.Z) / (b.Z - a.Z) + a.X)
                    inside = !inside;
            }
            return inside;
        }

        private static float Flat(Vector3 a, Vector3 b)
        {
            float dx = a.X - b.X, dz = a.Z - b.Z;
            return (float)Math.Sqrt(dx * dx + dz * dz);
        }

        private static double Normalize(double a)
        {
            while (a > Math.PI) a -= 2 * Math.PI;
            while (a < -Math.PI) a += 2 * Math.PI;
            return a;
        }
    }
}
