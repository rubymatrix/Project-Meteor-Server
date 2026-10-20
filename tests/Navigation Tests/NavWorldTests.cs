using System;
using System.Collections.Concurrent;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Threading;
using System.Threading.Tasks;
using DotRecast.Detour;
using Meteor.Navigation.Tests.Fixtures;
using Xunit;
using S = Meteor.Navigation.Tests.Fixtures.SyntheticScene;

namespace Meteor.Navigation.Tests
{
    public class NavWorldTests
    {
        private static readonly Lazy<NavWorld> shared = new Lazy<NavWorld>(S.LoadWorld);
        private static NavWorld World => shared.Value;
        private static NavInstance Fresh() => World.CreateInstance("test");

        #region Reader

        [Fact]
        public void ReaderRoundTrip()
        {
            var scene = S.Build();
            var ms = new MemoryStream();
            scene.Writer.Write(ms);
            ms.Position = 0;
            var file = NavFile.Read(ms);

            Assert.Equal(NavFile.VERSION, file.Version);
            Assert.Contains("XTRA", file.Sections); // unknown section skipped
            Assert.Equal("synthetic", file.Meta.Zone);
            Assert.Equal(S.RADIUS, file.Meta.WalkableRadius);
            Assert.Equal(scene.Writer.Tiles.Count, file.Tiles.Count);
            Assert.Equal(scene.Writer.Tiles.Select(t => t.tileRef), file.Tiles.Select(t => t.TileRef));
            Assert.Equal(3, file.Gates.Count);
            Assert.Equal("g1", file.Gates[0].Id);
            Assert.Equal(scene.Writer.Gates[0].Polys, file.Gates[0].Polys);
            Assert.Equal("sgrp_test_door", file.Gates[0].Driver["mapobj"]);
            Assert.Equal(new[] { S.LINK_LIFT }, file.Gates[S.GATE_LIFT].Links);
            Assert.Equal(2, file.Links.Count);
            Assert.False(file.Links[S.LINK_DROP].Bidir);
            Assert.Equal(-1, file.Links[S.LINK_DROP].Gate);
            Assert.Equal(S.GATE_LIFT, file.Links[S.LINK_LIFT].Gate);
            Assert.Equal(S.A, file.Seeds[0].Pos);
            Assert.Equal(scene.Writer.Islands, file.Islands);
            Assert.Equal(scene.Writer.Graph.Nodes.Length, file.Graph.Nodes.Length);
            Assert.Equal(scene.Writer.Graph.Edges.Length, file.Graph.Edges.Length);
            Assert.Equal(scene.Writer.Graph.PolyNode, file.Graph.PolyNode);
            Assert.Equal(scene.Writer.Graph.Nodes[3].CenterPoly, file.Graph.Nodes[3].CenterPoly);
            Assert.Equal(scene.Writer.Graph.Nodes[3].Flags, file.Graph.Nodes[3].Flags);

            var world = new NavWorld(file, "rt");
            Assert.Empty(world.Warnings);
            Assert.Equal(scene.Writer.Tiles.Count, world.TileCount);
            // tiles came back at their saved refs, so stored poly refs still resolve to the same polys
            foreach (long r in scene.Writer.Gates[0].Polys)
            {
                Assert.True(world.Mesh.IsValidPolyRef(r));
                Assert.Equal(NavArea.GATE_0, world.PolyArea(r));
                Assert.Equal(S.GATE_DOOR, world.GateOfPoly(r));
            }
            Assert.True(scene.PrunedPolys > 0);
        }

        [Fact]
        public void RejectsBadMagic()
        {
            Assert.Throws<InvalidDataException>(() => NavFile.Read(new MemoryStream(new byte[64])));
        }

