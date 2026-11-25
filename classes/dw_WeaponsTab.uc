/* DualWield.dw_WeaponsTab
 */
class dw_WeaponsTab extends UT2K4TabPanel;

var automated GUISectionBackground bg_Groups, bg_Weapons, bg_AllWeapons, bg_Props;

// Profile management
var automated moComboBox cb_Profile;
var automated GUIButton  btn_DelProfile, btn_AddProfile, btn_RenProfile;
var automated moEditBox  ed_ProfileName;

// Weapon Groups
var automated GUIListBox lb_Groups;

// Selected Weapons
var automated GUIListBox lb_Weapons;

// Available Weapons
var automated GUIListBox lb_AllWeapons;

// Options & Group Properties
var automated moComboBox cb_Restriction;
var automated moEditBox  ed_Filter, ed_GroupName;
var automated moCheckBox ch_ExcludeMode, ch_StrictNaming;

var localized string RestrictionDesc[3];
var localized string PresetPrefix;
var localized string NewGroupItem;
var localized string UnknownPackageText, OfficialPackageText;
var array<string> OfficialPackages;

var array<CacheManager.WeaponRecord> WeaponList;

// profiles pending deletion when user clicks "OK"
var array<dw_WeaponsProfile> DeletedProfiles;

var name tempname;

var bool bForceReloadProfile;


function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
    local int i;

    super.InitComponent(MyController, MyOwner);
    
    class'CacheManager'.static.GetWeaponList(WeaponList);
    
    for (i = 0; i < ArrayCount(RestrictionDesc); ++i)
        cb_Restriction.AddItem(RestrictionDesc[i]);
    
    ListProfiles();
    
    i = cb_Profile.FindExtra(class'dw_WeaponsModule'.default.ConfiguredProfileName);
    if (i != -1)
        cb_Profile.SilentSetIndex(i);

    Profile_Change(none);
    ProfileName_Change(none);
    
    bg_Groups.ManageComponent(lb_Groups);
    bg_Weapons.ManageComponent(lb_Weapons);
    bg_AllWeapons.ManageComponent(lb_AllWeapons);
    
    bg_Props.ManageComponent(ch_ExcludeMode);
    bg_Props.ManageComponent(ch_StrictNaming);
    bg_Props.ManageComponent(ed_GroupName);
    bg_Props.ManageComponent(cb_Restriction);
    bg_Props.ManageComponent(ed_Filter);
}

function ListProfiles()
{
    local array<string> names;
    local array<dw_WeaponsProfile> Profiles;
    local int i;
    
    cb_Profile.MyComboBox.Clear();
    
    // get a list of all profiles (including presets)
    names = class'dw_WeaponsProfile'.static.GetProfileNames();
    
    Profiles.Length = names.Length;
    
    for (i = 0; i < names.Length; ++i)
        if (names[i] != "")
        {
            // load each profile
            Profiles[i] = class'dw_WeaponsProfile'.static.GetProfile(names[i]);

            // and add it to the list (showing its Display Name)
            if (Profiles[i] != none)
            {
                if (Profiles[i].IsPreset)
                    cb_Profile.AddItem(PresetPrefix $ Profiles[i].DisplayName, Profiles[i], names[i]);
                else
                    cb_Profile.AddItem(Profiles[i].DisplayName, Profiles[i], names[i]);
            }
        }
    
    // sort alphabetically by Display Name
    cb_Profile.MyComboBox.List.Sort();
}


// Rules are server-authoritative: remote non-admin clients may browse but not edit.
function bool CanEditRules()
{
    local PlayerController PC;

    PC = PlayerOwner();
    if (PC == none || PC.Level.NetMode != NM_Client || PC.PlayerReplicationInfo == none)
        return true;
    return PC.PlayerReplicationInfo.bAdmin;
}

function bool IsLocked(dw_WeaponsProfile P)
{
    return P == none || P.IsPreset || !CanEditRules();
}

