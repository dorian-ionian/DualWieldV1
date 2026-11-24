/* DualWield.dw_OptionsTab
 */
class dw_OptionsTab extends UT2K4TabPanel;

var automated GUISectionBackground bg_Misc, bg_Firing, bg_HUD;
var automated GUISectionBackground bg_Controls, bg_Commands;

// Misc
var automated moCheckBox ch_AllowAkimbo, ch_DisableDualAR, ch_EncourageBots;
// Firing
var automated moCheckBox ch_NoZoom,      ch_MergeAkimbo,   ch_SpacedFiring;
// Rendering/HUD
var automated moCheckBox  ch_DisplayModes, ch_AutoSwitchAmmo;
var automated moFloatEdit ed_NameFadeTime;
var automated moComboBox  cb_ZoomRender;
// Controls
var automated moCheckBox ch_SingleButton, ch_ControlSetMode, ch_FireSetMode,
                         ch_WeaponSwitch, ch_MiddleMouseToBest,
                         ch_QuickZoom,    ch_ThrowWeapon;
// Sub-weapon Commands
var automated GUIEditBox ed_NewCommand;
var automated GUIListBox lb_Commands;
var automated GUIButton  btn_AddCommand, btn_DelCommand, btn_SetCommand;


var           string ZoomRenderConditions[5];
var localized string ZoomRenderConditionDescriptions[5];

var localized string FireSetModeText, FireToggleModeText,
                     FireSetModeDesc, FireToggleModeDesc;

event InitComponent(GUIController MyController, GUIComponent MyOwner)
{
    local int i;

    super.InitComponent(MyController, MyOwner);
    
    for (i = 0; i < ArrayCount(ZoomRenderConditions); ++i)
        cb_ZoomRender.AddItem(ZoomRenderConditionDescriptions[i],, ZoomRenderConditions[i]);
    
    // Misc
    bg_Misc.ManageComponent(ch_AllowAkimbo);
    bg_Misc.ManageComponent(ch_DisableDualAR);
    bg_Misc.ManageComponent(ch_EncourageBots);
    
    // Firing
    bg_Firing.ManageComponent(ch_NoZoom);
    bg_Firing.ManageComponent(ch_MergeAkimbo);
    bg_Firing.ManageComponent(ch_SpacedFiring);
    
    // HUD
    bg_HUD.ManageComponent(ch_DisplayModes);
    bg_HUD.ManageComponent(ch_AutoSwitchAmmo);
    bg_HUD.ManageComponent(ed_NameFadeTime);
    bg_HUD.ManageComponent(cb_ZoomRender);
    
    // Controls
    bg_Controls.ManageComponent(ch_SingleButton);
    bg_Controls.ManageComponent(ch_ControlSetMode);
    bg_Controls.ManageComponent(ch_FireSetMode);
    bg_Controls.ManageComponent(ch_WeaponSwitch);
    bg_Controls.ManageComponent(ch_QuickZoom);
    bg_Controls.ManageComponent(ch_ThrowWeapon);
    bg_Controls.ManageComponent(ch_MiddleMouseToBest);

    // Components are created by ManageComponent, so load values only after that
    LoadSettings();

    SingleButtonCheck_Change(none);
    MergeAkimboCheck_Change(none);
}

function MutDualWield FindMutator()
{
    local MutDualWield mut;

    foreach PlayerOwner().DynamicActors(class'MutDualWield', mut)
        return mut;

    return none;
}

function string BoolFlag(bool b)
{
    if (b)
        return "1";
    return "0";
}

// Server-wide rules can only be changed by the server's admin (or locally, when not a remote client).
function bool CanEditServerRules()
{
    local PlayerController PC;

    PC = PlayerOwner();
    if (PC == none || PC.Level.NetMode != NM_Client || PC.PlayerReplicationInfo == none)
        return true;
    return PC.PlayerReplicationInfo.bAdmin;
}

