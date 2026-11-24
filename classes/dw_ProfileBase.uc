/* DualWield.dw_ProfileBase
 */
class dw_ProfileBase extends dw_ObjectBase
    config(DualWieldV1)
    PerObjectConfig;

var           const bool   IsPreset;   // set = true if this class is a preset
var protected const string PresetName; // name for preset (each preset should be a seperate sub-class)
var protected const array<class<dw_ProfileBase> >  Presets; // array of preset classes

var config string DisplayName;


event Created()
{
    if (DisplayName == "")
        DisplayName = string(name);
    
    // Ensure presets don't use values from .ini file.
    // (Otherwise server and clients may go out of sync.)
    if (IsPreset)
        Reset();
}

function Save()
{
    if (!IsPreset)
        SaveConfig();
}

function Reset()
{
    ClearConfig();

    // Override to set desired defaults.
}

static function array<string> GetProfileNames()
{
    local array<string> names;
    local int i;

    names = GetPerObjectNames("DualWieldV1", string(default.Class.Name));
    
    if (default.Presets.Length > 0)
    { // insert presets at beginning of list
        names.Insert(0, default.Presets.Length);
        for (i = 0; i < default.Presets.Length; ++i)
            names[i] = default.Presets[i].default.PresetName;
    }
    
    return names;
}

static function bool ProfileIsPreset(string profileName)
{
    local int i;
    
    for (i = 0; i < default.Presets.Length; ++i)
        if (default.Presets[i].default.PresetName ~= profileName)
        { // return preset with this name
            return true;
        }
    
    return false;
}

static function bool ProfileExists(string profileName)
{
    local array<string> names;
    local int i;
    
    // check presets
    for (i = 0; i < default.Presets.Length; ++i)
        if (default.Presets[i].default.PresetName ~= profileName)
            return true;

    names = GetPerObjectNames("DualWieldV1", string(default.Class.Name));
    
    // check custom profiles
    for (i = 0; i < names.Length; ++i)
        if (profileName ~= names[i])
            return true;

    return false;
}

// This should be overridden in sub-classes for type-safety.
protected static function dw_ProfileBase GetProfileBase(string profileName)
{
    local int i;
    
    for (i = 0; i < default.Presets.Length; ++i)
        if (default.Presets[i].default.PresetName ~= profileName)
        { // return preset with this name
            return new(none, default.Presets[i].default.PresetName) default.Presets[i];
        }

    // create/load profile.  if none with this name exist, profile will be empty.
    return new(none, profileName) default.Class;
}

static function ResetAll()
{
    local int i;
    local array<string> names;
    local dw_ProfileBase p;
    
    // get a list of all custom profiles
    names = GetPerObjectNames("DualWieldV1", string(default.Class.Name));
    
    for (i = 0; i < names.Length; ++i)
    { // load and clear/delete each profile
        p = new(none, names[i]) default.Class;
        p.ClearConfig();
    }
}

defaultproperties
{
}