        [Fact]
        public void SceneHasExpectedAreasAndGates()
        {
            Assert.NotNull(World.Graph);
            Assert.NotEmpty(World.Gates[S.GATE_DOOR].Polys);
            Assert.NotEmpty(World.Gates[S.GATE_WALL].Polys);
            var water = Fresh().Project(S.Pool, NavAgent.Player);
            Assert.True(water.Ok);
            Assert.Equal(NavArea.WATER, World.PolyArea(water.Poly));
            Assert.Equal(0, World.GateIndex("g1"));
            Assert.Equal(-1, World.GateIndex("nope"));
            Assert.Equal(new[] { S.GATE_DOOR }, World.GatesByDriver("mapobj", "sgrp_test_door"));
            Assert.Equal(new[] { S.GATE_WALL }, World.GatesByDriver("timeline", "time_test_hide"));
        }

        #endregion

        #region Project

        [Fact]
        public void ProjectFindsGroundUnderPoint()
        {
            var p = Fresh().Project(new Vector3(5, 1.5f, 5), NavAgent.Mob);
            Assert.True(p.Ok);
            Assert.InRange(p.Position.Y, -0.3f, 0.3f);
            Assert.Equal(5, p.Position.X, 1);
        }

        [Fact]
        public void ProjectRooftopIsVerticalMismatch()
        {
            // the slab is pruned; the only ground is 6 m below
            var p = Fresh().Project(S.Roof, NavAgent.Player);
            Assert.Equal(NavReason.VerticalMismatch, p.Reason);
            Assert.InRange(p.Position.Y, -0.3f, 0.3f);
        }

        [Fact]
        public void ProjectFarFromMeshIsOffMesh()
        {
            Assert.Equal(NavReason.GoalOffMesh, Fresh().Project(new Vector3(300, 0, 300), NavAgent.Mob).Reason);
        }

        [Fact]
        public void SnapHandlesRowsWithoutHeight()
        {
            var inst = Fresh();
            var p = inst.Snap(new Vector3(105, 0, 35), NavAgent.Player);  // Y = 0: highest ground in the column
            Assert.True(p.Ok);
            Assert.InRange(p.Position.Y, 9.7f, 10.3f);
            var roof = inst.Snap(S.Roof, NavAgent.Player);                 // pruned roof: the floor below
            Assert.True(roof.Ok);
            Assert.InRange(roof.Position.Y, -0.3f, 0.3f);
            var far = inst.Snap(new Vector3(5, 3, -40), NavAgent.Player);  // 40 m off the edge: widening search
            Assert.True(far.Ok);
            Assert.False(inst.Snap(new Vector3(900, 0, 900), NavAgent.Player).Ok);
        }

        #endregion

        #region PlanRoute

        [Fact]
        public void ShortTripIsStraight()
        {
            var route = Fresh().PlanRoute(S.A, S.A2, NavAgent.Mob);
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.True(route.Complete);
            Assert.Equal(NavRoute.StretchKind.Straight, route.Stretch);
            Assert.True(Vector3.Distance(route.Points[^1], S.A2) < 0.5f);
            // sampled every 2 m on the ground
            Assert.True(route.Points.Count >= 9);
            Assert.All(route.Points, p => Assert.InRange(p.Y, -0.3f, 0.3f));
        }

        [Fact]
        public void LocalRouteGoesThroughTheDoor()
        {
            var route = Fresh().PlanRoute(S.A, S.B, NavAgent.Mob);
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.True(route.Complete);
            Assert.Equal(NavRoute.StretchKind.Local, route.Stretch);
            Assert.Contains(route.Points, p => S.InRect(p, S.DoorRect));
            Assert.True(Vector3.Distance(route.Points[^1], S.B) < 0.5f);
            Assert.InRange(route.Length, 50f, 60f);
        }

        [Fact]
        public void ClosedDoorReroutesThenGateClosed()
        {
            var inst = Fresh();
            inst.SetGate("g1", false);
            var route = inst.PlanRoute(S.A, S.B, NavAgent.Mob);
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.DoesNotContain(route.Points, p => S.InRect(p, S.DoorRect));
            Assert.Contains(route.Points, p => p.Z > 50); // the loop corridor
            Assert.True(route.Length > 100f);

            inst.SetGate("g2", false);
            route = inst.PlanRoute(S.A, S.B, NavAgent.Mob);
            Assert.Equal(NavReason.GateClosed, route.Reason);
            Assert.False(route.Ok);

            inst.SetGate("g1", true);
            Assert.Equal(NavReason.Ok, inst.PlanRoute(S.A, S.B, NavAgent.Mob).Reason);
        }

