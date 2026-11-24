/* DualWield.dw_LinkGun
 */
class dw_LinkGun extends LinkGun
    HideDropDown CacheExempt;

simulated function bool StartFire(int Mode)
{
	local SquadAI S;
	local Bot B;
	local vector AimDir;
	local LinkGun LG;

	if ( (Role == ROLE_Authority) && (PlayerController(Instigator.Controller) != None) && (UnrealTeamInfo(Instigator.PlayerReplicationInfo.Team) != None))
	{
		S = UnrealTeamInfo(Instigator.PlayerReplicationInfo.Team).AI.GetSquadLedBy(Instigator.Controller);
		if ( S != None )
		{
			AimDir = vector(Instigator.Controller.Rotation);
			for ( B=S.SquadMembers; B!=None; B=B.NextSquadMember )
				if ( (HoldSpot(B.GoalScript) == None) && (B.Pawn != None) )
				{
				    LG = GetLinkGun(B.Pawn);
				    if (LG != none
				        && LG.FocusOnLeader(true)
    					&& ((AimDir dot Normal(B.Pawn.Location - Instigator.Location)) < 0.9) )
    				{
    					B.Focus = Instigator;
    					B.FireWeaponAt(Instigator);
    				}
				}
		}
	}
	return Super.StartFire(Mode);
}

// AI Interface
function bool FocusOnLeader(bool bLeaderFiring)
{
	local Bot B;
	local Pawn LeaderPawn;
	local Actor Other;
	local vector HitLocation, HitNormal, StartTrace;
	local Vehicle V;

	B = Bot(Instigator.Controller);
	if ( B == None )
		return false;
	if ( PlayerController(B.Squad.SquadLeader) != None )
		LeaderPawn = B.Squad.SquadLeader.Pawn;
	else
	{
		V = B.Squad.GetLinkVehicle(B);
		if ( V != None )
		{
			LeaderPawn = V;
			bLeaderFiring = (LeaderPawn.Health < LeaderPawn.HealthMax) && (V.LinkHealMult > 0)
							&& ((B.Enemy == None) || V.bKeyVehicle);
		}
	}
	if ( LeaderPawn == None )
	{
		LeaderPawn = B.Squad.SquadLeader.Pawn;
		if ( LeaderPawn == None )
			return false;
	}
	if ( !bLeaderFiring && (LeaderPawn.Weapon == None || !LeaderPawn.Weapon.IsFiring()) )
		return false;
	if ( (Vehicle(LeaderPawn) != None)
	    || ((GetLinkGun(LeaderPawn) != None) && ((vector(B.Squad.SquadLeader.Rotation) dot Normal(Instigator.Location - LeaderPawn.Location)) < 0.9)) )
		//|| ((LinkGun(LeaderPawn.Weapon) != None) && ((vector(B.Squad.SquadLeader.Rotation) dot Normal(Instigator.Location - LeaderPawn.Location)) < 0.9)) )
	{
		StartTrace = Instigator.Location + Instigator.EyePosition();
		if ( VSize(LeaderPawn.Location - StartTrace) < LinkFire(FireMode[1]).TraceRange )
		{
			Other = Trace(HitLocation, HitNormal, LeaderPawn.Location, StartTrace, true);
			if ( Other == LeaderPawn )
			{
				B.Focus = Other;
				return true;
			}
		}
	}
	return false;
}

function float GetAIRating()
{
	local Bot B;
	local DestroyableObjective O;
	local Vehicle V;

	B = Bot(Instigator.Controller);
	if ( B == None )
		return AIRating;

	if ( (PlayerController(B.Squad.SquadLeader) != None)
		&& (B.Squad.SquadLeader.Pawn != None)
		&& (GetLinkGun(B.Squad.SquadLeader.Pawn) != None) )
		//&& (LinkGun(B.Squad.SquadLeader.Pawn.Weapon) != None) )
		return 1.2;

	V = B.Squad.GetLinkVehicle(B);
	if ( (V != None)
		&& (VSize(Instigator.Location - V.Location) < 1.5 * LinkFire(FireMode[1]).TraceRange)
		&& (V.Health < V.HealthMax) && (V.LinkHealMult > 0) )
		return 1.2;

	if ( Vehicle(B.RouteGoal) != None && B.Enemy == None && VSize(Instigator.Location - B.RouteGoal.Location) < 1.5 * LinkFire(FireMode[1]).TraceRange
	     && Vehicle(B.RouteGoal).TeamLink(B.GetTeamNum()) )
		return 1.2;

	O = DestroyableObjective(B.Squad.SquadObjective);
	if ( O != None && B.Enemy == None && O.TeamLink(B.GetTeamNum()) && O.Health < O.DamageCapacity
	     && VSize(Instigator.Location - O.Location) < 1.1 * LinkFire(FireMode[1]).TraceRange && B.LineOfSightTo(O) )
		return 1.2;

	return AIRating * FMin(Pawn(Owner).DamageScaling, 1.5);
}

