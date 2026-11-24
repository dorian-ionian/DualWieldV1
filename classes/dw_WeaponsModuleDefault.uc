/* DualWield.dw_WeaponsModuleDefault
 */
class dw_WeaponsModuleDefault extends dw_WeaponsModule;

var Weapon PendingWeapons[2]; // weapons being switched to
var float  PendingTime[2];    // time when pending weapon should change (end of animation)
var byte   ForcePutDown[2];   // if (> 0) must put the weapon down (even if Pending is none)

var Inventory DuplicateList; // duplicate weapons (for "Akimbo")

var name TempName;

// Switch logging: logs when a switch is requested, completes, or stays pending over StuckSeconds
var config bool bDebugSwitchLog;
var config float StuckSeconds;
var float PendingStart[2];    // level time when the current switch was requested
var byte  SwitchLogged[2];    // 1 = a switch is in progress and its request was logged
var byte  StuckLogged[2];     // 1 = the current switch was already reported as stuck

replication
{
    reliable if (bNetDirty && bNetOwner && Role == ROLE_Authority)
        DuplicateList;
    
    // functions client->server
    reliable if (Role < ROLE_Authority)
        ServerChangeWeapon;

    // functions server->client
    reliable if (Role == ROLE_Authority)
        ClientSelectWeapon;
}

/** ACCESSORS **/

// Get the current or pending weapon.
simulated function Weapon GetSelectedWeapon(int hand)
{
    if (PendingWeapons[hand] != none)
        return PendingWeapons[hand];

    return DW.Weapons[hand];
}

/** WEAPON SELECTION/SWITCHING **/

// Put newWeapon in the specified hand.
simulated function SelectWeapon(Weapon newWeapon, int hand)
{
    if (newWeapon != none && DW.Weapons[hand] == newWeapon
       && (newWeapon.ClientState == WS_ReadyToFire || newWeapon.ClientState == WS_BringUp))
        return;

    if (Role == ROLE_Authority)
        ClientSelectWeapon(newWeapon, hand);

    if (newWeapon == none)
        ForcePutDown[hand] = 1;
    PendingWeapons[hand] = newWeapon;
}

protected simulated function ClientSelectWeapon(Weapon newWeapon, int hand)
{
    if (Role < ROLE_Authority)
    {
        if (newWeapon == none)
            ForcePutDown[hand] = 1;
        PendingWeapons[hand] = newWeapon;
    }
}

simulated function bool AllowThrowWeapon(int hand)
{
    local Inventory inv;

    // if weapon is in the DuplicateList, remove it
    if (DW.Weapons[hand] == DuplicateList)
    {   // weapon is at the head of the list - move the head
        DuplicateList = DW.Weapons[hand].Inventory;
    }
    else
    {
        for (inv = DuplicateList; inv != none; inv = inv.Inventory)
        {   // weapon is the next item - set the next item to the one after
            if (inv.Inventory == DW.Weapons[hand])
            {
                inv.Inventory = inv.Inventory.Inventory;
                break;
            }
        }
    }
    return true;
}

/** MASTER EVENTS **/

simulated event Master_BringUp(optional Weapon PrevWeapon)
{
    if (Role == ROLE_Authority
        && DW.Weapons[0]     == none && DW.Weapons[1]     == none
        && PendingWeapons[0] == none && PendingWeapons[1] == none)
    {
        SwitchLeftToBest();
        SwitchRightToBest();
    }
}

simulated function LogSwitch(int hand, string Event)
{
    local Weapon W;
    local string cs;

    W = DW.Weapons[hand];
    if (W != none)
        cs = string(GetEnum(enum'EWeaponClientState', W.ClientState));

    Log("DualWieldSwitch:" @ Event @ "hand=" $ hand
        @ "role=" $ Role
        @ "old=" $ W @ "oldState=" $ cs
        @ "pending=" $ PendingWeapons[hand]
        @ "pendingTime=" $ PendingTime[hand]
        @ "forcePutDown=" $ ForcePutDown[hand]
        @ "time=" $ Level.TimeSeconds, 'DualWieldSwitch');
}

