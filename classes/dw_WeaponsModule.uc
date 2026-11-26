/* DualWield.dw_WeaponsModule
 */
class dw_WeaponsModule extends dw_Module;

var bool bReloadProfile;

var globalconfig string ConfiguredProfileName;

// Comma-separated base class names that may never be dual-wielded, in any profile.
// Matched with IsA, so sub-classes are included. Example: KFWeapon,RFWeapon
var globalconfig string BlockedBaseClasses;

// Comma-separated package-qualified class names that may never be dual-wielded, in any profile.
// Matched exactly, so sub-classes are not blocked. Example: XWeapons.Minigun
var globalconfig string BlockedClassPaths;
var dw_WeaponsProfile CurrentProfile;


simulated function ReloadConfig()
{
    local dw_WeaponsProfileManager mgr;
    
    if (ConfiguredProfileName ~= default.ConfiguredProfileName || default.bReloadProfile)
        return;

    ConfiguredProfileName = default.ConfiguredProfileName;

    if (Role == ROLE_Authority)
    {
        foreach DynamicActors(class'dw_WeaponsProfileManager', mgr)
        { // re-initialize profile managers
            // (mgr should re-load profile and restart replicating it to clients)
            if (!(mgr.CurrentProfileName ~= ConfiguredProfileName))
            {
                mgr.Initialize(ConfiguredProfileName);
                
                if (mgr.Profile != none)
                { // sync profile with manager
                    CurrentProfile = mgr.Profile;
                }
            }
        }
    }
        
    default.bReloadProfile = false;
}


simulated function PostNetBeginPlay()
{
    local dw_WeaponsProfileManager mgr;
    local PlayerController PC;
    
    super.PostNetBeginPlay();
    
    default.bReloadProfile = false;
    
    if (ConfiguredProfileName == "")
        ConfiguredProfileName = "Default";
    
    if (Level.NetMode == NM_Client)
    { // this actor should only exist on the server and OWNING client
        // (so the local player should always be the owner of this module)
        PC = Level.GetLocalPlayerController();
        // Can't use:
        // - Instigator, as it isn't replicated.
        // - DW.Owner, as DW.GiveTo() may not have been called yet.
    }
    else
    {
        if (Instigator == none && DW != none)
            Instigator = Pawn(DW.Owner);

        if (Instigator != none)
        { // Instigator should be set natively even before
            // the Dual Weapon is actually given to the player
            PC = PlayerController(Instigator.Controller);
        }
    }
    
    // if no player owner... (owner may be a bot)
    if (DW == none || PC == none)
    {
        if (CurrentProfile == none)
        { // use whatever profile is available
            foreach DynamicActors(class'dw_WeaponsProfileManager', mgr)
            {
                if (mgr.Profile != none)
                {
                    CurrentProfile = mgr.Profile;
                    return;
                }
            }
            // or load the configured profile
            CurrentProfile = class'dw_WeaponsProfile'.static.GetProfile(ConfiguredProfileName);
        }
        return;
    }
    
    foreach PC.ChildActors(class'dw_WeaponsProfileManager', mgr)
        break;

    if (Role == ROLE_Authority)
    {
        if (mgr == none)
        { // associate a profile manager with this player
            mgr = Spawn(class'dw_WeaponsProfileManager', PC);
            if (mgr != none)
            { // begin replicating (if applicable)
                mgr.Initialize(ConfiguredProfileName);
            }
            else
                Warn("Profile manager failed to Spawn");//DEBUG
        }
        if (mgr != none)
        {   // create only one profile instance if possible
            if (mgr.Profile != none)
                CurrentProfile = mgr.Profile;
        }

        if (CurrentProfile == none)
            CurrentProfile = class'dw_WeaponsProfile'.static.GetProfile(ConfiguredProfileName);
    }
    else
    {
        if (mgr == none)
            foreach DynamicActors(class'dw_WeaponsProfileManager', mgr)
                break;

        if (mgr != none && mgr.Profile != none)
            CurrentProfile = mgr.Profile;
    }
}


simulated function Weapon GetSelectedWeapon(int hand)
{
    return DW.Weapons[hand];
}

// Implement in sub-classes:

simulated function Weapon GetWeapon(class<Weapon> weaponType, int hand) { return none; }
simulated function Weapon GetNextUsableWeapon(Weapon current, int hand) { return none; }
simulated function Weapon GetPrevUsableWeapon(Weapon current, int hand) { return none; }
simulated function Weapon GetBestUsableWeapon(int hand)                 { return none; }
simulated function Weapon GetSlotWeapon(byte F, int hand, optional Weapon current) { return none; }

simulated function SelectWeapon(Weapon newWeapon, int hand);
simulated function ThrowWeapon(int hand);

simulated function bool IsUsableWeapon(Weapon w, int hand) { return false; }

simulated function bool AllowThrowWeapon(int hand);

// Akimbo weapons- implementation is optional
function bool CheckAkimboPickup(Pickup item) { return false; }
function bool GiveDuplicate(class<Weapon> WeaponType, optional WeaponPickup item) { return false; }

/** WEAPON-SWITCHING **/

// weapon-switching functions
simulated function NextLeftWeapon()  { NextSubWeapon(0); }
simulated function PrevLeftWeapon()  { PrevSubWeapon(0); }
simulated function NextRightWeapon() { NextSubWeapon(1); }
simulated function PrevRightWeapon() { PrevSubWeapon(1); }

protected simulated function NextSubWeapon(int hand)
{
    local Weapon w;

    // get current (or pending) weapon
    w = GetSelectedWeapon(hand);
    // find next usable weapon after that
    w = GetNextUsableWeapon(w, hand);
    // put it in the desired hand
    if (w != none)
        SelectWeapon(w, hand);
}

protected simulated function PrevSubWeapon(int hand)
{
    local Weapon w;
    
    if (DW.M_Weapons != none)
    {
        // get current (or pending) weapon
        w = GetSelectedWeapon(hand);
        // find previous usable weapon after that
        w = GetPrevUsableWeapon(w, hand);
        // put it in the desired hand
        if (w != none)
            SelectWeapon(w, hand);
    }
}

simulated function SwitchLeftToBest()   { SwitchToBest(0); }
simulated function SwitchRightToBest()  { SwitchToBest(1); }
simulated function SwitchBothToBest()   { SwitchToBest(0); SwitchToBest(1); }

protected simulated function SwitchToBest(int hand)
{
    local Weapon w;

    // find best rated dual-wieldable weapon for hand
    w = GetBestUsableWeapon(hand);
    // select it
    if (w != none)
        SelectWeapon(w, hand);
}

simulated function SwitchLeftWeapon(byte F)  { SwitchWeapon(F, 0); }
simulated function SwitchRightWeapon(byte F) { SwitchWeapon(F, 1); }

protected simulated function SwitchWeapon(byte F, int hand)
{
    local Weapon w;
    
    // get the next weapon in slot F
    w = GetSlotWeapon(F, hand);
    // select it
    if (w != none)
        SelectWeapon(w, hand);
}

defaultproperties
{
	ConfiguredProfileName="Default"
}
