/* DualWield.dw_Module
 */
class dw_Module extends dw_ActorBase;

var  dw_DualWeapon  DW;
var  dw_Module      NextModule;

// Called when player has configured options in-game and wants them to take effect.
simulated function ReloadConfig();

simulated function PostNetBeginPlay()
{
    DW = dw_DualWeapon(Owner);

    if (DW != none)
    { // insert self at beginning of linked-list of modules
        NextModule = DW.ModuleList;
        DW.ModuleList = self;    
        
        if (Instigator == none)
            Instigator = Pawn(DW.Owner);
    }
}

simulated function Destroyed()
{
    local dw_Module mod;

    // remove self from Module List
    // (so as not to sever next module)
    if (DW != none && NextModule != none)
    {
        if (DW.ModuleList == self)
            DW.ModuleList = NextModule;
        else
        {
            for (mod = DW.ModuleList; mod != none; mod = mod.NextModule)
                if (mod.NextModule == self) {
                    mod.NextModule = NextModule;
                    break;
                }
        }
    }
}

// NOTE: These 'events' will never get called by native code-
//       they directly correspond to a conceptual or actual 'event'
//       occurring in the dw_DualWeapon (master).

simulated event Master_BringUp(optional Weapon PrevWeapon);
simulated event Master_WeaponTick(float dt);
simulated event Master_ChangedSubWeapon(int hand);  // called if one hand changed
simulated event Master_ChangedSubWeapons();         // called if both hands changed
simulated event Master_RenderOverlays(Canvas Canvas);

defaultproperties
{
	bOnlyRelevantToOwner=True
	bAlwaysRelevant=True
	bReplicateMovement=False
	bOnlyDirtyReplication=True
	RemoteRole=ROLE_SimulatedProxy
}
