/* DualWield.dw_ControlModuleSingle
 *   - Uses a single control button instead of two.
 *   - Hitting the control button toggles dual-wielding mode.
 *   - Weapon-switching keys, etc. apply to left/right weapon
 *    (depending on player handedness.)
 *   - Use the control button to perform actions on the other weapon.
 */
class dw_ControlModuleSingle extends dw_ControlModuleDefault;

simulated function PostNetBeginPlay()
{
    super.PostNetBeginPlay();
    
    if (Instigator == none)
        Instigator = Pawn(DW.Owner);

    if (Instigator != none && Instigator.IsLocallyControlled())
        DW.bNoVoluntarySwitch = true;
}

function ControlPressed(int hand)
{
    bSwitchOnRelease = true;
}

function ControlReleased(int hand)
{
    local int h;

    if (bSwitchOnRelease && Instigator.Weapon != none)
    {
        h = GetHand();

        if (DW.IsCurrentWeapon())
        { // put down a weapon, prefering to keep the one on the right side
            // (or left side if that is the player's preference)
            if (DW.Weapons[0] == none && DW.Weapons[1] == none)
            {
                if (Instigator.Controller != none)
                    Instigator.Controller.SwitchToBestWeapon();
                return;
            }

            if (DW.Weapons[h] == none)
                h = h^1;

            Instigator.PendingWeapon = DW.Weapons[h];
            Instigator.Weapon.PutDown();
        }
        else
        {
            if (DW.M_Weapons != none && Instigator.Weapon != none)
            {
                if (Instigator.Weapon != DW.Weapons[h])
                {
                    if (Instigator.Weapon == DW.Weapons[h^1])
                    { // already dual-wielding the weapon, just put it in the correct hand
                        DW.Weapons[h^1] = DW.Weapons[h];
                        DW.Weapons[h] = Instigator.Weapon;
                        
                        if (DW.Role < ROLE_Authority)
                            DW.ServerChangedSubWeapons(DW.Weapons[0], DW.Weapons[1]);
                        DW.ChangedSubWeapons();
                    }
                    else if (DW.M_Weapons.IsUsableWeapon(Instigator.Weapon, h))
                    { // put it in the correct hand
                        DW.Weapons[h] = Instigator.Weapon; // ensure *instant* switch
                        //DW.M_Weapons.SelectWeapon(Instigator.Weapon, h);
                        
                        if (DW.Role < ROLE_Authority)
                            DW.ServerChangedSubWeapon(h, Instigator.Weapon);
                        DW.ChangedSubWeapon(h);
                    }
                    else if (DW.Weapons[h] == none)
                    { // switch to best
                        DW.M_Weapons.SelectWeapon(DW.M_Weapons.GetBestUsableWeapon(h), h);
                    }
                }
                // select the best weapon to start dual-wielding
                if (DW.Weapons[h^1] == none)
                    DW.M_Weapons.SelectWeapon(DW.M_Weapons.GetBestUsableWeapon(h^1), h^1);
            }
            DW.SwitchToDualWeapon();
        }
    }
}

function bool KeyPressed(Interactions.EInputKey Key, string keybind, bool bControlLeft, bool bControlRight)
{
    local bool bControl, bDualWielding;

    if (bControlLeft || bControlRight)
        bControl = true;
    
    if (keybind ~= "Fire")
    {
        if (bControl && bEnableFireSetMode)
        {
            if (DW.M_Firing != none)
                DW.M_Firing.ToggleFireMode(0^DW.default.ExchangeFireModes);
            bSwitchOnRelease = false;
            return true;
        }
        return false;
    }
    else if (keybind ~= "AltFire")
    {
        if (bControl && bEnableFireSetMode)
        {
            if (DW.M_Firing != none)
                DW.M_Firing.ToggleFireMode(1^DW.default.ExchangeFireModes);
            bSwitchOnRelease = false;
            return true;
        }
        return false;
    }
    else if (keybind ~= "SwitchWeapon 10")
    { // don't override translocator key; for convenience
        return false;
    }
    
    bDualWielding = DW.IsCurrentWeapon();
    
    // don't auto-control weapon when exiting dual-wielding mode
    if (Instigator != none && Instigator.PendingWeapon != none && Instigator.PendingWeapon != DW)
        bDualWielding = false;

    if (GetHand() == 0) {
        bControlLeft = bDualWielding && !bControl;
        bControlRight = bControl;
    } else {
        bControlLeft = bControl;
        bControlRight = bDualWielding && !bControl;
    }
    
    if (super.KeyPressed(Key, keybind, bControlLeft, bControlRight))
    {
        if (!DW.IsCurrentWeapon())
            bSwitchOnRelease = true;
        return true;
    }
    return false;
}

protected function int GetHand()
{
    if (DW.Weapons[0] == none)
        return 1;
    else if (DW.Weapons[1] == none)
        return 0;

    if (Instigator != none && Instigator.Controller != none
       && Instigator.Controller.Handedness == -1)
        return 0; // left-handed
    else
        return 1; // right-handed
}

defaultproperties
{
}
