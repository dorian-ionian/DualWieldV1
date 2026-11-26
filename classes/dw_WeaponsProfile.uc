/* DualWield.dw_WeaponsProfile
 */
class dw_WeaponsProfile extends dw_ProfileBase;

enum EGroupRestriction
{
    WR_Disallowed,          // weapons in this group are never allowed
    WR_MutuallyExclusive,   // weapons in this group may not be dual-wielded with each other
    WR_Allowed              // only applicable in EXCLUDE mode (weapons in this group are allowed)
};

struct WeaponGroup
{
    var config string            GroupName;
    var config EGroupRestriction Restriction;
    var config array<name>       Weapons;
    
    // Object property filter which determines whether a weapon group's
    // restrictions apply to a given weapon.
    // See DualWieldV1.dw_ObjectFilter for syntax.
    var config string Filter;
    
    var transient dw_ObjectFilter FilterObj; // actual "compiled" filter
};


var config bool bExcludeMode; // if true, allow only weapons in WR_Allowed groups
var config bool bStrictNaming; // if true, class name must match, so sub-classes aren't picked up

// WeaponGroups define which weapons can or cannot be dual-wielded.
var config array<WeaponGroup> WeaponGroups;

var transient name tempname;

// Base classes that may never be dual-wielded (from BlockedBaseClasses in the INI).
var transient array<name> BlockedClasses;

// Package-qualified classes that may never be dual-wielded (from BlockedClassPaths in the INI).
var transient array<class> BlockedClassRefs;

function bool IsBlockedClass(Weapon w)
{
    local int i;

    for (i = 0; i < BlockedClasses.Length; ++i)
        if (w.IsA(BlockedClasses[i]))
            return true;

    for (i = 0; i < BlockedClassRefs.Length; ++i)
        if (w.Class == BlockedClassRefs[i])
            return true;

    return false;
}