simulated event Master_WeaponTick(float dt)
{
    local int i, j;

    for (i = 0; i < 2; i++)
    {
        if (DW.Weapons[i] != none)
        {
            // RPGWeapons which no longer belong to Owner can not be PutDown()
            if (DW.Weapons[i].IsA('RPGWeapon') && DW.Weapons[i].Owner != DW.Owner)
            {
                // remove weapon immediately
                DW.Weapons[i] = none;
                DW.ChangedSubWeapon(i);

                if (i == 0)
                    SwitchLeftToBest();
                else
                    SwitchRightToBest();
            }
            else if (!IsUsableWeapon(DW.Weapons[i], i))
            {
                if (i == 0)
                    SwitchLeftToBest();
                else
                    SwitchRightToBest();
            }
        }
    }

    // make absolutely sure we are not changing to a weapon that we are already holding.
    // if we try to fire when we have the same weapon in both hands, the game crashes.
    for (i = 0; i < 2; i++)
    {
        j = i^1;

        // do not allow switching one hand to a weapon already held in the other hand
        if (PendingWeapons[i] != none && PendingWeapons[i] == DW.Weapons[j])
        {
            PendingWeapons[i] = none;
            if (DW.Weapons[j].ClientState == WS_Hidden)
                DW.Weapons[j].BringUp();
        }
    }
    // do not allow switching both hands to the same weapon
    if (PendingWeapons[0] != none && PendingWeapons[0] == PendingWeapons[1])
        PendingWeapons[0] = none;

    for (i = 0; i < 2; i++)
    {
        // dual-weapon switching code:
        if ((PendingWeapons[i] != none) || (ForcePutDown[i] != 0))
        {
            if (bDebugSwitchLog && SwitchLogged[i] == 0)
            {
                SwitchLogged[i] = 1;
                PendingStart[i] = Level.TimeSeconds;
                LogSwitch(i, "requested");
            }

            if (DW.Weapons[i] == none
                || DW.Weapons[i].ClientState == WS_Hidden
                || (PendingTime[i] >= 0 && PendingTime[i] <= Level.TimeSeconds))
            {
                // allow firing module to prevent weapon-switch
                if (DW.M_Firing != none
                   && !DW.M_Firing.AllowWeaponChange(PendingWeapons[i], i))
                    continue;

                if (DW.Weapons[i] != none)
                {
                    // hide the old weapons so they can be brought back up later
                    DW.Weapons[i].ClientState = WS_Hidden;
                    if (DW.ModifiedWeapons[i] != none)
                        DW.ModifiedWeapons[i].ClientState = WS_Hidden;
                }

                if (PendingWeapons[i] != none)
                {
                    if (Role < ROLE_Authority)
                    {
                        DW.Weapons[i] = PendingWeapons[i];

                        DW.ChangedSubWeapon(i);

                        DW.Weapons[i].ClientState = WS_Hidden; // make sure it plays bring up anim
                        if (DW.ModifiedWeapons[i] != none) // for UT2004 RPG compatibility
                            DW.ModifiedWeapons[i].ClientState = WS_Hidden;

                        DW.Weapons[i].BringUp();
                    }
                    ServerChangeWeapon(PendingWeapons[i], i);
                }
                else
                {
                    DW.Weapons[i] = none;

                    DW.ServerChangedSubWeapon(i, DW.Weapons[i]);
                    if (Role < ROLE_Authority)
                        DW.ChangedSubWeapon(i);
                }

                if (SwitchLogged[i] != 0)
                {
                    if (bDebugSwitchLog)
                        LogSwitch(i, "done after" @ (Level.TimeSeconds - PendingStart[i]) $ "s");
                    SwitchLogged[i] = 0;
                    StuckLogged[i] = 0;
                }

                PendingWeapons[i] = none;
                PendingTime[i] = -1;

                ForcePutDown[i] = 0;
            }
            else
            {
                if (bDebugSwitchLog && StuckLogged[i] == 0 && Level.TimeSeconds - PendingStart[i] > StuckSeconds)
                {
                    StuckLogged[i] = 1;
                    LogSwitch(i, "STUCK");
                }

                if (DW.Weapons[i].ClientState != WS_PutDown)
                {
                    if (DW.Weapons[i].PutDown() && DW.Weapons[i].ClientState == WS_PutDown)
                    {
                        PendingTime[i] = Level.TimeSeconds + DW.Weapons[i].TimerRate;

                        DW.Weapons[i].SetTimer(10000000, false);
                    }
                }
            }
        }
        else if (DW.Weapons[i] != none && DW.Weapons[i].ClientState == WS_Hidden)
        {
            // hack to fix "sub-weapon freezing"
            DW.Weapons[i].ClientState = WS_ReadyToFire;
            // sync ClientState for RPG, otherwise weapon-switching won't work. ouch!
            if (DW.ModifiedWeapons[i] != none)
                DW.ModifiedWeapons[i].ClientState = WS_ReadyToFire;
        }
    }
}

