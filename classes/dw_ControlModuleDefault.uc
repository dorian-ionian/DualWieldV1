/* DualWield.dw_ControlModuleDefault
 */
class dw_ControlModuleDefault extends dw_ControlModule;

var bool bZoomingLeft, bZoomingRight;
var bool bSwitchOnRelease;


function ControlPressed(int hand)
{
    if (!DW.IsCurrentWeapon()) {
        DW.SwitchToDualWeapon();
        bSwitchOnRelease = false;
    } else
        bSwitchOnRelease = true;
}

function ControlReleased(int hand)
{
    if (bEnableControlSetMode && bSwitchOnRelease && dw.M_Firing != none)
        dw.M_Firing.ToggleFireMode(hand);
}

function bool KeyPressed(Interactions.EInputKey Key, string keybind, bool bControlLeft, bool bControlRight)
{
    local int i;
    
    if (keybind ~= "dw_ExtraFireLeft")
    {
        if (dw.M_Firing != none)
            dw.M_Firing.bFireLeft = 1;
        return true;
    }
    else if (keybind ~= "dw_ExtraFireRight")
    {
        if (dw.M_Firing != none)
            dw.M_Firing.bFireRight = 1;
        return true;
    }

    // control-modified keys from now on
    if (!bControlLeft && !bControlRight)
        return false;

    if (keybind ~= "NextWeapon")
    {
        if (bEnableWeaponSwitch && dw.M_Weapons != none)
        {
            if (bControlLeft)
                dw.M_Weapons.NextLeftWeapon();
            if (bControlRight)
                dw.M_Weapons.NextRightWeapon();
        }
        // allow normal weapon-switch
        else return false;
    }
    else if (keybind ~= "PrevWeapon")
    {
        if (bEnableWeaponSwitch && dw.M_Weapons != none)
        {
            if (bControlLeft)
                dw.M_Weapons.PrevLeftWeapon();
            if (bControlRight)
                dw.M_Weapons.PrevRightWeapon();
        }
        else return false;
    }
    else if (keybind ~= "SwitchToBestWeapon")
    {
        if (bEnableWeaponSwitch && dw.M_Weapons != none)
        {
            if (bControlLeft && bControlRight)
                dw.M_Weapons.SwitchBothToBest();
            else if (bControlLeft)
                dw.M_Weapons.SwitchLeftToBest();
            else
                dw.M_Weapons.SwitchRightToBest();
        }
        else return false;
    }
    else if (keybind ~= "Fire")
    {
        if (bEnableQuickZoom || bEnableFireSetMode)
        {
            if (bControlLeft)
            {
                if (bEnableQuickZoom && FireModeIsZoom(dw.Weapons[0], 0))
                {
                    dw.Weapons[0].ClientStartFire(0);
                    // weapon will call ClientStopFire() if bIsFiring==true
                    // and the corresponding fire button is not being pressed.
                    dw.Weapons[0].GetFireMode(0).bIsFiring = false;
                    // remember we are zooming (so we can stop).
                    bZoomingLeft = true;
                }
                // control+fire = set sub-weapon mode to primary
                else if (bEnableFireSetMode)
                    dw.SetFireMode(0, 0);
            }
            if (bControlRight)
            {
                if (bEnableQuickZoom && FireModeIsZoom(dw.Weapons[1], 0))
                {
                    dw.Weapons[1].ClientStartFire(0);
                    dw.Weapons[1].GetFireMode(0).bIsFiring = false;
                    bZoomingRight = true;
                }
                else if (bEnableFireSetMode)
                    dw.SetFireMode(1, 0);
            }
        }
        // let Fire message through
        else return false;
    }
    else if (keybind ~= "AltFire")
    {
        if (bEnableQuickZoom || bEnableFireSetMode)
        {
            if (bControlLeft)
            {
                if (bEnableQuickZoom && FireModeIsZoom(dw.Weapons[0], 1))
                {
                    dw.Weapons[0].ClientStartFire(1);
                    dw.Weapons[0].GetFireMode(1).bIsFiring = false;
                    bZoomingLeft = true;
                }
                else if (bEnableFireSetMode)
                    dw.SetFireMode(0, 1);
            }
            if (bControlRight)
            {
                if (bEnableQuickZoom && FireModeIsZoom(dw.Weapons[1], 1))
                {
                    dw.Weapons[1].ClientStartFire(1);
                    dw.Weapons[1].GetFireMode(1).bIsFiring = false;
                    bZoomingRight = true;
                }
                else if (bEnableFireSetMode)
                    dw.SetFireMode(1, 1);
            }
        }
        // let AltFire message through
        else return false;
    }
    else if (keybind ~= "ShrinkHUD")
    {
        if (dw.M_Rendering != none)
        {
            dw.M_Rendering.bDisplayFireModes = !dw.M_Rendering.bDisplayFireModes;
            Instigator.ClientMessage("Dual Weapon: Display Fire-modes = "
                $ dw.M_Rendering.bDisplayFireModes);
            
            class'dw_RenderingModule'.default.bDisplayFireModes = dw.M_Rendering.bDisplayFireModes;
            class'dw_RenderingModule'.static.StaticSaveConfig();
        }
    }
    else if (keybind ~= "GrowHUD")
    {
        dw.IncrementZoomRenderCondition();
        
        if (dw.M_Rendering != none)
        {
            class'dw_RenderingModule'.default.ZoomRenderString
                = string(GetEnum(enum'EZoomRenderCondition', dw.M_Rendering.ZoomRenderCondition));
            class'dw_RenderingModule'.static.StaticSaveConfig();
        }
    }
    else if (keybind ~= "ThrowWeapon")
    {
        if (bEnableThrowWeapon)
        {
            if (bControlLeft)
                dw.ThrowSubWeapon(0);
            if (bControlRight)
                dw.ThrowSubWeapon(1);
        }
        else return false;
    }
    else if (Left(keybind, 13) ~= "SwitchWeapon ")
    {
        if (bEnableWeaponSwitch && dw.M_Weapons != none)
        {
            i = int(Mid(keybind, 13));
            if (bControlLeft)
                dw.M_Weapons.SwitchLeftWeapon(i);
            if (bControlRight)
                dw.M_Weapons.SwitchRightWeapon(i);
        }
        else return false;
    }
    else
    {
        if (bEnableCustomCommands)
        {
            if (bControlLeft && ShouldCommandSubWeapon(dw.Weapons[0], keybind))
            {
                i = 1;
                dw.CommandSubWeapon(0, keybind);
            }
            if (bControlRight && ShouldCommandSubWeapon(dw.Weapons[1], keybind))
            {
                i = 1;
                dw.CommandSubWeapon(1, keybind);
            }
        }
        if (i == 0)
        {
            if (bEnableMouseBestWeapon && Key == IK_MiddleMouse)
            {
                if (dw.M_Weapons != none)
                {   // quick switch-to-best-weapon
                    // (only if MiddleMouse isn't bound to any of the above)
                    if (bControlLeft && bControlRight)
                        dw.M_Weapons.SwitchBothToBest();
                    else if (bControlLeft)
                        dw.M_Weapons.SwitchLeftToBest();
                    else
                        dw.M_Weapons.SwitchRightToBest();
                }
            }
            // not a recognized key or command, return false
            else
                return false;
        }
    }

    // pressed a recognized key combo, don't switch-modes-on-release
    bSwitchOnRelease = false;
    return true;
}