function Profile_Change(GUIComponent Sender)
{
    local dw_WeaponsProfile Profile;

    Profile = dw_WeaponsProfile(cb_Profile.GetObject());
    
    // can't rename or delete *preset* profiles
    if (IsLocked(Profile)) {
        btn_DelProfile.DisableMe();
        btn_RenProfile.DisableMe();
    } else {
        btn_DelProfile.EnableMe();
        btn_RenProfile.EnableMe();
    }
    
    if (Profile == none)
    { // no profile selected, disable controls
        ch_ExcludeMode.DisableMe();
        ch_StrictNaming.DisableMe();
        // restriction, filter and groupname are disabled/enabled in Groups_SelectItem().
    }
    else
    { // enable controls (though they may be read-only)
        ch_ExcludeMode.EnableMe();
        ch_StrictNaming.EnableMe();

        // read-only if profile is a preset
        ch_ExcludeMode.SetReadOnly(IsLocked(Profile));
        ch_StrictNaming.SetReadOnly(IsLocked(Profile));
        cb_Restriction.SetReadOnly(IsLocked(Profile));
        ed_Filter.SetReadOnly(IsLocked(Profile));
        ed_GroupName.SetReadOnly(IsLocked(Profile));

        ch_ExcludeMode.SetComponentValue(Profile.bExcludeMode, true);
        ch_StrictNaming.SetComponentValue(Profile.bStrictNaming, true);
    }
    
    UpdateGroups();
    
    Groups_SelectItem(none);
}

function UpdateGroups()
{
    local dw_WeaponsProfile Profile;
    local int i, j, count;

    Profile = dw_WeaponsProfile(cb_Profile.GetObject());
    
    lb_Groups.List.Clear();
    
    if (Profile == none)
        return;
    
    for (j = 0; j < ArrayCount(RestrictionDesc); ++j)
    {
        if (Profile.IsPreset)
        { // don't show empty categories if profile is preset
            count = 0;
            for (i = 0; i < Profile.WeaponGroups.Length; ++i)
                if (int(Profile.WeaponGroups[i].Restriction) == j)
                    ++count;
            
            if (count == 0)
                continue;
        }
        
        lb_Groups.List.Add(RestrictionDesc[j],,, true);
        
        for (i = 0; i < Profile.WeaponGroups.Length; ++i)
        {
            // group by restriction
            if (int(Profile.WeaponGroups[i].Restriction) == j)
                lb_Groups.List.Add(Profile.WeaponGroups[i].GroupName,, string(i));
        }
        
        if (!IsLocked(Profile))
            lb_Groups.List.Add(NewGroupItem,, "NEW");
    }
}

