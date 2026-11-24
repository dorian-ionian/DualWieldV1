//-----------------------------------------------------------
// Dual-wielding weapon shell.
//
// Goals:
//  - allow dual wielding of ANY two weapons
//  - be compatible with most, if not all, official and custom weapons
//
// Author: Steve Gray (a.k.a. porkmanii)
//-----------------------------------------------------------
class dw_DualWeapon extends Weapon
    CacheExempt HideDropdown
    config(DualWieldV1);


var() class<dw_RenderingModule> RenderingModuleClass;
var() class<dw_FiringModule>    FiringModuleClass;
var() class<dw_WeaponsModule>   WeaponsModuleClass;
var() class<dw_ControlModule>   ControlModuleClass;

var dw_Module          ModuleList;  // one of the below, for chained events.
var dw_RenderingModule M_Rendering; // handles rendering of weapons/hud
var dw_FiringModule    M_Firing;    // handles firing mechanisms
var dw_WeaponsModule   M_Weapons;   // handles weapon selection/switching & restrictions
var dw_ControlModule   M_Control;   // handles control mechanisms/input


var Weapon Weapons[2]; // weapons in left and right hands
var Weapon ModifiedWeapons[2]; // for UT2004 RPG compatibility

// Read by TitanRPG's mastery label via GetPropertyText, so TitanRPG needs no compile-time link to this package
var string LeftWeaponAlias, RightWeaponAlias;   // string(class) of each held gun, the key TitanRPG uses for kill counts
var string LeftWeaponItemName, RightWeaponItemName; // class default ItemName of each held gun

var() bool bSingleButtonMode;
var() class<dw_ControlModule>   SingleButtonControlModuleClass;

var(HUD) bool bAutoSwitchAmmo; // auto-switch ammo display to last used weapon
var int SelectedAmmo; // weapon index of ammo to display

// for determining which weapon to GetEffectStart for (in GetEffectStart())
var int LastFireMode;

var actor OffhandActor; // attachment for left hand
var dw_OffhandAimActor OffhandAiming;

var() bool bEncourageBotDualing;

// for fixing Link beam positioning issues
// (only used if previous class is XWeapons.LinkBeamEffect, not sub-classes)
var const class<LinkBeamEffect> LinkBeamEffectClass[2];

var int PlayerHandedness;

replication
{
    // NOTE: I've suppressed my urge to check 'bNetDirty'
    //       as Inventory has bOnlyDirtyReplication=True.

    // replicate firing and weapons modules (always server-controlled)
    reliable if (bNetInitial && Role == ROLE_Authority)
        M_Firing, M_Weapons;
    
    // replicate rendering & control modules if not client-side
    reliable if (bNetInitial && Role == ROLE_Authority
                && M_Rendering != none && M_Rendering.RemoteRole != ROLE_None)
        M_Rendering;
    reliable if (bNetInitial && Role == ROLE_Authority
                 && M_Control != none && M_Control.RemoteRole != ROLE_None)
        M_Control;
    
    // functions client->server
    reliable if (Role < ROLE_Authority)
        ServerChangedSubWeapon, ServerChangedSubWeapons, ThrowSubWeapon,
        SetFireMode, ServerSetHandedness, ServerSetFiringOptions,
        /** console commands **/
        SwitchFireMode, CommandSubWeapon, CommandSubWeapons,
        ReloadMeNow, ChangeAmmo, ChaosWeaponOption;

    // functions server->client
    reliable if (Role == ROLE_Authority)
        ClientRemoveWeapons, ClientRemoveWeapon;
}

/** INIT **/

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    bAutoSwitchAmmo = class'dw_RenderingModule'.default.bAutoSwitchAmmo;
    bSingleButtonMode = class'dw_ControlModule'.default.bSingleButtonMode;

    // initialize modules
    InitModules();
}

simulated function PostNetBeginPlay()
{
    super.PostNetBeginPlay();
    
    // server value should be overwritten by client at some point
    if (Level.NetMode != NM_DedicatedServer)
    {
        PlayerHandedness = Level.GetLocalPlayerController().Handedness;
        ServerSetHandedness(PlayerHandedness);
        SendFiringOptions();
    }
}

function ServerSetHandedness(int hand)
{
    PlayerHandedness = hand;
}

// firing is decided on the server, so the client's firing options must be sent there
simulated function SendFiringOptions()
{
    if (Role < ROLE_Authority)
        ServerSetFiringOptions(class'dw_FiringModule'.default.bDisallowZoom,
            class'dw_FiringModule'.default.bMergeAkimbo,
            class'dw_FiringModule'.default.bSpacedFiring);
}

function ServerSetFiringOptions(bool bNoZoom, bool bMerge, bool bSpaced)
{
    if (M_Firing == none)
        return;

    M_Firing.bDisallowZoom = bNoZoom;
    M_Firing.bAllowZoom    = !bNoZoom;
    M_Firing.bMergeAkimbo  = bMerge;
    M_Firing.bSpacedFiring = bSpaced;
    // bMergedModes is only recalculated when sub-weapons change
    M_Firing.Master_ChangedSubWeapons();
}

simulated function InitModules()
{
    // Firing and Weapon sub-systems should always be server-controlled
    // (and replicated to client)

    if (Role == ROLE_Authority)
    {
        // init firing sub-system
        if (FiringModuleClass != none)
            M_Firing = Spawn(FiringModuleClass, self);
    
        // init weapon selection sub-system
        if (WeaponsModuleClass != none)
            M_Weapons = Spawn(WeaponsModuleClass, self);
    }
    
    if (bSingleButtonMode && SingleButtonControlModuleClass != none)
        ControlModuleClass = SingleButtonControlModuleClass;

    // Rendering and Control sub-systems may be server-controlled or client-side.
    InitRendering();
    InitControls();
}

simulated function InitRendering()
{
    // init rendering sub-system    
    if (RenderingModuleClass != none
        && (Role == ROLE_Authority || RenderingModuleClass.default.RemoteRole == ROLE_None))
        M_Rendering = Spawn(RenderingModuleClass, self);
}

simulated function InitControls()
{
    // init controls/input sub-system
    if (ControlModuleClass != none
        && (Role == ROLE_Authority || ControlModuleClass.default.RemoteRole == ROLE_None))
        M_Control = Spawn(ControlModuleClass, self);
}

/** CONFIG **/

simulated function ReloadConfig()
{
    local dw_Module mod;
    
    SetSingleButtonMode(class'dw_ControlModule'.default.bSingleButtonMode);
    
    for (mod = ModuleList; mod != none; mod = mod.NextModule)
        mod.ReloadConfig();

    if (M_Firing != none)
        M_Firing.Master_ChangedSubWeapons();
    SendFiringOptions();
}

simulated exec function SetSingleButtonMode(bool singleMode, optional bool nosave)
{
    // if no change, don't bother
    if (bSingleButtonMode == singleMode)
        return;
    
    // ensure single button mode is possible
    if (SingleButtonControlModuleClass == none)
        return;

    // if control module is server-side and we are client, take no action
    if (M_Control != none && M_Control.Role != ROLE_Authority)
        return;
    
    // determine desired control module class
    if (singleMode)
        ControlModuleClass = SingleButtonControlModuleClass;
    else
        ControlModuleClass = default.ControlModuleClass;
    
    bSingleButtonMode = singleMode;
    
    // double-check current control module class (if equal, no action required)
    if (M_Control != none && M_Control.Class == ControlModuleClass)
        return;
    
    // if this control module class is server-side and we are client, take no action
    if (ControlModuleClass != none && ControlModuleClass.default.RemoteRole != ROLE_None
       && Role != ROLE_Authority)
        return;
    
    // clean up old module
    if (M_Control != none)
        M_Control.Destroy();
    
    bNoVoluntarySwitch = false;
    
    // initialize new module
    InitControls();
    
    if (!nosave) {
        class'dw_ControlModule'.default.bSingleButtonMode = singleMode;
        class'dw_ControlModule'.static.StaticSaveConfig();
    }
}

/** EXEC/INPUT FUNCTIONS **/

simulated exec function NextSubWeapon(string HandString)
{
    ChangeHand(HandString);
}
simulated exec function ChangeHand(string HandString)
{
    if (M_Weapons != none)
    {
        if (HandString ~= "left")
            M_Weapons.NextLeftWeapon();
        else
        if (HandString ~= "right")
            M_Weapons.NextRightWeapon();
    }
}

simulated exec function PrevSubWeapon(string HandString)
{
    if (M_Weapons != none)
    {
        if (HandString ~= "left")
            M_Weapons.PrevLeftWeapon();
        else
        if (HandString ~= "right")
            M_Weapons.PrevRightWeapon();
    }
}

// switch to the best weapon for the specified Hand
simulated exec function SwitchToBest(optional string HandString)
{
    if (M_Weapons != none)
    {
        if (HandString == "" || HandString ~= "left")
            M_Weapons.SwitchLeftToBest();
    
        if (HandString == "" || HandString ~= "right")
            M_Weapons.SwitchRightToBest();
    }
}

exec function SwitchFireMode(optional string hand)
{
    local int i;
    if (hand ~= "left") i = 0;
    else if (hand ~= "right") i = 1;
    else i = -1;

    if (M_Firing != none)
    {
        if (i != 1)
            M_Firing.ToggleFireMode(0);
        if (i != 0)
            M_Firing.ToggleFireMode(1);
    }
}

