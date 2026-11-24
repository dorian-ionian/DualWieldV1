/* DualWield.dw_RenderingModuleDefault
 */
class dw_RenderingModuleDefault extends dw_RenderingModule;

// NOTE: Rendering Modules are client-side by default, so there
//       is no need to use the 'simulated' keyword, but custom
//       modules may override RemoteRole to replicate if desired,
//       in which case PostBeginPlay should be simulated.

/** RENDERING **/

simulated event Master_RenderOverlays(Canvas Canvas)
{
    local float OldHandedness, XL, YL;
    local int i, j;
    local bool bHiddenHand, bDrawLeft, bDrawRight, bFoundSniper;
    local Controller c;
    
    if (Instigator == none)
        Instigator = Pawn(DW.Owner);
    
    // Accessed Nones can be murder to the log file.
    if (Instigator == none)
        return;

    if (Instigator.Controller != none)
        c = Instigator.Controller;
    // for compatibility with passenger seats with ability to wield weapons
    else if (Instigator.DrivenVehicle != none)
        c = Instigator.DrivenVehicle.Controller;

    OldHandedness = c.Handedness;

    bHiddenHand = (OldHandedness < -1.0 || OldHandedness > 1.0);

    // if zoomed in while dual-wielding..
    if ((PlayerController(Instigator.Controller) != none)
        && (PlayerController(Instigator.Controller).DesiredFOV != PlayerController(Instigator.Controller).DefaultFOV)
        && (DW.Weapons[0] != none) && (DW.Weapons[1] != none))
    {
        switch (ZoomRenderCondition)
        {
            case ZR_AlwaysLeft:  bDrawLeft = true;                      break;
            case ZR_AlwaysRight:                    bDrawRight = true;  break;
            case ZR_AlwaysBoth:  bDrawLeft = true;  bDrawRight = true;  break;
            case ZR_FirstSniper:
                // find the first weapon with an active zoom fire-mode
                for (i = 0; i < 2; i++)
                {
                    if (DW.Weapons[i] == none)
                        continue;
                    
                    j = DW.M_Firing.SelectedFireMode(i);
                    if (j < 0 || j > 1) j = 1;

                    if (class'dw_FiringModule'.static.IsZoomFireMode(DW.Weapons[i].GetFireMode(j)))
                    {
                        bFoundSniper = true;
                        break;
                    }
                }
                // no active zoom fire-modes, find inactive zoom fire-modes
                if (!bFoundSniper)
                {
                    for (i = 0; i < 2; i++)
                    {
                        if (DW.Weapons[i] == none)
                            continue;

                        for (j = 0; j < 2; j++)
                        {
                            if (class'dw_FiringModule'.static.IsZoomFireMode(DW.Weapons[i].GetFireMode(j)))
                            {
                                bFoundSniper = true;
                                break;
                            }
                        }
                        if (bFoundSniper)
                            break;
                    }
                }
                // no zoom fire-modes, but RemoteStrikeWeapon has a
                // different kind of zoom, so check for a RemoteStrikeWeapon
                if (!bFoundSniper)
                {
                    for (i = 0; i < 2; i++)
                    {
                        if (DW.Weapons[i] != none && DW.Weapons[i].IsA('RemoteStrikeWeapon'))
                        {
                            bFoundSniper = true;
                            break;
                        }
                    }
                }
                // found a zoom-able weapon?
                if (bFoundSniper)
                {
                    if (i == 0)
                        bDrawLeft = true;
                    else
                        bDrawRight = true;
                }
        }
    }
    else
    {
        bDrawLeft = true;
        bDrawRight = true;
    }

    // use the crosshair for the first (right->left) visible weapon
    if (bDrawRight && (DW.Weapons[1] != none))
        i = 1;
    else if (bDrawLeft && (DW.Weapons[0] != none))
        i = 0;
    else
        i = -1;

    if (i > -1)
    {
        DW.CustomCrosshair             = DW.Weapons[i].CustomCrosshair;
        DW.CustomCrossHairColor        = DW.Weapons[i].CustomCrossHairColor;
        DW.CustomCrossHairScale        = DW.Weapons[i].CustomCrossHairScale;
        DW.CustomCrossHairTextureName  = DW.Weapons[i].CustomCrossHairTextureName;
        DW.CustomCrossHairTexture      = DW.Weapons[i].CustomCrossHairTexture;
        if (DW.CustomCrosshairTexture == none)
        {
            DW.CustomCrosshairTexture = Texture(DynamicLoadObject(DW.CustomCrossHairTextureName, class'Texture'));
            if (DW.CustomCrossHairTexture == none)
            {
                // couldn't load crosshair texture; don't try again
                DW.CustomCrossHairTextureName = "";
                DW.Weapons[i].CustomCrossHairTextureName = "";
            }
            else
                DW.Weapons[i].CustomCrossHairTexture = DW.CustomCrosshairTexture;
        }
    }
    else
    {
        // use default crosshair
        DW.CustomCrosshair = -1;
    }

    if (DW.Weapons[0] != none)
    {
        PreDrawFPSubWeapon(0);

        if (bDrawLeft && !bHiddenHand)
        {
            if (!bHiddenHand)
                c.Handedness = -1; // force left hand
            DW.Weapons[0].Hand = c.Handedness;
            DW.Weapons[0].RenderOverlays(Canvas);
        }
        else // just update the weapon's location
            UpdateSubWeaponPos(0);
    }

    if (DW.Weapons[1] != none)
    {
        PreDrawFPSubWeapon(1);

        if (bDrawRight && !bHiddenHand)
        {
            if (!bHiddenHand)
                c.Handedness = 1; // force right hand
            DW.Weapons[1].Hand = c.Handedness;
            DW.Weapons[1].RenderOverlays(Canvas);
        }
        else
            UpdateSubWeaponPos(1);
    }

    c.Handedness = OldHandedness;

    Canvas.Font = Canvas.MedFont;
    Canvas.StrLen("X", XL, YL);
    for (i = 0; i < 2; i++)
    {
        //fade time 0 = never hide the name
        if (DW.Weapons[i] != none && (WeaponNameFadeTime <= 0 || WeaponNameTime[i] > 0))
        {
            Canvas.DrawColor = DW.Weapons[i].HudColor;
            if (WeaponNameFadeTime > 0)
                Canvas.DrawColor.A = byte(255.0 * (WeaponNameTime[i] / WeaponNameFadeTime));

            Canvas.DrawTextJustified(DW.Weapons[i].ItemName, i*2,
                               10, Canvas.ClipY * 0.5 - YL * 0.5,
                Canvas.ClipX - 10, Canvas.ClipY * 0.5 + YL * 0.5);
        }
    }

    // draw selected fire modes
    if (bDisplayFireModes && DW.M_Firing != none && DW.M_Firing.DisplayFireModes()
        && DW.Weapons[0] != none && DW.Weapons[1] != none)
    {
        Canvas.Font = Canvas.SmallFont;

        if ( DW.M_Firing.DisplayFireMode(0) )
        {
            Canvas.SetPos(Canvas.ClipX * 0.45, Canvas.ClipY * 0.55);
            Canvas.DrawColor = DW.CustomCrossHairColor;
            Canvas.DrawText( DW.M_Firing.SelectedFireMode(0) );
        }

        if ( DW.M_Firing.DisplayFireMode(1) )
        {
            Canvas.SetPos(Canvas.ClipX * 0.55, Canvas.ClipY * 0.55);
            Canvas.DrawColor = DW.CustomCrossHairColor;
            Canvas.DrawText( DW.M_Firing.SelectedFireMode(1) );
        }
    }
}

