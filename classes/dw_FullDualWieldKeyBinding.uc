/* DualWield.dw_FullDualWieldKeyBinding
 */
class dw_FullDualWieldKeyBinding extends GUIUserKeyBinding;

defaultproperties
{
	KeyData(0)=(KeyLabel="Main Controls",bIsSection=True)
	KeyData(1)=(Alias="dw_LeftWeaponControl",KeyLabel="Control Left Weapon")
	KeyData(2)=(Alias="dw_RightWeaponControl",KeyLabel="Control Right Weapon")
	KeyData(3)=(KeyLabel="Firing: Extra",bIsSection=True)
	KeyData(4)=(Alias="dw_ExtraFireLeft",KeyLabel="Left Alternate Fire")
	KeyData(5)=(Alias="dw_ExtraFireRight",KeyLabel="Right Alternate Fire")
	KeyData(6)=(KeyLabel="Firing: Optional",bIsSection=True)
	KeyData(7)=(Alias="SwitchFireMode",KeyLabel="Toggle Both Fire-Modes")
	KeyData(8)=(Alias="SwitchFireMode left",KeyLabel="Toggle Left Fire-Mode")
	KeyData(9)=(Alias="SwitchFireMode right",KeyLabel="Toggle Right Fire-Mode")
	KeyData(10)=(KeyLabel="Weapon-Switching: Optional",bIsSection=True)
	KeyData(11)=(Alias="NextSubWeapon left",KeyLabel="Next Weapon (Left)")
	KeyData(12)=(Alias="NextSubWeapon right",KeyLabel="Next Weapon (Right)")
	KeyData(13)=(Alias="PrevSubWeapon left",KeyLabel="Prev Weapon (Left)")
	KeyData(14)=(Alias="PrevSubWeapon right",KeyLabel="Prev Weapon (Right)")
	KeyData(15)=(Alias="SwitchToBest",KeyLabel="Best Weapons")
	KeyData(16)=(KeyLabel="HUD",bIsSection=True)
	KeyData(17)=(Alias="SwitchAmmoDisplay",KeyLabel="Switch Ammo Display")
	KeyData(18)=(KeyLabel="Config",bIsSection=True)
	KeyData(19)=(Alias="Mutate DualWieldConfig",KeyLabel="Open Config In-Game")
}
