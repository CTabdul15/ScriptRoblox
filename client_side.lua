-- Dieses LocalScript erstellt eine erweiterte, interaktive und verschiebbare UI.
-- Es ermöglicht das Erkunden von Spieler-Objekten, das clientseitige Manipulieren von Charakteren und das Anzeigen/Kopieren des eigenen Quellcodes.
-- Es enthält auch eine Einstellungs-Registerkarte, um einen Hotkey zum Ein-/Ausblenden der Benutzeroberfläche festzulegen.
-- Version 24: Code-Bereinigung zur Behebung von Syntaxfehlern durch unsichtbare Zeichen.
--
-- #################################################################################################
-- ## WICHTIGER HINWEIS ZUR FUNKTIONSWEISE:                                                       ##
-- ## Dieses LocalScript ist ein "LocalScript". Alle Aktionen (Freeze, Kill, etc.) auf andere Spieler  ##
-- ## sind NUR FÜR DICH SICHTBAR. Der Server und die anderen Spieler sind davon nicht betroffen.  ##
-- ## Dies ist eine Sicherheitsfunktion von Roblox, die nicht umgangen werden kann.              ##
-- #################################################################################################
--

print("CLIENT: Erweiterter Spieler-Explorer v24 (Code-Bereinigung) gestartet.")

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService") -- Nötig für das Anzeigen von Code

-- Lokaler Spieler
local localPlayer = Players.LocalPlayer

-- Zustandsspeicher für UI und Funktionen
local uiState = {} -- Speichert den Zustand (offen/geschlossen) von UI-Elementen
local playerFrames = {} -- Speichert die UI-Frames und Verbindungen für jeden Spieler
local playerFunctionStates = {} -- Speichert den Zustand von an/aus Funktionen für jeden Spieler

-- Globale Einstellungen
local toggleUiKey = Enum.KeyCode.RightShift -- Standard-Taste zum Ein-/Ausblenden der UI
local isBindingKey = false -- Verfolgt, ob wir auf eine Tasteneingabe für das Binding warten
local keybindButton = nil -- Referenz auf den Keybind-Button

-- #################### UI ERSTELLUNG (Basis) ####################
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerExplorer"
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

-- Haupt-Container-Frame (nicht scrollbar)
local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(0, 350, 0, 550)
mainContainer.Position = UDim2.new(0.5, -175, 0.5, -275)
mainContainer.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
mainContainer.BackgroundTransparency = 0.1
mainContainer.ClipsDescendants = true
mainContainer.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainContainer

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 80, 100)
stroke.Thickness = 1.5
stroke.Parent = mainContainer

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 48, 58)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 32, 38))
})
gradient.Rotation = 90
gradient.Parent = mainContainer

-- Titel-Leiste (bleibt oben fixiert)
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(60, 63, 75)
title.Text = "  Spieler-Explorer v24"
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Parent = mainContainer

-- ScrollingFrame für den Inhalt
local mainFrame = Instance.new("ScrollingFrame")
mainFrame.Name = "ScrollingContent"
mainFrame.Size = UDim2.new(1, 0, 1, -30)
mainFrame.Position = UDim2.new(0, 0, 0, 30)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
mainFrame.BackgroundTransparency = 1
mainFrame.BorderSizePixel = 0
mainFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
mainFrame.ScrollBarThickness = 6
mainFrame.Parent = mainContainer

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 22, 0, 22)
closeButton.Position = UDim2.new(1, -28, 0.5, -11)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeButton.Text = ""
closeButton.Parent = title

local closeIcon = Instance.new("TextLabel")
closeIcon.Size = UDim2.new(1, 0, 1, 0)
closeIcon.Text = "X"
closeIcon.BackgroundTransparency = 1
closeIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
closeIcon.Font = Enum.Font.GothamBold
closeIcon.TextSize = 14
closeIcon.Parent = closeButton

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- Hilfsfunktion für visuelles Feedback bei Klick
local function giveVisualFeedback(button, color)
    local originalColor = button.BackgroundColor3
    button.BackgroundColor3 = color or Color3.fromRGB(60, 180, 120)
    wait(0.5)
    button.BackgroundColor3 = originalColor
end

-- Funktion um den Skript-Source zu bekommen
local function getScriptSource()
    local source = ""
    if getscriptsource then
        source = getscriptsource(script)
    elseif script and script.Source then
        source = script.Source
    else
        warn("Konnte Skript-Quelle nicht finden.")
    end
    return source
end

-- Funktion um Text in die Zwischenablage zu kopieren
local function copyToClipboard(text, feedbackButton)
    if setclipboard and text ~= "" then
        pcall(function()
            setclipboard(text)
            if feedbackButton then
                giveVisualFeedback(feedbackButton)
            end
        end)
    else
        warn("`setclipboard` ist nicht verfügbar oder die Quelle ist leer.")
    end
end

local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 0, 0)
contentFrame.AutomaticSize = Enum.AutomaticSize.Y
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = contentFrame

-- #################### FUNKTIONEN ####################

