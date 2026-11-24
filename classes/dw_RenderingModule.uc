/* DualWield.dw_RenderingModule
 */
class dw_RenderingModule extends dw_Module config(DualWieldClient);

// how should weapon rendering be handled when DesiredFOV != DefaultFOV (dual-mode only)?
var enum EZoomRenderCondition
{
    ZR_Never, // never render either weapon while DesiredFOV != DefaultFOV
    ZR_AlwaysLeft, // always render left weapon (but not right weapon)
    ZR_AlwaysRight, // always render right weapon (but not left weapon)
    ZR_AlwaysBoth, // always render both weapons
    ZR_FirstSniper // render the first zoom weapon found (and not the other weapon)
} ZoomRenderCondition;

var config bool   bAutoSwitchAmmo;
var config string ZoomRenderString;
var config bool   bDisplayFireModes; // display numbers representing the selected fire modes (under the crosshair)
var config float  WeaponNameFadeTime;

var float WeaponNameTime[2];


simulated function ReloadConfig()
{
    bAutoSwitchAmmo     = default.bAutoSwitchAmmo;
    ZoomRenderString    = default.ZoomRenderString;
    bDisplayFireModes   = default.bDisplayFireModes;
    WeaponNameFadeTime  = default.WeaponNameFadeTime;
    
    DW.bAutoSwitchAmmo  = bAutoSwitchAmmo;

    SetPropertyText("ZoomRenderCondition", ZoomRenderString);
}


simulated function PostBeginPlay()
{
    // client-side options
    SetPropertyText("ZoomRenderCondition", ZoomRenderString);
}

simulated function IncrementZoomRenderCondition()
{
    switch (ZoomRenderCondition)
    {
        case ZR_Never:          ZoomRenderCondition = ZR_AlwaysLeft;    break;
        case ZR_AlwaysLeft:     ZoomRenderCondition = ZR_AlwaysRight;   break;
        case ZR_AlwaysRight:    ZoomRenderCondition = ZR_AlwaysBoth;    break;
        case ZR_AlwaysBoth:     ZoomRenderCondition = ZR_FirstSniper;   break;
        case ZR_FirstSniper:
        default:                ZoomRenderCondition = ZR_Never;         break;
    }
    if (Instigator != none)
        Instigator.ClientMessage("Dual Weapon: Zoom Render Condition = "
            $ GetZoomRenderConditionString(ZoomRenderCondition));
}

simulated function string GetZoomRenderConditionString(EZoomRenderCondition cond)
{
    switch (cond)
    {
        case ZR_Never:          return "never render in zoom";
        case ZR_AlwaysLeft:     return "always render left weapon in zoom";
        case ZR_AlwaysRight:    return "always render right weapon in zoom";
        case ZR_AlwaysBoth:     return "always render both weapons in zoom";
        case ZR_FirstSniper:    return "render first sniper when in zoom";
        default:                return string(cond);
    }
}

defaultproperties
{
	ZoomRenderString="ZR_FirstSniper"
	bDisplayFireModes=True
	WeaponNameFadeTime=2.000000
	RemoteRole=ROLE_None
	bNotOnDedServer=True
}
