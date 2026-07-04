if CLIENT then
    -- =============================================================
    -- 1. CONFIGURATION ET ÉTATS DU SYSTÈME
    -- =============================================================
    MYMENU = MYMENU or {
        Active = false,
        Closing = false,      
        SubClosing = false,   
        Index = 1,
        CurrentMenu = "MAIN",
        MenuX = -350, 
        TargetMenuX = 15,
        MenuY = 15,
        SubMenuOffset = -350, 
        TargetOffset = 0,
        ScrollIndex = 1,
        
        -- Timers et variables pour les effets UI
        MainMenuNoiseStart = 0,
        SubMenuNoiseStart = 0,
        CloseNoiseStart = 0,
        SubCloseNoiseStart = 0,
        NoiseDuration = 0.15, 

        -- Système Typewriter (Machine à écrire)
        MenuOpenTime = 0,
        SubMenuOpenTime = 0,
        FullTitle = "> Override",
        TypeSpeed = 0.04,

        -- États de la logique interne du menu
        InSubSub = false,
        SubSubIndex = 1,
        CurrentFOV = 90,

        -- États de l'Update Checker autonome
        UpdateState = "checking",
        UpdateChoice = 1,
        UpdateAnimAlpha = 255,
        UpdateAnimY = 0,
        UpdateCheckedTime = 0,
        CheckStartTime = nil
    }

    MYMENU_ERRORS = MYMENU_ERRORS or {}

    MYMENU_SETTINGS = MYMENU_SETTINGS or {
        ["UI Option A"] = false,
        ["UI Option B"] = false,
        ["UI Option C"] = false
    }

    local menus = {
        MAIN = {"UI OPTIONS", "QUICK COMMANDS", "MENU UI CONFIG", "ERROR LOGS", "MISC"},
        ["UI OPTIONS"] = {"UI Option A", "UI Option B", "UI Option C"},
        ["MENU UI CONFIG"] = {}, 
        ["MISC"] = {"Check Updates"}, 
        ["QUICK COMMANDS"] = {
            "gmod_mcore_test", "mat_queue_mode", "cl_showfps", "r_cleardecals",
            "cl_cmdrate", "cl_updaterate", "hud_saytext_time", "cl_drawhud",
            "mat_specular", "cl_ragdoll_collide", "gmod_admin_cleanup", "snd_restart",
            "disconnect", "retry"
        }
    }

    local binaryCommands = {
        ["gmod_mcore_test"] = true, ["mat_queue_mode"] = true, ["cl_showfps"] = true,
        ["hud_saytext_time"] = true, ["cl_drawhud"] = true, ["mat_specular"] = true,
        ["cl_ragdoll_collide"] = true
    }

    -- =============================================================
    -- 2. LOGIQUE DU SYSTEME HTTP D'UPDATE
    -- =============================================================
    local CURRENT_VERSION = "1.0.0"
    local VERSION_URL = "https://raw.githubusercontent.com/TonPseudo/TonRepo/main/version.txt" 

    local function TriggerUpdateCheck()
        MYMENU.UpdateState = "checking"
        MYMENU.UpdateAnimAlpha = 255
        MYMENU.UpdateAnimY = 0
        MYMENU.UpdateChoice = 1
        MYMENU.CheckStartTime = CurTime()
        MYMENU.UpdateCheckedTime = CurTime() + 1.5

        http.Fetch(VERSION_URL, 
            function(body)
                local latestVersion = string.trim(body)
                timer.Simple(math.max(0, MYMENU.UpdateCheckedTime - CurTime()), function()
                    if MYMENU.UpdateState == "checking" then
                        if latestVersion and latestVersion ~= "" and latestVersion ~= CURRENT_VERSION then
                            MYMENU.UpdateState = "prompt"
                        else
                            MYMENU.UpdateState = "uptodate"
                        end
                    end
                end)
            end,
            function(error)
                -- Géré automatiquement par le timeout dans HUDPaint
            end
        )
    end

    -- Lancement automatique de la vérification initiale
    TriggerUpdateCheck()

    -- Catcher de logs d'erreurs Lua
    hook.Add("OnLuaError", "TerminalInspector_ErrorCatcher", function(str, realm, stack, addrow)
        local shortErr = string.Split(str, "\n")[1] or str
        table.insert(MYMENU_ERRORS, 1, { msg = shortErr, time = os.date("%H:%M:%S") })
        if #MYMENU_ERRORS > 50 then table.remove(MYMENU_ERRORS) end
    end)

    -- Configuration des polices et couleurs
    surface.CreateFont("TerminalTitleFont", { font = "Roboto", size = 26, weight = 800, extended = true })
    surface.CreateFont("TerminalMenuFont", { font = "Roboto", size = 16, weight = 700, extended = true })
    surface.CreateFont("TerminalSubFont", { font = "ConsoleFont", size = 11, weight = 600, extended = true })

    local menuBlue = Color(0, 160, 255)
    local bgBlue = Color(10, 16, 22, 245)

    -- Effet de Scanlines CRT
    local function DrawCRTScanlines(x, y, w, h, alpha)
        surface.SetDrawColor(0, 0, 0, alpha * 0.45)
        for i = 0, h, 4 do
            surface.DrawRect(x, y + i + (math.floor(CurTime() * 12) % 4), w, 1)
        end
    end

    -- Effet de Bruit Blanc Dense Flash
    local function DrawDenseWhiteNoise(x, y, w, h, startTime, duration, inverse)
        local timePassed = CurTime() - startTime
        if timePassed >= duration or timePassed < 0 then return end

        local progress = timePassed / duration
        local noiseAlpha = inverse and math.Clamp(progress * 255, 0, 255) or math.Clamp((1 - progress) * 255, 0, 255)

        render.SetScissorRect(x, y, x + w, y + h, true)
            local blockSize = 4 
            for bx = 0, w, blockSize do
                for by = 0, h, blockSize do
                    if math.random(1, 100) > 30 then
                        local grey = math.random(150, 255)
                        surface.SetDrawColor(grey, grey, grey, noiseAlpha)
                        surface.DrawRect(x + bx, y + by, blockSize, blockSize)
                    end
                end
            end
        render.SetScissorRect(0, 0, 0, 0, false)
    end

    -- Bordure arrondie optimisée
    local function DrawPerfectRoundedOutline(x, y, w, h, radius, color)
        surface.SetDrawColor(color.r, color.g, color.b, color.a)
        surface.DrawRect(x + radius, y, w - (radius * 2), 2)
        surface.DrawRect(x + radius, y + h - 2, w - (radius * 2), 2)
        surface.DrawRect(x, y + radius, 2, h - (radius * 2))
        surface.DrawRect(x + w - 2, y + radius, 2, h - (radius * 2))

        local steps = 8
        local corners = {
            {x + radius, y + radius, 180},
            {x + w - radius, y + radius, 270},
            {x + w - radius, y + h - radius, 0},
            {x + radius, y + h - radius, 90}
        }

        for _, corner in ipairs(corners) do
            local cx, cy, startAngle = corner[1], corner[2], corner[3]
            local lastX, lastY = nil, nil
            for i = 0, steps do
                local ang = math.rad(startAngle + (i / steps) * 90)
                local px = cx + math.cos(ang) * radius
                local py = cy + math.sin(ang) * radius
                if lastX and lastY then surface.DrawLine(lastX, lastY, px, py) surface.DrawLine(lastX, lastY + 1, px, py + 1) end
                lastX, lastY = px, py
            end
        end
    end

    -- =============================================================
    -- 3. RENDU VISUEL UNIFIÉ (HUDPaint)
    -- =============================================================
    hook.Add("HUDPaint", "TerminalInspector_Draw", function()
        local radius = 12 

        -----------------------------------------------------
        -- DEBUT DESSIN POPUP UPDATE CHECKER WIDE SCREEN --
        -----------------------------------------------------
        if not (MYMENU.UpdateState == "uptodate" and MYMENU.UpdateAnimAlpha <= 0) then
            if MYMENU.UpdateState == "uptodate" then
                MYMENU.UpdateAnimAlpha = Lerp(FrameTime() * 6, MYMENU.UpdateAnimAlpha, 0)
                MYMENU.UpdateAnimY = Lerp(FrameTime() * 6, MYMENU.UpdateAnimY, 120)
            end

            local alpha = MYMENU.UpdateAnimAlpha
            local frameW, frameH = 500, 250
            local frameX = (ScrW() - frameW) / 2
            local frameY = ((ScrH() - frameH) / 2) + MYMENU.UpdateAnimY

            local localBg = Color(10, 16, 22, alpha * 0.96)
            local localBlue = Color(menuBlue.r, menuBlue.g, menuBlue.b, alpha)

            draw.RoundedBox(radius, frameX, frameY, frameW, frameH, localBg)
            DrawPerfectRoundedOutline(frameX, frameY, frameW, frameH, radius, localBlue)
            DrawCRTScanlines(frameX, frameY, frameW, frameH, alpha)

            if MYMENU.UpdateState == "checking" then
                draw.SimpleText("CHECKING FOR UPDATES...", "TerminalTitleFont", frameX + (frameW / 2), frameY + 50, localBlue, 1, 1)
                
                if MYMENU.CheckStartTime and (CurTime() - MYMENU.CheckStartTime >= 5) then
                    MYMENU.UpdateState = "error"
                    MYMENU.UpdateChoice = 1 
                    MYMENU.CheckStartTime = nil
                end

                local centerX, centerY = frameX + (frameW / 2), frameY + 140
                local radiusOuter = 24
                local radiusInner = 18
                local rotationSpeed = CurTime() * 250 
                
                surface.SetDrawColor(menuBlue.r, menuBlue.g, menuBlue.b, alpha)
                local segments = 24
                local missingSegments = 3
                for i = 0, (segments - missingSegments) do
                    local angle1 = math.rad((i / segments) * 360 + rotationSpeed)
                    local angle2 = math.rad(((i + 1) / segments) * 360 + rotationSpeed)
                    local p1x, p1y = centerX + math.cos(angle1) * radiusInner, centerY + math.sin(angle1) * radiusInner
                    local p2x, p2y = centerX + math.cos(angle1) * radiusOuter, centerY + math.sin(angle1) * radiusOuter
                    local p3x, p3y = centerX + math.cos(angle2) * radiusOuter, centerY + math.sin(angle2) * radiusOuter
                    local p4x, p4y = centerX + math.cos(angle2) * radiusInner, centerY + math.sin(angle2) * radiusInner
                    
                    surface.DrawPoly({
                        { x = p1x, y = p1y },
                        { x = p2x, y = p2y },
                        { x = p3x, y = p3y },
                        { x = p4x, y = p4y }
                    })
                end

            elseif MYMENU.UpdateState == "error" then
                draw.SimpleText("UPDATE CHECK FAILED!", "TerminalTitleFont", frameX + (frameW / 2), frameY + 40, Color(255, 50, 50, alpha), 1, 1)
                draw.SimpleText("Unable to connect to Github. Retry search?", "TerminalMenuFont", frameX + (frameW / 2), frameY + 80, Color(200, 200, 200, alpha), 1, 1)

                local rSelected = MYMENU.UpdateChoice == 1
                local colRetry = rSelected and Color(255, 255, 255, alpha) or Color(150, 90, 90, alpha)
                local prefixRetry = rSelected and "> RETRY" or "RETRY"
                if rSelected then draw.RoundedBox(4, frameX + 50, frameY + 120, frameW - 100, 30, Color(255, 50, 50, 35 * (alpha/255))) end
                draw.SimpleText(prefixRetry, "TerminalMenuFont", frameX + 70, frameY + 125, colRetry, 0, 0)

                local nSelected = MYMENU.UpdateChoice == 2
                local colNo = nSelected and Color(255, 255, 255, alpha) or Color(150, 90, 90, alpha)
                local prefixNo = nSelected and "> NO" or "NO"
                if nSelected then draw.RoundedBox(4, frameX + 50, frameY + 160, frameW - 100, 30, Color(255, 50, 50, 35 * (alpha/255))) end
                draw.SimpleText(prefixNo, "TerminalMenuFont", frameX + 70, frameY + 165, colNo, 0, 0)
                
                draw.SimpleText("Press ENTER to confirm", "TerminalSubFont", frameX + (frameW / 2), frameY + frameH - 20, Color(150, 90, 90, alpha * 0.7), 1, 1)

            elseif MYMENU.UpdateState == "prompt" then
                draw.SimpleText("A NEW UPDATE IS AVAILABLE!", "TerminalTitleFont", frameX + (frameW / 2), frameY + 40, Color(255, 70, 70, alpha), 1, 1)
                draw.SimpleText("Do you want to update the mod?", "TerminalMenuFont", frameX + (frameW / 2), frameY + 80, Color(255, 255, 255, alpha), 1, 1)

                local ySelected = MYMENU.UpdateChoice == 1
                local colYes = ySelected and Color(255, 255, 255, alpha) or Color(90, 125, 150, alpha)
                local prefixYes = ySelected and "> YES" or "YES"
                if ySelected then draw.RoundedBox(4, frameX + 50, frameY + 120, frameW - 100, 30, Color(0, 160, 255, 45 * (alpha/255))) end
                draw.SimpleText(prefixYes, "TerminalMenuFont", frameX + 70, frameY + 125, colYes, 0, 0)

                local nSelected = MYMENU.UpdateChoice == 2
                local colNo = nSelected and Color(255, 255, 255, alpha) or Color(90, 125, 150, alpha)
                local prefixNo = nSelected and "> NO" or "NO"
                if nSelected then draw.RoundedBox(4, frameX + 50, frameY + 160, frameW - 100, 30, Color(0, 160, 255, 45 * (alpha/255))) end
                draw.SimpleText(prefixNo, "TerminalMenuFont", frameX + 70, frameY + 165, colNo, 0, 0)
                
                draw.SimpleText("Press ENTER to confirm", "TerminalSubFont", frameX + (frameW / 2), frameY + frameH - 20, Color(90, 125, 150, alpha * 0.7), 1, 1)
            end
            return 
        end

        if not MYMENU.Active then return end

        local FT = FrameTime()
        local w, h = 290, 380
        local maxVisibleItems = 8

        MYMENU.MenuX = Lerp(FT * 18, MYMENU.MenuX, MYMENU.TargetMenuX)
        MYMENU.SubMenuOffset = Lerp(FT * 18, MYMENU.SubMenuOffset, MYMENU.TargetOffset)

        local globalAlpha = 255
        if MYMENU.Closing then
            local progress = math.Clamp((CurTime() - MYMENU.CloseNoiseStart) / MYMENU.NoiseDuration, 0, 1)
            globalAlpha = (1 - progress) * 255
            if progress >= 1 then MYMENU.Active = false MYMENU.Closing = false return end
        end

        local adjMenuBlue = Color(menuBlue.r, menuBlue.g, menuBlue.b, globalAlpha)
        local adjBgBlue = Color(bgBlue.r, bgBlue.g, bgBlue.b, (bgBlue.a / 255) * globalAlpha)

        -----------------------------------------
        -- PANEL 1: MENU PRINCIPAL
        -----------------------------------------
        draw.RoundedBox(radius, MYMENU.MenuX, MYMENU.MenuY, w, h, adjBgBlue)
        DrawPerfectRoundedOutline(MYMENU.MenuX, MYMENU.MenuY, w, h, radius, adjMenuBlue)
        DrawCRTScanlines(MYMENU.MenuX, MYMENU.MenuY, w, h, globalAlpha)

        if MYMENU.Closing then 
            DrawDenseWhiteNoise(MYMENU.MenuX, MYMENU.MenuY, w, h, MYMENU.CloseNoiseStart, MYMENU.NoiseDuration, true)
        else
            DrawDenseWhiteNoise(MYMENU.MenuX, MYMENU.MenuY, w, h, MYMENU.MainMenuNoiseStart, MYMENU.NoiseDuration, false)
        end

        surface.SetFont("TerminalTitleFont")
        local elapsedMain = CurTime() - MYMENU.MenuOpenTime
        local charsMain = math.Clamp(math.floor(elapsedMain / MYMENU.TypeSpeed) + 1, 1, string.len(MYMENU.FullTitle))
        local currentSubTitle = string.sub(MYMENU.FullTitle, 1, charsMain)
        
        local tW, _ = surface.GetTextSize(currentSubTitle)
        draw.SimpleText(currentSubTitle, "TerminalTitleFont", MYMENU.MenuX + 15, MYMENU.MenuY + 12, adjMenuBlue, 0, 0)
        
        local cursorAlpha = math.abs(math.sin(CurTime() * 5)) * globalAlpha
        draw.SimpleText("_", "TerminalTitleFont", MYMENU.MenuX + 15 + tW, MYMENU.MenuY + 12, Color(menuBlue.r, menuBlue.g, menuBlue.b, cursorAlpha), 0, 0)

        draw.RoundedBox(0, MYMENU.MenuX + 10, MYMENU.MenuY + 45, w - 20, 1, Color(menuBlue.r, menuBlue.g, menuBlue.b, 50 * (globalAlpha/255)))

        local versionMod = "v1.0.0"
        local rC = math.sin(CurTime() * 2) * 127 + 128
        local gC = math.sin(CurTime() * 2 + 2) * 127 + 128
        local bC = math.sin(CurTime() * 2 + 4) * 127 + 128
        draw.SimpleText(versionMod, "DermaDefault", MYMENU.MenuX + 15, MYMENU.MenuY + h - 22, Color(rC, gC, bC, 240 * (globalAlpha/255)), 0, 0)

        for i, opt in ipairs(menus["MAIN"]) do
            local itemY = MYMENU.MenuY + 60 + ((i - 1) * 38)
            local isCurrentOrPrevious = (MYMENU.CurrentMenu == opt or (MYMENU.SubClosing and MYMENU.PreviousMenu == opt))
            
            if isCurrentOrPrevious then
                local arrowBounce = math.sin(CurTime() * 8) * 3
                surface.SetFont("TerminalMenuFont")
                
                local arrowText = "> "
                local categoryText = opt
                local currentX = MYMENU.MenuX + 35 + arrowBounce
                local speed = 120
                local spread = 15

                for j = 1, string.len(arrowText) do
                    local char = string.sub(arrowText, j, j)
                    local hue = (CurTime() * speed - (j * spread)) % 360
                    local rgbColor = HSVToColor(hue, 1, 1)
                    rgbColor.a = globalAlpha
                    draw.SimpleText(char, "TerminalMenuFont", currentX, itemY + 6, rgbColor, 0, 0)
                    local charW, _ = surface.GetTextSize(char)
                    currentX = currentX + charW
                end
                
                currentX = MYMENU.MenuX + 55
                for j = 1, string.len(categoryText) do
                    local char = string.sub(categoryText, j, j)
                    local hue = (CurTime() * speed - ((j + 2) * spread)) % 360
                    local rgbColor = HSVToColor(hue, 1, 1)
                    rgbColor.a = globalAlpha
                    draw.SimpleText(char, "TerminalMenuFont", currentX, itemY + 6, rgbColor, 0, 0)
                    local charW, _ = surface.GetTextSize(char)
                    currentX = currentX + charW
                end
            else
                if MYMENU.CurrentMenu == "MAIN" and MYMENU.Index == i then
                    draw.RoundedBox(4, MYMENU.MenuX + 8, itemY, w - 16, 32, Color(0, 160, 255, 45 * (globalAlpha/255)))
                    draw.SimpleText(opt, "TerminalMenuFont", MYMENU.MenuX + 15, itemY + 6, Color(255, 255, 255, globalAlpha), 0, 0)
                else
                    local optCol = Color(90, 125, 150, globalAlpha)
                    draw.SimpleText(opt, "TerminalMenuFont", MYMENU.MenuX + 15, itemY + 6, optCol, 0, 0)
                end
            end
        end

        -----------------------------------------
        -- PANEL 2: CONTENU DES ONGLETS (SUB)
        -----------------------------------------
        if MYMENU.CurrentMenu ~= "MAIN" or MYMENU.SubClosing then
            local subX = MYMENU.MenuX + MYMENU.SubMenuOffset
            local activeAlpha = 255
            
            if MYMENU.SubClosing then
                local progress = math.Clamp((CurTime() - MYMENU.SubCloseNoiseStart) / MYMENU.NoiseDuration, 0, 1)
                activeAlpha = (1 - progress) * 255
                if progress >= 1 then MYMENU.SubClosing = false MYMENU.CurrentMenu = "MAIN" end
            else
                activeAlpha = math.Clamp((MYMENU.SubMenuOffset / 305) * 255, 0, 255)
            end

            activeAlpha = (activeAlpha / 255) * globalAlpha
            local subAdjBlue = Color(menuBlue.r, menuBlue.g, menuBlue.b, activeAlpha)
            local subAdjBg = Color(bgBlue.r, bgBlue.g, bgBlue.b, (bgBlue.a / 255) * activeAlpha)

            draw.RoundedBox(radius, subX, MYMENU.MenuY, w, h, subAdjBg)
            DrawPerfectRoundedOutline(subX, MYMENU.MenuY, w, h, radius, subAdjBlue)
            DrawCRTScanlines(subX, MYMENU.MenuY, w, h, activeAlpha)

            if MYMENU.SubClosing then
                DrawDenseWhiteNoise(subX, MYMENU.MenuY, w, h, MYMENU.SubCloseNoiseStart, MYMENU.NoiseDuration, true)
            else
                DrawDenseWhiteNoise(subX, MYMENU.MenuY, w, h, MYMENU.SubMenuNoiseStart, MYMENU.NoiseDuration, false)
            end

            local activeTitle = MYMENU.SubClosing and MYMENU.PreviousMenu or MYMENU.CurrentMenu
            local elapsedSub = CurTime() - MYMENU.SubMenuOpenTime
            local charsSub = math.Clamp(math.floor(elapsedSub / MYMENU.TypeSpeed) + 1, 1, string.len(activeTitle))
            local currentSubMenuTitle = string.sub(activeTitle, 1, charsSub)
            
            draw.SimpleText(currentSubMenuTitle, "TerminalTitleFont", subX + 15, MYMENU.MenuY + 12, subAdjBlue, 0, 0)
            draw.RoundedBox(0, subX + 10, MYMENU.MenuY + 45, w - 20, 1, Color(menuBlue.r, menuBlue.g, menuBlue.b, 50 * (activeAlpha / 255)))

            if activeTitle == "ERROR LOGS" then
                local totalErrors = #MYMENU_ERRORS
                if totalErrors == 0 then
                    draw.SimpleText("No system errors detected.", "TerminalMenuFont", subX + 15, MYMENU.MenuY + 60, Color(90, 125, 150, activeAlpha), 0, 0)
                else
                    local startLoop = MYMENU.ScrollIndex
                    local endLoop = math.min(startLoop + maxVisibleItems - 1, totalErrors)
                    for i = startLoop, endLoop do
                        local err = MYMENU_ERRORS[i]
                        if not err then break end
                        local itemY = MYMENU.MenuY + 60 + ((i - startLoop) * 38)
                        local displayText = "[" .. err.time .. "] " .. err.msg
                        if string.len(displayText) > 26 then displayText = string.sub(displayText, 1, 24) .. "..." end

                        if MYMENU.Index == i and not MYMENU.SubClosing then
                            draw.RoundedBox(4, subX + 8, itemY, w - 16, 32, Color(255, 50, 50, 40 * (activeAlpha / 255)))
                            draw.SimpleText("> " .. displayText, "TerminalMenuFont", subX + 15, itemY + 6, Color(255, 255, 255, activeAlpha), 0, 0)
                        else
                            draw.SimpleText(displayText, "TerminalMenuFont", subX + 15, itemY + 6, Color(200, 70, 70, activeAlpha), 0, 0)
                        end
                    end
                end
            elseif activeTitle == "MENU UI CONFIG" then
                draw.SimpleText("Empty category.", "TerminalMenuFont", subX + 15, MYMENU.MenuY + 60, Color(90, 125, 150, activeAlpha), 0, 0)
            else
                local subOptions = menus[activeTitle] or {}
                local startLoop = MYMENU.ScrollIndex
                local endLoop = math.min(startLoop + maxVisibleItems - 1, #subOptions)

                for i = startLoop, endLoop do
                    local opt = subOptions[i]
                    if not opt then break end
                    local itemY = MYMENU.MenuY + 60 + ((i - startLoop) * 38)

                    local extraText = ""
                    local extraColor = Color(0, 200, 255, activeAlpha)

                    if activeTitle == "UI OPTIONS" then
                        extraText = MYMENU_SETTINGS[opt] and "[ON]" or "[OFF]"
                        extraColor = MYMENU_SETTINGS[opt] and Color(0, 255, 60, activeAlpha) or Color(255, 60, 60, activeAlpha)
                    elseif activeTitle == "QUICK COMMANDS" then
                        extraText = binaryCommands[opt] and ">" or "[EXE]"
                        if binaryCommands[opt] then extraColor = subAdjBlue end
                    elseif activeTitle == "MISC" then
                        extraText = "[EXE]"
                    end

                    if MYMENU.Index == i and not MYMENU.SubClosing then
                        draw.RoundedBox(4, subX + 8, itemY, w - 16, 32, Color(0, 160, 255, 35 * (activeAlpha / 255)))
                        local formattedName = (extraText == ">") and (opt .. " >") or opt
                        draw.SimpleText("> " .. formattedName, "TerminalMenuFont", subX + 15, itemY + 6, Color(255, 255, 255, activeAlpha), 0, 0)
                    else
                        local formattedName = (extraText == ">") and (opt .. " >") or opt
                        draw.SimpleText(formattedName, "TerminalMenuFont", subX + 15, itemY + 6, Color(90, 125, 150, activeAlpha), 0, 0)
                    end
                    
                    if extraText ~= ">" then
                        draw.SimpleText(extraText, "TerminalMenuFont", subX + w - 55, itemY + 6, extraColor, 0, 0)
                    end
                end
            end
        else
            if not MYMENU.Closing then MYMENU.TargetOffset = 0 end
        end

        -----------------------------------------
        -- PANEL 3: POPUP CONTEXTUEL (SUB-SUB)
        -----------------------------------------
        if MYMENU.InSubSub and MYMENU.SubMenuOffset > 250 and not MYMENU.SubClosing then
            local subX = MYMENU.MenuX + MYMENU.SubMenuOffset
            local subSubX = subX + w + 8 

            if MYMENU.CurrentMenu == "ERROR LOGS" then
                local subSubW, subSubH = 340, 260
                draw.RoundedBox(radius, subSubX, MYMENU.MenuY, subSubW, subSubH, Color(20, 12, 12, 245 * (globalAlpha / 255)))
                DrawPerfectRoundedOutline(subSubX, MYMENU.MenuY, subSubW, subSubH, radius, Color(255, 50, 50, globalAlpha))
                draw.SimpleText("Terminal Inspector", "TerminalTitleFont", subSubX + 15, MYMENU.MenuY + 12, Color(255, 50, 50, globalAlpha), 0, 0)

                local selectedError = MYMENU_ERRORS[MYMENU.Index]
                if selectedError then
                    local lines = {}
                    local rawText = selectedError.msg
                    for i = 1, string.len(rawText), 45 do table.insert(lines, string.sub(rawText, i, i + 44)) end
                    for k, lineText in ipairs(lines) do
                        local lineY = MYMENU.MenuY + 60 + ((k - 1) * 20)
                        draw.SimpleText(lineText, "TerminalSubFont", subSubX + 15, lineY, Color(255, 100, 100, globalAlpha), 0, 0)
                    end
                end

            elseif MYMENU.CurrentMenu == "QUICK COMMANDS" then
                local visualIndex = MYMENU.Index - MYMENU.ScrollIndex
                local targetDropdownY = MYMENU.MenuY + 60 + (visualIndex * 38)

                local dropdownW, dropdownH = 160, 68
                draw.RoundedBox(6, subSubX, targetDropdownY, dropdownW, dropdownH, adjBgBlue)
                DrawPerfectRoundedOutline(subSubX, targetDropdownY, dropdownW, dropdownH, 6, adjMenuBlue)

                local currentCmd = menus["QUICK COMMANDS"][MYMENU.Index] or "cmd"

                if MYMENU.SubSubIndex == 1 then
                    draw.RoundedBox(4, subSubX + 5, targetDropdownY + 5, dropdownW - 10, 26, Color(0, 160, 255, 45 * (globalAlpha / 255)))
                    draw.SimpleText("> " .. currentCmd .. " 1", "TerminalSubFont", subSubX + 10, targetDropdownY + 12, Color(255, 255, 255, globalAlpha), 0, 0)
                    draw.SimpleText(currentCmd .. " 0", "TerminalSubFont", subSubX + 10, targetDropdownY + 42, Color(90, 125, 150, globalAlpha), 0, 0)
                else
                    draw.RoundedBox(4, subSubX + 5, targetDropdownY + 35, dropdownW - 10, 26, Color(0, 160, 255, 45 * (globalAlpha / 255)))
                    draw.SimpleText(currentCmd .. " 1", "TerminalSubFont", subSubX + 10, targetDropdownY + 12, Color(90, 125, 150, globalAlpha), 0, 0)
                    draw.SimpleText("> " .. currentCmd .. " 0", "TerminalSubFont", subSubX + 10, targetDropdownY + 42, Color(255, 255, 255, globalAlpha), 0, 0)
                end
            end
        end
    end)
-- =============================================================
    -- 4. ENTRÉES ET NAVIGATION CLAVIER ULTRA-STABLE (CORRIGÉ)
    -- =============================================================
    local actionKey = false
    hook.Add("CreateMove", "TerminalInspector_Input", function(cmd)
        local pR = input.IsKeyDown(KEY_RIGHT)
        local pU = input.IsKeyDown(KEY_UP)
        local pD = input.IsKeyDown(KEY_DOWN)
        local pL = input.IsKeyDown(KEY_LEFT)
        local pEnter = input.IsKeyDown(KEY_ENTER)

        -- Anti-spam : Si aucune touche n'est pressée, on libère le verrou
        if not pR and not pU and not pD and not pL and not pEnter then actionKey = false return end
        if actionKey then return end 

        -------------------------------------------------------------
        -- 1. PRIORITÉ VISUELLE : GESTION DE L'UPDATE CHECKER (SI AFFICHÉ)
        -------------------------------------------------------------
        -- On ne bloque les touches QUE si l'animation de l'update est visible à l'écran (Alpha > 0)
        if not (MYMENU.UpdateState == "uptodate" and MYMENU.UpdateAnimAlpha <= 0) then
            
            if MYMENU.UpdateState == "checking" then
                return -- On bloque temporairement pendant le chargement initial
            end

            if MYMENU.UpdateState == "prompt" or MYMENU.UpdateState == "error" then
                if pU then
                    actionKey = true
                    MYMENU.UpdateChoice = 1
                    surface.PlaySound("common/talk.wav")
                elseif pD then
                    actionKey = true
                    MYMENU.UpdateChoice = 2
                    surface.PlaySound("common/talk.wav")
                elseif pEnter or pR then
                    actionKey = true
                    surface.PlaySound("ui/buttonclick.wav")
                    if MYMENU.UpdateState == "error" then
                        if MYMENU.UpdateChoice == 1 then
                            TriggerUpdateCheck()
                        else
                            -- Si l'utilisateur fait "NO" sur l'erreur, on force l'état pour libérer le menu
                            MYMENU.UpdateState = "uptodate"
                            MYMENU.UpdateAnimAlpha = 0
                        end
                    elseif MYMENU.UpdateState == "prompt" then
                        if MYMENU.UpdateChoice == 1 then
                            gui.OpenURL("https://github.com/TonPseudo/TonRepo") 
                        end
                        MYMENU.UpdateState = "uptodate"
                    end
                end
                return -- On s'arrête ici SEULEMENT si la popup d'update est à l'écran
            end
        end

        -------------------------------------------------------------
        -- 2. GESTION STANDARD DU MENU PRINCIPAL
        -------------------------------------------------------------
        if MYMENU.Active and MYMENU.Closing then return end

        -- Ouverture du menu via Flèche Droite
        if not MYMENU.Active then
            if pR then
                MYMENU.Active = true 
                MYMENU.Closing = false 
                MYMENU.CurrentMenu = "MAIN" 
                MYMENU.Index = 1 
                MYMENU.ScrollIndex = 1
                MYMENU.MenuX = -350 
                MYMENU.TargetMenuX = 15 
                MYMENU.TargetOffset = 0 
                MYMENU.SubMenuOffset = -350
                MYMENU.MainMenuNoiseStart = CurTime() 
                MYMENU.MenuOpenTime = CurTime()
                MYMENU.InSubSub = false
                surface.PlaySound("ui/buttonclick.wav")
                actionKey = true
            end
            return
        end

        local currentMenuOptions = (MYMENU.CurrentMenu == "MAIN") and menus["MAIN"] or (menus[MYMENU.CurrentMenu] or MYMENU_ERRORS)
        local maxVisibleItems = 8

        -- Navigation Haut
        if pU then
            actionKey = true
            surface.PlaySound("common/talk.wav")
            if MYMENU.InSubSub and MYMENU.CurrentMenu == "QUICK COMMANDS" then
                MYMENU.SubSubIndex = (MYMENU.SubSubIndex == 1) and 2 or 1
            elseif not MYMENU.InSubSub then
                MYMENU.Index = MYMENU.Index - 1
                if MYMENU.Index < 1 then 
                    MYMENU.Index = #currentMenuOptions
                    MYMENU.ScrollIndex = math.max(1, #currentMenuOptions - maxVisibleItems + 1)
                elseif MYMENU.Index < MYMENU.ScrollIndex then
                    MYMENU.ScrollIndex = MYMENU.Index
                end
            end
        end

        -- Navigation Bas
        if pD then
            actionKey = true
            surface.PlaySound("common/talk.wav")
            if MYMENU.InSubSub and MYMENU.CurrentMenu == "QUICK COMMANDS" then
                MYMENU.SubSubIndex = (MYMENU.SubSubIndex == 1) and 2 or 1
            elseif not MYMENU.InSubSub then
                MYMENU.Index = MYMENU.Index + 1
                if MYMENU.Index > #currentMenuOptions then
                    MYMENU.Index = 1
                    MYMENU.ScrollIndex = 1
                elseif MYMENU.Index > (MYMENU.ScrollIndex + maxVisibleItems - 1) then
                    MYMENU.ScrollIndex = MYMENU.ScrollIndex + 1
                end
            end
        end

        -- Validation / Entrée dans un sous-menu (Droite ou Enter)
        if pR or pEnter then
            actionKey = true
            if MYMENU.CurrentMenu == "MAIN" then
                local selectedCategory = menus["MAIN"][MYMENU.Index]
                if selectedCategory then
                    surface.PlaySound("ui/buttonclick.wav")
                    MYMENU.CurrentMenu = selectedCategory
                    MYMENU.PreviousMenu = "MAIN"
                    MYMENU.Index = 1
                    MYMENU.ScrollIndex = 1
                    MYMENU.TargetOffset = 305
                    MYMENU.SubMenuNoiseStart = CurTime()
                    MYMENU.SubMenuOpenTime = CurTime()
                    MYMENU.InSubSub = false
                end
            else
                if MYMENU.CurrentMenu == "UI OPTIONS" then
                    local options = menus["UI OPTIONS"]
                    local currentOpt = options[MYMENU.Index]
                    if currentOpt then
                        surface.PlaySound("ui/buttonclick.wav")
                        MYMENU_SETTINGS[currentOpt] = not MYMENU_SETTINGS[currentOpt]
                    end
                elseif MYMENU.CurrentMenu == "QUICK COMMANDS" then
                    local cmdName = menus["QUICK COMMANDS"][MYMENU.Index]
                    if cmdName then
                        if binaryCommands[cmdName] then
                            if not MYMENU.InSubSub then
                                surface.PlaySound("ui/buttonclick.wav")
                                MYMENU.InSubSub = true
                                MYMENU.SubSubIndex = 1
                            else
                                surface.PlaySound("ui/buttonclick.wav")
                                local state = (MYMENU.SubSubIndex == 1) and 1 or 0
                                LocalPlayer():ConCommand(cmdName .. " " .. state)
                                MYMENU.InSubSub = false
                            end
                        else
                            surface.PlaySound("ui/buttonclick.wav")
                            LocalPlayer():ConCommand(cmdName)
                        end
                    end
                elseif MYMENU.CurrentMenu == "ERROR LOGS" then
                    if #MYMENU_ERRORS > 0 then
                        surface.PlaySound("ui/buttonclick.wav")
                        MYMENU.InSubSub = not MYMENU.InSubSub
                    end
                elseif MYMENU.CurrentMenu == "MISC" then
                    local opt = menus["MISC"][MYMENU.Index]
                    if opt == "Check Updates" then
                        surface.PlaySound("ui/buttonclick.wav")
                        TriggerUpdateCheck()
                    end
                end
            end
        end

        -- Retour / Fermeture (Gauche)
        if pL then
            actionKey = true
            if MYMENU.InSubSub then
                surface.PlaySound("ui/buttonclick.wav")
                MYMENU.InSubSub = false
            elseif MYMENU.CurrentMenu ~= "MAIN" then
                surface.PlaySound("ui/buttonclick.wav")
                MYMENU.SubClosing = true
                MYMENU.PreviousMenu = MYMENU.CurrentMenu
                MYMENU.CurrentMenu = "MAIN"
                MYMENU.TargetOffset = 0
                MYMENU.SubCloseNoiseStart = CurTime()
                
                for idx, catName in ipairs(menus["MAIN"]) do
                    if catName == MYMENU.PreviousMenu then
                        MYMENU.Index = idx
                        break
                    end
                end
                MYMENU.ScrollIndex = 1
            else
                surface.PlaySound("ui/buttonclick.wav")
                MYMENU.Closing = true
                MYMENU.CloseNoiseStart = CurTime()
            end
        end
    end)
end