function Groups_SelectItem(GUIComponent Sender)
{
    local dw_WeaponsProfile Profile;
    local int i, group, w;
    local string packagename, packagetext, extra;
    
    lb_Weapons.List.Clear();
    lb_AllWeapons.List.Clear();

    Profile = dw_WeaponsProfile(cb_Profile.GetObject());
    
    if (lb_Groups.List.GetExtra() == "" || Profile == none)
    {
        ed_GroupName.DisableMe();
        cb_Restriction.DisableMe();
        ed_Filter.DisableMe();
        return;
    }
    
    cb_Restriction.EnableMe();
    
    ed_Filter.EnableMe();
    ed_Filter.MyEditBox.TextStr = "";
    ed_Filter.MyEditBox.CaretPos = 0;

    ed_GroupName.EnableMe();
    ed_GroupName.MyEditBox.TextStr = "";
    ed_GroupName.MyEditBox.CaretPos = 0;

    if (lb_Groups.List.GetExtra() == "NEW")
    {
        // find last section header before this item
        for (i = lb_Groups.List.Index-1; i > -1; --i)
            if (lb_Groups.List.Elements[i].bSection)
            { // select corresponding restriction type
                w = cb_Restriction.FindIndex(lb_Groups.List.GetItemAtIndex(i));
                if (w != -1)
                    cb_Restriction.SilentSetIndex(w);
                break;
            }
        
        for (w = 0; w < WeaponList.Length; ++w)
        {
            GetPackage(WeaponList[w].ClassName, packagename, packagetext);
            
            extra = packagename $ "." $ GetItemName(WeaponList[w].ClassName);
            
            lb_AllWeapons.List.Add(WeaponList[w].FriendlyName,, extra);
                
            // if no section exists for this package, add one
            if (lb_AllWeapons.List.FindExtra(packagename) == -1)
                lb_AllWeapons.List.Add(packagetext,, packagename, true);
        }
        return;
    }

    group = int(lb_Groups.List.GetExtra());
    if (group < 0 || group >= Profile.WeaponGroups.Length)
        return;

    // silently set text for group name
    ed_GroupName.MyEditBox.TextStr = Profile.WeaponGroups[group].GroupName;
    // and filter
    ed_Filter.MyEditBox.TextStr = Profile.WeaponGroups[group].Filter;
    // and restriction
    cb_Restriction.SilentSetIndex(int(Profile.WeaponGroups[group].Restriction));

    for (i = 0; i < Profile.WeaponGroups[group].Weapons.Length; ++i)
    {
        // find weapon record for this weapon
        w = FindWeapon(string(Profile.WeaponGroups[group].Weapons[i]));
        
        if (w != -1)
        {
            GetPackage(WeaponList[w].ClassName, packagename, packagetext);
            
            // Prefix extra string data (weapon name) with package name, for sort order.
            extra = packagename $ "." $ Profile.WeaponGroups[group].Weapons[i];
            
            lb_Weapons.List.Add(WeaponList[w].FriendlyName,, extra);
        }
        else
        { // add Unknown Package section
            packagename = "--UnknownPackage";
            packagetext = UnknownPackageText;
            
            extra = "--UnknownPackage." $ Profile.WeaponGroups[group].Weapons[i];

            // add weapon
            lb_Weapons.List.Add(string(Profile.WeaponGroups[group].Weapons[i]),, extra);
        }

        // if no section exists for this package, add one
        if (lb_Weapons.List.FindExtra(packagename) == -1)
            lb_Weapons.List.Add(packagetext,, packagename, true);
    }
    
    if (IsLocked(Profile))
        return;
    
    for (w = 0; w < WeaponList.Length; ++w)
    {
        GetPackage(WeaponList[w].ClassName, packagename, packagetext);
        
        extra = GetItemName(WeaponList[w].ClassName);
        
        // Weapon restrictions work by class name.  If this class name is already
        // in the group (even if from a different package), no need to add it.
        for (i = 0; i < lb_Weapons.List.ItemCount; ++i)
            if (GetItemName(lb_Weapons.List.GetExtraAtIndex(i)) ~= extra)
                break;
        if (i < lb_Weapons.List.ItemCount)
            continue;
        
        extra = packagename $ "." $ extra;
        
        lb_AllWeapons.List.Add(WeaponList[w].FriendlyName,, extra);
            
        // if no section exists for this package, add one
        if (lb_AllWeapons.List.FindExtra(packagename) == -1)
            lb_AllWeapons.List.Add(packagetext,, packagename, true);
    }
}

function int FindWeapon(string weaponname)
{
    local int i;
    
    for (i = 0; i < WeaponList.Length; ++i)
        if (GetItemName(WeaponList[i].ClassName) ~= weaponname)
            return i;
    
    return -1;
}

function GetPackage(string classname, out string packagename, out string packagetext)
{
    local int i;
    
    i = InStr(classname, ".");

    if (i < 1)
        packagename = "--UnknownPackage";
    else    
        packagename = Left(classname, i);
    
    if (IsOfficialPackage(packagename))
        packagename = "--OfficialPackage";
    
    switch (packagename)
    {
    case "--UnknownPackage":    packagetext = UnknownPackageText;   break;
    case "--OfficialPackage":   packagetext = OfficialPackageText;  break;
    default:                    packagetext = packagename;          break;
    }
}

function bool IsOfficialPackage(string packageName)
{
    local int i;
    
    for (i = 0; i < OfficialPackages.Length; ++i)
        if (packageName ~= OfficialPackages[i])
            return true;
    
    return false;
}

function ProfileName_Change(GUIComponent Sender)
{
    local dw_WeaponsProfile Profile;
    
    Profile = dw_WeaponsProfile(cb_Profile.GetObject());

    if (Profile != none && !IsLocked(Profile))
    {
        if (ed_ProfileName.GetText() != "")
            btn_RenProfile.EnableMe();
        else
            btn_RenProfile.DisableMe();
    }
    //else: rename button should already be disabled
    
    if (ed_ProfileName.GetText() != "" && CanEditRules())
        btn_AddProfile.EnableMe();
    else
        btn_AddProfile.DisableMe();
}

