using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;

namespace Meteor.Map.DataObjects
{
    class RecipeResolver
    {
        Dictionary<uint, Recipe>  recipeList;
        Dictionary<string, List<Recipe>> matsToRecipes;

        private RecipeResolver(Dictionary<uint, Recipe> recipeList, Dictionary<string, List<Recipe>> matsToRecipes)
        {
            this.recipeList = recipeList;
            this.matsToRecipes = matsToRecipes;
        }

        public static RecipeResolver Init()
        {
            var recipeList = new Dictionary<uint, Recipe>();
            var matToRecipes = new Dictionary<string, List<Recipe>>();

            Database.GetRecipeGamedata(recipeList, matToRecipes);

            return new RecipeResolver(recipeList, matToRecipes);
        }

        public List<Recipe> GetRecipeFromMats(uint mat1 = 0, uint mat2 = 0, uint mat3 = 0, uint mat4 = 0, uint mat5 = 0, uint mat6 = 0, uint mat7 = 0, uint mat8 = 0)
        {
            uint[] mats = new uint[8];
            mats[0] = mat1;
            mats[1] = mat2;
            mats[2] = mat3;
            mats[3] = mat4;
            mats[4] = mat5;
            mats[5] = mat6;
            mats[6] = mat7;
            mats[7] = mat8;

            Array.Sort(mats);

            byte[] result = new byte[8 * sizeof(int)];
            Buffer.BlockCopy(mats, 0, result, 0, result.Length);
            string hash;
            using (MD5 md5 = MD5.Create())
            {
                hash = BitConverter.ToString(md5.ComputeHash(result));
            }

            if (matsToRecipes.ContainsKey(hash))
                return matsToRecipes[hash];
            else
                return null;
        }

        public Recipe GetRecipeByItemID(int objectiveItemID)
        {
            return recipeList.Values.FirstOrDefault(recipe => recipe.resultItemID == objectiveItemID);
        }

        public Recipe GetRecipeByID(uint recipeID)
        {
            if (recipeID == 0)
                return null;
            return GetMatsForRecipe(recipeID);
        }

        public Recipe GetMatsForRecipe(uint recipeID)
        {
            if (recipeList.ContainsKey(recipeID))
                return recipeList[recipeID];
            else
                return null;
        }

        public int GetNumRecipes()
        {
            return recipeList.Count;
        }
    }
}