function SetFireMode(int hand, int mode)
{
    if (M_Firing != none)
        M_Firing.SelectFireMode(hand, mode);
}

simulated exec function GetWeaponLeft(class<Weapon> NewWeaponClass )
{
    GetWeapon(NewWeaponClass, 0);
}

simulated exec function GetWeaponRight(class<Weapon> NewWeaponClass )
{
    GetWeapon(NewWeaponClass, 1);
}

simulated function GetWeapon(class<Weapon> NewWeaponClass, int Hand)
{
    local Weapon w;
    
    if (M_Weapons != none)
    {
        // find a weapon of this class dual-wieldable in this Hand
        w = M_Weapons.GetWeapon(NewWeaponClass, Hand);
        // select it
        if (w != none)
            M_Weapons.SelectWeapon(w, Hand);
    }
}

simulated exec function SwitchWeaponLeft(byte F)
{
    if (M_Weapons != none)
        M_Weapons.SwitchLeftWeapon(F);
}

simulated exec function SwitchWeaponRight(byte F)
{
    if (M_Weapons != none)
        M_Weapons.SwitchRightWeapon(F);
}

simulated exec function EmptyHand(string Hand)
{
    local int i;

    if (Hand ~= "right") i = 1;
    else if (Hand ~= "left") i = 0;
    else return;

    if (M_Weapons != none)
        M_Weapons.SelectWeapon(none, i);
}

simulated exec function SwitchAmmoDisplay()
{
    SelectedAmmo = SelectedAmmo^1;

    //Instigator.ClientMessage("Switched to "
    //    $ Eval(SelectedAmmo == 1, "Secondary", "Primary") $ " ammo display.");
}

exec function DieDieDieDie()
{
    local Inventory inv;
    
    if (M_Weapons == none || Level.NetMode != NM_Standalone)
        return;

    for (inv = Instigator.Inventory; inv != none; inv = inv.Inventory)
        if (inv.IsA('Weapon'))
            M_Weapons.GiveDuplicate(class<Weapon>(inv.Class));
}

/* Dual-wielding stuff */

simulated function BringUp(optional Weapon PrevWeapon)
{
    local int Mode;
    local dw_Module mod;

    ClearStaleHands();

    for (mod = ModuleList; mod != none; mod = mod.NextModule)
        mod.Master_BringUp(PrevWeapon);

    BringUpTime = 0;
    if (Weapons[0] != none)
    {
        //Weapons[0].ClientState = WS_Hidden;
        //if (ModifiedWeapons[0] != none) // for UT2004 RPG compatibility
        //    ModifiedWeapons[0].ClientState = WS_Hidden;
        if (!AllowQuickSwitch(PrevWeapon, 0))
            Weapons[0].BringUp(/*PrevWeapon*/);
        BringUpTime = FMax(BringUpTime, Weapons[0].TimerRate);
    }
    if (Weapons[1] != none)
    {
        //Weapons[1].ClientState = WS_Hidden;
        //if (ModifiedWeapons[1] != none)
        //    ModifiedWeapons[1].ClientState = WS_Hidden;
        if (!AllowQuickSwitch(PrevWeapon, 1))
            Weapons[1].BringUp(/*PrevWeapon*/);
        BringUpTime = FMax(BringUpTime, Weapons[1].TimerRate);
    }
    UpdateFireModes();

    if (ClientState == WS_Hidden && BringUpTime > 0)
    {
        ClientState = WS_BringUp;
        SetTimer(BringUpTime, false);
    }
    else
        ClientState = WS_ReadyToFire;

    for (Mode = 0; Mode < NUM_FIRE_MODES; Mode++)
    {
        FireMode[Mode].bIsFiring = false;
        FireMode[Mode].HoldTime = 0.0;
        FireMode[Mode].bServerDelayStartFire = false;
        FireMode[Mode].bServerDelayStopFire = false;
        FireMode[Mode].bInstantStop = false;

    }
    if ( (PrevWeapon != None) && PrevWeapon.HasAmmo() && !PrevWeapon.bNoVoluntarySwitch )
        OldWeapon = PrevWeapon;
    else
        OldWeapon = None;
}

simulated function bool PutDown()
{
    if (Weapons[0] != none)
    {
        // May allow quick switch (no anim, allow firing) if switching
        // to a weapon we are already holding in one hand.
        // Weapons[x].PutDown() should be called regardless of whether we
        // are already being put down, in case the user selected a
        // different weapon after selecting the weapon being held.
        if (!AllowQuickSwitch(Instigator.PendingWeapon, 0))
        {
            Weapons[0].PutDown();
            if (Weapons[0].TimerRate > 0)
                Weapons[0].SetTimer(1000000, false);
        }
    }
    if (Weapons[1] != none)
    {
        if (!AllowQuickSwitch(Instigator.PendingWeapon, 1))
        {
            Weapons[1].PutDown();
            if (Weapons[1].TimerRate > 0)
                Weapons[1].SetTimer(1000000, false);
        }
    }

    if (ClientState == WS_BringUp || ClientState == WS_ReadyToFire)
    {
        DownDelay = 0;

        if (Weapons[0] != none)
        {
            if (Weapons[0].DownDelay > 0)
                DownDelay = FMax(DownDelay, Weapons[0].DownDelay + Weapons[0].PutDownTime);
            else
                DownDelay = FMax(DownDelay, Weapons[0].PutDownTime);
        }
        if (Weapons[1] != none)
        {
            if (Weapons[1].DownDelay > 0)
                DownDelay = FMax(DownDelay, Weapons[1].DownDelay + Weapons[1].PutDownTime);
            else
                DownDelay = FMax(DownDelay, Weapons[1].PutDownTime);
        }

        ClientState = WS_PutDown;

        if ( DownDelay > 0 )
        {
            SetTimer(DownDelay, false);
            DownDelay = 0; // don't reset the timer to PutDownTime in Timer()
        }
        else
            SetTimer(PutDownTime, false);
    }

    Instigator.AmbientSound = None;
    OldWeapon = None;
    return true; // return false if preventing weapon switch
}

function ServerChangedSubWeapon(int hand, Weapon newWeapon)
{
    if (Weapons[hand] != none && Weapons[hand] != newWeapon)
        Weapons[hand].Hand = 0;
    Weapons[hand] = newWeapon;
    ChangedSubWeapon(hand);
}

function ServerChangedSubWeapons(Weapon left, Weapon right)
{
    if (Weapons[0] != none)
        Weapons[0].Hand = 0;
    if (Weapons[1] != none)
        Weapons[1].Hand = 0;
    Weapons[0] = left;
    Weapons[1] = right;
    ChangedSubWeapons();
}

// TitanRPG treats Hand != 0 as held. Guns the container no longer holds must not keep it,
// and several swap paths overwrite Weapons[] without clearing the old gun's Hand.
simulated function ClearStaleHands()
{
    local Inventory inv;
    local Weapon w;

    if (Instigator == none)
        return;

    for (inv = Instigator.Inventory; inv != none; inv = inv.Inventory)
    {
        w = Weapon(inv);
        if (w != none && w.Hand != 0 && w != Weapons[0] && w != Weapons[1])
            w.Hand = 0;
    }
}

simulated function ChangedSubWeapon(int hand)
{
    local dw_Module mod;

    ClearStaleHands();

    // show charging bar if at least one weapon wants it
    bShowChargingBar
        = (Weapons[0] != none && Weapons[0].bShowChargingBar)
       || (Weapons[1] != none && Weapons[1].bShowChargingBar);

    ModifiedWeapons[hand] = none;
    
    if (Weapons[hand] != none)
    {
        if (hand == 0)
            Weapons[hand].Hand = -1; // left
        else
            Weapons[hand].Hand = +1; // right

        UpdateInstigator(Weapons[hand]);    
    
        // for UT2004 RPG compatibility
        // (some things have to be done to the RPGWeapon's ModifiedWeapon)
        if (Weapons[hand].IsA('RPGWeapon'))
            ModifiedWeapons[hand] = FindModifiedWeapon(Weapons[hand]);
    }

    // HACK: call this for old hacks
    UpdateFireModes();
    
    UpdateSubWeaponOverlays();
    
    if (Role == ROLE_Authority)
    {
        if (Weapons[hand] != none)
            BroadcastOwnerEvent('ChangedWeapon', Weapons[hand]);
        
        // re-attach the third-person guns
        DetachFromPawn(Instigator);
        if (IsCurrentWeapon())
            AttachToPawn(Instigator);
    }

    for (mod = ModuleList; mod != none; mod = mod.NextModule)
        mod.Master_ChangedSubWeapon(hand);
}

