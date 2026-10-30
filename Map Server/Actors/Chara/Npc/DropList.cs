using System.Collections.Generic;
using System.Linq;

namespace Meteor.Map.Actors
{
    // One row of server_battlenpc_drop_list. Rates are per 10000.
    class DropEntry
    {
        public byte groupId;        // 0 = independent roll; N = one roll per group, pick weighted by rate
        public ushort groupRate;
        public uint itemId;
        public ushort rate;
        public uint minQty, maxQty;
        public ushort hqRate;       // chance of +1 (quality 2) on top of a quality-1 row
        public byte quality;
        public byte requiredPart;   // 0 = always; 1..8 = only if that body part was broken this life (PartBreak)
    }

    struct DropResult
    {
        public uint itemId;
        public int quantity;
        public byte quality;
    }

    // A monster's loot table (Tools/seed/build_drop_seed.py), rolled once per eligible player per kill.
    class DropList
    {
        public const int MAX_ITEMS_PER_KILL = 10;

        public readonly List<DropEntry> entries = new List<DropEntry>();

        // brokenPartsMask: PartBreak.BrokenMask of the corpse (bit part - 1); -1 ignores part gates.
        public List<DropResult> Roll(int brokenPartsMask = -1)
        {
            var results = new List<DropResult>();
            // Part-gated rows (horn-break drops) count only when the part broke.
            var usable = entries.Where(e => e.requiredPart == 0 || brokenPartsMask == -1
                                            || (brokenPartsMask & (1 << (e.requiredPart - 1))) != 0).ToList();

            foreach (var entry in usable.Where(e => e.groupId == 0))
            {
                if (results.Count >= MAX_ITEMS_PER_KILL)
                    return results;
                if (Program.Random.Next(10000) < entry.rate)
                    results.Add(Make(entry));
            }

            foreach (var group in usable.Where(e => e.groupId != 0).GroupBy(e => e.groupId))
            {
                if (results.Count >= MAX_ITEMS_PER_KILL)
                    break;
                if (Program.Random.Next(10000) >= group.First().groupRate)
                    continue;
                int total = group.Sum(e => e.rate);
                if (total <= 0)
                    continue;
                int pick = Program.Random.Next(total);
                foreach (var entry in group)
                {
                    pick -= entry.rate;
                    if (pick < 0)
                    {
                        results.Add(Make(entry));
                        break;
                    }
                }
            }
            return results;
        }

        private static DropResult Make(DropEntry entry)
        {
            byte quality = entry.quality;
            if (quality == 1 && entry.hqRate > 0 && Program.Random.Next(10000) < entry.hqRate)
                quality = 2;
            int quantity = (int)entry.minQty;
            if (entry.maxQty > entry.minQty)
                quantity = Program.Random.Next((int)entry.minQty, (int)entry.maxQty + 1);
            return new DropResult { itemId = entry.itemId, quantity = quantity, quality = quality };
        }
    }
}
