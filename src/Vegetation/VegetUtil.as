namespace Veget {
	bool DoesItemModelHaveVeget(NPlugItem_SVariantList@ varList, bool randYawMustBeTrue, int variant = -1) {
		if (varList is null) return false;
		int minVar = Math::Max(variant, 0);
		int maxVar = MathX::Max(uint(variant + 1), varList.Variants.Length);
		// for (uint i = 0; i < varList.Variants.Length; i++) {
		for (int i = minVar; i < maxVar; i++) {
			auto em = varList.Variants[i].EntityModel;
			auto treeModel = cast<CPlugVegetTreeModel>(em);
			if (treeModel is null) continue;
			if (randYawMustBeTrue && !treeModel.Data.Params_EnableRandomRotationY) continue;
			return true;
		}
		return false;
	}

	bool DoesItemModelHaveVeget(CGameItemModel@ model, bool randYawMustBeTrue, int variant = -1) {
		if (model is null) return false;
		auto varList = cast<NPlugItem_SVariantList>(model.EntityModel);
		if (varList !is null) return DoesItemModelHaveVeget(varList, randYawMustBeTrue, variant);
		// could do prefabs here too
		return false;
	}
}