simulated function ChangedSubWeapons()
{
    local int h;
    local dw_Module mod;

    ClearStaleHands();
    
    // show charging bar if at least one weapon wants it
    bShowChargingBar
        = (Weapons[0] != none && Weapons[0].bShowChargingBar)
       || (Weapons[1] != none && Weapons[1].bShowChargingBar);

    for (h = 0; h < 2; ++h)
    {
        ModifiedWeapons[h] = none;
        
        if (Weapons[h] != none)
        {
            if (h == 0)
                Weapons[h].Hand = -1; // left
            else
                Weapons[h].Hand = +1; // right
        
            UpdateInstigator(Weapons[h]);
        
            // for UT2004 RPG compatibility
            // (some things have to be done to the RPGWeapon's ModifiedWeapon)
            if (Weapons[h].IsA('RPGWeapon'))
                ModifiedWeapons[h] = FindModifiedWeapon(Weapons[h]);
        }
    }

    // HACK: call this for old hacks
    UpdateFireModes();
    
    UpdateSubWeaponOverlays();
    
    if (Role == ROLE_Authority)
    {
        // re-attach the third-person guns
        DetachFromPawn(Instigator);
        if (IsCurrentWeapon())
            AttachToPawn(Instigator);

        for (h = 0; h < 2; ++h)
            if (Weapons[h] != none)
                BroadcastOwnerEvent('ChangedWeapon', Weapons[h]);
    }

    for (mod = ModuleList; mod != none; mod = mod.NextModule)
        mod.Master_ChangedSubWeapons();
}

// broadcast an OwnerEvent with W as the "current weapon"
function BroadcastOwnerEvent(name EventName, Weapon W)
{
    local Weapon oldWeap;
    
    oldWeap = Instigator.Weapon;
    Instigator.Weapon = W;
    
    Instigator.Inventory.OwnerEvent(EventName);
    
    Instigator.Weapon = oldWeap;
}

// send an OwnerEvent to W with it as the "current weapon"
function SendOwnerEvent(name EventName, Weapon w)
{
    local Inventory oldInventory;
    local Weapon oldWeap;

    oldWeap = Instigator.Weapon;
    Instigator.Weapon = w; // make sure 'w' knows it's the current weapon

    oldInventory = w.Inventory;
    w.Inventory = none; // don't notify next Inventory item of OwnerEvent

    w.OwnerEvent(EventName);

    w.Inventory = oldInventory;
    Instigator.Weapon = oldWeap;
}

// OBSOLETE: here only for old hacks
simulated function UpdateFireModes()
{
    local int i;

    for (i = 0; i < 2; ++i)
    {
        if (Weapons[i] != none)
        {
            // if mode is a LinkFire
            if (LinkFire(Weapons[i].FireMode[1]) != none
            // and is using the default LinkBeamEffect
                && (LinkFire(Weapons[i].FireMode[1]).BeamEffectClass == class'LinkBeamEffect'
            // or one of our hacked LinkBeamEffects
                 || ClassIsChildOf(LinkFire(Weapons[i].FireMode[1]).BeamEffectClass, class'dw_LinkBeamEffect')))
            // set beam class to insert our beam position correction hack
                LinkFire(Weapons[i].FireMode[1]).BeamEffectClass = LinkBeamEffectClass[i];
    
            FireMode[i].Instigator = Instigator;
            if (Instigator != none)
                FireMode[i].InitEffects();
        }
    }
}

simulated function CheckSuperBerserk()
{
    if (Weapons[0] != none)
        Weapons[0].CheckSuperBerserk();
    if (Weapons[1] != none)
        Weapons[1].CheckSuperBerserk();
}

simulated function StartBerserk()
{
    if (Weapons[0] != none)
        Weapons[0].StartBerserk();
    if (Weapons[1] != none)
        Weapons[1].StartBerserk();
}

simulated function StopBerserk()
{
    if (Weapons[0] != none)
        Weapons[0].StopBerserk();
    if (Weapons[1] != none)
        Weapons[1].StopBerserk();
}

/* Ammo Interface */

simulated function class<Ammunition> GetAmmoClass(int mode)
{
    local int a, b;
    a = SelectedAmmo;
    b = a^1;

    if (Weapons[a] != none)
        return Weapons[a].GetAmmoClass(mode);
    if (Weapons[b] != none)
        return Weapons[b].GetAmmoClass(mode);

    return none;
}

simulated function MaxOutAmmo()
{
    local int i;

    for (i = 0; i < 2; i++)
        if (Weapons[i] != none)
            Weapons[i].MaxOutAmmo();
}

simulated function SuperMaxOutAmmo()
{
    local int i;

    for (i = 0; i < 2; i++)
        if (Weapons[i] != none)
            Weapons[i].SuperMaxOutAmmo();
}

simulated function int MaxAmmo(int mode)
{
    local int a, b;
    a = SelectedAmmo;
    b = a^1;

    if (Weapons[a] != none)
        return Weapons[a].MaxAmmo(mode);
    if (Weapons[b] != none)
        return Weapons[b].MaxAmmo(mode);

    return 0;
}

simulated function FillToInitialAmmo(){}

simulated function int AmmoAmount(int mode)
{
    local int a, b;
    a = SelectedAmmo;
    b = a^1;

    if (Weapons[a] != none)
        return Weapons[a].AmmoAmount(mode);
    if (Weapons[b] != none)
        return Weapons[b].AmmoAmount(mode);

    return 0;
}

simulated function class<Pickup> AmmoPickupClass(int mode)
{
    local class<Ammunition> ac;

    ac = GetAmmoClass(mode);
    if (ac != none)
        return ac.default.PickupClass;

    return None;
}

simulated function bool AmmoMaxed(int mode)
{
    if (GetAmmoClass(mode) == none)
        return false;

    return (AmmoAmount(mode) >= MaxAmmo(mode));
}

simulated function GetAmmoCount(out float MaxAmmoPrimary, out float CurAmmoPrimary)
{
    local int a, b;
    a = SelectedAmmo;
    b = a^1;
    
    if (Weapons[a] != none)
        Weapons[a].GetAmmoCount(MaxAmmoPrimary, CurAmmoPrimary);
    else if (Weapons[b] != none)
        Weapons[b].GetAmmoCount(MaxAmmoPrimary, CurAmmoPrimary);
}

simulated function float AmmoStatus(optional int Mode) // returns float value for ammo amount
{
    local int a, b;
    a = SelectedAmmo;
    b = a^1;

    if (Weapons[a] != none)
        return Weapons[a].AmmoStatus(Mode);
    if (Weapons[b] != none)
        return Weapons[b].AmmoStatus(Mode);

    return 0;
}

simulated function bool ConsumeAmmo(int Mode, float load, optional bool bAmountNeededIsMax)
{
    // ConsumeAmmo should not be called for this weapon. The left and right
    // weapons should have ConsumeAmmo called by their fire-modes.
    return true;
}

function bool AddAmmo(int AmmoToAdd, int Mode)
{
    // should not be called. HandlePickupQuery should handle
    // picking up ammo for the child weapons.
    return false;
}

simulated function bool HasAmmo()
{
    // always "have ammo" (don't auto-switch away).
    // sub-weapons with no ammo are automatically switched
    // with sub-weapons that have ammo.
    return true;
}

// for AI
simulated function bool NeedAmmo(int mode)
{
    return false;
}

simulated function float DesireAmmo(class<Inventory> NewAmmoClass, bool bDetour)
{
    local int i;
    local float desire;
    
    // sub-weapons may not be in inventory, so
    // DesireAmmo may not normally be called for them.

    for (i = 0; i < 2; i++)
        if (Weapons[i] != none)
            desire += Weapons[i].DesireAmmo(NewAmmoClass, bDetour);

    return desire;
}

simulated function CheckOutOfAmmo()
{
    local int i;

    if (M_Weapons != none)
        for (i = 0; i < 2; i++)
        {
            if (Weapons[i] != none && !Weapons[i].HasAmmo())
                if (i == 0)
                    M_Weapons.SwitchLeftToBest();
                else
                    M_Weapons.SwitchRightToBest();
        }
}

simulated function DrawWeaponInfo(Canvas C)
{
    local int a, b;
    a = SelectedAmmo;
    b = a^1;

    if (Weapons[a] != none)
        Weapons[a].DrawWeaponInfo(C);
    else if (Weapons[b] != none)
        Weapons[b].DrawWeaponInfo(C);
}

simulated function NewDrawWeaponInfo(Canvas C, float YPos)
{
    local int a, b;
    a = SelectedAmmo;
    b = a^1;
    
    if (Weapons[a] != none)
        Weapons[a].NewDrawWeaponInfo(C, YPos);
    else if (Weapons[b] != none)
        Weapons[b].NewDrawWeaponInfo(C, YPos);
}

simulated function float ChargeBar()
{
    local int a, b;
    a = SelectedAmmo;
    b = a^1;

    if (Weapons[a] != none && Weapons[a].bShowChargingBar)
        return Weapons[a].ChargeBar();
    else if (Weapons[b] != none && Weapons[b].bShowChargingBar)
        return Weapons[b].ChargeBar();

    return 0;
}

simulated event RenderOverlays(Canvas Canvas)
{
    local dw_Module mod;

    // sub-weapons can change hands at any time (switches, akimbo duplicates),
    // so re-apply the wrapper's overlay to whichever weapons are held now
    UpdateSubWeaponOverlays();
    UpdateRPGOverlay(Weapons[0]);
    UpdateRPGOverlay(Weapons[1]);
    
    // let rendering module render first (so hud never goes over weapons)
    if (M_Rendering != none)
        M_Rendering.Master_RenderOverlays(Canvas);
    
    // let other modules render
    for (mod = ModuleList; mod != none; mod = mod.NextModule)
        if (mod != M_Rendering)
            mod.Master_RenderOverlays(Canvas);
}

simulated function PreDrawFPSubWeapon(int i);

/* AI functions */

