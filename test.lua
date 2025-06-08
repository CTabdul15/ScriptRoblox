-- ######################################################################
-- ## Visuelles Diagnose-Skript (Keine Konsole benötigt)               ##
-- ## Zeigt den Status und Fehler in einer GUI auf dem Bildschirm an.   ##
-- ######################################################################

-- Erstelle eine Funktion, um die Nachricht auf dem Bildschirm zu aktualisieren
local statusLabel = nil
local function createStatusGui()
    if statusLabel and statusLabel.Parent then return end -- GUI bereits vorhanden

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "VisualDebug"
    screenGui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.Position = UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 1, 0)
    statusLabel.Position = UDim2.new(0, 10, 0, 0)
    statusLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.SourceSansBold
    statusLabel.TextSize = 16
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Text = "Diagnose-Tool gestartet..."
    statusLabel.Parent = frame
    
    screenGui.Parent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

-- Funktion zum Aktualisieren des Textes
local function updateStatus(message)
    if not statusLabel or not statusLabel.Parent then
        createStatusGui()
    end
    print(message) -- Für den Fall, dass doch eine Konsole existiert
    statusLabel.Text = tostring(message)
end

-- Führe den Ladevorgang in einem geschützten Aufruf aus, um Fehler abzufangen
local success, result = pcall(function()
    updateStatus("Versuche, Skript herunterzuladen...")
    
    local url = "https://raw.githubusercontent.com/CTabdul15/ScriptRoblox/script/client_side"
    local raw_script = game:HttpGet(url)
    
    updateStatus("Download abgeschlossen. Grösse: " .. #raw_script .. " Zeichen.")
    
    if #raw_script < 100 or raw_script:find("404: Not Found") then
        updateStatus("FEHLER: Download fehlgeschlagen! Datei nicht gefunden (404) oder leer.")
        wait(10) -- Warte 10 Sekunden, damit die Nachricht gelesen werden kann
        return
    end
    
    updateStatus("Skript wird ausgeführt...")
    local script_function = loadstring(raw_script)
    if typeof(script_function) ~= "function" then
        updateStatus("FEHLER: loadstring hat keine Funktion zurückgegeben. Möglicherweise Syntaxfehler im Skript.")
        wait(10)
        return
    end

    script_function()
    updateStatus("Erfolg! Skript wurde ohne Absturz ausgeführt. Die GUI sollte jetzt sichtbar sein.")
    wait(5)
    statusLabel.Parent.Parent:Destroy() -- Räume die Diagnose-GUI nach 5 Sekunden auf
end)

-- Wenn pcall einen Fehler abgefangen hat, zeige ihn an
if not success then
    updateStatus("SCRIPT ABSTURZ: " .. tostring(result))
end