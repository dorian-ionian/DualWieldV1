/* DualWield.dw_WPMinigunOnly
   TEMP TEST PRESET: only the Minigun may be dual-wielded.
   Defined in defaultproperties because nested arrays inside config structs
   (WeaponGroups.Weapons) do not load from DualWieldV1.ini.
 */
class dw_WPMinigunOnly extends dw_WeaponsProfile;

defaultproperties
{
	WeaponGroups(0)=(GroupName="Minigun Only",Restriction=WR_Allowed,Weapons=("Minigun"))
	bExcludeMode=True
	bStrictNaming=False
	IsPreset=True
	PresetName="MinigunOnly"
	DisplayName="MinigunOnly"
}
