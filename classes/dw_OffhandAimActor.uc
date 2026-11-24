//-----------------------------------------------------------
// Actor for pointing the player's left arm in the right
// direction while dual-wielding.  Used by dw_DualWeapon.
//-----------------------------------------------------------
class dw_OffhandAimActor extends dw_ActorBase;

var Actor OffhandActor;
var float OffhandYawOffset;
var float AimAlpha;

replication
{
    reliable if (bNetInitial && Role == ROLE_Authority)
        OffhandActor;
}

function InitFor(Actor offhand)
{
    OffhandActor = offhand;
}

simulated function Tick(float dt)
{
    local rotator newRot;

    // do stuff for third-person weapon in left hand
    if (OffhandActor != none)
    {
        // hack to hide (3rd-person) left-hand weapon when right-hand one is hidden:
        // (for vehicle games - to hide left-hand weapon when you get in a vehicle)
        if (xWeaponAttachment(OffhandActor) != none
            && xPawn(Instigator) != none && xPawn(Instigator).WeaponAttachment != none
            && xPawn(Instigator).WeaponAttachment.bHidden != OffhandActor.bHidden)
            xWeaponAttachment(OffhandActor).Hide(xPawn(Instigator).WeaponAttachment.bHidden);

        AimAlpha = AimAlpha * (1 - 2 * dt);

        Instigator = OffhandActor.Instigator;

        // point in firing direction
        if ( Instigator != None )
        {
            newRot = Instigator.Rotation;
            if ( AimAlpha < 0.5 )
                newRot.Yaw += 4500 * (1 - 2*AimAlpha) + OffhandYawOffset;
            Instigator.SetBoneDirection('lfarm', newRot,, 1.0, 1);

            newRot.Roll += 32768;
            Instigator.SetBoneDirection(OffhandActor.AttachmentBone, newRot,, 1.0, 1);
        }
    }
    else if (Role == ROLE_Authority)
        Destroy();
}

simulated function Destroyed()
{
    if (Instigator != none && OffhandActor != none)
    {
        Instigator.SetBoneDirection(OffhandActor.AttachmentBone, OffhandActor.Rotation,, 0, 0);
        Instigator.SetBoneDirection('lfarm', OffhandActor.Rotation,, 0, 0);
    }
}

defaultproperties
{
	OffhandYawOffset=-2000.000000
	bAlwaysRelevant=True
	bReplicateMovement=False
	bOnlyDirtyReplication=True
	RemoteRole=ROLE_SimulatedProxy
}
