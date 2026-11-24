/* DualWield.dw_WPDefault
 */
class dw_WPDefault extends dw_WeaponsProfile;

defaultproperties
{
	WeaponGroups(0)=(GroupName="Disabled",Weapons=("Translauncher","Painter"))
	WeaponGroups(1)=(GroupName="Dual Weapons",Weapons=("AssaultRifle","CPP","Enforcer"),filter="bDualMode=True")
	IsPreset=True
	PresetName="Default"
	DisplayName="Default"
}