/** WEAPON-FINDING FUNCTIONS **/

// Find a weapon of the specified class usable in the specified hand.
simulated function Weapon GetWeapon(class<Weapon> weaponType, int hand)
{
    local Inventory inv;
    
    inv = Instigator.FindInventoryType(weaponType);
    
    if (Weapon(inv) != none)
    {
        if (DW.Weapons[hand^1] == inv || PendingWeapons[hand^1] == inv)
            inv = FindDuplicate(class<Weapon>(inv.Class));

        if (inv != none && IsUsableWeapon(Weapon(inv), hand))
            return Weapon(inv);
    }
    return none;
}

// Find the next weapon after current, usable in hand.
simulated function Weapon GetNextUsableWeapon(Weapon current, int hand)
{
    local Weapon Inv;
    local Weapon dup;
    local int i;
    
    if (Instigator == none)
        return none;

    if (current == none)
    {
        return GetBestUsableWeapon(hand);
    }
    
    Inv = current;
    
    if (IsAkimboWeapon(Inv))
    { // Akimbo weapons aren't in the inventory chain,
        // so use the original weapon of the same class.
        Inv = Weapon(Instigator.FindInventoryType(current.Class));
        // FindInventoryType may return sub-classes (which we don't want)
        if (Inv == none || Inv.Class != current.Class)
            Inv = current;
    }

    while (Inv != none)
    {
        // get the next weapon in logical order
        // (not necessarily actual order in inventory chain)
        Inv = Instigator.Inventory.NextWeapon(none, Inv);
        
        if (Inv == none || Inv == DW)
            continue;
        
        // + give up after 100 tries (prevent possible infinite loop)
        // + give up after cycling through all weapons
        if ((i++ > 100) || (Inv == current))
            break;

        if (inv == DW.Weapons[hand^1] || inv == PendingWeapons[hand^1])
        { // weapon already in the other hand, check for a duplicate (for akimbo)
            dup = FindDuplicate(inv.Class);

            if (dup != none && IsUsableWeapon(dup, hand))
                return dup;
        }
        else
        if (IsUsableWeapon(inv, hand))
            return inv;
    }
    return none;
}

// Find the previous weapon before current, usable in hand.
simulated function Weapon GetPrevUsableWeapon(Weapon current, int hand)
{
    local Weapon Inv;
    local Weapon dup;
    local int i;
    
    if (Instigator == none)
        return none;

    if (current == none)
    {
        return GetBestUsableWeapon(hand);
    }
    
    Inv = current;
    
    if (IsAkimboWeapon(Inv))
    { // Akimbo weapons aren't in the inventory chain,
        // so use the original weapon of the same class.
        Inv = Weapon(Instigator.FindInventoryType(current.Class));
        // FindInventoryType may return sub-classes (which we don't want)
        if (Inv == none || Inv.Class != current.Class)
            Inv = current;
    }

    while (Inv != none)
    {
        // PrevWeapon instead of NextWeapon (see above)
        Inv = Instigator.Inventory.PrevWeapon(none, Inv);
        
        if (Inv == none || Inv == DW)
            continue;
        
        if ((i++ > 100) || (Inv == current))
            break;

        if (inv == DW.Weapons[hand^1] || inv == PendingWeapons[hand^1])
        {
            dup = FindDuplicate(inv.Class);

            if (dup != none && IsUsableWeapon(dup, hand))
                return dup;
        }
        else
        if (IsUsableWeapon(inv, hand))
            return inv;
    }
    return none;
}

