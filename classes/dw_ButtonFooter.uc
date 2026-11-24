/* DualWield.dw_ButtonFooter
 */
class dw_ButtonFooter extends ButtonFooter;

var automated GUIButton b_OK, b_Cancel;

function bool InternalOnClick(GUIComponent Sender)
{
    if ( Sender == b_OK )
		Controller.CloseMenu(false);

	else if ( Sender == b_Cancel )
		Controller.CloseMenu(true);

	return true;
}

defaultproperties
{
	Begin Object Class=GUIButton Name=OkButton
		Caption="OK"
		StyleName="FooterButton"
		WinTop=0.085678
		WinHeight=0.036482
		RenderWeight=2.000000
		TabOrder=1
		bBoundToParent=True
		OnClick=dw_ButtonFooter.InternalOnClick
		OnKeyEvent=OkButton.InternalOnKeyEvent
	End Object
	b_OK=GUIButton'DualWieldV1.dw_ButtonFooter.OkButton'

	Begin Object Class=GUIButton Name=CancelButton
		Caption="CANCEL"
		StyleName="FooterButton"
		WinTop=0.085678
		WinLeft=0.885352
		WinWidth=0.114648
		WinHeight=0.036482
		RenderWeight=2.000000
		TabOrder=0
		bBoundToParent=True
		OnClick=dw_ButtonFooter.InternalOnClick
		OnKeyEvent=CancelButton.InternalOnKeyEvent
	End Object
	b_Cancel=GUIButton'DualWieldV1.dw_ButtonFooter.CancelButton'

}