function LoadSettings()
{
    local int i;
    local MutDualWield mut;

    // Misc (the server's copy, replicated to clients, when the mutator exists)
    mut = FindMutator();
    if (mut != none)
    {
        ch_AllowAkimbo.Checked(mut.bAllowAkimbo);
        ch_DisableDualAR.Checked(mut.bDisableDualARs);
        ch_EncourageBots.Checked(mut.bEncourageBotDualing);
    }
    else
    {
        ch_AllowAkimbo.Checked(class'MutDualWield'.default.bAllowAkimbo);
        ch_DisableDualAR.Checked(class'MutDualWield'.default.bDisableDualARs);
        ch_EncourageBots.Checked(class'MutDualWield'.default.bEncourageBotDualing);
    }
    if (CanEditServerRules())
    {
        ch_AllowAkimbo.EnableMe();
        ch_DisableDualAR.EnableMe();
        ch_EncourageBots.EnableMe();
    }
    else
    {
        ch_AllowAkimbo.DisableMe();
        ch_DisableDualAR.DisableMe();
        ch_EncourageBots.DisableMe();
    }

    // Firing
    ch_NoZoom.Checked(class'dw_FiringModule'.default.bDisallowZoom);
    ch_MergeAkimbo.Checked(class'dw_FiringModule'.default.bMergeAkimbo);
    ch_SpacedFiring.Checked(class'dw_FiringModule'.default.bSpacedFiring);
    
    // HUD
    ch_DisplayModes.Checked(class'dw_RenderingModule'.default.bDisplayFireModes);
    ch_AutoSwitchAmmo.Checked(class'dw_RenderingModule'.default.bAutoSwitchAmmo);
    ed_NameFadeTime.SetValue(class'dw_RenderingModule'.default.WeaponNameFadeTime);
    cb_ZoomRender.Find(class'dw_RenderingModule'.default.ZoomRenderString,, true);
    
    // Controls
    ch_SingleButton.Checked(class'dw_ControlModule'.default.bSingleButtonMode);
    ch_ControlSetMode.Checked(class'dw_ControlModule'.default.bEnableControlSetMode);
    ch_FireSetMode.Checked(class'dw_ControlModule'.default.bEnableFireSetMode);
    ch_WeaponSwitch.Checked(class'dw_ControlModule'.default.bEnableWeaponSwitch);
    ch_MiddleMouseToBest.Checked(class'dw_ControlModule'.default.bEnableMouseBestWeapon);
    ch_QuickZoom.Checked(class'dw_ControlModule'.default.bEnableQuickZoom);
    ch_ThrowWeapon.Checked(class'dw_ControlModule'.default.bEnableThrowWeapon);
    
    // Sub-weapon Commands
    for (i = 0; i < class'dw_ControlModule'.default.SubWeaponCommands.Length; ++i)
        lb_Commands.List.Add(class'dw_ControlModule'.default.SubWeaponCommands[i]);
}