function bool AllowWeapon(Weapon w, dw_DualWeapon DW, int hand)
{
    local int i, j, k;
    local bool bAllow;
    local int other;
    local Weapon otherWeapon;

    if (IsBlockedClass(w))
        return false;

    other = hand^1;
    
    if (DW.M_Weapons != none)
        otherWeapon = DW.M_Weapons.GetSelectedWeapon(other);
    else
        otherWeapon = DW.Weapons[other];

    if (bExcludeMode)
    {
        // in exclude mode, only weapons in WR_Allowed groups are allowed-
        // all other groups are ignored.

        for (i = 0; i < WeaponGroups.Length; ++i)
        {
            // Sub-classed weapons may be recognized as their parent class.
            // If this occurs, it should be possible to disallow said sub-classes.
            // (For example, ShockRifles are allowed, but not SuperShockRifles.)
            // This does not apply if strict naming rules are in use.
            // (i.e. SuperShockRifle is not perceived as a ShockRifle.)
            if (WeaponGroups[i].Restriction == WR_Disallowed && bStrictNaming)
                continue;
            
            for (j = 0; j < WeaponGroups[i].Weapons.Length; ++j)
                if (w.Class.Name == WeaponGroups[i].Weapons[j]
                   || (!bStrictNaming && w.IsA(WeaponGroups[i].Weapons[j])))
                { // found weapon in this group
                    if (WeaponGroups[i].Filter != "")
                    { // group has a filter
                        if (WeaponGroups[i].FilterObj == none)
                        { // parse filter string (once only)
                            WeaponGroups[i].FilterObj = new class'dw_ObjectFilter';
                            WeaponGroups[i].FilterObj.Parse(WeaponGroups[i].Filter);
                        }
                        
                        // if weapon doesn't match filter, group doesn't apply
                        if (!WeaponGroups[i].FilterObj.IsMatch(w))
                            break;
                    }
                    
                    if (WeaponGroups[i].Restriction == WR_Disallowed)
                    {
                        return false;
                    }
                    else if (WeaponGroups[i].Restriction == WR_MutuallyExclusive)
                    {
                        if (DW.Weapons[other] != none || otherWeapon != none)
                            for (k = 0; k < WeaponGroups[i].Weapons.Length; ++k)
                            {
                                // If weapon in other hand is also in this group,
                                // this weapon cannot be dual-wielded.
                                if (bStrictNaming) {
                                    if (DW.Weapons[other] != none && DW.Weapons[other].Class.Name == WeaponGroups[i].Weapons[k])
                                        return false;
                                    if (otherWeapon != none && otherWeapon.Class.Name == WeaponGroups[i].Weapons[k])
                                        return false;
                                } else {
                                    if (DW.Weapons[other] != none && DW.Weapons[other].IsA(WeaponGroups[i].Weapons[k]))
                                        return false;
                                    if (otherWeapon != none && otherWeapon.IsA(WeaponGroups[i].Weapons[k]))
                                        return false;
                                }
                            }
                    }
                    bAllow = true;
                    // continue looking
                    // (if w is in another mutually exclusive group, it may not be allowed)
                }
        }
        return bAllow;
    }
    else
    {
        for (i = 0; i < WeaponGroups.Length; ++i)
        {
            // WR_Allowed groups have no effect, as exclude mode is disabled
            if (WeaponGroups[i].Restriction == WR_Allowed)
                continue;
            
            for (j = 0; j < WeaponGroups[i].Weapons.Length; ++j)
                if (w.Class.Name == WeaponGroups[i].Weapons[j]
                   || (!bStrictNaming && w.IsA(WeaponGroups[i].Weapons[j])))
                { // found weapon in this group
                    if (WeaponGroups[i].Filter != "")
                    { // group has a filter
                        if (WeaponGroups[i].FilterObj == none)
                        { // parse filter string (once only)
                            WeaponGroups[i].FilterObj = new class'dw_ObjectFilter';
                            WeaponGroups[i].FilterObj.Parse(WeaponGroups[i].Filter);
                        }
                     
                        // if weapon doesn't match filter, group doesn't apply
                        if (!WeaponGroups[i].FilterObj.IsMatch(w))
                            break;
                    }
                    
                    if (WeaponGroups[i].Restriction == WR_MutuallyExclusive)
                    {
                        if (DW.Weapons[other] != none || otherWeapon != none)
                            for (k = 0; k < WeaponGroups[i].Weapons.Length; ++k)
                            {
                                // If weapon in other hand is also in this group,
                                // this weapon cannot be dual-wielded.
                                if (bStrictNaming) {
                                    if (DW.Weapons[other] != none && DW.Weapons[other].Class.Name == WeaponGroups[i].Weapons[k])
                                        return false;
                                    if (otherWeapon != none && otherWeapon.Class.Name == WeaponGroups[i].Weapons[k])
                                        return false;
                                } else {
                                    if (DW.Weapons[other] != none && DW.Weapons[other].IsA(WeaponGroups[i].Weapons[k]))
                                        return false;
                                    if (otherWeapon != none && otherWeapon.IsA(WeaponGroups[i].Weapons[k]))
                                        return false;
                                }
                            }
                    }
                    else // WR_Disallowed
                        return false;
                }
        }
        return true;
    }
}

// Possibly prevent an akimbo weapon from being picked up.
// May not be accuracte if weapon is not listed, but is a
// sub-class of a listed weapon (when bStrictNaming==False),
// or if its group has a filter.
// Takes the spawned duplicate, so IsA() can match sub-classes.
function bool AllowAkimbo(Weapon w)
{
    local int i, j;
    local bool bAllow;

    if (IsBlockedClass(w))
        return false;

    if (bExcludeMode)
    {
        // If strict naming is disabled, assume weapon *might* be allowed
        // (may be a sub-class of a listed weapon)
        bAllow = ! bStrictNaming;
        // Otherwise, weapon must be in an Allowed group.

        for (i = 0; i < WeaponGroups.Length; ++i)
        {
            for (j = 0; j < WeaponGroups[i].Weapons.Length; ++j)
                if (w.Class.Name == WeaponGroups[i].Weapons[j])
                {
                    if (WeaponGroups[i].Restriction == WR_Allowed)
                    { // assume group may apply to this weapon (ignore filter)
                        bAllow = true;
                        break;
                    }

                    if (WeaponGroups[i].Filter != "")
                    { // group has a filter, may not be applicable
                        break;
                    }
                    
                    if (WeaponGroups[i].Restriction != WR_Allowed)
                    {   // either:
                        //  disallowed, or
                        //  mutually exclusive (no akimbo)
                        return false;
                    }
                }
        }
        // assume weapon *might* be allowed
        return bAllow;
    }
    else
    {
        for (i = 0; i < WeaponGroups.Length; ++i)
        {
            if (WeaponGroups[i].Restriction == WR_Allowed)
                continue;
            
            for (j = 0; j < WeaponGroups[i].Weapons.Length; ++j)
                if (w.Class.Name == WeaponGroups[i].Weapons[j]
                   || (!bStrictNaming && w.IsA(WeaponGroups[i].Weapons[j])))
                {
                    if (WeaponGroups[i].Filter != "")
                    { // group has a filter, may not be applicable
                        break;
                    }

                    // either:
                    //  disallowed, or
                    //  mutually exclusive (no akimbo)
                    return false;
                }
        }
        // assume weapon *might* be allowed
        return true;
    }
}


