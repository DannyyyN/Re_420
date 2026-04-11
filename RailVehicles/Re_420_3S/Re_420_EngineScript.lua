--------------------------------------------------------------
--                  Re 420 Engine Script                    --
--------------------------------------------------------------
HERE = "Assets\\InbetweenArrows\\Re_420\\RailVehicles\\Re_420_3S\\"
require(HERE .. "Utils.lua")
require(HERE .. "Re_420_ControlScript.lua")

-- Druckzustand initialisieren
speiseleitungsdruck = 9.4
hauptluftdruck = 4.923795
bremszylinderdruck = 0.0
trainbrake_pressure = 0.0
needle_HLL = 4.923795
needle_BC = 0.0
needle_SL = 9.4

-- Zustandsflags zurücksetzen
G_PressureInitTimer = 0.0
G_PressureInitComplete = false
G_Fuellstellung_Active = false
G_Fuellstellung_Phase = 0
G_Fuellstellung_Timer = 0
G_Fuellstellung_Dwell_Timer = 0
G_PostFuellstellung_Descent = false
G_Fuellstellung_Phase3_Target = 5.4
G_Fahrstellung_Overshoot_Active = false
G_Fahrstellung_Dwell_Timer = 0
G_BrakePressureGoal = 5.0
G_Zwangsbremse = false
G_Rangierbremse = 0.0
G_CompressorRunning = false
G_SAPBEngaged = true
G_FstCheckTimer = 0.0
G_FstCheckComplete = false

-- Stufenschalter auf 0
G_DriveStage = 0
G_BrakeStage = 0
G_StageSwitchTimer = 0.0

-- Startup / cab state zurücksetzen
-- G_RC = true
G_cabActive = true
G_StartupTimer = 0
G_StartupComplete = false
_hasUpdated = false

--------------------------------------------------------------------------------
-- STUFENSCHALTER
-- 32 Fahrstufen  → Stufe 32 = Regulator 1.0 = 3100A
-- 23 Bremsstufen → Stufe 23 = DynamicBrake 1.0 = 2200A
--------------------------------------------------------------------------------

local DRIVE_STAGES = 32
local BRAKE_STAGES = 23
local DRIVE_A_PER_STAGE = 3100.0 / DRIVE_STAGES -- 96.875 A/Stufe
local BRAKE_A_PER_STAGE = 2200.0 / BRAKE_STAGES -- ~95.65 A/Stufe

-- Schaltzeiten
local FAST_INTERVAL = 1.0 / 3.0 -- Rasches Aufschalten: 3 Stufen/s
local SLOW_INTERVAL = 1.0 -- Stufenweises Schalten: 1 Stufe/s

-- Zustand
local G_DriveStage = 0 -- 0..32
local G_BrakeStage = 0 -- 0..23
local G_StageSwitchTimer = 0.0 -- Countdown bis zur nächsten erlaubten Stufe

-- Fahrschalterposition aus VirtualThrottle-Wert bestimmen
-- Positionen identisch zum Domino:
--   ++: >4.9  |  +: >3.9  |  M: >2.5  |  ●: >1.9
--   –: >0.9   |  0: >-0.1 |  B–: >-1.1 |  B●: >-2.1 |  B+: rest
local function GetFSPos(tv)
    if tv > 4.9 then
        return "++"
    elseif tv > 3.9 then
        return "+"
    elseif tv > 2.5 then
        return "M"
    elseif tv > 1.9 then
        return "dot" -- Fahren ●
    elseif tv > 0.9 then
        return "minus" -- Fahren –
    elseif tv > -0.1 then
        return "0" -- Neutral 0
    elseif tv > -1.1 then
        return "b_minus" -- Bremsen –
    elseif tv > -2.1 then
        return "b_dot" -- Bremsen ●
    else
        return "b_plus" -- Bremsen +
    end
end

