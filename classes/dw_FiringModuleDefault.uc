/* DualWield.dw_FiringModuleDefault
 */
class dw_FiringModuleDefault extends dw_FiringModule;

var bool  bMergedModes; // modes are currently merged
var float FireDelay[2], StartFireTime[2];
var int   StartFireWeapon[2];

var protected int SelectedFireModes[2]; // fire-mode to use in dual mode

var byte bFire[4]; // fire 'buttons' for all four modes (left pri, left alt, right pri, right alt)

// akimbo: if fire-mode fires bProjTarget projectiles (e.g. ShockProjectile)
//  override bSpacedFiring to prevent them from colliding (and killing instigator)
var byte bSpacedOverride[2];

replication
{
    // functions server->client
    reliable if (Role == ROLE_Authority)
        ClientSetFireModes;

    // functions client->server
    reliable if (Role < ROLE_Authority)
        ServerSelectFireMode;
}


/** IMPLEMENTATION **/

simulated event Master_WeaponTick(float dt)
{
    local int i, j, m;
    local byte bTrigger;

    if (Instigator == none || Instigator.Controller == none)
    {
        // Reset fire buttons- (extra fire) button release may not be detected
        // while player is controller another Pawn (i.e. vehicle or redeemer warhead).
        bFire[0] = 0; bFire[1] = 0;
        bFire[2] = 0; bFire[3] = 0;
        return;
    }
    
    if (PlayerController(Instigator.Controller) != none)
    {
        if (DW.Weapons[0] == none || DW.Weapons[1] == none)
        {
            bFire[0] = Instigator.Controller.bFire;
            bFire[1] = Instigator.Controller.bAltFire;
            bFire[2] = bFire[0];
            bFire[3] = bFire[1];
        }
        else if (bMergedModes)
        {
            if ((bSpacedFiring || bSpacedOverride[0]!=0 || bSpacedOverride[1]!=0)
                && (DW.Weapons[0] != none && DW.Weapons[1] != none))
            {
                for (m = 0; m < 2; ++m)
                {
                    if (m == 0)
                        bTrigger = Instigator.Controller.bFire;
                    else
                        bTrigger = Instigator.Controller.bAltFire;

                    if (!bSpacedFiring && bSpacedOverride[m]==0)
                    { // only the other mode should be spaced; trigger both weapons
                        bFire[  m] = bTrigger;
                        bFire[2+m] = bTrigger;
                        continue;
                    }
                    
                    if (IsZoomFireMode(DW.Weapons[0].GetFireMode(m)))
                    { // trigger only one zoom mode (otherwise we'll zoom back out)
                        bFire[  m] = bTrigger;
                        bFire[2+m] = 0;
                        continue;
                    }
                    
                    i = StartFireWeapon[m]*2+m;
                    j = i^2; // other weapon
                    
                    if ((bFire[i]==0) != (bTrigger==0))
                    {
                        if (bTrigger==0)
                        { // released fire
                            StartFireWeapon[m] = StartFireWeapon[m]^1;
                            FireDelay[m] = 0;
                        }
                        else
                        { // pressed fire
                            StartFireTime[m] = Level.TimeSeconds;
                            FireDelay[m] = DW.Weapons[StartFireWeapon[m]].GetFireMode(m).FireRate * 0.5;

                            if (StartFireWeapon[m^1] == StartFireWeapon[m]
                              && DW.Weapons[StartFireWeapon[m]].GetFireMode(m).bModeExclusive)
                            { // mutually-exclusive modes, fire the other weapon first
                                // (otherwise we have to wait for this one)
                                StartFireWeapon[m^1] = StartFireWeapon[m]^1;
                            }
                        }    
                    }

                    bFire[i] = bTrigger;

                    if (bFire[i]!=0)
                    {
                        if (bFire[j]==0 && StartFireTime[m] + FireDelay[m] < Level.TimeSeconds)
                            bFire[j] = bFire[i];
                    }
                    else
                        bFire[j] = 0;
                }
            }
            else
            {
                bFire[0] = Instigator.Controller.bFire;
                bFire[1] = Instigator.Controller.bAltFire;
                bFire[2] = bFire[0];
                bFire[3] = bFire[1];
            }
        }
        else
        {
            if (DW.ExchangeFireModes != 0)
                i = 2; // primary fire = right-hand weapon
            else
                j = 2; // alternate fire = right-hand weapon

            bFire[i+SelectedFireModes[0]  ] = Instigator.Controller.bFire;
            bFire[j+SelectedFireModes[1]  ] = Instigator.Controller.bAltFire;
            bFire[  SelectedFireModes[0]^1] = bFireLeft;
            bFire[2+SelectedFireModes[1]^1] = bFireRight;
        }
    }
    else if (Instigator.Controller.bFire == 0 && Instigator.Controller.bAltFire == 0)
    {
        if (Bot(Instigator.Controller) == none || ! Bot(Instigator.Controller).bCanFire)
        {
            bFire[0] = 0; bFire[1] = 0;
            bFire[2] = 0; bFire[3] = 0;
        }
    }
    
    if (DW.Weapons[0] != none)
        SubWeaponTick(0, dt, bFire[0], bFire[1]);
    
    if (DW.Weapons[1] != none)
        SubWeaponTick(1, dt, bFire[2], bFire[3]);
}