        [Fact]
        public void LongRouteFollowsTheGraphInStretches()
        {
            var inst = Fresh();
            var route = inst.PlanRoute(S.A, S.E, NavAgent.Mob);
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.False(route.Complete);
            Assert.Equal(NavRoute.StretchKind.Window, route.Stretch);
            Assert.NotNull(route.GraphNodes);
            float firstReach = route.Points.Max(p => p.X);
            Assert.InRange(firstReach, 40f, 110f); // about two cells ahead

            int guard = 0;
            while (!route.Complete && guard++ < 20)
                Assert.True(route.Advance(route.Points[^1]), route.ToString());
            Assert.True(route.Complete);
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.True(Vector3.Distance(route.Points[^1], S.E) < 0.5f);
            Assert.InRange(route.StretchCount, 2, 8);
        }

        [Fact]
        public void LongRouteReplansAfterGateChange()
        {
            var inst = Fresh();
            var route = inst.PlanRoute(S.A, S.E, NavAgent.Mob);
            Assert.False(route.Complete);
            inst.SetGate("g1", false);
            Assert.True(route.Stale);
            Assert.True(route.Advance(S.A));
            Assert.DoesNotContain(route.Points, p => S.InRect(p, S.DoorRect));
            Assert.False(route.Stale);
        }

        [Fact]
        public void RooftopGoalIsVerticalMismatch()
        {
            Assert.Equal(NavReason.VerticalMismatch, Fresh().PlanRoute(S.A, S.Roof, NavAgent.Mob).Reason);
        }

        [Fact]
        public void OffMeshStart()
        {
            Assert.Equal(NavReason.StartOffMesh, Fresh().PlanRoute(new Vector3(300, 0, 300), S.A, NavAgent.Mob).Reason);
        }

        [Fact]
        public void RoutePointsCarryGroundHeight()
        {
            var route = Fresh().PlanRoute(S.Pad, S.Top, NavAgent.Player);
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.True(route.Complete);
            Assert.InRange(route.Points[^1].Y, 9.7f, 10.3f);
            Assert.All(route.Points, p => Assert.True(p.Y < 0.3f || p.Y > 9.7f, $"point {p} floats between floors"));
        }

        [Fact]
        public void WideAgentCornersArePushedOut()
        {
            var inst = Fresh();
            var thin = inst.PlanRoute(S.A, S.B, NavAgent.Mob);
            var wide = inst.PlanRoute(S.A, S.B, NavAgent.Mob.With("Wide", radius: 1.2f));
            Assert.Equal(NavReason.Ok, wide.Reason);
            // the door edges are the inside corners: the wide agent keeps further from them
            float Clear(NavRoute r) => r.Corners.Where(c => S.InRect(c, (29, 12, 34.5f, 18)))
                .Select(c => Math.Min(Math.Abs(c.Z - 13.5f), Math.Abs(c.Z - 16.5f))).DefaultIfEmpty(9).Min();
            Assert.True(Clear(wide) > Clear(thin) + 0.3f, $"thin {Clear(thin)} wide {Clear(wide)}");
        }

        #endregion

        #region Filters and links

        [Fact]
        public void MobsCannotUsePlayerOnlyGround()
        {
            var inst = Fresh();
            Assert.Equal(NavReason.NoRoute, inst.PlanRoute(S.E, S.F, NavAgent.Mob).Reason);
            Assert.Equal(NavReason.NoRoute, inst.Reachable(S.E, S.F, NavAgent.Mob).Reason);
            var route = inst.PlanRoute(S.E, S.F, NavAgent.Player);
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.True(Vector3.Distance(route.Points[^1], S.F) < 0.5f);
        }