function Stufenschalter(dt)
    local tv = GetControlValue("VirtualThrottle") or 0
    local pos = GetFSPos(tv)

    -- Timer herunterzählen
    G_StageSwitchTimer = G_StageSwitchTimer - dt

    -- Sicherheit: Beim Wechsel zwischen Fahren und Bremsen sofort Gegenseite nullen
    if pos == "b_minus" or pos == "b_dot" or pos == "b_plus" then
        G_DriveStage = 0
    elseif pos == "++" or pos == "+" or pos == "M" or pos == "dot" or pos == "minus" then
        G_BrakeStage = 0
    end

    -- ─────────────────────────────────────────────────────────
    -- Position 0: Rasches Abschalten auf 0 (Trennhüpfer öffnen)
    -- ─────────────────────────────────────────────────────────
    if pos == "0" then
        if G_DriveStage > 0 and G_StageSwitchTimer <= 0 then
            G_DriveStage = G_DriveStage - 1
            G_StageSwitchTimer = FAST_INTERVAL
        end
        if G_BrakeStage > 0 and G_StageSwitchTimer <= 0 then
            G_BrakeStage = G_BrakeStage - 1
            G_StageSwitchTimer = FAST_INTERVAL
        end

        -- ─────────────────────────────────────────────────────────
        -- Fahren ++: Rasches Aufschalten (3/s) bis 2100A,
        --            dann stufenweises Weiterschalten (1/s) bis 3100A
        -- ─────────────────────────────────────────────────────────
    elseif pos == "++" then
        if G_DriveStage < DRIVE_STAGES and G_StageSwitchTimer <= 0 then
            local currentA = G_DriveStage * DRIVE_A_PER_STAGE
            if currentA < 2100.0 then
                G_DriveStage = G_DriveStage + 1
                G_StageSwitchTimer = FAST_INTERVAL
            else
                G_DriveStage = G_DriveStage + 1
                G_StageSwitchTimer = SLOW_INTERVAL
            end
        end

        -- ─────────────────────────────────────────────────────────
        -- Fahren +: Rasches Aufschalten bis 2100A (3/s),
        --           dann stufenweise (1/s) mit Zuschaltstrom 2300A
        -- ─────────────────────────────────────────────────────────
    elseif pos == "+" then
        if G_DriveStage < DRIVE_STAGES and G_StageSwitchTimer <= 0 then
            local currentA = G_DriveStage * DRIVE_A_PER_STAGE
            if currentA < 2100.0 then
                G_DriveStage = G_DriveStage + 1
                G_StageSwitchTimer = FAST_INTERVAL
            elseif currentA < 2300.0 then
                G_DriveStage = G_DriveStage + 1
                G_StageSwitchTimer = SLOW_INTERVAL
            end
            -- Bei >= 2300A: kein weiteres Aufschalten in Position +
        end

        -- ─────────────────────────────────────────────────────────
        -- Fahren M: Stufenweises Aufschalten (1/s),
        --           Zuschaltstrom 2300A
        -- ─────────────────────────────────────────────────────────
    elseif pos == "M" then
        if G_DriveStage < DRIVE_STAGES and G_StageSwitchTimer <= 0 then
            local currentA = G_DriveStage * DRIVE_A_PER_STAGE
            if currentA < 2300.0 then
                G_DriveStage = G_DriveStage + 1
                G_StageSwitchTimer = SLOW_INTERVAL
            end
        end

        -- ─────────────────────────────────────────────────────────
        -- Fahren ●: Stufenschalter bleibt auf der letzten Stufe
        -- ─────────────────────────────────────────────────────────
    elseif pos == "dot" then
        -- Keine Änderung

        -- ─────────────────────────────────────────────────────────
        -- Fahren –: Stufenweises Zurückschalten bis 2100A (1/s),
        --           dann rasches Abschalten auf 0 (3/s)
        --           (Von 0: nur Trennhüpfer ein → G_DriveStage = 0, kein Effekt)
        -- ─────────────────────────────────────────────────────────
    elseif pos == "minus" then
        if G_DriveStage > 0 and G_StageSwitchTimer <= 0 then
            local currentA = G_DriveStage * DRIVE_A_PER_STAGE
            if currentA > 2100.0 then
                -- Stufenweises Zurückschalten (langsam)
                G_DriveStage = G_DriveStage - 1
                G_StageSwitchTimer = SLOW_INTERVAL
            else
                -- Rasches Abschalten auf 0
                G_DriveStage = G_DriveStage - 1
                G_StageSwitchTimer = FAST_INTERVAL
            end
        end

        -- ─────────────────────────────────────────────────────────
        -- Bremsen –: Stufenweises Zurückschalten bis 2100A (1/s),
        --            dann rasches Abschalten auf 0 (3/s)
        --            (Von 0: Richtungswender auf Bremsen, Trennhüpfer ein)
        -- ─────────────────────────────────────────────────────────
    elseif pos == "b_minus" then
        if G_BrakeStage > 0 and G_StageSwitchTimer <= 0 then
            local currentA = G_BrakeStage * BRAKE_A_PER_STAGE
            if currentA > 2100.0 then
                G_BrakeStage = G_BrakeStage - 1
                G_StageSwitchTimer = SLOW_INTERVAL
            else
                G_BrakeStage = G_BrakeStage - 1
                G_StageSwitchTimer = FAST_INTERVAL
            end
        end

        -- ─────────────────────────────────────────────────────────
        -- Bremsen ●: Stufenschalter bleibt auf der letzten Stufe
        -- ─────────────────────────────────────────────────────────
    elseif pos == "b_dot" then
        -- Keine Änderung

        -- ─────────────────────────────────────────────────────────
        -- Bremsen +: Rasches Aufschalten bis 2100A (3/s),
        --            dann stufenweise (1/s) bis Bremsstrom 2200A
        -- ─────────────────────────────────────────────────────────
    elseif pos == "b_plus" then
        if G_BrakeStage < BRAKE_STAGES and G_StageSwitchTimer <= 0 then
            local currentA = G_BrakeStage * BRAKE_A_PER_STAGE
            if currentA < 2100.0 then
                G_BrakeStage = G_BrakeStage + 1
                G_StageSwitchTimer = FAST_INTERVAL
            else
                G_BrakeStage = G_BrakeStage + 1
                G_StageSwitchTimer = SLOW_INTERVAL
            end
        end
    end

    -- Stufen auf TS-Controls abbilden
    -- Fahrstufe 32 → Regulator 1.0 (= 3100A)
    -- Bremsstufe 23 → DynamicBrake 1.0 (= 2200A)
    SetControlValue("Regulator", G_DriveStage / DRIVE_STAGES)
    SetControlValue("DynamicBrake", G_BrakeStage / BRAKE_STAGES)
