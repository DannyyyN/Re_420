--------------------------------------------------------------
--                 NPZ Domino Engine Script                 --
--       Developed by smino's Bombastischer Bublisher       --
--------------------------------------------------------------

function GetControlValue(name)
    if Call( "*:ControlExists", name, 0 ) then
        return Call( "*:GetControlValue", name, 0 );
    end
    return nil;
end

function SetControlValue(name, value)
    if Call( "*:ControlExists", name, 0 ) then
        Call( "*:SetControlValue", name, 0, value );
    end
end

function SetAnimTime(name, value)
    --if Call( "*:ControlExists", name, 0 ) then
        Call( "*:SetTime", name, value );
    --end
end

function ArrayHasValue(array, val)
    for index, value in ipairs(array) do
        if value == val then
            return true
        end
    end
    return false
end

function SmoothMove(dt,cur,tgt,mul) -- Smoothly move from the current to the target <3 norm

    if (cur == tgt) then
        return cur;
    end
  
    if tgt > cur then --If the target is bigger than the current regulator position
  
        cur = cur + (dt * mul ); --Move the current regulator
        if cur > tgt then --If the current regulator is now bigger then we climbed a bit too far.
            cur = tgt;
        end  
      
    elseif tgt < cur then --If the target is bigger than the current regulator position
  
        cur = cur - (dt * mul ); --Move the current regulator
        if cur < tgt then --If the current regulator is now smaller then we fell a bit too far.
            cur = tgt;
        end    
    end
  
    return cur
  end

function LockControl(name, value)
    if Call( "*:ControlExists", name, 0 ) then
        Call( "*:SetControlValue", name, 0, lambda(value, 1, 0) );
    end
end

function NodeVisibility(node, visible)
    Call("ActivateNode", node, lambda(visible, "1", "0"))
end

function LightTurnedOn(node, on)
    Call(node..":Activate", lambda(on, "1", "0"))
end

function SendConsistMessage(name, message, direction)
    return Call("SendConsistMessage", name, message, direction);
end

function timer(tps, max, val, tim, dir)
    if dir then 
        return math.min(val + tps * tim, max);
    else 
        return math.max(val - tps * tim, max);
    end
end

function lambda(cond, tru, fals)
    if cond then return tru else return fals end 
end

FlashingIndicator = {OnTime = 0, OffTime = 0, Timer = 0, On = false, Flashing = false, AmountMode = false, Amount = 0}

function FlashingIndicator:Initialize(onTime, offTime)
    self.OnTime = onTime;
    self.OffTime = offTime;
    self.Timer = 0;
    self.On = false;
    self.Flashing = false;
end

function FlashingIndicator:Update(dt)
    if self.Flashing or self.AmountMode then
        self.Timer = self.Timer - dt;
        if self.Timer <= 0 then
            if self.On then
                self.Timer = self.OffTime;
                self.On = false;
                self.Amount = math.max(0, self.Amount-1);
                self.AmountMode = self.Amount ~= 0;
            else
                self.Timer = self.OnTime;
                self.On = true;
            end
        end
    end
    return lambda(self.On,1,0);
end

function FlashingIndicator:SetActive(active)
    if active then
        self.Timer = self.OnTime;
        self.On = true;
        self.Flashing = false;
    else
        self.Timer = self.OffTime;
        self.On = false;
        self.Flashing = false;
    end
    return lambda(self.On,1,0);
end

function FlashingIndicator:SetFlashing(flashing)
    self.Flashing = flashing;
end

function FlashingIndicator:SetFlashingAmount(amount)
    self.AmountMode = true;
    self.Amount = amount;
    self.Timer = self.OffTime;
    self.On = false;
end

NotchedLeverModes = {MOVINGNOTCH = 1, INNOTCHTIMEOUT = 2, INNOTCH = 3, NORM = 4}
NotchedLever = {Notches = {}, NotchCount = 0, NotchSize= 0.0, MovementSpeed = 1.0, NotchDelay = 0.5, CurrentPos = 0.0, MinPos = 0.0, MaxPos = 1.0, nextlowernotch = 0, nexthighernotch = 1, targetpos = 0.0, mode = NotchedLeverModes.NORM; Timer = {}}

function NotchedLever:Initialise(Notches, NotchSize, MovementSpeed, NotchDelay, CurrentPos, MinPos, MaxPos)
    self.Notches = Notches
    self.NotchCount = table.getn(Notches);
    self.NotchSize = NotchSize
    self.MovementSpeed = MovementSpeed
    self.NotchDelay = NotchDelay
    self.CurrentPos = CurrentPos
    self.targetpos = CurrentPos
    self.MinPos = MinPos
    self.MaxPos = MaxPos
    self.Timer = Timer;

    self.Timer:Initialise(self.NotchDelay)
    for index,v in Notches do -- find next higher notch
        if v > CurrentPos then
            self.nexthighernotch = index
            -- find lower notch from here
            if Notches[index-1] == CurrentPos then
                self.nextlowernotch = math.max(index-1,1) -- correct if not in notch
            else
                self.nextlowernotch = math.max(index-2,1) -- correct if in notch
                self.mode = NotchedLeverModes.INNOTCH
            end
            return
        end
    end
end

function NotchedLever:Update(dt, increase, decrease)
    if self.mode == NotchedLeverModes.MOVINGNOTCH  then -- moving out of notch or into notch
        self.CurrentPos = SmoothMove(dt, self.CurrentPos, self.targetpos, self.MovementSpeed);
        if self.CurrentPos == self.targetpos then
            self.mode = NotchedLeverModes.NORM;
        end
    else -- freely move more or less
        if increase==decrease then
            if self.mode == NotchedLeverModes.INNOTCHTIMEOUT then
                self.mode = NotchedLeverModes.INNOTCH -- degrade it to just being in notch
            end
            SetControlValue("Degub", self.nextlowernotch);
            return self.CurrentPos -- do nothing as either nothing pressed or both pressed
        end
        if self.mode == NotchedLeverModes.INNOTCH then -- if In Notch and Botun is pressed
            if increase and self.CurrentPos >= self.MaxPos-0.01 then
                -- YOU AIN'T EVEN GONNA DO NOTHING if we're trying to push past max lmao
            elseif decrease and self.CurrentPos <= self.MinPos+0.01 then
                -- same as above
            else
                self.mode = NotchedLeverModes.INNOTCHTIMEOUT
                self.Timer:Reset();
            end
        end
        if self.mode == NotchedLeverModes.INNOTCHTIMEOUT then
            if self.Timer:Update(dt) then
                self.mode = NotchedLeverModes.MOVINGNOTCH;
                self.targetpos = self.CurrentPos + lambda(increase, self.NotchSize, self.NotchSize * -1);
                if increase then -- increase lower notch
                    if self.nexthighernotch > 2 then -- we're not in first notch so we can increase this
                        self.nextlowernotch = math.min(self.NotchCount-1, self.nextlowernotch + 1);
                    end
                else -- decrease next higher notch
                    if self.nextlowernotch < self.NotchCount-1 then -- we're not in last notch so we can decrease this
                        self.nexthighernotch = math.max(2, self.nexthighernotch - 1);
                    end
                end
            end
        end
        local curpos = self.CurrentPos;
        if self.mode == NotchedLeverModes.MOVINGNOTCH then
            curpos = SmoothMove(dt, self.CurrentPos, self.targetpos, self.MovementSpeed);
            if curpos >= self.targetpos then
                self.mode = NotchedLeverModes.NORM;
            end
        end
        if self.mode == NotchedLeverModes.NORM then
            curpos = SmoothMove(dt, self.CurrentPos, lambda(increase, self.MaxPos, self.MinPos), self.MovementSpeed);
            if increase then -- if moving up we need to check next higher notch
                if self.Notches[self.nexthighernotch] < curpos then --we hit notch babeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
                    curpos = self.Notches[self.nexthighernotch];
                    self.nexthighernotch = math.min(self.NotchCount, self.nexthighernotch + 1); -- next higher notch index increase
                    self.mode = NotchedLeverModes.INNOTCH
                end
            else
                if self.Notches[self.nextlowernotch] > curpos then --we hit notch babeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
                    curpos = self.Notches[self.nextlowernotch];
                    self.nextlowernotch = math.max(1, self.nextlowernotch - 1); -- next lower notch index decrease
                    self.mode = NotchedLeverModes.INNOTCH
                end
            end
        end
        self.CurrentPos = curpos;
    end
    SetControlValue("Degub", self.nextlowernotch);
    return self.CurrentPos;
end

Timer = {CurrentTime = 0.0, ResetTime = 0.0}

function Timer:Initialise(ResetTime)
    self.CurrentTime = ResetTime;
    self.ResetTime = ResetTime;
end

function Timer:Update(dt)
    self.CurrentTime = math.max(0, self.CurrentTime-dt);
    if self.CurrentTime < 0.01 then
        return true
    end
    return false
end

function Timer:Reset()
    self.CurrentTime = self.ResetTime
end


function LampTest()
    if G_LampTestActive then
        return -- Already running a lamp test
    end
    
    local lamps = {
        "Notlicht_LIT",
        "Hauptschalter_LIT",
        "Pantograph_LIT",
        "Parkstellung_LIT",
        "Zugsammelschiene_LIT",
        "KlimaNotAus_LIT",
        "Fahrgastbeleuchtung_Ein_LIT",
        "Fahrgastbeleuchtung_Aus_LIT",
        "D_LIT",
        "Fuehrerstandbeleuchtung_LIT",
        "Scheibenheizung_LIT",
        "Fussheizung_LIT",
        "HL_Nicht_Durchgaengig_LIT",
        "Ueberbrueckung_Fahrsperre_LIT",
        "Hilfsbetriebsstoerung_LIT",
        "Notruf_WC_LIT",
        "Notlauf_Federung_Steuerwagen_LIT",
        "Tueroeffnung_Rollstuhl_LIT",
        "Notlauf_Luftfederung_Steuerwagen_LIT",
        "Haltanforderung_LIT",
        "Traktionsstoerung_LIT",
        "Quiettierung_LIT",
        "Schleuderbremse_LIT",
        "FSB_Anlegen_LIT",
        "FSB_Loesen_LIT",
        "Bremse_Angelegt_LIT",
        "Bremsprobe_BremseGeloest_LIT",
        "Bremse_Abgesperrt_LIT",
        "Magnetschienenbremse_LIT",
        "TF_L_LIT",
        "TV_LIT",
        "TF_R_LIT",
        "Schiebetritt_LIT",
        "TFS_LIT",
        "Manoever_LIT",
        "ZUBQuittierung_lit",
        "Scheinwerfer_LIT"
    };
    
    -- Turn all lamps on (except Notbremsanforderung)
    for _, lamp in ipairs(lamps) do
        SetControlValue(lamp, 1);
    end
    
    -- Start ZTB indicators (fast blinking for 10 seconds)
    SetControlValue("ZTB_1_lit", 1);
    SetControlValue("ZTB_2_lit", 1);
    SetControlValue("ZTB_3_lit", 1);
    
    -- Set the lamp test as active and reset timers
    G_LampTestActive = true
    G_LampTestTimer = 0
    G_NotbremsTimer = 0
    G_NotbremsBlinkCount = 0
    G_NotbremsBlinkState = true  -- Start with ON state
    G_ZTBBlinkState = true
    G_ZTBBlinkTimer = 0
end

function UpdateLampTest(dt)
    if G_LampTestActive then
        G_LampTestTimer = G_LampTestTimer + dt
        
        -- Activate GSM-R_lit at 2 seconds and keep it on
        if G_LampTestTimer >= 2.0 and not G_GSMR_Active then
            G_GSMR_Active = true
            SetControlValue("GSM-R_lit", 1)
        end
        
        -- Handle Notbremsanforderung_LIT (starts after 3 seconds, blinks 3 times in 3 seconds)
        if G_LampTestTimer >= 3.0 and G_LampTestTimer < 6.0 then
            G_NotbremsTimer = G_NotbremsTimer + dt
            
            -- Blink 3 times in 3 seconds: each complete blink (ON-OFF) takes 1 second
            -- So we toggle every 0.5 seconds: ON(0.5s)-OFF(0.5s)-ON(0.5s)-OFF(0.5s)-ON(0.5s)-OFF(0.5s)
            if G_NotbremsTimer >= 0.5 then
                G_NotbremsTimer = 0
                G_NotbremsBlinkState = not G_NotbremsBlinkState
                SetControlValue("Notbremsanforderung_LIT", lambda(G_NotbremsBlinkState, 1, 0))
                
                -- Count blinks (only count when turning ON)
                if G_NotbremsBlinkState then
                    G_NotbremsBlinkCount = G_NotbremsBlinkCount + 1
                end
            end
        elseif G_LampTestTimer >= 6.0 then
            -- Make sure it's off after blinking period
            SetControlValue("Notbremsanforderung_LIT", 0)
        end
        
        -- Handle ZTB fast blinking (for 10 seconds)
        if G_LampTestTimer < 10.0 then
            G_ZTBBlinkTimer = G_ZTBBlinkTimer + dt
            
            -- Fast blink every 0.2 seconds
            if G_ZTBBlinkTimer >= 0.2 then
                G_ZTBBlinkTimer = 0
                G_ZTBBlinkState = not G_ZTBBlinkState
                local ztbValue = lambda(G_ZTBBlinkState, 1, 0)
                SetControlValue("ZTB_1_lit", ztbValue)
                SetControlValue("ZTB_2_lit", ztbValue)
                SetControlValue("ZTB_3_lit", ztbValue)
            end
        else
            -- After 10 seconds: restore correct ZTB state
            if UpdateZTBDisplay then
                UpdateZTBDisplay()
            end
        end
        
        -- Turn off main lamps after 5 seconds (base lamp test duration)
        if G_LampTestTimer >= 5.0 and G_LampTestTimer < 5.1 then
            -- Only execute once when crossing 5 seconds
            local lamps = {
                "Notlicht_LIT",
                "Hauptschalter_LIT",
                "Pantograph_LIT",
                "Zugsammelschiene_LIT",
                "KlimaNotAus_LIT",
                "Fahrgastbeleuchtung_Ein_LIT",
                "D_LIT",
                "Scheibenheizung_LIT",
                "Fussheizung_LIT",
                "HL_Nicht_Durchgaengig_LIT",
                "Ueberbrueckung_Fahrsperre_LIT",
                "Hilfsbetriebsstoerung_LIT",
                "Notruf_WC_LIT",
                "Notlauf_Federung_Steuerwagen_LIT",
                "Tueroeffnung_Rollstuhl_LIT",
                "Notlauf_Luftfederung_Steuerwagen_LIT",
                "Haltanforderung_LIT",
                "Traktionsstoerung_LIT",
                "Quiettierung_LIT",
                "Schleuderbremse_LIT",
                "FSB_Loesen_LIT",
                "Bremse_Abgesperrt_LIT",
                "Magnetschienenbremse_LIT",
                "TF_L_LIT",
                "TV_LIT",
                "TF_R_LIT",
                "Schiebetritt_LIT",
                "TFS_LIT",
                "Manoever_LIT",
                "ZUBQuittierung_lit"
            };
            
            -- Turn main lamps off
            for _, lamp in ipairs(lamps) do
                SetControlValue(lamp, 0);
            end
            
            -- Set Notlicht_LIT to 2 (bright) after lamp test
            G_NotlichtState = 1
            SetControlValue("Notlicht_LIT", 1)
            
            -- Immediately restore state-based indicator lights (FSB, brakes, FGBAus, Scheinwerfer, etc.)
            -- This happens at 5 seconds, not waiting for 10 seconds
            UpdateIndicatorLights()
        end
        
        -- Complete lamp test after 10 seconds (when all special timers are done)
        if G_LampTestTimer >= 10.0 then
            G_LampTestActive = false
        end
    end
    
    -- Also manage the pantograph state
    UpdatePantograph(dt)
end

-- TIMS (Train Information Management System)
-- Add these to your ControlScript

local TIMS_destinations = "abzABCDcdefghijklmnopqrstu[^&;vwxy_+EFGHIJKLMNOPQRSTUVWXYZ@#${}=-%()*.";
local TIMS_currentPosition = 0;
local TIMS_bootupTimer = 0;
local TIMS_ready = false;
local TIMS_syncPending = false;
local TIMS_syncTimer = 0;
G_TIMS_currentDestination = "m"; -- Global so other scripts can access it - default to NOT in service
local TIMS_UpButtonHeld = false
local TIMS_DownButtonHeld = false
local TIMS_UpHoldTimer = 0
local TIMS_DownHoldTimer = 0
local TIMS_AutoScrollTimer = 0
local TIMS_AutoScrollDelay = 0.25  -- Scroll speed when auto-scrolling (seconds between scrolls)

function TIMS_Initialize()
    TIMS_currentPosition = 0;
    TIMS_bootupTimer = 0;
    TIMS_ready = false;
    G_TIMS_currentDestination = "m";  -- Default to NOT in service
    TIMS_UpButtonHeld = false
    TIMS_DownButtonHeld = false
    TIMS_UpHoldTimer = 0
    TIMS_DownHoldTimer = 0
    TIMS_AutoScrollTimer = 0
    Call("TIMS:SetText", "?????");
    
    -- Deactivate TIMS buttons on initialization
    Call("*:ActivateNode", "TIMS_Dn", 0);
    Call("*:ActivateNode", "TIMS_Up", 0);
    Call("*:ActivateNode", "TIMS_Enter", 0);
end

function TIMS_Update(dt)
    -- Check if Steuerstrom is off
    if not G_Steuerstrom then
        if TIMS_ready then
            TIMS_ready = false;
            Call("TIMS:SetText", "?????");
            -- Deactivate TIMS buttons
            Call("*:ActivateNode", "TIMS_Dn", 0);
            Call("*:ActivateNode", "TIMS_Up", 0);
            Call("*:ActivateNode", "TIMS_Enter", 0);
        end
        TIMS_bootupTimer = 0;
        TIMS_syncPending = false;
        return;
    end
    
    -- Steuerstrom is on, check if we need to boot up
    if not TIMS_ready then
        TIMS_bootupTimer = TIMS_bootupTimer + dt;
        if TIMS_bootupTimer >= 9.0 then
            TIMS_ready = true;
            TIMS_currentPosition = 0; -- Reset to 'a'
            TIMS_UpdateDisplay();
            
            -- Activate TIMS buttons
            Call("*:ActivateNode", "TIMS_Dn", 1);
            Call("*:ActivateNode", "TIMS_Up", 1);
            Call("*:ActivateNode", "TIMS_Enter", 1);
            
            -- Try to sync with current destination after bootup
            TIMS_syncPending = true;
            TIMS_syncTimer = 0;
        end
    end
    
    -- Handle pending sync (read RVNumber after a delay)
    if TIMS_syncPending and TIMS_ready then
        TIMS_syncTimer = TIMS_syncTimer + dt;
        if TIMS_syncTimer >= 0.5 then -- Wait 0.5 seconds
            TIMS_ReadCurrentDestination();
            TIMS_syncPending = false;
        end
    end
    
    -- Handle button hold auto-scroll
    if TIMS_ready then
        -- Up button hold
        if TIMS_UpButtonHeld then
            TIMS_UpHoldTimer = TIMS_UpHoldTimer + dt
            if TIMS_UpHoldTimer >= 1.0 then
                -- Auto-scroll mode activated
                TIMS_AutoScrollTimer = TIMS_AutoScrollTimer + dt
                if TIMS_AutoScrollTimer >= TIMS_AutoScrollDelay then
                    TIMS_AutoScrollTimer = 0
                    TIMS_ScrollUp()
                end
            end
        end
        
        -- Down button hold
        if TIMS_DownButtonHeld then
            TIMS_DownHoldTimer = TIMS_DownHoldTimer + dt
            if TIMS_DownHoldTimer >= 1.0 then
                -- Auto-scroll mode activated
                TIMS_AutoScrollTimer = TIMS_AutoScrollTimer + dt
                if TIMS_AutoScrollTimer >= TIMS_AutoScrollDelay then
                    TIMS_AutoScrollTimer = 0
                    TIMS_ScrollDown()
                end
            end
        end
    end
end

function TIMS_UpdateDisplay()
    if not TIMS_ready then
        return;
    end
    
    local len = string.len(TIMS_destinations);
    
    -- Display format: [pos+3][pos+2][pos+1][pos]!
    -- Shows 4 destinations with the rightmost being selected
    local display = "";
    
    for i = 3, 0, -1 do
        local index = TIMS_currentPosition + i;
        -- Wrap around
        while index >= len do
            index = index - len;
        end
        display = display .. string.sub(TIMS_destinations, index + 1, index + 1);
    end
    
    display = display .. "!";
    
    Call("TIMS:SetText", display);
end

-- Internal scroll functions (called by both button press and auto-scroll)
function TIMS_ScrollUp()
    if not TIMS_ready then
        return
    end
    
    local len = string.len(TIMS_destinations)
    TIMS_currentPosition = TIMS_currentPosition - 1
    if TIMS_currentPosition < 0 then
        TIMS_currentPosition = len - 1
    end
    TIMS_UpdateDisplay()
end

function TIMS_ScrollDown()
    if not TIMS_ready then
        return
    end
    
    local len = string.len(TIMS_destinations)
    TIMS_currentPosition = TIMS_currentPosition + 1
    if TIMS_currentPosition >= len then
        TIMS_currentPosition = 0
    end
    TIMS_UpdateDisplay()
end


-- Button handlers (called from ControlScript with button value)
function TIMS_Up(value)
    if not TIMS_ready then
        return
    end
    
    if value > 0.99 then
        -- Button pressed
        if not TIMS_UpButtonHeld then
            -- First press - scroll once immediately
            TIMS_ScrollUp()
            TIMS_UpButtonHeld = true
            TIMS_UpHoldTimer = 0
            TIMS_AutoScrollTimer = 0
        end
    else
        -- Button released
        TIMS_UpButtonHeld = false
        TIMS_UpHoldTimer = 0
        TIMS_AutoScrollTimer = 0
    end
end

function TIMS_Down(value)
    if not TIMS_ready then
        return
    end
    
    if value > 0.99 then
        -- Button pressed
        if not TIMS_DownButtonHeld then
            -- First press - scroll once immediately
            TIMS_ScrollDown()
            TIMS_DownButtonHeld = true
            TIMS_DownHoldTimer = 0
            TIMS_AutoScrollTimer = 0
        end
    else
        -- Button released
        TIMS_DownButtonHeld = false
        TIMS_DownHoldTimer = 0
        TIMS_AutoScrollTimer = 0
    end
end
function TIMS_Enter()
    if not TIMS_ready then
        return;
    end
    
    -- Get current destination character
    local destChar = string.sub(TIMS_destinations, TIMS_currentPosition + 1, TIMS_currentPosition + 1);
    G_TIMS_currentDestination = destChar;
    
    -- Apply to this car
    TIMS_ApplyDestination(destChar);
    
    -- Broadcast to all cars in both directions
    SendConsistMessage(CM_TIMS_DESTINATION, destChar, 0);
    SendConsistMessage(CM_TIMS_DESTINATION, destChar, 1);
end

function TIMS_ApplyDestination(destChar)
    -- Get current RV number to preserve first 4 digits
    local currentRV = Call("*:GetRVNumber");
    
    if currentRV and string.len(currentRV) >= 4 then
        -- Extract first 4 digits and append new destination
        local prefix = string.sub(currentRV, 1, 4);
        
        -- Set new destination (only change last character)
        Call("*:SetRVNumber", prefix .. destChar);
        
        -- Update global tracker
        G_TIMS_currentDestination = destChar;
        
        -- Deactivate Body2.002 node when destination is "m", activate otherwise
        if destChar == "m" then
            Call("*:ActivateNode", "Body2.002", 0)
        else
            Call("*:ActivateNode", "Body2.002", 1)
        end
        
        -- Update passengers for this car
        if UpdatePassengers then
            UpdatePassengers()
        end
    end
end

function TIMS_ReadCurrentDestination()
    -- Read current destination from RVNumber
    local currentRV = Call("*:GetRVNumber");
    if currentRV and string.len(currentRV) >= 5 then
        local destChar = string.sub(currentRV, -1); -- Get last character
        
        -- Skip sync if destination is "n" (default/unset)
        if destChar == "m" then
            return false;
        end
        
        -- Find position in destinations string
        local len = string.len(TIMS_destinations);
        for i = 1, len do
            if string.sub(TIMS_destinations, i, i) == destChar then
                TIMS_currentPosition = i - 1;
                G_TIMS_currentDestination = destChar;
                TIMS_UpdateDisplay();
                return true;
            end
        end
    end
    
    -- If not found or no RVNumber, keep current position
    return false;
end

function TIMS_SyncOnCabActivation()
    -- Called when a cab becomes active to sync TIMS with current destination
    if not G_cabActive then
        return;
    end
    
    -- Set sync pending flag - will read RVNumber after a short delay
    TIMS_syncPending = true;
    TIMS_syncTimer = 0;
end

-- GSM-R (Global System for Mobile Communications - Railway)
-- Time Display System

local GSMR_updateTimer = 0;
local GSMR_lastDisplayedTime = "";

function GSMR_Initialize()
    -- Turn off GSM-R display initially
    Call("GSM-R:Activate", 0);
end

function GSMR_Update(dt)
    -- GSM-R only works when Steuerstrom is active
    if not G_Steuerstrom then
        -- Turn off display when Steuerstrom is inactive
        Call("GSM-R:Activate", 0);
        Call("GSM-R:SetText", "");  -- Clear the text
        GSMR_updateTimer = 0;
        GSMR_lastDisplayedTime = "";
        return;
    end
    
    -- Steuerstrom is active, turn on display
    Call("GSM-R:Activate", 1);
    
    -- Update timer
    GSMR_updateTimer = GSMR_updateTimer + dt;
    
    -- Update every second
    if GSMR_updateTimer >= 1.0 then
        GSMR_updateTimer = 0;
        GSMR_UpdateTimeDisplay();
    end
end

-- Helper function to convert digit to letter (0=a, 1=b, 2=c, ..., 9=j)
function GSMR_DigitToLetter(digit)
    local letters = "abcdefghij";
    return string.sub(letters, digit + 1, digit + 1);
end

-- Helper function to pad number with leading zero and convert to letters
function GSMR_PadNumber(num)
    local tens = math.floor(num / 10);
    local ones = math.mod(num, 10);
    return GSMR_DigitToLetter(tens) .. GSMR_DigitToLetter(ones);
end

function GSMR_UpdateTimeDisplay()
    -- Get current time of day in seconds
    local timeOfDaySeconds = SysCall("ScenarioManager:GetTimeOfDay");
    
    if not timeOfDaySeconds then
        return;
    end
    
    -- Convert to integer (floor)
    local totalSeconds = math.floor(timeOfDaySeconds);
    if totalSeconds < 0 then
        totalSeconds = 0;
    end
    
    -- Calculate hours, minutes, seconds (all as integers) - same logic as before
    local hours = math.mod(math.floor(totalSeconds / 3600), 24);
    local minutes = math.floor(math.mod(totalSeconds, 3600) / 60);
    local seconds = math.floor(math.mod(totalSeconds, 60));
    
    -- Format as "HHMMSS" using manual padding and convert to letters (6 characters total)
    local timeString = GSMR_PadNumber(hours) .. GSMR_PadNumber(minutes) .. GSMR_PadNumber(seconds);
    
    -- Only update if time changed (avoid unnecessary calls)
    if timeString ~= GSMR_lastDisplayedTime then
        GSMR_lastDisplayedTime = timeString;
        
        -- Set the text on the GSM-R display (in letter format)
        Call("GSM-R:SetText", timeString);
        
        -- Also show in alert message with formatted time (in actual numbers)
        local hoursStr = (hours < 10) and ("0" .. hours) or ("" .. hours);
        local minutesStr = (minutes < 10) and ("0" .. minutes) or ("" .. minutes);
        local secondsStr = (seconds < 10) and ("0" .. seconds) or ("" .. seconds);
        local formattedTime = hoursStr .. ":" .. minutesStr .. ":" .. secondsStr;
    end
end

function GSMR_Activate()
    -- Called when GSM-R is turned on
    G_GSMR_Active = true;
    SetControlValue("GSM-R_lit", 1);
    GSMR_updateTimer = 0;
    -- Immediately update to show current time
    GSMR_UpdateTimeDisplay();
end

function GSMR_Deactivate()
    -- Called when GSM-R is turned off
    G_GSMR_Active = false;
    SetControlValue("GSM-R_lit", 0);
    Call("GSM-R:Activate", 0);
    Call("GSM-R:SetText", "");  -- Clear the display
    GSMR_lastDisplayedTime = "";
end

--[[
  0..100: Reserved
  101: Consist Length + Door Side + Slave Decider
  102: Door Open Signal
  103: Door Close Signal
  150: Raise pantograph
  151: Lower pantograph
  152: Steuerstrom ON
  153: Steuerstrom OFF
  156: VST Claim Giving mode
  158: Steuerstrom Claim (Master Cab)
  159: Steuerstrom Release (Clear Master Cab)
  160: Steuerstrom Alarm (Conflict detected)
  161: Steuerstrom Alarm Clear (Conflict resolved)
  161: Steuerstrom Alarm Clear
  157: VST Exchange Random ID
  200: Apply SAPB
  201: Release SAPB
  210: Park
  211: Zugschlusslichter
  212: Warnsignal
  220: Fahrgastraum lighting ON
  221: Fahrgastraum lighting OFF
  224: Traktionsventilation value
  225: Magnetschienenbremse ON
  226: Magnetschienenbremse OFF
  227: Voltmeter ON (display only)
  228: Voltmeter OFF (display only)
  229: Bremsanzeiger Update (broadcast Bremsanzeiger value, FSB is local)
  230: TIMS Destination Broadcast
  231: FSB Status (broadcast engaged/released state)
  498: Transmit Operating Mode
  499: Transmit New Dominant Train uwu
  --------- END OF AUTO ONWARDS SENDING ---------
  501: Consist Length + Door Side ("Zugbustaufe")
  560: ZTB Count Request
  561: ZTB Result Broadcast
  900: RTF: Consist Length + reversedness+
  999: 
]] 
CM_DOOR_OPEN = 102
CM_DOOR_CLOSE = 103
CM_DOOR_STATUS_LEFT = 104  -- Report if this car has left doors actually open
CM_DOOR_STATUS_RIGHT = 105  -- Report if this car has right doors actually open
CM_PANTOGRAPH_RAISE = 150
CM_PANTOGRAPH_LOWER = 151
CM_STEUERSTROM_ON = 152
CM_STEUERSTROM_OFF = 153
CM_HAUPTSCHALTER_ON = 154
CM_VST_CLAIM_GIVING = 156
CM_STEUERSTROM_ALARM_CLEAR = 161
CM_VST_EXCHANGE_ID = 157
CM_STEUERSTROM_ALARM_CLEAR = 161
CM_STEUERSTROM_ALARM = 160
CM_STEUERSTROM_RELEASE = 159
CM_STEUERSTROM_CLAIM = 158
CM_HAUPTSCHALTER_OFF = 155
CM_ZUGSAMMELSCHIENE_ON = 232
CM_ZUGSAMMELSCHIENE_OFF = 233
CM_SAPB_APPLY = 200
CM_SAPB_RELEASE = 201
CM_SAPM_ENABLE = 203;
CM_SAPM_DISABLE = 204;
CM_DISABLE_PARKLIGHT = 210
CM_ENABLE_PARKLIGHT = 211
CM_FAHRGASTRAUM_ON = 220
CM_FAHRGASTRAUM_OFF = 221
CM_TRAKTIONSVENTILATION = 224
CM_MAGNETBREMSE_ON = 225
CM_MAGNETBREMSE_OFF = 226
CM_VOLTMETER_ON = 227
CM_VOLTMETER_OFF = 228
CM_BREMSANZEIGER_UPDATE = 229
CM_TIMS_DESTINATION = 230
CM_FSB_STATUS = 231
CM_OM_TRANSMIT = 498
CM_DOMINANT_TRAIN = 499
CM_ZUGBUSTAUFE = 501
CM_ZTB_COUNT = 560
CM_ZTB_BROADCAST = 561
CM_RTF_ZUGBUSTAUFE = 900
COUPLING_MSG = 10000
CM_NOTLICHT_ON = 222
CM_NOTLICHT_OFF = 223

local is_last = false;