        [Fact]
        public void LiftIsForEscortsAndPlayersNotMobs()
        {
            var inst = Fresh();
            Assert.Equal(NavReason.NoRoute, inst.Reachable(S.Pad, S.Top, NavAgent.Mob).Reason);
            Assert.Equal(NavReason.Ok, inst.Reachable(S.Pad, S.Top, NavAgent.Escort).Reason);
            Assert.Equal(NavReason.Ok, inst.PlanRoute(S.Pad, S.Top, NavAgent.Escort).Reason);
            inst.SetGate("g3", false);
            Assert.Equal(NavReason.GateClosed, inst.Reachable(S.Pad, S.Top, NavAgent.Escort).Reason);
            Assert.Equal(NavReason.GateClosed, inst.PlanRoute(S.Pad, S.Top, NavAgent.Escort).Reason);
        }

        [Fact]
        public void DropIsOneWay()
        {
            var inst = Fresh();
            // the fixture's drop is 10 high: a mob agent with no link height limit
            var jumper = new NavAgent("Jumper", 0.5f, 2.0f, 0.75f, NavAgent.Mob.Include, NavAgent.Mob.Exclude);
            Assert.Equal(NavReason.Ok, inst.Reachable(S.Top, S.DropPad, jumper).Reason);
            var down = inst.PlanRoute(S.Top, S.DropPad, jumper);
            Assert.Equal(NavReason.Ok, down.Reason);
            Assert.InRange(down.Points[^1].Y, -0.3f, 0.3f);
            Assert.Equal(NavReason.NoRoute, inst.Reachable(S.DropPad, S.Top, jumper).Reason);
            // a real mob is walked by the client, whose ground probe doesn't reach 10 down: no lift, no way down
            Assert.Equal(NavReason.NoRoute, inst.Reachable(S.Top, S.DropPad, NavAgent.Mob).Reason);
            // escorts don't jump: they take the lift down instead
            var escort = inst.PlanRoute(S.Top, S.DropPad, NavAgent.Escort);
            Assert.Equal(NavReason.Ok, escort.Reason);
            Assert.Contains(escort.Points, p => S.InRect(p, (100, 17, 110, 25)) && p.Y < 0.3f);
        }

        [Fact]
        public void WaterCostAndExclusion()
        {
            var inst = Fresh();
            var from = new Vector3(36, 0, 15);
            var to = new Vector3(54, 0, 15);
            var dry = NavAgent.Player.With("Dry", exclude: NavFlags.Water);
            var route = inst.PlanRoute(from, to, dry, new RouteOpts { StraightMaxDistance = 0 });
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.DoesNotContain(route.Points, p => S.InRect(p, (40.5f, 5.5f, 49.5f, 24.5f)));
            var swimmer = inst.PlanRoute(from, to, NavAgent.Player, new RouteOpts { StraightMaxDistance = 0 });
            Assert.True(swimmer.Length < route.Length);
            Assert.False(inst.Project(S.Pool, dry, 1.0f, 1.0f).Ok);
        }

        #endregion

        #region Walk, CanSee, RandomPoint, Displace

        [Fact]
        public void WalkStopsAtWalls()
        {
            var inst = Fresh();
            Assert.True(inst.Walk(S.A, new Vector3(25, 0, 5), NavAgent.Mob).Clear);
            var hit = inst.Walk(new Vector3(25, 0, 5), new Vector3(45, 0, 5), NavAgent.Mob);
            Assert.Equal(NavReason.Ok, hit.Reason);
            Assert.InRange(hit.T, 0.15f, 0.3f);
            Assert.InRange(hit.Point.X, 29f, 30f);
            // through the door only while it is open
            var a = new Vector3(25, 0, 15);
            var b = new Vector3(40, 0, 15);
            Assert.True(inst.Walk(a, b, NavAgent.Mob).Clear);
            inst.SetGate("g1", false);
            Assert.False(inst.Walk(a, b, NavAgent.Mob).Clear);
        }

        [Fact]
        public void WalkFromBesideTheMeshIsStartOffMesh()
        {
            // 3 y west of room A: the projection finds its edge, but the start isn't on the mesh
            var hit = Fresh().Walk(new Vector3(-3, 0, 15), new Vector3(5, 0, 15), NavAgent.Player);
            Assert.Equal(NavReason.StartOffMesh, hit.Reason);
        }