end

--------------------------------------------------------------------------------
-- ZUGBREMSHEBEL (FV4a Bremsventilstellung → Ziel-HLL-Druck)
-- Identisch zum Domino
--------------------------------------------------------------------------------

function ZugBremsHebel(value)
    if value < 0.175 then
        return -1.0 -- Füllstellung
    elseif value < 0.305 then
        return 5.0 -- Fahrstellung
    elseif value < 0.4 then
        return 4.6 - (value - 0.345) / 0.055 * 0.3
    elseif value < 0.66 then
        return 4.3 - (value - 0.4) / 0.26 * 0.5
    elseif value < 0.72 then
        return 3.8 - (value - 0.66) / 0.06 * 0.2
    elseif value <= 0.8 then
        return 3.6 - (value - 0.72) / 0.08 * 0.1
    elseif value <= 0.9 then
        return 3.5 - (value - 0.8) / 0.1 * 0.6
    elseif value < 1.1 then
        return 2.9
    else
        return 0.0 -- Schnellbremse
    end
end

--------------------------------------------------------------------------------
-- BREMSDRUCKZUSTAND (identisch zum Domino)
--------------------------------------------------------------------------------

local speiseleitungsdruck = 9.4
local hauptluftdruck = 4.923795
local bremszylinderdruck = 0.0
local trainbrake_pressure = 0.0
local needle_HLL = 4.923795
local needle_BC = 0.0
local needle_SL = 9.4

-- Kompressor-Konstanten
local C_COMPRESSOR_ON_PRESSURE = 8.0
local C_COMPRESSOR_OFF_PRESSURE = 10.0
local C_COMPRESSOR_FILL_RATE = 0.065