local messages = {
    [CM_DOOR_OPEN] = function(argument, direction)
        SelectDoorsToOpenOnRelease(argument)
    end,
    [CM_DOOR_CLOSE] = function(argument, direction)
        CloseDoors();
    end,
    [CM_DOOR_STATUS_LEFT] = function(argument, direction)
        -- Track if any car in consist has left doors open
        -- argument: 1 = doors open, 0 = doors closed
        local doorsOpen = (tonumber(argument) == 1)
        if doorsOpen then
            G_ConsistDoorsOpenLeft = true
        end
        -- Forward to all cars
        SendConsistMessage(CM_DOOR_STATUS_LEFT, argument, direction)
    end,
    [CM_DOOR_STATUS_RIGHT] = function(argument, direction)
        -- Track if any car in consist has right doors open
        -- argument: 1 = doors open, 0 = doors closed
        local doorsOpen = (tonumber(argument) == 1)
        if doorsOpen then
            G_ConsistDoorsOpenRight = true
        end
        -- Forward to all cars
        SendConsistMessage(CM_DOOR_STATUS_RIGHT, argument, direction)
    end,
    [CM_PANTOGRAPH_RAISE] = function(argument, direction)
        PantographRaise();
    end,
    [CM_PANTOGRAPH_LOWER] = function(argument, direction)
        PantographLower();
    end,
    [CM_STEUERSTROM_ON] = function(argument, direction)
        G_Steuerstrom = true
        -- Recheck ZTB unit count when Steuerstrom activates
        if ZTB_InitiateCount then
            ZTB_InitiateCount()
        end
    end,
    [CM_STEUERSTROM_OFF] = function(argument, direction)
        G_Steuerstrom = false
    end,
    [CM_VST_EXCHANGE_ID] = function(argument, direction)
        local otherID = tonumber(argument)
        
        -- Only process if we're an inner endcar (both ends coupled)
        if G_VST_MasterRandomID and 
           G_SomethingCoupledAtRear == 1 and G_SomethingCoupledAtFront == 1 then
            
            -- Track which direction we received the FIRST valid ID from
            if not G_VST_CompareDirection then
                G_VST_CompareDirection = direction
            end
            
            -- Only compare with IDs from the direction we locked onto first
            -- This ensures consistent pairing in multi-unit consists
            if direction == G_VST_CompareDirection and G_VST_Mode == 0 then
                if G_VST_MasterRandomID > otherID then
                    G_VST_Mode = 1
                    SetControlValue("VST", 1)
                    UpdateVST()
                elseif G_VST_MasterRandomID < otherID then
                    G_VST_Mode = 2
                    SetControlValue("VST", 2)
                    UpdateVST()
                else
                    -- ID collision - regenerate and resend
                    G_VST_MasterRandomID = math.random(1, 999999)
                    G_VST_CompareDirection = nil  -- Reset direction tracking
                    Call("SendConsistMessage", CM_VST_EXCHANGE_ID, G_VST_MasterRandomID, 0)
                    Call("SendConsistMessage", CM_VST_EXCHANGE_ID, G_VST_MasterRandomID, 1)
                end
            end
        end
    end,
    [CM_STEUERSTROM_CLAIM] = function(argument, direction)
        local otherCabID = tonumber(argument)
        
        -- If this cab already has Steuerstrom active
        if G_ThisCabHasSteuerstrom then
            -- CONFLICT: Two cabs both have Steuerstrom active!
            -- Broadcast alarm to ALL cabs
            Call("SendConsistMessage", CM_STEUERSTROM_ALARM, 0, 0)
            Call("SendConsistMessage", CM_STEUERSTROM_ALARM, 0, 1)
            
            -- Use cab ID as tiebreaker - lower ID gives up
            if G_ThisCabID < otherCabID then
                -- We have lower ID - give up control completely
                DeactivateSteuerstrom()
                G_SteuerstromMasterCabID = otherCabID
                G_SteuerstromAlarmActive = true
                SetControlValue("Steuerstrom_SND", 1)
                SysCall("ScenarioManager:ShowAlertMessageExt", "Steuerstrom-Konflikt / Conflit / Conflitto / Conflict", "Schalter ausschalten!\nDesactiver l'interrupteur!\nDisattivare l'interruttore!\nSwitch off!", 2, 0)
            else
                -- We have higher ID - keep control but trigger alarm
                Call("SendConsistMessage", CM_STEUERSTROM_CLAIM, G_ThisCabID, direction)
                G_SteuerstromAlarmActive = true
                SetControlValue("Steuerstrom_SND", 1)
                SysCall("ScenarioManager:ShowAlertMessageExt", "Steuerstrom-Konflikt / Conflit / Conflitto / Conflict", "Schalter ausschalten!\nDesactiver l'interrupteur!\nDisattivare l'interruttore!\nSwitch off!", 2, 0)
            end
        else
            -- Store the master cab ID
            G_SteuerstromMasterCabID = otherCabID
            
            -- If this is an engine car (Fst=1), broadcast FSB status to the newly activated cab
            local fstValue = GetControlValue("Fst") or 0
            if fstValue > 0.5 then
                SendConsistMessage(CM_FSB_STATUS, lambda(G_SAPBEngaged, 1, 0), 0)
                SendConsistMessage(CM_FSB_STATUS, lambda(G_SAPBEngaged, 1, 0), 1)
            end
        end
    end,
    [CM_STEUERSTROM_RELEASE] = function(argument, direction)
        -- Clear the master cab ID so other cabs can activate Steuerstrom
        G_SteuerstromMasterCabID = 0
    end,
    [CM_STEUERSTROM_ALARM] = function(argument, direction)
        -- Trigger alarm in this cab
        G_SteuerstromAlarmActive = true
        SetControlValue("Steuerstrom_SND", 1)
    end,
    [CM_STEUERSTROM_ALARM_CLEAR] = function(argument, direction)
        -- Clear alarm in this cab
        G_SteuerstromAlarmActive = false
        SetControlValue("Steuerstrom_SND", 0)
    end,
    [CM_HAUPTSCHALTER_ON] = function(argument, direction)
        G_Hauptschalter = true
        SetControlValue("Hauptschalter_LIT", 1)
        TV_SetMainSwitch(true)  -- Update TV system
    end,
    [CM_HAUPTSCHALTER_OFF] = function(argument, direction)
        G_Hauptschalter = false
        SetControlValue("Hauptschalter_LIT", 0)
        TV_SetMainSwitch(false)  -- Update TV system
    end,
    [CM_ZUGSAMMELSCHIENE_ON] = function(argument, direction)
        G_ZugsammelschieneLIT = true
        SetControlValue("Zugsammelschiene_LIT", 1)
    end,
    [CM_ZUGSAMMELSCHIENE_OFF] = function(argument, direction)
        G_ZugsammelschieneLIT = false
        SetControlValue("Zugsammelschiene_LIT", 0)
    end,
    [CM_SAPB_APPLY] = function(argument, direction)
        OnControlValueChange("PB_Apply", 0, 0.999)
    end,
    [CM_SAPB_RELEASE] = function(argument, direction)
        OnControlValueChange("PB_Release", 0, 0.999)
    end,
    [CM_SAPM_ENABLE] = function(argument, direction)
        ParkstellungSet(true, true)
    end,
    [CM_SAPM_DISABLE] = function(argument, direction)
        ParkstellungSet(false, true)
    end,
    [CM_DISABLE_PARKLIGHT] = function(argument, direction)
        Call("Parklicht:Activate", 0)
        Call("*:ActivateNode", "lights_parklicht", 0)
    end,
    [CM_ENABLE_PARKLIGHT] = function(argument, direction)
        Call("Parklicht:Activate", 1)
        Call("*:ActivateNode", "lights_parklicht", 1)
    end,
    [CM_FAHRGASTRAUM_ON] = function(argument, direction)
        -- Turn on lights in this car
        G_FahrgastraumbeleuchtungOn = true
        Call("*:ActivateNode", "Innenraum_lit", 1)
        Call("*:ActivateNode", "Innenraum", 0)
        -- Update passengers
        if UpdatePassengers then
            UpdatePassengers()
        end
    end,
    [CM_FAHRGASTRAUM_OFF] = function(argument, direction)
        -- Turn off lights in this car
        G_FahrgastraumbeleuchtungOn = false
        Call("*:ActivateNode", "Innenraum_lit", 0)
        Call("*:ActivateNode", "Innenraum", 1)
        -- Update passengers
        if UpdatePassengers then
            UpdatePassengers()
        end
    end,
    [CM_TRAKTIONSVENTILATION] = function(argument, direction)
        -- Receive TV value from controlling car
        SetControlValue("Traktionsventilation", tonumber(argument))
    end,
    [CM_MAGNETBREMSE_ON] = function(argument, direction)
        -- Activate MG brake animation - set target to max value
        G_MGBrake_Target = 4.16666666667
    end,
    [CM_MAGNETBREMSE_OFF] = function(argument, direction)
        -- Deactivate MG brake animation - set target to 0
        G_MGBrake_Target = 0
    end,
    [CM_VOLTMETER_ON] = function(argument, direction)
        -- Set voltmeter active state (display only, doesn't affect G_Steuerstrom)
        G_VoltmeterActive = true
    end,
    [CM_VOLTMETER_OFF] = function(argument, direction)
        -- Clear voltmeter active state (display only)
        G_VoltmeterActive = false
    end,
    [CM_BREMSANZEIGER_UPDATE] = function(argument, direction)
        -- Receive brake indicator target value from controlling car
        -- Format: "Bremsanzeiger_target" (FSB is local to each car)
        G_Bremsanzeiger_Target = tonumber(argument) or 1.0
    end,
    [CM_TIMS_DESTINATION] = function(argument, direction)
        -- Update destination for entire consist
        TIMS_ApplyDestination(argument)
        if UpdatePassengers then
            UpdatePassengers()
        end
    end,
    [CM_FSB_STATUS] = function(argument, direction)
        -- Update FSB engaged state in all cars (regardless of Fst value)
        G_SAPBEngaged = (tonumber(argument) == 1)
        UpdateFSBLights()
    end,
    [CM_OM_TRANSMIT] = function(argument, direction)
        SetOperatingMode(argument);
    end,
    [CM_DOMINANT_TRAIN] = function(argument, direction)
        G_RC = true;
        G_cabActive = false;
    end,
    [CM_ZUGBUSTAUFE] = function(argument, direction)
        CheckConsist(argument, direction);
    end,
    [CM_ZTB_COUNT] = function(argument, direction)
        -- String-based counting: each endcar appends if both ends coupled
        if ZTB_CountResponse then
            ZTB_CountResponse(argument, direction)
        end
    end,
    [CM_ZTB_BROADCAST] = function(argument, direction)
        if ZTB_SetUnitCount then
            ZTB_SetUnitCount(tonumber(argument))
        end
        SendConsistMessage(CM_ZTB_BROADCAST, argument, direction)
    end,
    [CM_RTF_ZUGBUSTAUFE] = function(argument, direction)
        RTF_ConsistLength(argument, direction);
    end,
    [COUPLING_MSG] = function(argument, direction)
        -- Just acknowledge existence for coupling detection
        -- No action needed - return value indicates coupling
    end,
    [CM_NOTLICHT_ON] = function(argument, direction)
        G_NotlichtActive = true
        SetControlValue("Notlicht_LIT", 2)
        SetControlValue("Headlight", 0)
        CheckCouplings()
        UpdateNotlicht()
    end,
    [CM_NOTLICHT_OFF] = function(argument, direction)
        G_NotlichtActive = false
        SetControlValue("Notlicht_LIT", 1)
        SetControlValue("Headlight", 1)
        CheckCouplings()
        UpdateNotlicht()
    end
}

function ConsistMessage(message, argument, direction)
    local name = tonumber(message)
    if messages[name] then
        messages[name](argument, direction)
    else
    end

    -- Forward the consist message to the next unit if applicable
    if name < 500 then
        SendConsistMessage(message, argument, direction)
    end
end

function CheckConsist(m, d)
    local text = m .. lambda(d == 1, "n", "f");
    IsFlipped = d == 0;
    local res = SendConsistMessage(CM_ZUGBUSTAUFE, text, d);
    if res == 0 then
        is_last = true;
        SendConsistMessage(CM_RTF_ZUGBUSTAUFE, text, (1 - d));
    end
end

NumberOfUnits = 0

function RTF_ConsistLength(m, d)
    local res = SendConsistMessage(CM_RTF_ZUGBUSTAUFE, m, d);
    if res == 0 then -- if last wagon then show to user, later actually use that data lmao
        NumberOfUnits = math.min(3, math.max(NumberOfUnits, math.floor(string.len(m) / 4)));
    end
end

--------------------------------------------------------------------------------
-- STOP REQUEST SYSTEM (Haltanforderung)
--------------------------------------------------------------------------------
-- State Variables - REGULAR STOP REQUEST
G_StopRequest_Active = false
G_StopRequest_Timer = 0
G_StopRequest_NextTriggerTime = 0
G_StopRequest_WasAbove100 = false
G_StopRequest_DecelTriggerPending = false
G_StopRequest_LastSpeed = 0
G_StopRequest_SlowDecelTriggered = false -- Track if <10km/h trigger already fired

-- State Variables - WHEELCHAIR STOP REQUEST (independent timer)
G_WheelchairRequest_Active = false
G_WheelchairRequest_Timer = 0
G_WheelchairRequest_NextTriggerTime = 0
G_WheelchairRequest_WasAbove100 = false
G_WheelchairRequest_DecelTriggerPending = false
G_WheelchairRequest_SlowDecelTriggered = false
G_WheelchairRequest_DoorHoldActive = false
G_WheelchairRequest_DoorHoldTimer = 0
G_WheelchairRequest_LightTimer = 0 -- Timer for clearing light after 22 seconds
G_WheelchairRequest_LightDebugTimer = 0 -- Debug timer

-- Debug tracking
-- G_StopRequest_DebugTimer = 0

-- Initialize stop request system
function StopRequest_Initialize()
    -- Regular stop request
    G_StopRequest_Active = false
    G_StopRequest_Timer = 0
    G_StopRequest_NextTriggerTime = math.random(120, 300) -- 2-5 minutes
    G_StopRequest_WasAbove100 = false
    G_StopRequest_DecelTriggerPending = false
    G_StopRequest_LastSpeed = 0
    G_StopRequest_SlowDecelTriggered = false

    -- Wheelchair stop request (independent)
    G_WheelchairRequest_Active = false
    G_WheelchairRequest_Timer = 0
    G_WheelchairRequest_NextTriggerTime = math.random(120, 300) -- 2-5 minutes (separate from regular)
    G_WheelchairRequest_WasAbove100 = false
    G_WheelchairRequest_DecelTriggerPending = false
    G_WheelchairRequest_SlowDecelTriggered = false
    G_WheelchairRequest_DoorHoldActive = false
    G_WheelchairRequest_DoorHoldTimer = 0
    G_WheelchairRequest_LightTimer = 0
    G_WheelchairRequest_LightDebugTimer = 0

    G_StopRequest_DebugTimer = 0

    SetControlValue("Haltanforderung_LIT", 0)
    SetControlValue("Tueroeffnung_Rollstuhl_LIT", 0)
end

-- Check if train is in passenger service
function StopRequest_IsInService()
    local dest = G_TIMS_currentDestination or "m" -- Default to NOT in service if not set
    -- Not in service if destination is m, n, o, p, or q
    return dest ~= "m" and dest ~= "n" and dest ~= "o" and dest ~= "p" and dest ~= "q"
end

-- Update stop request system
function StopRequest_Update(dt)
    -- Only active if Steuerstrom is on and train is in service
    if not G_Steuerstrom or not StopRequest_IsInService() then
        if G_StopRequest_Active then
            G_StopRequest_Active = false
            SetControlValue("Haltanforderung_LIT", 0)
        end
        if G_WheelchairRequest_Active then
            G_WheelchairRequest_Active = false
            SetControlValue("Tueroeffnung_Rollstuhl_LIT", 0)
        end
        G_StopRequest_Timer = 0
        G_WheelchairRequest_Timer = 0
        return
    end

    -- Get current speed
    local speed = math.abs(Call("GetSpeed") or 0) * 3.6 -- Convert m/s to km/h

    -- Debug output every 30 seconds
    -- G_StopRequest_DebugTimer = G_StopRequest_DebugTimer + dt
    -- if G_StopRequest_DebugTimer >= 30.0 then
    --     G_StopRequest_DebugTimer = 0
    --     local dest = G_TIMS_currentDestination or "nil"
    --     local inService = StopRequest_IsInService() and "YES" or "NO"
    --     -- SysCall("ScenarioManager:ShowAlertMessageExt", 
    --     --     "StopReq: Reg=" .. math.floor(G_StopRequest_Timer) .. "/" .. 
    --     --     math.floor(G_StopRequest_NextTriggerTime) .. "s | WC=" .. 
    --     --     math.floor(G_WheelchairRequest_Timer) .. "/" .. 
    --     --     math.floor(G_WheelchairRequest_NextTriggerTime) .. "s | Dest=" .. dest .. 
    --     --     " | InSvc=" .. inService .. " | Spd=" .. math.floor(speed) .. "km/h", 2, 0)
    -- end

    -- Check if doors are released/closed
    local doorsLeft = Call("GetControlValue", "DoorsOpenCloseLeft", 0) or 0
    local doorsRight = Call("GetControlValue", "DoorsOpenCloseRight", 0) or 0

    if doorsLeft > 0.5 or doorsRight > 0.5 then
        -- Doors RELEASED (signal = 1) - allowed to open

        -- Clear regular stop request
        if G_StopRequest_Active then
            G_StopRequest_Active = false
            SetControlValue("Haltanforderung_LIT", 0)
            -- Reset timer for next regular request
            if speed < 100 then
                G_StopRequest_NextTriggerTime = math.random(120, 300) -- 2-5 minutes
            else
                G_StopRequest_NextTriggerTime = math.random(480, 900) -- 8-15 minutes
            end
            G_StopRequest_Timer = 0
        end

        -- Start wheelchair timers when doors released (only once - check if not already started)
        if G_WheelchairRequest_Active and not G_WheelchairRequest_DoorHoldActive and G_WheelchairRequest_LightTimer == 0 then
            G_WheelchairRequest_DoorHoldActive = true
            G_WheelchairRequest_DoorHoldTimer = 0
            G_WheelchairRequest_LightTimer = 0.001 -- Start at 0.001 to mark as started
            G_WheelchairRequest_LightDebugTimer = 0
            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Wheelchair: Doors released, timers started (20s door, 22s light)", 1, 0)
        end

        -- Reset deceleration triggers when stopped
        G_StopRequest_SlowDecelTriggered = false
        G_WheelchairRequest_SlowDecelTriggered = false
    end

    -- Update wheelchair light timer - clear light after 22 seconds (runs after doors released)
    if G_WheelchairRequest_Active and G_WheelchairRequest_LightTimer > 0 then
        G_WheelchairRequest_LightTimer = G_WheelchairRequest_LightTimer + dt
        G_WheelchairRequest_LightDebugTimer = G_WheelchairRequest_LightDebugTimer + dt

        -- Debug every 5 seconds
        if G_WheelchairRequest_LightDebugTimer >= 5.0 then
            G_WheelchairRequest_LightDebugTimer = 0
            local timeLeft = 22.0 - G_WheelchairRequest_LightTimer
            -- SysCall("ScenarioManager:ShowAlertMessageExt", 
            --     "Wheelchair Light: " .. string.format("%.1f", G_WheelchairRequest_LightTimer) .. "s / 22s (left: " .. string.format("%.1f", timeLeft) .. "s)", 1, 0)
        end

        if G_WheelchairRequest_LightTimer >= 22.0 then
            -- 22 seconds elapsed - clear wheelchair light and request flag
            SetControlValue("Tueroeffnung_Rollstuhl_LIT", 0)
            G_WheelchairRequest_Active = false
            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Wheelchair Light OFF after 22 seconds", 1, 0)
        end
    end

    -- Handle wheelchair door hold timer (20 seconds to hold door open)
    if G_WheelchairRequest_DoorHoldActive then
        G_WheelchairRequest_DoorHoldTimer = G_WheelchairRequest_DoorHoldTimer + dt
        if G_WheelchairRequest_DoorHoldTimer >= 20.0 then
            -- 20 seconds elapsed - mark that door can now close
            G_WheelchairRequest_DoorHoldActive = false
        end
    end

    -- Only generate new requests if train is moving
    if speed < 1.0 then
        G_StopRequest_LastSpeed = speed
        return
    end

    -- Track speed changes for deceleration logic
    local speedDecreased = speed < G_StopRequest_LastSpeed

    -- NEW: Check for slow deceleration (<10 km/h) - 75% chance for regular, 10% for wheelchair
    if speedDecreased and speed < 10.0 and G_StopRequest_LastSpeed >= 10.0 then
        if not G_StopRequest_SlowDecelTriggered and math.random() < 0.75 then
            StopRequest_TriggerRegular()
            G_StopRequest_SlowDecelTriggered = true
        end
    end

    if speedDecreased and speed < 10.0 and G_StopRequest_LastSpeed >= 10.0 then
        if not G_WheelchairRequest_SlowDecelTriggered and math.random() < 0.10 then
            StopRequest_TriggerWheelchair(true) -- Pass true to skip 5% check (already checked above)
            G_WheelchairRequest_SlowDecelTriggered = true
        end
    end

    -- Reset slow decel triggers if speed goes back above 15 km/h
    if speed > 15.0 then
        G_StopRequest_SlowDecelTriggered = false
        G_WheelchairRequest_SlowDecelTriggered = false
    end

    -- REGULAR STOP REQUEST - Speed-based state tracking
    if speed >= 100 then
        if not G_StopRequest_WasAbove100 then
            G_StopRequest_WasAbove100 = true
            G_StopRequest_Timer = 0
            G_StopRequest_NextTriggerTime = math.random(480, 900) -- 8-15 minutes
        end
        G_StopRequest_DecelTriggerPending = false
    else
        -- Below 100 km/h
        if G_StopRequest_WasAbove100 then
            G_StopRequest_WasAbove100 = false
            if speed < 50 then
                G_StopRequest_DecelTriggerPending = true
            else
                G_StopRequest_Timer = 0
                G_StopRequest_NextTriggerTime = math.random(120, 300) -- 2-5 minutes
            end
        end

        -- Check for deceleration trigger (100+ to below 50)
        if G_StopRequest_DecelTriggerPending and speed < 50 then
            if math.random() < 0.5 then
                StopRequest_TriggerRegular()
            end
            G_StopRequest_DecelTriggerPending = false
            G_StopRequest_Timer = 0
            G_StopRequest_NextTriggerTime = math.random(120, 300)
        elseif G_StopRequest_DecelTriggerPending and not speedDecreased and speed > 50 then
            G_StopRequest_DecelTriggerPending = false
            G_StopRequest_Timer = 0
            G_StopRequest_NextTriggerTime = math.random(120, 300)
        end
    end

    -- WHEELCHAIR STOP REQUEST - Speed-based state tracking (independent)
    if speed >= 100 then
        if not G_WheelchairRequest_WasAbove100 then
            G_WheelchairRequest_WasAbove100 = true
            G_WheelchairRequest_Timer = 0
            G_WheelchairRequest_NextTriggerTime = math.random(480, 900) -- 8-15 minutes
        end
        G_WheelchairRequest_DecelTriggerPending = false
    else
        -- Below 100 km/h
        if G_WheelchairRequest_WasAbove100 then
            G_WheelchairRequest_WasAbove100 = false
            if speed < 50 then
                G_WheelchairRequest_DecelTriggerPending = true
            else
                G_WheelchairRequest_Timer = 0
                G_WheelchairRequest_NextTriggerTime = math.random(120, 300) -- 2-5 minutes
            end
        end

        -- Check for deceleration trigger (100+ to below 50)
        if G_WheelchairRequest_DecelTriggerPending and speed < 50 then
            if math.random() < 0.5 then
                StopRequest_TriggerWheelchair()
            end
            G_WheelchairRequest_DecelTriggerPending = false
            G_WheelchairRequest_Timer = 0
            G_WheelchairRequest_NextTriggerTime = math.random(120, 300)
        elseif G_WheelchairRequest_DecelTriggerPending and not speedDecreased and speed > 50 then
            G_WheelchairRequest_DecelTriggerPending = false
            G_WheelchairRequest_Timer = 0
            G_WheelchairRequest_NextTriggerTime = math.random(120, 300)
        end
    end

    -- Update regular stop request timer
    if not G_StopRequest_Active then
        G_StopRequest_Timer = G_StopRequest_Timer + dt
        if G_StopRequest_Timer >= G_StopRequest_NextTriggerTime then
            StopRequest_TriggerRegular()
        end
    end

    -- Update wheelchair request timer (independent)
    if not G_WheelchairRequest_Active then
        G_WheelchairRequest_Timer = G_WheelchairRequest_Timer + dt
        if G_WheelchairRequest_Timer >= G_WheelchairRequest_NextTriggerTime then
            StopRequest_TriggerWheelchair()
        end
    end

    G_StopRequest_LastSpeed = speed
end

-- Trigger regular stop request
function StopRequest_TriggerRegular()
    G_StopRequest_Active = true
    SetControlValue("Haltanforderung_LIT", 1)
    G_StopRequest_Timer = 0
    -- SysCall("ScenarioManager:ShowAlertMessageExt", "Regular Stop Request!", 1, 0)
end

-- Trigger wheelchair stop request (also triggers regular)
-- Trigger wheelchair stop request (also triggers regular)
function StopRequest_TriggerWheelchair(alwaysTrigger)
    -- Check 5% chance only if not called from deceleration trigger
    local shouldTrigger = alwaysTrigger or (math.random() < 0.05)

    if shouldTrigger then
        G_WheelchairRequest_Active = true
        SetControlValue("Tueroeffnung_Rollstuhl_LIT", 1)
        -- Also activate regular stop request
        G_StopRequest_Active = true
        SetControlValue("Haltanforderung_LIT", 1)
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Wheelchair Stop Request!", 1, 0)
    end

    -- Always reset timer (whether 5% succeeded or not)
    G_WheelchairRequest_Timer = 0
    -- Set new random time for next attempt
    local speed = math.abs(Call("GetSpeed") or 0) * 3.6
    if speed < 100 then
        G_WheelchairRequest_NextTriggerTime = math.random(120, 300) -- 2-5 minutes
    else
        G_WheelchairRequest_NextTriggerTime = math.random(480, 900) -- 8-15 minutes
    end
end
-- ZTB (Zugbustaufe) System - counts units based on G_BothEndsCoupled
G_ZTB_UnitCount = 0

function ZTB_InitiateCount()
    CheckCouplings()

    -- Start counting by sending empty string in both directions
    -- Each endcar with G_BothEndsCoupled=1 will append "X" to the string
    SendConsistMessage(CM_ZTB_COUNT, "", 1) -- Forward
    SendConsistMessage(CM_ZTB_COUNT, "", 0) -- Backward
end

function ZTB_CountResponse(countString, direction)
    -- Add to string if this endcar has both ends coupled
    if G_BothEndsCoupled == 1 then
        countString = countString .. "X"
    end

    -- Continue sending or finalize
    local res = SendConsistMessage(CM_ZTB_COUNT, countString, direction)

    if res == 0 then
        -- Reached end of consist, calculate units
        local internalCount = string.len(countString)
        -- Formula: 0 internal = 1 unit, 2 internal = 2 units, 4 internal = 3 units
        G_ZTB_UnitCount = math.floor(internalCount / 2) + 1
        G_ZTB_UnitCount = math.min(3, math.max(1, G_ZTB_UnitCount))

        -- -- Debug message
        -- SysCall("ScenarioManager:ShowAlertMessageExt",
        --     "ZTB: " .. internalCount .. " internal endcars = " .. G_ZTB_UnitCount .. " units", 2, 0)

        -- Broadcast result
        SendConsistMessage(CM_ZTB_BROADCAST, G_ZTB_UnitCount, 1)
        SendConsistMessage(CM_ZTB_BROADCAST, G_ZTB_UnitCount, 0)

        UpdateZTBDisplay()
    end
end

function ZTB_SetUnitCount(count)
    G_ZTB_UnitCount = math.min(3, math.max(1, tonumber(count) or 1))
    UpdateZTBDisplay()
end

function UpdateZTBDisplay()
    -- Don't update during lamp test ZTB blinking (first 10 seconds)
    if G_LampTestActive and G_LampTestTimer < 10.0 then
        return
    end

    SetControlValue("ZTB_1_lit", (G_ZTB_UnitCount >= 1) and 1 or 0)
    SetControlValue("ZTB_2_lit", (G_ZTB_UnitCount >= 2) and 1 or 0)
    SetControlValue("ZTB_3_lit", (G_ZTB_UnitCount >= 3) and 1 or 0)
end

function ScheinwerferButton(name, value)
    if name ~= "Scheinwerfer_BT" then
        return
    end

    if value < 0.99 then
        return
    end

    -- Only works with Steuerstrom active
    if not G_RC and not G_Steuerstrom or G_NotlichtActive then
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Scheinwerfer kann ohne Steuerstrom nicht bedient werden", 1, 0)
        return
    end

    -- Toggle Fernlicht (high beam)
    G_ScheinwerferOn = not G_ScheinwerferOn

    -- Activate Fernlicht nodes instead of Headlights control
    if G_ScheinwerferOn then
        Call("Fernlicht_1:Activate", 1)
        Call("Fernlicht_2:Activate", 1)
        Call("Fernlicht_3:Activate", 1)

        SetControlValue("Scheinwerfer_LIT", 2)
    else
        Call("Fernlicht_1:Activate", 0)
        Call("Fernlicht_2:Activate", 0)
        Call("Fernlicht_3:Activate", 0)

        SetControlValue("Scheinwerfer_LIT", 1)
    end

    if not G_RC then
        -- SysCall("ScenarioManager:ShowAlertMessageExt",
        -- lambda(G_ScheinwerferOn, "Fernlicht eingeschaltet", "Fernlicht ausgeschaltet"), 1, 0)
    end
end

function TimsButton(name, value)
    if name == "TIMS_Up" then
        TIMS_Up(value); -- ✓ Pass value, always call
        return;
    end

    if name == "TIMS_Dn" then
        TIMS_Down(value); -- ✓ Pass value, always call
        return;
    end

    if name == "TIMS_Enter" then
        if value > 0.99 then
            TIMS_Enter(); -- ✓ This one is fine (doesn't need value)
        end
        return;
    end
end

function MirrorButton(name, value)
    if name ~= "Spiegel_BT" then
        return
    end

    -- Detect button press (rising edge)
    if value > 0.9 and not G_MirrorButtonPressed then
        G_MirrorButtonPressed = true

        -- Only works with Steuerstrom active
        if not G_Steuerstrom then
            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Spiegel kann ohne Steuerstrom nicht bedient werden", 1, 0)
            return
        end

        -- Toggle mirror state
        G_MirrorExtended = not G_MirrorExtended

        -- if not G_RC then
        --     -- SysCall("ScenarioManager:ShowAlertMessageExt",
        --         -- lambda(G_MirrorExtended, "Spiegel ausgefahren", "Spiegel eingefahren"), 1, 0)
        -- end
    elseif value < 0.1 then
        G_MirrorButtonPressed = false
    end
end

function UpdateMirror(dt)
    -- Animate mirror over 1 second
    local targetValue = lambda(G_MirrorExtended, 1, 0)
    G_MirrorAnimCurrent = ExponentialMove(dt, G_MirrorAnimCurrent, targetValue, 1.0)
    SetControlValue("FstMirror_Anim", G_MirrorAnimCurrent)
end

function UpdateHeadlights()
    -- If Steuerstrom is not active, turn off Fernlicht
    if not G_Steuerstrom then
        Call("Fernlicht_1:Activate", 0)
        Call("Fernlicht_2:Activate", 0)
        Call("Fernlicht_3:Activate", 0)
        return
    end

    -- Update Fernlicht nodes based on state
    if G_ScheinwerferOn then
        Call("Fernlicht_1:Activate", 1)
        Call("Fernlicht_2:Activate", 1)
        Call("Fernlicht_3:Activate", 1)
    else
        Call("Fernlicht_1:Activate", 0)
        Call("Fernlicht_2:Activate", 0)
        Call("Fernlicht_3:Activate", 0)
    end
    -- Removed all SetControlValue("Scheinwerfer_LIT", ...) - handled by UpdateIndicatorLights
end

function CheckCouplings()
    G_SomethingCoupledAtRear = (Call("SendConsistMessage", COUPLING_MSG, 0, 0) == 1) and 1 or 0
    -- Check for item connected to rear end of vehicle - returns 1 if coupled, 0 otherwise

    G_SomethingCoupledAtFront = (Call("SendConsistMessage", COUPLING_MSG, 0, 1) == 1) and 1 or 0
    -- Check for item connected to front end of vehicle - returns 1 if coupled, 0 otherwise

    if G_SomethingCoupledAtRear == 1 and G_SomethingCoupledAtFront == 1 then
        G_BothEndsCoupled = 1
    else
        G_BothEndsCoupled = 0
    end
end

function ZUBButtonController(name, value)
    if value > 0.99 then
        if name == "ZUBManeuver_BT" then
            -- TODO: Manöver an/aus
        end
    end
end

function ZugBremsHebel(value)
    if value < 0.175 then
        return -1.0 -- Füllstellung (around 0.1)
    elseif value >= 0.175 and value < 0.305 then
        return 5.0 -- Fahrstellung (around 0.25)
    elseif value >= 0.305 and value < 0.4 then
        -- Zwischen 0.345 und 0.4: von 4.7 bis 4.4 (Δ 0.3 bar über 0.055)
        return 4.6 - (value - 0.345) / 0.055 * 0.3
    elseif value >= 0.4 and value < 0.66 then
        -- From 0.4 to 0.66: from 4.3 to 3.8 (Δ 0.5 bar over 0.26)
        return 4.3 - (value - 0.4) / 0.26 * 0.5
    elseif value >= 0.66 and value < 0.72 then
        -- From 0.66 to 0.72: from 3.8 to 3.6 (Δ 0.2 bar over 0.06)
        return 3.8 - (value - 0.66) / 0.06 * 0.2
    elseif value >= 0.72 and value <= 0.8 then
        -- From 0.72 to 0.8: from 3.6 to 3.5 (Δ 0.1 bar over 0.08)
        return 3.6 - (value - 0.72) / 0.08 * 0.1
    elseif value > 0.8 and value <= 0.9 then
        -- From 0.8 to 0.9: from 3.5 to 2.9 (Δ 0.6 bar over 0.1)
        return 3.5 - (value - 0.8) / 0.1 * 0.6
    elseif value > 0.9 and value < 1.1 then
        -- From 0.9 to 1.0: hold at 2.9 bar (last service brake position before Schnellbremse)
        return 2.9
    else
        return 0.0 -- Schnellbremse (>= 1.1)
    end
end

--------------------------------------------------------------------------------
-- BRAKE TEST MODE (Bremsprobemodus)
--------------------------------------------------------------------------------
G_BrakeTestMode = false

function BremsprobemodeButton(name, value)
    if value > 0.99 and name == "Bremsprobe_BT" then
        -- Check conditions: Steuerstrom must be on AND FSB (SAPB) must be applied
        if G_Steuerstrom and G_SAPBEngaged then
            -- Toggle brake test mode
            G_BrakeTestMode = not G_BrakeTestMode
            
            if G_BrakeTestMode then
                SysCall("ScenarioManager:ShowAlertMessageExt", "Bremsprobe / Essai de frein / Prova freni / Brake test", "Aktiviert\nActive\nAttivato\nActivated", 1.5, 0)
            else
                SysCall("ScenarioManager:ShowAlertMessageExt", "Bremsprobe / Essai de frein / Prova freni / Brake test", "Deaktiviert\nDesactive\nDisattivato\nDeactivated", 1.5, 0)
                -- Immediately turn off the light when deactivating
                SetControlValue("Bremsprobe_BremseGeloest_LIT", 0)
            end
        else
            -- Show message about requirements
            if not G_Steuerstrom then
                SysCall("ScenarioManager:ShowAlertMessageExt", "Bremsprobe / Essai de frein / Prova freni / Brake test", "Braucht Steuerstrom\nNecessite courant de commande\nRichiede corrente di controllo\nRequires control current", 2, 0)
            elseif not G_SAPBEngaged then
                SysCall("ScenarioManager:ShowAlertMessageExt", "Bremsprobe / Essai de frein / Prova freni / Brake test", "Braucht FSB\nNecessite frein parking\nRichiede freno parcheggio\nRequires parking brake", 2, 0)
            end
        end
    end
end

local PB_change_Timer = math.random() * 2 + 3
local PB_change = false
function TimedThings(dt)
    if PB_change then
        PB_change_Timer = PB_change_Timer - dt;
        if PB_change_Timer <= 0 then
            G_SAPBEngaged = not G_SAPBEngaged;
            PB_change_Timer = lambda(G_SAPBEngaged, math.random() * 2 + 3, math.random() * 2 + 1);
            PB_change = false;
            
            -- Only set HandBrake for engine cars (Fst=1)
            local fstVal = GetControlValue("Fst") or 0
            if fstVal >= 0.5 then
                SetControlValue("HandBrake", lambda(G_SAPBEngaged, 1, 0));
            else
                SetControlValue("HandBrake", 0);
            end
        end
    end
end

function ParkingBrake(name, value)
    -- FSB Anlegen (Apply)
    if name == "PB_Apply" then
        if value > 0.99 then
            -- Check if Steuerstrom is active (required for local FSB operation)
            -- Remote controlled cars (G_RC=true) can receive FSB commands via consist messages
            if not G_RC and not G_Steuerstrom then
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "FSB kann ohne Steuerstrom nicht bedient werden", 1, 0)
                return
            end

            if not G_SAPBEngaged then
                -- Start blinking sequence for applying
                G_FSB_Blinking = true
                G_FSB_BlinkTimer = 0
                G_FSB_BlinkCount = 0
                G_FSB_BlinkState = true
                G_FSB_TargetState = true -- We want to apply

                -- Play sound when button is pressed
                SetControlValue("Federspeicher_SND", 1)

                -- Send message to all units in consist (only if this is the controlling car)
                if not G_RC then
                    SendConsistMessage(CM_SAPB_APPLY, 0, 1)
                    SendConsistMessage(CM_SAPB_APPLY, 0, 0)
                end

                -- if not G_RC then
                --     SysCall("ScenarioManager:ShowAlertMessageExt", "Federspeicherbremsen werden angelegt...", 1, 0)
                -- end
            end
        end

        -- FSB Lösen (Release)
    elseif name == "PB_Release" then
        if value > 0.99 then
            G_FSB_ReleaseButtonPressed = true

            -- Check if Steuerstrom is active (required for local FSB operation)
            -- Remote controlled cars (G_RC=true) can receive FSB commands via consist messages
            if not G_RC and not G_Steuerstrom then
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "FSB kann ohne Steuerstrom nicht bedient werden", 1, 0)
                return
            end

            if G_SAPBEngaged and not G_Parkstellung then
                -- Start blinking sequence for releasing
                G_FSB_Blinking = true
                G_FSB_BlinkTimer = 0
                G_FSB_BlinkCount = 0
                G_FSB_BlinkState = true
                G_FSB_TargetState = false -- We want to release

                -- Play sound when button is pressed
                SetControlValue("Federspeicher_SND", 0)

                -- Send message to all units in consist (only if this is the controlling car)
                if not G_RC then
                    SendConsistMessage(CM_SAPB_RELEASE, 0, 1)
                    SendConsistMessage(CM_SAPB_RELEASE, 0, 0)
                end

                if not G_RC then
                    -- SysCall("ScenarioManager:ShowAlertMessageExt", "Federspeicherbremsen werden gelöst...", 1, 0)
                end
            elseif G_Parkstellung and not G_RC then
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "FSB kann in Parkstellung nicht gelöst werden", 1, 0)
            end
        else
            G_FSB_ReleaseButtonPressed = false
        end
    end

    UpdateFSBLights()
end

-- Add this function to update the indicator lights
function UpdateFSBLights()
    -- Don't update during lamp test UNLESS we're past 5 seconds
    if G_LampTestActive and G_LampTestTimer < 5.0 then
        return
    end

    -- FSB lights only work when Steuerstrom is active
    if not G_Steuerstrom then
        SetControlValue("FSB_Anlegen_LIT", 0)
        SetControlValue("FSB_Loesen_LIT", 0)
        return
    end

    -- Handle blinking state
    if G_FSB_Blinking then
        SetControlValue("FSB_Anlegen_LIT", lambda(G_FSB_BlinkState, 1, 0))
        -- FSB_Loesen_LIT is off during blinking
        SetControlValue("FSB_Loesen_LIT", 0)
    else
        -- Normal state: FSB_Anlegen_LIT is ON when brakes are applied
        SetControlValue("FSB_Anlegen_LIT", lambda(G_SAPBEngaged, 1, 0))
        -- FSB_Loesen_LIT is normally off (only turned on by button press in ParkingBrake)
        -- Don't override it here if the button is being pressed, but ensure it's off otherwise
        -- Since ParkingBrake handles turning it on, we just make sure it's off by default
        if G_SAPBEngaged then
            -- If brake is engaged, the release button shouldn't show confirmation light
            SetControlValue("FSB_Loesen_LIT", 0)
        end
        -- If brake is not engaged, ParkingBrake function will handle the light based on button state
    end
end