        [Fact]
        public void WalkOutOverTheEdgeIsBlockedAtOnce()
        {
            // on room A's eroded edge, pointing out of it: a wall at zero, not a failed query
            var inst = Fresh();
            var hit = inst.Walk(new Vector3(0.4f, 0, 15), new Vector3(-6, 0, 15), NavAgent.Player);
            Assert.Equal(NavReason.Ok, hit.Reason);
            Assert.InRange(hit.T, 0.0f, 0.05f);
            // and back in from the same spot is clear
            Assert.True(inst.Walk(new Vector3(0.4f, 0, 15), new Vector3(10, 0, 15), NavAgent.Player).Clear);
        }

        [Fact]
        public void WalkTowardsNaNFailsWithoutThrowing()
        {
            var hit = Fresh().Walk(S.A, new Vector3(float.NaN, 0, 5), NavAgent.Player);
            Assert.Equal(NavReason.NoRoute, hit.Reason);
        }

        [Fact]
        public void WalkToAnotherFloorIsVerticalMismatch()
        {
            var hit = Fresh().Walk(new Vector3(105, 0, 21), new Vector3(105, 6, 21), NavAgent.Player);
            Assert.Equal(NavReason.VerticalMismatch, hit.Reason);
        }

        [Fact]
        public void CanSee()
        {
            var inst = Fresh();
            Assert.True(inst.CanSee(S.A, S.A2));
            Assert.False(inst.CanSee(new Vector3(25, 0, 5), new Vector3(40, 0, 5)));     // mesh edge between rooms
            Assert.True(inst.CanSee(new Vector3(25, 0, 15), new Vector3(40, 0, 15)));    // through the open door
            Assert.True(inst.CanSee(S.Top, S.DropPad));                                   // off the ledge, down
            Assert.True(inst.CanSee(S.DropPad, S.Top));                                   // and back up
            inst.SetGate("g1", false);
            Assert.False(inst.CanSee(new Vector3(25, 0, 15), new Vector3(40, 0, 15)));
        }

        [Fact]
        public void RandomPointStaysInTheRingAndIsReachable()
        {
            var inst = Fresh();
            for (int i = 0; i < 200; i++)
            {
                var p = inst.RandomPoint(S.ACenter, 3.0f, 8.0f, NavAgent.Mob);
                Assert.True(p.Ok, p.ToString());
                float d = Vector2.Distance(new Vector2(p.Position.X, p.Position.Z), new Vector2(S.ACenter.X, S.ACenter.Z));
                Assert.InRange(d, 3.0f, 8.0f);
                Assert.InRange(p.Position.Y, -0.3f, 0.3f); // never the pruned roof in the middle
                Assert.Equal(NavReason.Ok, inst.Reachable(S.ACenter, p.Position, NavAgent.Mob).Reason);
            }
        }

        [Fact]
        public void DisplaceStopsAtTheEdge()
        {
            var inst = Fresh();
            var free = inst.Displace(new Vector3(15, 0, 5), Vector3.UnitX, 5, NavAgent.Mob);
            Assert.Equal(NavReason.Ok, free.Reason);
            Assert.Equal(20, free.Position.X, 1);
            var blocked = inst.Displace(new Vector3(25, 0, 5), Vector3.UnitX, 10, NavAgent.Mob);
            Assert.Equal(NavReason.Partial, blocked.Reason);
            Assert.InRange(blocked.Position.X, 29f, 29.6f);
            Assert.InRange(blocked.Position.Y, -0.3f, 0.3f);
        }

        #endregion

        #region Reachable and gate state