function float RangedAttackTime()
{
    local float lowest;

    if (Weapons[0] != none)
    {
        lowest = Weapons[0].RangedAttackTime();
        if (Weapons[1] != none)
            lowest = FMin(lowest, Weapons[1].RangedAttackTime());
    }
    else if (Weapons[1] != none)
    {
        lowest = Weapons[1].RangedAttackTime();
    }
    return lowest;
}

function bool RecommendRangedAttack()
{
    return ((Weapons[0] == none || Weapons[0].RecommendRangedAttack())
        && (Weapons[1] == none || Weapons[1].RecommendRangedAttack()));
}

function bool RecommendLongRangedAttack()
{
    return ((Weapons[0] == none || Weapons[0].RecommendLongRangedAttack())
        && (Weapons[1] == none || Weapons[1].RecommendLongRangedAttack()));
}

function bool FocusOnLeader(bool bLeaderFiring)
{
    return ((Weapons[0] == none || Weapons[0].FocusOnLeader(bLeaderFiring))
        && (Weapons[1] == none || Weapons[1].FocusOnLeader(bLeaderFiring)));
}

// return true if weapon effect has splash damage (if significant)
// use by bot to avoid hurting self
// should be based on current firing Mode if active
function bool SplashDamage()
{
    local int h, mode;

    for (h = 0; h < 2; ++h)
        for (mode = 0; mode < NUM_FIRE_MODES; mode++)
        {
            if (Weapons[h].FireMode[mode].IsFiring() && Weapons[h].FireMode[mode].bSplashDamage)
                return true;
        }

    return false;
}

// return true if weapon should be fired to take advantage of splash damage
// For example, rockets should be fired at enemy feet
function bool RecommendSplashDamage()
{
    local int h, mode;

    for (h = 0; h < 2; ++h)
        for (mode = 0; mode < NUM_FIRE_MODES; mode++)
        {
            if (Weapons[h].FireMode[mode].IsFiring() && Weapons[h].FireMode[mode].bRecommendSplashDamage)
                return true;
        }

    return false;
}

function float GetDamageRadius()
{
    local float largest;
    local int h, mode;

    for (h = 0; h < 2; ++h)
        for (mode = 0; mode < NUM_FIRE_MODES; mode++)
        {
            if (Weapons[h].FireMode[mode].ProjectileClass != None)
                largest = FMax(Weapons[h].FireMode[mode].ProjectileClass.default.DamageRadius, largest);
        }

    return largest;
}

// Repeater weapons like minigun should be 0.99, other weapons based on likelihood
// of firing again right away
function float RefireRate()
{
    if (Weapons[0] != none && Weapons[1] != none)
        return (Weapons[0].RefireRate() + Weapons[1].RefireRate()) * 0.5;
    if (Weapons[0] != none)
        return Weapons[0].RefireRate();
    if (Weapons[1] != none)
        return Weapons[1].RefireRate();

    return 0;
}

// tells AI that it needs to release the fire button for this weapon to do anything
function bool FireOnRelease()
{
    local int h, mode;

    for (h = 0; h < 2; ++h)
        for (mode = 0; mode < NUM_FIRE_MODES; mode++)
        {
            if (Weapons[h].FireMode[mode].IsFiring() && Weapons[h].FireMode[mode].bFireOnRelease)
                return true;
        }

    return false;
}

simulated function Weapon RecommendWeapon( out float rating )
{
    local Weapon Recommended;
    local float oldRating;

    if ( (Instigator == None) || (Instigator.Controller == None) )
    {
        rating = -2;
    }
    else
    {
        rating = RateSelf();// + Instigator.Controller.WeaponPreference(self);

        if (Weapons[0] != none && Weapons[1] != none)
        {
            rating += 0.75
                * (Instigator.Controller.WeaponPreference(Weapons[0])
                 + Instigator.Controller.WeaponPreference(Weapons[1]));
        }
        //else: less than two weapons, so Dual Weapon is not so useful
    }

    if ( inventory != None )
    {
        Recommended = inventory.RecommendWeapon(oldRating);
        if ( (Recommended != None) && (oldRating > rating) )
        {
            rating = oldRating;
            return Recommended;
        }
    }
    return self;
}

function SetAITarget(Actor T)
{
    if (Weapons[0] != none)
        Weapons[0].SetAITarget(T);
    if (Weapons[1] != none)
        Weapons[1].SetAITarget(T);
}

/* BotFire()
Choose the best mode for each weapon, and switch to it if necessary.
If possible, fire both weapons.
25% chance of firing only one weapon when two are available.
*/
function bool BotFire(bool bFinished, optional name FiringMode)
{
    if (M_Firing != none)
        return M_Firing.BotFire(bFinished, FiringMode);
    
    return false;
}

// this returns the actual projectile spawn location or trace start
simulated function vector GetFireStart(vector X, vector Y, vector Z)
{
    if (Weapons[1] != none)
        return Weapons[1].GetFireStart(X, Y, Z);
    if (Weapons[0] != none)
        return Weapons[0].GetFireStart(X, Y, Z);
    return super.GetFireStart(X, Y, Z);
}

// need to figure out modified rating based on enemy/tactical situation
simulated function float RateSelf()
{
    local int i;
    local Weapon RateWeapons[2];
    local bool bBotOwner;

    if (Instigator != none && AIController(Instigator.Controller) != none)
    {
        // switch to best so rating is based on best dual-wieldable weapons
        if (M_Weapons != none)
            M_Weapons.SwitchBothToBest();

        bBotOwner = true;
    }

    if (M_Weapons != none)
        for (i = 0; i < 2; i++)
            RateWeapons[i] = M_Weapons.GetSelectedWeapon(i);

    if (RateWeapons[0] == none && RateWeapons[1] == none)
    {
        // no weapons!
        CurrentRating = -2;
    }
    else if (RateWeapons[0] != none && (RateWeapons[1] == none || !RateWeapons[1].HasAmmo()))
    {
        // weapons[1] is unusable, use weapons[0] rating
        CurrentRating = RateWeapons[0].RateSelf();
    }
    else if (RateWeapons[1] != none && (RateWeapons[0] == none || !RateWeapons[0].HasAmmo()))
    {
        // weapons[0] is unusable, use weapons[1] rating
        CurrentRating = RateWeapons[1].RateSelf();
    }
    else
    {
        // both weapons are valid and have ammo, rate both
        if (bEncourageBotDualing && bBotOwner)
            CurrentRating = (RateWeapons[0].RateSelf() + RateWeapons[1].RateSelf() + 0.5);
        else
            CurrentRating = ((RateWeapons[0].RateSelf() + RateWeapons[1].RateSelf()) * 0.75);
    }

    return CurrentRating;
}

function float GetAIRating()
{
    local float rating;

    if (Weapons[0] != none && Weapons[1] != none)
    {
        rating = (Weapons[0].GetAIRating() + Weapons[1].GetAIRating());

        if (bEncourageBotDualing)
            rating += 0.5;
        else
            rating *= 0.75;
    }
    else if (Weapons[0] != none)
        rating = Weapons[0].GetAIRating();
    else if (Weapons[1] != none)
        rating = Weapons[1].GetAIRating();

    return rating;
}

// tells bot whether to charge or back off while using this weapon
function float SuggestAttackStyle()
{
    if (Weapons[0] != none)
    {
        if (Weapons[1] != none) // use the avg of the two weapons' attack style
            return (Weapons[0].SuggestAttackStyle() + Weapons[1].SuggestAttackStyle()) * 0.5;
        else
            return Weapons[0].SuggestAttackStyle();
    }
    else if (Weapons[1] != none)
    {
        return Weapons[1].SuggestAttackStyle();
    }
    return 0.0;
}

// tells bot whether to charge or back off while defending against this weapon
function float SuggestDefenseStyle()
{
    if (Weapons[0] != none)
    {
        if (Weapons[1] != none) // use the avg of the two weapons' attack style
            return (Weapons[0].SuggestDefenseStyle() + Weapons[1].SuggestDefenseStyle()) * 0.5;
        else
            return Weapons[0].SuggestDefenseStyle();
    }
    else if (Weapons[1] != none)
    {
        return Weapons[1].SuggestDefenseStyle();
    }
    return 0.0;
}

// return true if recommend jumping while firing to improve splash damage (by shooting at feet)
// true for R.L., for example
function bool SplashJump()
{
    return (Weapons[0] != none && Weapons[0].SplashJump())
        || (Weapons[1] != none && Weapons[1].SplashJump());
}

// return false if out of range, can't see target, etc.
function bool CanAttack(Actor Other)
{
    return (Weapons[0] != none && Weapons[0].CanAttack(Other))
        || (Weapons[1] != none && Weapons[1].CanAttack(Other));
}

/* Misc */

