//-----------------------------------------------------------
// LinkBeamEffect class for compatibility with Dual Wielding
// (much more likely to attach itself to the correct weapon)
//-----------------------------------------------------------
class dw_LinkBeamEffect extends LinkBeamEffect;

var Weapon ownerWeapon;

var const class<dw_DualWeapon> DualWeaponClass;

simulated function SetBeamLocation()
{
    local xWeaponAttachment Attachment;

    if ( Level.NetMode == NM_DedicatedServer )
    {
        StartEffect = Instigator.Location + Instigator.EyeHeight*Vect(0,0,1);
        SetLocation( StartEffect );
        return;
    }

    if ( Instigator == None )
    {
        SetLocation( StartEffect );
    }
    else
    {
        if ( Instigator.IsFirstPerson() )
        {
            if ( (Instigator.Weapon == None) || Instigator.Weapon.WeaponCentered() || (Instigator.Weapon.Instigator == None) )
                SetLocation( Instigator.Location );
            else
            {
                if (ownerWeapon == none)
                    ownerWeapon = GetOwnerWeapon();
                SetLocation(ownerWeapon.GetEffectStart() - 60 * vector(Instigator.Controller.Rotation));
            }
        }
        else
        {
            Attachment = GetWeaponAttachment();
            if ( Attachment != None && (Level.TimeSeconds - Attachment.LastRenderTime) < 1 )
                SetLocation( Attachment.GetTipLocation() );
            else
                SetLocation( Instigator.Location + Normal(EndEffect - Instigator.Location) * 25.0 );
        }
        if ( Role == ROLE_Authority ) // what clients will use if their instigator is not relevant yet
            StartEffect = Location;
    }
}

simulated function Weapon GetOwnerWeapon()
{
    local dw_DualWeapon dw;
    local WeaponFire linkMode;
    local int i, j;

    if (Instigator == none)
        return none;

    dw = DualWeaponClass.static.GetDualWeapon(Instigator);

    if (dw != none)
    {
        for (i = 0; i < 2; i++)
        {
            if (dw.Weapons[i] == none)
                continue;

            if (i == 0)
                j = 1;
            else
                j = 0;

            linkMode = dw.GetSubWeaponFireMode(i, 'LinkFire');
            // if sub-weapon [i] has a LinkFire mode,
            if (LinkFire(linkMode) != none
                // with the expected BeamEffectClass
                && LinkFire(linkMode).BeamEffectClass == Class
                // and it is possibly creating a beam (self)
                && ((linkMode.bIsFiring && LinkFire(linkMode).Beam == none)
                // or it already owns self
                 || (LinkFire(linkMode).Beam == self)
                // or the other sub-weapon doesn't have a LinkFire mode
                 || (LinkFire(dw.GetSubWeaponFireMode(j, 'LinkFire')) == none)))
                 // return sub-weapon [i]
                 return dw.Weapons[i];
        }
    }

    // revert to default behaviour
    return Instigator.Weapon;
}

simulated function xWeaponAttachment GetWeaponAttachment()
{
    if (ownerWeapon == none)
        ownerWeapon == GetOwnerWeapon();

    if (ownerWeapon != none && xWeaponAttachment(ownerWeapon.ThirdPersonActor) != none)
        return xWeaponAttachment(ownerWeapon.ThirdPersonActor);

    return xPawn(Instigator).WeaponAttachment;
}

defaultproperties
{
	DualWeaponClass=Class'DualWieldV1.dw_DualWeapon'
}