-- Bremsanlage-Konstanten (identisch Domino)
local C_HLL_EVACUATION_SPEED = 0.4
local C_HLL_FILL_SPEED = 0.12
local C_HLL_SL_FILL_FACTOR = 0.1
local C_BC_FILL_SPEED = 0.3

-- Füllstellung / Fahrstellung Zustandsvariablen
G_BrakePressureGoal = 0.0
G_Fuellstellung_Active = false
G_Fuellstellung_Phase = 0
G_Fuellstellung_Timer = 0
G_Fuellstellung_Dwell_Timer = 0
G_PostFuellstellung_Descent = false
G_Fuellstellung_Phase3_Target = 5.4
G_Fahrstellung_Overshoot_Active = false
G_Fahrstellung_Dwell_Timer = 0
G_Zwangsbremse = false
G_Rangierbremse = 0.0
G_CompressorRunning = false
G_SAPBEngaged = true
G_PressureInitComplete = false
G_PressureInitTimer = 0.0
G_FstCheckComplete = false
G_FstCheckTimer = 0.0

-- Cab-Zustand (identisch zum Domino)
G_RC = true
G_cabActive = true

-- Startup-Timer (verhindert Interlock-Meldungen während Initialisierung)
G_StartupTimer = 0
G_StartupComplete = false

-- Reverser-Interlock Nachrichtenflags
G_Msg_ThrottleNoReverser = false
G_Msg_ReverserThrottleOn = false
G_Msg_ReverserMoving = false

--------------------------------------------------------------------------------
-- BREMSVENTIL: VirtualBrake + VirtualEngineBrakeControl lesen
--------------------------------------------------------------------------------

function Bremsventil(dt)
    G_Rangierbremse = GetControlValue("VirtualEngineBrakeControl") or 0
    local brakeValue = GetControlValue("VirtualBrake") or 0
    G_BrakePressureGoal = ZugBremsHebel(brakeValue)
end

--------------------------------------------------------------------------------
-- BREMSRECHNER (identische Physik zum Domino, vereinfacht)
-- Ohne: Hauptschalter-Gating, ZTB-Skalierung, Magnetschienenbremse,
--       Schleuderbremse, Bügelfeuer (für erste Version)
--------------------------------------------------------------------------------