function HolderDied()
{
    local Vector TossVel;
    local Vector X,Y,Z;
    local int i;
    local class<weapon> weaponClass;

    if (Weapons[0] != none)
        Weapons[0].HolderDied();
    if (Weapons[1] != none)
        Weapons[1].HolderDied();

    if (Instigator == none || IsGhosting())
    {
        return;
    }

    for (i = 0; i < 2; i++)
    {
        if (Weapons[i] != none)
        { // add "death holding weapon" for both weapons
            if (ModifiedWeapons[i] != none)
                weaponClass = ModifiedWeapons[i].Class;
            else
                weaponClass = Weapons[i].Class;
            
            switch (Caps(string(weaponClass)))
            {
            case "DUALWIELD.DW_LINKGUN":
            case "UT2004RPG.RPGLINKGUN":
                weaponClass = class'LinkGun';
            }

            if (TeamPlayerReplicationInfo(Instigator.PlayerReplicationInfo) != none)
                TeamPlayerReplicationInfo(Instigator.PlayerReplicationInfo).AddWeaponDeathHolding(weaponClass);
        }
        if (Weapons[i] != none && /*Weapons[i].CanThrow()*/ Weapons[i].bCanThrow && Weapons[i].HasAmmo())
        {
            TossVel = Vector(Instigator.GetViewRotation());
            TossVel = TossVel * ((Instigator.Velocity Dot TossVel) + 500) + Vect(0,0,200);

            Weapons[i].Velocity = TossVel;
            GetAxes(Instigator.Rotation,X,Y,Z);
            Weapons[i].DropFrom(Instigator.Location + 0.8 * Instigator.CollisionRadius * X - 0.5 * Instigator.CollisionRadius * Y);
        }
        if (Weapons[i] != none)
            Weapons[i].Hand = 0;
        Weapons[i] = none;
        ModifiedWeapons[i] = none;
    }

    ClientRemoveWeapons();
}

// UT2004 RPG Ghost ability hack
function bool IsGhosting()
{
    local Inventory inv;

    if (Instigator == none)
        return false;

    for (inv = Instigator.Inventory; inv != none; inv = inv.Inventory)
        if (inv.IsA('GhostInv'))
            return inv.GetPropertyText("bDisabled") == "False";

    return false;
}

// called by server to tell client to remove both weapons
simulated function ClientRemoveWeapons()
{
    if (Role < ROLE_Authority)
    {
        Weapons[0] = none;
        Weapons[1] = none;
        ChangedSubWeapons();
    }
}

simulated function bool CanThrow()
{
    return false;
}

function StartDebugging()
{
    if (Weapons[0] != none)
        Weapons[0].StartDebugging();
    if (Weapons[1] != none)
        Weapons[1].StartDebugging();
}

simulated function ClientWriteStats(byte Mode, bool bMatch, bool bAllowFire, bool bDelay, bool bAlt, float wait)
{
    if (Weapons[0] != none)
        Weapons[0].ClientWriteStats(Mode, bMatch, bAllowFire, bDelay, bAlt, wait);
    if (Weapons[1] != none)
        Weapons[1].ClientWriteStats(Mode, bMatch, bAllowFire, bDelay, bAlt, wait);
}

function class<DamageType> GetDamageType()
{
    return none;
}

function HackPlayFireSound()
{
}

simulated function DisplayDebug(Canvas Canvas, out float YL, out float YPos)
{
    local int i;
    local string T;

    //
    // Display debug info for self
    // (minus mesh/animation stuff)
    //

    Canvas.SetDrawColor(0,255,0);
    if ( (Pawn(Owner) != None) && (Pawn(Owner).PlayerReplicationInfo != None) )
        Canvas.DrawText("WEAPON "$GetItemName(string(self))$" Owner "$Pawn(Owner).PlayerReplicationInfo.PlayerName);
    else
        Canvas.DrawText("WEAPON "$GetItemName(string(self))$" Owner "$Owner);
    YPos += YL;
    Canvas.SetPos(4,YPos);

    //Canvas.DrawText("     PendingWeapons: "$GetItemName(string(PendingWeapons[0]))$", "$GetItemName(string(PendingWeapons[1])));
    //YPos += YL;
    //Canvas.SetPos(4,YPos);

    T = "     STATE: "$GetStateName()$" Timer: "$TimerCounter$" Client State ";

    Switch( ClientState )
    {
        case WS_None: T=T$"None"; break;
        case WS_Hidden: T=T$"Hidden"; break;
        case WS_BringUp: T=T$"BringUp"; break;
        case WS_PutDown: T=T$"PutDown"; break;
        case WS_ReadyToFire: T=T$"ReadyToFire"; break;
    }

    Canvas.DrawText(T, false);
    YPos += YL;
    Canvas.SetPos(4,YPos);

    for ( i=0; i<NUM_FIRE_MODES; i++ )
    {
        if ( FireMode[i] == None )
        {
            Canvas.DrawText("NO FIREMODE "$i);
            YPos += YL;
            Canvas.SetPos(4,YPos);
        }
        else
            FireMode[i].DisplayDebug(Canvas,YL,YPos);
    }

    //
    // Display debug info for sub-weapons
    //

    YPos += YL;
    if (Weapons[0] != none)
    {
        Canvas.DrawText("LEFT WEAPON");
        YPos += YL;
        Weapons[0].DisplayDebug(Canvas, YL, YPos);
    }
    else
    {
        Canvas.DrawText("LEFT WEAPON == None");
        YPos += YL;
    }
    YPos += YL * 2;

    if (Weapons[1] != none)
    {
        Canvas.DrawText("RIGHT WEAPON");
        YPos += YL;
        Weapons[1].DisplayDebug(Canvas, YL, YPos);
    }
    else
    {
        Canvas.DrawText("RIGHT WEAPON == None");
        YPos += YL;
    }
    YPos += YL;
}

simulated function bool ReadyToFire(int Mode)
{
    if (M_Firing != none)
        return M_Firing.DefaultReadyToFire(Mode);
    
    return false;
}

simulated event WeaponTick(float dt)
{
    local int i;
    local Weapon w;
    local dw_Module mod;
    

    if (Weapons[1] != none)
        w = Weapons[1];
    else if (Weapons[0] != none)
        w = Weapons[0];
    else
        w = none;

    if (w != none)
    {
        // update third-person weapon model references
        // (for network play, where these aren't replicated)
        if (w.ThirdPersonActor != none && w.ThirdPersonActor != ThirdPersonActor)
            ThirdPersonActor = w.ThirdPersonActor;
        if (Weapons[1] != none && Weapons[0] != none
            && Weapons[0].ThirdPersonActor != none
            && Weapons[0].ThirdPersonActor != OffhandActor)
            OffhandActor = Weapons[0].ThirdPersonActor;
    }

    w = Instigator.Weapon;
    for (i = 0; i < 2; i++)
    {
        if (Weapons[i] != none)
        {
            // ensure the weapon's location is updated
            // (should be adjusted more in RenderOverlays
            //  if the weapon is going to be rendered)
            Weapons[i].SetLocation(Instigator.Location);
            if (ModifiedWeapons[i] != none)
                ModifiedWeapons[i].SetLocation(Instigator.Location);

            // HACK for RL lock-on
            if (NeedsTickHack(Weapons[i]))
            {
                Instigator.Weapon = Weapons[i];
                Weapons[i].Tick(dt);
            }

            // Redeemers force you to switch weapons when they have no ammo
            // (so don't call WeaponTick for Redeemers)
            if (!Weapons[i].IsA('Redeemer')
                && (ModifiedWeapons[i] == none || !ModifiedWeapons[i].IsA('Redeemer')))
                Weapons[i].WeaponTick(dt);
        }
    }
    Instigator.Weapon = w;

    for (i = 0; i < 2; i++)
        UpdateRPGOverlay(Weapons[i]);

    // for improving GetEffectStart() results
    if (Weapons[0] != none && Weapons[1] != none)
    {
        LastFireMode = 1;
    }


    for (mod = ModuleList; mod != none; mod = mod.NextModule)
    {
        mod.Master_WeaponTick(dt);
        // destroyed in weapon tick (e.g. triggered shield gun fire, killed self)
        if (bDeleteMe || mod == none)
            break;
    }


    if (Weapons[0] != none && Weapons[1] != none)
    {
        if (Role < ROLE_Authority
            && LinkFire(Weapons[0].FireMode[1]) != none
            && LinkFire(Weapons[0].FireMode[1]).bIsFiring
            && LinkFire(Weapons[1].FireMode[1]) != none
            && LinkFire(Weapons[1].FireMode[1]).bIsFiring)
        {
            CheckLinkBeam(LinkFire(Weapons[0].FireMode[1]));
            CheckLinkBeam(LinkFire(Weapons[1].FireMode[1]));
        }
    }
}

// hack for correct link beam end-positioning in network games
// (LinkFire may grab the wrong beam)
simulated function CheckLinkBeam(LinkFire lf)
{
    local LinkBeamEffect LB;

    if (lf.Beam == none || lf.Beam.Class != lf.BeamEffectClass)
    {
        foreach DynamicActors(class'LinkBeamEffect', LB)
            if (!LB.bDeleteMe
                && LB.Class == lf.BeamEffectClass
                && LB.Instigator != None && LB.Instigator == lf.Instigator)
            {
                lf.Beam = LB;
                break;
            }
    }
}

simulated function ClientWeaponSet(bool bPossiblySwitch)
{
    local int i;

    super.ClientWeaponSet(bPossiblySwitch);
    
    if (Instigator == none)
        return;

    for (i = 0; i < 2; i++)
        if (Weapons[i] != none)
            UpdateInstigator(Weapons[i]);

    UpdateInstigator_Modules();
}

simulated function UpdateInstigator_Modules()
{
    if (M_Rendering != none)
        M_Rendering.Instigator = Instigator;
    if (M_Firing != none)
        M_Firing.Instigator = Instigator;
    if (M_Weapons != none)
        M_Weapons.Instigator = Instigator;
    if (M_Control != none)
        M_Control.Instigator = Instigator;
}

