/* DualWield.dw_FiringModule
 */
class dw_FiringModule extends dw_Module config(DualWieldClient);

replication
{
    // server-controlled variables
    reliable if (bNetDirty && Role == ROLE_Authority)
        bAllowZoom;

    // functions client->server
    reliable if (Role < ROLE_Authority)
        SubServerStartFire;
}

var config bool bDisallowZoom;
var config bool bMergeAkimbo; // in Akimbo-mode, fire buttons correspond to fire modes, instead of sub-weapons
var config bool bSpacedFiring; // if (bMergedModes), use alternating fire instead of simultaneous fire


// seperate replicated variable (so server doesn't overwrite client's config)
var bool bAllowZoom;

var byte bFireLeft, bFireRight; // input buttons- set to fire unselected modes
var int FiringWeapon; // weapon currently firing (ModeDoFire()), or -1


simulated function ReloadConfig()
{
    // client-side control-related settings
    bMergeAkimbo  = default.bMergeAkimbo;
    bSpacedFiring = default.bSpacedFiring;

    // NOTE: this config var has no immediate effect (bAllowZoom is used)
    bDisallowZoom = default.bDisallowZoom;

    // replicate setting to clients    
    if (Role == ROLE_Authority)
        bAllowZoom = !bDisallowZoom;
}


function PostBeginPlay()
{
    bAllowZoom = !bDisallowZoom;
}


// Called to determine whether we currently cannot change weapons.
// (e.g. we are firing and firing prevents weapon-switch.)
simulated function bool AllowWeaponChange(Weapon to, int hand)
{
    return true;
}

simulated function     SelectFireMode(int hand, int mode);      // Select a fire-mode as primary.
simulated function int SelectedFireMode(int hand) { return 0; } // Currently selected fire-mode.
simulated function     ToggleFireMode(int hand);                // Select opposite fire-mode.

simulated function bool DisplayFireModes() { return false; }    // overrides DisplayFireMode(hand)
simulated function bool DisplayFireMode(int hand) { return true; }

function bool BotFire(bool bFinished, optional name FiringMode);

simulated function bool DefaultReadyToFire(int mode)
{
    // default (dw_DualWeapon) fire-modes aren't used
    return false;
}

/** DEFAULT IMPLEMENTATION **/

// Default implementation uses fire for left weapon and altfire for right.
// Primary fire only.
simulated event Master_WeaponTick(float dt)
{
    local int i;
    local byte bFire[2];
    
    if (Instigator == none || Instigator.Controller == none)
        return;
    
    bFire[0] = Instigator.Controller.bFire;
    bFire[1] = Instigator.Controller.bAltFire;
    
    for (i = 0; i < 2; ++i)
        if (DW.Weapons[i] != none)
            SubWeaponTick(i, dt, bFire[i], 0);
}


/** UTILITY FUNCTIONS **/

static function bool IsZoomFireMode(WeaponFire wf)
{
    // UT2004 weapons with sniper zoom modes
    if (wf.IsA('SniperZoom') || wf.IsA('PainterZoom'))
        return true;
    // Ballistic Weapons with sniper zoom modes (third-party)
    if (wf.IsA('BallisticScopeFire'))
        return true;

    return false;
}

// Simulate the native weapon tick in UnrealScript.
// (Native weapon tick normally applies only to Pawn's real weapon.)
//
// bPriFire and bAltFire contain the desired status of firing. (i.e. fire buttons)
simulated function SubWeaponTick( int hand, float dt, byte bPriFire, byte bAltFire )
{
    local int i;
    local byte bFire[2];
    local Weapon w, instigatorWeapon;
    local WeaponFire wf;
    
    w = DW.Weapons[hand];

    if (w == none || w.Instigator == none || w.Instigator.Controller == none)
        return;

    // WeaponTick should be called manually if desired.
    //w.WeaponTick(dt);

    for (i = 0; i < 2; i++)
    {
        wf = w.GetFireMode(i);
        if (wf != none)
        {
            SubModeTick(wf, dt, hand);

            if (w == none || w.Instigator == none || w.Instigator.Controller == none)
                return;
            

            if (w.Role == ROLE_Authority)
            {
                // hack for AR alt fire (sounds & anims) and other Instigator.Weapon checks
                instigatorWeapon = w.Instigator.Weapon;
                w.Instigator.Weapon = w;

                if (wf.bServerDelayStartFire)
                {
                    if (wf.NextFireTime <= Level.TimeSeconds + wf.PreFireTime)
                        SubServerStartFire(hand, i);
                        //w.ServerStartFire(i);
                }
                else if (wf.bServerDelayStopFire)
                {
                    wf.bServerDelayStopFire = false;
                    w.StopFire(i);
                }

                if (w.Instigator != none)
                    w.Instigator.Weapon = instigatorWeapon;
            }
        }
    }

    if (w.Instigator.IsLocallyControlled() && !w.bEndOfRound)
    {
        if (w.ClientState == WS_None || w.ClientState == WS_Hidden)
        {
            w.ClientState = WS_ReadyToFire;
        }

        if (w.ClientState == WS_ReadyToFire)
        {
            if (w.default.ExchangeFireModes == 0) {
                bFire[0] = bPriFire;
                bFire[1] = bAltFire;
            } else {
                bFire[1] = bPriFire;
                bFire[0] = bAltFire;
            }

            // hack for AR alt fire (sounds & anims) and other Instigator.Weapon checks
            instigatorWeapon = w.Instigator.Weapon;
            w.Instigator.Weapon = w;

            for (i = 0; i < 2; i++)
            {
                wf = w.GetFireMode(i);
                if (wf != none)
                {
                    if (wf.bIsFiring && bFire[i] == 0)
                    {
                        w.ClientStopFire(i);
                    }
                    else if (!wf.bIsFiring && bFire[i] != 0)
                    {
                        SubClientStartFire(hand, i);
                        //w.ClientStartFire(i);
                    }
                }
            }
            
            if (w.Instigator != none)
                w.Instigator.Weapon = instigatorWeapon;
        }
    }
}