function bool LinkedTo(LinkGun L)
{
	local Pawn Other;
	local LinkGun OtherWeapon, Head;
	local int sanity;

	Head = self;
	while (Head != None && Head.Linking && sanity < 20)
	{
            Other = LinkFire(Head.FireMode[1]).LockedPawn;
            if (Other == None)
                return false;
            else
            {
                //OtherWeapon = LinkGun(Other.Weapon);
                OtherWeapon = GetLinkGun(Other);
                if (OtherWeapon == None)
                    return false;
                else
                    Head = OtherWeapon;
            }
            if (Head == L)
            	return true;

            sanity++;
        }

        return false;
}

function bool ConsumeAmmo(int Mode, float load, optional bool bAmountNeededIsMax)
{
	local Controller C;
	local LinkGun LG;

	if (Linking && LinkFire(FireMode[1]).LockedPawn != None && Vehicle(LinkFire(FireMode[1]).LockedPawn) == None)
		return true;

	if ( mode == 0 )
		bAmountNeededIsMax = true;

	//use ammo from linking teammates
	if (Instigator != None && Instigator.PlayerReplicationInfo != None && Instigator.PlayerReplicationInfo.Team != None)
	{
		for (C = Level.ControllerList; C != None; C = C.NextController)
		{
		    if (C.Pawn == none)
		        continue;

		    LG = GetLinkGun(C.Pawn);
			//if (C.Pawn != None && LinkGun(C.Pawn.Weapon) != None && LinkGun(C.Pawn.Weapon).LinkedTo(self))
		    if (LG != none && LG.LinkedTo(self))
				LG.LinkedConsumeAmmo(Mode, load, bAmountNeededIsMax);
	    }
	}

	return Super.ConsumeAmmo(Mode, load, bAmountNeededIsMax);
}

function LinkGun GetLinkGun(Pawn P)
{
    if (LinkGun(P.Weapon) != none)
        return LinkGun(P.Weapon);
    
    if (dw_DualWeapon(P.Weapon) != none)
    { // dual-wielding,
        if (LinkGun(dw_DualWeapon(P.Weapon).Weapons[1]) != none)
        { // and left weapon is a link gun
            if (LinkGun(dw_DualWeapon(P.Weapon).Weapons[0]) != none)
            { // and right weapon is a link gun,
                // decide by hand (so if we are being dual-wielded, left link -> left link)
                if (dw_DualWeapon(P.Weapon).Weapons[0].Hand == Hand)
                    return LinkGun(dw_DualWeapon(P.Weapon).Weapons[0]);
            }
            // return left weapon
            return LinkGun(dw_DualWeapon(P.Weapon).Weapons[1]);
        }
        else if (LinkGun(dw_DualWeapon(P.Weapon).Weapons[0]) != none)
            return LinkGun(dw_DualWeapon(P.Weapon).Weapons[0]);
    }

    return none;
}

function DropFrom(vector StartLocation)
{    
    // hack to only show regular link gun in stats
    // (saves having to replace all the damage types)
    if (Instigator != none && Instigator.Controller != none
       && Instigator.Controller.LastPawnWeapon == class)
        Instigator.Controller.LastPawnWeapon = class'LinkGun';

    super.DropFrom(StartLocation);
 
    // force game to use Controller.LastPawnWeapon instead of Pawn.Weapon
    // (for "Deaths w/" stats)
    if (!bDeleteMe && (Instigator == none || Instigator.Health <= 0))
        Destroy();
}

defaultproperties
{
	FireModeClass(0)=Class'DualWieldV1.dw_LinkAltFire'
	FireModeClass(1)=Class'DualWieldV1.dw_LinkFire'
	PickupClass=Class'DualWieldV1.dw_LinkGunPickup'
}
