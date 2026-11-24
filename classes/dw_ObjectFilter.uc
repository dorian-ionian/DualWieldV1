/* DualWield.dw_ObjectFilter:
 *  Utility class for filtering objects based on a filter string.
 *
 *  Filter strings can be in the format:
 *   <property name><operator><test value>
 *
 *  Operators:
 *   =    Case-insensitive string comparison.
 *   ><   Case-insensitive string search.
 *   <    Numerical (float) less than.
 *   >    Numerical (float) greater than.
 *   !    Prefix - reverses the value of any operator.
 *
 *  Also note:
 *   - ';' delimited lists of filters are supported.
 *   - The default ';' delimiter can be overriden.
 *   - If property name is "self", test value will be compared
 *     to the string representation of the object being tested.
 */
class dw_ObjectFilter extends dw_ObjectBase;

const F_EqualTo     = 0x1;
const F_Contains    = 0x2;
const F_GreaterThan = 0x4;
const F_LessThan    = 0x8;
const F_ALL         = 0xF;
const F_NOT         = 0x10;

struct Filter
{
    var string PropName;
    var string PropValue;
    var float  NumValue;
    var int    Type;
};

var array<Filter> Filters;

function Parse(string filterList, optional string delim)
{
    local array<string> items;
    local int i;
    local string A, B;
    local Filter f;

    if (delim == "")
        delim = ";";

    Split(filterList, delim, items);
    
    for (i = 0; i < items.Length; ++i)
    {
        if (Divide(items[i], "=", A, B))
            f.Type = F_EqualTo;
        else if (Divide(items[i], "><", A, B)) {
            f.Type = F_Contains;
            B = Caps(B);
        } else if (Divide(items[i], ">", A, B))
            f.Type = F_GreaterThan;
        else if (Divide(items[i], "<", A, B))
            f.Type = F_LessThan;
        else { // default: string(obj) contains filtertext
            f.Type = F_Contains;
            A = "self";
            B = items[i];
        }
        
        switch (f.Type)
        {
        case F_Contains:
            B = Caps(B); 
            break;
        case F_GreaterThan:
        case F_LessThan:
            f.NumValue = float(B);
        }

        if (Right(A, 1) == "!")
        {
            A = Left(A, Len(A) - 1);
            f.Type = (f.Type | F_NOT);
        }
        
        f.PropName = A;
        f.PropValue = B;
        
        Filters[Filters.Length] = f;
    }
}

function Reset()
{
    Filters.Length = 0;
}

function bool IsMatch(Object obj)
{
    local bool b;
    local int i;
    local string val;

    for (i = 0; i < Filters.Length; ++i)
    {
        if (Filters[i].PropName ~= "self")
            val = string(obj);
        else
            val = GetProperty(obj, Filters[i].PropName);

        switch (Filters[i].Type & F_All)
        {
        case F_EqualTo:
            b = (val ~= Filters[i].PropValue);
            break;
        case F_Contains:
            b = (InStr(Caps(val), Filters[i].PropValue) != -1);
            break;
        case F_GreaterThan:
            b = (float(val) > Filters[i].NumValue);
            break;
        case F_LessThan:
            b = (float(val) < Filters[i].NumValue);
        }
        
        if ((Filters[i].Type & F_NOT) != 0)
            b = ! b;
        
        if (! b)
            return false;
    }
    return true;
}

// Gets a property of an object as text, with array indexing support.
static function string GetProperty(Object obj, string PropName)
{
    if (PropName ~= "self")
        return string(obj);

    if (PropName ~= "state")
        return string(obj.GetStateName());

    if (Right(PropName, 1) == "]")
    { // array support
        return GetIndexedProperty(obj, PropName);
    }

    return obj.GetPropertyText(PropName);
}

// INTERNAL - only use if PropName is in format abc[123]
static function string GetIndexedProperty(Object obj, string PropName)
{
    local int i, j, index;
    local string list;
    
    // get property name and index from "PropName[index]"
    if (! GetIndex(PropName, index))
    {
        return obj.GetPropertyText(PropName);
    }
    
    // get the (list) property
    list = obj.GetPropertyText(PropName);
    
    while (Len(list) > 0 && i <= index)
    {
        j = InStr(list, ",");
        if (j == -1)
        {
            if (i == index)
                return list;
            break;
        }
        
        if (i == index) // found item at index
            return Left(list, j);

        // remove leftmost item and continue
        list = Mid(list, j+1);

        ++i;
    }
    
    return obj.GetPropertyText(PropName);
}

static function bool GetIndex(out string PropName, out int Index)
{
    local int i;
    
    if (Right(PropName, 1) != "]")
        return false;

    i = InStr(PropName, "[");
    if (i == -1)
        return false;
    
    // get property name and index from "PropName[index]"
    Index = int(Mid(PropName, i+1, Len(PropName) - (i+2)));
    PropName = Left(PropName, i);
    return true;
}

function string GetOperatorString(int op)
{
    local string t;

    switch (op & F_All)
    {
    case F_EqualTo:      t = "=";   break;
    case F_Contains:     t = "><";  break;
    case F_GreaterThan:  t = ">";   break;
    case F_LessThan:     t = "<";   break;
    }
    
    if ((op & F_NOT) != 0)
        t = "!" $ t;

    return t;
}

defaultproperties
{
}
