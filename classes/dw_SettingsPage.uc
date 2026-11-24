/* DualWield.dw_SettingsPage
 */
class dw_SettingsPage extends UT2K4MainPage;

function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
    local int i;

    Super.InitComponent(MyController, MyOwner);

	for ( i = 0; i < PanelCaption.Length && i < PanelClass.Length && i < PanelHint.Length; i++ )
	{
		c_Tabs.AddTab(PanelCaption[i], PanelClass[i],, PanelHint[i]);
	}
}

event Closed(GUIComponent Sender, bool bCancelled)
{
    local dw_DualWeapon dw;

    super.Closed(Sender, bCancelled);
    
    foreach PlayerOwner().DynamicActors(class'dw_DualWeapon', dw)
    { // for immediate config changes in-game
        dw.ReloadConfig();
    }
}

defaultproperties
{
	Begin Object Class=GUIHeader Name=MyHeader
		Caption="Dual Wielding Configuration"
		RenderWeight=0.300000
	End Object
	t_Header=GUIHeader'DualWieldV1.dw_SettingsPage.MyHeader'

	Begin Object Class=dw_ButtonFooter Name=MyFooter
		RenderWeight=0.300000
		TabOrder=4
		OnPreDraw=MyFooter.InternalOnPreDraw
	End Object
	t_Footer=dw_ButtonFooter'DualWieldV1.dw_SettingsPage.MyFooter'

	PanelClass(0)="DualWieldV1.dw_OptionsTab"
	PanelClass(1)="DualWieldV1.dw_WeaponsTab"
	PanelClass(2)="DualWieldV1.dw_KeyBindTab"
	PanelCaption(0)="Options"
	PanelCaption(1)="Weapons"
	PanelCaption(2)="Controls"
	PanelHint(0)="Configure various dual-wielding options..."
	PanelHint(1)="Configure the restrictions on which weapons can be dual-wielded..."
	PanelHint(2)="Configure dual-wielding key-bindings..."
	bPauseIfPossible=True
	bPersistent=False
	bAllowedAsLast=True
}