simulated function bool DisplayFireModes()
{
    // don't display modes if in merged-akimbo mode (irrelevance)
    return ! bMergedModes;
}

simulated function bool DisplayFireMode(int hand)
{
    // don't display mode for nothing!
    if (DW.Weapons[hand] == none)
        return false;

    // don't display mode if mode can't be switched
    return AllowFireMode(DW.Weapons[hand].GetFireMode(SelectedFireModes[hand]^1));
}

// Select a fire-mode for use. (i.e. Fire=left weapon's selected mode)
simulated function SelectFireMode(int hand, int mode)
{
    ServerSelectFireMode(hand, mode);
}

protected function ServerSelectFireMode(int hand, int mode)
{
    local Weapon w;
    
    w = DW.Weapons[hand];
    if (w == none)
        return;

    if (!AllowFireMode(w.GetFireMode(mode)))
    { // mode not usable, ensure other mode is selected if valid
        mode = mode^1;
        if (AllowFireMode(w.GetFireMode(mode)))
        {
            if (SelectedFireModes[hand] != mode)
            {
                SelectedFireModes[hand] = mode;
                // send updated modes to client
                ClientSetFireModes(SelectedFireModes[0], SelectedFireModes[1]);
            }
        }
        return;
    }
    
    SelectedFireModes[hand] = mode;
    
    // send updated modes to client
    ClientSetFireModes(SelectedFireModes[0], SelectedFireModes[1]);
}

protected simulated function ClientSetFireModes(int mode0, int mode1)
{
    if (Role < ROLE_Authority)
    {
        SelectedFireModes[0] = mode0;
        SelectedFireModes[1] = mode1;
    }
}

// Currently selected fire-mode.
simulated function int SelectedFireMode(int hand)
{
    return SelectedFireModes[hand];
}

// Select opposite fire-mode.
simulated function ToggleFireMode(int hand)
{
    SelectFireMode(hand, SelectedFireModes[hand]^1);
}

protected simulated function bool AllowFireMode(WeaponFire wf)
{
    if (wf == none)
        return false;

    if (!bAllowZoom && IsZoomFireMode(wf))
        return false;

    return true;
}

/** BOT SUPPORT **/