// Modifiers are owned by the pawn: find the one whose weapon is W
simulated function RPGBase FindCopyModifier(Pawn P, Weapon W)
{
    local RPGBase WM, Found;

    foreach P.ChildActors(class'RPGBase', WM)
        if (Found == none && WM.GetWeapon() == W)
            Found = WM;
    return Found;
}

simulated function CollectProjectiles(WeaponFire wf, out array<Projectile> List)
{
    local Projectile P;

    List.Length = 0;
    foreach wf.Instigator.DynamicActors(class'Projectile', P)
        if (P.Instigator == wf.Instigator)
        {
            List.Length = List.Length + 1;
            List[List.Length - 1] = P;
        }
}

// Credit every projectile that appeared since Before was taken to the copy's modifier
simulated function TagNewProjectiles(WeaponFire wf, RPGBase WM, array<Projectile> Before)
{
    local array<Projectile> After;
    local int i, j;
    local bool bWasThere;

    CollectProjectiles(wf, After);
    for (i = 0; i < After.Length; i++)
    {
        bWasThere = false;
        for (j = 0; j < Before.Length; j++)
            if (Before[j] == After[i])
            {
                bWasThere = true;
                break;
            }

        if (!bWasThere)
            WM.TagProjectile(After[i]);
    }
}

simulated function SubModeTick( WeaponFire wf, float dt, int hand )
{
    local array<Projectile> Before;
    local RPGBase WM;

    if (wf.Weapon == none || wf.Instigator == none)
        return;

    if (wf.TimerInterval != 0)
    {
        if (wf.NextTimerPop < Level.TimeSeconds)
        {
            wf.Timer();
            if (wf.bTimerLoop)
                wf.NextTimerPop += wf.TimerInterval;
            else
                wf.TimerInterval = 0;
        }
    }

    // continuous fire (e.g. link beam) deals its damage in ModeTick
    class'RPGBase'.default.FiringSubWeapon = wf.Weapon;
    wf.ModeTick(dt);
    class'RPGBase'.default.FiringSubWeapon = none;

    if ( (wf.bIsFiring && !wf.bFireOnRelease)
        || ((wf.bInstantStop || !wf.bIsFiring) && wf.bFireOnRelease)
        || (wf.HoldTime > wf.MaxHoldTime && wf.MaxHoldTime > 0) )
    {
        if (Level.TimeSeconds > wf.NextFireTime && (wf.bInstantStop || !wf.bNowWaiting))
        {
            FiringWeapon = hand;
            class'RPGBase'.default.FiringSubWeapon = wf.Weapon;
            WM = FindCopyModifier(wf.Instigator, wf.Weapon);
            if (WM != none)
                CollectProjectiles(wf, Before);
            wf.ModeDoFire();
            if (WM != none)
                TagNewProjectiles(wf, WM, Before);
            class'RPGBase'.default.FiringSubWeapon = none;
            FiringWeapon = -1;

            if (wf.bWaitForRelease)
                wf.bNowWaiting = true;
            
            if (DW != none && DW.bAutoSwitchAmmo)
                DW.SelectedAmmo = hand;
        }
    }
    else if (wf.bWaitForRelease && Level.TimeSeconds >= wf.NextFireTime)
    {
        wf.bNowWaiting = false;

        if (wf.HoldTime == 0)
        {
            FiringWeapon = hand;
            class'RPGBase'.default.FiringSubWeapon = wf.Weapon;
            wf.ModeHoldFire();
            class'RPGBase'.default.FiringSubWeapon = none;
            FiringWeapon = -1;
            
            if (DW != none && DW.bAutoSwitchAmmo)
                DW.SelectedAmmo = hand;
        }

        wf.HoldTime += dt;
    }
    wf.bInstantStop = false;
}

simulated function SubClientStartFire(int hand, int Mode)
{
    local Weapon w;
    w = DW.Weapons[hand];

    if ( w == none
        || w.Instigator.Controller.IsInState('GameEnded') || w.Instigator.Controller.IsInState('RoundEnded') )
        return;

    if (Role < ROLE_Authority)
    {
        if (w.StartFire(Mode))
        {
            //ServerStartFire(Mode);
            SubServerStartFire(hand, Mode);
        }
    }
    else
    {
        w.StartFire(Mode);
    }

    // for sniper zoom and RL tight-wad.
    // ReadyToFire should prevent it from actually firing again.
    w.ClientStartFire(Mode);
}

// hack to get around an "Instigator != self" line
function SubServerStartFire(byte hand, byte mode)
{
    local WeaponFire wf;

    if (DW.Weapons[hand] == none)
        return;

    wf = DW.Weapons[hand].GetFireMode(mode);

    if ( (wf.NextFireTime <= Level.TimeSeconds + wf.PreFireTime)
        && DW.Weapons[hand].StartFire(Mode) )
    {
        wf.ServerStartFireTime = Level.TimeSeconds;
        wf.bServerDelayStartFire = false;
    }
    else if ( wf.AllowFire() )
    {
        wf.bServerDelayStartFire = true;
    }
    else
        DW.Weapons[hand].ClientForceAmmoUpdate(Mode, DW.Weapons[hand].AmmoAmount(Mode));
}

defaultproperties
{
	bAllowZoom=True
}