function Bremsrechner(dt)

    -- ── Kompressor (automatisch, immer aktiv) ────────────────────────────────
    if G_CompressorRunning then
        if speiseleitungsdruck >= C_COMPRESSOR_OFF_PRESSURE then
            G_CompressorRunning = false
        else
            speiseleitungsdruck = speiseleitungsdruck + C_COMPRESSOR_FILL_RATE * dt
        end
    else
        if speiseleitungsdruck < C_COMPRESSOR_ON_PRESSURE then
            G_CompressorRunning = true
        end
    end

    -- ── Druckinitialisierung / Abschlussstellung ──────────────────────────────
    local y = GetControlValue("VirtualBrake") or 0
    local abschlussstellung_active = false

    if y < 0.01 then
        if not G_PressureInitComplete then
            -- Initialisierungsphase: Drücke auf Startwerte zwingen
            G_BrakePressureGoal = 4.923795
            hauptluftdruck = 4.923795
            speiseleitungsdruck = 9.4
            bremszylinderdruck = 0.0
        else
            -- Abschlussstellung: Drücke einfrieren
            abschlussstellung_active = true
        end
    end

    if not abschlussstellung_active then

        -- ── Füllstellung (FV4a Sonderverhalten) ──────────────────────────────
        if G_BrakePressureGoal < -0.5 then
            if not G_Fuellstellung_Active then
                G_Fuellstellung_Active = true
                G_Fuellstellung_Phase = 0
                G_Fuellstellung_Timer = 0
            end
            G_Fuellstellung_Dwell_Timer = G_Fuellstellung_Dwell_Timer + dt
            G_Fuellstellung_Timer = G_Fuellstellung_Timer + dt

            if G_Fuellstellung_Phase == 0 then
                -- Phase 0: 2 Sekunden Wartezeit
                if G_Fuellstellung_Timer >= 2.0 then
                    G_Fuellstellung_Phase = 1
                    G_Fuellstellung_Timer = 0
                end
            elseif G_Fuellstellung_Phase == 1 then
                -- Phase 1: Hochdruckfüllstoß auf 7.5 bar (~2 Sek.)
                if hauptluftdruck < 7.4 then
                    hauptluftdruck = hauptluftdruck + 3.75 * dt
                    speiseleitungsdruck = speiseleitungsdruck - 0.3 * dt
                else
                    G_Fuellstellung_Phase = 2
                    G_Fuellstellung_Timer = 0
                end
            elseif G_Fuellstellung_Phase == 2 then
                -- Phase 2: Langsamer Abstieg 7.5 → 5.4 bar (3 Sek.)
                if G_Fuellstellung_Timer < 3.0 then
                    if hauptluftdruck > 5.4 then
                        hauptluftdruck = hauptluftdruck - 0.7 * dt
                    end
                else
                    hauptluftdruck = 5.4
                    G_Fuellstellung_Phase = 3
                    G_Fuellstellung_Timer = 0
                end
            elseif G_Fuellstellung_Phase == 3 then
                -- Phase 3: Sehr langsamer Abstieg 5.4 → 5.0 (~3 Min., Niederdrucküberladung)
                G_Fuellstellung_Phase3_Target = math.max(5.0, G_Fuellstellung_Phase3_Target - 0.0022 * dt)
                G_PostFuellstellung_Descent = true
                if hauptluftdruck > G_Fuellstellung_Phase3_Target + 0.01 then
                    hauptluftdruck = hauptluftdruck - 0.0022 * dt
                elseif hauptluftdruck >= G_Fuellstellung_Phase3_Target - 0.01 then
                    hauptluftdruck = G_Fuellstellung_Phase3_Target
                end
                if G_Fuellstellung_Phase3_Target <= 5.0 then
                    G_PostFuellstellung_Descent = false
                end
            end
        else
            -- Füllstellung verlassen
            if G_Fuellstellung_Active then
                if G_Fuellstellung_Phase == 3 then
                    -- Langsamer Abstieg weiterführen
                elseif G_Fuellstellung_Phase == 2 then
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

        -- ── Post-Füllstellung: langsamer Abstieg weiterführen ─────────────────
        if G_PostFuellstellung_Descent and not G_Fuellstellung_Active then
            G_Fuellstellung_Phase3_Target = math.max(5.0, G_Fuellstellung_Phase3_Target - 0.0022 * dt)
            if G_Fuellstellung_Phase3_Target <= 5.0 then
                G_PostFuellstellung_Descent = false
            end
            if math.abs(G_BrakePressureGoal - 5.0) < 0.01 and not G_Fahrstellung_Overshoot_Active then
                if hauptluftdruck > G_Fuellstellung_Phase3_Target + 0.01 then
                    hauptluftdruck = hauptluftdruck - 0.0022 * dt
                elseif hauptluftdruck < G_Fuellstellung_Phase3_Target - 0.02 then
                    hauptluftdruck = math.min(hauptluftdruck + 1.5 * dt, G_Fuellstellung_Phase3_Target)
                    speiseleitungsdruck = speiseleitungsdruck - C_HLL_SL_FILL_FACTOR * dt
                else
                    hauptluftdruck = G_Fuellstellung_Phase3_Target
                end
            end
        end

        -- ── Fahrstellung Überschwingen (realistische Bremsfreigabe) ───────────
        if math.abs(G_BrakePressureGoal - 5.0) < 0.1 then
            if not G_Fahrstellung_Overshoot_Active then
                local diff = 5.0 - hauptluftdruck
                if diff > 0.1 and not G_PostFuellstellung_Descent then
                    G_Fahrstellung_Dwell_Timer = G_Fahrstellung_Dwell_Timer + dt
                    if G_Fahrstellung_Dwell_Timer >= 0.8 then
                        local overshoot = math.min(diff * 0.6, 1.0)
                        overshoot = math.max(overshoot, 0.5)
                        hauptluftdruck = 5.0 + overshoot
                        speiseleitungsdruck = speiseleitungsdruck - overshoot * 0.15
                        G_Fahrstellung_Overshoot_Active = true
                        G_Fahrstellung_Dwell_Timer = 0
                    end
                else
                    G_Fahrstellung_Dwell_Timer = 0
                end
            elseif hauptluftdruck > 5.05 then
                hauptluftdruck = hauptluftdruck - 0.16 * dt
                if hauptluftdruck <= 5.0 then
                    hauptluftdruck = 5.0
                    G_Fahrstellung_Overshoot_Active = false
                end
            else
                G_Fahrstellung_Overshoot_Active = false
            end
        else
            G_Fahrstellung_Overshoot_Active = false
            G_Fahrstellung_Dwell_Timer = 0
        end

        -- ── Effektives HLL-Ziel (Post-Füllstellung berücksichtigen) ───────────
        local effective_goal = G_BrakePressureGoal
        if G_PostFuellstellung_Descent and math.abs(G_BrakePressureGoal - 5.0) < 0.1 then
            effective_goal = G_Fuellstellung_Phase3_Target
        end

        -- ── HLL-Druckbewegung ─────────────────────────────────────────────────
        if effective_goal > -0.1 and not G_Fahrstellung_Overshoot_Active then
            if hauptluftdruck > effective_goal + 0.02 then
                local evac_speed = C_HLL_EVACUATION_SPEED
                if G_BrakePressureGoal < 0.5 then
                    evac_speed = C_HLL_EVACUATION_SPEED * 15.0 -- Schnellbremse: 15× schneller
                end
                hauptluftdruck = hauptluftdruck - evac_speed * dt
            elseif hauptluftdruck < effective_goal - 0.02 then
                local fill_speed = C_HLL_FILL_SPEED * 0.5
                if hauptluftdruck < 2.0 and G_BrakePressureGoal > 2.5 then
                    fill_speed = C_HLL_FILL_SPEED * 25.0 -- Schnelle Erholung nach Schnellbremse
                elseif hauptluftdruck < G_BrakePressureGoal - 1.0 and G_BrakePressureGoal > 2.0 then
                    fill_speed = C_HLL_FILL_SPEED * 15.0
                end
                hauptluftdruck = hauptluftdruck + fill_speed * dt
                speiseleitungsdruck = speiseleitungsdruck - C_HLL_SL_FILL_FACTOR * dt
            end
        end

        -- ── Bremszylinderdruck aus HLL berechnen ──────────────────────────────
        local bc_target
        if hauptluftdruck >= 4.7 then
            bc_target = 0.0
        elseif hauptluftdruck >= 2.9 then
            bc_target = 0.5 + (4.7 - hauptluftdruck) / 1.8 * 2.6
        elseif hauptluftdruck > 0.0 then
            bc_target = 3.1 + (2.9 - hauptluftdruck) / 2.9 * 0.1
        else
            bc_target = 3.2
        end

        trainbrake_pressure = bc_target

        local bc_fill = C_BC_FILL_SPEED
        if G_BrakePressureGoal < 0.5 then
            bc_fill = C_BC_FILL_SPEED * 3.0 -- Schnellbremse: 3× schneller
        end

        -- Rangierbremse (direktwirkend, kein Verzug)
        local bc_target_auto = bc_target
        local rangierbremse_bar = G_Rangierbremse * 3.5
        bc_target = math.max(bc_target, rangierbremse_bar)

        if rangierbremse_bar > bc_target_auto then
            -- Rangierbremse dominant: sofortige Wirkung
            bremszylinderdruck = rangierbremse_bar
        else
            -- Automatikbremse: pneumatische Verzögerung
            if bc_target > bremszylinderdruck then
                bremszylinderdruck = math.min(bremszylinderdruck + bc_fill * dt, bc_target)
            elseif bc_target < bremszylinderdruck then
                bremszylinderdruck = math.max(bremszylinderdruck - bc_fill * 0.5 * dt, bc_target)
            end
        end

        -- TrainBrakeControl setzen
        SetControlValue("TrainBrakeControl", trainbrake_pressure / 3.8)

        -- EngineBrakeControl (Fahrzeugbremse inkl. reduzierter Rangierbremse)
        local vehicleBrake
        if rangierbremse_bar > bc_target_auto and bc_target > 0.01 then
            local reduced = bc_target_auto + (rangierbremse_bar - bc_target_auto) * 0.6
            vehicleBrake = (bremszylinderdruck * (reduced / bc_target)) / 3.8
        else
            vehicleBrake = bremszylinderdruck / 3.8
        end
        vehicleBrake = math.min(vehicleBrake, 0.85)
        SetControlValue("EngineBrakeControl", vehicleBrake)

    else
        -- ── Abschlussstellung: aktuellen Zustand halten ───────────────────────
        local vehicleBrake = math.min(bremszylinderdruck / 3.8, 0.85)
        SetControlValue("EngineBrakeControl", vehicleBrake)
    end

    -- ── Drücke klemmen ────────────────────────────────────────────────────────
    speiseleitungsdruck = math.max(0.0, math.min(10.5, speiseleitungsdruck))
    hauptluftdruck = math.max(0.0, math.min(7.5, hauptluftdruck))
    bremszylinderdruck = math.max(0.0, math.min(3.8, bremszylinderdruck))

    -- ── Zeigernadelanimation (gedämpft, identisch Domino) ─────────────────────
    if G_BrakePressureGoal < 0.5 then
        needle_HLL = SmoothMove(dt, needle_HLL, hauptluftdruck, 20.0)
    else
        needle_HLL = SmoothMoveEaseOut(dt, needle_HLL, hauptluftdruck, 1.5)
    end
    needle_BC = SmoothMoveEaseOut(dt, needle_BC, bremszylinderdruck, 5.0)
    needle_SL = SmoothMoveEaseOut(dt, needle_SL, speiseleitungsdruck, 5.0)

    SetControlValue("HLLPressure", needle_HLL)
    SetControlValue("BCPressure", needle_BC)
    SetControlValue("SLPressure", needle_SL)

    -- ── HandBrake (FSB) ───────────────────────────────────────────────────────
    if G_FstCheckComplete then
        SetControlValue("HandBrake", lambda(G_SAPBEngaged, 1, 0))
    end