-- Add this to your TimedThings function (or create UpdateFSB function called from Update)
function UpdateFSB(dt)
    -- Handle blinking sequence
    if G_FSB_Blinking then
        G_FSB_BlinkTimer = G_FSB_BlinkTimer + dt

        -- Blink every 0.5 seconds (5 complete blinks = 10 transitions in 5 seconds)
        if G_FSB_BlinkTimer >= 0.5 then
            G_FSB_BlinkTimer = 0
            G_FSB_BlinkState = not G_FSB_BlinkState

            -- Count complete blinks (only when turning ON)
            if G_FSB_BlinkState then
                G_FSB_BlinkCount = G_FSB_BlinkCount + 1
            end

            UpdateFSBLights()

            -- After 5 blinks (5 seconds), apply or release the brake
            if G_FSB_BlinkCount >= 5 then
                G_FSB_Blinking = false
                G_FSB_BlinkCount = 0

                -- Check if this car has Fst=1 (engine car) - only engine cars physically apply FSB
                local fstValue = GetControlValue("Fst") or 0
                if fstValue > 0.5 then
                    if G_FSB_TargetState then
                        -- Apply the brake
                        G_SAPBEngaged = true
                        SetControlValue("HandBrake", 1)

                        -- Broadcast FSB status to all cars (only from controlling car)
                        if not G_RC then
                            SendConsistMessage(CM_FSB_STATUS, 1, 1) -- Forward
                            SendConsistMessage(CM_FSB_STATUS, 1, 0) -- Backward
                            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Federspeicherbremsen angelegt", 1, 0)
                        end
                    else
                        -- Release the brake
                        G_SAPBEngaged = false
                        SetControlValue("HandBrake", 0)

                        -- Broadcast FSB status to all cars (only from controlling car)
                        if not G_RC then
                            SendConsistMessage(CM_FSB_STATUS, 0, 1) -- Forward
                            SendConsistMessage(CM_FSB_STATUS, 0, 0) -- Backward
                            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Federspeicherbremsen gelöst", 1, 0)
                        end
                    end
                else
                    -- Not an engine car - just update local FSB state for display
                    -- The engine car will broadcast the actual state which we'll receive via CM_FSB_STATUS
                    G_SAPBEngaged = G_FSB_TargetState

                    if not G_RC then
                        -- SysCall("ScenarioManager:ShowAlertMessageExt", 
                        --     lambda(G_FSB_TargetState, "Federspeicherbremsen angelegt", "Federspeicherbremsen gelöst"), 1, 0)
                    end
                end

                UpdateFSBLights()
            end
        end
    end
end

function KompressorButton(name, value)
    if name ~= "Kompressor_BT" then
        return
    end

    if value < 0.99 then
        return
    end

    -- Check if Hauptschalter is active
    if not G_Hauptschalter then
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Kompressor kann ohne Hauptschalter nicht bedient werden", 1, 0)
        return
    end

    -- Toggle between automatic and manual mode
    G_Compressor_Manual = not G_Compressor_Manual

    if G_Compressor_Manual then
        -- Switched to manual mode
        SetControlValue("D_LIT", 2) -- Light up
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Kompressor manuell eingeschaltet", 1, 0)
    else
        -- Switched back to automatic mode
        SetControlValue("D_LIT", 1) -- Base illumination only
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Kompressor Automatikbetrieb", 1, 0)
    end
end

function KlimaNotAusButton(name, value)
    if name ~= "KlimaNotAus_BT" then
        return
    end

    if value < 0.99 then
        return
    end

    if not G_Steuerstrom then
        return
    end

    SysCall("ScenarioManager:ShowAlertMessageExt", "Klimaanlage Notaus / Arret d'urgence / Arresto di emergenza / Emergency stop", "Aktiviert\nActive\nAttivato\nActivated", 1.5, 0)

    -- Toggle emergency stop
    G_KlimaNotAus = not G_KlimaNotAus

    if G_KlimaNotAus then
        -- Emergency stop activated
        SetControlValue("KlimaNotAus_LIT", 2) -- Fully lit
        SysCall("ScenarioManager:ShowAlertMessageExt", "Klimaanlage Notaus / Arret clim. / Arresto clima / AC emergency stop", "Aktiviert\nActive\nAttivato\nActivated", 1.5, 0)

        -- Force AC sound to 0 IMMEDIATELY
        G_Klimaanlage_Target = 0
        G_Klimaanlage_Current = 0
        SetControlValue("Klimaanlage_SND", 0)
        G_Klimaanlage_DelayTimer = 0
        G_Klimaanlage_IsTransitioning = false
        G_Klimaanlage_TransitionTimer = 0
    else
        -- Emergency stop deactivated
        SetControlValue("KlimaNotAus_LIT", 1) -- Base illumination
        SysCall("ScenarioManager:ShowAlertMessageExt", "Klimaanlage Notaus / Arret clim. / Arresto clima / AC emergency stop", "Deaktiviert\nDesactive\nDisattivato\nDeactivated", 1.5, 0)

        -- Resume normal AC operation based on switch position
        if G_Steuerstrom then
            G_Klimaanlage_Target = G_Klimaanlage_SwitchPosition
            G_Klimaanlage_DelayTimer = G_Klimaanlage_Delay
        end
    end
end

function SchleuderbremseButton(name, value)
    if name ~= "Schleuderbremse_BT" then
        return
    end

    -- Hold button - active only while pressed
    -- Can be pressed when rolling, but not when braking
    if not G_Steuerstrom then
        G_Schleuderbremse_Manual = false
        return
    end
    
    local brakeControl = GetControlValue("TrainBrakeControl") or 0
    
    if value > 0.99 and brakeControl < 0.01 then
        -- Button pressed and no driver brakes
        G_Schleuderbremse_Manual = true
    else
        -- Button released or driver brakes applied
        G_Schleuderbremse_Manual = false
    end
end

function ParkstellungButton(name, value)
    if name ~= "Parkstellung_BT" then
        return
    end

    -- Detect button press (rising edge)
    if value > 0.9 and not G_ParkstellungButtonPressed then
        G_ParkstellungButtonPressed = true

        -- Parkstellung button only works when Steuerstrom is active (but only check for local control)
        if not G_RC and not G_Steuerstrom then
            SysCall("ScenarioManager:ShowAlertMessageExt", "Parkstellung", "Braucht Steuerstrom\nNecessite courant de commande\nRichiede corrente di controllo\nRequires control current", 1.5, 0)
            return
        end

        if not G_Parkstellung then
            -- Check if controls are in correct position before allowing Parkstellung
            local bremsventilValue = Call("GetControlValue", "VirtualBrake", 0)
            local reverserValue = Call("GetControlValue", "Reverser", 0)

            -- Check if controls are in neutral position (required for all Parkstellung operations)
            local controlsInNeutral = (bremsventilValue < 0.1 and reverserValue >= -0.1 and reverserValue <= 0.1)

            -- NEW: If pantograph AND hauptschalter are both NOT on, and controls are neutral, raise them
            if not G_PantographRaised and not G_Hauptschalter then
                if not controlsInNeutral then
                    if not G_RC then
                        SysCall("ScenarioManager:ShowAlertMessageExt",
                            "Parkstellung", "Bremsventil auf Abschluss, Wendeschalter auf 0\nFrein sur isolement, inverseur sur 0\nFreno su isolamento, invertitore su 0\nBrake to isolation, reverser to 0",
                            2, 0)
                    end
                    return
                end

                -- Controls are in neutral, raise pantograph and set hauptschalter pending
                G_PantographRaising = true
                G_PantographTimer = 0
                G_HauptschalterPending = true
                G_ParkstellungPendingAfterHauptschalter = true -- Flag to enter Parkstellung after Hauptschalter activates
                TV_SetMainSwitch(true)
                SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 1)
                SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 0)
                -- SysCall("ScenarioManager:ShowAlertMessageExt", 
                --     "Pantograph wird hochgefahren, Hauptschalter und Parkstellung werden automatisch aktiviert", 1, 0)
                return
            end

            -- NEW: If both pantograph AND hauptschalter are already on, enter Parkstellung automatically
            if G_PantographRaised and G_Hauptschalter then
                if not controlsInNeutral then
                    if not G_RC then
                        SysCall("ScenarioManager:ShowAlertMessageExt",
                            "Parkstellung", "Bremse auf 0, Wendeschalter auf 0\nFrein sur 0, inverseur sur 0\nFreno su 0, invertitore su 0\nBrake to 0, reverser to 0",
                            2, 0)
                    end
                    return
                end

                -- Enter Parkstellung
                ParkstellungSet(true);
                SendConsistMessage(CM_SAPM_ENABLE, "", 1)
                SendConsistMessage(CM_SAPM_ENABLE, "", 0)
                return
            end

            -- OLD BEHAVIOR: Hauptschalter is required but pantograph may not be raised yet
            -- This handles the case where Hauptschalter is on but pantograph is still raising
            if not G_Hauptschalter then
                if not G_RC then
                    SysCall("ScenarioManager:ShowAlertMessageExt",
                        "Parkstellung", "Braucht Hauptschalter\nNecessite disjoncteur principal\nRichiede interruttore principale\nRequires main switch", 1.5, 0)
                end
                return
            end

            -- Bremsventil must be at 0 (< 0.1 = Füllstellung)
            -- VirtualThrottle must be at neutral (between 1.9 and 2.1)
            if bremsventilValue >= 0.1 then
                if not G_RC then
                    SysCall("ScenarioManager:ShowAlertMessageExt",
                        "Parkstellung", "Bremse auf 0\nFrein sur 0\nFreno su 0\nBrake to 0", 2, 0)
                end
                return
            end

            if reverserValue < -0.1 or reverserValue > 0.1 then
                if not G_RC then
                    SysCall("ScenarioManager:ShowAlertMessageExt",
                        "Parkstellung", "Wendeschalter auf 0\nInverseur sur 0\nInvertitore su 0\nReverser to 0", 2, 0)
                end
                return
            end

            -- Entering Parkstellung (old path for compatibility)
            if not G_PantographRaised and not G_Hauptschalter then
                G_PantographRaising = true
                G_PantographTimer = 0
                G_HauptschalterPending = true
                G_ParkstellungPendingAfterHauptschalter = true -- Flag to enter Parkstellung after Hauptschalter activates
                TV_SetMainSwitch(true)
                SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 1)
                SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 0)
            end

            ParkstellungSet(true);
            SendConsistMessage(CM_SAPM_ENABLE, "", 1)
            SendConsistMessage(CM_SAPM_ENABLE, "", 0)
        else
            ParkstellungSet(false);
            SendConsistMessage(CM_SAPM_DISABLE, "", 1)
            SendConsistMessage(CM_SAPM_DISABLE, "", 0)
        end
    elseif value < 0.1 then
        G_ParkstellungButtonPressed = false
    end
end

function ParkstellungSet(value, override)
    if G_Steuerstrom or override then
        G_Parkstellung = value
        if G_Parkstellung then
            G_Federspeicher = true;

            -- Apply FSB with blinking sequence when entering Parkstellung
            if not G_SAPBEngaged and not G_FSB_Blinking then
                -- Start blinking sequence for applying
                G_FSB_Blinking = true
                G_FSB_BlinkTimer = 0
                G_FSB_BlinkCount = 0
                G_FSB_BlinkState = true
                G_FSB_TargetState = true -- We want to apply

                -- Play sound when FSB is applied by Parkstellung
                SetControlValue("Federspeicher_SND", 1)

                -- Send message to all units in consist (only if this is the controlling car)
                if not G_RC then
                    SendConsistMessage(CM_SAPB_APPLY, 0, 1)
                    SendConsistMessage(CM_SAPB_APPLY, 0, 0)
                end

                -- SysCall("ScenarioManager:ShowAlertMessageExt", "Parkstellung aktiviert - FSB wird angelegt...", 1, 0)
            else
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "Parkstellung aktiviert", 1, 0)
            end
        else
            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Parkstellung deaktiviert", 1, 0)
        end

        -- Update Parkstellung indicator light
        SetControlValue("Parkstellung_LIT", lambda(G_Parkstellung, 1, 0))
    end
end

function CabLightControl(name, value)
    if name == "Fstandbeleuchtung_BT" then
        if value >= 0.99 then
            -- Toggle the cab light state
            G_CabLight = not G_CabLight

            -- Set the control value based on the new state
            if G_CabLight then
                G_CabLight = true;
                SetControlValue("CabLight", 1)
                Call("CabLight:SetColour", 0.9211618, 0.9414937, 0.6887967)
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "Cab Light Enabled", 1, 0)
            else
                G_CabLight = false;
                SetControlValue("CabLight", 0)
                Call("CabLight:SetColour", 0, 0, 0)
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "Cab Light Disabled", 1, 0)
            end
        end
    end
end
--------------------------------------------------------------------------------
-- STEUERSTROM (Control Current) System
--------------------------------------------------------------------------------

function SteuerstromSwitch(name, value)
    if name ~= "Steuerstrom_SW" then
        return
    end

    -- Turn off alarm sound when switch is moved to OFF
    if value < 0.01 then
        SetControlValue("Steuerstrom_SND", 0)
        G_SteuerstromAlarmActive = false
        -- Broadcast alarm clear to all cabs
        Call("SendConsistMessage", CM_STEUERSTROM_ALARM_CLEAR, 0, 0)
        Call("SendConsistMessage", CM_STEUERSTROM_ALARM_CLEAR, 0, 1)
    end
    if value > 0.99 and not G_ThisCabHasSteuerstrom then
        -- Check if another cab already has Steuerstrom
        if G_SteuerstromMasterCabID ~= 0 and G_SteuerstromMasterCabID ~= G_ThisCabID then
            -- Another cab has Steuerstrom active - reject and trigger alarm
            SetControlValue("Steuerstrom_SND", 1)
            SysCall("ScenarioManager:ShowAlertMessageExt", "Steuerstrom", "Bereits in anderem Fuehrerstand aktiv\nDeja actif dans autre cabine\nGia attivo in altra cabina\nAlready active in other cab", 2, 0)
            return
        end

        -- Claim Steuerstrom by broadcasting our cab ID
        SendConsistMessage(CM_STEUERSTROM_CLAIM, G_ThisCabID, 0)
        SendConsistMessage(CM_STEUERSTROM_CLAIM, G_ThisCabID, 1)

        -- Set this cab as master
        G_ThisCabHasSteuerstrom = true
        G_SteuerstromMasterCabID = G_ThisCabID

        G_RC = false
        G_cabActive = true
        G_Steuerstrom = true
        G_VoltmeterActive = true

        -- Set Steuerstrom_On ControlValue
        SetControlValue("Steuerstrom_On", 1)

        -- Restore Zugsammelschiene if Parkstellung is active and Hauptschalter is on
        if G_Parkstellung and G_Hauptschalter then
            G_ZugsammelschieneLIT = true
            SetControlValue("Zugsammelschiene_LIT", 1)
            -- Broadcast to entire consist
            SendConsistMessage(CM_ZUGSAMMELSCHIENE_ON, 0, 1)
            SendConsistMessage(CM_ZUGSAMMELSCHIENE_ON, 0, 0)
        end

        -- Broadcast voltmeter state to all cabs (separate from G_Steuerstrom for display only)
        SendConsistMessage(CM_VOLTMETER_ON, 0, 0)
        SendConsistMessage(CM_VOLTMETER_ON, 0, 1)

        -- DEBUG
        -- SysCall("ScenarioManager:ShowAlertMessageExt", 
        --     "After activation - G_RC:" .. tostring(G_RC) .. 
        --     " G_Steuerstrom:" .. tostring(G_Steuerstrom), 2, 0)

        TIMS_SyncOnCabActivation()

        -- Turn on headlights if Notlicht is not active
        if not G_NotlichtActive then
            SetControlValue("Headlights", 1)
        end

        Call("Parklicht:Activate", 0)
        Call("*:ActivateNode", "lights_parklicht", 0)
        SendConsistMessage(CM_DISABLE_PARKLIGHT, 0, 1)
        SendConsistMessage(CM_DISABLE_PARKLIGHT, 0, 0)
        LampTest()
        UpdateIndicatorLights()
        Call("SendConsistMessage", CM_DOMINANT_TRAIN, 0, 1)
        Call("SendConsistMessage", CM_DOMINANT_TRAIN, 0, 0)
        WiperSteuerstromOn()  -- Resume wipers if controller still active

        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Steuerstrom activated", 1, 0)
    elseif value < 0.01 and G_ThisCabHasSteuerstrom then
        -- Check if NOT in Parkstellung - if so, emergency shutdown
        if not G_Parkstellung then
            -- Get current speed
            local currentSpeed = math.abs(Call("GetSpeed") or 0) * 3.6 -- km/h
            
            -- If train is moving, trigger Zwangsbremsung
            if currentSpeed > 1.0 then
                G_Zwangsbremse = true
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "Zwangsbremsung: Steuerstrom ohne Parkstellung ausgeschaltet!", 2, 0)
            end
            
            -- Lower pantograph (this also turns off Hauptschalter)
            PantographLower()
            TV_SetMainSwitch(false)
            SendConsistMessage(CM_PANTOGRAPH_LOWER, "", 1)
            SendConsistMessage(CM_PANTOGRAPH_LOWER, "", 0)
        end
        
        -- Deactivate all systems
        DeactivateSteuerstrom()
        G_SteuerstromMasterCabID = 0

        -- Broadcast release to all other cabs so they can activate Steuerstrom
        SendConsistMessage(CM_STEUERSTROM_RELEASE, 0, 0)
        SendConsistMessage(CM_STEUERSTROM_RELEASE, 0, 1)

        -- Broadcast parking light activation
        SendConsistMessage(CM_ENABLE_PARKLIGHT, 0, 1)
        SendConsistMessage(CM_ENABLE_PARKLIGHT, 0, 0)

        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Steuerstrom deactivated", 1, 0)
    end
end

--------------------------------------------------------------------------------
-- FAHRGASTRAUMBELEUCHTUNG (Passenger Lighting)
--------------------------------------------------------------------------------

function FahrgastraumbeleuchtungButton(name, value)
    if name == "FGBEin_BT" then
        if value > 0.99 then
            if not G_RC and not G_Steuerstrom then
                return
            end
            if not G_FahrgastraumEinButtonPressed then
                G_FahrgastraumEinButtonPressed = true
                if not G_FahrgastraumbeleuchtungOn then
                    G_FahrgastraumbeleuchtungOn = true
                    -- Turn on lit interior, turn off normal interior
                    Call("*:ActivateNode", "Innenraum_lit", 1)
                    Call("*:ActivateNode", "Innenraum", 0)
                    -- Turn off the "Aus" indicator light
                    SetControlValue("Fahrgastbeleuchtung_Aus_LIT", 0)
                    -- Update passengers in this car
                    if UpdatePassengers then
                        UpdatePassengers()
                    end
                    -- Send consist message to all cars to turn lights ON
                    SendConsistMessage(CM_FAHRGASTRAUM_ON, 0, 1) -- Forward
                    SendConsistMessage(CM_FAHRGASTRAUM_ON, 0, 0) -- Backward
                end
            end
        else
            G_FahrgastraumEinButtonPressed = false
        end
    elseif name == "FGBAus_BT" then
        if value > 0.99 then
            if not G_RC and not G_Steuerstrom then
                return
            end
            if not G_FahrgastraumAusButtonPressed then
                G_FahrgastraumAusButtonPressed = true
                if G_FahrgastraumbeleuchtungOn then
                    G_FahrgastraumbeleuchtungOn = false
                    -- Turn off lit interior, turn on normal interior
                    Call("*:ActivateNode", "Innenraum_lit", 0)
                    Call("*:ActivateNode", "Innenraum", 1)
                    -- Turn on the "Aus" indicator light
                    SetControlValue("Fahrgastbeleuchtung_Aus_LIT", 1)
                    -- Update passengers in this car
                    if UpdatePassengers then
                        UpdatePassengers()
                    end
                    -- Send consist message to all cars to turn lights OFF
                    SendConsistMessage(CM_FAHRGASTRAUM_OFF, 0, 1) -- Forward
                    SendConsistMessage(CM_FAHRGASTRAUM_OFF, 0, 0) -- Backward
                end
            end
        else
            G_FahrgastraumAusButtonPressed = false
        end
    end
end

--------------------------------------------------------------------------------
-- NOTLICHT (Emergency Light) Button
--------------------------------------------------------------------------------

function NotlichtButton(name, value)
    if name ~= "Notlicht_BT" then
        return
    end
    if value > 0.99 then
        if not G_RC and not G_Steuerstrom then
            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Notlicht kann ohne Steuerstrom nicht bedient werden", 1, 0)
            return
        end
        if not G_NotlichtButtonPressed then
            G_NotlichtButtonPressed = true
            G_NotlichtActive = not G_NotlichtActive

            if G_NotlichtActive then
                SetControlValue("Notlicht_LIT", 2) -- Bright when active
                -- Turn off headlights when Notlicht is active
                SetControlValue("Headlights", 0)
                SendConsistMessage(CM_NOTLICHT_ON, 0, 1)
                SendConsistMessage(CM_NOTLICHT_ON, 0, 0)
                if not G_RC then
                    -- SysCall("ScenarioManager:ShowAlertMessageExt", "Notlicht aktiviert", 1, 0)
                end
            else
                SetControlValue("Notlicht_LIT", 1) -- Dim when inactive
                -- Turn on headlights if Steuerstrom is active
                if G_Steuerstrom then
                    SetControlValue("Headlights", 1)
                end
                SendConsistMessage(CM_NOTLICHT_OFF, 0, 1)
                SendConsistMessage(CM_NOTLICHT_OFF, 0, 0)
                if not G_RC then
                    -- SysCall("ScenarioManager:ShowAlertMessageExt", "Notlicht deaktiviert", 1, 0)
                end
            end

            CheckCouplings()
            UpdateNotlicht()
        end
    else
        G_NotlichtButtonPressed = false
    end
end

function PantographButton(name, value)
    if name ~= "Pantograph_BT" then
        return
    end

    if value < 0.99 then
        return
    end

    if not G_Steuerstrom then
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Cannot operate pantograph - Steuerstrom not active", 1, 0)
        return
    end

    if G_PantographRaising or G_PantographLowering then
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Pantograph already in motion", 1, 0)
        return
    end

    if not G_PantographRaised then
        TV_SetMainSwitch(true)
        PantographRaise()
        SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 1)
        SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 0)
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Raising pantographs", 1, 0)
    else
        -- Check if Parkstellung is active
        if G_Parkstellung then
            SysCall("ScenarioManager:ShowAlertMessageExt", "Pantograph / Pantographe", "Nicht in Parkstellung absenken\nPas descendre en position parking\nNon abbassare in posizione parcheggio\nCannot lower in parking mode", 2, 0)
            return
        end

        PantographLower()
        TV_SetMainSwitch(false)
        SendConsistMessage(CM_PANTOGRAPH_LOWER, "", 1)
        SendConsistMessage(CM_PANTOGRAPH_LOWER, "", 0)
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Lowering pantographs", 1, 0)
    end

    UpdateIndicatorLights()
end

function PantographRaise()
    if not G_PantographRaising and not G_PantographRaised then
        G_PantographRaising = true
        G_PantographTimer = 0
    end
end

function PantographLower()
    if not G_PantographLowering and G_PantographRaised then
        if G_Hauptschalter then
            G_Hauptschalter = false
            G_HauptschalterActivationTimer = 0
            -- Start ramp down (7.3 seconds)
            G_HauptschalterSoundActive = false
            G_HauptschalterSoundRampingDown = true
            G_HauptschalterSoundTimer = 0
            G_HauptschalterLitTimer = 0
            SetControlValue("Hauptschalter_SND", 1) -- Start at 1, will ramp down to 0
            SetControlValue("Hauptschalter_LIT", 1)
            SendConsistMessage(CM_HAUPTSCHALTER_OFF, 0, 1)
            SendConsistMessage(CM_HAUPTSCHALTER_OFF, 0, 0)
        end
        G_PantographLowering = true
        G_PantographTimer = 0
    end
end

function UpdatePantograph(dt)
    if G_PantographRaising then
        G_PantographTimer = G_PantographTimer + dt
        local progress = math.min(G_PantographTimer / G_PantographRaiseTime, 1.0)

        SetAnimTime("pantograph", progress * 2)

        if G_PantographTimer >= G_PantographRaiseTime then
            G_PantographRaising = false
            G_PantographRaised = true
            SetControlValue("PantographControl", 1)

            -- Check if Hauptschalter was pending
            if G_HauptschalterPending then
                G_HauptschalterPending = false
                G_Hauptschalter = true
                G_HauptschalterPressureDrop = true -- Trigger SL pressure drop
                G_HauptschalterActivationTimer = 0 -- Start 7-second delay

                -- Check if throttle is not at 0 - if so, set Fahrsperre
                local throttleValue = GetControlValue("VirtualThrottle") or 0
                if not (throttleValue >= -0.1 and throttleValue <= 0.9) then
                    G_FahrsperreActive = true
                    -- SysCall("ScenarioManager:ShowAlertMessageExt", 
                    --     "Fahrsperre: Fahrhebel auf 0 stellen", 2, 0)
                end
                G_ZugsammelschieneTimer = 0
                SetControlValue("Zugsammelschiene_LIT", 0)

                -- Stop any ramp down in progress and start ramp up
                G_HauptschalterSoundRampingDown = false
                G_HauptschalterSoundTimer = 0
                G_HauptschalterSoundActive = true
                G_HauptschalterLitTimer = 0
                SetControlValue("Hauptschalter_SND", 0) -- Start at 0, will ramp to 1

                SendConsistMessage(CM_HAUPTSCHALTER_ON, 0, 1)
                SendConsistMessage(CM_HAUPTSCHALTER_ON, 0, 0)

                -- Check if we should automatically enter Parkstellung
                if G_ParkstellungPendingAfterHauptschalter then
                    G_ParkstellungPendingAfterHauptschalter = false
                    ParkstellungSet(true)
                    SendConsistMessage(CM_SAPM_ENABLE, "", 1)
                    SendConsistMessage(CM_SAPM_ENABLE, "", 0)
                    -- SysCall("ScenarioManager:ShowAlertMessageExt", "Pantograph raised - Main switch closed, Parkstellung aktiviert",
                    -- 1, 0)
                else
                    -- SysCall("ScenarioManager:ShowAlertMessageExt", "Pantograph raised - Main switch closed, 15kV connected",
                    -- 1, 0)
                end
            else
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "Pantograph raised", 1, 0)
            end

            UpdateIndicatorLights()
        end

    elseif G_PantographLowering then
        G_PantographTimer = G_PantographTimer + dt
        local progress = 1.0 - math.min(G_PantographTimer / G_PantographRaiseTime, 1.0)

        SetAnimTime("pantograph", progress * 2)

        if G_PantographTimer >= G_PantographRaiseTime then
            G_PantographLowering = false
            G_PantographRaised = false
            SetControlValue("PantographControl", 0)

            if G_Hauptschalter then
                G_Hauptschalter = false
                G_HauptschalterActivationTimer = 0
                G_ZugsammelschieneLIT = false
                G_ZugsammelschieneTimer = 0
                SetControlValue("Zugsammelschiene_LIT", 0)
                -- Broadcast Zugsammelschiene off to entire consist
                SendConsistMessage(CM_ZUGSAMMELSCHIENE_OFF, 0, 1)
                SendConsistMessage(CM_ZUGSAMMELSCHIENE_OFF, 0, 0)
                -- Start ramp down (7.3 seconds)
                G_HauptschalterSoundActive = false
                G_HauptschalterSoundRampingDown = true
                G_HauptschalterSoundTimer = 0
                G_HauptschalterLitTimer = 0
                SetControlValue("Hauptschalter_SND", 1) -- Start at 1, will ramp down to 0
                SendConsistMessage(CM_HAUPTSCHALTER_OFF, 0, 1)
                SendConsistMessage(CM_HAUPTSCHALTER_OFF, 0, 0)
            end

            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Pantograph lowered", 1, 0)
            UpdateIndicatorLights()
        end
    end
end

--------------------------------------------------------------------------------
-- PNEUMATIC BRAKE INDICATORS
--------------------------------------------------------------------------------

function UpdatePneumaticBrakeIndicators()
    -- Don't update during lamp test UNLESS we're past 5 seconds
    if G_LampTestActive and G_LampTestTimer < 5.0 then
        return
    end

    if not G_Steuerstrom then
        SetControlValue("Bremse_Angelegt_LIT", 0)
        SetControlValue("Bremsprobe_BremseGeloest_LIT", 0)
        -- Deactivate brake test mode if Steuerstrom is lost
        if G_BrakeTestMode then
            G_BrakeTestMode = false
        end
        return
    end

    local bcPressure = Call("GetControlValue", "BCPressure", 0)

    if bcPressure then
        -- Brake is applied when BCPressure > 0
        if bcPressure > 0.1 then
            SetControlValue("Bremse_Angelegt_LIT", 1)
            -- Bremsprobe light is OFF when brakes are applied (in brake test mode)
            if G_BrakeTestMode then
                SetControlValue("Bremsprobe_BremseGeloest_LIT", 0)
            else
                SetControlValue("Bremsprobe_BremseGeloest_LIT", 0)
            end
        else
            -- Brake is released when BCPressure is 0 or very low
            SetControlValue("Bremse_Angelegt_LIT", 0)
            -- Bremsprobe light is ON when brakes are released (only in brake test mode)
            if G_BrakeTestMode then
                SetControlValue("Bremsprobe_BremseGeloest_LIT", 1)
            else
                SetControlValue("Bremsprobe_BremseGeloest_LIT", 0)
            end
        end
    end
    
    -- Deactivate brake test mode if FSB is released
    if G_BrakeTestMode and not G_SAPBEngaged then
        G_BrakeTestMode = false
        SetControlValue("Bremsprobe_BremseGeloest_LIT", 0)
    end
end

--------------------------------------------------------------------------------
-- HAUPTSCHALTER (Main Switch) System
--------------------------------------------------------------------------------

function HauptschalterButton(name, value)
    if name ~= "Hauptschalter_BT" then
        return
    end

    if value < 0.99 then
        return
    end

    -- Prevent button spam: Don't allow button press if sound ramp is in progress
    if G_HauptschalterSoundActive then
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Hauptschalter wird eingeschaltet - bitte warten (13s)", 1, 0)
        return
    end

    if G_HauptschalterSoundRampingDown then
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Hauptschalter wird ausgeschaltet - bitte warten (7s)", 1, 0)
        return
    end

    if not G_Steuerstrom then
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Cannot operate main switch - Steuerstrom not active", 1, 0)
        return
    end

    if not G_PantographRaised and not G_PantographRaising then
        -- Start raising pantograph and mark that we want to close Hauptschalter after
        G_PantographRaising = true
        G_PantographTimer = 0
        G_HauptschalterPending = true
        SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 1)
        SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 0)
        TV_SetMainSwitch(true)
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Raising pantograph - Main switch will activate when connected",
        -- 1, 0)
    elseif G_PantographRaising then
        -- Pantograph is still raising, just set pending
        TV_SetMainSwitch(true)
        G_HauptschalterPending = true
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Main switch will activate when pantograph is connected", 1, 0)
    elseif G_PantographRaised and not G_Hauptschalter then
        -- Pantograph is up, close the switch immediately
        TV_SetMainSwitch(true)
        G_Hauptschalter = true
        G_HauptschalterPressureDrop = true -- Trigger SL pressure drop
        G_HauptschalterActivationTimer = 0 -- Start 7-second delay

        -- Check if throttle is not at 0 - if so, set Fahrsperre
        local throttleValue = GetControlValue("VirtualThrottle") or 0
        if not (throttleValue >= -0.1 and throttleValue <= 0.9) then
            G_FahrsperreActive = true
            -- SysCall("ScenarioManager:ShowAlertMessageExt", 
            --     "Fahrsperre: Fahrhebel auf 0 stellen", 2, 0)
        end
        G_ZugsammelschieneTimer = 0
        G_ZugsammelschieneLIT = false
        SetControlValue("Zugsammelschiene_LIT", 0)

        -- Stop any ramp down in progress and start ramp up
        G_HauptschalterSoundRampingDown = false
        G_HauptschalterSoundTimer = 0
        G_HauptschalterSoundActive = true
        G_HauptschalterLitTimer = 0
        SetControlValue("Hauptschalter_SND", 0) -- Start at 0, will ramp to 1

        SendConsistMessage(CM_HAUPTSCHALTER_ON, 0, 1)
        SendConsistMessage(CM_HAUPTSCHALTER_ON, 0, 0)
        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Main switch closed - 15kV connected", 1, 0)
    elseif G_Hauptschalter then
        -- Check if Parkstellung is active
        if G_Parkstellung then
            -- SysCall("ScenarioManager:ShowAlertMessageExt", "Hauptschalter kann in Parkstellung nicht ausgeschaltet werden", 2, 0)
            return
        end

        -- Switch is closed, open it
        TV_SetMainSwitch(false)
        G_Hauptschalter = false
        G_HauptschalterActivationTimer = 0
        G_ZugsammelschieneLIT = false
        G_ZugsammelschieneTimer = 0
        SetControlValue("Zugsammelschiene_LIT", 0)
        -- Broadcast Zugsammelschiene off to entire consist
        SendConsistMessage(CM_ZUGSAMMELSCHIENE_OFF, 0, 1)
        SendConsistMessage(CM_ZUGSAMMELSCHIENE_OFF, 0, 0)

        -- Stop sound ramp up and start ramp down (7.3 seconds)
        G_HauptschalterSoundActive = false
        G_HauptschalterSoundRampingDown = true
        G_HauptschalterSoundTimer = 0
        G_HauptschalterLitTimer = 0
        SetControlValue("Hauptschalter_SND", 1) -- Start at 1, will ramp down to 0

        SendConsistMessage(CM_HAUPTSCHALTER_OFF, 0, 1)
        SendConsistMessage(CM_HAUPTSCHALTER_OFF, 0, 0)

        -- SysCall("ScenarioManager:ShowAlertMessageExt", "Main switch opened", 1, 0)
    end

    UpdateIndicatorLights()
end

--------------------------------------------------------------------------------
-- MAGNETSCHIENENBREMSE (Magnetic Track Brake) System
--------------------------------------------------------------------------------

function MagnetbrakeButton(name, value)
    if name ~= "Magnetschienenbremse_BT" then
        return
    end

    -- Button pressed (value > 0.5)
    G_MagnetbrakeButtonPressed = (value > 0.5)
end

--------------------------------------------------------------------------------
-- INDICATOR LIGHTS & LAMP TEST
--------------------------------------------------------------------------------

function UpdateIndicatorLights()
    if G_Steuerstrom then
        -- Normal operation with Steuerstrom active
        -- Don't update Pantograph and Hauptschalter lights during lamp test (first 5 seconds)
        if not (G_LampTestActive and G_LampTestTimer < 5.0) then
            SetControlValue("Pantograph_LIT", G_PantographRaised and 0 or 1)
            -- Hauptschalter_LIT: only turns off (green light) after 5 seconds have passed
            if G_Hauptschalter and G_HauptschalterLitTimer >= 5.0 then
                SetControlValue("Hauptschalter_LIT", 0) -- Green light (off) = Hauptschalter is ON
            else
                SetControlValue("Hauptschalter_LIT", 1) -- White light (on) = Hauptschalter is OFF or still warming up
            end
        end
        
        -- Parkstellung_LIT: Don't update during lamp test (first 5 seconds)
        if not (G_LampTestActive and G_LampTestTimer < 5.0) then
            SetControlValue("Parkstellung_LIT", lambda(G_Parkstellung, 1, 0))
        end
        SetControlValue("Fuehrerstandbeleuchtung_LIT", lambda(G_CabLight, 1, 0))

        -- GSM-R stays on when active
        SetControlValue("GSM-R_lit", lambda(G_GSMR_Active, 1, 0))

        -- Notlicht indicator (fully lit when active)
        SetControlValue("Notlicht_LIT", lambda(G_NotlichtActive, 2, 1))

        -- Scheinwerfer indicator (1 when on, 2 when Fernlicht/high beam is active)
        SetControlValue("Scheinwerfer_LIT", lambda(G_ScheinwerferOn, 2, 1))

        -- Kompressor indicator (1 for base illumination, 2 when manually on)
        SetControlValue("D_LIT", G_Compressor_Manual and 2 or 1)
        
        -- Schleuderbremse indicator (1 for ready, 2 when active)
        SetControlValue("Schleuderbremse_LIT", G_Schleuderbremse_Active and 2 or 1)

        -- KlimaNotAus indicator (1 for base illumination, 2 when emergency stop active)
        SetControlValue("KlimaNotAus_LIT", G_KlimaNotAus and 2 or 1)
        -- Fahrgastbeleuchtung_Aus indicator (on when passenger lights are OFF)
        -- Don't update during lamp test (first 5 seconds)
        if not (G_LampTestActive and G_LampTestTimer < 5.0) then
            SetControlValue("Fahrgastbeleuchtung_Aus_LIT", lambda(not G_FahrgastraumbeleuchtungOn, 1, 0))
        end

        -- Fahrsperre indicator (lights up when interlock is active)
        CheckFahrsperre()
        SetControlValue("Fahrsperre_LIT", G_Fahrsperre and 1 or 0)

        -- Update FSB lights based on state
        UpdateFSBLights()

        -- Update pneumatic brake indicators
        UpdatePneumaticBrakeIndicators()
    else
        -- When Steuerstrom is OFF, only Parkstellung and Fuehrerstandbeleuchtung can be on
        SetControlValue("Parkstellung_LIT", lambda(G_Parkstellung, 1, 0))
        SetControlValue("Fuehrerstandbeleuchtung_LIT", lambda(G_CabLight, 1, 0))
        SetControlValue("Schleuderbremse_LIT", 0)

        -- Turn off all other indicator lights
        SetControlValue("Pantograph_LIT", 0)
        SetControlValue("Hauptschalter_LIT", 0)
        SetControlValue("Fahrsperre_LIT", 0)
        SetControlValue("Zugsammelschiene_LIT", 0)
        SetControlValue("Notlicht_LIT", 0)
        SetControlValue("GSM-R_lit", 0)
        SetControlValue("Scheinwerfer_LIT", 0)
        SetControlValue("KlimaNotAus_LIT", 0)
        SetControlValue("Fahrgastbeleuchtung_Ein_LIT", 0)
        SetControlValue("D_LIT", 0)
        SetControlValue("Fahrgastbeleuchtung_Aus_LIT", 0)
        SetControlValue("Scheibenheizung_LIT", 0)
        SetControlValue("Fussheizung_LIT", 0)
        SetControlValue("HL_Nicht_Durchgaengig_LIT", 0)
        SetControlValue("Ueberbrueckung_Fahrsperre_LIT", 0)
        SetControlValue("Hilfsbetriebsstoerung_LIT", 0)
        SetControlValue("Notruf_WC_LIT", 0)
        SetControlValue("Notlauf_Federung_Steuerwagen_LIT", 0)
        SetControlValue("Tueroeffnung_Rollstuhl_LIT", 0)
        SetControlValue("Notlauf_Luftfederung_Steuerwagen_LIT", 0)
        SetControlValue("Haltanforderung_LIT", 0)
        SetControlValue("Traktionsstoerung_LIT", 0)
        SetControlValue("Quiettierung_LIT", 0)
        SetControlValue("FSB_Anlegen_LIT", 0)
        SetControlValue("FSB_Loesen_LIT", 0)
        SetControlValue("Bremse_Angelegt_LIT", 0)
        SetControlValue("Bremsprobe_BremseGeloest_LIT", 0)
        SetControlValue("Bremse_Abgesperrt_LIT", 0)
        SetControlValue("Magnetschienenbremse_LIT", 0)
        SetControlValue("Notbremsanforderung_LIT", 0)
        SetControlValue("TF_L_LIT", 0)
        SetControlValue("TV_LIT", 0)
        SetControlValue("TF_R_LIT", 0)
        SetControlValue("Schiebetritt_LIT", 0)
        SetControlValue("TFS_LIT", 0)
        SetControlValue("Manoever_LIT", 0)
        SetControlValue("ZUBQuittierung_lit", 0)

    end

    -- Update ZTB display (works in all modes)
    UpdateZTBDisplay()
