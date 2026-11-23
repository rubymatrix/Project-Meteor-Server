using Meteor.Common;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Meteor.Map.Actors.QuestNS
{
    class QuestData
    {
        private Player owner;
        private Quest parent;

        private uint flags;
        private ushort counter1;
        private ushort counter2;
        private ushort counter3;
        private ushort counter4;
        private uint time;

        private uint npcLsFrom = 0;
        private byte npcLsMessageStep = 0;

        public bool Dirty { get; private set; } = false;

        public QuestData(Player owner, Quest parent, uint flags, ushort counter1, ushort counter2, ushort counter3, ushort counter4, uint time, uint npcLsFrom, byte npcLsMessageStep)
        {
            this.owner = owner;
            this.parent = parent;
            this.flags = flags;
            this.counter1 = counter1;
            this.counter2 = counter2;
            this.counter3 = counter3;
            this.counter4 = counter4;
            this.time = time;
            this.npcLsFrom = npcLsFrom;
            this.npcLsMessageStep = npcLsMessageStep;
        }

        public QuestData(Player owner, Quest parent)
        {
            this.owner = owner;
            this.parent = parent;
            time = flags = counter1 = counter2 = counter3 = counter4 = 0;
        }

        public void ClearData()
        {
            time = flags = counter1 = counter2 = counter3 = counter4 = 0;
            Dirty = true;
        }

        public void SetFlag(int index)
        {
            if (index >= 0 && index < 32)
            {
                flags |= (uint)(1 << index);
                Dirty = true;
            }
        }

        public void ClearFlag(int index)
        {
            if (index >= 0 && index < 32)
            {
                flags &= (uint)~(1 << index);
                Dirty = true;
            }
        }

        public ushort IncCounter(int num)
        {
            Dirty = true;

            switch (num)
            {
                case 0:
                    counter1++;
                    return counter1;
                case 1:
                    counter2++;
                    return counter2;
                case 2:
                    counter3++;
                    return counter3;
                case 3:
                    counter4++;
                    return counter4;
            }

            Dirty = false;
            return 0;
        }

        public ushort DecCounter(int num)
        {
            Dirty = true;

            switch (num)
            {
                case 0:
                    counter1--;
                    return counter1;
                case 1:
                    counter2--;
                    return counter2;
                case 2:
                    counter3--;
                    return counter3;
                case 3:
                    counter4--;
                    return counter4;
            }

            Dirty = false;
            return 0;
        }

        public void SetCounter(int num, ushort value)
        {
            Dirty = true;

            switch (num)
            {
                case 0:
                    counter1 = value;
                    return;
                case 1:
                    counter2 = value;
                    return;
                case 2:
                    counter3 = value;
                    return;
                case 3:
                    counter4 = value;
                    return;
            }

            Dirty = false;
        }

        public bool GetFlag(int index)
        {
            if (index >= 0 && index < 32)
                return (flags & (uint)(1 << index)) != 0;
            return false;
        }

        public uint GetFlags()
        {
            return flags;
        }

        public ushort GetCounter(int num)
        {
            switch (num)
            {
                case 0:
                    return counter1;
                case 1:
                    return counter2;
                case 2:
                    return counter3;
                case 3:
                    return counter4;
            }

            return 0;
        }

        public void SetTimeNow()
        {
            time = Utils.UnixTimeStampUTC(GameClock.Now);
            Dirty = true;
        }

        public uint GetTime()
        {
            return time;
        }

        public void SetNpcLsFrom(uint from)
        {
            npcLsFrom = from;
            npcLsMessageStep = 1;
            Dirty = true;
        }

        public void IncrementNpcLsMsgStep()
        {
            npcLsMessageStep++;
            Dirty = true;
        }

        public uint GetNpcLsFrom()
        {
            return npcLsFrom;
        }

        public byte GetMsgStep()
        {
            return npcLsMessageStep;
        }

        public void ClearNpcLs()
        {
            npcLsFrom = 0;
        }

        public void ClearDirty()
        {
            Dirty = false;
        }        

        public void Save()
        {
            Database.UpdateQuest(owner, parent);
        }
    }
}
