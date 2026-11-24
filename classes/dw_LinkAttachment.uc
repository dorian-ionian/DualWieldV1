//-----------------------------------------------------------
// Link Attachment used to prevent accessed nones.
//-----------------------------------------------------------
class dw_LinkAttachment extends LinkAttachment;

var LinkGun gun;

simulated function UpdateLinkColor()
{
    // !! original code didn't check if Instigator.Weapon.IsA('LinkGun') !!
    //if ( Instigator != None && Instigator.Weapon != None )
    //  LinkGun(Instigator.Weapon).UpdateLinkColor( LinkColor );
    if ( gun != none )
        gun.UpdateLinkColor( LinkColor );

    if ( MuzFlash != None )
    {
        switch ( LinkColor )
        {
            case LC_Gold    : MuzFlash.Skins[0] = FinalBlend'XEffectMat.LinkMuzProjYellowFB';   break;
            case LC_Green   :
            default         : MuzFlash.Skins[0] = FinalBlend'XEffectMat.LinkMuzProjGreenFB';    break;
        }
    }
}

function InitFor(Inventory I)
{
    super.InitFor(I);

    gun = LinkGun(I);
}

defaultproperties
{
}