simulated function UpdateInstigator(Weapon w)
{
    w.Instigator = Instigator;
    if (w.FireMode[0] != none)
        w.FireMode[0].Instigator = Instigator;
    if (w.FireMode[1] != none)
        w.FireMode[1].Instigator = Instigator;
}

simulated event Tick(float DeltaTime)
{
    local int i;
    local bool bDoUpdate;

    if (bDeleteMe)
        return;

    for (i = 0; i < 2; i++)
    {
        if ((Weapons[i] != none
            // RPGWeapons with no ModifiedWeapon cause problems
             && Weapons[i].IsA('RPGWeapon') && Weapons[i].Owner != Owner))
        {
            bDoUpdate = true;
            Weapons[i] = none;
        }
    }
    if (bDoUpdate)
    {
        ChangedSubWeapons();
    }

    // UDamage/invis expire without calling SetOverlayMaterial on the container, so re-sync each tick
    UpdateSubWeaponOverlays();

    PublishHandWeapons();
}

simulated function PublishHandWeapons()
{
    LeftWeaponAlias = "";
    LeftWeaponItemName = "";
    RightWeaponAlias = "";
    RightWeaponItemName = "";

    if (Weapons[0] != none)
    {
        LeftWeaponAlias = string(Weapons[0].Class);
        LeftWeaponItemName = Weapons[0].Class.default.ItemName;
    }
    if (Weapons[1] != none)
    {
        RightWeaponAlias = string(Weapons[1].Class);
        RightWeaponItemName = Weapons[1].Class.default.ItemName;
    }
}

simulated function Timer()
{
    local int Mode;
    local float OldDownDelay;

    OldDownDelay = DownDelay;
    DownDelay = 0;

    if (ClientState == WS_BringUp)
    {
        UpdateFireModes();
        ClientState = WS_ReadyToFire;
    }
    else if (ClientState == WS_PutDown)
    {
        if ( OldDownDelay > 0 )
        {
            SetTimer(PutDownTime, false);
            return;
        }

        if ( Instigator.PendingWeapon == None )
        {
            ClientState = WS_ReadyToFire;
            // update sub-weapon ClientStates
            for (Mode = 0; Mode < 2; Mode++)
            {
                if (Weapons[Mode] != none && Weapons[Mode].ClientState == WS_PutDown)
                {
                    Weapons[Mode].ClientState = ClientState;
                    if (ModifiedWeapons[Mode] != none)
                        ModifiedWeapons[Mode].ClientState = ClientState;
                }
            }
            UpdateFireModes();
        }
        else
        {
            ClientState = WS_Hidden;
            // update sub-weapon ClientStates
            for (Mode = 0; Mode < 2; Mode++)
            {
                if (Weapons[Mode] != none && Weapons[Mode].ClientState == WS_PutDown)
                {
                    Weapons[Mode].ClientState = ClientState;
                    if (ModifiedWeapons[Mode] != none)
                        ModifiedWeapons[Mode].ClientState = ClientState;
                }
            }

            Instigator.ChangedWeapon();
            if ( Instigator.Weapon == self )
            {
                ClientState = WS_ReadyToFire;
                UpdateFireModes();
            }
        }
    }
}

simulated function Destroyed()
{
    local int h;

    // TitanRPG treats Hand != 0 as held; a gun left in inventory must not keep it
    for (h = 0; h < 2; ++h)
        if (Weapons[h] != none)
            Weapons[h].Hand = 0;

    if (ThirdPersonActor != none)
        ThirdPersonActor.Destroy();
    if (OffhandAiming != none)
        OffhandAiming.Destroy();
    if (OffhandActor != none)
        OffhandActor.Destroy();

    if (Role == ROLE_Authority)
    { // clean up server-controlled modules
        if (M_Rendering != none)
            M_Rendering.Destroy();
        if (M_Firing != none)
            M_Firing.Destroy();
    }
    if (M_Weapons != none)
        M_Weapons.Destroy();
    if (M_Control != none)
        M_Control.Destroy();

    super.Destroyed();
}

// third-person stuff
function AttachToPawn(Pawn P)
{
    local name BoneName;
    local Inventory primaryInv;

    if (Weapons[1] != none)
    {
        primaryInv = Weapons[1];
    }
    else if (Weapons[0] != none)
    {
        primaryInv = Weapons[0];
    }
    else
        return;

    if (Weapons[0] != none)
    {
        // try to prevent accessed nones
        if (Weapons[0].AttachmentClass == class'LinkAttachment')
            Weapons[0].AttachmentClass = class'dw_LinkAttachment';
        Weapons[0].AttachToPawn(P);
    }
    if (Weapons[1] != none)
    {
        if (Weapons[1].AttachmentClass == class'LinkAttachment')
            Weapons[1].AttachmentClass = class'dw_LinkAttachment';
        Weapons[1].AttachToPawn(P);
    }

    ThirdPersonActor = primaryInv.ThirdPersonActor;

    if (Weapons[1] != none && Weapons[0] != none)
    {
        OffhandActor = Weapons[0].ThirdPersonActor;

        if (OffhandActor != none)
        {
            BoneName = P.GetOffhandBoneFor(Weapons[0]);
            if ( BoneName == '' )
            {
                // not network-compatible?:
                if (xWeaponAttachment(OffhandActor) != none)
                    xWeaponAttachment(OffhandActor).Hide(true);
                else
                    OffhandActor.bHidden = true;

                OffhandActor = none;
            }
            else
            {
                P.AttachToBone(OffhandActor,BoneName);

                OffhandActor.SetRelativeRotation(rot(0,32768,0) + OffhandActor.RelativeRotation);
                if ((xPawn(Instigator) == none) || !xPawn(Instigator).bClearWeaponOffsets)
                    OffhandActor.SetRelativeLocation(GetOffhandOffset(OffhandActor));

                OffhandAiming = OffhandActor.Spawn(class'dw_OffhandAimActor');
                OffhandAiming.InitFor(OffhandActor);
            }

            // so xPawn doesn't hold one weapon with both hands when there are two weapons..
            if (xWeaponAttachment(ThirdPersonActor) != none)
                xWeaponAttachment(ThirdPersonActor).bHeavy = false;
        }
    }
}

// RelativeLocation doesn't look right left-handed,
// so it's overridden here for the stock weapons
simulated function vector GetOffhandOffset(Actor offhand)
{
    if (offhand.IsA('AssaultAttachment'))
        return vect(40,-3,-7);

    if (offhand.IsA('BioAttachment'))
        return vect(10,-5,-5);
    if (offhand.IsA('ONSMineLayerAttachment'))
        return vect(15,-5,-5);

    if (offhand.IsA('LinkAttachment'))
        return vect(-10,-4,-10);

    if (offhand.IsA('MinigunAttachment'))
        return vect(10,-10,-5);

    if (offhand.IsA('FlakAttachment'))
        return vect(10,-5,-5);
    if (offhand.IsA('ONSGrenadeAttachment'))
        return vect(20,0,-10);

    if (offhand.IsA('RocketAttachment'))
        return vect(15,-5,-5);
    if (offhand.IsA('ONSAVRiLAttachment'))
        return vect(-30,0,-15);

    if (offhand.IsA('SniperAttachment'))
        return vect(10,-10,-5);
    if (offhand.IsA('ClassicSniperAttachment'))
        return vect(45,-5,-10);

    if (offhand.IsA('RedeemerAttachment'))
        return vect(55,-5,-5);

    return offhand.RelativeLocation;
}

simulated function DetachFromPawn(Pawn P)
{
    super.DetachFromPawn(P);

    if (OffhandAiming != none)
        OffhandAiming.Destroy();

    if (OffhandActor != None)
    {
        // reset left arm rotation
        Instigator.SetBoneDirection(OffhandActor.AttachmentBone, OffhandActor.Rotation,, 0, 0);
        Instigator.SetBoneDirection('lfarm', OffhandActor.Rotation,, 0, 0);

        OffhandActor.Destroy();
        OffhandActor = None;
    }

    if (Weapons[0] != none)
        Weapons[0].DetachFromPawn(P);
    if (Weapons[1] != none)
        Weapons[1].DetachFromPawn(P);
}

// shield gun support (not working?):
function bool CheckReflect( Vector HitLocation, out Vector RefNormal, int AmmoDrain )
{
    return (Weapons[0] != none && Weapons[0].CheckReflect(HitLocation, RefNormal, AmmoDrain))
        || (Weapons[1] != none && Weapons[1].CheckReflect(HitLocation, RefNormal, AmmoDrain));
}

function AdjustPlayerDamage( out int Damage, Pawn InstigatedBy, Vector HitLocation,
                             out Vector Momentum, class<DamageType> DamageType)
{
    if (Weapons[0] != none)
        Weapons[0].AdjustPlayerDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType);
    if (Weapons[1] != none)
        Weapons[1].AdjustPlayerDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType);
}

simulated function SetOverlayMaterial( Material mat, float time, bool bOverride )
{
    super.SetOverlayMaterial(mat, time, bOverride);

    UpdateSubWeaponOverlays();
}

simulated function UpdateSubWeaponOverlays()
{
    SyncSubOverlay(Weapons[0]);
    SyncSubOverlay(Weapons[1]);
    SyncSubOverlay(ThirdPersonActor);
    SyncSubOverlay(OffhandActor);
}