end

function UpdateZugsammelschiene(dt)
    -- Only run the timer logic if this is the controlling cab (has Steuerstrom)
    -- Remote units will get Zugsammelschiene state via consist messages
    if G_Steuerstrom then
        -- Only count if main switch is closed and light isn't on yet
        if G_Hauptschalter and not G_ZugsammelschieneLIT then
            G_ZugsammelschieneTimer = G_ZugsammelschieneTimer + dt

            if G_ZugsammelschieneTimer >= G_ZugsammelschieneDelay then
                G_ZugsammelschieneLIT = true
                SetControlValue("Zugsammelschiene_LIT", 1)
                -- Broadcast to entire consist
                SendConsistMessage(CM_ZUGSAMMELSCHIENE_ON, 0, 1)
                SendConsistMessage(CM_ZUGSAMMELSCHIENE_ON, 0, 0)
                -- SysCall("ScenarioManager:ShowAlertMessageExt", "Zugsammelschiene energized", 1, 0)
            end
        elseif not G_Hauptschalter and G_ZugsammelschieneLIT then
            -- Turn off Zugsammelschiene if Hauptschalter is off
            G_ZugsammelschieneLIT = false
            G_ZugsammelschieneTimer = 0
            SetControlValue("Zugsammelschiene_LIT", 0)
            -- Broadcast to entire consist
            SendConsistMessage(CM_ZUGSAMMELSCHIENE_OFF, 0, 1)
            SendConsistMessage(CM_ZUGSAMMELSCHIENE_OFF, 0, 0)
        end
    end
    -- Note: Remote units (without Steuerstrom) receive Zugsammelschiene state via consist messages
end

--------------------------------------------------------------------------------
-- HAUPTSCHALTER TIMERS
--------------------------------------------------------------------------------

function UpdateHauptschalterTimers(dt)
    -- Handle Hauptschalter sound ramp up (13 seconds, 0 to 1)
    if G_HauptschalterSoundActive then
        G_HauptschalterSoundTimer = G_HauptschalterSoundTimer + dt

        -- Calculate linear ramp from 0 to 1 over 13 seconds
        local soundValue = math.min(1.0, G_HauptschalterSoundTimer / 13.65)
        SetControlValue("Hauptschalter_SND", soundValue)

        -- Stop ramping when we reach 13 seconds
        if G_HauptschalterSoundTimer >= 13.65 then
            G_HauptschalterSoundActive = false
            SetControlValue("Hauptschalter_SND", 1)
        end
    end

    -- Handle Hauptschalter sound ramp down (7.3 seconds, 1 to 0)
    if G_HauptschalterSoundRampingDown then
        G_HauptschalterSoundTimer = G_HauptschalterSoundTimer + dt

        -- Calculate linear ramp from 1 to 0 over 7.3 seconds
        local soundValue = math.max(0.0, 1.0 - (G_HauptschalterSoundTimer / 7.6))
        SetControlValue("Hauptschalter_SND", soundValue)

        -- Stop ramping when we reach 7.3 seconds
        if G_HauptschalterSoundTimer >= 7.6 then
            G_HauptschalterSoundRampingDown = false
            SetControlValue("Hauptschalter_SND", 0)
        end
    end

    -- Handle Hauptschalter light delay (5 seconds until fully lit)
    if G_Hauptschalter and G_HauptschalterLitTimer < 5.0 then
        G_HauptschalterLitTimer = G_HauptschalterLitTimer + dt

        -- After 5 seconds, update the light to show it's fully on (0 = off indicator light)
        if G_HauptschalterLitTimer >= 5.0 then
            UpdateIndicatorLights()
        end
    elseif not G_Hauptschalter then
        -- Reset timer when Hauptschalter is off
        G_HauptschalterLitTimer = 0
    end
end

--------------------------------------------------------------------------------
-- NEEDLE ANIMATIONS (Exponential)
--------------------------------------------------------------------------------

function UpdateNeedles(dt)
    -- Voltmeter_klein: uses G_VoltmeterActive which is synchronized across all cabs
    -- This is separate from G_Steuerstrom to show power state without affecting control logic
    local voltmeterTarget = lambda(G_VoltmeterActive, 1, 0)
    G_VoltmeterCurrent = ExponentialMove(dt, G_VoltmeterCurrent, voltmeterTarget, 2.0)
    SetControlValue("Voltmeter_klein", G_VoltmeterCurrent)

    -- Pantoneedle: different speeds for up vs down
    local pantoTarget = 0
    local pantoSpeed = 0.25 -- Default speed

    if G_PantographLowering then
        pantoTarget = 0
        pantoSpeed = 1.0 -- 4x faster when going down
    elseif G_PantographRaised then
        pantoTarget = 1
        pantoSpeed = 0.25 -- Original speed when going up
    else
        pantoTarget = 0
    end

    G_PantoNeedleCurrent = ExponentialMove(dt, G_PantoNeedleCurrent, pantoTarget, pantoSpeed)
    SetControlValue("Pantonadel", G_PantoNeedleCurrent)
end

function ExponentialMove(dt, current, target, speed)
    -- Exponential smoothing: moves quickly at first, then slows down
    local diff = target - current
    local change = diff * (1 - math.exp(-speed * dt))
    local newValue = current + change

    -- Snap to target if very close
    if math.abs(target - newValue) < 0.001 then
        return target
    end

    return newValue
end

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

function SetAnimTime(name, value)
    if Call("*:ControlExists", name, 0) then
        Call("*:SetTime", name, value)
    end
end

function LightTurnedOn(lightName, state)
    if Call("*:ControlExists", lightName, 0) then
        if state then
            Call(lightName .. ":Activate", 1)
        else
            Call(lightName .. ":Activate", 0)
        end
    end
end

--------------------------------------------------------------------------------
-- FAHRSPERRE (Driving Interlock) System
--------------------------------------------------------------------------------

function CheckFahrsperre()
    local doorsLeft = Call("GetControlValue", "DoorsOpenCloseLeft", 0)
    local doorsRight = Call("GetControlValue", "DoorsOpenCloseRight", 0)
    local tuerSchleife = Call("GetControlValue", "TuerSchleife", 0)

    -- Fahrsperre is active if:
    -- - Any door open signals are active (value = 1)
    -- - Any doors are actually physically open (TuerSchleife = 1)
    -- - Parking brake is engaged

    -- if doorsLeft > 0.5 or doorsRight > 0.5 or tuerSchleife > 0.5 or G_SAPBEngaged then
    --     G_Fahrsperre = true
    --     return true
    -- else
    --     G_Fahrsperre = false
    --     return false
    -- end
end

function CanApplyPower()
    CheckFahrsperre()

    if G_Fahrsperre then
        return false
    end

    return G_Steuerstrom and G_PantographRaised and G_Hauptschalter
end
function KlimaanlageSwitch(name, value)
    if name ~= "Klimaanlage_SW" then
        return
    end

    -- Determine desired level based on switch position
    local desiredLevel = 0
    if value < 0.5 then
        desiredLevel = 0 -- Position 0: Off
    elseif value < 1.5 then
        desiredLevel = 1 -- Position 1: Low
    elseif value < 2.5 then
        desiredLevel = 2 -- Position 2: Medium
    else
        desiredLevel = 3 -- Position 3: High
    end

    -- Store the switch position (even when Steuerstrom is off, so we can resume)
    G_Klimaanlage_SwitchPosition = desiredLevel

    -- Only apply if Steuerstrom is ON
    if G_Steuerstrom then
        if desiredLevel ~= G_Klimaanlage_Target then
            G_Klimaanlage_Target = desiredLevel
            G_Klimaanlage_DelayTimer = G_Klimaanlage_Delay -- Start 5-second delay
        end
    end
end

function InstrumentenbeleuchtungControl(name, value)
    if name ~= "Instrumentenbeleuchtung_SW" then
        return
    end

    local range = 1.0 * value
    Call("Tacholicht_RBDe:SetRange", range * 0.6)
    Call("Tacholicht_ABt:SetRange", range * 0.6)
    Call("InstrumentenBeleuchtung_L:SetRange", 0.2 + (range * 0.35))
    Call("InstrumentenBeleuchtung_R:SetRange", range)

end

function UpdateKlimaanlage(dt)
    -- Handle KlimaNotAus (emergency stop) - force AC to 0
    if G_KlimaNotAus then
        if G_Klimaanlage_Target ~= 0 then
            G_Klimaanlage_Target = 0
            G_Klimaanlage_DelayTimer = 0
            G_Klimaanlage_IsTransitioning = true
            G_Klimaanlage_TransitionTimer = 0
            G_Klimaanlage_StartValue = G_Klimaanlage_Current
            G_Klimaanlage_TotalTransitionTime = G_Klimaanlage_TransitionTime
        end
        -- Skip normal processing when emergency stop is active
        if G_Klimaanlage_Target == 0 and not G_Klimaanlage_IsTransitioning then
            SetControlValue("Klimaanlage_SND", 0)
            return
        end
    end

    -- Handle Steuerstrom state changes
    if not G_Steuerstrom then
        -- Steuerstrom is OFF - smoothly turn off AC
        if G_Klimaanlage_Target ~= 0 then
            G_Klimaanlage_Target = 0
            G_Klimaanlage_DelayTimer = 0 -- No delay when turning off due to Steuerstrom loss
            -- Start transition immediately
            G_Klimaanlage_IsTransitioning = true
            G_Klimaanlage_TransitionTimer = 0
            local distance = math.abs(G_Klimaanlage_Target - G_Klimaanlage_Current)
            G_Klimaanlage_TotalTransitionTime = distance * G_Klimaanlage_TransitionTime
        end
    else
        -- Steuerstrom is ON - restore switch position if needed
        if G_Klimaanlage_Target ~= G_Klimaanlage_SwitchPosition and G_Klimaanlage_DelayTimer == 0 and
            not G_Klimaanlage_IsTransitioning then
            G_Klimaanlage_Target = G_Klimaanlage_SwitchPosition
            G_Klimaanlage_DelayTimer = G_Klimaanlage_Delay
        end
    end

    -- Handle delay timer
    if G_Klimaanlage_DelayTimer > 0 then
        G_Klimaanlage_DelayTimer = G_Klimaanlage_DelayTimer - dt
        if G_Klimaanlage_DelayTimer <= 0 then
            G_Klimaanlage_DelayTimer = 0
            -- Delay finished, start transition
            G_Klimaanlage_IsTransitioning = true
            G_Klimaanlage_TransitionTimer = 0
            G_Klimaanlage_StartValue = G_Klimaanlage_Current
            -- Calculate total transition time: 3.5 seconds PER LEVEL of change
            local distance = math.abs(G_Klimaanlage_Target - G_Klimaanlage_Current)
            G_Klimaanlage_TotalTransitionTime = distance * G_Klimaanlage_TransitionTime
        end
        return -- Still waiting
    end

    -- Handle smooth transition
    if G_Klimaanlage_IsTransitioning then
        G_Klimaanlage_TransitionTimer = G_Klimaanlage_TransitionTimer + dt

        local progress = math.min(1.0, G_Klimaanlage_TransitionTimer / G_Klimaanlage_TotalTransitionTime)
        local step = dt / G_Klimaanlage_TotalTransitionTime

        if G_Klimaanlage_Current < G_Klimaanlage_Target then
            -- Ramping up
            G_Klimaanlage_Current = G_Klimaanlage_Current +
                                        ((G_Klimaanlage_Target - G_Klimaanlage_Current) * step /
                                            (1.0 - progress + 0.001))
        else
            -- Ramping down
            G_Klimaanlage_Current = G_Klimaanlage_Current -
                                        ((G_Klimaanlage_Current - G_Klimaanlage_Target) * step /
                                            (1.0 - progress + 0.001))
        end

        -- Clamp value
        G_Klimaanlage_Current = math.max(0.0, math.min(3.0, G_Klimaanlage_Current))

        -- Check if transition complete
        if G_Klimaanlage_TransitionTimer >= G_Klimaanlage_TotalTransitionTime then
            G_Klimaanlage_Current = G_Klimaanlage_Target
            G_Klimaanlage_IsTransitioning = false
            G_Klimaanlage_TransitionTimer = 0
        end
    end

    -- Set the control value (try passing decimal value directly)
    SetControlValue("Klimaanlage_SND", G_Klimaanlage_Current)
end

-- Check for Steuerstrom conflicts (called every frame in Update)
function CheckSteuerstromConflict()
    local switchPosition = GetControlValue("Steuerstrom_SW") or 0

    -- If switch is ON but this cab doesn't have control
    if switchPosition > 0.99 and not G_ThisCabHasSteuerstrom then
        -- Check if another cab has control
        if G_SteuerstromMasterCabID ~= 0 and G_SteuerstromMasterCabID ~= G_ThisCabID then
            -- Trigger alarm - another cab has Steuerstrom
            SetControlValue("Steuerstrom_SND", 1)
        end
    end
end

-- Deactivate Steuerstrom systems (called when losing control)
function DeactivateSteuerstrom()
    G_ThisCabHasSteuerstrom = false
    G_cabActive = false
    G_RC = true
    G_Steuerstrom = false

    -- Set Steuerstrom_On ControlValue
    SetControlValue("Steuerstrom_On", 0)
    G_VoltmeterActive = false

    -- Broadcast voltmeter state to all cabs
    SendConsistMessage(CM_VOLTMETER_OFF, 0, 0)
    SendConsistMessage(CM_VOLTMETER_OFF, 0, 1)

    -- Retract mirrors if extended
    if G_MirrorExtended then
        G_MirrorExtended = false
    end

    -- Turn off headlights
    SetControlValue("Headlights", 0)

    -- Turn off Fernlicht
    G_ScheinwerferOn = false
    Call("Fernlicht_1:Activate", 0)
    Call("Fernlicht_2:Activate", 0)
    Call("Fernlicht_3:Activate", 0)
    SetControlValue("Scheinwerfer_LIT", 0)

    -- Turn on parking lights
    Call("Parklicht:Activate", 1)
    Call("*:ActivateNode", "lights_parklicht", 1)

    -- Turn off GSM-R
    G_GSMR_Active = false
    SetControlValue("GSM-R_lit", 0)

    -- Turn off Notlicht
    G_NotlichtActive = false
    SetControlValue("Notlicht_LIT", 0)

    -- Turn off wipers
    WiperSteuerstromOff()

    -- Turn off AC
    SetControlValue("Klimaanlage_SND", 0)

    -- Deactivate magnetic brake
    G_MagnetbrakeActive = false
    G_MagnetbrakeButtonPressed = false
    SetControlValue("Magnetschienenbremse_LIT", 0)
    
    -- Deactivate Schleuderbremse
    G_Schleuderbremse_Active = false
    G_Schleuderbremse_Manual = false
    G_Schleuderbremse_AutoTimer = 0.0
    SetControlValue("Schleuderbremse_LIT", 0)

end

-- Traktionsventilation System for NPZ Domino
-- Manages cooling fan phases based on speed, acceleration, and main switch state

-- Global state variables
G_TV_Enabled = false              -- Whether main switch allows fan operation
G_TV_CurrentValue = 0             -- Current fan value (0, 1, or 2)
G_TV_TargetValue = 0              -- Target fan value
G_TV_TransitionTimer = 0          -- Timer for smooth transitions (4 seconds)
G_TV_StandstillTimer = 0          -- Timer for random standstill behavior
G_TV_StandstillOffDelay = 0       -- Random delay before turning off (15-45s)
G_TV_StandstillOnDelay = 0        -- Random delay before turning on (60-180s)
G_TV_IsTransitioning = false      -- Whether we're currently transitioning
G_TV_WasMoving = false            -- Track if train was previously moving
G_TV_FirstRun = true              -- Track first acceleration after standstill

-- Constants
local TRANSITION_TIME = 4.0       -- Time to transition between phases
local PHASE1_SPEED = 0            -- Speed to activate phase 1 (on acceleration)
local PHASE2_SPEED_UP = 115        -- Speed to go to phase 2 (km/h)
local PHASE2_SPEED_DOWN = 112      -- Speed to drop back to phase 1 (km/h)
local MIN_MOVING_SPEED = 0.3      -- Minimum speed to be considered "moving" (km/h)

-- Helper function for random float between min and max
local function RandomFloat(min, max)
    return min + (math.random() * (max - min))
end

-- Initialize the system
function TV_Initialize()
    G_TV_Enabled = false
    G_TV_CurrentValue = 0
    G_TV_TargetValue = 0
    G_TV_TransitionTimer = 0
    G_TV_StandstillTimer = 0
    G_TV_StandstillOffDelay = RandomFloat(15, 45)
    G_TV_StandstillOnDelay = RandomFloat(60, 180)
    G_TV_IsTransitioning = false
    G_TV_WasMoving = false
    G_TV_FirstRun = true
    
    SetControlValue("Traktionsventilation", 0)
end

-- Called when main switch (Hauptschalter) changes state
function TV_SetMainSwitch(enabled)
    G_TV_Enabled = enabled
    
    
    if not enabled then
        -- Main switch turned off - don't force off, let it cycle randomly like at standstill
        G_TV_StandstillTimer = 0
        G_TV_StandstillOffDelay = RandomFloat(15, 45)
        G_TV_StandstillOnDelay = RandomFloat(60, 180)
        G_TV_FirstRun = true
    else
        -- Main switch turned on - reset standstill timers
        G_TV_StandstillTimer = 0
        G_TV_StandstillOffDelay = RandomFloat(15, 45)
        G_TV_StandstillOnDelay = RandomFloat(60, 180)
    end
end
-- Main update function - call this every frame with delta time
function TV_Update(dt)
    -- Only the controlling car should calculate TV state
    -- Other cars will receive the value via consist messages
    if not G_cabActive or G_RC then
        -- This is not the controlling car, don't calculate anything
        return
    end
    
    -- Get current speed in km/h
    local speed = Call("GetSpeed") * 3.6
    local absSpeed = math.abs(speed)
    local isMoving = absSpeed > MIN_MOVING_SPEED
    
    -- Get acceleration/braking state from controls
    local throttle = GetControlValue("Regulator")
    local brake = GetControlValue("DynamicBrake")
    local isAccelerating = throttle > 0.01
    local isBraking = brake > 0.01
    
    -- Determine target phase based on speed and state
    local newTarget = G_TV_TargetValue
    
    -- PRIORITY CHECK: If compressor is running, TV must be at least phase 1
    -- This ensures TV runs whenever the compressor is active
    if G_CompressorRunning and G_TV_Enabled then
        if G_TV_TargetValue == 0 then
            newTarget = 1  -- Turn on TV to phase 1 when compressor starts
        end
    end
    
    if G_TV_Enabled then
        -- Main switch is ON - normal operation based on speed
        if isMoving then
            -- Train is moving
            G_TV_WasMoving = true
            G_TV_StandstillTimer = 0
            
            if isAccelerating and G_TV_FirstRun and G_TV_TargetValue == 0 then
                -- First acceleration after standstill - start fan at phase 1
                newTarget = 1
                G_TV_FirstRun = false
            elseif absSpeed >= PHASE2_SPEED_UP and G_TV_TargetValue == 1 then
                -- Speed high enough for phase 2
                newTarget = 2
            elseif absSpeed < PHASE2_SPEED_DOWN and G_TV_TargetValue == 2 then
                -- Speed dropped below threshold - drop to phase 1 (regardless of braking state)
                newTarget = 1
            elseif not G_TV_FirstRun and G_TV_TargetValue == 0 and absSpeed > MIN_MOVING_SPEED then
                -- Fan is off but train is moving - turn on to phase 1
                newTarget = 1
            end
            
        else
            -- Train is at standstill
            if G_TV_WasMoving then
                -- Just stopped - reset standstill timer and pick random off delay
                G_TV_StandstillTimer = 0
                G_TV_StandstillOffDelay = RandomFloat(15, 45)
                G_TV_WasMoving = false
            end
            
            -- Handle standstill timing
            G_TV_StandstillTimer = G_TV_StandstillTimer + dt
            
            if G_TV_TargetValue > 0 then
                -- Fan is on at standstill - check if it's time to turn off
                -- BUT: Don't turn off if compressor is running
                if G_TV_StandstillTimer >= G_TV_StandstillOffDelay and not G_CompressorRunning then
                    newTarget = 0
                    G_TV_StandstillTimer = 0
                    G_TV_StandstillOnDelay = RandomFloat(60, 180)
                    G_TV_FirstRun = true  -- Next movement will trigger first run behavior
                end
            else
                -- Fan is off at standstill - check if it's time to turn on
                if G_TV_StandstillTimer >= G_TV_StandstillOnDelay then
                    newTarget = 1  -- Turn on to phase 1
                    G_TV_StandstillTimer = 0
                    G_TV_StandstillOffDelay = RandomFloat(15, 45)
                end
            end
        end
    else
        -- Main switch is OFF - fans should always be off
        newTarget = 0
        
        -- Reset standstill state for when main switch comes back on
        G_TV_StandstillTimer = 0
        G_TV_FirstRun = true
    end
    
    -- Start transition if target changed
    if newTarget ~= G_TV_TargetValue then
        -- If ramping UP from OFF (0), always start from 0
        -- But allow smooth transition from phase 1 to 2
        if newTarget > G_TV_TargetValue and G_TV_TargetValue == 0 then
            G_TV_CurrentValue = 0
        end
        
        G_TV_TargetValue = newTarget
        G_TV_IsTransitioning = true
        G_TV_TransitionTimer = 0
    end
    
    
    -- Handle smooth transitions (continues even if main switch is off for smooth shutdown)
    if G_TV_IsTransitioning then
        G_TV_TransitionTimer = G_TV_TransitionTimer + dt
        
        local progress = math.min(1.0, G_TV_TransitionTimer / TRANSITION_TIME)
        
        -- Calculate the step for this frame
        local step = dt / TRANSITION_TIME
        
        if G_TV_CurrentValue < G_TV_TargetValue then
            -- Ramping up
            G_TV_CurrentValue = G_TV_CurrentValue + ((G_TV_TargetValue - G_TV_CurrentValue) * step / (1 - progress + 0.001))
        else
            -- Ramping down - also takes 4 seconds
            G_TV_CurrentValue = G_TV_CurrentValue - ((G_TV_CurrentValue - G_TV_TargetValue) * step / (1 - progress + 0.001))
        end
        
        -- Clamp value
        G_TV_CurrentValue = math.max(0, math.min(2, G_TV_CurrentValue))
        
        -- Check if transition complete
        if G_TV_TransitionTimer >= TRANSITION_TIME then
            G_TV_CurrentValue = G_TV_TargetValue
            G_TV_IsTransitioning = false
        end
    end
    
    -- Update the control value
    SetControlValue("Traktionsventilation", G_TV_CurrentValue)
    
    -- Broadcast TV value to all cars in consist
    SendConsistMessage(CM_TRAKTIONSVENTILATION, G_TV_CurrentValue, 1)  -- Forward
    SendConsistMessage(CM_TRAKTIONSVENTILATION, G_TV_CurrentValue, 0)  -- Backward
end

-- Optional: Debug function to check current state
function TV_GetDebugInfo()
    local speed = Call("GetSpeed") * 3.6
    return string.format(
        "TV Debug: Speed=%.1fkm/h, Current=%.2f, Target=%d, Transitioning=%s, Timer=%.1fs, Enabled=%s",
        speed,
        G_TV_CurrentValue,
        G_TV_TargetValue,
        tostring(G_TV_IsTransitioning),
        G_TV_StandstillTimer,
        tostring(G_TV_Enabled)
    )
end

-- Wiper 1 (Right - WiperController_R)
wiperAnim = 0
wiperAnimSmoothed = 0
wiperDirection = 1 -- 1 = forward, -1 = backward
wiperSpeed = 0
wiperTargetSpeed = 0
wiperCurrentVelocity = 0
wiperReturning = false

-- Wiper 2 (Left - WiperController_L)
wiper2Anim = 0
wiper2AnimSmoothed = 0
wiper2Direction = 1 -- 1 = forward, -1 = backward
wiper2Speed = 0
wiper2TargetSpeed = 0
wiper2CurrentVelocity = 0
wiper2Returning = false

function WiperModeControl(name, value)
    -- Wipers require Steuerstrom to operate
    -- If Steuerstrom is off and trying to activate wipers, do nothing
    if not G_Steuerstrom and value > 0 then
        return
    end

    if name == "WiperController_R" then
        if value == 0 then
            SetControlValue("Wipers", 0)
            -- Only set returning if wiper was actually running
            if wiperTargetSpeed > 0 then
                wiperReturning = true
            end
            wiperTargetSpeed = 0
        elseif value == 1 then
            SetControlValue("Wipers", 1)
            wiperTargetSpeed = 1 -- Normal speed
            wiperReturning = false
            -- DON'T reset position - keep current wiperAnim
        elseif value == 2 then
            SetControlValue("Wipers", 2)
            wiperTargetSpeed = 2 -- Medium fast
            wiperReturning = false
            -- DON'T reset position - keep current wiperAnim
        elseif value == 3 then
            SetControlValue("Wipers", 3)
            wiperTargetSpeed = 3 -- Fast
            wiperReturning = false
            -- DON'T reset position - keep current wiperAnim
        end
    elseif name == "WiperController_L" then
        if value == 0 then
            SetControlValue("Wipers2", 0)
            -- Only set returning if wiper was actually running
            if wiper2TargetSpeed > 0 then
                wiper2Returning = true
            end
            wiper2TargetSpeed = 0
        elseif value == 1 then
            SetControlValue("Wipers2", 1)
            wiper2TargetSpeed = 1 -- Normal speed
            wiper2Returning = false
            -- DON'T reset position - keep current wiper2Anim
        elseif value == 2 then
            SetControlValue("Wipers2", 2)
            wiper2TargetSpeed = 2 -- Medium fast
            wiper2Returning = false
            -- DON'T reset position - keep current wiper2Anim
        elseif value == 3 then
            SetControlValue("Wipers2", 3)
            wiper2TargetSpeed = 3 -- Fast
            wiper2Returning = false
            -- DON'T reset position - keep current wiper2Anim
        end
    end
end

function WiperUpdate(dt)
    -- Wipers require Steuerstrom to start moving, but the physical return-to-home
    -- animation must still play even when Steuerstrom is off.
    -- New activation is already blocked in WiperModeControl.
    
    -- Update Wiper 1 (Right)
    if wiperTargetSpeed > 0 or wiperCurrentVelocity > 0.01 or wiperReturning then
        -- Get target velocity based on speed setting
        local targetVelocity = 0
        if wiperTargetSpeed == 1 then
            targetVelocity = 1.0 / 1.2 -- Normal: 1.2s per direction
        elseif wiperTargetSpeed == 2 then
            targetVelocity = 1.0 / 0.7 -- Medium fast: 0.7s per direction
        elseif wiperTargetSpeed == 3 then
            targetVelocity = 1.0 / 0.5
        end
        
        -- If returning to home, use normal speed
        if wiperReturning then
            targetVelocity = 1.0 / 1.2 -- Use normal speed to return
        end
        
        -- Smooth velocity transition (acceleration/deceleration)
        local velocityTransitionSpeed = 3.0 -- How fast to change speed
        if wiperCurrentVelocity < targetVelocity then
            wiperCurrentVelocity = math.min(targetVelocity, wiperCurrentVelocity + velocityTransitionSpeed * dt)
        elseif wiperCurrentVelocity > targetVelocity then
            wiperCurrentVelocity = math.max(targetVelocity, wiperCurrentVelocity - velocityTransitionSpeed * dt)
        end
        
        -- Update position based on current velocity and direction
        wiperAnim = wiperAnim + (wiperCurrentVelocity * wiperDirection * dt)
        
        -- Check boundaries and reverse direction
        if wiperAnim >= 1.0 then
            wiperAnim = 1.0
            wiperDirection = -1 -- Reverse to go back
        elseif wiperAnim <= 0.0 then
            wiperAnim = 0.0
            wiperDirection = 1 -- Reverse to go forward
            
            -- If returning and reached home position, stop completely
            if wiperReturning then
                wiperAnimSmoothed = 0
                wiperCurrentVelocity = 0
                wiperReturning = false
                SetControlValue("Wiper1", 0)
                SetAnimTime("Wiper1", 0)
                SetAnimTime("Wiper1_ext", 0)
                return
            end
        end
        
        -- Calculate smoothed animation with position-based lead
        -- Add lead offset when approaching endpoints to reach them ~0.5s earlier
        local leadOffset = 0
        
        if wiperDirection == 1 then
            -- Moving forward (0 to 1): add lead when above 0.5
            if wiperAnim > 0.5 then
                -- Linear lead that increases as we approach 1.0
                -- At 0.5: no lead, at 1.0: maximum lead
                local leadAmount = (wiperAnim - 0.5) / 0.5  -- 0 to 1
                leadOffset = leadAmount * 0.4  -- Up to 0.4 lead
            end
        else
            -- Moving backward (1 to 0): add lead when below 0.5
            if wiperAnim < 0.5 then
                -- Linear lead that increases as we approach 0.0
                -- At 0.5: no lead, at 0.0: maximum lead
                local leadAmount = (0.5 - wiperAnim) / 0.5  -- 0 to 1
                leadOffset = -leadAmount * 0.4  -- Up to -0.4 lead (negative to go toward 0)
            end
        end
        
        -- Apply lead with smoothing
        local targetWithLead = wiperAnim + leadOffset
        local smoothingFactor = 15.0
        wiperAnimSmoothed = wiperAnimSmoothed + (targetWithLead - wiperAnimSmoothed) * math.min(1.0, dt * smoothingFactor)
        
        -- Clamp to valid range
        wiperAnimSmoothed = math.max(0, math.min(1, wiperAnimSmoothed))
        
        -- SetControlValue uses actual position
        SetControlValue("WiperInt2", wiperAnim)
        
        -- SetAnimTime uses lagged position
        SetAnimTime("Wiper1", wiperAnimSmoothed)
        SetAnimTime("Wiper2_ext", wiperAnim)
    end
    
    -- Update Wiper 2 (Left)
    if wiper2TargetSpeed > 0 or wiper2CurrentVelocity > 0.01 or wiper2Returning then
        -- Get target velocity based on speed setting
        local targetVelocity = 0
        if wiper2TargetSpeed == 1 then
            targetVelocity = 1.0 / 1.2 -- Normal: 1.2s per direction
        elseif wiper2TargetSpeed == 2 then
            targetVelocity = 1.0 / 0.7 -- Medium fast: 0.7s per direction
        elseif wiper2TargetSpeed == 3 then
            targetVelocity = 1.0 / 0.5 -- Fast: 0.4s per direction
        end
        
        -- If returning to home, use normal speed
        if wiper2Returning then
            targetVelocity = 1.0 / 1.2 -- Use normal speed to return
        end
        
        -- Smooth velocity transition (acceleration/deceleration)
        local velocityTransitionSpeed = 3.0 -- How fast to change speed
        if wiper2CurrentVelocity < targetVelocity then
            wiper2CurrentVelocity = math.min(targetVelocity, wiper2CurrentVelocity + velocityTransitionSpeed * dt)
        elseif wiper2CurrentVelocity > targetVelocity then
            wiper2CurrentVelocity = math.max(targetVelocity, wiper2CurrentVelocity - velocityTransitionSpeed * dt)
        end
        
        -- Update position based on current velocity and direction
        wiper2Anim = wiper2Anim + (wiper2CurrentVelocity * wiper2Direction * dt)
        
        -- Check boundaries and reverse direction
        if wiper2Anim >= 1.0 then
            wiper2Anim = 1.0
            wiper2Direction = -1 -- Reverse to go back
        elseif wiper2Anim <= 0.0 then
            wiper2Anim = 0.0
            wiper2Direction = 1 -- Reverse to go forward
            
            -- If returning and reached home position, stop completely
            if wiper2Returning then
                wiper2AnimSmoothed = 0
                wiper2CurrentVelocity = 0
                wiper2Returning = false
                SetControlValue("Wiper2", 0)
                SetAnimTime("Wiper2", 0)
                SetAnimTime("Wiper_ext", 0)
                return
            end
        end
        
        -- Calculate smoothed animation with position-based lead
        -- Add lead offset when approaching endpoints to reach them ~0.5s earlier
        local leadOffset = 0
        
        if wiper2Direction == 1 then
            -- Moving forward (0 to 1): add lead when above 0.5
            if wiper2Anim > 0.5 then
                -- Linear lead that increases as we approach 1.0
                -- At 0.5: no lead, at 1.0: maximum lead
                local leadAmount = (wiper2Anim - 0.5) / 0.5  -- 0 to 1
                leadOffset = leadAmount * 0.4  -- Up to 0.4 lead
            end
        else
            -- Moving backward (1 to 0): add lead when below 0.5
            if wiper2Anim < 0.5 then
                -- Linear lead that increases as we approach 0.0
                -- At 0.5: no lead, at 0.0: maximum lead
                local leadAmount = (0.5 - wiper2Anim) / 0.5  -- 0 to 1
                leadOffset = -leadAmount * 0.4  -- Up to -0.4 lead (negative to go toward 0)
            end
        end
        
        -- Apply lead with smoothing
        local targetWithLead = wiper2Anim + leadOffset
        local smoothingFactor = 15.0
        wiper2AnimSmoothed = wiper2AnimSmoothed + (targetWithLead - wiper2AnimSmoothed) * math.min(1.0, dt * smoothingFactor)
        
        -- Clamp to valid range
        wiper2AnimSmoothed = math.max(0, math.min(1, wiper2AnimSmoothed))
        
        -- SetControlValue uses actual position
        SetControlValue("WiperInt1", wiper2Anim)
        
        -- SetAnimTime uses lagged position
        SetAnimTime("Wiper2", wiper2AnimSmoothed)
        SetAnimTime("Wiper1_ext", wiper2Anim)
    end
end
-- Turn off wipers when Steuerstrom turns OFF
function WiperSteuerstromOff()
    -- Always send wiper back to home position if it's anywhere but home
    if wiperAnim > 0.0 or wiperCurrentVelocity > 0.01 then
        wiperReturning = true
    end
    wiperTargetSpeed = 0
    SetControlValue("Wipers", 0)
    
    if wiper2Anim > 0.0 or wiper2CurrentVelocity > 0.01 then
        wiper2Returning = true
    end
    wiper2TargetSpeed = 0
    SetControlValue("Wipers2", 0)
end