function SaveSettings()
{
    local int i;
    local MutDualWield mut;
    local dw_DualWeapon dw;
    local string flags;
    
    // Misc
    if (PlayerOwner().Level.NetMode == NM_Client)
    { // the server owns these rules: it saves them and replicates them back
        if (CanEditServerRules())
        {
            flags = BoolFlag(ch_AllowAkimbo.IsChecked()) $ BoolFlag(ch_DisableDualAR.IsChecked())
                  $ BoolFlag(ch_EncourageBots.IsChecked());
            PlayerOwner().ConsoleCommand("mutate DualWieldSet" $ flags);
        }
    }
    else
    {
        class'MutDualWield'.default.bAllowAkimbo         = ch_AllowAkimbo.IsChecked();
        class'MutDualWield'.default.bDisableDualARs      = ch_DisableDualAR.IsChecked();
        class'MutDualWield'.default.bEncourageBotDualing = ch_EncourageBots.IsChecked();
        class'MutDualWield'.static.StaticSaveConfig();

        // for in-game config
        foreach PlayerOwner().DynamicActors(class'MutDualWield', mut)
        {
            mut.bAllowAkimbo         = mut.default.bAllowAkimbo;
            mut.bDisableDualARs      = mut.default.bDisableDualARs;
            mut.bEncourageBotDualing = mut.default.bEncourageBotDualing;
        }
    }
    
    // Firing
    class'dw_FiringModule'.default.bDisallowZoom = ch_NoZoom.IsChecked();
    class'dw_FiringModule'.default.bMergeAkimbo  = ch_MergeAkimbo.IsChecked();
    class'dw_FiringModule'.default.bSpacedFiring = ch_SpacedFiring.IsChecked();
    class'dw_FiringModule'.static.StaticSaveConfig();
    // Rendering/HUD
    class'dw_RenderingModule'.default.bDisplayFireModes  = ch_DisplayModes.IsChecked();
    class'dw_RenderingModule'.default.bAutoSwitchAmmo    = ch_AutoSwitchAmmo.IsChecked();
    class'dw_RenderingModule'.default.WeaponNameFadeTime = ed_NameFadeTime.GetValue();
    class'dw_RenderingModule'.default.ZoomRenderString   = cb_ZoomRender.GetExtra();
    class'dw_RenderingModule'.static.StaticSaveConfig();

    // Controls
    class'dw_ControlModule'.default.bSingleButtonMode       = ch_SingleButton.IsChecked();
    class'dw_ControlModule'.default.bEnableControlSetMode   = ch_ControlSetMode.IsChecked();
    class'dw_ControlModule'.default.bEnableFireSetMode      = ch_FireSetMode.IsChecked();
    class'dw_ControlModule'.default.bEnableWeaponSwitch     = ch_WeaponSwitch.IsChecked();
    class'dw_ControlModule'.default.bEnableMouseBestWeapon  = ch_MiddleMouseToBest.IsChecked();
    class'dw_ControlModule'.default.bEnableQuickZoom        = ch_QuickZoom.IsChecked();
    class'dw_ControlModule'.default.bEnableThrowWeapon      = ch_ThrowWeapon.IsChecked();
    
    // Sub-weapon Commands
    class'dw_ControlModule'.default.SubWeaponCommands.Length = lb_Commands.List.ItemCount;
    for (i = 0; i < lb_Commands.List.ItemCount; ++i)
        class'dw_ControlModule'.default.SubWeaponCommands[i] = lb_Commands.List.GetItemAtIndex(i);

    class'dw_ControlModule'.static.StaticSaveConfig();
    
    // all settings are saved, so apply them to the in-game weapons now
    foreach PlayerOwner().DynamicActors(class'dw_DualWeapon', dw)
        dw.ReloadConfig();
}

function SingleButtonCheck_Change(GUIComponent Sender)
{
    if (ch_SingleButton.IsChecked())
    {
        // control key toggles dual-wielding mode
        ch_ControlSetMode.DisableMe();
        // control+fire toggles fire-mode for left weapon
        ch_FireSetMode.SetCaption(FireToggleModeText);
        ch_FireSetMode.SetHint(FireToggleModeDesc);
        ch_QuickZoom.DisableMe();
    }
    else
    {
        // control keys may toggle fire-modes
        ch_ControlSetMode.EnableMe();
        // left control+fire sets fire-mode for left weapon to primary
        ch_FireSetMode.SetCaption(FireSetModeText);
        ch_FireSetMode.SetHint(FireSetModeDesc);
        // or does quick-zoom
        ch_QuickZoom.EnableMe();
    }
}

function MergeAkimboCheck_Change(GUIComponent Sender)
{
    // Spaced Firing has no effect if Merge Akimbo is disabled.
    if (ch_MergeAkimbo.IsChecked())
        ch_SpacedFiring.EnableMe();
    else
        ch_SpacedFiring.DisableMe();
}

