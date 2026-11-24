//-----------------------------------------------------------
// Give each player a dual-wielding weapon shell.
//-----------------------------------------------------------
class MutDualWield extends Mutator
    config(DualWieldV1);

var config bool   bEncourageBotDualing,
                  bDisableDualARs,
                  bAllowAkimbo;

var bool bInitialized;
var class<dw_DualWeapon> DualWeaponClass;

var class<dw_DualWeapon> NewDualWeaponClass;

replication
{
    reliable if (bNetDirty && Role == ROLE_Authority)
        NewDualWeaponClass, bAllowAkimbo, bDisableDualARs, bEncourageBotDualing;
}

function PostBeginPlay()
{
    local GameRulesDualWield rules;
    
    rules = Spawn(class'GameRulesDualWield');
    rules.Master = self;

    // Prepend, not append: TitanRPG's RPGRules returns early on weapon
    // pickups without calling Super, so it must not run before this rule.
    rules.NextGameRules = Level.Game.GameRulesModifiers;
    Level.Game.GameRulesModifiers = rules;

    if (!bInitialized)
        Initialize();
}

function Initialize()
{
    DualWeaponClass = class'dw_DualWeapon';
    DualWeaponClass.static.MutatorInitialized(self);
    bInitialized = true;
    NewDualWeaponClass = DualWeaponClass;
}

simulated function PostNetReceive()
{
    if (!bInitialized && NewDualWeaponClass != none)
    {
        DualWeaponClass = NewDualWeaponClass;
        bInitialized = true;
        bNetNotify = false;
    }
}

function ModifyPlayer(Pawn Other)
{
    super.ModifyPlayer(Other);

    if (!bInitialized)
        Initialize();

    DualWeaponClass.static.GiveDualWeapon(Other, Level.Game.BaseMutator);
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local int w;

    if (Weapon(Other) != none)
    {
        // server-side settings are set here
        // client-side settings are set in dw_DualWeapon.PostBeginPlay()
        if (dw_DualWeapon(Other) != none)
        {
            dw_DualWeapon(Other).bEncourageBotDualing = bEncourageBotDualing;
        }
        else if (bAllowAkimbo && DualWeaponClass == default.DualWeaponClass)
        {
            // call me lazy, but I don't want to manually synchronize the ammo charges
            EnableAmmoInstances(Weapon(Other));
        }
    }
    else if (WeaponLocker(Other) != none)
    {
        // replace link gun with dual-wieldable (fully linking) link gun
        for (w = 0; w < WeaponLocker(Other).Weapons.Length; ++w)
            if (WeaponLocker(Other).Weapons[w].WeaponClass == class'LinkGun')
                WeaponLocker(Other).Weapons[w].WeaponClass = class'dw_LinkGun';

        if (bAllowAkimbo)
            AddWeaponLockerHook(WeaponLocker(Other));
    }
    else if (xWeaponBase(Other) != none)
    {
        // replace link gun with dual-wieldable (fully linking) link gun
        if (xWeaponBase(Other).WeaponType == class'LinkGun')
            xWeaponBase(Other).WeaponType = class'dw_LinkGun';
    }
    else if (Ammunition(Other) != none)
    {
        Spawn(class'dw_AmmoSync', Other);
    }
    return true;
}

function string GetInventoryClassOverride(string InventoryClassName)
{
    InventoryClassName = super.GetInventoryClassOverride(InventoryClassName);

    if (InventoryClassName ~= "XWeapons.LinkGun")
        return "DualWieldV1.dw_LinkGun";
}

// adds a dw_DualWeapon to the weapon locker, as a hook
// to allow pick-up of weapons the player already has.
// (WeaponLocker only calls PickupQuery if the player doesn't
//  own the weapon already)
function AddWeaponLockerHook(WeaponLocker L)
{
    local WeaponLocker.WeaponEntry weap;

    // GameRulesDualWield prevents the dw_DummyWeapon from
    // actually being given to the player
    weap.WeaponClass = class'dw_DummyWeapon';

    L.Weapons[L.Weapons.Length] = weap;
}

function EnableAmmoInstances(Weapon w)
{
    local dw_AmmoInstanceActor aia;

    // RemoteStrikeWeapons use AmmoCharge reguardless of bNoAmmoInstances,
    // so enabling ammo instances for them gives them infinite ammo
    if (w.IsA('RemoteStrikeWeapon'))
        return;

    w.bNoAmmoInstances = false;

    if (Level.NetMode != NM_Standalone)
    {
        // bNoAmmoInstances is not replicated, so to set it client-side...
        aia = Spawn(class'dw_AmmoInstanceActor', w);
        aia.AmmoInstanceWeapon = w;
    }
}

simulated function Tick(float DeltaTime)
{
    local PlayerController PC;

    if (Level.NetMode == NM_DedicatedServer)
    {
        Disable('Tick');
        return;
    }

    PC = Level.GetLocalPlayerController();

    if (PC != none)
    {
        if (!bInitialized)
        {
            if (Role < ROLE_Authority)
                return; // wait until DualWeaponClass is received
            Initialize(); // determine the correct DualWeaponClass
        }
        Disable('Tick');
    }
}

function Mutate(string MutateString, PlayerController Sender)
{
    super.Mutate(MutateString, Sender);

    if (Left(MutateString, 12) ~= "DualWieldSet")
    {
        if (Sender.PlayerReplicationInfo.bAdmin || Level.Game.AccessControl.IsAdmin(Sender))
            SetRules(Mid(MutateString, 12));
    }
}

// Flags: three characters, '1' or '0', for bAllowAkimbo, bDisableDualARs, bEncourageBotDualing.
// Saved to the server's config and replicated to every client.
function SetRules(string flags)
{
    bAllowAkimbo         = Mid(flags, 0, 1) == "1";
    bDisableDualARs      = Mid(flags, 1, 1) == "1";
    bEncourageBotDualing = Mid(flags, 2, 1) == "1";

    default.bAllowAkimbo         = bAllowAkimbo;
    default.bDisableDualARs      = bDisableDualARs;
    default.bEncourageBotDualing = bEncourageBotDualing;
    StaticSaveConfig();
}

defaultproperties
{
	DualWeaponClass=Class'DualWieldV1.dw_DualWeapon'
	bAddToServerPackages=True
	ConfigMenuClassName="DualWieldV1.dw_SettingsPage"
	FriendlyName="Dual Wielding"
	Description="Gives each player the Dual Weapon, allowing them to dual-wield (nearly) any two weapons."
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
	bNetNotify=True
}
