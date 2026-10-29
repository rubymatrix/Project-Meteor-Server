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

namespace Meteor.Map.actors.chara.ai
{
    // Where the mobs fighting one standing target stop, so they don't stack. Each keeps its approach
    // bearing; bearings too close together are pushed apart, at most MAX_SHIFT off each mob's own line,
    // and a mob that still can't fit stands a rank further out. No server types, so the unit tests can
    // drive it directly. Angles are radians on the XZ plane.
    static class MeleeSpread
    {
        public const float SPACING = 2.7f;
        // Closer than this after the spread, the later mob stands a rank further out.
        public const float SPACING_MIN = 1.3f;
        public const float BODY_GAP = 0.5f;
        public const float MAX_SHIFT = 25.0f * (float)Math.PI / 180.0f;
        public const float RANK_STEP = 1.5f;
        // A mob already standing in range gives way half as much as one arriving.
        public const float STANDING_WEIGHT = 0.5f;
        private const int PASSES = 4;

        public struct Member
        {
            public uint Id;
            public float X, Z;
            // Stop distance from the target (centre to centre), and the furthest it may stand and still reach.
            public float Radius, MaxRadius;
            public float Body;
            public bool Standing;
        }

        public struct Stop
        {
            public uint Id;
            public float X, Z;
            // Approach bearing, chosen bearing, distance from the target.
            public float Theta0, Theta, Radius;
            public bool SecondRank;
        }

        public static float Bearing(float tx, float tz, float x, float z) => (float)Math.Atan2(z - tz, x - tx);

        // Wraps an angle to (-pi, pi].
        public static float Wrap(float a)
        {
            a = (float)Math.IEEERemainder(a, 2 * Math.PI);
            return a <= -Math.PI ? a + 2 * (float)Math.PI : a;
        }

        public static float Spacing(float bodyA, float bodyB) => Math.Max(SPACING, bodyA + bodyB + BODY_GAP);

        // The angle that puts two points at radii ra and rb around the centre s apart.
        public static float AngleFor(float s, float ra, float rb)
        {
            float r = Math.Max(0.01f, (ra + rb) * 0.5f);
            return 2.0f * (float)Math.Asin(Math.Min(1.0f, s / (2.0f * r)));
        }

        public static Stop At(float tx, float tz, uint id, float theta0, float theta, float radius, bool rank) => new Stop
        {
            Id = id,
            Theta0 = theta0,
            Theta = theta,
            Radius = radius,
            SecondRank = rank,
            X = tx + radius * (float)Math.Cos(theta),
            Z = tz + radius * (float)Math.Sin(theta),
        };

        // Stop points for the members around a target at (tx, tz), in the members' order.
        public static Stop[] Solve(float tx, float tz, IList<Member> members)
        {
            int n = members.Count;
            var theta0 = new float[n];
            var theta = new float[n];
            var radius = new float[n];
            var weight = new float[n];
            for (int i = 0; i < n; i++)
            {
                var m = members[i];
                theta0[i] = theta[i] = Bearing(tx, tz, m.X, m.Z);
                radius[i] = m.Radius;
                weight[i] = m.Standing ? STANDING_WEIGHT : 1.0f;
            }

            var order = new int[n];
            for (int pass = 0; pass < PASSES && n > 1; pass++)
            {
                for (int i = 0; i < n; i++)
                    order[i] = i;
                // Around the circle; equal bearings by id, so the lower id goes the negative way.
                Array.Sort(order, (a, b) =>
                {
                    int c = Wrap(theta[a]).CompareTo(Wrap(theta[b]));
                    return c != 0 ? c : members[a].Id.CompareTo(members[b].Id);
                });
                int pairs = n == 2 ? 1 : n;
                for (int k = 0; k < pairs; k++)
                {
                    int i = order[k], j = order[(k + 1) % n];
                    float gap = Wrap(theta[j] - theta[i]);
                    if (gap < 0)
                        gap += 2 * (float)Math.PI;
                    float need = AngleFor(Spacing(members[i].Body, members[j].Body), radius[i], radius[j]);
                    if (gap >= need)
                        continue;
                    float push = need - gap, sum = weight[i] + weight[j];
                    theta[i] = Clamp(theta[i] - push * weight[i] / sum, theta0[i]);
                    theta[j] = Clamp(theta[j] + push * weight[j] / sum, theta0[j]);
                }
            }

            var stops = new Stop[n];
            for (int i = 0; i < n; i++)
                stops[i] = At(tx, tz, members[i].Id, theta0[i], theta[i], radius[i], false);

            // Still too close: the one arriving (then the higher id) stands a rank out on its own line.
            for (int i = 0; i < n; i++)
            {
                for (int j = 0; j < n; j++)
                {
                    if (i == j || stops[i].SecondRank)
                        continue;
                    float dx = stops[i].X - stops[j].X, dz = stops[i].Z - stops[j].Z;
                    if (dx * dx + dz * dz >= SPACING_MIN * SPACING_MIN)
                        continue;
                    bool iYields = members[i].Standing != members[j].Standing ? !members[i].Standing : members[i].Id > members[j].Id;
                    if (!iYields)
                        continue;
                    float r = Math.Min(radius[i] + RANK_STEP, Math.Max(radius[i], members[i].MaxRadius));
                    stops[i] = At(tx, tz, members[i].Id, theta0[i], theta0[i], r, true);
                }
            }
            return stops;
        }

        private static float Clamp(float theta, float theta0)
        {
            float d = Wrap(theta - theta0);
            return theta0 + Math.Max(-MAX_SHIFT, Math.Min(MAX_SHIFT, d));
        }
    }
}