function bool InternalPreDraw(Canvas C)
{
    local float FrameTop, FrameHeight, AH;
    local float Offset;

    AH = ActualHeight();
	FrameTop    = AH * bg_Commands.WinTop    + 44;
	FrameHeight = AH * bg_Commands.WinHeight - 62;

	Offset = AH * 0.065;
	
    ed_NewCommand.WinTop  = FrameTop;
    lb_Commands.WinTop    = FrameTop + Offset;
    lb_Commands.WinHeight = FrameHeight - Offset;

	Offset = AH * 0.05;
	
    btn_AddCommand.WinTop = FrameTop;
    btn_DelCommand.WinTop = FrameTop + Offset;
    btn_SetCommand.WinTop = FrameTop + Offset*2;

	return false;
}

event Closed(GUIComponent Sender, bool bCancelled)
{
    super.Closed(Sender, bCancelled);
    
    if (!bCancelled)
        SaveSettings();
}

function bool AddCommand_Click(GUIComponent Sender)
{
    if (ed_NewCommand.GetText() != "")
        lb_Commands.List.Add(ed_NewCommand.GetText());
    return true;
}

function bool DelCommand_Click(GUIComponent Sender)
{
    if (lb_Commands.List.Index != -1)
        lb_Commands.List.Remove(lb_Commands.List.Index);
    return true;
}

function bool SetCommand_Click(GUIComponent Sender)
{
    if (lb_Commands.List.Index != -1 && ed_NewCommand.GetText() != "")
        lb_Commands.List.Replace(lb_Commands.List.Index, ed_NewCommand.GetText());
    return true;
}