// Find the best weapon usable in hand.
simulated function Weapon GetBestUsableWeapon(int hand)
{
    local Inventory inv;
    local Weapon best;
    local Weapon w;
    local float bestRating, rating;
    local int other;
    
    if (Instigator == none)
        return none;
    
    other = hand^1;

    for (inv = Instigator.Inventory; inv != none; inv = inv.Inventory)
    {
        if (!inv.IsA('Weapon'))
            continue;

        // if weapon is in other hand, rate its akimbo duplicate instead
        if (DW.Weapons[other] == inv || PendingWeapons[other] == inv)
            w = FindDuplicate(class<Weapon>(inv.Class));
        else
            w = Weapon(inv);
        
        if (w == none)
            continue;

        if (!IsUsableWeapon(w, hand))
            continue;

        if (w.Instigator == none)
            w.Instigator = Instigator;

        rating = w.RateSelf();

        // any weapon with ammo beats a weapon with no ammo (and no weapon at all)
        if (best == none || !best.HasAmmo() || rating > bestRating)
        {
            best = w;
            bestRating = rating;
        }
    }

    return best;
}

// Find the next weapon in slot F, usable in hand.
simulated function Weapon GetSlotWeapon(byte F, int hand, optional Weapon current)
{
    local Weapon newWeapon, dup;
    local int tries, other;
    local bool bLooped;

    if ((Instigator == none) || (Instigator.Inventory == none))
        return none;

    if (current == none)
        current = GetSelectedWeapon(hand);

    if (current != none)
    {
        if (IsAkimboWeapon(current))
        { // akimbo weapons are in a seperate list, so use its duplicate weapon
            current = Weapon(DW.FindInventory(Instigator, current.Class));
        }

        if (current != none && current.Inventory != none)
            newWeapon = current.Inventory.WeaponChange(F, true);
    }

    if (newWeapon == none)
    {
        bLooped = true; // don't loop around
        newWeapon = Instigator.Inventory.WeaponChange(F, true);
    }

    if (newWeapon == none)
        return none;

    other = hand^1;

    while (newWeapon != none && !IsUsableWeapon(newWeapon, hand) && (tries++ < 100))
    {
        dup = FindDuplicate(newWeapon.Class);

        // check if its akimbo duplicate is somehow usable
        if (dup != none && IsUsableWeapon(dup, hand)) {
            newWeapon = dup;
            break;
        }

        if (newWeapon != none && newWeapon.Inventory != none)
        {
            newWeapon = newWeapon.Inventory.WeaponChange(F, true);
        }
        else
        {
            if (bLooped) // already looped, no use looping again
                break;
            bLooped = true;
            // loop around (to find weapons earlier in the chain than the current one)
            newWeapon = Instigator.Inventory.WeaponChange(F, true);
        }
    }

    return newWeapon;
}

/** USABILITY DETERMINATION **/

// Determine if w is dual-wieldable in the specified hand.
simulated function bool IsUsableWeapon(Weapon w, int hand)
{
    local int other;

    if (w == none || w.IsA('dw_DualWeapon'))
        return false;

    if (w.bNoVoluntarySwitch)
        return false;

    other = hand^1;

    // can't dual-wield one weapon in both hands!
    if (DW.Weapons[other] == w || PendingWeapons[other] == w)
        return false;

    if (!DW.HasAmmoHack(w))
        return false;

    // enforce weapon-selection rules on RPGWeapon's "sub-weapon"
    // (RPGWeapon is kind of a wrapper for a weapon, like dw_DualWeapon)
    if (w.IsA('RPGWeapon'))
    {
        w = DW.FindModifiedWeapon(w);
        if (w != none)
            return IsUsableWeapon(w, hand);
        else
            return false;
    }
    
    if (CurrentProfile != none)
        return CurrentProfile.AllowWeapon(w, DW, hand);
    
    return true;
}

/** PROTECTED FUNCTIONS **/