protected simulated function PreDrawFPSubWeapon(int i)
{
    // Pawn.CalcDrawOffset() uses "Weapon.DisplayFOV" instead of
    // "Weapon(inv).DisplayFOV"... how uncool!
    // (was causing display problems with some weapons)
    if (DW.ModifiedWeapons[i] != none)
        DW.DisplayFOV = DW.ModifiedWeapons[i].DisplayFOV;
    else
        DW.DisplayFOV = DW.Weapons[i].DisplayFOV;
    
    DW.PreDrawFPSubWeapon(i);
}

protected simulated function UpdateSubWeaponPos(int h)
{
    DW.Weapons[h].SetLocation( Instigator.Location + Instigator.CalcDrawOffset(DW.Weapons[h]) );
    DW.Weapons[h].SetRotation( Instigator.GetViewRotation() );

    if (DW.ModifiedWeapons[h] != none)
    { // UT2004 RPG support
        DW.ModifiedWeapons[h].SetLocation(DW.Weapons[h].Location);
        DW.ModifiedWeapons[h].SetRotation(DW.Weapons[h].Rotation);
    }
}

/** MASTER EVENTS **/

simulated event Master_BringUp(optional Weapon PrevWeapon)
{
    WeaponNameTime[0] = WeaponNameFadeTime;
    WeaponNameTime[1] = WeaponNameFadeTime;
}

simulated event Master_ChangedSubWeapon(int hand)
{
    WeaponNameTime[hand] = WeaponNameFadeTime;
}

simulated event Master_ChangedSubWeapons()
{
    WeaponNameTime[0] = WeaponNameFadeTime;
    WeaponNameTime[1] = WeaponNameFadeTime;
}

simulated event Master_WeaponTick(float dt)
{
    if (WeaponNameTime[0] > 0)
        WeaponNameTime[0] -= dt;    
    if (WeaponNameTime[1] > 0)
        WeaponNameTime[1] -= dt;    
}

defaultproperties
{
}
