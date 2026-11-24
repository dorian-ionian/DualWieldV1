/* DualWield.dw_GUIList
 */
class dw_GUIList extends GUIList;

// Used by SortList.
delegate int CompareItem(GUIListElem ElemA, GUIListElem ElemB)
{
	return StrCmp(ElemA.ExtraStrData, ElemB.ExtraStrData);
}

defaultproperties
{
}