-- Funktion zum Verschieben des Fensters
local dragging = false
local dragStart, startPos
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainContainer.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
		local newPos = input.Position - dragStart
		mainContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + newPos.X, startPos.Y.Scale, startPos.Y.Offset + newPos.Y)
	end
end)

-- Automatische und zuverlässige Aktualisierung der Canvas-Größe
contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	mainFrame.CanvasSize = UDim2.new(0, 0, 0, contentFrame.AbsoluteSize.Y)
end)

-- Rekursive Funktion, um die Baumstruktur für jedes Objekt zu erstellen
function createEntry(object, parentUi, indent)
	local entryFrame = Instance.new("Frame")
	entryFrame.Name = "EntryFrame"
	entryFrame.Size = UDim2.new(1, 0, 0, 0)
	entryFrame.AutomaticSize = Enum.AutomaticSize.Y
	entryFrame.BackgroundTransparency = 1
	entryFrame.Parent = parentUi

	local entryLayout = Instance.new("UIListLayout")
	entryLayout.SortOrder = Enum.SortOrder.LayoutOrder
	entryLayout.Parent = entryFrame

	local entryButton = Instance.new("TextButton")
	entryButton.Name = object.Name
	entryButton.Size = UDim2.new(1, 0, 0, 22)
	entryButton.TextXAlignment = Enum.TextXAlignment.Left
	entryButton.BackgroundTransparency = 1
	entryButton.TextColor3 = Color3.fromRGB(220, 220, 220)
	entryButton.Font = Enum.Font.Gotham
	entryButton.TextSize = 14
	entryButton.Parent = entryFrame
	entryButton.LayoutOrder = 1

	local children = {}
	pcall(function() children = object:GetChildren() end)
	local objectPath = object:GetFullName()
	local prefix = string.rep("    ", indent)
	local childrenFrame = nil

	local function updateEntryVisuals()
		if #children > 0 then
			local isExpanded = uiState[objectPath] or false
			local toggleSymbol = isExpanded and "[-] " or "[+] "
			entryButton.Text = prefix .. toggleSymbol .. object.Name .. " (" .. object.ClassName .. ")"

			if isExpanded and not childrenFrame then
				childrenFrame = Instance.new("Frame")
				childrenFrame.Name = "ChildrenFrame"
				childrenFrame.Size = UDim2.new(1, 0, 0, 0)
				childrenFrame.AutomaticSize = Enum.AutomaticSize.Y
				childrenFrame.BackgroundTransparency = 1
				childrenFrame.Parent = entryFrame
				childrenFrame.LayoutOrder = 2
				local childrenLayout = Instance.new("UIListLayout")
				childrenLayout.Padding = UDim.new(0, 1)
				childrenLayout.Parent = childrenFrame
				for _, child in ipairs(children) do
					createEntry(child, childrenFrame, indent + 1)
				end
			elseif not isExpanded and childrenFrame then
				childrenFrame:Destroy()
				childrenFrame = nil
			end
		elseif object:IsA("ValueBase") then
			entryButton.Text = prefix .. "- " .. object.Name .. ": " .. tostring(object.Value)
			entryButton.TextColor3 = Color3.fromRGB(120, 220, 120)
		else
			entryButton.Text = prefix .. "- " .. object.Name .. " (" .. object.ClassName .. ")"
		end
	end

	entryButton.MouseButton1Click:Connect(function()
		if #children > 0 then
			uiState[objectPath] = not uiState[objectPath]
			updateEntryVisuals()
		end
	end)

	entryButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end

		for _, v in ipairs(entryButton:GetChildren()) do
			if v.Name == "ContextMenu" then v:Destroy() end
		end

		local contextMenu = Instance.new("Frame")
		contextMenu.Name = "ContextMenu"
		contextMenu.Size = UDim2.new(0, 150, 0, 0)
		contextMenu.AutomaticSize = Enum.AutomaticSize.Y
		contextMenu.Position = UDim2.new(0, 5, 1, 5)
		contextMenu.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
		contextMenu.ZIndex = 20
		contextMenu.Parent = entryButton
		local menuCorner = Instance.new("UICorner"); menuCorner.CornerRadius = UDim.new(0,4); menuCorner.Parent = contextMenu
		local menuStroke = Instance.new("UIStroke"); menuStroke.Color = Color3.fromRGB(100,100,110); menuStroke.Parent = contextMenu
		local menuLayout = Instance.new("UIListLayout"); menuLayout.Padding = UDim.new(0,2); menuLayout.Parent = contextMenu

		local function createMenuButton(text)
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(1, 0, 0, 25)
			button.Text = text
			button.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
			button.TextColor3 = Color3.fromRGB(220, 220, 220)
			button.Font = Enum.Font.Gotham
			button.TextSize = 14
			button.Parent = contextMenu
			return button
		end

		local copyPathButton = createMenuButton("Pfad kopieren")
		copyPathButton.MouseButton1Click:Connect(function()
			setclipboard(object:GetFullName())
			copyPathButton.Text = "Kopiert!"
			wait(1)
			contextMenu:Destroy()
		end)

		if object:IsA("ValueBase") then
			local editValueButton = createMenuButton("Wert bearbeiten")
			editValueButton.MouseButton1Click:Connect(function()
				contextMenu:Destroy()
				local editBox = Instance.new("TextBox")
				editBox.Size = UDim2.new(1, 0, 1, 0)
				editBox.Position = UDim2.new(0,0,0,0)
				editBox.Text = tostring(object.Value)
				editBox.ClearTextOnFocus = false
				editBox.Font = Enum.Font.Gotham
				editBox.TextColor3 = Color3.fromRGB(255, 255, 255)
				editBox.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
				editBox.ZIndex = 10
				editBox.Parent = entryButton
				editBox:CaptureFocus()

				local function applyChange()
					pcall(function()
						local new_val = editBox.Text
						if tonumber(new_val) and not object:IsA("StringValue") then
							object.Value = tonumber(new_val)
						else
							object.Value = new_val
						end
					end)
					editBox:Destroy()
					updateEntryVisuals()
				end

				editBox.FocusLost:Connect(function(enterPressed)
					if enterPressed then applyChange() else editBox:Destroy() end
				end)
			end)
		end

		local closeConn
		closeConn = UserInputService.InputBegan:Connect(function()
			if contextMenu and contextMenu.Parent then
				contextMenu:Destroy()
			end
			closeConn:Disconnect()
		end)
	end)

	updateEntryVisuals()
