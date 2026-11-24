/* DualWield.dw_ControlModule
 */
class dw_ControlModule extends dw_Module config(DualWieldClient);

var config bool
    bSingleButtonMode,      // affects which control module class is used by dw_DualWeapon
    bEnableFireSetMode,     // control+(alt)fire = toggle/set fire-mode
    bEnableControlSetMode,  // control = toggle fire-mode (2button mode only)
    bEnableWeaponSwitch,    // control+weaponswitch command = sub-weapon switch
    bEnableQuickZoom,       // control+(alt)fire = zoom (overrides FireSetMode)
    bEnableMouseBestWeapon, // control+MiddleMouse = sub-weapon switch to best
    bEnableThrowWeapon,     // control+ThrowWeapon = throw sub-weapon
    bEnableCustomCommands;  // third-party mod support (for commands built into weapons)

var config array<string> SubWeaponCommands;

function ControlPressed(int hand);
function ControlReleased(int hand);

function bool KeyPressed(Interactions.EInputKey Key, string keybind, bool bControlLeft, bool bControlRight)  { return false; }
function bool KeyReleased(Interactions.EInputKey Key, string keybind, bool bControlLeft, bool bControlRight) { return false; }

simulated function ReloadConfig()
{
    bEnableFireSetMode      = default.bEnableFireSetMode;
    bEnableControlSetMode   = default.bEnableControlSetMode;
    bEnableWeaponSwitch     = default.bEnableWeaponSwitch;
    bEnableQuickZoom        = default.bEnableQuickZoom;
    bEnableMouseBestWeapon  = default.bEnableMouseBestWeapon;
    bEnableThrowWeapon      = default.bEnableThrowWeapon;
    bEnableCustomCommands   = default.bEnableCustomCommands;
    
    SubWeaponCommands       = default.SubWeaponCommands;
}

defaultproperties
{
	bEnableFireSetMode=True
	bEnableControlSetMode=True
	bEnableWeaponSwitch=True
	bEnableQuickZoom=True
	bEnableMouseBestWeapon=True
	bEnableThrowWeapon=True
	bEnableCustomCommands=True
	SubWeaponCommands(0)="ReloadMeNow"
	SubWeaponCommands(1)="ChaosWeaponOption"
	SubWeaponCommands(2)="ChangeAmmo"
	SubWeaponCommands(3)="Reload"
	SubWeaponCommands(4)="SwitchWeaponMode"
	SubWeaponCommands(5)="WeaponSpecial"
	SubWeaponCommands(6)="ToggleLight"
	SubWeaponCommands(7)="ToggleTargeter"
	SubWeaponCommands(8)="CombatZoom"
	RemoteRole=ROLE_None
	bNotOnDedServer=True
}
