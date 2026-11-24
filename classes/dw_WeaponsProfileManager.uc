/* DualWield.dw_WeaponsProfileManager
 *  Replicates weapons profiles.
 */
class dw_WeaponsProfileManager extends dw_ActorBase;

var string CurrentProfileName;
var dw_WeaponsProfile Profile;

var int CurrentGroup;

replication
{
    // functions client -> server
    reliable if (Role < ROLE_Authority)
        ServerSendProfile;
    
    // functions server -> client
    reliable if (Role == ROLE_Authority)
        ClientBeginGroup, ClientReceiveWeapons, ClientReceiveFilter, ClientReceiveGroupCount,         ClientSetProfileName, ClientSetProfileFlags, ClientSetBlockedClasses;}

function Initialize(string profileName)
{
    local dw_WeaponsProfileManager wpm;
    
    CurrentProfileName = profileName;
    CurrentGroup = 0;
    
    foreach DynamicActors(class'dw_WeaponsProfileManager', wpm)
    {
        if (wpm == self)
            continue;
        // try to create only one instance of the profile
        // (may be multiple managers- one for each human player)
        if (wpm.Profile != none && string(wpm.Profile.Name) ~= profileName)
        {
            Profile = wpm.Profile;
            break;
        }
    }

    if (Profile == none || !(string(Profile.Name) ~= profileName))
        Profile = class'dw_WeaponsProfile'.static.GetProfile(profileName);

    Profile.SetBlockedClasses(class'dw_WeaponsModule'.default.BlockedBaseClasses);

    if (Level.NetMode != NM_Standalone)
    {
        SetTimer(0, false);

        ClientSetProfileName(profileName);
        ClientSetProfileFlags(Profile.bExcludeMode, Profile.bStrictNaming);
        ClientSetBlockedClasses(class'dw_WeaponsModule'.default.BlockedBaseClasses);

        //if (!Profile.IsPreset)
        //{ // profile is not a preset, gradually replicate it to the client
        //    SetTimer(1.0/NetUpdateFrequency, true);
        //}
    }
}

function Timer()
{
    if (CurrentGroup < Profile.WeaponGroups.Length)
    {
        if (CurrentGroup == 0)
            ClientReceiveGroupCount(Profile.WeaponGroups.Length);

        SendGroup(CurrentGroup);
        ++CurrentGroup;
    }
    else
    {
        SetTimer(0, false);
        // May need to update profile later.
        //bTearOff = true;
    }
}

// Each RPC string is limited to 255 characters, so a group is sent as a
// header, weapon names packed into chunks (never split mid-name), and
// filter text in fixed-size parts.
function SendGroup(int num)
{
    local int i;
    local string chunk, wname, filter;

    ClientBeginGroup(num, Profile.WeaponGroups[num].Restriction);

    for (i = 0; i < Profile.WeaponGroups[num].Weapons.Length; ++i)
    {
        wname = string(Profile.WeaponGroups[num].Weapons[i]);
        if (chunk != "" && Len(chunk) + Len(wname) + 1 > 200)
        {
            ClientReceiveWeapons(num, chunk);
            chunk = "";
        }
        if (chunk != "")
            chunk $= ",";
        chunk $= wname;
    }
    if (chunk != "")
        ClientReceiveWeapons(num, chunk);

    filter = Profile.WeaponGroups[num].Filter;
    while (filter != "")
    {
        ClientReceiveFilter(num, Left(filter, 200));
        filter = Mid(filter, 200);
    }
}

// Called by client for server to start sending profile.
function ServerSendProfile()
{
    if (TimerRate == 0)
    {
        CurrentGroup = 0;
        SetTimer(1.0/NetUpdateFrequency, true);
    }
}

simulated function ClientBeginGroup(int num, coerce int restrict)
{
    if (Role < ROLE_Authority && Profile != none)
        Profile.BeginWeaponGroup(num, restrict);
}

simulated function ClientReceiveWeapons(int num, string weaponlist)
{
    local int i;
    local string weapon;

    if (Role < ROLE_Authority && Profile != none)
    {
        while (weaponlist != "")
        {
            i = InStr(weaponlist, ",");
            if (i != -1)
            {
                weapon = Left(weaponlist, i);
                weaponlist = Mid(weaponlist, i+1);
            }
            else
            {
                weapon = weaponlist;
                weaponlist = "";
            }

            if (weapon != "")
                Profile.AddWeaponToGroup(num, weapon);
        }
    }
}

simulated function ClientReceiveFilter(int num, string part)
{
    if (Role < ROLE_Authority && Profile != none)
        Profile.AppendGroupFilter(num, part);
}

// Groups don't carry the profile's mode flags, so they are sent separately.
// Without these, a client treats an exclude-mode profile as allow-all.
simulated function ClientSetProfileFlags(bool bExclude, bool bStrict)
{
    if (Role < ROLE_Authority && Profile != none)
    {
        Profile.bExcludeMode = bExclude;
        Profile.bStrictNaming = bStrict;
    }
}

// Blocked base classes come from the server's INI, so they are sent separately.
simulated function ClientSetBlockedClasses(string list)
{
    if (Role < ROLE_Authority && Profile != none)
        Profile.SetBlockedClasses(list);
}

// Replicate group count to client, to ensure count is correct
// if the profile is preset client-side but not server-side.
simulated function ClientReceiveGroupCount(int count)
{
    if (Role < ROLE_Authority)
        Profile.WeaponGroups.Length = Max(count, 0);
}

simulated function PostBeginPlay()
{
    local dw_WeaponsProfile wp;

    if (Role < ROLE_Authority)
        if (Profile == none)
        { // init temp profile obj
            wp = new(none, "DELETEME") class'dw_WeaponsProfile';
            wp.Reset(); // don't allow it to be configured
            SetProfile(wp);
        }
}

simulated function ClientSetProfileName(string profileName)
{
    local dw_WeaponsProfile wp;

    if (Role < ROLE_Authority)
    {
        CurrentProfileName = profileName;

        if (CurrentProfileName != "")
        { // received profile name
            if (class'dw_WeaponsProfile'.static.ProfileIsPreset(CurrentProfileName))
            { // current profile is a preset, load it straight away
                SetProfile(class'dw_WeaponsProfile'.static.GetProfile(CurrentProfileName));
            }
            else
            {
                if (Profile == none || Profile.Name != 'DELETEME')
                { // may have switched profiles mid-game; start from a clean slate
                    wp = new(none, "DELETEME") class'dw_WeaponsProfile';
                    wp.Reset();
                    SetProfile(wp);
                }
            }
        }
        // tell server to send us the profile
        ServerSendProfile();
    }
}

simulated function SetProfile(dw_WeaponsProfile newProfile)
{
    local dw_WeaponsModule wm;
    
    // sync profile with weapons modules
    foreach DynamicActors(class'dw_WeaponsModule', wm)
    {
        if (wm.CurrentProfile == Profile || wm.CurrentProfile == none)
            wm.CurrentProfile = newProfile;
    }

    Profile = newProfile;
}

defaultproperties
{
	bOnlyRelevantToOwner=True
	bReplicateMovement=False
	bSkipActorPropertyReplication=True
	RemoteRole=ROLE_SimulatedProxy
	NetUpdateFrequency=5.000000
}
