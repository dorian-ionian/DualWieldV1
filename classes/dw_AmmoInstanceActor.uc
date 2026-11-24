//-----------------------------------------------------------
// Actor for setting Weapon.bNoAmmoInstances client-side
// (because it isn't replicated)
//-----------------------------------------------------------
class dw_AmmoInstanceActor extends dw_ActorBase;

var Weapon AmmoInstanceWeapon;

replication
{
    unreliable if (bNetInitial && Role == ROLE_Authority)
        AmmoInstanceWeapon;
}

simulated function PostBeginPlay()
{
    SetTimer(10, false);
}

simulated function Timer()
{
    Destroy();
}

simulated function Tick(float DeltaTime)
{
    if (AmmoInstanceWeapon != none)
    {
        AmmoInstanceWeapon.bNoAmmoInstances = false;

        // destroying on server too early prevents replication to the clients
        if (Role < ROLE_Authority)
            Destroy();
        else
            Disable('Tick');
    }
}

defaultproperties
{
	bNetTemporary=True
	bOnlyRelevantToOwner=True
	bAlwaysRelevant=True
	bReplicateMovement=False
	bSkipActorPropertyReplication=True
	RemoteRole=ROLE_SimulatedProxy
	bGameRelevant=True
}