defaultproperties
{
	Begin Object Class=GUISectionBackground Name=MiscSection
		Caption="Misc"
		WinTop=0.010000
		WinWidth=0.500000
		WinHeight=0.285000
		OnPreDraw=MiscSection.InternalPreDraw
	End Object
	bg_Misc=GUISectionBackground'DualWieldV1.dw_OptionsTab.MiscSection'

	Begin Object Class=GUISectionBackground Name=FiringSection
		Caption="Firing"
		WinTop=0.307000
		WinWidth=0.500000
		WinHeight=0.285000
		OnPreDraw=FiringSection.InternalPreDraw
	End Object
	bg_Firing=GUISectionBackground'DualWieldV1.dw_OptionsTab.FiringSection'

	Begin Object Class=GUISectionBackground Name=HUDSection
		Caption="HUD"
		WinTop=0.605000
		WinWidth=0.500000
		WinHeight=0.385000
		OnPreDraw=HUDSection.InternalPreDraw
	End Object
	bg_HUD=GUISectionBackground'DualWieldV1.dw_OptionsTab.HUDSection'

	Begin Object Class=GUISectionBackground Name=ControlsSection
		Caption="Controls"
		WinTop=0.010000
		WinLeft=0.510000
		WinWidth=0.490000
		WinHeight=0.490000
		OnPreDraw=ControlsSection.InternalPreDraw
	End Object
	bg_Controls=GUISectionBackground'DualWieldV1.dw_OptionsTab.ControlsSection'

	Begin Object Class=GUISectionBackground Name=CommandsSection
		Caption="Sub-Weapon Command Keys"
		WinTop=0.510000
		WinLeft=0.510000
		WinWidth=0.490000
		WinHeight=0.480000
		OnPreDraw=CommandsSection.InternalPreDraw
	End Object
	bg_Commands=GUISectionBackground'DualWieldV1.dw_OptionsTab.CommandsSection'

	Begin Object Class=moCheckBox Name=AllowAkimboCheck
		Caption="Allow Akimbo Weapons"
		OnCreateComponent=AllowAkimboCheck.InternalOnCreateComponent
		Hint="If enabled, players will be able to pick up two identical weapons to dual-wield."
		TabOrder=0
	End Object
	ch_AllowAkimbo=moCheckBox'DualWieldV1.dw_OptionsTab.AllowAkimboCheck'

	Begin Object Class=moCheckBox Name=DisableDualARCheck
		Caption="Disable Dual Assault Rifles"
		OnCreateComponent=DisableDualARCheck.InternalOnCreateComponent
		Hint="If enabled, picking up a second Assault Rifle won't enable 'dual mode', thus preventing you from dual-wielding the Assault Rifle with other weapons."
		TabOrder=1
	End Object
	ch_DisableDualAR=moCheckBox'DualWieldV1.dw_OptionsTab.DisableDualARCheck'

	Begin Object Class=moCheckBox Name=EncourageBotsCheck
		Caption="Encourage Bot Dual-Wielding"
		OnCreateComponent=EncourageBotsCheck.InternalOnCreateComponent
		Hint="If enabled, the Dual Weapon will get a rating boost to increase the likelihood of bots dual-wielding."
		TabOrder=2
	End Object
	ch_EncourageBots=moCheckBox'DualWieldV1.dw_OptionsTab.EncourageBotsCheck'

	Begin Object Class=moCheckBox Name=NoZoomCheck
		Caption="Disallow Zoom"
		OnCreateComponent=NoZoomCheck.InternalOnCreateComponent
		Hint="Prevent zoom fire-modes from being selected.  Zoom is still possible via the extra fire buttons."
		TabOrder=10
	End Object
	ch_NoZoom=moCheckBox'DualWieldV1.dw_OptionsTab.NoZoomCheck'

	Begin Object Class=moCheckBox Name=MergeAkimboCheck
		Caption="Merge Akimbo Weapons"
		OnCreateComponent=MergeAkimboCheck.InternalOnCreateComponent
		Hint="If enabled, Fire and AltFire control primary and alternate fire for both weapons when both weapons are identical."
		TabOrder=11
		OnChange=dw_OptionsTab.MergeAkimboCheck_Change
	End Object
	ch_MergeAkimbo=moCheckBox'DualWieldV1.dw_OptionsTab.MergeAkimboCheck'

	Begin Object Class=moCheckBox Name=SpacedFiringCheck
		Caption="Spaced Firing"
		OnCreateComponent=SpacedFiringCheck.InternalOnCreateComponent
		Hint="If enabled, firing will alternate between akimbo weapons, instead of both firing simultaneously.  This is always enabled for modes with colliding projectiles (e.g. Shock Rifle alt-fire.)"
		TabOrder=12
	End Object
	ch_SpacedFiring=moCheckBox'DualWieldV1.dw_OptionsTab.SpacedFiringCheck'

	Begin Object Class=moCheckBox Name=DisplayModesCheck
		Caption="Display Fire-Modes"
		OnCreateComponent=DisplayModesCheck.InternalOnCreateComponent
		Hint="If enabled, each weapon's selected fire-mode will be displayed on the HUD (near the crosshair.)"
		TabOrder=20
	End Object
	ch_DisplayModes=moCheckBox'DualWieldV1.dw_OptionsTab.DisplayModesCheck'

	Begin Object Class=moCheckBox Name=AutoSwitchAmmoCheck
		Caption="Auto-Switch Ammo Display"
		OnCreateComponent=AutoSwitchAmmoCheck.InternalOnCreateComponent
		Hint="If enabled, the ammo counter on the HUD will automatically show the ammo for the last weapon fired."
		TabOrder=21
	End Object
	ch_AutoSwitchAmmo=moCheckBox'DualWieldV1.dw_OptionsTab.AutoSwitchAmmoCheck'

	Begin Object Class=moFloatEdit Name=NameFadeTimeEdit
		MinValue=0.000000
		MaxValue=10.000000
		Caption="Weapon Name Fade Time"
		OnCreateComponent=NameFadeTimeEdit.InternalOnCreateComponent
		Hint="How long the weapon names displayed on the HUD take to fade out, or 0 to always show the weapon names."
		TabOrder=22
	End Object
	ed_NameFadeTime=moFloatEdit'DualWieldV1.dw_OptionsTab.NameFadeTimeEdit'

	Begin Object Class=moComboBox Name=ZoomRenderCombo
		bReadOnly=True
		Caption="Zoom Render Weapon"
		OnCreateComponent=ZoomRenderCombo.InternalOnCreateComponent
		Hint="Which weapon should be rendered while zoomed-in (if dual-wielding)?"
		TabOrder=23
	End Object
	cb_ZoomRender=moComboBox'DualWieldV1.dw_OptionsTab.ZoomRenderCombo'

	Begin Object Class=moCheckBox Name=SingleButtonCheck
		Caption="Single-Button Mode"
		OnCreateComponent=SingleButtonCheck.InternalOnCreateComponent
		Hint="Enable to make only one dual-wielding control key binding necessary."
		TabOrder=30
		OnChange=dw_OptionsTab.SingleButtonCheck_Change
	End Object
	ch_SingleButton=moCheckBox'DualWieldV1.dw_OptionsTab.SingleButtonCheck'

	Begin Object Class=moCheckBox Name=ControlSetModeCheck
		Caption="Toggle Fire-Mode w/ Control"
		OnCreateComponent=ControlSetModeCheck.InternalOnCreateComponent
		Hint="If enabled, pressing & releasing a dual-wielding control key toggles the selected fire-mode for its weapon."
		TabOrder=31
	End Object
	ch_ControlSetMode=moCheckBox'DualWieldV1.dw_OptionsTab.ControlSetModeCheck'

	Begin Object Class=moCheckBox Name=FireSetModeCheck
		Caption="Set Fire-Mode w/ Control+Fire"
		OnCreateComponent=FireSetModeCheck.InternalOnCreateComponent
		TabOrder=32
	End Object
	ch_FireSetMode=moCheckBox'DualWieldV1.dw_OptionsTab.FireSetModeCheck'

	Begin Object Class=moCheckBox Name=WeaponSwitchCheck
		Caption="Easy Weapon-Switching"
		OnCreateComponent=WeaponSwitchCheck.InternalOnCreateComponent
		Hint="If enabled, holding a dual-wielding control key causes weapon-switching keys to work for the relevant weapon/hand."
		TabOrder=33
	End Object
	ch_WeaponSwitch=moCheckBox'DualWieldV1.dw_OptionsTab.WeaponSwitchCheck'

	Begin Object Class=moCheckBox Name=MiddleMouseToBestCheck
		Caption="Middle-Mouse = SwitchToBest"
		OnCreateComponent=MiddleMouseToBestCheck.InternalOnCreateComponent
		Hint="If enabled, holding a dual-wielding control key causes the middle mouse button to act as a temporary Switch-to-best-weapon(s) key."
		TabOrder=36
	End Object
	ch_MiddleMouseToBest=moCheckBox'DualWieldV1.dw_OptionsTab.MiddleMouseToBestCheck'

	Begin Object Class=moCheckBox Name=QuickZoomCheck
		Caption="Easy Zoom"
		OnCreateComponent=QuickZoomCheck.InternalOnCreateComponent
		Hint="If enabled, holding a dual-wielding control key and pressing AltFire while wielding a Sniper weapon activates zoom."
		TabOrder=34
	End Object
	ch_QuickZoom=moCheckBox'DualWieldV1.dw_OptionsTab.QuickZoomCheck'

	Begin Object Class=moCheckBox Name=ThrowWeaponCheck
		Caption="Easy Throw-Weapon"
		OnCreateComponent=ThrowWeaponCheck.InternalOnCreateComponent
		Hint="If enabled, holding a dual-wielding control key and pressing ThrowWeapon throws the relevant sub-weapon."
		TabOrder=35
	End Object
	ch_ThrowWeapon=moCheckBox'DualWieldV1.dw_OptionsTab.ThrowWeaponCheck'

	Begin Object Class=GUIEditBox Name=NewCommandEdit
		Hint="Type a key alias/command name to add to the list."
		WinTop=0.580000
		WinLeft=0.535000
		WinWidth=0.400000
		WinHeight=0.050000
		TabOrder=40
		OnActivate=NewCommandEdit.InternalActivate
		OnDeActivate=NewCommandEdit.InternalDeactivate
		OnKeyType=NewCommandEdit.InternalOnKeyType
		OnKeyEvent=NewCommandEdit.InternalOnKeyEvent
	End Object
	ed_NewCommand=GUIEditBox'DualWieldV1.dw_OptionsTab.NewCommandEdit'

	Begin Object Class=GUIListBox Name=CommandsLB
		bVisibleWhenEmpty=True
		bSorted=True
		OnCreateComponent=CommandsLB.InternalOnCreateComponent
		StyleName="ListBox"
		Hint="Lists key aliases which can be used on specific sub-weapons while holding a control key. (e.g. Left Control + Reload *KEY* = reload for left weapon.)"
		WinTop=0.645000
		WinLeft=0.535000
		WinWidth=0.400000
		WinHeight=0.320000
		TabOrder=41
	End Object
	lb_Commands=GUIListBox'DualWieldV1.dw_OptionsTab.CommandsLB'

	Begin Object Class=GUIButton Name=AddCommandButton
		Caption="+"
		Hint="Add a command to the list."
		WinTop=0.580000
		WinLeft=0.940000
		WinWidth=0.040000
		WinHeight=0.050000
		TabOrder=42
		OnClick=dw_OptionsTab.AddCommand_Click
		OnKeyEvent=AddCommandButton.InternalOnKeyEvent
	End Object
	btn_AddCommand=GUIButton'DualWieldV1.dw_OptionsTab.AddCommandButton'

	Begin Object Class=GUIButton Name=DelCommandButton
		Caption="-"
		Hint="Remove a command from the list."
		WinTop=0.630000
		WinLeft=0.940000
		WinWidth=0.040000
		WinHeight=0.050000
		TabOrder=43
		OnClick=dw_OptionsTab.DelCommand_Click
		OnKeyEvent=DelCommandButton.InternalOnKeyEvent
	End Object
	btn_DelCommand=GUIButton'DualWieldV1.dw_OptionsTab.DelCommandButton'

	Begin Object Class=GUIButton Name=SetCommandButton
		Caption="="
		Hint="Replace the selected command."
		WinTop=0.680000
		WinLeft=0.940000
		WinWidth=0.040000
		WinHeight=0.050000
		TabOrder=44
		OnClick=dw_OptionsTab.SetCommand_Click
		OnKeyEvent=SetCommandButton.InternalOnKeyEvent
	End Object
	btn_SetCommand=GUIButton'DualWieldV1.dw_OptionsTab.SetCommandButton'

	ZoomRenderConditions(0)="ZR_Never"
	ZoomRenderConditions(1)="ZR_AlwaysLeft"
	ZoomRenderConditions(2)="ZR_AlwaysRight"
	ZoomRenderConditions(3)="ZR_AlwaysBoth"
	ZoomRenderConditions(4)="ZR_FirstSniper"
	ZoomRenderConditionDescriptions(0)="Neither"
	ZoomRenderConditionDescriptions(1)="Always Left"
	ZoomRenderConditionDescriptions(2)="Always Right"
	ZoomRenderConditionDescriptions(3)="Always Both"
	ZoomRenderConditionDescriptions(4)="First Sniper"
	FireSetModeText="Set Fire-Mode w/ Control+Fire"
	FireToggleModeText="Toggle Fire-Mode w/ Control+Fire"
	FireSetModeDesc="If enabled, pressing Fire/AltFire while holding a dual-wielding control key sets the active fire-mode for the relevant weapon."
	FireToggleModeDesc="If enabled, pressing Fire/AltFire while holding the dual-wielding control key toggles the active fire-mode for the left/right weapon."
	PanelCaption="Options"
	WinTop=0.150000
	WinHeight=0.740000
	OnPreDraw=dw_OptionsTab.InternalPreDraw
}