end


-- Funktion zum Erstellen eines UI-Eintrags für einen Spieler
function createPlayerEntry(player)
	if playerFrames[player] then return end

	playerFunctionStates[player] = {
		isFrozen = false, isFloating = false, isGodmode = false, isESP = false, isFlying = false,
		walkSpeedEnabled = false, jumpPowerEnabled = false,
		walkSpeedValue = 24, jumpPowerValue = 50, flySpeedValue = 75
	}

	local playerMainFrame = Instance.new("Frame")
	playerMainFrame.Name = player.Name .. "_MainFrame"
	playerMainFrame.Size = UDim2.new(1, 0, 0, 0)
	playerMainFrame.AutomaticSize = Enum.AutomaticSize.Y
	playerMainFrame.BackgroundTransparency = 1
	playerMainFrame.LayoutOrder = player.UserId
	playerMainFrame.Parent = contentFrame

	local playerLayout = Instance.new("UIListLayout")
	playerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerLayout.Padding = UDim.new(0, 2)
	playerLayout.Parent = playerMainFrame

	local playerHeader = Instance.new("TextButton")
	playerHeader.Name = player.Name
	playerHeader.Size = UDim2.new(1, 0, 0, 28)
	playerHeader.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	playerHeader.Text = "► " .. player.Name
	playerHeader.Font = Enum.Font.GothamBold
	playerHeader.TextSize = 16
	playerHeader.TextColor3 = Color3.fromRGB(255, 200, 100)
	playerHeader.TextXAlignment = Enum.TextXAlignment.Left
	playerHeader.Parent = playerMainFrame
	playerHeader.LayoutOrder = 1
	local playerHeaderCorner = Instance.new("UICorner"); playerHeaderCorner.CornerRadius = UDim.new(0,4); playerHeaderCorner.Parent = playerHeader

	local detailsContainer = Instance.new("Frame")
	detailsContainer.Name = "DetailsContainer"
	detailsContainer.Size = UDim2.new(1, -10, 0, 0)
    detailsContainer.Position = UDim2.new(0.5, 0, 0, 0)
    detailsContainer.AnchorPoint = Vector2.new(0.5, 0)
	detailsContainer.AutomaticSize = Enum.AutomaticSize.Y
	detailsContainer.BackgroundTransparency = 1
	detailsContainer.ClipsDescendants = true
	detailsContainer.Visible = false
	detailsContainer.Parent = playerMainFrame
	detailsContainer.LayoutOrder = 2

    local detailsLayout = Instance.new("UIListLayout")
    detailsLayout.Padding = UDim.new(0, 4)
    detailsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    detailsLayout.Parent = detailsContainer

	-- Tab-System (jetzt mit Scrolling)
	local tabScrollingFrame = Instance.new("ScrollingFrame")
	tabScrollingFrame.Name = "TabScrollingFrame"
	tabScrollingFrame.Size = UDim2.new(1, 0, 0, 35)
	tabScrollingFrame.BackgroundTransparency = 1
	tabScrollingFrame.BorderSizePixel = 0
	tabScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.X
	tabScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
	tabScrollingFrame.ScrollBarThickness = 4
	tabScrollingFrame.Parent = detailsContainer
	tabScrollingFrame.LayoutOrder = 1

	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(0, 0, 1, 0)
	tabContainer.AutomaticSize = Enum.AutomaticSize.X
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = tabScrollingFrame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabContainer

    -- Verbindung zur Aktualisierung der CanvasSize
	tabContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		tabScrollingFrame.CanvasSize = UDim2.new(0, tabContainer.AbsoluteSize.X, 0, 0)
	end)

	local pagesFrame = Instance.new("Frame")
	pagesFrame.Name = "PagesFrame"
	pagesFrame.Size = UDim2.new(1, 0, 0, 0)
	pagesFrame.AutomaticSize = Enum.AutomaticSize.Y
	pagesFrame.BackgroundTransparency = 1
	pagesFrame.Parent = detailsContainer
	pagesFrame.LayoutOrder = 2

	local activeTabColor = Color3.fromRGB(80, 120, 220)
	local inactiveTabColor = Color3.fromRGB(60, 60, 70)
	local pages = {}
	local tabs = {}
	local tabLayoutOrder = 1

	local function createTab(name)
		local page = Instance.new("Frame")
		page.Name = name .. "Page"
		page.Size = UDim2.new(1, 0, 0, 0)
		page.AutomaticSize = Enum.AutomaticSize.Y
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = pagesFrame
		local pageLayout = Instance.new("UIListLayout"); pageLayout.Padding = UDim.new(0, 5); pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; pageLayout.Parent = page
		pages[name] = page

		local tabButton = Instance.new("TextButton")
		tabButton.Name = name .. "Tab"
        tabButton.AutomaticSize = Enum.AutomaticSize.X
        tabButton.Size = UDim2.new(0,0,1,0)
		tabButton.BackgroundColor3 = inactiveTabColor
		tabButton.Text = " " .. name .. " "
		tabButton.Font = Enum.Font.GothamBold
		tabButton.TextSize = 14
		tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabButton.LayoutOrder = tabLayoutOrder
		tabButton.Parent = tabContainer
		local tabCorner = Instance.new("UICorner"); tabCorner.CornerRadius = UDim.new(0, 4); tabCorner.Parent = tabButton
        local tabPadding = Instance.new("UIPadding"); tabPadding.PaddingLeft = UDim.new(0,10); tabPadding.PaddingRight = UDim.new(0,10); tabPadding.Parent = tabButton
		tabs[name] = tabButton

		tabLayoutOrder = tabLayoutOrder + 1

		tabButton.MouseButton1Click:Connect(function()
			for tabName, otherPage in pairs(pages) do
				local isActive = (tabName == name)
				otherPage.Visible = isActive
				tabs[tabName].BackgroundColor3 = isActive and activeTabColor or inactiveTabColor
			end
		end)
		return page
	end

	-- Hier wird die Reihenfolge der Tabs festgelegt
	local actionsPage = createTab("Aktionen")
	local explorerPage = createTab("Explorer")
	local powerupsPage = createTab("Power-Ups")
    local codePage = createTab("Code")

    -- Einstellungs-Tab (nur für lokalen Spieler)
    if player == localPlayer then
        local settingsPage = createTab("Einstellungen")

        local keybindFrame = Instance.new("Frame")
        keybindFrame.Name = "KeybindFrame"
        keybindFrame.Size = UDim2.new(1, -20, 0, 80)
        keybindFrame.BackgroundTransparency = 1
        keybindFrame.Parent = settingsPage

        local keybindLayout = Instance.new("UIListLayout")
        keybindLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        keybindLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        keybindLayout.Padding = UDim.new(0, 5)
        keybindLayout.Parent = keybindFrame

        local keybindInfo = Instance.new("TextLabel")
        keybindInfo.Name = "KeybindInfo"
        keybindInfo.Size = UDim2.new(1, 0, 0, 20)
        keybindInfo.Text = "Hotkey zum Ein-/Ausblenden des Menüs"
        keybindInfo.Font = Enum.Font.Gotham
        keybindInfo.TextSize = 14
        keybindInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
        keybindInfo.BackgroundTransparency = 1
        keybindInfo.Parent = keybindFrame

        keybindButton = Instance.new("TextButton")
        keybindButton.Name = "KeybindButton"
        keybindButton.Size = UDim2.new(1, 0, 0, 35)
        keybindButton.BackgroundColor3 = Color3.fromRGB(80, 120, 220)
        keybindButton.Font = Enum.Font.GothamBold
        keybindButton.Text = "Toggle-Key ändern: " .. toggleUiKey.Name
        keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        keybindButton.TextSize = 16
        keybindButton.Parent = keybindFrame
        local kbBtnCorner = Instance.new("UICorner"); kbBtnCorner.Parent = keybindButton

        keybindButton.MouseButton1Click:Connect(function()
            if not isBindingKey then
                isBindingKey = true
                keybindButton.Text = "Taste drücken..."
            end
        end)
    end

	tabs["Aktionen"].BackgroundColor3 = activeTabColor
	pages["Aktionen"].Visible = true

	local disclaimerLabel = Instance.new("TextLabel")
	disclaimerLabel.Name = "Disclaimer"
	disclaimerLabel.Size = UDim2.new(1, 0, 0, 20)
	disclaimerLabel.Text = "Aktionen sind nur lokal sichtbar!"
	disclaimerLabel.Font = Enum.Font.SourceSansItalic
	disclaimerLabel.TextSize = 13
	disclaimerLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	disclaimerLabel.BackgroundTransparency = 1
	disclaimerLabel.TextXAlignment = Enum.TextXAlignment.Center
	disclaimerLabel.Parent = detailsContainer
	disclaimerLabel.LayoutOrder = 0

	-- Frame für einfache Aktionen
	local simpleActionsFrame = Instance.new("Frame")
	simpleActionsFrame.AutomaticSize = Enum.AutomaticSize.Y
	simpleActionsFrame.BackgroundTransparency = 1
	simpleActionsFrame.Parent = actionsPage
	local simpleActionsLayout = Instance.new("UIGridLayout")
	simpleActionsLayout.CellSize = UDim2.new(0, 140, 0, 30)
	simpleActionsLayout.CellPadding = UDim2.new(0, 5, 0, 5)
	simpleActionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	simpleActionsLayout.Parent = simpleActionsFrame

	-- Frame für Aktionen mit Slidern
	local sliderActionsFrame = Instance.new("Frame")
	sliderActionsFrame.Size = UDim2.new(1, 0, 0, 0)
	sliderActionsFrame.AutomaticSize = Enum.AutomaticSize.Y
	sliderActionsFrame.BackgroundTransparency = 1
	sliderActionsFrame.Parent = powerupsPage
	local sliderActionsLayout = Instance.new("UIListLayout")
	sliderActionsLayout.Padding = UDim.new(0, 5)
	sliderActionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sliderActionsLayout.Parent = sliderActionsFrame

    local function createActionButton(name, text, color)
		local button = Instance.new("TextButton")
		button.Name = name; button.Text = text; button.TextSize = 14
		button.BackgroundColor3 = color
		button.TextColor3 = Color3.fromRGB(255,255,255)
		button.Font = Enum.Font.Gotham
		button.Parent = simpleActionsFrame
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,4); corner.Parent = button
		return button
	end

	local function createSliderControl(config)
		local state = playerFunctionStates[player]

		local frame = Instance.new("Frame")
		frame.Name = config.name .. "Control"
		frame.Size = UDim2.new(1, 0, 0, 50)
		frame.BackgroundTransparency = 1
		frame.Parent = sliderActionsFrame

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.5, 0, 0, 20)
		title.Text = config.text
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextColor3 = Color3.fromRGB(240, 240, 240)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.BackgroundTransparency = 1
		title.Parent = frame

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0.5, 0, 0, 20)
		valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
		valueLabel.Font = Enum.Font.Gotham
		valueLabel.TextSize = 14
		valueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.BackgroundTransparency = 1
		valueLabel.Parent = frame

        local toggleButton
        if config.toggleKey then
            toggleButton = Instance.new("TextButton")
            toggleButton.Name = "ToggleButton"
            toggleButton.Size = UDim2.new(0, 50, 0, 20)
            toggleButton.Position = UDim2.new(1, -50, 0, 0)
            toggleButton.Font = Enum.Font.GothamBold
            toggleButton.TextSize = 12
            toggleButton.Parent = title

            toggleButton.MouseButton1Click:Connect(function()
                state[config.toggleKey] = not state[config.toggleKey]
            end)
        end

		local sliderTrack = Instance.new("Frame")
		sliderTrack.Size = UDim2.new(1, 0, 0, 6)
		sliderTrack.Position = UDim2.new(0, 0, 0, 25)
		sliderTrack.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		sliderTrack.Parent = frame
		local trackCorner = Instance.new("UICorner"); trackCorner.Parent = sliderTrack

		local sliderProgress = Instance.new("Frame")
		sliderProgress.Size = UDim2.new(0, 0, 1, 0)
		sliderProgress.BackgroundColor3 = config.color
		sliderProgress.Parent = sliderTrack
		local progressCorner = Instance.new("UICorner"); progressCorner.Parent = sliderProgress

		local knob = Instance.new("TextButton")
		knob.Size = UDim2.new(0, 16, 0, 16)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Position = UDim2.new(0, 0, 0.5, 0)
		knob.BackgroundColor3 = Color3.fromRGB(250, 250, 250)
		knob.Text = ""
		knob.ZIndex = 2
		knob.Parent = sliderTrack
		local knobCorner = Instance.new("UICorner"); knobCorner.CornerRadius = UDim.new(1,0); knobCorner.Parent = knob

		local function updateSlider(value)
			local percentage = (value - config.min) / (config.max - config.min)
			percentage = math.clamp(percentage, 0, 1)
			knob.Position = UDim2.new(percentage, 0, 0.5, 0)
			sliderProgress.Size = UDim2.new(percentage, 0, 1, 0)
			valueLabel.Text = string.format(config.format or "%.0f", value)
		end

		updateSlider(state[config.valueKey])

		knob.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local isDragging = true
				local moveConn, upConn

				moveConn = UserInputService.InputChanged:Connect(function(subInput)
					if (subInput.UserInputType == Enum.UserInputType.MouseMovement or subInput.UserInputType == Enum.UserInputType.Touch) and isDragging then
						local newX = subInput.Position.X - sliderTrack.AbsolutePosition.X
						local percentage = math.clamp(newX / sliderTrack.AbsoluteSize.X, 0, 1)
						local newValue = config.min + percentage * (config.max - config.min)
						state[config.valueKey] = newValue
						updateSlider(newValue)
					end
				end)

				upConn = UserInputService.InputEnded:Connect(function(subInput)
					if subInput.UserInputType == Enum.UserInputType.MouseButton1 or subInput.UserInputType == Enum.UserInputType.Touch then
						isDragging = false
						moveConn:Disconnect()
						upConn:Disconnect()
					end
				end)
			end
		end)

        return {frame=frame, toggleButton=toggleButton, title=title}
	end

	-- Erstellen der Buttons und Slider
	local tpButton = createActionButton("Teleport", "Zu Spieler TP", Color3.fromRGB(80, 120, 220))
	local killButton = createActionButton("Kill", "Kill", Color3.fromRGB(200, 40, 40))
	local freezeButton = createActionButton("Freeze", "Einfrieren", Color3.fromRGB(80, 180, 220))
	local floatButton = createActionButton("Float", "Schweben", Color3.fromRGB(180, 80, 220))
	local godmodeButton = createActionButton("Godmode", "Godmode Aus", Color3.fromRGB(220, 180, 80))
	local flyButton = createActionButton("Fly", "Fly Aus", Color3.fromRGB(100, 100, 255))
    local espButton = createActionButton("ESP", "ESP Aus", Color3.fromRGB(200, 60, 200))

	local walkSpeedControl = createSliderControl({ name = "WalkSpeed", text = "WalkSpeed", color = Color3.fromRGB(80, 220, 120), toggleKey = "walkSpeedEnabled", valueKey = "walkSpeedValue", min = 16, max = 500, default = 24 })
	local jumpPowerControl = createSliderControl({ name = "JumpPower", text = "JumpPower", color = Color3.fromRGB(80, 220, 120), toggleKey = "jumpPowerEnabled", valueKey = "jumpPowerValue", min = 50, max = 500, default = 50 })
	local flySpeedControl = createSliderControl({ name = "FlySpeed", text = "Fly Speed", color = Color3.fromRGB(100, 180, 255), valueKey = "flySpeedValue", min = 25, max = 1000, default = 75 })
    flySpeedControl.frame.Visible = false

	-- Explorer-Frame
	local explorerFrame = Instance.new("Frame")
	explorerFrame.Name = "ExplorerFrame"
	explorerFrame.Size = UDim2.new(1, 0, 0, 0)
	explorerFrame.AutomaticSize = Enum.AutomaticSize.Y
	explorerFrame.BackgroundTransparency = 1
	explorerFrame.Parent = explorerPage
	local explorerLayout = Instance.new("UIListLayout")
	explorerLayout.Padding = UDim.new(0, 1)
	explorerLayout.Parent = explorerFrame

	-- Code Editor/Viewer Inhalt
    local codeViewerFrame = Instance.new("Frame")
    codeViewerFrame.Name = "CodeViewerFrame"
    codeViewerFrame.Size = UDim2.new(1, 0, 0, 300)
    codeViewerFrame.BackgroundTransparency = 1
    codeViewerFrame.Parent = codePage

    local codeLayout = Instance.new("UIListLayout")
    codeLayout.Padding = UDim.new(0,10)
    codeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    codeLayout.Parent = codeViewerFrame

    local downloadButton = Instance.new("TextButton")
    downloadButton.Name = "DownloadButton"
    downloadButton.Size = UDim2.new(1, -20, 0, 35)
    downloadButton.BackgroundColor3 = Color3.fromRGB(80, 120, 220)
    downloadButton.Font = Enum.Font.GothamBold
    downloadButton.Text = "Skript in Zwischenablage kopieren"
    downloadButton.TextColor3 = Color3.fromRGB(255,255,255)
    downloadButton.TextSize = 16
    downloadButton.Parent = codeViewerFrame
    local dlBtnCorner = Instance.new("UICorner"); dlBtnCorner.Parent = downloadButton

    downloadButton.MouseButton1Click:Connect(function()
        copyToClipboard(getScriptSource(), downloadButton)
    end)

    local editorBg = Instance.new("Frame")
    editorBg.Name = "EditorBackground"
    editorBg.Size = UDim2.new(1, -20, 1, -55) -- Fills remaining space
    editorBg.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    editorBg.Parent = codeViewerFrame
    local editorCorner = Instance.new("UICorner"); editorCorner.Parent = editorBg
    local editorStroke = Instance.new("UIStroke"); editorStroke.Color = Color3.fromRGB(80,80,100); editorStroke.Parent = editorBg

    local codeEditorBox = Instance.new("TextBox")
    codeEditorBox.Name = "CodeEditor"
    codeEditorBox.Size = UDim2.new(1, -10, 1, -10)
    codeEditorBox.Position = UDim2.new(0.5, 0, 0.5, 0)
    codeEditorBox.AnchorPoint = Vector2.new(0.5, 0.5)
    codeEditorBox.MultiLine = true
    codeEditorBox.Text = getScriptSource()
    codeEditorBox.ClearTextOnFocus = false
    codeEditorBox.Font = Enum.Font.Code
    codeEditorBox.TextXAlignment = Enum.TextXAlignment.Left
    codeEditorBox.TextYAlignment = Enum.TextYAlignment.Top
    codeEditorBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    codeEditorBox.BackgroundTransparency = 1
    codeEditorBox.TextSize = 12
    codeEditorBox.Parent = editorBg

	local function rebuildExplorer()
		for _, child in ipairs(explorerFrame:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
		createEntry(player, explorerFrame, 0)
		if player.Character then createEntry(player.Character, explorerFrame, 0) end
	end

	-- Verbindungen für die Buttons
	tpButton.MouseButton1Click:Connect(function() pcall(function() localPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame end) end)
	killButton.MouseButton1Click:Connect(function() pcall(function() player.Character.Humanoid.Health = 0 end) end)
	freezeButton.MouseButton1Click:Connect(function() playerFunctionStates[player].isFrozen = not playerFunctionStates[player].isFrozen end)
	floatButton.MouseButton1Click:Connect(function() playerFunctionStates[player].isFloating = not playerFunctionStates[player].isFloating end)
	godmodeButton.MouseButton1Click:Connect(function() playerFunctionStates[player].isGodmode = not playerFunctionStates[player].isGodmode end)
	flyButton.MouseButton1Click:Connect(function() playerFunctionStates[player].isFlying = not playerFunctionStates[player].isFlying end)
	espButton.MouseButton1Click:Connect(function() playerFunctionStates[player].isESP = not playerFunctionStates[player].isESP end)

	playerHeader.MouseButton1Click:Connect(function()
		uiState[player.Name] = not uiState[player.Name]
		local isExpanded = uiState[player.Name]
		playerHeader.Text = (isExpanded and "▼ " or "► ") .. player.Name
		if isExpanded then rebuildExplorer() end
		detailsContainer.Visible = isExpanded
	end)

	local function handleCharacter()
		if player.Character then
			player.Character.ChildAdded:Connect(function() if uiState[player.Name] then rebuildExplorer() end end)
			player.Character.ChildRemoved:Connect(function() if uiState[player.Name] then rebuildExplorer() end end)
		end
	end

	player.CharacterAdded:Connect(function(character)
		handleCharacter()
		if uiState[player.Name] then rebuildExplorer() end
	end)
	handleCharacter()

	local espBox = Instance.new("BoxHandleAdornment")
	espBox.Name = "ESP_Box"
	espBox.AlwaysOnTop = true
	espBox.ZIndex = 5
	espBox.Size = Vector3.new(4, 6, 2)
	espBox.Transparency = 0.5
	espBox.Visible = false
	espBox.Parent = screenGui

	-- ######################################################################
	-- ### DIES IST DIE ZENTRALE LOGIK-SCHLEIFE FÜR ALLE FÄHIGKEITEN      ###
	-- ######################################################################
	local connection = RunService.RenderStepped:Connect(function()
		if not playerFrames[player] then return end
		local state = playerFunctionStates[player]
		if not state then return end

		pcall(function()
			local char = player.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if not humanoid then
                if espBox then espBox.Visible = false end
                return
            end

			if not (state.isFlying and player == localPlayer) then
				local finalWalkSpeed = state.walkSpeedEnabled and state.walkSpeedValue or 24
				local finalJumpPower = state.jumpPowerEnabled and state.jumpPowerValue or 50
				local finalPlatformStand = false

				if state.isFloating then finalPlatformStand = true end
				if state.isFrozen then finalWalkSpeed, finalJumpPower = 0, 0 end

				humanoid.WalkSpeed = finalWalkSpeed
				humanoid.JumpPower = finalJumpPower
				humanoid.PlatformStand = finalPlatformStand
			end

			if state.isGodmode then humanoid.Health = humanoid.MaxHealth end

			if state.isESP and char:FindFirstChild("HumanoidRootPart") then
				espBox.Adornee = char.HumanoidRootPart
				espBox.Visible = true
				if player.Team == localPlayer.Team and player.Team ~= nil then
					espBox.Color3 = Color3.fromRGB(0, 255, 0)
				else
					espBox.Color3 = Color3.fromRGB(255, 0, 0)
				end
			else
				espBox.Visible = false
			end

			freezeButton.Text = state.isFrozen and "Auftauen" or "Einfrieren"; freezeButton.BackgroundColor3 = state.isFrozen and Color3.fromRGB(220,120,80) or Color3.fromRGB(80,180,220)
			floatButton.Text = state.isFloating and "Fallen" or "Schweben"; floatButton.BackgroundColor3 = state.isFloating and Color3.fromRGB(220,180,80) or Color3.fromRGB(180,80,220)
			godmodeButton.Text = state.isGodmode and "Godmode An" or "Godmode Aus"; godmodeButton.BackgroundColor3 = state.isGodmode and Color3.fromRGB(40,200,40) or Color3.fromRGB(220,180,80)
			flyButton.Text = state.isFlying and "Fly An" or "Fly Aus"; flyButton.BackgroundColor3 = state.isFlying and Color3.fromRGB(100,180,255) or Color3.fromRGB(100,100,255)
			espButton.Text = state.isESP and "ESP An" or "ESP Aus"; espButton.BackgroundColor3 = state.isESP and Color3.fromRGB(255, 80, 255) or Color3.fromRGB(200, 60, 200)

			walkSpeedControl.toggleButton.Text = state.walkSpeedEnabled and "An" or "Aus"; walkSpeedControl.toggleButton.BackgroundColor3 = state.walkSpeedEnabled and Color3.fromRGB(40,200,120) or Color3.fromRGB(100,100,100)
			jumpPowerControl.toggleButton.Text = state.jumpPowerEnabled and "An" or "Aus"; jumpPowerControl.toggleButton.BackgroundColor3 = state.jumpPowerEnabled and Color3.fromRGB(40,200,120) or Color3.fromRGB(100,100,100)

            local jumpDisabled = state.isFlying or state.isFloating
            jumpPowerControl.title.TextColor3 = jumpDisabled and Color3.fromRGB(120,120,120) or Color3.fromRGB(240,240,240)
            jumpPowerControl.toggleButton.BackgroundColor3 = jumpDisabled and Color3.fromRGB(80,80,80) or (state.jumpPowerEnabled and Color3.fromRGB(40,200,120) or Color3.fromRGB(100,100,100))
            jumpPowerControl.toggleButton.AutoButtonColor = not jumpDisabled

            flySpeedControl.frame.Visible = state.isFlying

		end)
	end)

	playerFrames[player] = {Frame = playerMainFrame, Connection = connection, ESPBox = espBox}
end

function onPlayerRemoving(player)
	if playerFrames[player] then
		playerFrames[player].Connection:Disconnect()
		if playerFrames[player].ESPBox then
			playerFrames[player].ESPBox:Destroy()
		end
		playerFrames[player].Frame:Destroy()
		playerFrames[player] = nil
		playerFunctionStates[player] = nil
		uiState[player.Name] = nil
	end
end

-- #################### Globale Logik für LOKALEN Spieler (Fliegen) ####################
local flyGyro, flyVelocity
local baseFlySpeed = 75
local sprintFlySpeed = 250

RunService.RenderStepped:Connect(function()
	pcall(function()
		if not localPlayer or not localPlayer.Character or not playerFunctionStates[localPlayer] then return end

		local state = playerFunctionStates[localPlayer]
		local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")

		if not state.isFlying or not hrp then
			if flyGyro then flyGyro:Destroy(); flyGyro = nil end
			if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
			return
		end

		local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		humanoid.PlatformStand = true
		if not flyGyro then
			flyGyro = Instance.new("BodyGyro", hrp)
			flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			flyGyro.D = 100; flyGyro.P = 5000
		end
		if not flyVelocity then
			flyVelocity = Instance.new("BodyVelocity", hrp)
			flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			flyVelocity.P = 1250
		end

		flyGyro.CFrame = workspace.CurrentCamera.CFrame

		local currentFlySpeed = state.flySpeedValue
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			currentFlySpeed = currentFlySpeed * 2.5 -- Sprint multiplier
		end

		local moveVector = Vector3.new()
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + Vector3.new(0,0,-1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector + Vector3.new(0,0,1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + Vector3.new(1,0,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector + Vector3.new(-1,0,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector = moveVector + Vector3.new(0,1,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveVector = moveVector + Vector3.new(0,-1,0) end

		flyVelocity.Velocity = moveVector.Magnitude > 0 and (workspace.CurrentCamera.CFrame:VectorToWorldSpace(moveVector.Unit)) * currentFlySpeed or Vector3.new(0,0,0)
	end)
end)

-- #################### Globale Eingabelogik (Key-Binding & UI Toggle) ####################
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if isBindingKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            toggleUiKey = input.KeyCode
            isBindingKey = false
            if keybindButton then
                keybindButton.Text = "Toggle-Key ändern: " .. toggleUiKey.Name
            end
        end
    elseif input.KeyCode == toggleUiKey then
        -- Verhindert das Umschalten, wenn in einem Textfeld getippt wird (z.B. Chat)
        if gameProcessedEvent then return end
        mainContainer.Visible = not mainContainer.Visible
    end
end)


-- #################### INITIALISIERUNG & EVENTS ####################
for _, player in ipairs(Players:GetPlayers()) do
	createPlayerEntry(player)
end

Players.PlayerAdded:Connect(createPlayerEntry)
Players.PlayerRemoving:Connect(onPlayerRemoving)

script.Destroying:Connect(function()
	if screenGui then screenGui:Destroy() end
end)
