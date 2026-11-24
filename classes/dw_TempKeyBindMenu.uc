//-----------------------------------------------------------
// Menu for binding temporary keys for Dual-Wielding
//-----------------------------------------------------------
class dw_TempKeyBindMenu extends KeyBindMenu
    config(DualWieldV1);

var automated moCheckBox ch_NeverShow;

var int tempIndex;

var Interactions.EInputKey LeftControlKey, RightControlKey;

function MapBindings()
{
    AddCustomBindings(class'dw_DualWieldKeyBinding'.default.KeyData);

    super.MapBindings();

    tempIndex = Bindings.Length;

    CreateAliasMapping("", "Temporary Keys", true);
    CreateAliasMapping("templeft", "Control Left Weapon", false);
    CreateAliasMapping("tempright", "Control Right Weapon", false);

    LeftControlKey = class'dw_DualWieldInteraction'.default.LeftControlKey;
    BindKeyToAlias(tempIndex + 1, int(LeftControlKey));

    RightControlKey = class'dw_DualWieldInteraction'.default.RightControlKey;
    BindKeyToAlias(tempIndex + 2, int(RightControlKey));
}

function SetKeyBind(int Index, int SubIndex, byte NewKey)
{
    if (Index >= tempIndex)
    {
        SubIndex = 0;

        RemoveExistingKey(Index, SubIndex);

        if (Index == (tempIndex + 1))
        {
            LeftControlKey = EInputKey(NewKey);

            if (RightControlKey == LeftControlKey)
            {
                RightControlKey = IK_None;
                if (Bindings[tempIndex + 2].BoundKeys.Length > 0)
                    Bindings[tempIndex + 2].BoundKeys.Remove(0,
                        Bindings[tempIndex + 2].BoundKeys.Length);
            }
        }
        else if (Index == (tempIndex + 2))
        {
            RightControlKey = EInputKey(NewKey);

            if (LeftControlKey == RightControlKey)
            {
                LeftControlKey = IK_None;
                if (Bindings[tempIndex + 1].BoundKeys.Length > 0)
                    Bindings[tempIndex + 1].BoundKeys.Remove(0,
                        Bindings[tempIndex + 1].BoundKeys.Length);
            }
        }
        else
        {
            Warn("Tried to SetKeyBind with invalid index "$Index$" - tempIndex == "$tempIndex);
            return;
        }
        BindKeyToAlias(Index, NewKey);

        li_Binds.UpdatedItem(Index);
    }
    else
        super.SetKeyBind(Index, SubIndex, NewKey);
}

function RemoveExistingKey(int Index, int SubIndex)
{
    if (Index < tempIndex)
    {
        super.RemoveExistingKey(Index, SubIndex);
        return;
    }

    if ( !ValidBindIndex(Index) )
        return;

    if ( SubIndex >= Bindings[Index].BoundKeys.Length || Bindings[Index].BoundKeys[SubIndex] < 0 )
        return;

    Bindings[Index].BoundKeys.Remove(SubIndex, 1);

    if (Index == (tempIndex + 1))
       LeftControlKey = IK_None;
    else if (Index == (tempIndex + 2))
       RightControlKey = IK_None;
}

function AddCustomBindings( array<GUIUserKeyBinding.KeyInfo> KeyData )
{
    local int i;

    for ( i = 0; i < KeyData.Length; i++ )
        CreateAliasMapping( KeyData[i].Alias, KeyData[i].KeyLabel, KeyData[i].bIsSection );
}

function ClearBindings()
{
    Super.ClearBindings();
    Bindings = default.Bindings;
}

function AlignButtons()
{
    Super.AlignButtons();

    ch_NeverShow.WinTop = b_Cancel.WinTop - 0.04;
    ch_NeverShow.WinLeft = b_Cancel.WinLeft;
    ch_NeverShow.WinWidth = b_Cancel.WinWidth + b_OK.WinWidth;
}

event Closed(GUIComponent Sender, bool bCancelled)
{
    local dw_DualWieldInteraction dwInteraction;

    Super.Closed(Sender,bCancelled);

    if (!bCancelled)
    {
        class'dw_DualWieldInteraction'.default.bSuppressKeyBindMenu = ch_NeverShow.IsChecked();
        class'dw_DualWieldInteraction'.default.LeftControlKey = LeftControlKey;
        class'dw_DualWieldInteraction'.default.RightControlKey = RightControlKey;
        class'dw_DualWieldInteraction'.static.StaticSaveConfig();

        dwInteraction = FindInteraction();
        if (dwInteraction != none)
        {
            dwInteraction.LeftControlKey = LeftControlKey;
            dwInteraction.RightControlKey = RightControlKey;
        }
    }
}

function dw_DualWieldInteraction FindInteraction()
{
    local PlayerController PC;
    local int i;

    PC = PlayerOwner();
    if (PC != none && PC.Player != none)
    {
        for (i = 0; i < PC.Player.LocalInteractions.Length; i++)
        {
            if (dw_DualWieldInteraction(PC.Player.LocalInteractions[i]) != none)
                return dw_DualWieldInteraction(PC.Player.LocalInteractions[i]);
        }
    }
    return none;
}

defaultproperties
{
	Begin Object Class=moCheckBox Name=NeverShowButton
		Caption="Never ask me again"
		OnCreateComponent=NeverShowButton.InternalOnCreateComponent
		Hint="Do not show this configuration window again, even if only temporary keys are bound."
		WinTop=0.832397
		WinLeft=0.512695
		WinWidth=0.319298
		WinHeight=0.040000
		RenderWeight=1.000000
		TabOrder=98
		bBoundToParent=True
	End Object
	ch_NeverShow=moCheckBox'DualWieldV1.dw_TempKeyBindMenu.NeverShowButton'

	PageCaption="Configure Dual Wielding Keys"
	bAllowedAsLast=True
}
