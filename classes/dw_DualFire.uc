//-----------------------------------------------------------
// Place-holder fire-mode for when dw_DualWeapon has no
// sub-weapons.
//-----------------------------------------------------------
class dw_DualFire extends WeaponFire;

event ModeDoFire()
{
    // do basically nothing.
    if (Instigator.PendingWeapon != Weapon && Instigator.PendingWeapon != None)
    {
        bIsFiring = false;
        Weapon.PutDown();
    }
}

defaultproperties
{
	bModeExclusive=False
}
