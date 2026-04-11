function TuerfreigabeButton(name, value)
    if name == "BT_TuerFreigabe_R" then
        if value > 0.99 then
            -- if not G_RC and not G_Steuerstrom then
            --     return
            -- end
            SetControlValue("Startup", 1)
            -- else
            --     G_FahrgastraumEinButtonPressed = false
            -- end
        end
    end
end