-- Resume wipers when Steuerstrom turns ON based on current controller positions
function WiperSteuerstromOn()
    local controllerR = GetControlValue("WiperController_R") or 0
    local controllerL = GetControlValue("WiperController_L") or 0
    if controllerR > 0.5 then
        -- Clear returning flag so wiper starts moving instead of returning to 0
        wiperReturning = false
        WiperModeControl("WiperController_R", math.floor(controllerR + 0.5))
    end
    if controllerL > 0.5 then
        wiper2Returning = false
        WiperModeControl("WiperController_L", math.floor(controllerL + 0.5))
    end
end

----------------------------------------
-- Domino Door Controller             --
-- AI-driven door control system      --
----------------------------------------

-- Door timing constants (not used anymore, kept for reference)
DOORCLOSETIMER = 11.2;

-- Animation values (frames/24fps)
TRITTBRETT_EXTENDED = 0.5;      -- 12 frames / 24fps
INOVA_DOOR_OPEN = 3.125;        -- 75 frames / 24fps
ENGINE_DOOR_OPEN = 4.0;         -- 96 frames / 24fps

-- Door states and timers
Door1RTarget = 0;
Door1R = 0;
Door1R_ST = 0;  -- Schiebetritt/Trittbrett
Door1RCloseTimer = 0;
Door1R_TrittbrettDelayTimer = 0; -- Random delay 2-4 seconds before door opens
Door1R_ReopenDelayTimer = 0; -- Delay before door can reopen after closing (7-25 seconds)

Door2RTarget = 0;
Door2R = 0;
Door2R_ST = 0;
Door2RCloseTimer = 0;
Door2R_TrittbrettDelayTimer = 0;
Door2R_ReopenDelayTimer = 0;

Door1LTarget = 0;
Door1L = 0;
Door1L_ST = 0;
Door1LCloseTimer = 0;
Door1L_TrittbrettDelayTimer = 0;
Door1L_ReopenDelayTimer = 0;

Door2LTarget = 0;
Door2L = 0;
Door2L_ST = 0;
Door2LCloseTimer = 0;
Door2L_TrittbrettDelayTimer = 0;
Door2L_ReopenDelayTimer = 0;

-- Single door configuration (Fst)
HasOnlyOneDoor = false;

-- Control signals from AI
DoorsOpenCloseLeft_Active = false;
DoorsOpenCloseRight_Active = false;
DoorsOpenCloseLeft_Previous = 0;
DoorsOpenCloseRight_Previous = 0;

-- Visual indicators
blinkTimer = 0;
blinkState = false;

-- Wheelchair door tracking
WheelchairDoor_IsThisCar = false;  -- Is this car holding the wheelchair door
WheelchairDoor_Side = "";  -- "L" or "R"
WheelchairDoor_Closing = false;  -- Door is now closing after 20 seconds

-- Car type detection
IsEngineScript = false;
IsTrailerScript = false;

function DoorController_Initialize()
    -- Just set both flags to true so we try both animation types
    IsEngineScript = true;
    IsTrailerScript = true;
    
    -- Check if this is a single-door engine (Fst = 1)
    local fstValue = GetControlValue("Fst");
    if fstValue and fstValue > 0.5 then
        HasOnlyOneDoor = true;
    end
end

function Door_Update(dt)
    local currentSpeed = Call("*:GetSpeed");
    
    -- Read AI door control signals
    local doorsLeft = GetControlValue("DoorsOpenCloseLeft");
    local doorsRight = GetControlValue("DoorsOpenCloseRight");
    
    -- Detect transitions and handle door opening/closing
    HandleDoorSignals(doorsLeft, doorsRight, currentSpeed);
    
    -- Update door targets based on timers
    UpdateDoorTargets();
    
    -- Update timers
    UpdateDoorTimers(dt);
    
    -- Check if forced door closing is active and doors are actually closing (not already closed)
    local forcedClosing = GetControlValue("ForcedDoorClosing") or 0;
    local doorsAreClosing = false;
    
    if forcedClosing > 0.5 then
        -- Check if any door is in the process of closing (target is 0 but current position is not yet 0)
        if (Door1RTarget == 0 and Door1R > 0.01) or 
           (Door1LTarget == 0 and Door1L > 0.01) then
            doorsAreClosing = true;
        end
        
        if not HasOnlyOneDoor then
            if (Door2RTarget == 0 and Door2R > 0.01) or 
               (Door2LTarget == 0 and Door2L > 0.01) then
                doorsAreClosing = true;
            end
        end
    end
    
    -- Allow door movement when stopped, OR when forced closing is active and doors are actively closing
    if currentSpeed < 0.028 or (forcedClosing > 0.5 and doorsAreClosing) then
        -- Linear movement toward target (like pantograph)
        local doorSpeed = 1.0; -- Door animation speed (animation units per second)
        
        Door1R = LinearMove(dt, Door1R, Door1RTarget, doorSpeed);
        Door1L = LinearMove(dt, Door1L, Door1LTarget, doorSpeed);
        
        if not HasOnlyOneDoor then
            Door2R = LinearMove(dt, Door2R, Door2RTarget, doorSpeed);
            Door2L = LinearMove(dt, Door2L, Door2LTarget, doorSpeed);
        end
        
        -- Extend Trittbrett (TrailerScript only)
        if IsTrailerScript then
            ExtendTrittbrett(dt);
        end
    end
    
    -- Apply animations
    ApplyDoorAnimations();
    
    -- Update indicators
    UpdateDoorIndicators();
    
    -- Update wheelchair door status and clear light when door closes
    UpdateWheelchairDoorStatus();
    
    -- Update blinking timer
    blinkTimer = blinkTimer + dt;
    if blinkTimer >= 1.0 then
        blinkState = not blinkState;
        blinkTimer = 0;
    end
    
    -- Set ForcedDoorClosing flag
    UpdateForcedDoorClosing();
    
    -- Track and broadcast door status for mirror indicators
    -- Reset consist-wide flags (will be repopulated by consist messages)
    G_ConsistDoorsOpenLeft = false
    G_ConsistDoorsOpenRight = false
    
    -- Check if any doors are actually open on this car (> 0.1 means visibly open)
    local leftDoorsOpen = (Door1L > 0.1) or (Door2L > 0.1)
    local rightDoorsOpen = (Door1R > 0.1) or (Door2R > 0.1)
    
    -- Update local door state
    local leftStateChanged = (leftDoorsOpen ~= G_LocalDoorsOpenLeft)
    local rightStateChanged = (rightDoorsOpen ~= G_LocalDoorsOpenRight)
    
    G_LocalDoorsOpenLeft = leftDoorsOpen
    G_LocalDoorsOpenRight = rightDoorsOpen
    
    -- Broadcast door status if it changed
    if leftStateChanged then
        local status = leftDoorsOpen and 1 or 0
        SendConsistMessage(CM_DOOR_STATUS_LEFT, status, 0)
        SendConsistMessage(CM_DOOR_STATUS_LEFT, status, 1)
    end
    
    if rightStateChanged then
        local status = rightDoorsOpen and 1 or 0
        SendConsistMessage(CM_DOOR_STATUS_RIGHT, status, 0)
        SendConsistMessage(CM_DOOR_STATUS_RIGHT, status, 1)
    end
    
    -- Set consist-wide flags if this car has doors open
    if leftDoorsOpen then
        G_ConsistDoorsOpenLeft = true
    end
    if rightDoorsOpen then
        G_ConsistDoorsOpenRight = true
    end
end

function LinearMove(dt, current, target, speed)
    -- Move linearly toward target at constant speed
    if current < target then
        return math.min(current + speed * dt, target);
    elseif current > target then
        return math.max(current - speed * dt, target);
    else
        return current;
    end
end

function HandleDoorSignals(doorsLeft, doorsRight, currentSpeed)
    -- LEFT SIDE
    if doorsLeft == 1 and DoorsOpenCloseLeft_Previous == 0 then
        -- Signal activated - start opening random doors
        DoorsOpenCloseLeft_Active = true;
        if currentSpeed < 0.028 then
            OpenRandomDoorsLeft();
        end
    elseif doorsLeft == 0 and DoorsOpenCloseLeft_Previous == 1 then
        -- Signal deactivated - limit ALL door timers to 2-4 seconds max
        DoorsOpenCloseLeft_Active = false;
        
        -- Door1L: If timer is still running or door is open, limit to max 4 seconds
        if Door1LCloseTimer > 4 then
            Door1LCloseTimer = 2 + math.random() * 2; -- 2-4 seconds
        end
        
        -- Door2L: Same for second door
        if not HasOnlyOneDoor and Door2LCloseTimer > 4 then
            Door2LCloseTimer = 2 + math.random() * 2; -- 2-4 seconds
        end
        
        -- If any door is actually open, ensure forced closing is triggered
        if Door1L > 0 or (not HasOnlyOneDoor and Door2L > 0) then
            StartDelayedClosingLeft();
        end
    end
    DoorsOpenCloseLeft_Previous = doorsLeft;
    
    -- RIGHT SIDE
    if doorsRight == 1 and DoorsOpenCloseRight_Previous == 0 then
        -- Signal activated - start opening random doors
        DoorsOpenCloseRight_Active = true;
        if currentSpeed < 0.028 then
            OpenRandomDoorsRight();
        end
    elseif doorsRight == 0 and DoorsOpenCloseRight_Previous == 1 then
        -- Signal deactivated - limit ALL door timers to 2-4 seconds max
        DoorsOpenCloseRight_Active = false;
        
        -- Door1R: If timer is still running or door is open, limit to max 4 seconds
        if Door1RCloseTimer > 4 then
            Door1RCloseTimer = 2 + math.random() * 2; -- 2-4 seconds
        end
        
        -- Door2R: Same for second door
        if not HasOnlyOneDoor and Door2RCloseTimer > 4 then
            Door2RCloseTimer = 2 + math.random() * 2; -- 2-4 seconds
        end
        
        -- If any door is actually open, ensure forced closing is triggered
        if Door1R > 0 or (not HasOnlyOneDoor and Door2R > 0) then
            StartDelayedClosingRight();
        end
    end
    DoorsOpenCloseRight_Previous = doorsRight;
end

function OpenRandomDoorsLeft()
    -- Some doors can open immediately (people waiting at door)
    -- Don't open any doors if the signal is 0 (forced closing active)
    local doorsLeft = GetControlValue("DoorsOpenCloseLeft")
    if doorsLeft == 0 then
        return
    end

    -- Only if reopen delay has passed
    if Door1L_ReopenDelayTimer == 0 and math.random(2) == 1 then
        -- 9-23 seconds, weighted toward longer times (busy station)
        Door1LCloseTimer = 9 + (1 - math.random() * math.random()) * 14;
        -- TrailerScript: Check if Trittbrett already extended
        -- EngineScript: always immediate (no Trittbrett)
        if IsTrailerScript and Door1L_ST < 0.01 then
            Door1L_TrittbrettDelayTimer = 0.8; -- Wait for Trittbrett to extend
        else
            Door1L_TrittbrettDelayTimer = 0; -- Open immediately
        end
    end
    
    if not HasOnlyOneDoor then
        if Door2L_ReopenDelayTimer == 0 and math.random(2) == 1 then
            Door2LCloseTimer = 9 + (1 - math.random() * math.random()) * 14;
            if IsTrailerScript and Door2L_ST < 0.01 then
                Door2L_TrittbrettDelayTimer = 0.8;
            else
                Door2L_TrittbrettDelayTimer = 0;
            end
        end
    end
end

function OpenRandomDoorsRight()
    -- Some doors can open immediately (people waiting at door)
    -- Don't open any doors if the signal is 0 (forced closing active)
    local doorsRight = GetControlValue("DoorsOpenCloseRight")
    if doorsRight == 0 then
        return
    end

    -- Only if reopen delay has passed
    if Door1R_ReopenDelayTimer == 0 and math.random(2) == 1 then
        -- 9-23 seconds, weighted toward longer times (busy station)
        Door1RCloseTimer = 9 + (1 - math.random() * math.random()) * 14;
        -- TrailerScript: Check if Trittbrett already extended
        -- EngineScript: always immediate (no Trittbrett)
        if IsTrailerScript and Door1R_ST < 0.01 then
            Door1R_TrittbrettDelayTimer = 0.8; -- Wait for Trittbrett to extend
        else
            Door1R_TrittbrettDelayTimer = 0; -- Open immediately
        end
    end
    
    if not HasOnlyOneDoor then
        if Door2R_ReopenDelayTimer == 0 and math.random(2) == 1 then
            Door2RCloseTimer = 9 + (1 - math.random() * math.random()) * 14;
            if IsTrailerScript and Door2R_ST < 0.01 then
                Door2R_TrittbrettDelayTimer = 0.8;
            else
                Door2R_TrittbrettDelayTimer = 0;
            end
        end
    end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- WHEELCHAIR DOOR HOLD SYSTEM
--------------------------------------------------------------------------------
-- Check if this car has INOVA doors
function HasINOVADoors()
    -- Check if INOVA door control exists
    return Call("*:ControlExists", "INOVA_DoorsL1", 0) == 1 or 
           Call("*:ControlExists", "INOVA_DoorsR1", 0) == 1
end

-- Check if this car should hold a wheelchair door open
function ShouldHoldWheelchairDoor()
    -- Only INOVA cars can hold wheelchair doors
    if not HasINOVADoors() then
        return false
    end
    
    -- Only if wheelchair request is active and door hold just started
    if G_WheelchairRequest_Active and G_WheelchairRequest_DoorHoldActive and G_WheelchairRequest_DoorHoldTimer < 0.5 then
        -- 10% chance that this car is the one to hold a door
        -- This ensures roughly one door per consist stays open
        return math.random() < 0.1
    end
    return false
end

-- Update wheelchair door status - clear tracking when door fully closes
function UpdateWheelchairDoorStatus()
    if WheelchairDoor_IsThisCar then
        local doorPosition = 0
        
        -- Get the position of the wheelchair door
        if WheelchairDoor_Side == "L" then
            doorPosition = Door1L
        elseif WheelchairDoor_Side == "R" then
            doorPosition = Door1R
        end
        
        -- If door has fully closed, clear tracking variables
        -- Light and request flag are now cleared by timer in ControlScript (22 seconds)
        if doorPosition <= 0.01 and WheelchairDoor_Closing then
            WheelchairDoor_IsThisCar = false
            WheelchairDoor_Side = ""
            WheelchairDoor_Closing = false
        end
    end
end

function StartDelayedClosingLeft()
    -- Set ForcedDoorClosing flag
    SetControlValue("ForcedDoorClosing", 1);
    
    -- Check if we should hold a wheelchair door (INOVA only)
    local holdWheelchairDoor = ShouldHoldWheelchairDoor()
    
    if holdWheelchairDoor then
        -- This car is the wheelchair door holder!
        WheelchairDoor_IsThisCar = true
        WheelchairDoor_Side = "L"
        WheelchairDoor_Closing = false
        
        -- IMMEDIATELY open the door if not already open
        Door1LTarget = INOVA_DOOR_OPEN
        
        -- Keep door open for 20 seconds
        Door1LCloseTimer = 20.0
    else
        -- Normal door closing
        if Door1LCloseTimer > 5 then
            Door1LCloseTimer = 3 + math.random() * 2
        end
    end
    
    -- Set reopen delays for ALL doors to prevent them reopening during forced closing
    Door1L_ReopenDelayTimer = 3 + math.random() * 32;
            -- Mark wheelchair door as closing if this is the wheelchair door
            if WheelchairDoor_IsThisCar and WheelchairDoor_Side == "L" then
                WheelchairDoor_Closing = true
            end
    
    if not HasOnlyOneDoor then
        if Door2LCloseTimer > 5 then
            Door2LCloseTimer = 3 + math.random() * 2;
        end
        Door2L_ReopenDelayTimer = 3 + math.random() * 32;
    end
end


function StartDelayedClosingRight()
    -- Set ForcedDoorClosing flag
    SetControlValue("ForcedDoorClosing", 1);
    
    -- Check if we should hold a wheelchair door (INOVA only)
    local holdWheelchairDoor = ShouldHoldWheelchairDoor()
    
    if holdWheelchairDoor then
        -- This car is the wheelchair door holder!
        WheelchairDoor_IsThisCar = true
        WheelchairDoor_Side = "R"
        WheelchairDoor_Closing = false
        
        -- IMMEDIATELY open the door if not already open
        Door1RTarget = INOVA_DOOR_OPEN
        
        -- Keep door open for 20 seconds
        Door1RCloseTimer = 20.0
    else
        -- Normal door closing
        if Door1RCloseTimer > 5 then
            Door1RCloseTimer = 3 + math.random() * 2
        end
    end
    
    -- Set reopen delays for ALL doors to prevent them reopening during forced closing
    Door1R_ReopenDelayTimer = 3 + math.random() * 32;
    
    if not HasOnlyOneDoor then
        if Door2RCloseTimer > 5 then
            Door2RCloseTimer = 3 + math.random() * 2;
        end
        Door2R_ReopenDelayTimer = 3 + math.random() * 32;
    end
end

function UpdateDoorTargets()
    -- Use correct animation values based on car type
    local doorOpenValue = IsEngineScript and ENGINE_DOOR_OPEN or INOVA_DOOR_OPEN;
    
    -- Doors only open after Trittbrett delay timer expires (for INOVA doors)
    -- EngineScript has no Trittbrett so no delay
    if IsTrailerScript then
        Door1RTarget = lambda(Door1RCloseTimer > 0 and Door1R_TrittbrettDelayTimer <= 0, doorOpenValue, 0);
        Door1LTarget = lambda(Door1LCloseTimer > 0 and Door1L_TrittbrettDelayTimer <= 0, doorOpenValue, 0);
        if not HasOnlyOneDoor then
            Door2RTarget = lambda(Door2RCloseTimer > 0 and Door2R_TrittbrettDelayTimer <= 0, doorOpenValue, 0);
            Door2LTarget = lambda(Door2LCloseTimer > 0 and Door2L_TrittbrettDelayTimer <= 0, doorOpenValue, 0);
        else
            Door2RTarget = 0;
            Door2LTarget = 0;
        end
    else
        -- EngineScript - no delay
        Door1RTarget = lambda(Door1RCloseTimer > 0, doorOpenValue, 0);
        Door1LTarget = lambda(Door1LCloseTimer > 0, doorOpenValue, 0);
        if not HasOnlyOneDoor then
            Door2RTarget = lambda(Door2RCloseTimer > 0, doorOpenValue, 0);
            Door2LTarget = lambda(Door2LCloseTimer > 0, doorOpenValue, 0);
        else
            Door2RTarget = 0;
            Door2LTarget = 0;
        end
    end
end

function UpdateDoorTimers(dt)
    -- Countdown door close timers
    -- When a door timer reaches 0, set reopen delay (3-35 seconds for more variation)
    if Door1RCloseTimer > 0 then
        Door1RCloseTimer = Door1RCloseTimer - dt;
        if Door1RCloseTimer <= 0 then
            Door1RCloseTimer = 0;
            Door1R_ReopenDelayTimer = 3 + math.random() * 32; -- Random 3-35 seconds
            -- Mark wheelchair door as closing if this is the wheelchair door
            if WheelchairDoor_IsThisCar and WheelchairDoor_Side == "R" then
                WheelchairDoor_Closing = true
            end
        end
    end
    
    if Door1LCloseTimer > 0 then
        Door1LCloseTimer = Door1LCloseTimer - dt;
        if Door1LCloseTimer <= 0 then
            Door1LCloseTimer = 0;
            Door1L_ReopenDelayTimer = 3 + math.random() * 32; -- Random 3-35 seconds
            -- Mark wheelchair door as closing if this is the wheelchair door
            if WheelchairDoor_IsThisCar and WheelchairDoor_Side == "L" then
                WheelchairDoor_Closing = true
            end
        end
    end
    
    if not HasOnlyOneDoor then
        if Door2RCloseTimer > 0 then
            Door2RCloseTimer = Door2RCloseTimer - dt;
            if Door2RCloseTimer <= 0 then
                Door2RCloseTimer = 0;
                Door2R_ReopenDelayTimer = 3 + math.random() * 32;
            end
        end
        
        if Door2LCloseTimer > 0 then
            Door2LCloseTimer = Door2LCloseTimer - dt;
            if Door2LCloseTimer <= 0 then
                Door2LCloseTimer = 0;
                Door2L_ReopenDelayTimer = 3 + math.random() * 32;
            end
        end
    end
    
    -- Countdown reopen delay timers
    Door1R_ReopenDelayTimer = math.max(0, Door1R_ReopenDelayTimer - dt);
    Door1L_ReopenDelayTimer = math.max(0, Door1L_ReopenDelayTimer - dt);
    
    if not HasOnlyOneDoor then
        Door2R_ReopenDelayTimer = math.max(0, Door2R_ReopenDelayTimer - dt);
        Door2L_ReopenDelayTimer = math.max(0, Door2L_ReopenDelayTimer - dt);
    end
    
    -- Countdown Trittbrett delay timers (only when door timer is active)
    if Door1RCloseTimer > 0 then
        Door1R_TrittbrettDelayTimer = math.max(0, Door1R_TrittbrettDelayTimer - dt);
    end
    if Door1LCloseTimer > 0 then
        Door1L_TrittbrettDelayTimer = math.max(0, Door1L_TrittbrettDelayTimer - dt);
    end
    
    if not HasOnlyOneDoor then
        if Door2RCloseTimer > 0 then
            Door2R_TrittbrettDelayTimer = math.max(0, Door2R_TrittbrettDelayTimer - dt);
        end
        if Door2LCloseTimer > 0 then
            Door2L_TrittbrettDelayTimer = math.max(0, Door2L_TrittbrettDelayTimer - dt);
        end
    end
    
    -- Continue opening random doors while signal is active
    if DoorsOpenCloseLeft_Active then
        ContinueOpeningDoorsLeft();
    end
    
    if DoorsOpenCloseRight_Active then
        ContinueOpeningDoorsRight();
    end
end

function ContinueOpeningDoorsLeft()
    -- Random chance to open additional doors (1/1000 per frame, like RABe 514)
    -- Don't open any new doors if the signal is 0 (forced closing active)
    local doorsLeft = GetControlValue("DoorsOpenCloseLeft")
    if doorsLeft == 0 then
        return
    end

    if math.random(1000) == 69 then
        if math.random(2) == 1 or HasOnlyOneDoor then
            -- Only open if reopen delay has passed
            if Door1L_ReopenDelayTimer == 0 then
                Door1LCloseTimer = 9 + (1 - math.random() * math.random()) * 14; -- 9-23s, weighted longer
                -- TrailerScript: Check if Trittbrett already extended
                -- EngineScript: always immediate
                if IsTrailerScript and Door1L_ST < 0.01 then
                    Door1L_TrittbrettDelayTimer = 0.8;
                else
                    Door1L_TrittbrettDelayTimer = 0;
                end
            end
        else
            -- Only open if reopen delay has passed
            if Door2L_ReopenDelayTimer == 0 then
                Door2LCloseTimer = 9 + (1 - math.random() * math.random()) * 14; -- 9-23s, weighted longer
                if IsTrailerScript and Door2L_ST < 0.01 then
                    Door2L_TrittbrettDelayTimer = 0.8;
                else
                    Door2L_TrittbrettDelayTimer = 0;
                end
            end
        end
    end
end

function ContinueOpeningDoorsRight()
    -- Random chance to open additional doors
    -- Don't open any new doors if the signal is 0 (forced closing active)
    local doorsRight = GetControlValue("DoorsOpenCloseRight")
    if doorsRight == 0 then
        return
    end

    if math.random(1000) == 69 then
        if math.random(2) == 1 or HasOnlyOneDoor then
            -- Only open if reopen delay has passed
            if Door1R_ReopenDelayTimer == 0 then
                Door1RCloseTimer = 9 + (1 - math.random() * math.random()) * 14; -- 9-23s, weighted longer
                -- TrailerScript: Check if Trittbrett already extended
                -- EngineScript: always immediate
                if IsTrailerScript and Door1R_ST < 0.01 then
                    Door1R_TrittbrettDelayTimer = 0.8;
                else
                    Door1R_TrittbrettDelayTimer = 0;
                end
            end
        else
            -- Only open if reopen delay has passed
            if Door2R_ReopenDelayTimer == 0 then
                Door2RCloseTimer = 9 + (1 - math.random() * math.random()) * 14; -- 9-23s, weighted longer
                if IsTrailerScript and Door2R_ST < 0.01 then
                    Door2R_TrittbrettDelayTimer = 0.8;
                else
                    Door2R_TrittbrettDelayTimer = 0;
                end
            end
        end
    end
end

function ExtendTrittbrett(dt)
    -- Trittbrett extends ONLY when corresponding door is opening/open
    -- Stays extended while door is open/closing (Door > 0)
    -- Retracts when signal is off AND door is fully closed
    local trittbrettSpeed = 0.5;
    
    -- Door1R_ST
    if Door1RCloseTimer > 0 or Door1R > 0.01 then
        -- Door timer active OR door open - extend/maintain Trittbrett
        Door1R_ST = LinearMove(dt, Door1R_ST, TRITTBRETT_EXTENDED, trittbrettSpeed);
    elseif not DoorsOpenCloseRight_Active and Door1R == 0 then
        -- Signal off AND door fully closed - retract Trittbrett
        Door1R_ST = LinearMove(dt, Door1R_ST, 0, trittbrettSpeed);
    end
    
    -- Door2R_ST
    if Door2RCloseTimer > 0 or Door2R > 0.01 then
        Door2R_ST = LinearMove(dt, Door2R_ST, TRITTBRETT_EXTENDED, trittbrettSpeed);
    elseif not DoorsOpenCloseRight_Active and Door2R == 0 then
        Door2R_ST = LinearMove(dt, Door2R_ST, 0, trittbrettSpeed);
    end
    
    -- Door1L_ST
    if Door1LCloseTimer > 0 or Door1L > 0.01 then
        Door1L_ST = LinearMove(dt, Door1L_ST, TRITTBRETT_EXTENDED, trittbrettSpeed);
    elseif not DoorsOpenCloseLeft_Active and Door1L == 0 then
        Door1L_ST = LinearMove(dt, Door1L_ST, 0, trittbrettSpeed);
    end
    
    -- Door2L_ST
    if Door2LCloseTimer > 0 or Door2L > 0.01 then
        Door2L_ST = LinearMove(dt, Door2L_ST, TRITTBRETT_EXTENDED, trittbrettSpeed);
    elseif not DoorsOpenCloseLeft_Active and Door2L == 0 then
        Door2L_ST = LinearMove(dt, Door2L_ST, 0, trittbrettSpeed);
    end
end

function ApplyDoorAnimations()
    -- TESTING: Try both types of animations
    -- EngineScript animations
    SetAnimTime("DoorsL1", Door1L);
    SetAnimTime("DoorsR1", Door1R);
    
    if not HasOnlyOneDoor then
        SetAnimTime("DoorsL2", Door2L);
        SetAnimTime("DoorsR2", Door2R);
    end
    
    -- TrailerScript animations
    SetAnimTime("INOVA_DoorsL1", Door1L);
    SetAnimTime("INOVA_DoorsR1", Door1R);
    SetAnimTime("INOVA_DoorsL1ST", Door1L_ST);
    SetAnimTime("INOVA_DoorsR1ST", Door1R_ST);
    
    if not HasOnlyOneDoor then
        SetAnimTime("INOVA_DoorsL2", Door2L);
        SetAnimTime("INOVA_DoorsR2", Door2R);
        SetAnimTime("INOVA_DoorsL2ST", Door2L_ST);
        SetAnimTime("INOVA_DoorsR2ST", Door2R_ST);
    end
end

function UpdateDoorIndicators()
    local anyLeftDoorOpen = Door1L > 0 or (not HasOnlyOneDoor and Door2L > 0);
    local anyRightDoorOpen = Door1R > 0 or (not HasOnlyOneDoor and Door2R > 0);
    local anyTrittbrettExtendedLeft = Door1L_ST > 0 or (not HasOnlyOneDoor and Door2L_ST > 0);
    local anyTrittbrettExtendedRight = Door1R_ST > 0 or (not HasOnlyOneDoor and Door2R_ST > 0);
    
    -- Left door indicators
    if DoorsOpenCloseLeft_Active or anyTrittbrettExtendedLeft or anyLeftDoorOpen then
        if anyLeftDoorOpen then
            local blinkValue = blinkState and 1 or 0;
            SetControlValue("DoorReleaseLeft_On", blinkValue);
        elseif anyTrittbrettExtendedLeft then
            SetControlValue("DoorReleaseLeft_On", 1);
        else
            SetControlValue("DoorReleaseLeft_On", 1);
        end
    else
        SetControlValue("DoorReleaseLeft_On", 0);
    end
    
    -- Right door indicators
    if DoorsOpenCloseRight_Active or anyTrittbrettExtendedRight or anyRightDoorOpen then
        if anyRightDoorOpen then
            local blinkValue = blinkState and 1 or 0;
            SetControlValue("DoorReleaseRight_On", blinkValue);
        elseif anyTrittbrettExtendedRight then
            SetControlValue("DoorReleaseRight_On", 1);
        else
            SetControlValue("DoorReleaseRight_On", 1);
        end
    else
        SetControlValue("DoorReleaseRight_On", 0);
    end
    
    -- TuerSchleife indicator (door loop - any door or Trittbrett not fully closed)
    local anyDoorOrTrittbrettActive;
    if HasOnlyOneDoor then
        anyDoorOrTrittbrettActive = Door1R > 0 or Door1L > 0 or 
                                    Door1R_ST > 0 or Door1L_ST > 0;
    else
        anyDoorOrTrittbrettActive = Door1R > 0 or Door2R > 0 or Door1L > 0 or Door2L > 0 or 
                                    Door1R_ST > 0 or Door2R_ST > 0 or Door1L_ST > 0 or Door2L_ST > 0;
    end
    
    if anyDoorOrTrittbrettActive then
        SetControlValue("TuerSchleife", 1);
        TuerSchleife = 1;
    else
        SetControlValue("TuerSchleife", 0);
        TuerSchleife = 0;
    end
    
    -- Update door release light ring nodes
    UpdateDoorReleaseLights();
end

function UpdateDoorReleaseLights()
    -- Activate door release light rings when DoorsOpenClose is active
    -- These are the green rings that light up around doors
    
    if DoorsOpenCloseLeft_Active then
        -- Activate left door lights
        Call("*:ActivateNode", "Tueren_L1_L_G", 1);
        if not HasOnlyOneDoor then
            Call("*:ActivateNode", "Tueren_L2_L_G", 1);
        end
    else
        -- Deactivate left door lights
        Call("*:ActivateNode", "Tueren_L1_L_G", 0);
        Call("*:ActivateNode", "Tueren_L2_L_G", 0);
    end
    
    if DoorsOpenCloseRight_Active then
        -- Activate right door lights
        Call("*:ActivateNode", "Tueren_R1_L_G", 1);
        if not HasOnlyOneDoor then
            Call("*:ActivateNode", "Tueren_R2_L_G", 1);
        end
    else
        -- Deactivate right door lights
        Call("*:ActivateNode", "Tueren_R1_L_G", 0);
        Call("*:ActivateNode", "Tueren_R2_L_G", 0);
    end
end

function UpdateForcedDoorClosing()
    -- Set ForcedDoorClosing when door signal is 0 but doors are still open
    -- Clear when all doors are fully closed
    
    local doorsLeft = GetControlValue("DoorsOpenCloseLeft") or 0;
    local doorsRight = GetControlValue("DoorsOpenCloseRight") or 0;
    
    local shouldBeForced = false;
    
    -- Check left side: signal is 0 but doors are open
    if doorsLeft == 0 then
        if HasOnlyOneDoor then
            if Door1L > 0 then
                shouldBeForced = true;
            end
        else
            if Door1L > 0 or Door2L > 0 then
                shouldBeForced = true;
            end
        end
    end
    
    -- Check right side: signal is 0 but doors are open
    if doorsRight == 0 then
        if HasOnlyOneDoor then
            if Door1R > 0 then
                shouldBeForced = true;
            end
        else
            if Door1R > 0 or Door2R > 0 then
                shouldBeForced = true;
            end
        end
    end
    
    -- Set or clear the flag
    if shouldBeForced then
        SetControlValue("ForcedDoorClosing", 1);
    else
        SetControlValue("ForcedDoorClosing", 0);
    end
end

-- Consist message handlers
function SelectDoorsToOpenOnRelease(msg)
    -- Called by consist message CM_DOOR_OPEN (102)
    -- This is for consist-wide door opening commands
    if msg == 'R' then
        DoorsOpenCloseRight_Active = not IsFlipped;
        DoorsOpenCloseLeft_Active = IsFlipped;
    elseif msg == 'L' then
        DoorsOpenCloseLeft_Active = not IsFlipped;
        DoorsOpenCloseRight_Active = IsFlipped;
    end
    
    -- Randomly open doors on active side
    if DoorsOpenCloseRight_Active then
        OpenRandomDoorsRight();
    end
    
    if DoorsOpenCloseLeft_Active then
        OpenRandomDoorsLeft();
    end
end

function CloseDoors()
    -- Called by consist message CM_DOOR_CLOSE (103)
    DoorsOpenCloseLeft_Active = false;
    DoorsOpenCloseRight_Active = false;
    
    -- Start delayed closing for any open doors
    if Door1L > 0 or (not HasOnlyOneDoor and Door2L > 0) then
        StartDelayedClosingLeft();
    end
    
    if Door1R > 0 or (not HasOnlyOneDoor and Door2R > 0) then
        StartDelayedClosingRight();
    end
end

local OPERATING_MODES = {
    PARKSTELLUNG_BESETZT = 0,
    PARKSTELLUNG_UNBESETZT = 1,
    FAHREN = 2,
    ABGERUESTET = 3
}

G_SomethingCoupledAtFront = 0
G_SomethingCoupledAtRear = 0
G_BothEndsCoupled = 0
G_ScheinwerferOn = false
G_GSMR_Active = false
G_NotlichtState = 0
G_NotlichtActive = false -- New: true when Notlicht is ON, false when OFF
G_VehicleInFront = false -- New: for Notlicht end detection
G_VehicleBehind = false -- New: for Notlicht end detection
G_FahrgastraumbeleuchtungOn = false
G_VoltmeterCurrent = 0
G_PantoNeedleCurrent = 0
G_VoltmeterActive = false  -- Synchronized voltmeter state for display across all cabs
G_GradientDebugTimer = 0  -- Timer for gradient debug output
G_Fahrsperre = false
G_SAPBEngaged = true
G_FahrsperreActive = false  -- Fahrsperre (drive lock) - prevents acceleration until throttle returned to 0
G_HauptschalterActivationTimer = 0  -- 13-second delay after Hauptschalter activation before allowing acceleration
G_BrakeWasApplied = false  -- Track if brake was applied (for Fahrsperre)
G_SchnellbremseWasApplied = false  -- Track if Schnellbremse (emergency brake) was applied
G_FSB_Blinking = false
G_FSB_BlinkTimer = 0
G_FSB_BlinkCount = 0
G_FSB_BlinkState = false
G_FSB_TargetState = false -- true = applying, false = releasing
G_FSB_ReleaseButtonPressed = false
G_Steuerstrom = false
G_ThisCabHasSteuerstrom = false  -- True only if THIS cab activated Steuerstrom
G_SteuerstromMasterCabID = 0  -- ID of cab that has Steuerstrom active (0 if none)
G_ThisCabID = 0  -- Unique ID for this cab
G_SteuerstromAlarmActive = false  -- True when Steuerstrom conflict alarm is active
G_Parkstellung = false
G_PantographRaised = false
G_PantographRaising = false
G_PantographLowering = false
G_PantographTimer = 0
G_PantographRaiseTime = 7.0
G_Hauptschalter = false
G_HauptschalterPressureDrop = false  -- Flag to trigger SL pressure drop on Hauptschalter activation
G_HauptschalterSoundTimer = 0  -- Timer for Hauptschalter sound ramp (13s up, 7.3s down)
G_HauptschalterLitTimer = 0     -- Timer for Hauptschalter light delay (5s)
G_HauptschalterSoundActive = false  -- Whether the sound is ramping up
G_HauptschalterSoundRampingDown = false  -- Whether the sound is ramping down
G_LampTestActive = false
G_LampTestTimer = 0
G_LampTestDuration = 3.0
G_BrakePressureGoal = 0.0
G_Fuellstellung_Active = false  -- True when in Füllstellung
G_Fuellstellung_Phase = 0  -- 0 = initial 1s delay, 1 = Hochdruckfüllstoss, 2 = settling to 5.4, 3 = slow descent to 5.0
G_Fuellstellung_Timer = 0  -- Timer for phase transitions
G_Fahrstellung_Overshoot_Active = false  -- True when settling from Fahrstellung overshoot
G_Fuellstellung_Dwell_Timer = 0          -- Total seconds spent in Füllstellung this visit
G_PostFuellstellung_Descent = false     -- True when continuing slow descent after Füllstellung Phase 3
G_Fuellstellung_Phase3_Target = 5.4    -- Current target of the slow descent (ticks from 5.4 to 5.0)
G_Fahrstellung_Dwell_Timer = 0           -- Seconds spent dwelling in Fahrstellung before overshoot fires
G_LangsamgangReset = false
G_Federspeicher = false
G_RC = true
G_cabActive = true;
G_CabLight = false;
G_SAPB_ReleaseTimer = 0
G_SAPB_ReleaseLightActive = false
G_ZugsammelschieneLIT = false
G_ZugsammelschieneTimer = 0
G_ZugsammelschieneDelay = 8.0
G_LampTestActive = false
G_LampTestTimer = 0
G_LampTestDuration = 5.0

