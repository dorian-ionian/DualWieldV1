/* DualWield.dw_AmmoSync
 *  Synchronizes AmmoCharge with AmmoAmount of Ammunition object;
 *  subclass used to get around a problem with the v3369 Link Gun.
 *  (Only necessary if "Allow Akimbo Weapons" is enabled,
 *   as it enables ammo instaces : bNoAmmoInstances = false)
 */
class dw_AmmoSync extends dw_ActorBase;

var Ammunition Ammo;
var int        AmmoIndex;
var dw_DualWeapon DW;

function Tick(float dt)
{
    local Inventory inv;
    
    Ammo = Ammunition(Owner);
    if (Ammo == none)
    {
        Destroy();
        return;
    }

    if (Pawn(Ammo.Owner) == none)
    {
        if (Ammo.Instigator == none)
            return;
        inv = Ammo.Instigator.Inventory;
    }
    else
        inv = Ammo.Owner.Inventory;
    
    //for ( ; inv != none; inv = inv.Inventory)
    while (inv != none)
    {
        if (DW == none && dw_DualWeapon(inv) != none)
            DW = dw_DualWeapon(inv);

        if (Weapon(inv) != none && Weapon(inv).GetAmmoClass(AmmoIndex) == Ammo.Class)
        {
            // if bNoAmmoInstances == false, AmmoAmount() returns the AmmoAmount
            // from the ammo instace, which is not synchronized with the AmmoCharge.
            Weapon(inv).AmmoCharge[AmmoIndex] = Weapon(inv).AmmoAmount(AmmoIndex);
        }
        
        inv = inv.Inventory;
    }
    
    // check akimbo inventory chain also!
    if (DW != none && dw_WeaponsModuleDefault(DW.M_Weapons) != none)
        for (inv = dw_WeaponsModuleDefault(DW.M_Weapons).DuplicateList; inv != none; inv = inv.Inventory)
        {
            if (Weapon(inv) != none && Weapon(inv).GetAmmoClass(AmmoIndex) == Ammo.Class)
                Weapon(inv).AmmoCharge[AmmoIndex] = Weapon(inv).AmmoAmount(AmmoIndex);
        }
}

defaultproperties
{
	RemoteRole=ROLE_None
}