end

--------------------------------------------------------------------------------
-- REVERSER-INTERLOCK (identische Logik zum Domino)
-- • VirtualThrottle gesperrt wenn Reverser auf Neutral (0)
-- • Reverser gesperrt wenn Fahrschalter nicht auf 0 ODER Zug in Fahrt
--------------------------------------------------------------------------------

function UpdateReverserInterlocks()
    local tv = GetControlValue("VirtualThrottle") or 0
    local reverser = GetControlValue("Reverser") or 0
    local speedKPH = math.abs(Call("GetSpeed") or 0) * 3.6

    -- Fahrschalter ist auf "0" wenn VirtualThrottle im Bereich > -0.1 und <= 0.9
    local throttleAtZero = (tv > -0.1 and tv <= 0.9)
    local reverserAtNeutral = math.abs(reverser) < 0.1

    -- VirtualThrottle sperren wenn Reverser auf Neutral
    if reverserAtNeutral then
        Call("*:LockControl", "VirtualThrottle", 0, 1)
    else
        Call("*:LockControl", "VirtualThrottle", 0, 0)
        G_Msg_ThrottleNoReverser = false
    end

    -- Reverser sperren wenn Fahrschalter nicht 0 oder Zug fährt
    if not throttleAtZero then
        Call("*:LockControl", "Reverser", 0, 1)
    elseif speedKPH > 2.0 then
        Call("*:LockControl", "Reverser", 0, 1)
    else
        Call("*:LockControl", "Reverser", 0, 0)
        G_Msg_ReverserThrottleOn = false
        G_Msg_ReverserMoving = false
    end