-- Pressure initialization variables
G_PressureInitTimer = 0  -- Timer for initial pressure buildup
G_PressureInitComplete = false  -- Whether initial pressure buildup is done
G_PressureInitDuration = 3.0  -- 3 seconds for initial pressure buildup

-- Auto-setup timer for Steuerstrom switch
G_AutoSetup_SteuerstromTimer = 0
G_AutoSetup_Active = false
-- Message tracking flags (prevent spam)
G_MessageShown_SteuerstromAlarm = false
G_MessageShown_ParkstellungBrake = false
G_MessageShown_ParkstellungThrottle = false
G_MessageShown_ThrottleNoReverser = false
G_MessageShown_ReverserThrottleNotZero = false
G_MessageShown_ReverserTrainMoving = false
G_StartupTimer = 0  -- Prevent control interlock messages during initialization
G_StartupComplete = false
G_NotbremsTimer = 0
G_NotbremsBlinkCount = 0
G_NotbremsBlinkState = false
G_ZTBBlinkState = false
G_ZTBBlinkTimer = 0
G_HauptschalterPending = false
G_ParkstellungPendingAfterHauptschalter = false  -- Flag to enter Parkstellung after Hauptschalter activates
G_FahrgastraumEinButtonPressed = false
G_FahrgastraumAusButtonPressed = false
G_NotlichtButtonPressed = false
G_Rangierbremse = 0.0
G_MirrorExtended = false
G_MirrorButtonPressed = false
G_MirrorAnimCurrent = 0
G_ZTB_CountTimer = nil
G_ZTB_RecountDelay = 0
G_ZTB_CountCooldown = 0  -- Cooldown to prevent multiple overlapping counts
G_SteuerstromButtonPressed = false
G_ParkstellungButtonPressed = false
G_Zwangsbremse = false
G_VST_Mode = 0
G_VST_MasterRandomID = 0
G_VST_CompareDirection = nil  -- Track which direction we're comparing VST with
G_VST_FirstUpdateDelay = 3  -- Wait 3 frames before sending IDs at startup
G_VST_OtherID = 0
G_Klimaanlage_Current = 0  -- Current AC sound level (can be decimal for smooth transition)
G_Klimaanlage_Target = 0  -- Target AC sound level
G_Klimaanlage_DelayTimer = 0  -- Delay before transition starts
G_Klimaanlage_TransitionTimer = 0  -- Timer for transition progress

-- Buegelfeuer (Pantograph arcing) system - only active in winter
G_Season = 0  -- Current season (0=Spring, 1=Summer, 2=Autumn, 3=Winter)
G_BuegelfeuerActive = false  -- Is Buegelfeuer currently flashing
G_BuegelfeuerTimer = 0  -- Timer for arc duration
G_BuegelfeuerNextArcTimer = 0  -- Timer until next arc
G_BuegelfeuerBurstMode = false  -- Are we in a burst of multiple arcs
G_BuegelfeuerBurstCount = 0  -- Number of arcs remaining in current burst
G_BuegelfeuerBurstInterval = 0  -- Interval between arcs in a burst

-- Wheelslip Tachozappeln (Speedometer flickering during wheelslip)
G_WheelSlip = 0  -- Wheelslip state (0 = no slip, 1 = slip detected)
G_WheelSlipTimer = 0  -- Timer for wheelslip duration
G_Schleuderbremse_Active = false  -- Schleuderbremse active state
G_Schleuderbremse_Manual = false  -- Manual activation by driver (hold button)
G_Schleuderbremse_AutoTimer = 0.0  -- Minimum 2s hold timer for automatic activation
G_SpeedometerLastValue = 0  -- Last speedometer reading
G_LastSlipCalcTime = 0  -- Last time wheelslip calculation was done
G_DisplayedSpeedometer = 0  -- Currently displayed speedometer value (smoothed)
G_Klimaanlage_Delay = 5.0  -- 5 seconds delay before starting transition
G_Klimaanlage_TransitionTime = 3.5  -- 3.5 seconds for transition
G_Klimaanlage_IsTransitioning = false  -- Whether currently transitioning
G_Klimaanlage_StartValue = 0  -- Value when transition started
G_Klimaanlage_TotalTransitionTime = 0  -- Total time for this transition (calculated from distance)
G_Klimaanlage_SwitchPosition = 0  -- Switch position (stored even when Steuerstrom is off)

-- Mirror indicator door tracking (consist-wide)
G_ConsistDoorsOpenLeft = false  -- Are any doors open on left side across entire consist
G_ConsistDoorsOpenRight = false  -- Are any doors open on right side across entire consist
G_LocalDoorsOpenLeft = false  -- Are doors open on left side in this car
G_LocalDoorsOpenRight = false  -- Are doors open on right side in this car

-- Magnetschienenbremse variables
G_MagnetbrakeButtonPressed = false  -- Manual button state
G_MGBrake_AnimTime = 0  -- Current animation time (0 to 4.16666666667)
G_MGBrake_Animating = false  -- Whether currently animating
G_MGBrake_Target = 0  -- Target animation state (0 or 4.16666666667)
G_MagnetbrakeActive = false  -- Current active state (manual or automatic)

-- Bremsanzeiger (Brake Indicator) variables
G_Bremsanzeiger_Current = 1.0  -- Current animated value (0 = brake applied, 1 = brake released)
G_Bremsanzeiger_Target = 1.0  -- Target value - ONLY affected by BCPressure (0 = brake applied, 1 = brake released)
G_Bremsanzeiger_FSB_Current = 1.0  -- Current animated value for FSB indicator
G_Bremsanzeiger_FSB_Target = 1.0  -- Target value for FSB indicator (0 = FSB applied, 1 = FSB released)

-- Fst (Führerstandsfahrzeug) check timer
G_FstCheckTimer = 0  -- Timer to delay Fst check in InitialUpdate
G_FstCheckComplete = false  -- Whether Fst check has been done
G_KlimaNotAus = false

G_PZB = PZB

function OnCustomSignalMessage(arg)
    G_PZB:SignalMessage(arg)
end

function OnConsistMessage(message, argument, direction)
    ConsistMessage(message, argument, direction)
end

function OnControlValueChange(name, index, value)
    -- Block all controls when Steuerstrom alarm is active
    if G_SteuerstromAlarmActive and name ~= "Steuerstrom_SW" then
        if not G_MessageShown_SteuerstromAlarm then
            SysCall("ScenarioManager:ShowAlertMessageExt", "Steuerstrom-Konflikt / Conflit / Conflitto / Conflict", "Schalter ausschalten!\nDesactiver l'interrupteur!\nDisattivare l'interruttore!\nSwitch off!", 2, 0)
            G_MessageShown_SteuerstromAlarm = true
        end
        return
    else
        G_MessageShown_SteuerstromAlarm = false
    end

    -- Prevent control movement when Parkstellung is active
    -- VirtualBrake interlock: Lock when in Parkstellung
    if G_Parkstellung then
        Call("*:LockControl", "VirtualBrake", 0, 1) -- Lock
        if name == "VirtualBrake" and not G_MessageShown_ParkstellungBrake then
            SysCall("ScenarioManager:ShowAlertMessageExt", "Bremsventil / Robinet frein / Rubinetto freno / Brake valve", "Nicht in Parkstellung\nPas en position parking\nNon in posizione parcheggio\nNot in parking mode", 1.5, 0)
            G_MessageShown_ParkstellungBrake = true
        end
    else
        Call("*:LockControl", "VirtualBrake", 0, 0) -- Unlock
        G_MessageShown_ParkstellungBrake = false
    end

    -- VirtualThrottle interlock: Lock when in Parkstellung OR when Reverser is at neutral
    local currentReverser = GetControlValue("Reverser") or 0
    local reverserAtNeutral = math.abs(currentReverser) < 0.1
    
    if G_Parkstellung then
        Call("*:LockControl", "VirtualThrottle", 0, 1) -- Lock
        if name == "VirtualThrottle" and not G_MessageShown_ParkstellungThrottle then
            SysCall("ScenarioManager:ShowAlertMessageExt", "Fahrschalter / Controleur / Controllore / Throttle", "Nicht in Parkstellung\nPas en position parking\nNon in posizione parcheggio\nNot in parking mode", 1.5, 0)
            G_MessageShown_ParkstellungThrottle = true
        end
    elseif reverserAtNeutral then
        Call("*:LockControl", "VirtualThrottle", 0, 1) -- Lock
        if name == "VirtualThrottle" and not G_MessageShown_ThrottleNoReverser and G_StartupComplete then
            SysCall("ScenarioManager:ShowAlertMessageExt",
                "Fahrschalter / Controleur / Controllore / Throttle", "Fahrtrichtung waehlen\nChoisir sens de marche\nScegliere direzione\nSelect direction", 1.5, 0)
            G_MessageShown_ThrottleNoReverser = true
        end
    else
        Call("*:LockControl", "VirtualThrottle", 0, 0) -- Unlock
        G_MessageShown_ParkstellungThrottle = false
        G_MessageShown_ThrottleNoReverser = false
    end

    -- Reverser interlock: Lock when VirtualThrottle is not at 0 OR when train is moving
    local currentVirtualThrottle = GetControlValue("VirtualThrottle") or 0
    local throttleNotAtZero = math.abs(currentVirtualThrottle) > 0.1
    local currentSpeed = math.abs(Call("GetSpeed") or 0) * 3.6 -- km/h
    local trainIsMoving = currentSpeed > 1.0 -- Lock if speed > 1 km/h
    
    if throttleNotAtZero then
        Call("*:LockControl", "Reverser", 0, 1) -- Lock
        if name == "Reverser" and not G_MessageShown_ReverserThrottleNotZero and G_StartupComplete then
            SysCall("ScenarioManager:ShowAlertMessageExt",
                "Wendeschalter / Inverseur / Invertitore / Reverser", "Fahrschalter auf 0\nControleur sur 0\nControllore su 0\nThrottle to 0", 1.5, 0)
            G_MessageShown_ReverserThrottleNotZero = true
        end
    elseif trainIsMoving then
        Call("*:LockControl", "Reverser", 0, 1) -- Lock
        if name == "Reverser" and not G_MessageShown_ReverserTrainMoving and G_StartupComplete then
            SysCall("ScenarioManager:ShowAlertMessageExt",
                "Wendeschalter / Inverseur / Invertitore / Reverser", "Nicht waehrend Fahrt\nPas en marche\nNon durante la marcia\nNot while moving", 1.5, 0)
            G_MessageShown_ReverserTrainMoving = true
        end
    else
        Call("*:LockControl", "Reverser", 0, 0) -- Unlock
        G_MessageShown_ReverserThrottleNotZero = false
        G_MessageShown_ReverserTrainMoving = false
    end

    if name == "PZB_Wachsam" and value > 0.99 then
        G_PZB:Wachsam()
    end
    if name == "PZB_Frei" and value > 0.99 then
        G_PZB:Frei()
    end
    if name == "PZB_Befehl" then
        G_PZB:Befehl(value)
    end

    SetControlValue(name, value)

    -- Setup systems
    SteuerstromSwitch(name, value)
    PantographButton(name, value)
    HauptschalterButton(name, value)

    -- Other controls
    TimsButton(name, value)
    WiperModeControl(name, value);
    KlimaanlageSwitch(name, value)
    ParkstellungButton(name, value)
    ParkingBrake(name, value)
    CabLightControl(name, value)
    NotlichtButton(name, value)
    FahrgastraumbeleuchtungButton(name, value)
    ScheinwerferButton(name, value)
    MirrorButton(name, value)
    BremsprobemodeButton(name, value)
    MagnetbrakeButton(name, value)
    KompressorButton(name, value)
    KlimaNotAusButton(name, value)
    SchleuderbremseButton(name, value)

    if name == "Bremsventil" then
        G_BrakePressureGoal = ZugBremsHebel(value)
    end
end


function UpdatePassengers()
    -- Get current destination from RV number (last character)
    local currentRV = Call("*:GetRVNumber")
    local dest = "m"  -- Default to not in service
    
    if currentRV and string.len(currentRV) >= 5 then
        dest = string.sub(currentRV, 5, 5)
    end
    
    -- Check if train is in service (destination NOT m, n, o, p, or q)
    local isInService = dest ~= "m" and dest ~= "n" and dest ~= "o" and dest ~= "p" and dest ~= "q"
    
    -- Activate passengers only if: in service AND lights are on
    if isInService and G_FahrgastraumbeleuchtungOn then
        Call("*:ActivateNode", "Passengers", 1)
    else
        Call("*:ActivateNode", "Passengers", 0)
    end
end
function InitialUpdate(dt)
    SetControlValue("Startup", lambda(G_cabActive, 1, 0));
    -- HandBrake will be set after Fst check (0.5 seconds delay)
    G_FstCheckTimer = 0  -- Start timer for Fst check
    G_FstCheckComplete = false
    -- Initialize VirtualThrottle to 0 (neutral position)
    SetControlValue("VirtualThrottle", 0)
    SetControlValue("Federspeicher_SND", 1)
    TV_Initialize()
    UpdateHeadlights()
    Call("*:ActivateNode", "Innenraum_lit", 0)
    Call("*:ActivateNode", "Passengers", 0)
    Call("*:ActivateNode", "lights_notlicht", 0)
    Call("Notlicht_1:Activate", 0)
    Call("Notlicht_2:Activate", 0)
    Call("Notlicht_3:Activate", 0)
    -- Initialize Buegelfeuer as off
    Call("Buegelfeuer:Activate", 0)
    SetControlValue("Buegelfeuer", 0)
    -- Initialize snow particles as deactivated
    Call("SchneeL:SetEmitterActive", 0)
    Call("SchneeR:SetEmitterActive", 0)
    Call("SchneeL:SetEmitterRate", 0)
    Call("SchneeR:SetEmitterRate", 0)
    -- Initialize speedometer for wheelslip flickering
    SetControlValue("vSpeedometerKPH", 0, 0)
    SetControlValue("vAbsoluteSpeed", 0, 0)
    SetControlValue("vWheelSlip", 0, 1.0)  -- Initialize custom wheelslip (1.0 = no slip)
    G_SpeedometerLastValue = 0
    G_DisplayedSpeedometer = 0
    G_WheelSlip = 0
    G_LastSlipCalcTime = 0
    -- Initialize Fernlicht nodes
    Call("Fernlicht_1:Activate", 0)
    Call("Fernlicht_2:Activate", 0)
    Call("Fernlicht_3:Activate", 0)
    Call("*:ActivateNode", "TIMS_Dn", 0)
    Call("*:ActivateNode", "TIMS_Up", 0)
    Call("*:ActivateNode", "TIMS_Enter", 0)
    Call("*:ActivateNode", "Body2.002", 0)
    Call("*:ActivateNode", "Tueren_L1_L_G", 0);
    Call("*:ActivateNode", "Tueren_L1_R_G", 0);
    Call("*:ActivateNode", "Tueren_L2_L_G", 0);
    Call("*:ActivateNode", "Tueren_L2_R_G", 0);
    Call("*:ActivateNode", "Tueren_R1_L_G", 0);
    Call("*:ActivateNode", "Tueren_R1_R_G", 0);
    Call("*:ActivateNode", "Tueren_R2_L_G", 0);
    Call("*:ActivateNode", "Tueren_R2_R_G", 0);
    G_ScheinwerferOn = false
    SetControlValue("Headlights", 0)
    SetControlValue("Scheinwerfer_LIT", 0)
    -- Initialize consist length tracking (prevents false trigger on startup)
    gStartingLengthPrev = Call("*:GetConsistLength") or 0
    gPreviousConsistLength = gStartingLengthPrev  -- Store for uncoupling detection
    gUpdateCouplers = 0
    UpdateConsistLength()
    CheckCouplings()
    Call("TIMS:SetText", "?????");
    local wgnb = Call("*:GetRVNumber");

    --G_PZB:Start()
    
    -- Convert RV number to Decals format (remove last char, convert digits to letters)
    if wgnb and string.len(wgnb) >= 1 then
        -- Remove the last character (TIMS destination)
        local rvWithoutDest = string.sub(wgnb, 1, string.len(wgnb) - 1);
        
        -- Convert each digit to letter (0=a, 1=b, ..., 9=j)
        local decalsText = "";
        for i = 1, string.len(rvWithoutDest) do
            local char = string.sub(rvWithoutDest, i, i);
            local digit = tonumber(char);
            if digit then
                -- Convert digit to letter
                local letters = "abcdefghij";
                decalsText = decalsText .. string.sub(letters, digit + 1, digit + 1);
            else
                -- Keep non-digit characters as-is
                decalsText = decalsText .. char;
            end
        end
        
        Call("Decals:SetText", decalsText);
    else
        Call("Decals:SetText", "cabc");  -- Default fallback (2016)
    end
    
    ZTB_InitiateCount()
    TIMS_Initialize();
    GSMR_Initialize();
    DoorController_Initialize()
    UpdateVST()
    
    
    -- Auto-setup if player is in this cab
    local isEngineWithKey = Call("GetIsEngineWithKey")
    if isEngineWithKey == 1 then
        -- Player is in this cab - start auto-setup sequence
        SetControlValue("Federspeicher_SND", 1)
        G_AutoSetup_Active = true
        G_AutoSetup_SteuerstromTimer = 0
        
        -- Immediately set up everything except Steuerstrom activation
        -- 1. Raise Pantograph
        G_PantographRaised = true
        SetControlValue("PantographControl", 1)
        -- Broadcast pantograph state
        SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 1)
        SendConsistMessage(CM_PANTOGRAPH_RAISE, "", 0)
        
        -- 2. Start Hauptschalter sound ramp
        G_HauptschalterSoundActive = true
        G_HauptschalterSoundTimer = 0
        SetControlValue("Hauptschalter_SND", 0)
        
        -- 3. SAPB (Federspeicherbremse) is already engaged by default - keep it
        -- DO NOT activate Parkstellung in autosetup

        Call("Parklicht:Activate", 0)
        Call("*:ActivateNode", "lights_parklicht", 0)
        SendConsistMessage(CM_DISABLE_PARKLIGHT, "", 1)
        SendConsistMessage(CM_DISABLE_PARKLIGHT, "", 0)
        UpdateIndicatorLights()
    end
end

local _hasUpdated = false

function Update(dt)
    if not _hasUpdated then
        InitialUpdate(dt)
        _hasUpdated = true
    end

    -- Fst check: After 0.5 seconds, check if this car has Fst=1 (cab car)
    if not G_FstCheckComplete then
        G_FstCheckTimer = G_FstCheckTimer + dt
        if G_FstCheckTimer >= 0.5 then
            G_FstCheckComplete = true
            local fstVal = GetControlValue("Fst") or 0
            if fstVal < 0.5 then
                -- This is NOT a cab car (Fst=0) - release FSB if it was engaged
                if G_SAPBEngaged then
                    G_SAPBEngaged = false
                    SetControlValue("HandBrake", 0)
                end
            else
                -- This IS a cab car (Fst=1) - apply HandBrake based on G_SAPBEngaged
                SetControlValue("HandBrake", lambda(G_SAPBEngaged, 1, 0))
                -- Broadcast FSB status to all other cabs in the consist
                SendConsistMessage(CM_FSB_STATUS, lambda(G_SAPBEngaged, 1, 0), 0)
                SendConsistMessage(CM_FSB_STATUS, lambda(G_SAPBEngaged, 1, 0), 1)
            end
        end
    end

    -- Startup timer: Prevent control interlock messages during initialization
    if not G_StartupComplete then
        G_StartupTimer = G_StartupTimer + dt
        if G_StartupTimer >= 2.0 then
            G_StartupComplete = true
        end
    end

    -- Auto-setup: Activate Steuerstrom after 2 seconds
    if G_AutoSetup_Active then
        G_AutoSetup_SteuerstromTimer = G_AutoSetup_SteuerstromTimer + dt
        if G_AutoSetup_SteuerstromTimer >= 1.0 then
            -- Activate Steuerstrom after 2 second delay
            G_Steuerstrom = true
            G_ThisCabHasSteuerstrom = true
            G_cabActive = true
            G_RC = false
            
            -- Set VirtualBrake to 0.25 (Fahrstellung) after delay
            SetControlValue("VirtualBrake", 0.25)
            
            GSMR_Activate()
            
            SetAnimTime("pantograph", 2)
            SetControlValue("GSM-R_lit", 1)
            SetControlValue("Steuerstrom_SW", 1)
            SetControlValue("Headlights", 1)
            G_VoltmeterActive = true
            -- Broadcast Steuerstrom state
            SendConsistMessage(CM_STEUERSTROM_CLAIM, G_ThisCabID, 0)
            SendConsistMessage(CM_STEUERSTROM_CLAIM, G_ThisCabID, 1)
            
            Call("SendConsistMessage", CM_DOMINANT_TRAIN, 0, 1)
            Call("SendConsistMessage", CM_DOMINANT_TRAIN, 0, 0)
            SendConsistMessage(CM_VOLTMETER_ON, 0, 0)
            SendConsistMessage(CM_VOLTMETER_ON, 0, 1)

            
        
        -- 2. Enable Hauptschalter
        G_Hauptschalter = true
        G_HauptschalterPressureDrop = true  -- Trigger SL pressure drop
        TV_SetMainSwitch(true)
        -- Broadcast Hauptschalter state
        SendConsistMessage(CM_HAUPTSCHALTER_ON, 0, 0)
        SendConsistMessage(CM_HAUPTSCHALTER_ON, 0, 1)

            G_FahrgastraumbeleuchtungOn = true
                    -- Turn on lit interior, turn off normal interior
                    Call("*:ActivateNode", "Innenraum_lit", 1)
                    Call("*:ActivateNode", "Innenraum", 0)
                    -- Turn off the "Aus" indicator light
                    SetControlValue("Fahrgastbeleuchtung_Aus_LIT", 0)
                    -- Update passengers in this car
                    if UpdatePassengers then
                        UpdatePassengers()
                    end
                    -- Send consist message to all cars to turn lights ON
                    SendConsistMessage(CM_FAHRGASTRAUM_ON, 0, 1) -- Forward
                    SendConsistMessage(CM_FAHRGASTRAUM_ON, 0, 0) -- Backward
            -- Deactivate auto-setup
            G_AutoSetup_Active = false
        end
    end

    -- Zwangsbremsung: Clear when train stops
    if G_Zwangsbremse then
        local currentSpeed = math.abs(Call("GetSpeed") or 0) * 3.6 -- km/h
        if currentSpeed < 0.5 then
            -- Train has stopped - clear Zwangsbremsung
            G_Zwangsbremse = false
        end
    end

    -- VST: Send ID after a few frames delay (ensures coupling states are fully set)
    if G_VST_FirstUpdateDelay > 0 then
        G_VST_FirstUpdateDelay = G_VST_FirstUpdateDelay - 1
        if G_VST_FirstUpdateDelay == 0 then
            UpdateVSTCable()
        end
    end
    
    
    -- ZTB: Decrement cooldown timer
    if G_ZTB_CountCooldown > 0 then
        G_ZTB_CountCooldown = G_ZTB_CountCooldown - 1
    end
    
    -- ZTB: Recount after delay if scheduled (only if cooldown is not active)
    if G_ZTB_RecountDelay > 0 then
        G_ZTB_RecountDelay = G_ZTB_RecountDelay - 1
        if G_ZTB_RecountDelay == 0 and G_ZTB_CountCooldown == 0 then
            ZTB_InitiateCount()
            G_ZTB_CountCooldown = 120  -- Set 120-frame cooldown to prevent other cars from counting
        end
    end

    -- Update setup systems
    TV_Update(dt)
    UpdatePantograph(dt)
    UpdateLampTest(dt)
    UpdateIndicatorLights()
    CheckSteuerstromConflict()  -- Check for Steuerstrom conflicts every frame
    UpdateWindowAndDoorAnimations()
    Door_Update(dt)
    UpdateMirrorIndicators()  -- Update mirror door indicators
    StopRequest_Update(dt)  -- Update stop request system
    
    -- Update pressure initialization timer
    if not G_PressureInitComplete then
        G_PressureInitTimer = G_PressureInitTimer + dt
        if G_PressureInitTimer >= G_PressureInitDuration then
            G_PressureInitComplete = true
        end
    end
    
    local previousConsistLength = gStartingLength  -- Store before update for uncoupling detection
    UpdateConsistLength()
    if gUpdateCouplers == 1 then
        CheckCouplings()
        
        -- VST: Schedule re-negotiation after 1 frame delay
        -- This ensures both wagons are truly reset before sending new IDs
        G_VST_Mode = 0  -- Reset mode
        SetControlValue("VST", 0)
        G_VST_CompareDirection = nil  -- Reset direction tracking
        G_VST_MasterRandomID = math.random(1, 999999)  -- Generate new random ID
        G_VST_FirstUpdateDelay = 1  -- Will send ID in next Update()
        UpdateVST()  -- Update nodes immediately (forces outer endcars to Idle)

        -- Steuerstrom: Clear conflict state ONLY when uncoupling (consist got smaller)
        if gStartingLength < previousConsistLength then
            G_SteuerstromMasterCabID = 0
            G_SteuerstromAlarmActive = false
            SetControlValue("Steuerstrom_SND", 0)
        end
        -- Steuerstrom: If this cab has Steuerstrom, re-broadcast claim to detect conflicts
        if G_ThisCabHasSteuerstrom then
            Call("SendConsistMessage", CM_STEUERSTROM_CLAIM, G_ThisCabID, 0)
            Call("SendConsistMessage", CM_STEUERSTROM_CLAIM, G_ThisCabID, 1)
        end
        
        if G_NotlichtActive then
            UpdateNotlicht() -- Update lights when coupling changes
        end
        
        -- ZTB: Schedule recount after delay when coupling changes (all cars with randomized delay)
        G_ZTB_RecountDelay = 150 + math.random(0, 30)  -- Wait 150-180 frames (~2.5-3 seconds), randomized to prevent simultaneous counts
        
    end
    WiperUpdate(dt);
    UpdateKlimaanlage(dt)
    
    -- Update instrument lighting based on lever position
    local instrValue = GetControlValue("Instrumentenbeleuchtung_SW") or 0
    InstrumentenbeleuchtungControl("Instrumentenbeleuchtung_SW", instrValue)

    -- Control pantograph value
    if G_PantographRaised then
        SetControlValue("PantographControl", 1)
    else
        SetControlValue("PantographControl", 0)
    end

    -- Only allow traction if all power conditions met
    if CanApplyPower() then
        Fahrrechner(dt)
    else
        -- Immediately reset all power/brake states when power is lost
        SetControlValue("Regulator", 0)
        SetControlValue("DynamicBrake", 0)
        howMuchThrottle = 0
        targetThrottle = 0
        brakeStrength = 0
        targetBrakeStrength = 0
        cruiseControlActive = false
        cruiseTargetSpeed = 0
        filteredGradient = 0
    end

    -- Headlight interlock: Only check Steuerstrom and Notlicht (power loss handled in specific events)
    if not G_Steuerstrom or G_NotlichtActive then
        SetControlValue("Headlights", 0)
    end

    UpdatePneumaticBrakeIndicators()
    UpdateHeadlights()
    UpdateNeedles(dt)
    UpdateMirror(dt)
    UpdateHauptschalterTimers(dt)
    TIMS_Update(dt);
    GSMR_Update(dt);
    UpdateZugsammelschiene(dt)
    UpdateFSB(dt)
    TimedThings(dt);
    Bremsrechner(dt)
    UpdateMagnetschienenbremse()
    UpdateMGBrakeAnimation(dt)
    UpdateBremsanzeiger(dt)  -- Update brake indicators with smooth animation
    Bremsventil(dt)
    UpdateBuegelfeuer(dt)  -- Update pantograph arcing effects
    UpdateSnowParticles(dt)  -- Update snow particle effects based on speed
    UpdateWheelslipDetection(dt)  -- Detect wheelslip conditions
    UpdateSchleuderbremse(dt)  -- Update anti-wheelslip brake system
    UpdateSpeedometerWithWheelslip(dt)  -- Update speedometer with wheelslip flickering
    -- G_PZB:Update(dt)
    HandlePZB()
end

-- -- Handle PZB Outputs
-- function HandlePZB()
--     G_Fahrsperre = G_PZB.zwangsbremse 
--     G_Zwangsbremse = G_PZB.zwangsbremse
--     local p_text = lambda(G_PZB.leuchtmelder[55],"b","a")
--     p_text = p_text .. lambda(G_PZB.leuchtmelder[70],"b","a")
--     p_text = p_text .. lambda(G_PZB.leuchtmelder[85],"b","a")
--     p_text = p_text .. lambda(G_PZB.leuchtmelder[40],"b","a")
--     p_text = p_text .. lambda(G_PZB.leuchtmelder[500],"b","a")
--     p_text = p_text .. lambda(G_PZB.leuchtmelder[1000],"b","a")
--     --SysCall("ScenarioManager:ShowAlertMessageExt", "Debug:", 'Hund ' .. p_text, 1, 0);
--     Call("PZB:SetText", p_text);
-- end

-- Continue with existing Fahrrechner, Bremsrechner etc...

-- Global variables declaration
local howMuchThrottle = 0
local targetThrottle = 0
local previousPos = 0
local brakeStrength = 0
local targetBrakeStrength = 0
local cruiseControlActive = false
local cruiseTargetSpeed = 0
local previousSpeed = 0
local lastThrottleValue = 2.0
local tappingTimer = 0
local tappingUp = false
local tappingDown = false
local comingFromM = false
local displayedAmmeterSoll = 0
local displayedAmmeterIst = 0
-- Ammeter velocity tracking for smooth continuous movement
local ammeterCurrentVelocity = 0  -- Current rate of change (A/sec)

-- Smooth easing function for velocity ramping
-- Returns a factor between 0 and 1 based on how close we are to target
local function GetEasingFactor(distanceToTarget, maxChangeRate)
    -- Define easing zones
    local easeInDistance = maxChangeRate * 0.3   -- Start easing in over last 30% of max change
    local easeOutDistance = maxChangeRate * 0.3  -- Start easing out over first 30% of max change
    
    local absDistance = math.abs(distanceToTarget)
    
    -- Ease out when close to target (deceleration)
    if absDistance < easeInDistance then
        -- Cubic ease-out: starts fast, slows down
        local t = absDistance / easeInDistance
        return t * t * t
    -- Ease in when far from target (acceleration)
    elseif absDistance > (maxChangeRate * 2) then
        -- Start from current velocity and accelerate
        return math.min(1.0, 0.5 + (absDistance / (maxChangeRate * 4)))
    else
        -- Full speed in the middle
        return 1.0
    end
end

-- Cruise control variables
local cruiseIntegralError = 0
local cruiseLastError = 0
local filteredGradient = 0  -- Smoothed gradient value to prevent sudden changes
-- Throttle hold variables for moving back before reaching max
local heldThrottleM = 0.682 -- Maximum for M position (can be reduced if moving back early)
local heldThrottlePlus = 0.864 -- Maximum for + position (can be reduced if moving back early)

function SmoothMove(dt, cur, tgt, mul)
    if (cur == tgt) then
        return cur
    end

    if tgt > cur then
        cur = cur + (dt * mul)
        if cur > tgt then
            cur = tgt
        end
    elseif tgt < cur then
        cur = cur - (dt * mul)
        if cur < tgt then
            cur = tgt
        end
    end

    return cur
end

function SmoothMoveEaseOut(dt, cur, tgt, smoothness)
    -- Ease-out interpolation: movement speed is proportional to distance from target
    -- Higher smoothness = smoother/slower animation (typical values: 3-10)
    if math.abs(cur - tgt) < 0.001 then
        return tgt
    end
    
    local diff = tgt - cur
    local speed = diff * smoothness * dt
    cur = cur + speed
    
    -- Clamp to target if we overshoot
    if (diff > 0 and cur > tgt) or (diff < 0 and cur < tgt) then
        cur = tgt
    end
    
    return cur
end