function bool Button_Click(GUIComponent Sender)
{
    local dw_WeaponsProfile Profile;
    local string profileName;
    local int i;
    
    Profile = dw_WeaponsProfile(cb_Profile.GetObject());
    
    if (Profile == none)
        return true;

    switch (Sender)
    {
    case btn_DelProfile: // delete
        if (!IsLocked(Profile))
        { // add profile to list of profiles pending deletion (must click OK)
            DeletedProfiles[DeletedProfiles.Length] = Profile;
            // remove from list
            cb_Profile.MyComboBox.List.Remove(cb_Profile.GetIndex());
        }
        break;

    case btn_AddProfile: // add
        if (ed_ProfileName.GetText() != "")
        {
            // spaces and ] are illegal
            //profileName = Repl(Repl(ed_ProfileName.GetText(), "]", "}"), " ", "_");

            // Reasons I use predefined names (rather than the text entered):
            //   - Invalid characters can prevent the profile from working
            //   - Renaming doesn't change the real name, only the Display Name
            //     (so name and DisplayName may end up out of sync anyway)
            //   - It is guaranteed to not conflict with the presets I have created
            profileName = "CustomProfile";

            i = 1;        
            // automatically use the next number not in use
            while (class'dw_WeaponsProfile'.static.ProfileExists(profileName $ i) && i < 100)
                ++i;

            if (i < 100)
            {
                profileName = profileName $ i;
            }
            else
            { // OMG! How many f'ing profiles do you need!??!? ;-)
                Controller.OpenMenu("GUI2K4.UT2K4GenericMessageBox", "ERROR", "Failed to create a unique name for the new profile.  Ensure you have less than 100 custom profiles.");
                return true;
            }
           
            // create a new profile
            Profile = class'dw_WeaponsProfile'.static.GetProfile(profileName);

            // use entered text as display name
            Profile.DisplayName = ed_ProfileName.GetText();
			
			// add it to the list
			cb_Profile.AddItem(Profile.DisplayName, Profile, profileName);
			
			// keep the list sorted
			cb_Profile.MyComboBox.List.Sort();
			
			// select new profile
			i = cb_Profile.FindExtra(profileName);
			if (i != -1)
			    cb_Profile.SetIndex(i);
        }
        break;

    case btn_RenProfile: // rename
        if (!IsLocked(Profile) && ed_ProfileName.GetText() != "")
        { // set display name.  real name is not affected.
            Profile.DisplayName = ed_ProfileName.GetText();

            // update display name
            cb_Profile.MyComboBox.List.Replace(cb_Profile.GetIndex(), Profile.DisplayName, Profile, string(Profile.Name));
            
            // keep the list sorted
            cb_Profile.MyComboBox.List.Sort();
        }
        break;
    }
    
    return true;
}

function bool Weapons_DblClick(GUIComponent Sender)
{
    local GUIListBox lbDest;
    
    if (Sender == lb_Weapons)
        lbDest = lb_AllWeapons;
    else
        lbDest = lb_Weapons;

    MoveWeaponItem(GUIListBox(Sender), lbDest);

    return true;
}

// Move the selected item to the opposite list.
function MoveWeaponItem(GUIListBox lbSource, GUIListBox lbDest)
{
    local dw_WeaponsProfile Profile;
    local string item, extra, pkg, pkgtext;
    local int i, j;
    
    if (lbSource.List.Index == -1)
        return;
    
    // get the selected weapon item
    item = lbSource.List.Get();
    extra = lbSource.List.GetExtra();
    
    if (extra == "")
        return;
    
    Profile = dw_WeaponsProfile(cb_Profile.GetObject());

    // ensure an editable profile is selected
    if (IsLocked(Profile))
        return;
    
    if (lb_Groups.List.GetExtra() == "NEW")
    { // create a new group (should be selected automatically)
        CreateGroup(Profile);
    }
    
    // ensure a group is selected
    if (lb_Groups.List.GetExtra() == "" || lb_Groups.List.GetExtra() == "NEW")
        return;
    
    if (InStr(extra, ".") == -1)
    { // double-clicked a package
        pkg = extra $ ".";
        j = Len(pkg);
        pkgtext = item;

        // move all items in this package
        i = lbSource.List.Index+1;
        while (lbSource.List.ItemCount > i)
        {
            extra = lbSource.List.GetExtraAtIndex(i);
            // stop when we get to an item that isn't in the selected package
            if (extra == "" || !(Left(extra, j) ~= pkg))
                break;

            item = lbSource.List.GetItemAtIndex(i);
            
            lbSource.List.Remove(i,, true);
            lbDest.List.Add(item,, extra);
        }
        
        // remove . from package name
        pkg = Left(pkg, j-1);
        // remove package from source list
        CheckForPackage(lbSource, pkg, pkgtext, false);
        // ensure package header is present in destination list
        CheckForPackage(lbDest,   pkg, pkgtext, true );
    }
    else
    { // remove from old list and add to new
        lbSource.List.Remove(lbSource.List.Index,, true);
        lbDest.List.Add(item,, extra);
        
        // get the package for this item
        GetPackage(extra, pkg, pkgtext);
        // remove package from source list if it has no items left
        CheckForPackage(lbSource, pkg, pkgtext, false);
        // ensure package header is present in destination list
        CheckForPackage(lbDest,   pkg, pkgtext, true );
    }
    
    UpdateWeaponList( Profile, int(lb_Groups.List.GetExtra()) );
}