// The pawn's UDamage/invis overlay expires natively on the container, so judge it by the pawn's
// state. Once it has expired, a held gun gets back its RPG modifier overlay (or none).
simulated function SyncSubOverlay(Actor A)
{
    local xPawn P;
    local RPGBase WM;
    local Material mat;
    local float time;

    if (A == none)
        return;

    mat = OverlayMaterial;
    time = OverlayTimer;
    P = xPawn(Instigator);
    if (P != none && ((mat == P.UDamageWeaponMaterial && !P.HasUDamage()) || (mat == P.InvisMaterial && !P.bInvis)))
        mat = none;

    // only ever clear the pawn's own UDamage/invis overlay; leave RPG and other overlays alone
    if (mat == none)
    {
        if (P == none || (A.OverlayMaterial != P.UDamageWeaponMaterial && A.OverlayMaterial != P.InvisMaterial))
            return;
        if (Weapon(A) != none)
        {
            WM = FindRPGModifier(Weapon(A));
            if (WM != none && WM.IsIdentified() && WM.GetWeapon() == A)
            {
                mat = WM.GetOverlay();
                time = 9999;
            }
        }
    }

    if (A.OverlayMaterial != mat)
        A.SetOverlayMaterial(mat, time, true);
}

// Modifiers are owned by the pawn, so find the one whose weapon is W
simulated function RPGBase FindRPGModifier(Weapon W)
{
    local Pawn P;
    local RPGBase WM;

    P = Pawn(W.Owner);
    if (P == none)
        P = Instigator;
    if (P == none)
        return none;

    foreach P.ChildActors(class'RPGBase', WM)
        if (WM.GetWeapon() == W)
            return WM;
    return none;
}

// TitanRPG's modifier only applies its overlay while its weapon is Instigator.Weapon,
// which a held sub-weapon never is, so apply the modifier's overlay directly
simulated function UpdateRPGOverlay(Weapon W)
{
    local RPGBase WM;
    local Weapon Owned;

    if (W == none)
        return;

    WM = FindRPGModifier(W);
    Owned = none;
    if (WM != none)
        Owned = WM.GetWeapon();

    if (WM != none && WM.IsIdentified() && Owned != none
        && Owned.OverlayMaterial != WM.GetOverlay())
        WM.SetOverlay();
}

//TEST THIS:
function SynchronizeWeapon(Weapon ClientWeapon)
{
    if (ClientWeapon == Weapons[0] || ClientWeapon == Weapons[1])
        return;
    super.SynchronizeWeapon(ClientWeapon);
}

// the following function is a crappy hack for first-person effect offsets
// and should only affect weapons whose effects use the value returned
// by Instigator.Weapon.GetEffectStart() (like Shock Rifle and Link Gun)
simulated function vector GetEffectStart()
{
    local int i;

    i = GetEffectStartWeapon();
    if (i > -1 && i < 2)
    {
        // Pawn.CalcDrawOffset() uses DisplayFOV of current weapon
        DisplayFOV = Weapons[i].DisplayFOV;

        return Weapons[i].GetEffectStart();
    }

    return Instigator.Location;
}

// HACK: tries to put the firing effects on the correct weapon
// (slightly better than picking a random weapon)
simulated function int GetEffectStartWeapon()
{
    local int i, j;
    local float FireTime[2];
    
    // if only one weapon, use it
    if ((Weapons[0] == none) || (Weapons[1] == none))
    {
        if (Weapons[0] != none)
            return 0;
        else if (Weapons[1] != none)
            return 1;
        else
            return -1;
    }

    // if currently executing ModeDoFire for a weapon's firemode, use that weapon
    if (M_Firing != none && M_Firing.FiringWeapon != -1 && Weapons[M_Firing.FiringWeapon] != none)
        return M_Firing.FiringWeapon;

    for (i = 0; i < 2; i++)
        for (j = 0; j < NUM_FIRE_MODES; j++)
            if (Weapons[i].FireMode[j] != none && Weapons[i].FireMode[j].IsFiring())
            {
                if (Weapons[i].FireMode[j].IsA('LinkFire'))
                    FireTime[i] = Level.TimeSeconds;
                else
                    FireTime[i] = FMax(
                        FireTime[i],
                        (Weapons[i].FireMode[j].NextFireTime - Weapons[i].FireMode[j].FireRate));
            }

    if (FireTime[0] == FireTime[1])
        LastFireMode = LastFireMode^1;

    else if (FireTime[0] < FireTime[1])
        LastFireMode = 0;

    else
        LastFireMode = 1;

    return LastFireMode;
}

// returns true if mode cannot be changed yet
simulated function bool ModeIsFiring(int Mode)
{
    if (FireMode[Mode].IsFiring())
        return true;

    if (FireMode[Mode].NextFireTime >= Level.TimeSeconds /*+ FireMode[Mode].PreFireTime*/)
        return true;

    // minigun wind-up/down needs this hack
    if (MinigunFire(FireMode[Mode]) != none
        && !MinigunFire(FireMode[Mode]).IsIdle())
        return true;

    return false;
}

// used by dw_LinkBeamEffect
simulated function WeaponFire GetSubWeaponFireMode(int weapIndex, name fireModeType)
{
    if (Weapons[weapIndex] != none)
    {
        if (Weapons[weapIndex].FireMode[0].IsA(fireModeType))
            return Weapons[weapIndex].FireMode[0];

        if (Weapons[weapIndex].FireMode[1].IsA(fireModeType))
            return Weapons[weapIndex].FireMode[1];
    }

    return none;
}

function ThrowSubWeapon(int hand)
{
    local Vector TossVel;
    local Vector X,Y,Z;

    if ((hand < 0) || (hand > 1) || (Weapons[hand] == none))
        return;

    if (Level.Game.bAllowWeaponThrowing && Weapons[hand].CanThrow())
    {
        // weapons module may disallow weapon throwing
        if (M_Weapons != none && !M_Weapons.AllowThrowWeapon(hand))
            return;

        TossVel = Vector(Instigator.Controller.GetViewRotation());
        TossVel = TossVel * ((Instigator.Velocity Dot TossVel) + 500) + Vect(0,0,250);

        Weapons[hand].Velocity = TossVel;
        GetAxes(Instigator.Rotation,X,Y,Z);
        Weapons[hand].DropFrom(Instigator.Location + 0.8 * Instigator.CollisionRadius * X - 0.5 * Instigator.CollisionRadius * Y);

        // a thrown gun is no longer held; clear Hand so TitanRPG modifiers on it stop ticking
        Weapons[hand].Hand = 0;
        Weapons[hand] = none;
        ServerChangedSubWeapon(hand, none);

        ClientRemoveWeapon(hand);

        if (M_Weapons != none) {
            if (hand == 0)
                M_Weapons.SwitchLeftToBest();
            else
                M_Weapons.SwitchRightToBest();
        }
    }
}

// called by the server to tell client to remove a weapon
simulated function ClientRemoveWeapon(int hand)
{
    if (Role < ROLE_Authority)
    {
        if (Weapons[hand] != none)
            Weapons[hand].Hand = 0;
        Weapons[hand] = none;
        ChangedSubWeapon(hand);
    }
}

simulated function IncrementZoomRenderCondition()
{
    if (M_Rendering != none)
        M_Rendering.IncrementZoomRenderCondition();
}

//
// compatibility hacks for weapons which use console commands:
//

// Remote Strike & HaloUT reloading
exec function ReloadMeNow()
{
    CommandSubWeapons("ReloadMeNow");
}

// Remote Strike Functions
exec function ToggleLight()
{
    CommandOneSubWeapon("ToggleLight", 'RemoteStrikeWeapon');
}

exec function ToggleTargeter()
{
    CommandSubWeapons("ToggleTargeter");
}

simulated exec function CombatZoom()
{
    // if both weapons are RemoteStrikeWeapons, using CombatZoom
    // on both will toggle zoom twice, and appear to do nothing,
    // so call CombatZoom for only one RemoteStrikeWeapon
    // (or both weapons if one is not a RemoteStrikeWeapon)
    CommandOneSubWeapon("CombatZoom", 'RemoteStrikeWeapon');
}

simulated function CommandOneSubWeapon(string command, name weaponName)
{
    if (Weapons[0] != none && Weapons[0].IsA(weaponName))
        CommandSubWeapon(0, command);
    else
        CommandSubWeapons(command);
}

// ChaosUT multiple ammo-types
exec function ChangeAmmo()
{
    CommandSubWeapons("ChangeAmmo");
}

// ChaosUT weapons special function
exec function ChaosWeaponOption()
{
    CommandSubWeapons("ChaosWeaponOption");
}

// Ballistic Weapons Functions
exec simulated function Reload ()
{
    CommandSubWeapons("Reload");
}

exec simulated function SwitchWeaponMode ()
{
    CommandSubWeapons("SwitchWeaponMode");
}

exec simulated function WeaponSpecial(optional byte i)
{
    local int j;

    // M50 AR acts strange if both weapons try to activate camera,
    // so only activate one (prefer the one with a camera deployed)
    if (Weapons[0] != none && Weapons[1] != none
        && Weapons[0].IsA('M50AssaultRifle')
        && Weapons[1].IsA('M50AssaultRifle'))
    {
        if (Weapons[0].GetPropertyText("Camera") != "None")
            j = 0;
        else
            j = 1;

        CommandSubWeapon(j, "WeaponSpecial "$i);
    }
    else
        CommandSubWeapons("WeaponSpecial "$i);
}

