//-----------------------------------------------------------
// GameRules for DualWieldV1.MutDualWield
//-----------------------------------------------------------
class GameRulesDualWield extends GameRules;

var MutDualWield Master;

function bool OverridePickupQuery(Pawn Other, Pickup item, out byte bAllowPickup)
{
    local Inventory inv;
    local dw_DualWeapon dw;

    // Run before the rest of the chain (e.g. TitanRPG), which would otherwise
    // take over weapon pickups and skip the akimbo handling below.
    if (Master != none && item != none
        && ClassIsChildOf(item.InventoryType, class'Weapon'))
    {
        if (item.InventoryType == class'dw_DummyWeapon') // hook for WeaponLockers
        {
            if (Master.bAllowAkimbo && item.IsA('WeaponLocker'))
            {
                dw = Master.DualWeaponClass.static.GetDualWeapon(Other, true);
                if (dw != none)
                    dw.CheckAkimboLocker(WeaponLocker(item));
            }
            bAllowPickup = 0;
            return true;
        }

        if (Master.bAllowAkimbo && !item.IsA('RPGWeaponPickup'))
        {
            inv = Other.FindInventoryType(item.InventoryType);
            if (inv != none && inv.Class == item.InventoryType)
            {
                dw = Master.DualWeaponClass.static.GetDualWeapon(Other, true);
                if (dw != none && dw.CheckAkimboPickup(item))
                {
                    // DualWeaponClass handles simulating pick-up
                    bAllowPickup = 0;
                    return true;
                }
            }
        }

        if (Master.bDisableDualARs && item != none
            && (ClassIsChildOf(item.InventoryType, class'AssaultRifle')
             || IsCustomDualWeapon(item.InventoryType)))
        {
            if (WeaponPickup(item) != none)
            {
                inv = Master.DualWeaponClass.static.FindInventory(Other, item.InventoryType);
                if (inv != none && inv.Class == item.InventoryType
                    && !WeaponPickup(item).AllowRepeatPickup())
                {
                    bAllowPickup = 0;
                    return true;
                }
            }
        }
    }

    return super.OverridePickupQuery(Other, item, bAllowPickup);
}

function bool IsCustomDualWeapon(class<Inventory> invType)
{
    local string typeName;

    typeName = string(invType);

    if (typeName ~= "ChaosUT.CPP")
        return true;
    if (typeName ~= "Enforcer.Enforcer")
        return true;

    return false;
}

defaultproperties
{
}