function CheckForPackage(GUIListBox lb, string pkg, string pkgtext, bool shouldexist)
{
    local int idx;
    
    idx = lb.List.FindExtra(pkg);

    if (shouldexist)
    { // if not found, add it
        if (idx == -1)
            lb.List.Add(pkgtext,, pkg, true);
    }
    else if (idx != -1)
    { // if this is the last item, or the next item is a section, remove this item
        if (idx+1 >= lb.List.ItemCount || lb.List.Elements[idx+1].bSection)
            lb.List.Remove(idx,, true);
    }
}

function UpdateWeaponList(dw_WeaponsProfile Profile, int group)
{
    local int i, j;

    if (group < 0 || group >= Profile.WeaponGroups.Length)
        return;
    
    // clear internal weapon list
    Profile.WeaponGroups[group].Weapons.Length = 0;
    
    for (i = 0; i < lb_Weapons.List.ItemCount; ++i)
    {
        if (! lb_Weapons.List.Elements[i].bSection)
        {
            // convert weapon item name (class excluding package) to a name
            SetPropertyText("tempname", GetItemName(lb_Weapons.List.GetExtraAtIndex(i)));
            // add it to the list
            if (tempname != '')
                Profile.WeaponGroups[group].Weapons[j++] = tempname;
        }
    }

    ModifiedProfile(Profile);
}

function CreateGroup(dw_WeaponsProfile Profile)
{
    local int i;
    local string selectedweapon, groupname;
    
    // remember selected weapon
    selectedweapon = lb_AllWeapons.List.GetExtra();

    // add 1 to group array    
    i = Profile.WeaponGroups.Length;
    Profile.WeaponGroups.Length = i+1;

    groupname = ed_GroupName.GetText();
    if (groupname != "")
        Profile.WeaponGroups[i].GroupName = groupname;
    // auto-name (name conflicts may happen, but name has no real function)
    else
        Profile.WeaponGroups[i].GroupName = "group"$(i+1);

    // set restriction type
    Profile.SetRestriction(i, cb_Restriction.GetIndex());

    // insert at selected position
    lb_Groups.List.Insert(lb_Groups.List.Index, Profile.WeaponGroups[i].GroupName,, string(i));
    
    if (groupname != "") // put cursor at end of name (user is probably still typing)
        ed_GroupName.MyEditBox.CaretPos = Len(ed_GroupName.MyEditBox.TextStr);
    else // select all (auto-generated name)
        ed_GroupName.MyEditBox.bAllSelected = true;

    if (selectedweapon != "")
    { // reselect previously selected weapon
        i = lb_AllWeapons.List.FindExtra(selectedweapon);
        if (i != -1)
            lb_AllWeapons.List.SilentSetIndex(i);
    }
}