// perform a console command on a sub-weapon
exec function CommandSubWeapon(int hand, string command)
{
    local Weapon w;

    if ((hand < 0) || (hand > 1) || (Weapons[hand] == none)
        || (PlayerController(Instigator.Controller) == none))
        return;

    w = Instigator.Weapon;
    Instigator.Weapon = Weapons[hand];
    PlayerController(Instigator.Controller).ConsoleCommand(command);
    Instigator.Weapon = w;
}

// perform a console command on both sub-weapons
exec function CommandSubWeapons(string command)
{
    local Weapon w;
    local int i;

    if (PlayerController(Instigator.Controller) != none)
    {
        w = Instigator.Weapon;
        for (i = 0; i < 2; i++)
        {
            if (Weapons[i] != none)
            {
                Instigator.Weapon = Weapons[i];
                PlayerController(Instigator.Controller).ConsoleCommand(command);
            }
        }
        Instigator.Weapon = w;
    }
}

// hacky function for compatibility with UT2004 RPG:
// tries to find an RPGWeapon's ModifiedWeapon by
// comparing the FireModes of the weapons.
simulated function Weapon FindModifiedWeapon(Weapon rpgWeapon)
{
    local Weapon inv;

    if (Instigator == none)
        return none;

    foreach Instigator.ChildActors(class'Weapon', inv)
    {
        if (inv != none
            && !inv.IsA('dw_DualWeapon')
            && !inv.IsA('RPGWeapon')
            && inv.FireMode[0] == rpgWeapon.FireMode[0])
        {
            return inv;
        }
    }
    return none;
}

function bool CheckAkimboPickup(Pickup item)
{
    if (M_Weapons != none)
        return M_Weapons.CheckAkimboPickup(item);

    return false;
}

function CheckAkimboLocker(WeaponLocker L)
{
    local int i;

    if (L == none || L.InventoryType != class'dw_DummyWeapon')
        return;

    for (i = 0; i < L.Weapons.Length; i++)
    {
        if (L.Weapons[i].WeaponClass != none
            && L.Weapons[i].WeaponClass != class'dw_DummyWeapon')
        {
            L.InventoryType = L.Weapons[i].WeaponClass;
            CheckAkimboPickup(L);
        }
    }
    L.InventoryType = class'dw_DummyWeapon';
}

simulated function ClientForceAmmoUpdate(int Mode, int NewAmount)
{
    // REMOVED: call to Log()
    if ( bNoAmmoInstances )
        AmmoCharge[Mode] = NewAmount;
    else if ( Ammo[mode] != None )
        Ammo[mode].AmmoAmount = NewAmount;
}

simulated function bool NeedsTickHack(Weapon w)
{
    if (w.IsA('RocketLauncher'))
        return true;
    // not necessary for later builds of BallisticWeapon
    // as they changed to using WeaponTick(), but still
    // necessary for older versions
    if (w.IsA('BallisticWeapon'))
        return true;

    return false;
}

simulated function Weapon NextWeapon(Weapon CurrentChoice, Weapon CurrentWeapon)
{
    if (!bNoVoluntarySwitch)
        return super.NextWeapon(CurrentChoice, CurrentWeapon);

	if ( Inventory == None )
		return CurrentChoice;
	else
		return Inventory.NextWeapon(CurrentChoice,CurrentWeapon);
}

simulated function Weapon PrevWeapon(Weapon CurrentChoice, Weapon CurrentWeapon)
{
    if (!bNoVoluntarySwitch)
        return super.PrevWeapon(CurrentChoice, CurrentWeapon);

	if ( Inventory == None )
		return CurrentChoice;
	else
		return Inventory.PrevWeapon(CurrentChoice,CurrentWeapon);
}

simulated function SwitchToDualWeapon()
{
    local Pawn P;
    local int h;
    
    P = Pawn(Owner);

    if (P == none || P.Inventory == none || dw_DualWeapon(P.Weapon) != none)
        return;
    if (P.PendingWeapon != None && P.PendingWeapon.bForceSwitch)
        return;

    P.PendingWeapon = self;
    
    if (PlayerController(P.Controller) != none)
    {
        if (P.IsLocallyControlled()
           && int(P.Controller.Handedness) != PlayerHandedness)
        { // try to keep handedness syncd with server
            PlayerHandedness = P.Controller.Handedness;
            ServerSetHandedness(PlayerHandedness);
        }

        if (PlayerHandedness == -1)
            h = 0; // left
        else
            h = 1; // right (or centered or hidden, but default to right)

        if (P.Weapon == Weapons[h])
        { // don't play putdown or bringup (weapon not really changing)
            P.ChangedWeapon();
            return;
        }
    }
    if (P.Weapon != none)
        P.Weapon.PutDown();
}

// Determines whether to call BringUp() for a given sub-weapon
// when the Dual Weapon is taken out (from dw_DualWeapon.BringUp()).
// realWeapon is the single weapon being switched to or from.
simulated function bool AllowQuickSwitch(Weapon realWeapon, int hand)
{
    local int h;
    
    if (realWeapon == none || Pawn(Owner) == none)
        return false;
    
    if (PlayerController(Pawn(Owner).Controller) != none)
    {
        if (Pawn(Owner).IsLocallyControlled()
           && int(Pawn(Owner).Controller.Handedness) != PlayerHandedness)
        { // try to keep handedness syncd with server
            PlayerHandedness = Pawn(Owner).Controller.Handedness;
            ServerSetHandedness(PlayerHandedness);
        }

        if (PlayerHandedness == -1)
            h = 0; // left
        else
            h = 1; // right (or centered or hidden, but default to right)
    }
    else
        h = 1;

    return realWeapon == Weapons[hand] && hand == h && realWeapon.ClientState == WS_ReadyToFire;
}

simulated function bool IsCurrentWeapon()
{
    return (Instigator != none && Instigator.Weapon == self);
}

// give someone a Dual Weapon
static function GiveDualWeapon(Pawn Other, Mutator BaseMutator)
{
    Other.GiveWeapon("DualWieldV1.dw_DualWeapon");
}

// if Other is holding the Dual Weapon, this gets it
static function dw_DualWeapon GetDualWeapon(Pawn Other, optional bool bSearchInventory)
{
    if (Other == none)
        return none;

    if (dw_DualWeapon(Other.Weapon) != none)
        return dw_DualWeapon(Other.Weapon);

    if (bSearchInventory && Other.Inventory != none)
        return dw_DualWeapon(Other.FindInventoryType(class'dw_DualWeapon'));

    return none;
}

static function Inventory FindInventory(Pawn P, class<Inventory> DesiredClass)
{
    return P.FindInventoryType(DesiredClass);
}

static function MutatorInitialized(MutDualWield mut);

simulated function bool HasAmmoHack(Weapon w)
{
    local int i;
    
    if (w.Instigator == none)
    {
        if (Instigator == none)
            return w.HasAmmo();
        w.Instigator = Instigator;
    }
    
    // TODO: Check that the following hack is still necessary

    // when a weapon is destroyed, it destroys its Ammunition,
    // even though Ammunition is shared!
    if (!w.bNoAmmoInstances)
        for (i = 0; i < 2; i++)
            if (w.Ammo[i] == none && w.AmmoClass[i] != none)
                w.Ammo[i] = Ammunition(w.Instigator.FindInventoryType(w.AmmoClass[i]));

    if (!w.bNoAmmoInstances
        && ((w.Ammo[0] != none && w.Ammo[0].HasAmmo())
         || (w.Ammo[1] != none && w.Ammo[1].HasAmmo())))
    {
        // hook for xReload- ammunition determines if weapon really has ammo
        // (may have AmmoAmount==0, but ammo still in magazine)
    }
    else
        return w.HasAmmo();

    return true;
}

simulated function bool IsAkimboWeapon(Weapon w)
{
    if (dw_WeaponsModuleDefault(M_Weapons) != none)
        return dw_WeaponsModuleDefault(M_Weapons).IsAkimboWeapon(w);
    return false;
}

defaultproperties
{
	RenderingModuleClass=Class'DualWieldV1.dw_RenderingModuleDefault'
	FiringModuleClass=Class'DualWieldV1.dw_FiringModuleDefault'
	WeaponsModuleClass=Class'DualWieldV1.dw_WeaponsModuleDefault'
	ControlModuleClass=Class'DualWieldV1.dw_ControlModuleDefault'
	SingleButtonControlModuleClass=Class'DualWieldV1.dw_ControlModuleSingle'
	bAutoSwitchAmmo=True
	LinkBeamEffectClass(0)=Class'DualWieldV1.dw_LinkBeamEffect_L'
	LinkBeamEffectClass(1)=Class'DualWieldV1.dw_LinkBeamEffect_R'
	FireModeClass(0)=Class'DualWieldV1.dw_DualFire'
	FireModeClass(1)=Class'DualWieldV1.dw_DualFire'
	bCanThrow=False
	bNoInstagibReplace=True
	Priority=100
	CustomCrossHairScale=0.666700
	CustomCrossHairTextureName="Crosshairs.HUD.Crosshair_Cross5"
	InventoryGroup=11
	ItemName="Dual Weapon"
	DrawType=DT_None
	Mesh=SkeletalMesh'NewWeapons2004.AssaultRifle'
}