end

--------------------------------------------------------------------------------
-- OnControlValueChange – Interlocks mit Meldungen
--------------------------------------------------------------------------------

function OnControlValueChange(name, index, value)
    local tv = GetControlValue("VirtualThrottle") or 0
    local reverser = GetControlValue("Reverser") or 0
    local speedKPH = math.abs(Call("GetSpeed") or 0) * 3.6

    local throttleAtZero = (tv > -0.1 and tv <= 0.9)
    local reverserAtNeutral = math.abs(reverser) < 0.1

    -- ── VirtualThrottle-Anforderung: Reverser prüfen ──────────────────────────
    if name == "VirtualThrottle" then
        if reverserAtNeutral then
            Call("*:LockControl", "VirtualThrottle", 0, 1)
            if not G_Msg_ThrottleNoReverser and G_StartupComplete then
                SysCall("ScenarioManager:ShowAlertMessageExt", "Wendeschalter / Directional switch",
                    "Wendeschalter einstellen\nSet directional switch", 1.5, 0)
                G_Msg_ThrottleNoReverser = true
            end
        else
            Call("*:LockControl", "VirtualThrottle", 0, 0)
        end
    end

    -- ── Reverser-Anforderung: Fahrschalter und Geschwindigkeit prüfen ─────────
    if name == "Reverser" then
        if not throttleAtZero then
            Call("*:LockControl", "Reverser", 0, 1)
            if not G_Msg_ReverserThrottleOn then
                SysCall("ScenarioManager:ShowAlertMessageExt", "Wendeschalter / Directional switch",
                    "Fahrschalter auf 0\nThrottle to 0", 1.5, 0)
                G_Msg_ReverserThrottleOn = true
            end
        elseif speedKPH > 2.0 then
            Call("*:LockControl", "Reverser", 0, 1)
            if not G_Msg_ReverserMoving then
                SysCall("ScenarioManager:ShowAlertMessageExt", "Wendeschalter / Directional switch",
                    "Nicht waehrend Fahrt\nNot while moving", 1.5, 0)
                G_Msg_ReverserMoving = true
            end
        else
            Call("*:LockControl", "Reverser", 0, 0)
        end
    end

    SetControlValue(name, value)
    TuerfreigabeButton(name, value)