event Closed(GUIComponent Sender, bool bCancelled)
{
    local int i;
    local dw_WeaponsProfile Profile;
    
    super.Closed(Sender, bCancelled);

    // Remote clients get the server's rules replicated; only the server (or an admin) may save them.
    if (!bCancelled && CanEditRules())
    {
        for (i = 0; i < DeletedProfiles.Length; ++i)
            DeletedProfiles[i].ClearConfig();
            
        for (i = 0; i < cb_Profile.MyComboBox.List.ItemCount; ++i)
        {
            Profile = dw_WeaponsProfile(cb_Profile.MyComboBox.List.GetObjectAtIndex(i));
            if (Profile != none)
                Profile.Save();
        }
        
        if (bForceReloadProfile)
            class'dw_WeaponsModule'.default.bReloadProfile = true;
        class'dw_WeaponsModule'.default.ConfiguredProfileName = cb_Profile.GetExtra();
        class'dw_WeaponsModule'.static.StaticSaveConfig();
    }
    DeletedProfiles.Length = 0;
}

function Property_Change(GUIComponent Sender)
{
    local dw_WeaponsProfile Profile;
    local int group;
    
    Profile = dw_WeaponsProfile(cb_Profile.GetObject());
    if (Profile == none)
        return;
    
    if (Sender == ch_ExcludeMode)
        Profile.bExcludeMode = ch_ExcludeMode.IsChecked();

    else if (Sender == ch_StrictNaming)
        Profile.bStrictNaming = ch_StrictNaming.IsChecked();

    else if (lb_Groups.List.GetExtra() != "")
    {
        if (lb_Groups.List.GetExtra() == "NEW")
        { // create new group
            CreateGroup(Profile);

            if (lb_Groups.List.GetExtra() == "NEW") // jic
                return;
        }

        group = int(lb_Groups.List.GetExtra());
        if (group < 0 || group >= Profile.WeaponGroups.Length)
            return;

        Switch(Sender)
        {
        case ed_GroupName:
            if (ed_GroupName.GetText() != "")
            { // set group name
                Profile.WeaponGroups[group].GroupName = ed_GroupName.GetText();
                // update list item
                lb_Groups.List.SetItemAtIndex(lb_Groups.List.Index, ed_GroupName.GetText());
            }
            break;

        case cb_Restriction:
            if (int(Profile.WeaponGroups[group].Restriction) != cb_Restriction.GetIndex())
            {
                // set restriction
                Profile.SetRestriction(group, cb_Restriction.GetIndex());
                // update groups
                UpdateGroups();
                // reselect group
                lb_Groups.List.SetIndex(lb_Groups.List.FindExtra(string(group)));
                
                // ensure any existing weapons modules know to reload the profile
                ModifiedProfile(Profile);
            }
            break;
        
        case ed_Filter:
            Profile.WeaponGroups[group].Filter = ed_Filter.GetText();
            ModifiedProfile(Profile);
            break;
        }
    }
}

function bool Groups_KeyEvent(out byte Key, out byte State, float delta)
{
    if (Key == 0x2E && State == 1) // delete
    {
        DeleteGroup();
        return true;
    }
    return false;
}

function DeleteGroup()
{
    local dw_WeaponsProfile Profile;
    local int group;
    
    Profile = dw_WeaponsProfile(cb_Profile.GetObject());
    if (IsLocked(Profile))
        return;

    if (lb_Groups.List.GetExtra() == "" || lb_Groups.List.GetExtra() == "NEW")
        return;
    
    group = int(lb_Groups.List.GetExtra());
    if (group < 0 || group >= Profile.WeaponGroups.Length)
        return;
    
    Profile.WeaponGroups.Remove(group, 1);
    
    // update groups
    UpdateGroups();
    
    // ensure any existing weapons modules know to reload the profile
    ModifiedProfile(Profile);
}

event Free()
{
    super.Free();
    
    DeletedProfiles.Length = 0;
    WeaponList.Length = 0;
}

function ModifiedProfile(dw_WeaponsProfile Profile)
{
    if (string(Profile.Name) ~= class'dw_WeaponsModule'.default.ConfiguredProfileName)
        bForceReloadProfile = true;
}

