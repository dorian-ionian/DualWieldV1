/* Stock LinkAltFire hardcodes XWeapons.LinkProjectile, so a dual-wielded copy's
   ball would never reach TitanRPG's projectile. RPGProjectileName (DualWieldV1.ini)
   names TitanRPG's projectile, e.g. TitanRPG_DorianV1.RPGLinkProjectile. It is a
   string, so this package needs no compile-time link to TitanRPG. Empty = stock.
 */
class dw_LinkAltFire extends LinkAltFire config(DualWieldV1);

var config string RPGProjectileName;
var class<LinkProjectile> RPGProjectileClass;
var bool bRPGProjectileLoaded;

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local LinkProjectile Proj;

    if ( !bRPGProjectileLoaded )
    {
        bRPGProjectileLoaded = true;
        if ( RPGProjectileName != "" )
            RPGProjectileClass = class<LinkProjectile>(DynamicLoadObject(RPGProjectileName, class'Class'));
    }
    if ( RPGProjectileClass == None )
        return Super.SpawnProjectile(Start, Dir);

    Start += Vector(Dir) * 10.0 * LinkGun(Weapon).Links;
    Proj = Weapon.Spawn(RPGProjectileClass,,, Start, Dir);
    if ( Proj != None )
    {
        Proj.Links = LinkGun(Weapon).Links;
        Proj.LinkAdjust();
    }
    return Proj;
}
