//-----------------------------------------------------------
// Dummy weapon, used to hook WeaponLocker pickups
//-----------------------------------------------------------
class dw_DummyWeapon extends Weapon
    abstract
    CacheExempt
    HideDropDown;

defaultproperties
{
	PickupClass=Class'Engine.WeaponPickup'
}