protected function ServerChangeWeapon(Weapon PendingWeapon, int hand)
{
    if (DW.Weapons[hand] != none && DW.Weapons[hand] != PendingWeapon)
        DW.Weapons[hand].Hand = 0;
    DW.Weapons[hand] = PendingWeapon;

    DW.ChangedSubWeapon(hand);

    DW.Weapons[hand].ClientState = WS_Hidden; // make sure it plays bring up anim
    if (DW.ModifiedWeapons[hand] != none) // for UT2004 RPG compatibility
        DW.ModifiedWeapons[hand].ClientState = WS_Hidden;

    DW.Weapons[hand].BringUp();
}

protected simulated function Weapon FindDuplicate(class<Weapon> type)
{
    local Inventory inv;
    
    for (inv = DuplicateList; inv != none; inv = inv.Inventory)
        if (inv.Class == type)
            return Weapon(inv);

    return none;
}

/*protected*/ simulated function bool IsAkimboWeapon(Weapon w)
{
    local Inventory inv;
    
    for (inv = DuplicateList; inv != none; inv = inv.Inventory)
        if (inv == w)
            return true;

    return false;
}

/** AKIMBO WEAPONS **/

function bool CheckAkimboPickup(Pickup item)
{
    local class<Weapon> WeaponType;

    WeaponType = class<Weapon>(item.InventoryType);

    if (!GiveDuplicate(WeaponType, WeaponPickup(item)))
        return false;

    if (!item.IsA('WeaponLocker'))
    {
        item.AnnouncePickup(DW.Instigator);
        item.SetRespawn();
    }
    return true;
}

// TitanRPG only applies modifiers when a weapon is given through the normal pickup path,
// so a duplicate copies the TitanRPG modifier from the owner's weapon of the same class
function CopyRPGModifier(class<Weapon> WeaponType, Weapon dup)
{
    local Pawn P;
    local Inventory inv;
    local Weapon orig;
    local RPGBase WM;

    P = Pawn(DW.Owner);
    if (P == none)
        return;

    for (inv = P.Inventory; inv != none; inv = inv.Inventory)
    {
        if (inv.Class == WeaponType && inv != dup)
        {
            orig = Weapon(inv);
            break;
        }
    }
    if (orig == none)
        return;

    //TitanRPG modifiers are owned by the pawn, not the weapon, so search the pawn's children.
    //Match the original weapon instance, so a same-class modifier of another instance is never used.
    WM = none;
    foreach P.ChildActors(class'RPGBase', WM)
        if (WM.GetWeapon() == orig)
            break;
    if (WM != none)
    {
        //Each copy gets its own modifier, rolled separately from the original's
        WM = WM.CloneFor(dup);
    }
}


function bool GiveDuplicate(class<Weapon> WeaponType, optional WeaponPickup item)
{
    local Inventory inv;
    local Weapon dup;
    
    if (WeaponType == none)
        return false;
    
    // only one dup of each class
    for (inv = DuplicateList; inv != none; inv = inv.Inventory)
        if (inv.Class == WeaponType)
            return false;
    
    // spawn dup
    dup = Spawn(WeaponType,DW.Owner,,,rot(0,0,0));
    if (dup == none)
        return false;

    // check the spawned instance so sub-classes are matched
    if (CurrentProfile != none && ! CurrentProfile.AllowAkimbo(dup))
    {
        dup.Destroy();
        return false;
    }

    // give dup to owner
    dup.Instigator = DW.Instigator;
    dup.SetOwner(DW.Owner);
    dup.GiveAmmo(0, item, true);
    dup.GiveAmmo(1, item, true);

    CopyRPGModifier(WeaponType, dup);

    // add dup to list
    if (DuplicateList != none)
        dup.Inventory = DuplicateList;
    DuplicateList = dup;

    return true;
}

/** CLEANUP **/

function Destroyed()
{
    local Inventory inv, next;
    
    super.Destroyed();

    for (inv = DuplicateList; inv != none; inv = next)
    {
        next = inv.Inventory;
        inv.Destroy();
    }
}

defaultproperties
{
	PendingTime(0)=-1.000000
	PendingTime(1)=-1.000000
	StuckSeconds=3.000000
}
