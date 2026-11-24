//-----------------------------------------------------------
// Interaction for input to the Dual Weapon
//-----------------------------------------------------------
class dw_DualWieldInteraction extends Interaction
    config(DualWieldClient);

const LeftWeaponAlias = "dw_LeftWeaponControl";
const RightWeaponAlias = "dw_RightWeaponControl";

var bool bDefaultKeys;
var config EInputKey LeftControlKey, RightControlKey;
var config bool bSuppressKeyBindMenu;

var bool bControlLeft, bControlRight;
var bool bLoggedConsoleClamp, bLoggedTick;

var class<dw_DualWeapon> DualWeaponClass;

event Initialized()
{
    local EInputKey key;
    local string tmp;

    bDefaultKeys = true;
    for (key = IK_None; key <= IK_OEMClear; key = EInputKey(key + 1))
    {
        tmp = ViewportOwner.Actor.ConsoleCommand("KEYNAME" @ key);
        tmp = ViewportOwner.Actor.ConsoleCommand("KEYBINDING" @ tmp);

        if (tmp ~= LeftWeaponAlias || tmp ~= RightWeaponAlias)
        {
            // a key is set, don't prompt the user
            bDefaultKeys = false;
            break;
        }
    }
    // if no keys are set, prompt the player to set some (temporary) ones
    if (bDefaultKeys && !bSuppressKeyBindMenu)
        ViewportOwner.Actor.ClientOpenMenu("DualWieldV1.dw_TempKeyBindMenu");
}

function bool KeyEvent(out EInputKey Key, out EInputAction Action, float Delta)
{
    local string tmp;
    local dw_DualWeapon dw;

    if (ViewportOwner.Console != none && (ViewportOwner.Console.bVisible || ViewportOwner.Console.bTyping)
        && Key != ViewportOwner.Console.ConsoleHotKey && Action != IST_Release)
        return true;

    if (ViewportOwner.Actor.Pawn == none)
        return false;
    
    if ((Action == IST_Press) || (Action == IST_Release))
    {
        tmp = ViewportOwner.Actor.ConsoleCommand("KEYNAME" @ Key);
        tmp = ViewportOwner.Actor.ConsoleCommand("KEYBINDING" @ tmp);
        
        Master.bRequireRawJoystick = true;

        if (tmp ~= LeftWeaponAlias || (bDefaultKeys && Key == LeftControlKey))
        {
            if (bControlLeft != (Action == IST_Press))
            {
                bControlLeft = (Action == IST_Press);

                // always notify dual weapon of control-key press/release
                // (even if not currently dual-wielding)
                if (dw == none)
                    dw = DualWeaponClass.static.GetDualWeapon(ViewportOwner.Actor.Pawn, true);

                if (dw != none && dw.M_Control != none) {
                    if (bControlLeft)
                        dw.M_Control.ControlPressed(0);
                    else
                        dw.M_Control.ControlReleased(0);
                }
            }
            return true;
        }
        else if (tmp ~= RightWeaponAlias || (bDefaultKeys && Key == RightControlKey))
        {
            if (bControlRight != (Action == IST_Press))
            {
                bControlRight = (Action == IST_Press);

                if (dw == none)
                    dw = DualWeaponClass.static.GetDualWeapon(ViewportOwner.Actor.Pawn, true);

                if (dw != none && dw.M_Control != none) {
                    if (bControlRight)
                        dw.M_Control.ControlPressed(1);
                    else
                        dw.M_Control.ControlReleased(1);
                }
            }
            return true;
        }
        else
        {
            // notify dual weapon of keypress/release if:
            //  - holding a control key, or
            //  - currently dual-wielding
            dw = DualWeaponClass.static.GetDualWeapon(ViewportOwner.Actor.Pawn, (bControlLeft || bControlRight));
        
            if (dw != none && dw.M_Control != none)
            {
                if (Action == IST_Press)
                    return dw.M_Control.KeyPressed(Key, tmp, bControlLeft, bControlRight);
                else
                    return dw.M_Control.KeyReleased(Key, tmp, bControlLeft, bControlRight);
            }
        }
    }
    return false;
}

event NotifyLevelChange()
{
    // clean up
    Master.RemoveInteraction(self);
}

// Tick() only runs on interactions that set bRequiresTick.
// Keeps movement axes at zero while the console is open, whatever PlayerController class the server uses.
function Tick(float DeltaTime)
{
    local PlayerController PC;

    if (!bLoggedTick)
    {
        bLoggedTick = true;
        Log("DualWieldV1: interaction tick running");
    }
    if (ViewportOwner == none || ViewportOwner.Console == none || ViewportOwner.Actor == none)
        return;
    if (!(ViewportOwner.Console.bVisible || ViewportOwner.Console.bTyping))
        return;

    PC = ViewportOwner.Actor;
    PC.aBaseY = 0;
    PC.aForward = 0;
    PC.aStrafe = 0;
    PC.aUp = 0;

    if (!bLoggedConsoleClamp)
    {
        bLoggedConsoleClamp = true;
        Log("DualWieldV1: console movement clamp active");
    }
}

defaultproperties
{
	bRequiresTick=true
	LeftControlKey=IK_Ctrl
	RightControlKey=IK_Alt
	DualWeaponClass=Class'DualWieldV1.dw_DualWeapon'
}
