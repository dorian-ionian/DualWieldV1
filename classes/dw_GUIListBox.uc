/* DualWield.dw_GUIListBox: Reports double-click!!!
 */
class dw_GUIListBox extends GUIListBox;

function bool InternalOnDblClick(GUIComponent Sender)
{
	OnDblClick(Self);
	return true;
}

defaultproperties
{
}
