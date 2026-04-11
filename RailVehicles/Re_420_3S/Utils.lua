--------------------------------------------------------------------------------
-- HILFSFUNKTIONEN
--------------------------------------------------------------------------------
function GetControlValue(name)
    if Call("*:ControlExists", name, 0) then
        return Call("*:GetControlValue", name, 0)
    end
    return nil
end

function SetControlValue(name, value)
    if Call("*:ControlExists", name, 0) then
        Call("*:SetControlValue", name, 0, value)
    end
end

function SetAnimTime(name, value)
    --if Call( "*:ControlExists", name, 0 ) then
        Call( "*:SetTime", name, value );
    --end
end

function lambda(cond, tru, fals)
    if cond then
        return tru
    else
        return fals
    end
end

function SmoothMove(dt, cur, tgt, mul)
    if cur == tgt then
        return cur
    end
    if tgt > cur then
        cur = cur + dt * mul
        if cur > tgt then
            cur = tgt
        end
    else
        cur = cur - dt * mul
        if cur < tgt then
            cur = tgt
        end
    end
    return cur
end

function SmoothMoveEaseOut(dt, cur, tgt, smoothness)
    if math.abs(cur - tgt) < 0.001 then
        return tgt
    end
    local diff = tgt - cur
    cur = cur + diff * smoothness * dt
    if (diff > 0 and cur > tgt) or (diff < 0 and cur < tgt) then
        cur = tgt
    end
    return cur
end