function bool BotFire(bool bFinished, optional name FiringMode)
{
    local Controller C;
    local int hand, pri, alt;
    local bool bFiring;
    
    // if no weapons, can't fire
    if (DW.Weapons[0] == none && DW.Weapons[1] == none)
        return false;

    C = Instigator.Controller;
    
    if (C == none)
        return false;

    pri = 0;
    alt = 1;

    for (hand = 0; hand < 2; ++hand)
    {
        // NOTE: FiringWeapon corresponds to the weapon currently executing
        //       FireMode.ModeDoFire(), if any.  If FiringWeapon is set > -1,
        //       we know which weapon currently wants to re-fire.
        if (FiringWeapon == -1 || FiringWeapon == hand)
        {
            //if (Bot(C) == none || Bot(C).bStoppedFiring)
            //{
                bFire[pri] = 0;
                //if (LinkGun(DW.Weapons[hand]) == none || !LinkGun(DW.Weapons[hand]).Linking)
                    bFire[alt] = 0;
            //}
        
            if (DW.Weapons[hand] != none)
            {
                C.bFire    = bFire[pri];
                C.bAltFire = bFire[alt];
                
                DW.Weapons[hand].BotFire(bFinished, FiringMode);
                
                bFire[pri] = C.bFire;
                bFire[alt] = C.bAltFire;
                
                if (C.bFire != 0 || C.bAltFire != 0)
                    bFiring = true;
            }
        }
        pri = 2;
        alt = 3;
    }
    C.bFire    = 0;
    C.bAltFire = 0;
    
    return bFiring;
}

/** MASTER EVENTS **/

simulated event Master_ChangedSubWeapon(int hand)
{
     Master_ChangedSubWeapons();
}
simulated event Master_ChangedSubWeapons()
{
    local int m;
    local class<Projectile> ProjClass;

    if (Instigator != none && Instigator.IsHumanControlled()
        && Instigator.Controller.Role == ROLE_Authority)
    {   // if dual-wielding and zoom isn't allowed,
        // stop zooming/zoom out (the player can't do this manually)
        if (!bAllowZoom && DW.Weapons[0] != none && DW.Weapons[1] != none)
            PlayerController(Instigator.Controller).EndZoom();
    }
    
    bMergedModes = bMergeAkimbo && IsInAkimboMode();
    
    if (bMergedModes && !bSpacedFiring && DW.Weapons[0] != none)
    { // For safety, some modes should always be spaced.
        // For example, if not spaced, Shock Rifle alt-fire causes an instant
        // explosion, hurting the player.
        for (m = 0; m < 2; ++m)
        {
            ProjClass = DW.Weapons[0].GetFireMode(m).default.ProjectileClass;
            // if bProjTarget, projectiles may collide
            if (ProjClass != none
               && ProjClass.default.bProjTarget         // can collide with other projectiles
               && ProjClass.default.CollisionRadius > 1 // (more) likely to collide
               && ProjClass.default.Physics == PHYS_Projectile // straight lines, likely to meet at some point
               )
                bSpacedOverride[m] = 1;
            else
                bSpacedOverride[m] = 0;
        }
    }
}

/** UTILS **/

protected simulated function bool IsInAkimboMode()
{
    if (DW.Weapons[0] == none || DW.Weapons[1] == none)
        return false;

    if (DW.IsA('dw_DualWeapon_RPG'))
    { // UT2004RPG's magical weapons obscure the real weapons
        // (they copy the FireModes, but not the FireModeClasses)
        return GetFireModeClass(DW.Weapons[0], 0) == GetFireModeClass(DW.Weapons[1], 0)
            && GetFireModeClass(DW.Weapons[0], 1) == GetFireModeClass(DW.Weapons[1], 1);
    }
    return DW.Weapons[0].FireModeClass[0] == DW.Weapons[1].FireModeClass[0]
        && DW.Weapons[0].FireModeClass[1] == DW.Weapons[1].FireModeClass[1];
}

protected simulated function class<WeaponFire> GetFireModeClass(Weapon w, int m)
{
    local WeaponFire wf;
    wf = w.GetFireMode(m);
    if (wf != none)
        return wf.Class;
    return w.FireModeClass[m];
}

defaultproperties
{
}