/** FUNCTIONS FOR REPLICATING PROFILES **/

function SetRestriction(int num, int restrict)
{
    if (num < WeaponGroups.Length)
        WeaponGroups[num].Restriction = EGroupRestriction(Clamp(restrict, 0, 2));
}

function BeginWeaponGroup(int num, int restrict)
{
    if (WeaponGroups.Length < num+1)
        WeaponGroups.Length = num+1;

    WeaponGroups[num].Restriction = EGroupRestriction(restrict);
    WeaponGroups[num].Weapons.Length = 0;
    WeaponGroups[num].Filter = "";
    WeaponGroups[num].FilterObj = none;
}

function AddWeaponToGroup(int num, string weaponName)
{
    local int n;

    if (num >= WeaponGroups.Length)
        return;

    // string -> name conversion of a variable needs SetPropertyText
    SetPropertyText("tempname", weaponName);
    if (tempname == '')
        return;

    n = WeaponGroups[num].Weapons.Length;
    WeaponGroups[num].Weapons.Length = n+1;
    WeaponGroups[num].Weapons[n] = tempname;
}

// Takes the next trimmed entry off a comma-separated list. Returns "" when none is left.
function string PopListPart(out string list)
{
    local int i;
    local string part;

    while (part == "" && list != "")
    {
        i = InStr(list, ",");
        if (i != -1)
        {
            part = Left(list, i);
            list = Mid(list, i+1);
        }
        else
        {
            part = list;
            list = "";
        }

        while (Left(part, 1) == " ")
            part = Mid(part, 1);
        while (Len(part) > 0 && Right(part, 1) == " ")
            part = Left(part, Len(part)-1);
    }

    return part;
}

// Parses a comma-separated list of base class names (spaces around names are ignored).
function SetBlockedClasses(string list)
{
    local string part;

    BlockedClasses.Length = 0;
    part = PopListPart(list);
    while (part != "")
    {
        // string -> name conversion of a variable needs SetPropertyText
        SetPropertyText("tempname", part);
        if (tempname != '')
        {
            BlockedClasses.Length = BlockedClasses.Length + 1;
            BlockedClasses[BlockedClasses.Length-1] = tempname;
        }
        part = PopListPart(list);
    }
}

// Parses a comma-separated list of package-qualified class names, e.g. XWeapons.Minigun.
// Names that don't load are skipped.
function SetBlockedClassPaths(string list)
{
    local string part;
    local class c;

    BlockedClassRefs.Length = 0;
    part = PopListPart(list);
    while (part != "")
    {
        c = class(DynamicLoadObject(part, class'Class', true));
        if (c != none)
        {
            BlockedClassRefs.Length = BlockedClassRefs.Length + 1;
            BlockedClassRefs[BlockedClassRefs.Length-1] = c;
        }
        part = PopListPart(list);
    }
}

// Filter may arrive in several parts; the compiled filter is rebuilt lazily.
function AppendGroupFilter(int num, string part)
{
    if (num >= WeaponGroups.Length)
        return;

    WeaponGroups[num].Filter $= part;
    WeaponGroups[num].FilterObj = none;
}

function Reset()
{
    super.Reset();
    
    DisplayName   = default.DisplayName;
    bExcludeMode  = default.bExcludeMode;
    bStrictNaming = default.bStrictNaming;
    WeaponGroups  = default.WeaponGroups;
}

/** FUNCTIONS FOR RETRIEVING PROFILES **/

static function dw_WeaponsProfile GetProfile(string profileName)
{
    return dw_WeaponsProfile(GetProfileBase(profileName));
}

defaultproperties
{
	Presets(0)=Class'DualWieldV1.dw_WPDefault'
	//Presets(1)=Class'DualWieldV1.dw_WPMinigunOnly'
}