        [Fact]
        public void ReachableFollowsGateVersion()
        {
            var inst = Fresh();
            int changes = 0;
            inst.GateChanged += (_, g, open) => changes++;
            int v0 = inst.GateVersion;
            Assert.Equal(NavReason.Ok, inst.Reachable(S.A, S.B, NavAgent.Mob).Reason);
            var cachedState = inst.Gates;

            inst.SetGate("g1", false);
            inst.SetGate("g1", false); // no change, no version bump
            inst.SetGate("g2", false);
            Assert.Equal(v0 + 2, inst.GateVersion);
            Assert.Equal(2, changes);
            Assert.NotSame(cachedState, inst.Gates);
            Assert.Equal(NavReason.GateClosed, inst.Reachable(S.A, S.B, NavAgent.Mob).Reason);
            Assert.Equal(NavReason.Ok, inst.Reachable(S.A, S.A2, NavAgent.Mob).Reason);

            inst.ResetGates();
            Assert.Equal(NavReason.Ok, inst.Reachable(S.A, S.B, NavAgent.Mob).Reason);
            Assert.False(inst.SetGate("missing", true));

            // instances on one world don't share gate state
            var other = World.CreateInstance("other");
            inst.SetGate("g1", false);
            inst.SetGate("g2", false);
            Assert.Equal(NavReason.Ok, other.Reachable(S.A, S.B, NavAgent.Mob).Reason);
        }

        [Fact]
        public void StatsCountCallsAndReasons()
        {
            var world = S.LoadWorld();
            var inst = world.CreateInstance();
            inst.PlanRoute(S.A, S.B, NavAgent.Mob);
            inst.PlanRoute(S.A, S.Roof, NavAgent.Mob);
            var c = world.Stats[NavOp.PlanRoute];
            Assert.Equal(2, c.Calls);
            Assert.Equal(1, c.Reasons[(int)NavReason.VerticalMismatch]);
            Assert.Equal(1, c.Failures);
            Assert.Equal(2, c.Buckets.Sum());
            Assert.Contains("PlanRoute", world.Stats.Summary());
        }

        #endregion

        #region Threading

        [Fact]
        public void ParallelQueriesMatchSequentialResults()
        {
            var inst = Fresh();
            var points = new[] { S.A, S.A2, S.B, S.E, S.Pad, S.Top, S.DropPad, S.ACenter, new Vector3(60, 0, 57), new Vector3(140, 0, 15) };
            var agents = new[] { NavAgent.Mob, NavAgent.Escort, NavAgent.Player };
            var expected = new ConcurrentDictionary<(int, int, int), (NavReason, int)>();
            for (int i = 0; i < points.Length; i++)
                for (int j = 0; j < points.Length; j++)
                    for (int a = 0; a < agents.Length; a++)
                    {
                        var r = inst.PlanRoute(points[i], points[j], agents[a]);
                        expected[(i, j, a)] = (r.Reason, r.Points.Count);
                    }

            var errors = new ConcurrentQueue<string>();
            Parallel.For(0, 4000, new ParallelOptions { MaxDegreeOfParallelism = 8 }, n =>
            {
                var rnd = new Random(n);
                int i = rnd.Next(points.Length), j = rnd.Next(points.Length), a = rnd.Next(agents.Length);
                var r = inst.PlanRoute(points[i], points[j], agents[a]);
                if ((r.Reason, r.Points.Count) != expected[(i, j, a)])
                    errors.Enqueue($"{i}->{j} {agents[a]}: {r.Reason}/{r.Points.Count} vs {expected[(i, j, a)]}");
                inst.Reachable(points[i], points[j], agents[a]);
                inst.CanSee(points[i], points[j]);
                inst.RandomPoint(points[i], 1, 6, agents[a]);
            });
            Assert.Empty(errors);
        }

        [Fact]
        public async Task GateTogglesUnderLoadNeverThrow()
        {
            var inst = Fresh();
            using (var stop = new CancellationTokenSource())
            {
                var toggler = Task.Run(() =>
                {
                    bool open = false;
                    while (!stop.IsCancellationRequested)
                    {
                        inst.SetGate("g1", open);
                        inst.SetGate("g2", !open);
                        open = !open;
                    }
                });
                var allowed = new[] { NavReason.Ok, NavReason.GateClosed };
                Parallel.For(0, 2000, n =>
                {
                    var r = inst.Reachable(S.A, S.B, NavAgent.Mob);
                    Assert.Contains(r.Reason, allowed);
                    var route = inst.PlanRoute(S.A, S.B, NavAgent.Mob);
                    Assert.Contains(route.Reason, allowed);
                });
                stop.Cancel();
                await toggler;
            }
        }

        #endregion
    }
}