function Fahrrechner(dt)
    -- If Steuerstrom is off, force ammeter displays to drop to zero
    if not G_Steuerstrom then
        -- Rapidly drop ammeter displays to 0 when Steuerstrom is off
        local dropSpeed = 2000 * dt -- Fast drop rate: 2000 A/sec
        
        if displayedAmmeterSoll > 0 then
            displayedAmmeterSoll = math.max(0, displayedAmmeterSoll - dropSpeed)
            SetControlValue("AmmeterDisplaySoll", displayedAmmeterSoll)
        end
        
        if displayedAmmeterIst > 0 then
            displayedAmmeterIst = math.max(0, displayedAmmeterIst - dropSpeed)
            SetControlValue("AmmeterDisplayIst", displayedAmmeterIst)
        end
        
        -- Reset velocity to prevent carryover
        ammeterCurrentVelocity = 0
        
        -- Also reset throttle and brake
        SetControlValue("Regulator", 0)
        SetControlValue("DynamicBrake", 0)
        
        -- Early return - don't process any throttle/brake logic
        return
    end
    
    local throttleValue = GetControlValue("VirtualThrottle")
    local currentSpeedMPS = Call("GetSpeed") or 0
    local currentSpeedKPH = currentSpeedMPS * 3.6 -- Convert m/s to km/h
    local speedChangeRate = previousSpeed - currentSpeedKPH
    -- FAHRSPERRE (Drive Lock) SYSTEM
    -- Prevents acceleration when:
    -- 1. Train brake has been applied ABOVE 15 km/h (must return throttle to 0)
    --    Note: Engine brake does NOT trigger Fahrsperre
    -- 2. FSB/SAPB is engaged
    -- 3. Schnellbremse (VirtualBrake >= 1.1) has been applied (must return throttle to 0)
    -- 4. Hauptschalter activated while throttle not at 0
    -- 5. Within 13 seconds of Hauptschalter activation
    -- 6. Doors are open
    --    Below 15 km/h, brakes don't trigger Fahrsperre (for hill starts)
    
    local trainBrake = GetControlValue("TrainBrakeControl") or 0
    local engineBrake = GetControlValue("VirtualEngineBrakeControl") or 0    
    local doorsLeft = GetControlValue("DoorsOpenCloseLeft");
    local doorsRight = GetControlValue("DoorsOpenCloseRight");
    local throttleAtZero = (throttleValue >= -0.1 and throttleValue <= 0.9)
    
    -- Update Hauptschalter activation timer
    if G_Hauptschalter and G_HauptschalterActivationTimer < 13.0 then
        G_HauptschalterActivationTimer = G_HauptschalterActivationTimer + dt
    end
    
    -- Check if brakes are currently applied (excluding engine brake)
    local brakesApplied = (trainBrake > 0.01)
    
    -- Set Fahrsperre when brakes applied
    if brakesApplied and currentSpeedKPH > 15.0 then
        G_BrakeWasApplied = true
        G_FahrsperreActive = true
    end
    

    -- Clear brake-induced Fahrsperre if speed drops below 15 km/h
    if G_BrakeWasApplied and currentSpeedKPH <= 15.0 then
        G_FahrsperreActive = false
        G_BrakeWasApplied = false
    end

    -- Set Fahrsperre when FSB/SAPB engaged (at all speeds)
    if G_SAPBEngaged then
        G_FahrsperreActive = true
    end
    
    -- Get VirtualBrake value to check for Schnellbremse
    local virtualBrake = GetControlValue("VirtualBrake") or 0
    
    -- Set Fahrsperre when Schnellbremse (emergency brake) is applied (VirtualBrake >= 1.1)
    if virtualBrake >= 1.1 then
        G_SchnellbremseWasApplied = true
        G_FahrsperreActive = true
    end
    
    -- Clear Fahrsperre only when throttle returns to 0 and brakes released and FSB released and no Schnellbremse active
    if throttleAtZero and not brakesApplied and not G_SAPBEngaged and virtualBrake < 1.1 then
        G_FahrsperreActive = false
        G_BrakeWasApplied = false
        G_SchnellbremseWasApplied = false
    end

    if doorsLeft == 1 or doorsRight == 1 then
        G_FahrsperreActive = true
    end

    
    
    -- Check if acceleration should be blocked
    local fahrsperreBlocking = G_FahrsperreActive or (G_Hauptschalter and G_HauptschalterActivationTimer < 13.0)
    

    -- Track if we're coming from M position for cruise control activation
    if throttleValue > 2.5 and throttleValue <= 3.9 then
        comingFromM = true
    elseif (throttleValue >= -0.1 and throttleValue <= 0.9) or throttleValue >= 3.9 then
        -- Reset only when at neutral "0" position OR in + or ++ positions
        -- Do NOT reset when in brake positions (< -0.1)
        comingFromM = false
    end

    -- Detect tapping behavior when cruise control is active
    if cruiseControlActive and cruiseTargetSpeed > 0 then
        -- Detect entering M position (to increase speed)
        if throttleValue > 2.5 and lastThrottleValue <= 2.5 then
            tappingUp = true
            tappingDown = false
            tappingTimer = 0
        end

        -- Detect entering - position (to decrease speed)
        if throttleValue > 0.9 and throttleValue <= 1.5 and lastThrottleValue > 1.5 then
            tappingDown = true
            tappingUp = false
            tappingTimer = 0
        end

        -- Track tapping duration
        if tappingUp or tappingDown then
            tappingTimer = tappingTimer + dt

            -- If lever returns to cruise position (●) within 1 second, adjust the speed
            if tappingTimer < 1.0 and throttleValue >= 1.9 and throttleValue <= 2.1 then
                if tappingUp then
                    cruiseTargetSpeed = math.min(cruiseTargetSpeed + 2.0, 140.0)
                    -- SysCall("ScenarioManager:ShowAlertMessageExt",
                    --     "Cruise speed increased to: " .. math.floor(cruiseTargetSpeed + 0.5) .. " km/h", 1, 0)
                    tappingUp = false
                elseif tappingDown then
                    cruiseTargetSpeed = math.max(cruiseTargetSpeed - 2.0, 0)
                    -- SysCall("ScenarioManager:ShowAlertMessageExt",
                    --     "Cruise speed decreased to: " .. math.floor(cruiseTargetSpeed + 0.5) .. " km/h", 1, 0)
                    tappingDown = false
                end
            end

            -- If tapping takes too long (>1 second), cancel it and let regular function apply
            if tappingTimer >= 1.0 then
                tappingUp = false
                tappingDown = false
            end
        end
    else
        tappingUp = false
        tappingDown = false
    end

    -- Handle throttle positions
    if throttleValue > 4.9 then -- Position "++"
        cruiseControlActive = false
        cruiseTargetSpeed = 0
        cruiseIntegralError = 0

        -- Reset held values when in ++ (full power available again)
        heldThrottlePlus = 0.864
        heldThrottleM = 0.682

        if brakeStrength <= 0.001 then
            if howMuchThrottle < 1.0 then
                targetThrottle = math.min(1.0, howMuchThrottle + 0.25 * dt)
            end
        end
        targetBrakeStrength = 0
        previousPos = 5
    elseif throttleValue > 3.9 then -- Position "+"
        cruiseControlActive = false
        cruiseTargetSpeed = 0
        cruiseIntegralError = 0

        -- If coming from ++ and haven't reached 950A yet, capture and hold current value
        if previousPos == 5 and howMuchThrottle < 0.864 then
            heldThrottlePlus = howMuchThrottle
        end

        -- Reset M held value when in + (going forward allows full M power)
        heldThrottleM = 0.682

        if brakeStrength <= 0.001 then
            if howMuchThrottle < heldThrottlePlus then
                targetThrottle = math.min(heldThrottlePlus, howMuchThrottle + 0.16 * dt)
            end
        end
        targetBrakeStrength = 0
        previousPos = 4
    elseif throttleValue > 2.5 then -- Position "M"
        -- Only deactivate cruise control if NOT tapping or if tapping timeout exceeded
        if not tappingUp or tappingTimer >= 1.0 then
            cruiseControlActive = false
            cruiseTargetSpeed = 0
            cruiseIntegralError = 0
        end

        -- If coming from + and haven't reached 750A yet, capture and hold current value
        if previousPos == 4 and howMuchThrottle < 0.682 then
            heldThrottleM = howMuchThrottle
        end

        -- Only apply throttle if cruise control is not active
        if not cruiseControlActive then
            if brakeStrength <= 0.001 then
                if howMuchThrottle < heldThrottleM then
                    targetThrottle = math.min(heldThrottleM, howMuchThrottle + 0.07 * dt)
                end
            end
        end
        targetBrakeStrength = 0
        previousPos = 3
    elseif throttleValue > 1.5 and throttleValue < 2.5 then -- Position "●"
        -- Activate cruise control when coming from any power position (M, +, ++)
        if not cruiseControlActive and (previousPos == 3 or previousPos == 4 or previousPos == 5) then
            cruiseControlActive = true
            cruiseIntegralError = 0
            cruiseLastError = 0
            
            -- Calculate speed offset based on current amperage (displayedAmmeterSoll)
            -- Base offsets (at speeds below 100 km/h):
            -- 1100A+ → 14 km/h
            -- 950A → 10 km/h
            -- 750A → 8 km/h
            -- 0A → 0 km/h
            -- 
            -- At 140 km/h, offsets are reduced:
            -- 1100A+ → 7 km/h
            -- 950A → 5 km/h
            -- 750A → 3 km/h
            -- Linear interpolation between 100-140 km/h
            
            local baseSpeedOffset = 0
            local highSpeedOffset = 0
            local currentAmps = displayedAmmeterSoll
            
            -- Calculate base offset (for speeds < 100 km/h) and high-speed offset (at 140 km/h)
            if currentAmps >= 1100 then
                baseSpeedOffset = 14
                highSpeedOffset = 7
            elseif currentAmps >= 950 then
                -- Linear between 1100A and 950A
                local ratio = (currentAmps - 950) / (1100 - 950)
                baseSpeedOffset = 10 + ratio * (14 - 10)
                highSpeedOffset = 5 + ratio * (7 - 5)
            elseif currentAmps >= 750 then
                -- Linear between 950A and 750A
                local ratio = (currentAmps - 750) / (950 - 750)
                baseSpeedOffset = 8 + ratio * (10 - 8)
                highSpeedOffset = 3 + ratio * (5 - 3)
            elseif currentAmps > 0 then
                -- Linear between 750A and 0A
                local ratio = currentAmps / 750
                baseSpeedOffset = ratio * 8
                highSpeedOffset = ratio * 3
            else
                baseSpeedOffset = 0
                highSpeedOffset = 0
            end
            
            -- Apply speed-based scaling from 100 km/h to 140 km/h
            local speedOffset = baseSpeedOffset
            if currentSpeedKPH >= 140 then
                speedOffset = highSpeedOffset
            elseif currentSpeedKPH >= 100 then
                -- Linear interpolation between 100 km/h and 140 km/h
                local speedRatio = (currentSpeedKPH - 100) / (140 - 100)
                speedOffset = baseSpeedOffset + speedRatio * (highSpeedOffset - baseSpeedOffset)
            end
            -- else: use baseSpeedOffset (for speeds < 100 km/h)
            
            -- Set cruise target = current speed + calculated offset (max 140 km/h)
            cruiseTargetSpeed = math.min(currentSpeedKPH + speedOffset, 140)
            
            -- Initialize filtered gradient to current gradient (prevents startup transient)
            local currentGradient = Call("*:GetGradient") or 0
            filteredGradient = math.abs(currentGradient)
            
            previousSpeed = currentSpeedKPH
            -- SysCall("ScenarioManager:ShowAlertMessageExt", 
            --     "Cruise set to: " .. math.floor(cruiseTargetSpeed + 0.5) .. " km/h", 1, 0)
        end

        if cruiseControlActive then
            if cruiseTargetSpeed > 0 then
                -- Active cruise control - maintain target speed
                local speedError = cruiseTargetSpeed - currentSpeedKPH

                -- Speed scalar: 1.0 at 70 km/h → 2.0 at 140 km/h (linear)
                -- All gains, boosts and damping scale with this so the controller
                -- stays aggressive enough as aerodynamic drag and rolling resistance rise.
                local speedScalar
                if currentSpeedKPH >= 140 then
                    speedScalar = 2.0
                elseif currentSpeedKPH >= 70 then
                    speedScalar = 1.0 + (currentSpeedKPH - 70) / (140 - 70)
                else
                    speedScalar = 1.0
                end

                -- Get gradient and filter it to prevent sudden changes
                local actualGradient = Call("*:GetGradient") or 0
                local actualGradientAbs = math.abs(actualGradient)
                
                -- Exponential filter: smoothly approach actual gradient over ~3 seconds
                -- This prevents oscillations from sudden gradient changes
                local filterSpeed = 0.4  -- How fast to track gradient changes (0.4 = ~2.5 sec to reach 90%)
                filteredGradient = filteredGradient + ((actualGradientAbs - filteredGradient) * filterSpeed * dt)

                -- Proportional gain scales with speed: 0.095 at 70 km/h → 0.19 at 140 km/h
                -- Same km/h error requires far more throttle at high speed due to drag
                local proportionalGain = 0.095 * speedScalar
                local desiredThrottle = speedError * proportionalGain

                -- Boost thresholds drop at high speed (train responds more sluggishly,
                -- so trigger earlier) and boost amounts scale up with speedScalar
                local boostThresholdHigh = 4.0 - (speedScalar - 1.0) * 1.0   -- 4.0 → 3.0
                local boostThresholdLow  = 2.5 - (speedScalar - 1.0) * 0.5   -- 2.5 → 2.0
                if speedError > boostThresholdHigh then
                    desiredThrottle = desiredThrottle + 0.15 * speedScalar  -- 0.15 → 0.30
                elseif speedError > boostThresholdLow then
                    desiredThrottle = desiredThrottle + 0.08 * speedScalar  -- 0.08 → 0.16
                end

                -- Gradient compensation: Use FILTERED gradient for smooth response
                -- Base compensation and speed multiplier both scale with speedScalar
                if filteredGradient > 0.1 then
                    -- Base compensation scales with gradient and speedScalar:
                    -- 0.10 at 70 km/h → 0.20 at 140 km/h
                    local baseCompensation = filteredGradient * 0.10 * speedScalar
                    
                    -- Speed multiplier: higher speeds need more power
                    -- 40 km/h: 1.0x, 80 km/h: 1.5x, 140 km/h: 2.25x
                    local speedMultiplier = 1.0 + (currentSpeedKPH - 40) / 80
                    speedMultiplier = math.max(speedMultiplier, 1.0)
                    
                    local gradientCompensation = baseCompensation * speedMultiplier
                    
                    -- Gradual ramp: 0% at -1 km/h above target, 100% at +1 km/h below target
                    -- This prevents sudden on/off behavior when entering/exiting gradients
                    local rampFactor = math.max(0, math.min(1.0, 1.0 + speedError))
                    
                    desiredThrottle = desiredThrottle + (gradientCompensation * rampFactor)
                end

                -- Derivative / damping scales with speed: 0.5 at 70 km/h → 1.0 at 140 km/h
                -- Damping only activates when AT or ABOVE the target (speedError <= 0) to
                -- suppress overshoot. While still below target (speedError > 0) it must
                -- not fight the throttle or the train stalls short of the setpoint.
                -- 0 km/h over target:  0% damping
                -- 1 km/h over target: 50% damping
                -- 2+ km/h over target: 100% damping
                local dampingGain = 0.5 * speedScalar
                local dampingRamp = math.max(0.0, math.min(1.0, -speedError / 2.0))
                local dampingAdjustment = speedChangeRate * dampingGain * dampingRamp

                desiredThrottle = desiredThrottle + dampingAdjustment

                -- Speed-dependent max throttle: 0.682 at 70 km/h → 1.0 at 140 km/h
                local maxThrottle = 0.682 + (speedScalar - 1.0) * (1.0 - 0.682)
                maxThrottle = math.min(maxThrottle, 1.0)

                -- High-speed sustain floor (130–140 km/h)
                -- At these speeds aerodynamic drag is high enough that near-full throttle
                -- is needed just to keep accelerating. The proportional term alone produces
                -- far too little output once the speed error shrinks to 1-3 km/h.
                -- This floor linearly builds from 0% of maxThrottle at 130 km/h to
                -- 95% of maxThrottle at 140 km/h, and ramps to zero in the final 1 km/h
                -- so it doesn't cause overshoot past the target.
                if currentSpeedKPH >= 130 and speedError > 0 then
                    local sustainRatio = (currentSpeedKPH - 130) / (140 - 130)  -- 0→1 over 130–140 km/h
                    local sustainFloor = sustainRatio * maxThrottle * 0.95
                    local approachRamp = math.min(1.0, speedError)  -- full floor until 1 km/h from target
                    desiredThrottle = math.max(desiredThrottle, sustainFloor * approachRamp)
                end

                -- Clamp to valid range
                desiredThrottle = math.max(math.min(desiredThrottle, maxThrottle), 0.0)

                -- Throttle smoothing also scales: faster reaction needed at high speed
                -- Power increase:  5.0 at 70 km/h → 7.0 at 140 km/h
                -- Power reduction: 8.0 at 70 km/h → 11.0 at 140 km/h
                local throttleDiff = desiredThrottle - targetThrottle
                local smoothingFactor
                if throttleDiff < 0 then
                    smoothingFactor = 8.0 + (speedScalar - 1.0) * 3.0   -- 8.0 → 11.0
                else
                    smoothingFactor = 5.0 + (speedScalar - 1.0) * 2.0   -- 5.0 → 7.0
                end

                targetThrottle = targetThrottle + (throttleDiff * smoothingFactor * dt)

                -- Final clamp
                targetThrottle = math.max(math.min(targetThrottle, maxThrottle), 0.0)
            end -- End of cruiseTargetSpeed check
        end

        targetBrakeStrength = 0
        previousPos = 2
    elseif throttleValue > 0.9 then -- Position "-"
        -- Only deactivate cruise control if NOT tapping or if tapping timeout exceeded
        if not tappingDown or tappingTimer >= 1.0 then
            cruiseControlActive = false
            cruiseTargetSpeed = 0
            cruiseIntegralError = 0
        end

        -- Only apply throttle reduction if cruise control is not active
        if not cruiseControlActive then
            targetThrottle = math.max(howMuchThrottle - 0.1 * dt, 0)
        end

        targetBrakeStrength = 0
        previousPos = 1
    elseif throttleValue > -0.1 then -- Position "0"
        cruiseControlActive = false
        cruiseTargetSpeed = 0
        cruiseIntegralError = 0

        -- Reset held throttle values when returning to neutral
        heldThrottlePlus = 0.864
        heldThrottleM = 0.682

        -- Immediate power cutoff when returning to neutral (like Schnellbremse)
        howMuchThrottle = 0
        targetThrottle = 0
        brakeStrength = 0
        targetBrakeStrength = 0
        SetControlValue("Regulator", 0)
        SetControlValue("DynamicBrake", 0)

        previousPos = 0
    elseif throttleValue > -1.1 then -- Brake position "-"
        cruiseControlActive = false
        cruiseTargetSpeed = 0
        cruiseIntegralError = 0

        targetThrottle = 0

        if howMuchThrottle <= 0.001 then
            targetBrakeStrength = 0
        end
        previousPos = -1
    elseif throttleValue > -2.1 then -- Brake position "●"
        cruiseControlActive = false
        cruiseTargetSpeed = 0
        cruiseIntegralError = 0

        targetThrottle = 0
        targetBrakeStrength = brakeStrength
        previousPos = -2
    elseif throttleValue > -3.1 then -- Brake position "+"
        cruiseControlActive = false
        cruiseTargetSpeed = 0
        cruiseIntegralError = 0

        targetThrottle = 0
        if howMuchThrottle <= 0.001 then
            if brakeStrength < 0.85 then
                targetBrakeStrength = 0.85
            else
                targetBrakeStrength = 1.0
            end
        end
        previousPos = -3
    end

    if previousPos == 1 then
        howMuchThrottle = targetThrottle
    else
        howMuchThrottle = SmoothMove(dt, howMuchThrottle, targetThrottle, (targetThrottle > howMuchThrottle) and
            (previousPos == 5 and 0.25 or previousPos == 4 and 0.16 or previousPos == 3 and 0.1 or 0.5) or 0.5)
    end

    if previousPos ~= -2 then
        if targetBrakeStrength == 0.85 and brakeStrength < 0.85 then
            brakeStrength = SmoothMove(dt, brakeStrength, targetBrakeStrength, 0.15)
        elseif targetBrakeStrength == 1.0 and brakeStrength >= 0.85 then
            brakeStrength = SmoothMove(dt, brakeStrength, targetBrakeStrength, 0.05)
        else
            brakeStrength = SmoothMove(dt, brakeStrength, targetBrakeStrength, 0.15)
        end
    end

    lastThrottleValue = throttleValue

    howMuchThrottle = math.max(math.min(howMuchThrottle, 1), 0)
    brakeStrength = math.max(math.min(brakeStrength, 1.0), 0)
    
    -- FAHRSPERRE: Block throttle power output (lever stays in position, but no power delivered)
    if fahrsperreBlocking then
        howMuchThrottle = 0
        targetThrottle = 0
    end

    -- NEW: Cut off dynamic brake when VirtualBrake is in emergency position (>= 1.1)
    local virtualBrakeValue = GetControlValue("VirtualBrake")
    if virtualBrakeValue and virtualBrakeValue >= 1.1 then
        brakeStrength = 0
        targetBrakeStrength = 0
    end

    -- UPDATED: Calculate ammeter display values with smooth interpolation (no discrete jumps)
    local targetAmmeterSoll = 0
    if howMuchThrottle > 0 then
        -- Smooth interpolation between throttle ranges
        if targetThrottle >= 1.0 then
            targetAmmeterSoll = 1100 -- Fahren "++", capped
        elseif targetThrottle >= 0.864 then
            -- Interpolate between 950A (at 0.864) and 1100A (at 1.0)
            local rangeProgress = (targetThrottle - 0.864) / (1.0 - 0.864)
            targetAmmeterSoll = 950 + (1100 - 950) * rangeProgress
        elseif targetThrottle >= 0.682 then
            -- Interpolate between 750A (at 0.682) and 950A (at 0.864)
            local rangeProgress = (targetThrottle - 0.682) / (0.864 - 0.682)
            targetAmmeterSoll = 750 + (950 - 750) * rangeProgress
        else
            -- Interpolate between 0A (at 0.0) and 750A (at 0.682)
            targetAmmeterSoll = targetThrottle * (750 / 0.682)
        end
    elseif brakeStrength > 0 then
        -- Bei Geschwindigkeiten unter 4 km/h: keine Bremsstrom-Anzeige
        if currentSpeedKPH < 4.0 then
            targetAmmeterSoll = 0
        else
            -- FIX: Soll should directly follow actual brake current for perfect synchronization
            -- This prevents Soll from moving independently and ensures it stays synchronized with Ist
            local actualBrakeCurrent = math.abs(GetControlValue("Ammeter")) or 0
            targetAmmeterSoll = actualBrakeCurrent
        end
    end

    local actualAmperage = math.abs(GetControlValue("Ammeter"))
    local currentAmmeterSoll = GetControlValue("AmmeterDisplaySoll") or 0
    local ammeterDelta = targetAmmeterSoll - currentAmmeterSoll

    -- UPDATED: Rate limits per official manual
    local maxRatePerSecond
    
    -- Special case: Fast drop to zero when THROTTLE is released (not brake)
    -- Only apply if we're dropping from above brake max (750A), meaning we were in throttle + or ++
    if targetAmmeterSoll == 0 and ammeterDelta < 0 and brakeStrength == 0 and currentAmmeterSoll > 760 then
        maxRatePerSecond = 5500  -- Drop from max (1100A) to 0 in ~0.2 seconds
    elseif ammeterDelta > 0 then
        if previousPos == 5 then
            maxRatePerSecond = 300 -- Fahren "++": 300 A/sec
        elseif previousPos == 4 then
            maxRatePerSecond = 200 -- Fahren "+": 200 A/sec
        elseif previousPos == 3 then
            maxRatePerSecond = 100 -- Fahren "M": 100 A/sec
        else
            maxRatePerSecond = 250
        end
    else
        if previousPos == 1 then
            maxRatePerSecond = 200
        elseif previousPos == 0 then
            maxRatePerSecond = 800
        elseif previousPos == 2 then
            maxRatePerSecond = 180
        else
            maxRatePerSecond = 200
        end
    end

    -- NEW: Continuous eased velocity system
    local newAmmeterSoll
    
    -- Get easing factor based on distance to target
    local easingFactor = GetEasingFactor(ammeterDelta, maxRatePerSecond * dt)
    
    -- Calculate target velocity (with easing applied)
    local targetVelocity = maxRatePerSecond * easingFactor
    if ammeterDelta < 0 then
        targetVelocity = -targetVelocity
    end
    
    -- Smoothly interpolate current velocity toward target velocity
    -- This creates smooth acceleration/deceleration
    local velocityLerpFactor = math.min(1.0, dt * 8.0)  -- Adjust velocity quickly but smoothly
    ammeterCurrentVelocity = ammeterCurrentVelocity + (targetVelocity - ammeterCurrentVelocity) * velocityLerpFactor
    
    -- Apply velocity to position
    local change = ammeterCurrentVelocity * dt
    newAmmeterSoll = currentAmmeterSoll + change
    
    -- Clamp to target if we would overshoot
    if ammeterDelta > 0 and newAmmeterSoll > targetAmmeterSoll then
        newAmmeterSoll = targetAmmeterSoll
        ammeterCurrentVelocity = 0  -- Stop when reached
    elseif ammeterDelta < 0 and newAmmeterSoll < targetAmmeterSoll then
        newAmmeterSoll = targetAmmeterSoll
        ammeterCurrentVelocity = 0  -- Stop when reached
    end
    
    -- Handle very small differences (snap to target)
    if math.abs(ammeterDelta) < 0.5 then
        newAmmeterSoll = targetAmmeterSoll
        ammeterCurrentVelocity = 0
    end

    displayedAmmeterSoll = newAmmeterSoll

    -- Smooth interpolation for AmmeterDisplayIst
    local istSmoothFactor = 5.0
    displayedAmmeterIst = displayedAmmeterIst + (actualAmperage - displayedAmmeterIst) *
                              math.min(1.0, dt * istSmoothFactor)

    -- Add subtle physical inertia effect
    local needleChange = actualAmperage - displayedAmmeterIst
    if math.abs(needleChange) > 50 then
        displayedAmmeterIst = displayedAmmeterIst + needleChange * 0.05 * math.min(1.0, dt * 3)
    end

    -- ZTB-based dynamic brake scaling (compensates for 300% artificial increase)
    -- Determine brake scale factor and ammeter multiplier based on unit count
    local brakeScaleFactor = 1.0
    local ammeterMultiplier = 1.0
    
    if G_ZTB_UnitCount == 1 then
        brakeScaleFactor = 0.33  -- Limit to 1/3 power for single unit
        ammeterMultiplier = 3.0   -- Triple the display to show real amperage
    elseif G_ZTB_UnitCount == 2 then
        brakeScaleFactor = 0.67  -- Limit to 2/3 power for double unit
        ammeterMultiplier = 1.5   -- 1.5 the display
    else
        brakeScaleFactor = 1.0   -- Full power for triple unit
        ammeterMultiplier = 1.0   -- Normal display
    end
    
    -- Apply brake scaling
    local scaledBrakeStrength = brakeStrength * brakeScaleFactor
    
    -- Apply ammeter multiplier ONLY when braking (not when accelerating/regulating)
    local scaledDisplayedAmmeterSoll = displayedAmmeterSoll
    local scaledDisplayedAmmeterIst = displayedAmmeterIst
    
    if brakeStrength > 0 then
        -- Only scale ammeter displays during dynamic braking
        scaledDisplayedAmmeterSoll = displayedAmmeterSoll * ammeterMultiplier
        scaledDisplayedAmmeterIst = displayedAmmeterIst * ammeterMultiplier
    end

    -- Set the regulator control and dynamic brake
    SetControlValue("Regulator", howMuchThrottle)
    SetControlValue("DynamicBrake", scaledBrakeStrength)

    -- Set the ammeter display values
    -- When braking: Soll behaves EXACTLY like Ist (both show actual amperage)
    -- When not braking: Soll shows target, Ist shows actual
    if brakeStrength > 0 then
        -- During dynamic braking: both Soll and Ist display the actual amperage
        SetControlValue("AmmeterDisplaySoll", scaledDisplayedAmmeterIst)
        SetControlValue("AmmeterDisplayIst", scaledDisplayedAmmeterIst)
    else
        -- During acceleration/regulation: Soll shows target, Ist shows actual
        SetControlValue("AmmeterDisplaySoll", scaledDisplayedAmmeterSoll)
        SetControlValue("AmmeterDisplayIst", scaledDisplayedAmmeterIst)
    end

    -- Store current speed for next frame comparison
    previousSpeed = currentSpeedKPH
end

local speiseleitungsdruck = 9.4
local hauptluftdruck = 4.923795
local bremszylinderdruck = 0.0
local trainbrake_pressure = 0.0
-- Needle display values for smooth animation
local needle_HLL = 4.923795
local needle_BC = 0.0
local needle_SL = 9.4
local C_COMPRESSOR_TURN_ON_PRESSURE = 8.0
local C_COMPRESSOR_TURN_OFF_PRESSURE = 10.0
local C_COMPRESSOR_SPEED_PER_WAGON_AND_COMPRESSOR = 0.065  -- Halved for more realistic fill rate
local C_BREMSZYLINDER_MAX_PRESSURE = 3.7
local C_HLL_EVACUATION_SPEED = 0.4  -- 2.5x slower than before
local C_HLL_FILL_SPEED = 0.12  -- 2.5x slower than before
local C_HLL_SL_FILL_FACTOR = 0.1
local C_BREMSZYLINDER_FILL_SPEED = 0.3  -- 2x slower for realistic brake response

G_CompressorRunning = false  -- Current compressor state (global for TV system access)
G_Compressor_Manual = false  -- Manual compressor mode (button pressed)


function UpdateMagnetschienenbremse()
    local currentSpeedMPS = Call("GetSpeed") or 0
    local currentSpeedKPH = currentSpeedMPS * 3.6
    local virtualBrake = GetControlValue("VirtualBrake") or 0
    
    local wasActive = G_MagnetbrakeActive
    
    -- Automatic activation: Speed > 30 km/h AND VirtualBrake >= 1.1 (Schnellbremsung)
    local automaticCondition = (currentSpeedKPH > 30) and (virtualBrake >= 1.1)
    
    -- Manual activation: Button pressed AND speed > 30 km/h
    local manualCondition = G_MagnetbrakeButtonPressed and (currentSpeedKPH > 30)
    
    -- Deactivation conditions
    if G_MagnetbrakeActive then
        -- Deactivate if speed < 5 km/h
        if currentSpeedKPH < 5 then
            G_MagnetbrakeActive = false
        -- For automatic mode: also deactivate if brake lever released from emergency position
        elseif not G_MagnetbrakeButtonPressed and virtualBrake < 1.1 then
            G_MagnetbrakeActive = false
        end
    end
    
    -- Activation
    if (automaticCondition or manualCondition) and not G_MagnetbrakeActive then
        G_MagnetbrakeActive = true
    end
    
    -- Send consist messages when state changes
    if G_MagnetbrakeActive and not wasActive then
        -- Brake activated - set target for animation
        G_MGBrake_Target = 4.16666666667
        SendConsistMessage(CM_MAGNETBREMSE_ON, 0, 0)
        SendConsistMessage(CM_MAGNETBREMSE_ON, 0, 1)
    elseif not G_MagnetbrakeActive and wasActive then
        -- Brake deactivated - set target for animation
        G_MGBrake_Target = 0
        SendConsistMessage(CM_MAGNETBREMSE_OFF, 0, 0)
        SendConsistMessage(CM_MAGNETBREMSE_OFF, 0, 1)
    end
    
    -- Update light
    UpdateMagnetbrakeLicht()
end

function UpdateMGBrakeAnimation(dt)
    local MG_BRAKE_MAX_TIME = 4.16666666667  -- 10/24
    local MG_BRAKE_SPEED = MG_BRAKE_MAX_TIME / 1.0  -- Reaches max in 1 second
    
    if G_MGBrake_Target > G_MGBrake_AnimTime then
        -- Animating forward (activating)
        G_MGBrake_AnimTime = math.min(G_MGBrake_AnimTime + MG_BRAKE_SPEED * dt, G_MGBrake_Target)
        G_MGBrake_Animating = true
    elseif G_MGBrake_Target < G_MGBrake_AnimTime then
        -- Animating backward (deactivating)
        G_MGBrake_AnimTime = math.max(G_MGBrake_AnimTime - MG_BRAKE_SPEED * dt, G_MGBrake_Target)
        G_MGBrake_Animating = true
    else
        G_MGBrake_Animating = false
    end
    
    -- Set the animation time
    Call("*:SetTime", "MG_Bremse", G_MGBrake_AnimTime)
end

function UpdateMagnetbrakeLicht()
    -- Don't update during lamp test (unless > 5 seconds)
    if G_LampTestActive and G_LampTestTimer < 5.0 then
        return
    end
    
    if not G_Steuerstrom then
        -- No Steuerstrom: light off
        SetControlValue("Magnetschienenbremse_LIT", 0)
    elseif G_MagnetbrakeActive then
        -- Active: bright light
        SetControlValue("Magnetschienenbremse_LIT", 2)
    else
        -- Steuerstrom on but not active: dim light
        SetControlValue("Magnetschienenbremse_LIT", 1)
    end
end

function UpdateBremsanzeiger(dt)
    -- Get current HandBrake state (1 = applied, 0 = released)
    local handBrake = GetControlValue("HandBrake") or 0
    
    -- Get current vehicle brake control value
    local vehicleBrake = GetControlValue("TrainBrakeControl") or 0
    local rangierbremse = GetControlValue("VirtualEngineBrakeControl") or 0
    
    -- Bremsanzeiger: affected by BOTH TrainBrakeControl (pneumatic brake) AND VirtualEngineBrakeControl (Rangierbremse), NOT FSB
    if vehicleBrake > 0.05 or rangierbremse > 0.05 then
        -- Brake is applied (TrainBrakeControl > 0 OR Rangierbremse > 0)
        G_Bremsanzeiger_Target = 0.0
    else
        -- Brake is released (both TrainBrakeControl and Rangierbremse = 0)
        G_Bremsanzeiger_Target = 1.0
    end
    
    -- Bremsanzeiger_FSB: ONLY cares about HandBrake/FSB
    if handBrake > 0.5 then
        -- FSB (parking brake) is applied
        G_Bremsanzeiger_FSB_Target = 0.0
    else
        -- FSB is released
        G_Bremsanzeiger_FSB_Target = 1.0
    end
    
    -- Animation speed: 1.2 per second (3x faster - 0 to 1 in ~0.83 seconds)
    local animSpeed = 1.2
    
    -- Smooth animation for Bremsanzeiger with ease-in-ease-out
    local diff = G_Bremsanzeiger_Target - G_Bremsanzeiger_Current
    if math.abs(diff) > 0.001 then
        -- Use ease-out for smoother deceleration
        local step = animSpeed * dt
        if math.abs(diff) < step then
            G_Bremsanzeiger_Current = G_Bremsanzeiger_Target
        else
            -- Ease-out: slower as we approach target
            local easeFactor = math.min(1.0, math.abs(diff) / 0.5)  -- Ease over last 0.5 units
            G_Bremsanzeiger_Current = G_Bremsanzeiger_Current + (diff / math.abs(diff)) * step * easeFactor
        end
    end
    
    -- Smooth animation for Bremsanzeiger_FSB with ease-in-ease-out
    local diff_fsb = G_Bremsanzeiger_FSB_Target - G_Bremsanzeiger_FSB_Current
    if math.abs(diff_fsb) > 0.001 then
        local step = animSpeed * dt
        if math.abs(diff_fsb) < step then
            G_Bremsanzeiger_FSB_Current = G_Bremsanzeiger_FSB_Target
        else
            -- Ease-out: slower as we approach target
            local easeFactor = math.min(1.0, math.abs(diff_fsb) / 0.5)
            G_Bremsanzeiger_FSB_Current = G_Bremsanzeiger_FSB_Current + (diff_fsb / math.abs(diff_fsb)) * step * easeFactor
        end
    end
    
    SetAnimTime("Bremsanzeiger", G_Bremsanzeiger_Current)
    SetAnimTime("Bremsanzeiger_FSB", G_Bremsanzeiger_FSB_Current)
    
    -- Broadcast ONLY TrainBrakeControl status to consist (NOT Rangierbremse, which is local only)
    -- Calculate broadcast target based ONLY on vehicleBrake (pneumatic brake)
    local broadcast_target
    if vehicleBrake > 0.05 then
        broadcast_target = 0.0  -- Pneumatic brake applied
    else
        broadcast_target = 1.0  -- Pneumatic brake released
    end
    
    local message = string.format("%.1f", broadcast_target)
    Call("SendConsistMessage", CM_BREMSANZEIGER_UPDATE, message, 0)
    Call("SendConsistMessage", CM_BREMSANZEIGER_UPDATE, message, 1)
end

function UpdateSchleuderbremse(dt)
    -- Schleuderbremse: Anti-wheelslip brake system
    -- Automatically applies 0.8 BAR when wheelslip detected during acceleration
    -- Automatic activation holds for at least 2 seconds even if wheelslip clears immediately
    -- Driver can also manually activate it by holding button (when rolling, not braking)
    
    local currentSpeed = math.abs(Call("GetSpeed") or 0) * 3.6 -- km/h
    local throttleValue = GetControlValue("VirtualThrottle") or 0
    local brakeControl = GetControlValue("TrainBrakeControl") or 0
    
    -- Check conditions
    local isAccelerating = throttleValue > 0.1 and brakeControl < 0.01 and currentSpeed > 1.0
    local isRolling = currentSpeed > 1.0 and brakeControl < 0.01
    
    -- Reset if driver brakes applied (pneumatic system - no Steuerstrom dependency)
    if brakeControl > 0.01 then
        G_Schleuderbremse_Active = false
        G_Schleuderbremse_AutoTimer = 0.0
        return
    end
    
    -- Manual activation: Button held while rolling (no brakes)
    if G_Schleuderbremse_Manual and isRolling then
        G_Schleuderbremse_Active = true
        return
    end
    
    -- Automatic activation: Wheelslip during acceleration
    -- Restart the 2s timer every time fresh wheelslip is detected
    if isAccelerating and G_WheelSlip == 1 then
        G_Schleuderbremse_Active = true
        G_Schleuderbremse_AutoTimer = 2.0
        return
    end
    
    -- Keep active for minimum 2 seconds after automatic trigger
    if G_Schleuderbremse_AutoTimer > 0 then
        G_Schleuderbremse_AutoTimer = G_Schleuderbremse_AutoTimer - dt
        G_Schleuderbremse_Active = true
        return
    end
    
    -- Otherwise deactivate
    G_Schleuderbremse_Active = false
end

