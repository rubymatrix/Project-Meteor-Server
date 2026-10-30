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

namespace Meteor.Map.DataObjects
{
    // One model's size record (gamedata_model_size): scales in thousandths per appearance SIZE index,
    // body and pick radii in tenths of a yalm before scale.
    class ModelSizeRow
    {
        public short[] Scales = new short[8];
        public byte BodyRadius, PickRadius;
        public bool Flyer;
    }

    // The scale and body radius the client derives from a model and its appearance SIZE slot:
    // scale = table[size] / 1000, radius = base * 0.1 * scale. This is the melee spacing size, not the
    // collision capsule, which is 0.5 for everyone.
    static class ModelSize
    {
        public const float PLAYER_BODY_RADIUS = 0.30f;
        // A model without size data gets the collision capsule's radius.
        public const float DEFAULT_BODY_RADIUS = 0.5f;

        private static Dictionary<uint, ModelSizeRow> rows = new Dictionary<uint, ModelSizeRow>();

        public static int Count => rows.Count;

        public static void Load(Dictionary<uint, ModelSizeRow> table)
        {
            rows = table ?? new Dictionary<uint, ModelSizeRow>();
        }

        // The client reads appearance ids 0x100-9999 as monster model id - 0x100, which the table keeps
        // at 10000 + that.
        public static uint Normalize(uint modelId)
        {
            if (modelId >= 0x100 && modelId < 10000)
                return 10000 + (modelId - 0x100);
            return modelId;
        }

        public static ModelSizeRow Get(uint modelId)
        {
            rows.TryGetValue(Normalize(modelId), out ModelSizeRow row);
            return row;
        }

        public static float Scale(ModelSizeRow row, uint size)
        {
            if (row == null || size >= row.Scales.Length)
                return 1.0f;
            return row.Scales[size] / 1000.0f;
        }

        public static float BodyRadius(ModelSizeRow row, uint size, bool isPlayer)
        {
            if (row == null)
                return isPlayer ? PLAYER_BODY_RADIUS : DEFAULT_BODY_RADIUS;
            return row.BodyRadius * 0.1f * Scale(row, size);
        }

        public static float BodyRadius(uint modelId, uint size, bool isPlayer) => BodyRadius(Get(modelId), size, isPlayer);
    }
}