defaultproperties
{
	Begin Object Class=GUISectionBackground Name=GroupsBG
		bFillClient=True
		Caption="Weapon Groups"
		WinTop=0.050000
		WinWidth=0.320000
		WinHeight=0.940000
		OnPreDraw=GroupsBG.InternalPreDraw
	End Object
	bg_Groups=GUISectionBackground'DualWieldV1.dw_WeaponsTab.GroupsBG'

	Begin Object Class=GUISectionBackground Name=WeaponsBG
		bFillClient=True
		Caption="Selected Weapons"
		WinTop=0.400000
		WinLeft=0.330000
		WinWidth=0.320000
		WinHeight=0.590000
		OnPreDraw=WeaponsBG.InternalPreDraw
	End Object
	bg_Weapons=GUISectionBackground'DualWieldV1.dw_WeaponsTab.WeaponsBG'

	Begin Object Class=GUISectionBackground Name=AllWeaponsBG
		bFillClient=True
		Caption="Available Weapons"
		WinTop=0.400000
		WinLeft=0.660000
		WinWidth=0.320000
		WinHeight=0.590000
		OnPreDraw=AllWeaponsBG.InternalPreDraw
	End Object
	bg_AllWeapons=GUISectionBackground'DualWieldV1.dw_WeaponsTab.AllWeaponsBG'

	Begin Object Class=GUISectionBackground Name=PropsBG
		Caption="Options"
		WinTop=0.050000
		WinLeft=0.330000
		WinWidth=0.650000
		WinHeight=0.340000
		OnPreDraw=PropsBG.InternalPreDraw
	End Object
	bg_Props=GUISectionBackground'DualWieldV1.dw_WeaponsTab.PropsBG'

	Begin Object Class=moComboBox Name=ProfileCB
		bReadOnly=True
		Caption="Profile"
		OnCreateComponent=ProfileCB.InternalOnCreateComponent
		Hint="Select a profile to use."
		WinTop=0.007000
		WinLeft=0.000000
		WinWidth=0.320000
		WinHeight=0.040000
		TabOrder=0
		OnChange=dw_WeaponsTab.Profile_Change
	End Object
	cb_Profile=moComboBox'DualWieldV1.dw_WeaponsTab.ProfileCB'

	Begin Object Class=GUIButton Name=DelProfileBtn
		Caption="Del"
		Hint="Delete the current profile."
		WinTop=0.007000
		WinLeft=0.330000
		WinWidth=0.100000
		TabOrder=1
		OnClick=dw_WeaponsTab.Button_Click
		OnKeyEvent=DelProfileBtn.InternalOnKeyEvent
	End Object
	btn_DelProfile=GUIButton'DualWieldV1.dw_WeaponsTab.DelProfileBtn'

	Begin Object Class=GUIButton Name=AddProfileBtn
		Caption="Add"
		Hint="Create a new profile."
		WinTop=0.007000
		WinLeft=0.440000
		WinWidth=0.100000
		TabOrder=2
		OnClick=dw_WeaponsTab.Button_Click
		OnKeyEvent=AddProfileBtn.InternalOnKeyEvent
	End Object
	btn_AddProfile=GUIButton'DualWieldV1.dw_WeaponsTab.AddProfileBtn'

	Begin Object Class=GUIButton Name=RenProfileBtn
		Caption="Rename"
		Hint="Rename the current profile."
		WinTop=0.007000
		WinLeft=0.550000
		WinWidth=0.100000
		TabOrder=3
		OnClick=dw_WeaponsTab.Button_Click
		OnKeyEvent=RenProfileBtn.InternalOnKeyEvent
	End Object
	btn_RenProfile=GUIButton'DualWieldV1.dw_WeaponsTab.RenProfileBtn'

	Begin Object Class=moEditBox Name=ProfileNameEd
		bFlipped=True
		Caption="Name"
		OnCreateComponent=ProfileNameEd.InternalOnCreateComponent
		Hint="Type a name for a new or existing profile."
		WinTop=0.007000
		WinLeft=0.660000
		WinWidth=0.320000
		WinHeight=0.040000
		TabOrder=4
		OnChange=dw_WeaponsTab.ProfileName_Change
	End Object
	ed_ProfileName=moEditBox'DualWieldV1.dw_WeaponsTab.ProfileNameEd'

	Begin Object Class=GUIListBox Name=GroupsLB
		OnCreateComponent=GroupsLB.InternalOnCreateComponent
		Hint="Weapon groups apply restrictions to which weapons can be dual-wielded."
		TabOrder=10
		OnChange=dw_WeaponsTab.Groups_SelectItem
		OnKeyEvent=dw_WeaponsTab.Groups_KeyEvent
	End Object
	lb_Groups=GUIListBox'DualWieldV1.dw_WeaponsTab.GroupsLB'

	Begin Object Class=dw_GUIListBox Name=WeaponsLB
		DefaultListClass="DualWieldV1.dw_GUIList"
		bSorted=True
		OnCreateComponent=WeaponsLB.InternalOnCreateComponent
		Hint="This lists the weapons which are directly affected by the group's restriction."
		TabOrder=20
		OnDblClick=dw_WeaponsTab.Weapons_DblClick
	End Object
	lb_Weapons=dw_GUIListBox'DualWieldV1.dw_WeaponsTab.WeaponsLB'

	Begin Object Class=dw_GUIListBox Name=AllWeaponsLB
		DefaultListClass="DualWieldV1.dw_GUIList"
		bSorted=True
		OnCreateComponent=AllWeaponsLB.InternalOnCreateComponent
		Hint="This lists all weapons available for inserting into the selected group."
		TabOrder=40
		OnDblClick=dw_WeaponsTab.Weapons_DblClick
	End Object
	lb_AllWeapons=dw_GUIListBox'DualWieldV1.dw_WeaponsTab.AllWeaponsLB'

	Begin Object Class=moComboBox Name=RestrictionCB
		bReadOnly=True
		Caption="Restriction"
		OnCreateComponent=RestrictionCB.InternalOnCreateComponent
		Hint="Specifies the restriction to apply to weapons in the selected group."
		TabOrder=33
		OnChange=dw_WeaponsTab.Property_Change
	End Object
	cb_Restriction=moComboBox'DualWieldV1.dw_WeaponsTab.RestrictionCB'

	Begin Object Class=moEditBox Name=FilterEdit
		Caption="Filter"
		OnCreateComponent=FilterEdit.InternalOnCreateComponent
		Hint="Specify an additional criteria for weapons in this group - e.g. bDualMode=True.  =, <, >, and >< (contains) are supported, and can be prefixed with ! (not true)."
		TabOrder=34
		OnChange=dw_WeaponsTab.Property_Change
	End Object
	ed_Filter=moEditBox'DualWieldV1.dw_WeaponsTab.FilterEdit'

	Begin Object Class=moEditBox Name=GroupNameEdit
		Caption="Group Name"
		OnCreateComponent=GroupNameEdit.InternalOnCreateComponent
		Hint="The display name for this group. (Serves no real function.)"
		TabOrder=32
		OnChange=dw_WeaponsTab.Property_Change
	End Object
	ed_GroupName=moEditBox'DualWieldV1.dw_WeaponsTab.GroupNameEdit'

	Begin Object Class=moCheckBox Name=ExcludeModeCheck
		Caption="Exclude Mode"
		OnCreateComponent=ExcludeModeCheck.InternalOnCreateComponent
		Hint="If enabled, weapons are disabled by default - use Allowed and/or Mutually Exclusive groups to allow dual-wielding for specific weapons. (GLOBAL SETTING)"
		TabOrder=30
		OnChange=dw_WeaponsTab.Property_Change
	End Object
	ch_ExcludeMode=moCheckBox'DualWieldV1.dw_WeaponsTab.ExcludeModeCheck'

	Begin Object Class=moCheckBox Name=StrictNamingCheck
		Caption="Strict Naming"
		OnCreateComponent=StrictNamingCheck.InternalOnCreateComponent
		Hint="If enabled, sub-class weapons (e.g. My Custom Shock Rifle) won't automatically be included wherever their base (e.g. Shock Rifle) is included. (GLOBAL SETTING)"
		TabOrder=31
		OnChange=dw_WeaponsTab.Property_Change
	End Object
	ch_StrictNaming=moCheckBox'DualWieldV1.dw_WeaponsTab.StrictNamingCheck'

	RestrictionDesc(0)="Disallowed"
	RestrictionDesc(1)="Mutually Exclusive"
	RestrictionDesc(2)="Allowed"
	PresetPrefix="Preset: "
	NewGroupItem="<New Weapon Group>"
	UnknownPackageText="Unknown Package"
	OfficialPackageText="Official Weapons"
	OfficialPackages(0)="XWeapons"
	OfficialPackages(1)="Onslaught"
	OfficialPackages(2)="OnslaughtFull"
	OfficialPackages(3)="UTClassic"
	PanelCaption="Weapons"
	WinTop=0.150000
	WinHeight=0.740000
}