function bool KeyReleased(Interactions.EInputKey Key, string keybind, bool bControlLeft, bool bControlRight)
{
    if (keybind ~= "dw_ExtraFireLeft")
    {
        if (dw.M_Firing != none)
            dw.M_Firing.bFireLeft = 0;
        return true;
    }
    else if (keybind ~= "dw_ExtraFireRight")
    {
        if (dw.M_Firing != none)
            dw.M_Firing.bFireRight = 0;
        return true;
    }

    // Quick-zoom (stop zoom when fire button is released)
    if (bZoomingLeft || bZoomingRight)
    {
        if (keybind ~= "Fire")
        {
            if (bZoomingLeft)
            {
                if (FireModeIsZoom(dw.Weapons[0], 0))
                    dw.Weapons[0].ClientStopFire(0);
                bZoomingLeft = false;
            }
            if (bZoomingRight)
            {
                if (FireModeIsZoom(dw.Weapons[1], 0))
                    dw.Weapons[1].ClientStopFire(0);
                bZoomingRight = false;
            }
        }
        else if (keybind ~= "AltFire")
        {
            if (bZoomingLeft)
            {
                if (FireModeIsZoom(dw.Weapons[0], 1))
                    dw.Weapons[0].ClientStopFire(1);
                bZoomingLeft = false;
            }
            if (bZoomingRight)
            {
                if (FireModeIsZoom(dw.Weapons[1], 1))
                    dw.Weapons[1].ClientStopFire(1);
                bZoomingRight = false;
            }
        }
    }
    return false;
}

// checks whether to zoom instead of changing modes
protected function bool FireModeIsZoom(Weapon w, int mode)
{
    if (w == none)
        return false;

    return class'dw_FiringModule'.static.IsZoomFireMode(w.GetFireMode(mode));
}

// Returns true if the command may be implemented by a sub-weapon.
protected function bool ShouldCommandSubWeapon(Weapon w, string command)
{
    local int i;

    for (i = 0; i < default.SubWeaponCommands.Length; i++)
        if (command ~= default.SubWeaponCommands[i])
            return true;

    return false;
}

defaultproperties
{
}