end

--------------------------------------------------------------------------------
-- INITIALISIERUNG
--------------------------------------------------------------------------------

function Initialise()
    Call("BeginUpdate")
end

--------------------------------------------------------------------------------
-- INITIALUPDATE (einmalig beim ersten Frame, identisch zum Domino)
--------------------------------------------------------------------------------

local _hasUpdated = false

function InitialUpdate(dt)
    SysCall("ScenarioManager:ShowAlertMessageExt", "Test", 2, 0)
    SetAnimTime("pantograph1", 1)
    SetControlValue("Startup", 1)
    SetControlValue("PantographControl", 1)
    -- VirtualThrottle auf Neutral initialisieren
    SetControlValue("VirtualThrottle", 0)
    -- FST-Check-Timer starten
    G_FstCheckTimer = 0
    G_FstCheckComplete = false

    -- VirtualBrake auf Fahrstellung setzen
    SetControlValue("VirtualBrake", 0.25)
    SetControlValue("Reverser", 0)
end

--------------------------------------------------------------------------------
-- UPDATE (Hauptschleife)
--------------------------------------------------------------------------------

function Update(dt)

    -- ── Einmaliger erster Frame (identisch zum Domino) ────────────────────────
    if not _hasUpdated then
        InitialUpdate(dt)
        _hasUpdated = true
    end

    -- ── Startup-Timer: Interlock-Meldungen während Init unterdrücken ──────────
    if not G_StartupComplete then
        G_StartupTimer = G_StartupTimer + dt
        if G_StartupTimer >= 2.0 then
            G_StartupComplete = true
        end
    end
    -- ── Druckinitialisierungstimer ────────────────────────────────────────────
    if not G_PressureInitComplete then
        G_PressureInitTimer = G_PressureInitTimer + dt
        if G_PressureInitTimer >= 0.5 then
            G_PressureInitComplete = true
        end
    end

    -- ── FST-Prüfung (Führerstand vs. Mittelwagen) ─────────────────────────────
    if not G_FstCheckComplete then
        G_FstCheckTimer = G_FstCheckTimer + dt
        if G_FstCheckTimer >= 0.5 then
            G_FstCheckComplete = true
        end
    end

    -- ── Hauptsysteme ──────────────────────────────────────────────────────────
    Stufenschalter(dt)
    Bremsventil(dt)
    Bremsrechner(dt)
    UpdateReverserInterlocks()
end