function Bremsrechner(dt)
    -- Compressor logic - requires Hauptschalter to run AND 13-second activation delay to complete
    local compressor_was_running = G_CompressorRunning
    
    -- Check if Hauptschalter is on AND the 13-second activation period has completed
    local hauptschalterReady = G_Hauptschalter and G_HauptschalterActivationTimer >= 13.0
    
    if hauptschalterReady then
        if G_Compressor_Manual then
            -- Manual mode: always run, cap pressure at 10 bar
            G_CompressorRunning = true
            if speiseleitungsdruck < C_COMPRESSOR_TURN_OFF_PRESSURE then
                speiseleitungsdruck = speiseleitungsdruck + C_COMPRESSOR_SPEED_PER_WAGON_AND_COMPRESSOR * dt
            else
                -- Cap at 10 bar in manual mode
                speiseleitungsdruck = C_COMPRESSOR_TURN_OFF_PRESSURE
            end
        else
            -- Automatic mode: turn on at 8.0 bar, turn off at 10.0 bar
            if G_CompressorRunning and speiseleitungsdruck >= C_COMPRESSOR_TURN_OFF_PRESSURE then
                -- Pressure reached 10 bar - turn off compressor
                G_CompressorRunning = false
            elseif speiseleitungsdruck < 8.0 then
                -- Pressure below 8 bar - turn on compressor
                G_CompressorRunning = true
            end
            
            -- If compressor is running, increase pressure
            if G_CompressorRunning then
                speiseleitungsdruck = speiseleitungsdruck + C_COMPRESSOR_SPEED_PER_WAGON_AND_COMPRESSOR * dt
            end
        end
    else
        -- Hauptschalter off, compressor cannot run
        G_CompressorRunning = false
    end
    
    -- Update Traktionsventilation when compressor state changes
    if G_CompressorRunning ~= compressor_was_running then
        if G_CompressorRunning then
            -- Compressor started - turn on TV to phase 1 if off
            if G_TV_TargetValue == 0 then
                G_TV_TargetValue = 1
                G_TV_IsTransitioning = true
                G_TV_TransitionTimer = 0
                G_TV_CurrentValue = 0
            end
            -- Broadcast to all cars
            SendConsistMessage(CM_TRAKTIONSVENTILATION, 1, 0)
            SendConsistMessage(CM_TRAKTIONSVENTILATION, 1, 1)
        else
            -- Compressor stopped - allow TV to turn off if not moving
            local speed = Call("GetSpeed") * 3.6
            if math.abs(speed) < 0.3 and G_TV_TargetValue == 1 then
                G_TV_TargetValue = 0
                G_TV_IsTransitioning = true
                G_TV_TransitionTimer = 0
                -- Broadcast to all cars
                SendConsistMessage(CM_TRAKTIONSVENTILATION, 0, 0)
                SendConsistMessage(CM_TRAKTIONSVENTILATION, 0, 1)
            end
        end
    end

    -- Handle Hauptschalter activation pressure drop
    -- When main switch is turned on, SL pressure drops by 0.8-1.2 bar (simulates initial electrical system load)
    if G_HauptschalterPressureDrop then
        local pressureDrop = 0.8 + (math.random() * 0.4)  -- Random drop between 0.8 and 1.2 bar
        speiseleitungsdruck = math.max(0, speiseleitungsdruck - pressureDrop)
        G_HauptschalterPressureDrop = false  -- Clear flag after applying drop
    end


    local y = GetControlValue("VirtualBrake");

    -- Abschlussstellung (position 0): Isolate and maintain current pressures for diagnostic purposes
    -- During initialization period, force pressures to starting values
    local abschlussstellung_active = false
    
    if y < 0.01 then
        if not G_PressureInitComplete then
            -- During initialization: force pressures to starting values
            G_BrakePressureGoal = 4.923795
            hauptluftdruck = 4.923795
            speiseleitungsdruck = 9.4
            bremszylinderdruck = 0.0
        else
            -- After initialization: Abschlussstellung - freeze current pressures
            abschlussstellung_active = true
            -- Don't adjust any pressures - maintain current state for diagnostics
            -- Continue to end of function to update needle displays
        end
    end
    
    -- Only process brake logic if NOT in Abschlussstellung
    if not abschlussstellung_active then

    -- Handle Füllstellung (FV4a special behavior)
    if G_BrakePressureGoal < -0.5 then
        -- Füllstellung active
        if not G_Fuellstellung_Active then
            -- Just entered Füllstellung - start with 1 second delay
            G_Fuellstellung_Active = true
            G_Fuellstellung_Phase = 0  -- Start at Phase 0 (delay)
            G_Fuellstellung_Timer = 0
        end
        
        -- Accumulate total dwell time in Füllstellung
        G_Fuellstellung_Dwell_Timer = G_Fuellstellung_Dwell_Timer + dt
        G_Fuellstellung_Timer = G_Fuellstellung_Timer + dt
        
        if G_Fuellstellung_Phase == 0 then
            -- Phase 0: Initial delay - wait 2 seconds before Füllstellung takes effect
            -- This prevents accidental triggering when briefly passing through Füllstellung
            if G_Fuellstellung_Timer >= 2.0 then
                -- 2 seconds passed, move to Phase 1 (Hochdruckfüllstoss)
                G_Fuellstellung_Phase = 1
                G_Fuellstellung_Timer = 0
            end
            -- No pressure change during Phase 0
        elseif G_Fuellstellung_Phase == 1 then
            -- Phase 1: Hochdruckfüllstoss - Jump to 7.5 bar over ~2 seconds
            local hochdruck_target = 7.5
            if hauptluftdruck < hochdruck_target - 0.1 then
                hauptluftdruck = hauptluftdruck + 3.75 * dt  -- Fill to 7.5 bar in ~2 seconds (7.5/2 = 3.75 bar/sec)
                speiseleitungsdruck = speiseleitungsdruck - 0.3 * dt
            else
                -- Reached 7.5 bar, move to Phase 2
                G_Fuellstellung_Phase = 2
                G_Fuellstellung_Timer = 0
            end
        elseif G_Fuellstellung_Phase == 2 then
            -- Phase 2: Slowly descend from 7.5 to 5.4 bar over 3 seconds
            local settle_target = 5.4
            local settle_duration = 3.0
            if G_Fuellstellung_Timer < settle_duration then
                -- Slow descent: (7.5 - 5.4) = 2.1 bar over 3 seconds = 0.7 bar/sec
                local descent_rate = 0.7
                if hauptluftdruck > settle_target then
                    hauptluftdruck = hauptluftdruck - descent_rate * dt
                end
            else
                -- Settled at 5.4 bar, move to Phase 3
                hauptluftdruck = settle_target
                G_Fuellstellung_Phase = 3
                G_Fuellstellung_Timer = 0
            end
        elseif G_Fuellstellung_Phase == 3 then
            -- Phase 3: Very slow descent from 5.4 to 5.0 bar over ~3 minutes (Niederdrucküberladung)
            local final_target = 5.0
            local slow_descent_rate = 0.0022
            -- Tick the shared Phase3_Target down (also used by post-Füllstellung logic in Fahrstellung)
            G_Fuellstellung_Phase3_Target = math.max(final_target, G_Fuellstellung_Phase3_Target - slow_descent_rate * dt)
            G_PostFuellstellung_Descent = true
            -- Only push HLL down if it is above the current Phase3 target
            -- (if we braked below, normal brake logic handles it - don't force pressure up)
            if hauptluftdruck > G_Fuellstellung_Phase3_Target + 0.01 then
                hauptluftdruck = hauptluftdruck - slow_descent_rate * dt
            elseif hauptluftdruck >= G_Fuellstellung_Phase3_Target - 0.01 then
                hauptluftdruck = G_Fuellstellung_Phase3_Target
            end
            if G_Fuellstellung_Phase3_Target <= final_target then
                G_PostFuellstellung_Descent = false
            end
        end
    else
        -- Not in Füllstellung - reset state
        if G_Fuellstellung_Active then
            if G_Fuellstellung_Phase == 3 then
                -- Was in Phase 3 slow descent — preserve descent state so Fahrstellung continues it
                -- G_PostFuellstellung_Descent and G_Fuellstellung_Phase3_Target remain as-is
            elseif G_Fuellstellung_Phase == 2 then
                -- Was in Phase 2 (settling 7.5→5.4) — start slow descent from 5.4 when releasing to Fahrstellung
                G_PostFuellstellung_Descent = true
                G_Fuellstellung_Phase3_Target = 5.4
            elseif G_Fuellstellung_Dwell_Timer >= 2.0 then
                if hauptluftdruck < 5.5 then
                    hauptluftdruck = 5.5
                end
                G_PostFuellstellung_Descent = false
            else
                G_PostFuellstellung_Descent = false
            end
        end
        G_Fuellstellung_Active = false
        G_Fuellstellung_Phase = 0
        G_Fuellstellung_Timer = 0
        G_Fuellstellung_Dwell_Timer = 0
    end

    if G_Zwangsbremse then
        G_BrakePressureGoal = 0
    end

    -- Post-Füllstellung: keep Phase3_Target ticking down even when not in Füllstellung
    -- This keeps it synchronized regardless of braking activity.
    -- When in Fahrstellung, also directly drive HLL: slow descent or fast refill from brake.
    if G_PostFuellstellung_Descent and not G_Fuellstellung_Active then
        G_Fuellstellung_Phase3_Target = math.max(5.0, G_Fuellstellung_Phase3_Target - 0.0022 * dt)
        if G_Fuellstellung_Phase3_Target <= 5.0 then
            G_PostFuellstellung_Descent = false
        end
        -- Only touch HLL while in Fahrstellung and not during overshoot
        if math.abs(G_BrakePressureGoal - 5.0) < 0.01 and not G_Fahrstellung_Overshoot_Active then
            if hauptluftdruck > G_Fuellstellung_Phase3_Target + 0.01 then
                -- Still above the overcharge target: slow descent (Niederdrucküberladung)
                hauptluftdruck = hauptluftdruck - 0.0022 * dt
            elseif hauptluftdruck < G_Fuellstellung_Phase3_Target - 0.02 then
                -- Below target after releasing from a brake step: fill back quickly
                hauptluftdruck = math.min(hauptluftdruck + 1.5 * dt, G_Fuellstellung_Phase3_Target)
                speiseleitungsdruck = speiseleitungsdruck - C_HLL_SL_FILL_FACTOR * dt
            else
                hauptluftdruck = G_Fuellstellung_Phase3_Target
            end
        end
    end

    -- Handle Fahrstellung overshoot behavior (realistic brake release)
    -- Requires dwelling in Fahrstellung for at least 0.8 seconds so that sweeping
    -- the handle past it on the way to Abschluss does NOT trigger the overshoot.
    if math.abs(G_BrakePressureGoal - 5.0) < 0.1 then
        -- We're in or near Fahrstellung
        if not G_Fahrstellung_Overshoot_Active then
            local pressure_diff = 5.0 - hauptluftdruck
            if pressure_diff > 0.1 and not G_PostFuellstellung_Descent then
                G_Fahrstellung_Dwell_Timer = G_Fahrstellung_Dwell_Timer + dt
                if G_Fahrstellung_Dwell_Timer >= 0.8 then
                    -- Overshoot is proportional to pressure difference, capped at 1.0 BAR
                    local overshoot = math.min(pressure_diff * 0.6, 1.0)
                    -- Ensure minimum overshoot of 0.5 BAR to reach at least 5.5 BAR
                    overshoot = math.max(overshoot, 0.5)
                    hauptluftdruck = 5.0 + overshoot
                    speiseleitungsdruck = speiseleitungsdruck - overshoot * 0.15
                    G_Fahrstellung_Overshoot_Active = true
                    G_Fahrstellung_Dwell_Timer = 0
                end
            else
                G_Fahrstellung_Dwell_Timer = 0
            end
        elseif G_Fahrstellung_Overshoot_Active and hauptluftdruck > 5.05 then
            -- Settling back down to 5.0 from overshoot
            hauptluftdruck = hauptluftdruck - 0.16 * dt
            if hauptluftdruck <= 5.0 then
                hauptluftdruck = 5.0
                G_Fahrstellung_Overshoot_Active = false
            end
        else
            G_Fahrstellung_Overshoot_Active = false
        end
    else
        -- Left Fahrstellung - reset dwell timer and overshoot state
        G_Fahrstellung_Overshoot_Active = false
        G_Fahrstellung_Dwell_Timer = 0
    end
    
    -- Determine effective HLL target: in Fahrstellung with active post-Füllstellung descent,
    -- target the Phase3 overcharge value rather than flat 5.0
    local effective_goal = G_BrakePressureGoal
    if G_PostFuellstellung_Descent and math.abs(G_BrakePressureGoal - 5.0) < 0.1 then
        effective_goal = G_Fuellstellung_Phase3_Target
    end

    if effective_goal > -0.1 and not G_Fahrstellung_Overshoot_Active then
        if (hauptluftdruck > effective_goal + 0.02) or (hauptluftdruck < effective_goal - 0.02) then
            if hauptluftdruck > effective_goal then
                -- Schnellbremsung: evacuate HLL much faster when target is near 0
                local evacuation_speed = C_HLL_EVACUATION_SPEED
                if G_BrakePressureGoal < 0.5 then
                    evacuation_speed = C_HLL_EVACUATION_SPEED * 15.0  -- 15x faster for emergency braking
                end
                hauptluftdruck = hauptluftdruck - evacuation_speed * dt
            elseif hauptluftdruck < effective_goal then
                -- Faster refill when recovering from low pressure (e.g. emergency to service brake transition)
                local fill_speed = C_HLL_FILL_SPEED * 0.5
                -- Fast recovery from emergency brake: stay at high speed until close to target
                -- This ensures quick recovery when moving away from 0 BAR after Schnellbremse
                if hauptluftdruck < 2.0 and G_BrakePressureGoal > 2.5 then
                    -- Recovering from emergency brake (HLL very low, target is service brake range)
                    fill_speed = C_HLL_FILL_SPEED * 25.0  -- Much faster recovery
                elseif hauptluftdruck < G_BrakePressureGoal - 1.0 and G_BrakePressureGoal > 2.0 then
                    -- Still more than 1 bar below target in service brake range
                    fill_speed = C_HLL_FILL_SPEED * 15.0  -- Keep it fast
                end
                hauptluftdruck = hauptluftdruck + fill_speed * dt
                speiseleitungsdruck = speiseleitungsdruck - C_HLL_SL_FILL_FACTOR * dt
            end
        end
    end

    local bremszylinder_target = 0.0
    if hauptluftdruck >= 4.7 then
        bremszylinder_target = 0.0
    elseif hauptluftdruck >= 2.9 then
        -- Linear zwischen 4.7 bar (0.5 BC) und 2.9 bar (3.1 BC)
        bremszylinder_target = 0.5 + (4.7 - hauptluftdruck) / 1.8 * 2.6
    elseif hauptluftdruck > 0.0 then
        -- Linear zwischen 2.9 bar (3.1 BC) und 0.0 bar (3.2 BC)
        bremszylinder_target = 3.1 + (2.9 - hauptluftdruck) / 2.9 * 0.1
    else
        bremszylinder_target = 3.2
    end


    trainbrake_target = bremszylinder_target;

    -- Use 3x faster brake cylinder fill during Schnellbremse (emergency brake)
    local bc_fill_speed = C_BREMSZYLINDER_FILL_SPEED
    if G_BrakePressureGoal < 0.5 then
        bc_fill_speed = C_BREMSZYLINDER_FILL_SPEED * 3.0  -- 3x faster during emergency brake
    end

    if trainbrake_target > trainbrake_pressure then
        trainbrake_pressure = math.min(trainbrake_pressure + bc_fill_speed * dt, trainbrake_target)
    elseif trainbrake_target < trainbrake_pressure then
        trainbrake_pressure = math.max(trainbrake_pressure - bc_fill_speed * 0.5 * dt, trainbrake_target)
    end

    -- Store automatic brake target before adding Rangierbremse
    local bremszylinder_target_auto = bremszylinder_target
    local rangierbremse_target = G_Rangierbremse * 3.5
    
    bremszylinder_target = math.max(bremszylinder_target, rangierbremse_target) -- get higher of two values (rangierbremse, autom. bremse)

    -- Check if Rangierbremse is dominant (direct brake with no delay)
    if rangierbremse_target > bremszylinder_target_auto then
        -- Rangierbremse is active - apply/release instantly with no delay
        bremszylinderdruck = rangierbremse_target
    else
        -- Automatic brake is dominant - use normal pneumatic simulation with delay
        -- Use same 3x faster speed during Schnellbremse (bc_fill_speed already calculated above)
        if bremszylinder_target > bremszylinderdruck then
            bremszylinderdruck = math.min(bremszylinderdruck + bc_fill_speed * dt, bremszylinder_target)
        elseif bremszylinder_target < bremszylinderdruck then
            bremszylinderdruck = math.max(bremszylinderdruck - bc_fill_speed * 0.5 * dt, bremszylinder_target)
        end
    end

    SetControlValue("TrainBrakeControl", trainbrake_pressure / 3.8)
    
    -- Calculate vehicle brake value with reduced Rangierbremse effect
    -- Rangierbremse effect is 40% lower (60% of original) on TrainBrakeControl, but BCPressure shows full pressure
    local vehicleBrakeValue
    if rangierbremse_target > bremszylinder_target_auto and bremszylinder_target > 0.01 then
        -- Rangierbremse is dominant - scale down the actual pressure proportionally
        local reduced_target = bremszylinder_target_auto + (rangierbremse_target - bremszylinder_target_auto) * 0.6
        local scale_factor = reduced_target / bremszylinder_target
        vehicleBrakeValue = (bremszylinderdruck * scale_factor) / 3.8
    else
        -- Automatic brake is dominant or no brake - use normal calculation
        vehicleBrakeValue = bremszylinderdruck / 3.8
    end
    
    if G_MagnetbrakeActive then
        -- MG brake active: add 33% brake force
        vehicleBrakeValue = vehicleBrakeValue + 0.33
    end
    
    -- Schleuderbremse: Add 0.2 brake force when active
    if G_Schleuderbremse_Active then
        vehicleBrakeValue = vehicleBrakeValue + 0.2
    end
    
    -- Cap at maximum value
    vehicleBrakeValue = math.min(vehicleBrakeValue, 0.85)
    
    SetControlValue("EngineBrakeControl", vehicleBrakeValue)
    
    else
        -- Abschlussstellung: maintain current state, no pressure adjustments
        -- Keep TrainBrakeControl and EngineBrakeControl at current values
        SetControlValue("TrainBrakeControl", GetControlValue("TrainBrakeControl"))
        
        -- Calculate current vehicle brake value based on current BC pressure
        local vehicleBrakeValue = bremszylinderdruck / 3.8
        if G_MagnetbrakeActive then
            vehicleBrakeValue = vehicleBrakeValue + 0.33
        end
        if G_Schleuderbremse_Active then
            vehicleBrakeValue = vehicleBrakeValue + 0.2
        end
        vehicleBrakeValue = math.min(vehicleBrakeValue, 0.85)
        SetControlValue("EngineBrakeControl", vehicleBrakeValue)
    end  -- End of: if not abschlussstellung_active then
    
    -- Smooth needle animations with ease-out
    -- Special case: Schnellbremsung (emergency braking) - needle must respond quickly when dropping to 0
    if G_BrakePressureGoal < 0.5 then
        -- Schnellbremsung detected - use fast linear movement for HLL needle
        needle_HLL = SmoothMove(dt, needle_HLL, hauptluftdruck, 20.0)
    else
        -- Normal operation - use slower smoothing to reduce trembling (1.5 instead of 5.0)
        needle_HLL = SmoothMoveEaseOut(dt, needle_HLL, hauptluftdruck, 1.5)
    end
    
    -- Schleuderbremse: Add 0.8 BAR to BC pressure display only (not actual brake force)
    local bc_display_value = bremszylinderdruck
    if G_Schleuderbremse_Active then
        bc_display_value = bc_display_value + 0.8
    end
    
    needle_BC = SmoothMoveEaseOut(dt, needle_BC, bc_display_value, 5.0)
    needle_SL = SmoothMoveEaseOut(dt, needle_SL, speiseleitungsdruck, 5.0)
    
    SetControlValue("HLLPressure", needle_HLL)
    SetControlValue("BCPressure", needle_BC)
    SetControlValue("SLPressure", needle_SL)
    
    -- Only set HandBrake for engine cars (Fst=1) after Fst check is complete
    if G_FstCheckComplete then
        local fstVal = GetControlValue("Fst") or 0
        if fstVal >= 0.5 then
            -- This is an engine car (Fst=1) - set HandBrake based on G_SAPBEngaged
            SetControlValue("HandBrake", lambda(G_SAPBEngaged, 1, 0))
        else
            -- This is a cab control car (Fst=0) - always keep HandBrake released
            SetControlValue("HandBrake", 0)
        end
    end
end

RASTE_TIMER = 0.2
THROTTLE_MOVE_SPEED = 0.3

local BremsVentilMovement = NotchedLever

function Bremsventil(dt)
    G_Rangierbremse = GetControlValue("VirtualEngineBrakeControl")
    local newValue = GetControlValue("VirtualBrake")
    G_BrakePressureGoal = ZugBremsHebel(newValue)
end

function UpdateConsistLength()
    gStartingLength = Call("*:GetConsistLength")
    if gStartingLength ~= gStartingLengthPrev then
        gUpdateCouplers = 1
    else
        gUpdateCouplers = 0
    end
    gStartingLengthPrev = gStartingLength
end

function UpdateNotlicht()
    if not G_NotlichtActive then
        Call("*:ActivateNode", "lights_notlicht", 0)
        Call("Notlicht_1:Activate", 0)
        Call("Notlicht_2:Activate", 0)
        Call("Notlicht_3:Activate", 0)
        return
    end

    -- Debug: Check coupling values
    -- SysCall("ScenarioManager:ShowAlertMessageExt",
        -- "Front: " .. G_SomethingCoupledAtFront .. " Rear: " .. G_SomethingCoupledAtRear, 1, 0)

    -- Notlicht active
    if G_SomethingCoupledAtFront == 1 and G_SomethingCoupledAtRear == 1 then
        Call("*:ActivateNode", "lights_notlicht", 0)
        Call("Notlicht_1:Activate", 0)
        Call("Notlicht_2:Activate", 0)
        Call("Notlicht_3:Activate", 0)
    else
        Call("*:ActivateNode", "lights_notlicht", 1)
        Call("Notlicht_1:Activate", 1)
        Call("Notlicht_2:Activate", 1)
        Call("Notlicht_3:Activate", 1)
    end
end

--------------------------------------------------------------------------------
-- Buegelfeuer (Pantograph Arcing) System
-- Simulates electrical arcing between pantograph and overhead wire
-- Only active in winter due to ice and frost conditions
--------------------------------------------------------------------------------
function UpdateBuegelfeuer(dt)
    -- Only simulate Buegelfeuer in winter (Season 3)
    if G_Season ~= 3 then
        if G_BuegelfeuerActive then
            Call("Buegelfeuer:Activate", 0)
            SetControlValue("Buegelfeuer", 0)
            G_BuegelfeuerActive = false
        end
        return
    end
    
    -- Only active when pantograph is raised and Hauptschalter is on
    if not G_PantographRaised or not G_Hauptschalter then
        if G_BuegelfeuerActive then
            Call("Buegelfeuer:Activate", 0)
            SetControlValue("Buegelfeuer", 0)
            G_BuegelfeuerActive = false
        end
        G_BuegelfeuerTimer = 0
        G_BuegelfeuerNextArcTimer = 0
        return
    end
    
    -- Get current speed
    local currentSpeed = Call("*:GetSpeed")
    local speedKPH = math.abs(currentSpeed) * 3.6
    
    -- Only active when moving at least 3 km/h
    if speedKPH < 3.0 then
        if G_BuegelfeuerActive then
            Call("Buegelfeuer:Activate", 0)
            SetControlValue("Buegelfeuer", 0)
            G_BuegelfeuerActive = false
        end
        G_BuegelfeuerTimer = 0
        G_BuegelfeuerNextArcTimer = 0
        return
    end
    
    -- Update active arc
    if G_BuegelfeuerActive then
        G_BuegelfeuerTimer = G_BuegelfeuerTimer + dt
        
        -- Arc duration is 0.1 seconds
        if G_BuegelfeuerTimer >= 0.1 then
            Call("Buegelfeuer:Activate", 0)
            SetControlValue("Buegelfeuer", 0)
            G_BuegelfeuerActive = false
            G_BuegelfeuerTimer = 0
            
            -- If in burst mode, reduce burst count
            if G_BuegelfeuerBurstMode then
                G_BuegelfeuerBurstCount = G_BuegelfeuerBurstCount - 1
                
                if G_BuegelfeuerBurstCount > 0 then
                    -- Set up next arc in burst with short interval
                    G_BuegelfeuerNextArcTimer = G_BuegelfeuerBurstInterval
                else
                    -- Burst finished, exit burst mode and calculate next arc timing
                    G_BuegelfeuerBurstMode = false
                    
                    -- Calculate timing for next arc sequence based on speed
                    local currentSpeed = Call("*:GetSpeed")
                    local speedKPH = math.abs(currentSpeed) * 3.6
                    local baseInterval
                    if speedKPH < 20 then
                        baseInterval = 4 + math.random() * 11  -- 4-15 seconds
                    elseif speedKPH < 60 then
                        baseInterval = 3 + math.random() * 5  -- 3-8 seconds
                    elseif speedKPH < 100 then
                        baseInterval = 1 + math.random() * 2  -- 1-3 seconds
                    else
                        baseInterval = 1 + math.random()  -- 1-2 seconds
                    end
                    G_BuegelfeuerNextArcTimer = baseInterval
                end
            end
        end
    else
        -- Update timer for next arc
        if G_BuegelfeuerNextArcTimer > 0 then
            G_BuegelfeuerNextArcTimer = G_BuegelfeuerNextArcTimer - dt
            
            -- Time to trigger next arc
            if G_BuegelfeuerNextArcTimer <= 0 then
                Call("Buegelfeuer:Activate", 1)
                SetControlValue("Buegelfeuer", 1)
                G_BuegelfeuerActive = true
                G_BuegelfeuerTimer = 0
                
                -- If not in burst mode, decide on next arc timing
                if not G_BuegelfeuerBurstMode then
                    -- Base interval between arcs (in seconds)
                    local baseInterval
                    if speedKPH < 20 then
                        baseInterval = 4 + math.random() * 11  -- 4-15 seconds when barely moving
                    elseif speedKPH < 60 then
                        baseInterval = 3 + math.random() * 5  -- 3-8 seconds at low-medium speed
                    elseif speedKPH < 100 then
                        baseInterval = 1 + math.random() * 2  -- 1-3 seconds at medium-high speed
                    else
                        baseInterval = 1 + math.random()  -- 1-2 seconds at high speed
                    end
                    
                    -- 80% chance to enter burst mode (rapid sequence of arcs)
                    if math.random() < 0.80 then
                        G_BuegelfeuerBurstMode = true
                        G_BuegelfeuerBurstCount = math.random(6, 10)  -- 6-10 arcs in a burst
                        G_BuegelfeuerBurstInterval = 0.05 + math.random() * 0.05  -- 0.05-0.1 seconds between burst arcs
                        G_BuegelfeuerNextArcTimer = G_BuegelfeuerBurstInterval
                    else
                        G_BuegelfeuerNextArcTimer = baseInterval
                    end
                end
            end
        else
            -- Initialize first arc timing if not set
            if G_BuegelfeuerNextArcTimer == 0 and not G_BuegelfeuerBurstMode then
                -- Start with a random delay
                local initialDelay = 2 + math.random() * 3  -- 2-5 seconds
                G_BuegelfeuerNextArcTimer = initialDelay
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Snow Particles (Schnee)
-- Controls snow particle emission from wheels based on speed
-- Only active in winter
--------------------------------------------------------------------------------
function UpdateSnowParticles(dt)
    -- Only active in winter (Season 3)
    if G_Season ~= 3 then
        Call("SchneeL:SetEmitterActive", 0)
        Call("SchneeR:SetEmitterActive", 0)
        return
    end
    
    -- Get current speed
    local currentSpeed = Call("*:GetSpeed") or 0
    local speedKPH = math.abs(currentSpeed) * 3.6
    
    -- Below 10 km/h: deactivate particles
    if speedKPH < 10.0 then
        Call("SchneeL:SetEmitterActive", 0)
        Call("SchneeR:SetEmitterActive", 0)
    else
        -- Activate emitters
        Call("SchneeL:SetEmitterActive", 1)
        Call("SchneeR:SetEmitterActive", 1)
        
        -- Calculate emission rate based on speed with custom scaling
        -- 10 km/h = 0.2
        -- 80 km/h = 0.02
        -- 140 km/h = 0.01
        local emitterRate
        if speedKPH <= 80 then
            -- Linear interpolation from 0.2 (at 10 km/h) to 0.02 (at 80 km/h)
            local t = (speedKPH - 10.0) / 70.0  -- Normalize to 0-1 range
            emitterRate = 0.2 - (t * 0.18)  -- 0.2 - 0.18 = 0.02
        else
            -- Linear interpolation from 0.02 (at 80 km/h) to 0.01 (at 140 km/h)
            local t = (speedKPH - 80.0) / 60.0  -- Normalize to 0-1 range
            t = math.min(t, 1.0)  -- Clamp at 140 km/h
            emitterRate = 0.02 - (t * 0.01)  -- 0.02 - 0.01 = 0.01
        end
        
        -- Set the emission rate for both left and right particles
        Call("SchneeL:SetEmitterRate", emitterRate)
        Call("SchneeR:SetEmitterRate", emitterRate)
    end
end

--------------------------------------------------------------------------------
-- Wheelslip Detection and Speedometer Flickering (Tachozappeln)
-- Simulates realistic speedometer needle flickering during wheelslip
--------------------------------------------------------------------------------
function UpdateWheelslipDetection(dt)
    -- Get wheelslip value from simulation (1.0 = no slip, 1.1-4.0 = slipping)
    local slipAmount = Call("*:GetControlValue", "Wheelslip", 0) or 1.0
    
    -- Get brake control value to detect if brakes are applied
    local brakeControl = Call("*:GetControlValue", "TrainBrakeControl", 0) or 0
    
    -- Create custom vWheelSlip that resets when braking (realistic behavior)
    local vWheelSlipValue
    if brakeControl > 0.01 then
        -- Brakes are applied: wheelslip should stop (realistic)
        vWheelSlipValue = 1.0
        G_WheelSlip = 0  -- No wheelslip when braking
    else
        -- No braking: use game's wheelslip value
        vWheelSlipValue = slipAmount
        
        -- Detect wheelslip: slip occurs when value is > 1.0
        if slipAmount > 1.0 then
            G_WheelSlip = 1
            G_WheelSlipTimer = G_WheelSlipTimer + dt
        else
            G_WheelSlip = 0
            G_WheelSlipTimer = 0
        end
    end
    
    -- Set the custom vWheelSlip control value
    Call("*:SetControlValue", "vWheelSlip", 0, vWheelSlipValue)
end

function UpdateSpeedometerWithWheelslip(dt)
    -- Get current simulation time and speedometer reading
    local simulationTime = Call("*:GetSimulationTime") or 0
    local simSpeedometer = Call("*:GetControlValue", "SpeedometerKPH", 0) or 0
    
    -- Get custom vWheelSlip value (1.0 = no slip, >1.0 = slipping)
    local vWheelSlip = Call("*:GetControlValue", "vWheelSlip", 0) or 1.0
    
    local targetSpeedometer = simSpeedometer
    
    -- If wheelslip is active (vWheelSlip > 1.0), apply Tachozappeln (speedometer flickering)
    if vWheelSlip > 1.0 then
        if simulationTime > G_LastSlipCalcTime + 0.02 then
            local riddleValue = 10
            local randomRiddle = math.random()
            local randomRiddle2 = math.random()
            local randomRiddle3 = randomRiddle + randomRiddle2
            
            -- Calculate flicker amount based on random values
            if randomRiddle > 0.7 then
                riddleValue = 20.0 + randomRiddle3
            elseif randomRiddle < 0.3 then
                riddleValue = 15.0 + (randomRiddle * randomRiddle2)
            else
                riddleValue = 10.0 + (randomRiddle * randomRiddle2)
            end
            
            -- Check if dynamic brake is active
            local dynamicBrake = Call("*:GetControlValue", "DynamicBrake", 0) or 0
            if dynamicBrake > 0.1 then
                -- During braking: flicker downward from last stable value
                targetSpeedometer = (G_SpeedometerLastValue - riddleValue) + 10
            else
                -- During acceleration: flicker upward from CURRENT displayed value
                -- (not G_SpeedometerLastValue which is frozen since slip started)
                targetSpeedometer = G_DisplayedSpeedometer + riddleValue
            end
            
            G_LastSlipCalcTime = simulationTime
        else
            -- Use last calculated target between updates
            targetSpeedometer = G_DisplayedSpeedometer
        end
    else
        -- No wheelslip: update last value for future reference
        if simSpeedometer ~= G_SpeedometerLastValue then
            G_SpeedometerLastValue = simSpeedometer
        end
    end
    
    -- Apply smooth interpolation with in-ease effect
    local smoothFactor = 4.0  -- Weaker smoothing for gentle transition
    G_DisplayedSpeedometer = G_DisplayedSpeedometer + (targetSpeedometer - G_DisplayedSpeedometer) *
                             math.min(1.0, dt * smoothFactor)
    
    -- Set the smoothed speedometer value
    Call("*:SetControlValue", "vSpeedometerKPH", 0, G_DisplayedSpeedometer)
    
    -- Set absolute speed in m/s (convert from km/h by dividing by 3.6)
    local speedMS = G_DisplayedSpeedometer / 3.6
    Call("*:SetControlValue", "vAbsoluteSpeed", 0, speedMS)
end

function Initialise()
    Call("BeginUpdate")
    -- Don't seed - Train Simulator already initializes each wagon with unique random state
    -- Just call math.random() directly like FVD script does
    G_VST_MasterRandomID = math.random(1, 999999)
    G_ThisCabID = math.random(1, 999999)  -- Generate unique ID for this cab
    
    -- Initialize pressure buildup timer
    G_PressureInitTimer = 0
    G_PressureInitComplete = false
    
    -- Get current season (0=Spring, 1=Summer, 2=Autumn, 3=Winter)
    G_Season = SysCall("GetSeason") or 0
    
    -- Initialize Buegelfeuer (pantograph arcing) as off
    Call("Buegelfeuer:Activate", 0)
    SetControlValue("Buegelfeuer", 0)
    
    -- G_PZB:Initialise()
    StopRequest_Initialize()  -- Initialize stop request system
end


--------------------------------------------------------------------------------
-- VST (Vielfachsteuerungskabel) Configuration
--------------------------------------------------------------------------------


function UpdateVSTCable()
    -- Only send ID if we're an inner endcar (both ends coupled)
    if G_VST_MasterRandomID and G_VST_MasterRandomID > 0 and 
       G_SomethingCoupledAtRear == 1 and G_SomethingCoupledAtFront == 1 then
        Call("SendConsistMessage", CM_VST_EXCHANGE_ID, G_VST_MasterRandomID, 0)
        Call("SendConsistMessage", CM_VST_EXCHANGE_ID, G_VST_MasterRandomID, 1)
    end
end

function UpdateVST()
    -- Force outer endcars (not both ends coupled) to Idle
    if not (G_SomethingCoupledAtRear == 1 and G_SomethingCoupledAtFront == 1) then
        G_VST_Mode = 0
        G_VST_CompareDirection = nil
        SetControlValue("VST", 0)
    end
    
    local vstMode = GetControlValue("VST")
    
    if vstMode < 0.5 then
        -- Mode 0: Idle
        Call("*:ActivateNode", "VST_Receiver_closed", 1)
        Call("*:ActivateNode", "VST_Grounding_open", 1)
        Call("*:ActivateNode", "VST_Cable_I", 1)
        
        Call("*:ActivateNode", "VST_Receiver_open", 0)
        Call("*:ActivateNode", "VST_Grounding_closed", 0)
        Call("*:ActivateNode", "VST_Cable_G", 0)
        Call("*:ActivateNode", "VST_Cable_R", 0)
        
    elseif vstMode < 1.5 then
        -- Mode 1: Giving
        Call("*:ActivateNode", "VST_Receiver_closed", 1)
        Call("*:ActivateNode", "VST_Grounding_closed", 1)
        Call("*:ActivateNode", "VST_Cable_G", 1)
        
        Call("*:ActivateNode", "VST_Receiver_open", 0)
        Call("*:ActivateNode", "VST_Grounding_open", 0)
        Call("*:ActivateNode", "VST_Cable_I", 0)
        Call("*:ActivateNode", "VST_Cable_R", 0)
        
    else
        -- Mode 2: Receiving
        Call("*:ActivateNode", "VST_Receiver_open", 1)
        Call("*:ActivateNode", "VST_Grounding_open", 1)
        Call("*:ActivateNode", "VST_Cable_R", 1)
        Call("*:ActivateNode", "VST_Cable_I", 1)
        
        Call("*:ActivateNode", "VST_Receiver_closed", 0)
        Call("*:ActivateNode", "VST_Grounding_closed", 0)
        Call("*:ActivateNode", "VST_Cable_G", 0)
    end
end

function UpdateWindowAndDoorAnimations()
    -- Check if player is in this cab
    local isEngineWithKey = Call("GetIsEngineWithKey")
    
    -- Get control values
    local windowL = GetControlValue("WindowL") or 0
    local windowR = GetControlValue("WindowR") or 0
    local fstTuer = GetControlValue("FstTuer") or 0
    local fstMirror = GetControlValue("FstMirror_Anim") or 0
    local RolloL = GetControlValue("RolloL") or 0
    local RolloVL = GetControlValue("RolloVL") or 0
    local RolloVR = GetControlValue("RolloVR") or 0
    local Cam_Move = GetControlValue("Cam_Movement" or 0)

    -- If player is NOT in this cab (GetIsEngineWithKey returns 0), close all blinds
    if isEngineWithKey == 0 then
        RolloL = 1
        RolloVL = 1
        RolloVR = 1
    end

    -- Set corresponding animation times
    SetAnimTime("WindowL_ext", windowL)
    SetAnimTime("WindowR_ext", windowR)
    SetAnimTime("FstTuer_ext", fstTuer)
    SetAnimTime("MirrorR", fstMirror)
    SetAnimTime("MirrorL", fstMirror)
    SetAnimTime("RolloL", RolloL)
    SetAnimTime("RolloVL", RolloVL)
    SetAnimTime("RolloVR", RolloVR)
    SetAnimTime("Cam_MoveAnim", Cam_Move)
end

function UpdateMirrorIndicators()
    -- Get door control signals (whether driver has released doors)
    local doorsLeftSignal = GetControlValue("DoorsOpenCloseLeft") or 0
    local doorsRightSignal = GetControlValue("DoorsOpenCloseRight") or 0
    
    -- Check if doors are open or signal is released (1)
    local leftIndicator = (G_ConsistDoorsOpenLeft or G_LocalDoorsOpenLeft or doorsLeftSignal > 0.5)
    local rightIndicator = (G_ConsistDoorsOpenRight or G_LocalDoorsOpenRight or doorsRightSignal > 0.5)
    
    -- Set all mirror control values (both ABt and RBDe)
    SetControlValue("Spiegel_L_RBDe", leftIndicator and 1 or 0)
    SetControlValue("Spiegel_L_ABt", leftIndicator and 1 or 0)
    SetControlValue("Spiegel_R_RBDe", rightIndicator and 1 or 0)
    SetControlValue("Spiegel_R_ABt", rightIndicator and 1 or 0)
end