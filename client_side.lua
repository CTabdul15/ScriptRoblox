-- Merged & Enhanced Player Explorer v33.1
-- Changelog:
-- - Fixed expand/collapse animation bug by correctly calculating target height.
-- - Re-instated smooth TweenService animation for player frame resizing.
-- - Fixed UI element offsets (Close button, player expand arrow).
-- - Added comprehensive, re-bindable key system for actions (Fly, Speed, etc.).
-- - Implemented sliders for granular control over WalkSpeed and FlySpeed.
-- - Added a dedicated "Keybinds" tab for settings.
-- - Keybind buttons now dynamically resize to fit text content.
-- - Added a scrolling frame to action tabs to prevent overflow.
-- - General UI polish and code refactoring for better maintainability.
-- IMPORTANT: This is a LocalScript - all actions on other players are CLIENT-SIDE ONLY

print("CLIENT: Enhanced Player Explorer v33.1 starting...")

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- Local Player
local localPlayer = Players.LocalPlayer

-- Wait for PlayerGui to exist
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- UI Theme & Configuration
local Theme = {
	Fonts = {
		Title = Enum.Font.GothamBold,
		Header = Enum.Font.GothamBold,
		Regular = Enum.Font.Gotham,
		Light = Enum.Font.GothamMedium
	},
	Colors = {
		Background = Color3.fromRGB(24, 25, 30),
		Primary = Color3.fromRGB(33, 35, 42),
		Secondary = Color3.fromRGB(24, 26, 31),
		Accent = Color3.fromRGB(88, 101, 242),
		AccentHover = Color3.fromRGB(110, 122, 249),
		Text = Color3.fromRGB(230, 232, 235),
		TextSecondary = Color3.fromRGB(180, 182, 185),
		Success = Color3.fromRGB(87, 242, 135),
		Warning = Color3.fromRGB(108, 97, 35),
		Error = Color3.fromRGB(237, 66, 69),
		ToggleOn = Color3.fromRGB(88, 101, 242),
		ToggleOff = Color3.fromRGB(70, 73, 82),
		TabActive = Color3.fromRGB(88, 101, 242),
		TabInactive = Color3.fromRGB(50, 52, 60),
	},
	Animation = {
		Speed = 0.2,
		Easing = Enum.EasingStyle.Quint,
		Direction = Enum.EasingDirection.Out
	}
}

-- State Storage
local uiState = {}
local playerFrames = {}
local playerFunctionStates = {}
local selectedPlayer = nil
local globalConnections = {}
local screenGui
local activeKeybindButton = nil
local isBindingKey = false
local localPlayerSettings = {
	walkSpeed = 16,
	flySpeed = 75
}

-- Keybind Configuration (Default values)
local keybinds = {
	toggleUi = {name = "Toggle UI", key = Enum.KeyCode.RightShift},
	fly = {name = "Toggle Fly", key = Enum.KeyCode.F},
	speed = {name = "Toggle Speed", key = Enum.KeyCode.G},
	-- Add more keybinds here as needed
}

-- Create ScreenGui with error handling
local function createScreenGui()
	local existing = playerGui:FindFirstChild("PlayerExplorerEnhanced")
	if existing then
		existing:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PlayerExplorerEnhanced"
	screenGui.Parent = playerGui
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.ResetOnSpawn = false

	return screenGui
end

-- Initialize ScreenGui
screenGui = createScreenGui()

-- Cleanup function
local function cleanupAndDestroy()
	print("Cleaning up Player Explorer...")
	for player, data in pairs(playerFrames) do
		if data.Connection then data.Connection:Disconnect() end
		if data.ESPBox then data.ESPBox:Destroy() end
	end
	for _, conn in ipairs(globalConnections) do conn:Disconnect() end

	pcall(function()
		if localPlayer and localPlayer.Character then
			local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand = false
				humanoid.WalkSpeed = 16 -- Reset speed
			end
			for _, part in ipairs(localPlayer.Character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = true
				end
			end
		end
	end)

	table.clear(globalConnections)
	pcall(function() screenGui:Destroy() end)
	print("Cleanup complete.")
end

-- Toast Notification Function
local function showToast(message, toastColor)
	spawn(function()
		local toastFrame = Instance.new("Frame")
		toastFrame.Name = "ToastNotification"
		toastFrame.Size = UDim2.new(0, 250, 0, 50)
		toastFrame.Position = UDim2.new(0.5, -125, 1, 50)
		toastFrame.BackgroundColor3 = Theme.Colors.Primary
		toastFrame.BorderSizePixel = 0
		toastFrame.Parent = screenGui
		toastFrame.ZIndex = 100

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = toastFrame

		local stroke = Instance.new("UIStroke")
		stroke.Color = toastColor or Theme.Colors.Accent
		stroke.Thickness = 1.5
		stroke.Parent = toastFrame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -10, 1, 0)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.Font = Theme.Fonts.Regular
		label.TextColor3 = Theme.Colors.Text
		label.Text = message
		label.TextSize = 15
		label.TextWrapped = true
		label.Parent = toastFrame

		local tweenInfoIn = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local tweenIn = TweenService:Create(toastFrame, tweenInfoIn, {Position = UDim2.new(0.5, -125, 1, -60)})
		tweenIn:Play()

		wait(3)

		local tweenInfoOut = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		local tweenOut = TweenService:Create(toastFrame, tweenInfoOut, {Position = UDim2.new(0.5, -125, 1, 50)})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			toastFrame:Destroy()
		end)
	end)
end


-- Main Container
local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(0, 400, 0, 600) -- Increased size for more content
mainContainer.Position = UDim2.new(0.5, -200, 0.5, -300)
mainContainer.BackgroundColor3 = Theme.Colors.Background
mainContainer.BorderSizePixel = 0
mainContainer.ClipsDescendants = true
mainContainer.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainContainer

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Theme.Colors.Secondary
mainStroke.Parent = mainContainer

-- Title Bar
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 35)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Theme.Colors.Primary
title.BorderSizePixel = 0
title.Text = "  Player Explorer v33.1"
title.Font = Theme.Fonts.Title
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Colors.Text
title.TextSize = 16
title.Parent = mainContainer

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = title

-- Close Button (FIXED OFFSET)
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 24, 0, 24)
closeButton.Position = UDim2.new(1, -10, 0.5, 0) -- Positioned from the right edge with 10px padding
closeButton.AnchorPoint = Vector2.new(1, 0.5) -- Anchored to the right-center
closeButton.BackgroundColor3 = Theme.Colors.Error
closeButton.Text = "X"
closeButton.Font = Theme.Fonts.Title
closeButton.TextColor3 = Theme.Colors.Text
closeButton.TextSize = 14
closeButton.Parent = title
closeButton.ZIndex = 2
closeButton.MouseButton1Click:Connect(cleanupAndDestroy)
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

-- ScrollingFrame for player list
local mainFrame = Instance.new("ScrollingFrame")
mainFrame.Name = "PlayerListScroll"
mainFrame.Size = UDim2.new(1, 0, 1, -35)
mainFrame.Position = UDim2.new(0, 0, 0, 35)
mainFrame.BackgroundColor3 = Theme.Colors.Background
mainFrame.BorderSizePixel = 0
mainFrame.ScrollBarImageColor3 = Theme.Colors.Accent
mainFrame.ScrollBarThickness = 5
mainFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
mainFrame.Parent = mainContainer

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = mainFrame

local framePadding = Instance.new("UIPadding")
framePadding.PaddingTop = UDim.new(0, 10)
framePadding.PaddingBottom = UDim.new(0, 10)
framePadding.PaddingLeft = UDim.new(0, 10)
framePadding.PaddingRight = UDim.new(0, 10)
framePadding.Parent = mainFrame

-- Make window draggable
local dragging = false
local dragStart, startPos
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainContainer.Position
		input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
	end
end)
table.insert(globalConnections, UserInputService.InputChanged:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
		local newPos = input.Position - dragStart
		mainContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + newPos.X, startPos.Y.Scale, startPos.Y.Offset + newPos.Y)
	end
end))

-- Update canvas size when content changes
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	mainFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
end)


-- #region UI Component Factory

--- Creates a slider for numerical input.
function createSlider(name, min, max, initialValue, parent, callback)
	local sliderFrame = Instance.new("Frame")
	sliderFrame.Name = name .. "SliderFrame"
	sliderFrame.Size = UDim2.new(1, 0, 0, 50)
	sliderFrame.BackgroundTransparency = 1
	sliderFrame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "SliderLabel"
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Regular
	label.TextColor3 = Theme.Colors.TextSecondary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = name .. ": " .. initialValue
	label.TextSize = 15
	label.Parent = sliderFrame

	local sliderBack = Instance.new("Frame")
	sliderBack.Name = "SliderBack"
	sliderBack.Size = UDim2.new(1, 0, 0, 8)
	sliderBack.Position = UDim2.new(0, 0, 0, 25)
	sliderBack.BackgroundColor3 = Theme.Colors.Secondary
	sliderBack.Parent = sliderFrame
	local backCorner = Instance.new("UICorner"); backCorner.CornerRadius = UDim.new(1,0); backCorner.Parent = sliderBack

	local sliderFill = Instance.new("Frame")
	sliderFill.Name = "SliderFill"
	local percent = (initialValue - min) / (max - min)
	sliderFill.Size = UDim2.new(percent, 0, 1, 0)
	sliderFill.BackgroundColor3 = Theme.Colors.Accent
	sliderFill.Parent = sliderBack
	local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(1,0); fillCorner.Parent = sliderFill

	local sliderHandle = Instance.new("TextButton")
	sliderHandle.Name = "SliderHandle"
	sliderHandle.Size = UDim2.new(0, 16, 0, 16)
	sliderHandle.AnchorPoint = Vector2.new(0.5, 0.5)
	sliderHandle.Position = UDim2.new(1, 0, 0.5, 0)
	sliderHandle.Text = ""
	sliderHandle.BackgroundColor3 = Theme.Colors.Text
	sliderHandle.ZIndex = 2
	sliderHandle.Parent = sliderFill
	local handleCorner = Instance.new("UICorner"); handleCorner.CornerRadius = UDim.new(1,0); handleCorner.Parent = sliderHandle

	local draggingSlider = false
	sliderHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = true end
	end)
	sliderHandle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mouseX = UserInputService:GetMouseLocation().X
			local backPos = sliderBack.AbsolutePosition.X
			local backSize = sliderBack.AbsoluteSize.X
			local alpha = math.clamp((mouseX - backPos) / backSize, 0, 1)
			local value = math.floor(min + (max - min) * alpha + 0.5)

			sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
			sliderHandle.Position = UDim2.new(1, 0, 0.5, 0)
			label.Text = name .. ": " .. value
			if callback then callback(value) end
		end
	end)
	return sliderFrame
end


--- Creates a button for changing a keybind.
function createKeybindButton(id, bindInfo, parent)
	local frame = Instance.new("Frame")
	frame.Name = id .. "KeybindFrame"
	frame.Size = UDim2.new(1, 0, 0, 35)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "KeybindLabel"
	label.Size = UDim2.new(0.5, -5, 1, 0)
	label.TextSize = 16 
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Regular
	label.TextColor3 = Theme.Colors.Text
	label.Text = bindInfo.name .. ":"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local button = Instance.new("TextButton")
	button.Name = "KeybindButton"
	button.Size = UDim2.new(0.5, -5, 1, 0)
	button.Position = UDim2.fromScale(0.5, 0)
	button.BackgroundColor3 = Theme.Colors.Secondary
	button.Font = Theme.Fonts.Header
	button.TextColor3 = Theme.Colors.Text
	button.Text = bindInfo.key.Name
	button.TextSize = 15
	button.Parent = frame
	button.AutomaticSize = Enum.AutomaticSize.X -- DYNAMIC SIZE
	button.ClipsDescendants = false
	local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(0,6); btnCorner.Parent = button
	local btnPadding = Instance.new("UIPadding"); btnPadding.PaddingLeft=UDim.new(0,10); btnPadding.PaddingRight=UDim.new(0,10); btnPadding.Parent = button

	button.MouseButton1Click:Connect(function()
		if isBindingKey and activeKeybindButton then
			-- Cancel previous binding
			activeKeybindButton.Text = keybinds[activeKeybindButton.Name:gsub("KeybindButton", "")].key.Name
			activeKeybindButton.TextSize = 15
			activeKeybindButton.BackgroundColor3 = Theme.Colors.Secondary
		end
		isBindingKey = true
		activeKeybindButton = button
		button.Text = "..."
		button.BackgroundColor3 = Theme.Colors.Warning
	end)

	return frame
end
-- #endregion


-- Object Explorer Function
function createEntry(object, parentUi, indent)
	-- This function remains largely the same as the original, as it was well-built.
	-- No significant changes requested or needed for this part.
	local entryFrame = Instance.new("Frame")
	entryFrame.Name = "EntryFrame"
	entryFrame.Size = UDim2.new(1, 0, 0, 0)
	entryFrame.AutomaticSize = Enum.AutomaticSize.Y
	entryFrame.BackgroundTransparency = 1
	entryFrame.Parent = parentUi
	local entryLayout = Instance.new("UIListLayout"); entryLayout.SortOrder = Enum.SortOrder.LayoutOrder; entryLayout.Parent = entryFrame

	local entryButton = Instance.new("TextButton")
	entryButton.Name = object.Name; entryButton.Size = UDim2.new(1, 0, 0, 22)
	entryButton.TextXAlignment = Enum.TextXAlignment.Left; entryButton.BackgroundTransparency = 1
	entryButton.TextColor3 = Theme.Colors.TextSecondary; entryButton.Font = Theme.Fonts.Light
	entryButton.TextSize = 15; entryButton.Parent = entryFrame; entryButton.LayoutOrder = 1

	local children = {}; pcall(function() children = object:GetChildren() end)
	local objectPath = object:GetFullName(); local prefix = string.rep("    ", indent)
	local childrenFrame = nil

	local function updateEntryVisuals()
		if #children > 0 then
			local isExpanded = uiState[objectPath] or false
			local toggleSymbol = isExpanded and "V " or "> "
			entryButton.Text = prefix .. toggleSymbol .. object.Name .. " (" .. object.ClassName .. ")"
			if isExpanded and not childrenFrame then
				childrenFrame = Instance.new("Frame"); childrenFrame.Name = "ChildrenFrame"; childrenFrame.Size = UDim2.new(1, 0, 0, 0)
				childrenFrame.AutomaticSize = Enum.AutomaticSize.Y; childrenFrame.BackgroundTransparency = 1
				childrenFrame.Parent = entryFrame; childrenFrame.LayoutOrder = 2
				local childrenLayout = Instance.new("UIListLayout"); childrenLayout.Padding = UDim.new(0, 1); childrenLayout.Parent = childrenFrame
				for _, child in ipairs(children) do createEntry(child, childrenFrame, indent + 1) end
			elseif not isExpanded and childrenFrame then
				childrenFrame:Destroy(); childrenFrame = nil
			end
		elseif object:IsA("ValueBase") then
			entryButton.Text = prefix .. "- " .. object.Name .. ": " .. tostring(object.Value)
			entryButton.TextColor3 = Theme.Colors.Success
		else
			entryButton.Text = prefix .. "- " .. object.Name .. " (" .. object.ClassName .. ")"
		end
	end

	entryButton.MouseButton1Click:Connect(function()
		if #children > 0 then uiState[objectPath] = not uiState[objectPath]; updateEntryVisuals() end
	end)
	-- Context Menu (Right-Click)
	entryButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
		for _, v in ipairs(entryButton:GetChildren()) do if v.Name == "ContextMenu" then v:Destroy() end end
		local contextMenu = Instance.new("Frame"); contextMenu.Name = "ContextMenu"; contextMenu.Size = UDim2.new(0, 150, 0, 0)
		contextMenu.AutomaticSize = Enum.AutomaticSize.Y; contextMenu.Position = UDim2.new(0, 5, 1, 5)
		contextMenu.BackgroundColor3 = Theme.Colors.Primary; contextMenu.ZIndex = 20; contextMenu.Parent = entryButton
		local menuCorner = Instance.new("UICorner"); menuCorner.CornerRadius = UDim.new(0,4); menuCorner.Parent = contextMenu
		local menuStroke = Instance.new("UIStroke"); menuStroke.Color = Theme.Colors.Secondary; menuStroke.Parent = contextMenu
		local menuLayout = Instance.new("UIListLayout"); menuLayout.Padding = UDim.new(0,2); menuLayout.Parent = contextMenu
		local function createMenuButton(text)
			local button = Instance.new("TextButton"); button.Size = UDim2.new(1, 0, 0, 25); button.Text = text
			button.BackgroundColor3 = Theme.Colors.Secondary; button.TextColor3 = Theme.Colors.Text
			button.Font = Theme.Fonts.Regular; button.TextSize = 15; button.Parent = contextMenu
			return button
		end
		local copyPathButton = createMenuButton("Copy Path")
		copyPathButton.MouseButton1Click:Connect(function()
			if setclipboard then setclipboard(object:GetFullName()); showToast("Path copied!", Theme.Colors.Success)
			else showToast("Clipboard not available", Theme.Colors.Error) end
			contextMenu:Destroy()
		end)
		if object:IsA("ValueBase") then
			local editValueButton = createMenuButton("Edit Value")
			editValueButton.MouseButton1Click:Connect(function()
				contextMenu:Destroy()
				local editBox = Instance.new("TextBox"); editBox.Size = UDim2.new(1, 0, 1, 0); editBox.Position = UDim2.new(0,0,0,0)
				editBox.Text = tostring(object.Value); editBox.ClearTextOnFocus = false; editBox.Font = Theme.Fonts.Regular
				editBox.TextColor3 = Theme.Colors.Text; editBox.BackgroundColor3 = Theme.Colors.Secondary
				editBox.ZIndex = 10; editBox.Parent = entryButton; editBox:CaptureFocus()
				local function applyChange()
					pcall(function()
						local new_val = editBox.Text
						if object:IsA("NumberValue") or object:IsA("IntValue") then object.Value = tonumber(new_val) or object.Value
						elseif object:IsA("BoolValue") then
							if new_val:lower() == "true" then object.Value = true
							elseif new_val:lower() == "false" then object.Value = false end
						else object.Value = new_val end
					end); editBox:Destroy(); updateEntryVisuals()
				end
				editBox.FocusLost:Connect(function(enterPressed) if enterPressed then applyChange() else editBox:Destroy() end end)
			end)
		end
		local closeConn; closeConn = UserInputService.InputBegan:Connect(function()
			if contextMenu and contextMenu.Parent then contextMenu:Destroy() end
			closeConn:Disconnect()
		end)
	end)
	updateEntryVisuals()
end

-- Function to create player entry
local function createPlayerEntry(player)
	if playerFrames[player] then return end

	playerFunctionStates[player] = {
		isFrozen = false, isGodmode = false, isESP = false, isFlying = false, speedBoost = false,
	}

	local playerMainFrame = Instance.new("Frame")
	playerMainFrame.Name = player.Name .. "_MainFrame"; playerMainFrame.Size = UDim2.new(1, -20, 0, 40)
	playerMainFrame.BackgroundColor3 = Theme.Colors.Primary; playerMainFrame.BorderSizePixel = 0
	playerMainFrame.ClipsDescendants = true; playerMainFrame.LayoutOrder = player.UserId; playerMainFrame.Parent = mainFrame
	local playerCorner = Instance.new("UICorner"); playerCorner.CornerRadius = UDim.new(0, 8); playerCorner.Parent = playerMainFrame

	local playerHeader = Instance.new("TextButton")
	playerHeader.Name = "Header"; playerHeader.Size = UDim2.new(1, 0, 0, 40); playerHeader.BackgroundTransparency = 1
	playerHeader.Text = ""; playerHeader.Parent = playerMainFrame

	-- FIXED: Arrow icon moved to the far left
	local icon = Instance.new("TextLabel"); icon.Size = UDim2.new(0, 20, 1, 0); icon.Position = UDim2.fromOffset(10, 0)
	icon.BackgroundTransparency = 1; icon.Font = Theme.Fonts.Header; icon.Text = ">" -- Using ▸ and ▾
	icon.TextColor3 = Theme.Colors.Accent; icon.TextSize = 20; icon.Parent = playerHeader

	local playerNameLabel = Instance.new("TextLabel")
	playerNameLabel.Size = UDim2.new(1, -40, 1, 0); playerNameLabel.Position = UDim2.fromOffset(35, 0)
	playerNameLabel.BackgroundTransparency = 1; playerNameLabel.Font = Theme.Fonts.Header; playerNameLabel.TextSize = 16
	playerNameLabel.TextColor3 = player == localPlayer and Theme.Colors.Success or Theme.Colors.Text
	playerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	playerNameLabel.Text = player.Name .. (player == localPlayer and " (YOU)" or "")
	playerNameLabel.Parent = playerHeader

	local detailsContainer = Instance.new("Frame")
	detailsContainer.Name = "DetailsContainer"; detailsContainer.Size = UDim2.new(1, 0, 0, 0)
	detailsContainer.AutomaticSize = Enum.AutomaticSize.Y; detailsContainer.Position = UDim2.new(0, 0, 0, 40)
	detailsContainer.BackgroundTransparency = 1; detailsContainer.ClipsDescendants = true
	detailsContainer.Visible = false; detailsContainer.Parent = playerMainFrame

	local detailsLayout = Instance.new("UIListLayout"); detailsLayout.Padding = UDim.new(0, 5)
	detailsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; detailsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	detailsLayout.Parent = detailsContainer
	local detailsPadding = Instance.new("UIPadding"); detailsPadding.PaddingTop = UDim.new(0, 10); detailsPadding.PaddingBottom = UDim.new(0, 10)
	detailsPadding.PaddingLeft = UDim.new(0, 10); detailsPadding.PaddingRight = UDim.new(0, 10); detailsPadding.Parent = detailsContainer

	-- Tab System
	local tabContainer = Instance.new("Frame"); tabContainer.Name = "TabContainer"; tabContainer.Size = UDim2.new(1, 0, 0, 30)
	tabContainer.BackgroundTransparency = 1; tabContainer.Parent = detailsContainer; tabContainer.LayoutOrder = 1
	local tabLayout = Instance.new("UIListLayout"); tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; tabLayout.Padding = UDim.new(0, 5); tabLayout.Parent = tabContainer

	-- NEW: Scrolling frame for pages to prevent button overflow
	local pagesScrollingFrame = Instance.new("ScrollingFrame"); pagesScrollingFrame.Name = "PagesScrollingFrame"
	pagesScrollingFrame.Size = UDim2.new(1, 0, 0, 250); pagesScrollingFrame.BackgroundTransparency = 1
	pagesScrollingFrame.Parent = detailsContainer; pagesScrollingFrame.LayoutOrder = 2
	pagesScrollingFrame.BorderSizePixel = 0; pagesScrollingFrame.ScrollBarThickness = 4

	local pagesFrame = Instance.new("Frame"); pagesFrame.Name = "PagesFrame"; pagesFrame.Size = UDim2.new(1, 0, 0, 0)
	pagesFrame.AutomaticSize = Enum.AutomaticSize.Y; pagesFrame.BackgroundTransparency = 1
	pagesFrame.Parent = pagesScrollingFrame
	pagesScrollingFrame.CanvasSize = UDim2.new(0,0,0,0)
	pagesFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		pagesScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, pagesFrame.AbsoluteSize.Y)
	end)

	local pages = {}; local tabs = {}
	local function createTab(name)
		local page = Instance.new("Frame"); page.Name = name .. "Page"; page.Size = UDim2.new(1, 0, 0, 0)
		page.AutomaticSize = Enum.AutomaticSize.Y; page.BackgroundTransparency = 1; page.Visible = false
		page.Parent = pagesFrame
		local pageLayout = Instance.new("UIGridLayout"); pageLayout.CellPadding = UDim2.fromOffset(6, 6)
		pageLayout.CellSize = UDim2.new(0.5, -3, 0, 35); pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder; pageLayout.Parent = page
		pages[name] = page

		local tabButton = Instance.new("TextButton"); tabButton.Name = name .. "Tab"; tabButton.AutomaticSize = Enum.AutomaticSize.X
		tabButton.Size = UDim2.new(0, 0, 1, 0); tabButton.BackgroundColor3 = Theme.Colors.TabInactive
		tabButton.Text = " " .. name .. " "; tabButton.Font = Theme.Fonts.Header; tabButton.TextSize = 14
		tabButton.TextColor3 = Theme.Colors.Text; tabButton.Parent = tabContainer
		local tabCorner = Instance.new("UICorner"); tabCorner.CornerRadius = UDim.new(0, 6); tabCorner.Parent = tabButton
		local tabPadding = Instance.new("UIPadding"); tabPadding.PaddingLeft = UDim.new(0,10); tabPadding.PaddingRight = UDim.new(0,10); tabPadding.Parent = tabButton
		tabs[name] = tabButton

		tabButton.MouseButton1Click:Connect(function()
			for tabName, otherPage in pairs(pages) do
				local isActive = (tabName == name)
				otherPage.Visible = isActive
				tabs[tabName].BackgroundColor3 = isActive and Theme.Colors.TabActive or Theme.Colors.TabInactive
				if tabName == "Explorer" and isActive then
					for _, child in ipairs(otherPage:GetChildren()) do if not child:IsA("UILayout") then child:Destroy() end end
					pcall(function() createEntry(player, otherPage, 0) end)
					pcall(function() if player.Character then createEntry(player.Character, otherPage, 0) end end)
				end
			end
		end)
		return page
	end

	local actionsPage = createTab("Actions")
	local explorerPage = createTab("Explorer")
	if player == localPlayer then
		local localPowersPage = createTab("Local Powers")
		local keybindsPage = createTab("Keybinds")

		keybindsPage:FindFirstChildOfClass("UIGridLayout"):Destroy()
		local keybindListLayout = Instance.new("UIListLayout")
		keybindListLayout.Padding = UDim.new(0, 5)
		keybindListLayout.Parent = keybindsPage

		-- Create all keybind buttons
		for id, bindInfo in pairs(keybinds) do
			createKeybindButton(id, bindInfo, keybindsPage)
		end

		-- Add sliders for Local Powers
		localPowersPage:FindFirstChildOfClass("UIGridLayout"):Destroy()
		local powersListLayout = Instance.new("UIListLayout")
		powersListLayout.Padding = UDim.new(0, 10)
		powersListLayout.Parent = localPowersPage

		createSlider("Walk Speed", 16, 200, localPlayerSettings.walkSpeed, localPowersPage, function(value)
			localPlayerSettings.walkSpeed = value
			if playerFunctionStates[localPlayer].speedBoost then
				pcall(function() localPlayer.Character.Humanoid.WalkSpeed = value end)
			end
		end)
		createSlider("Fly Speed", 25, 500, localPlayerSettings.flySpeed, localPowersPage, function(value)
			localPlayerSettings.flySpeed = value
		end)
	end

	-- Set default tab
	tabs["Actions"].BackgroundColor3 = Theme.Colors.TabActive
	pages["Actions"].Visible = true
	explorerPage:FindFirstChildOfClass("UIGridLayout"):Destroy() -- Explorer uses ListLayout
	local explorerListLayout = Instance.new("UIListLayout"); explorerListLayout.Padding = UDim.new(0, 1); explorerListLayout.Parent = explorerPage

	local function createActionButton(text, iconChar, color, callback, parentFrame)
		local button = Instance.new("TextButton"); button.Name = text; button.Text = ""; button.BackgroundColor3 = color
		button.BorderSizePixel = 0; button.AutoButtonColor = false; button.Parent = parentFrame
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = button
		local buttonIcon = Instance.new("TextLabel"); buttonIcon.Size = UDim2.fromScale(0.25, 1); buttonIcon.BackgroundTransparency = 1
		buttonIcon.Font = Theme.Fonts.Header; buttonIcon.Text = iconChar; buttonIcon.TextColor3 = Theme.Colors.Text
		buttonIcon.TextSize = 18; buttonIcon.Parent = button
		local buttonLabel = Instance.new("TextLabel"); buttonLabel.Size = UDim2.fromScale(0.75, 1); buttonLabel.Position = UDim2.fromScale(0.25, 0)
		buttonLabel.BackgroundTransparency = 1; buttonLabel.Font = Theme.Fonts.Regular; buttonLabel.Text = text
		buttonLabel.TextColor3 = Theme.Colors.Text; buttonLabel.TextSize = 15; buttonLabel.TextXAlignment = Enum.TextXAlignment.Left
		buttonLabel.Parent = button
		button.MouseEnter:Connect(function() TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = color:lerp(Color3.new(1,1,1), 0.2)}):Play() end)
		button.MouseLeave:Connect(function() TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play() end)
		if callback then button.MouseButton1Click:Connect(callback) end
		return button
	end

	-- Create action buttons
	createActionButton("Kill", "☠", Theme.Colors.Error, function() pcall(function() player.Character.Humanoid.Health = 0 end); showToast("Kill executed", Theme.Colors.Error) end, actionsPage)
	createActionButton("Freeze", "❄", Color3.fromRGB(119, 191, 243), function() playerFunctionStates[player].isFrozen = not playerFunctionStates[player].isFrozen; showToast("Freeze " .. (playerFunctionStates[player].isFrozen and "ON" or "OFF"), playerFunctionStates[player].isFrozen and Theme.Colors.Success or Theme.Colors.Error) end, actionsPage)
	createActionButton("Teleport To", "➡", Theme.Colors.Accent, function() pcall(function() localPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame; showToast("Teleported to " .. player.Name, Theme.Colors.Success) end) end, actionsPage)
	createActionButton("Bring Here", "⬅", Theme.Colors.Accent, function() pcall(function() player.Character.HumanoidRootPart.CFrame = localPlayer.Character.HumanoidRootPart.CFrame; showToast(player.Name .. " brought here", Theme.Colors.Success) end) end, actionsPage)
	createActionButton("Godmode", "✚", Theme.Colors.Warning, function() playerFunctionStates[player].isGodmode = not playerFunctionStates[player].isGodmode; showToast("Godmode " .. (playerFunctionStates[player].isGodmode and "ON" or "OFF"), playerFunctionStates[player].isGodmode and Theme.Colors.Success or Theme.Colors.Error) end, actionsPage)
	createActionButton("ESP", "▣", Color3.fromRGB(212, 119, 243), function() playerFunctionStates[player].isESP = not playerFunctionStates[player].isESP; showToast("ESP " .. (playerFunctionStates[player].isESP and "ON" or "OFF"), playerFunctionStates[player].isESP and Theme.Colors.Success or Theme.Colors.Error) end, actionsPage)

	-- Local player only buttons (for display, logic is handled by keybinds)
	if player == localPlayer then
		createActionButton("Fly", "✈", Theme.Colors.ToggleOff, function() playerFunctionStates[localPlayer].isFlying = not playerFunctionStates[localPlayer].isFlying; showToast("Fly " .. (playerFunctionStates[player].isFlying and "ON" or "OFF"), playerFunctionStates[player].isFlying and Theme.Colors.Success or Theme.Colors.Error) end, actionsPage)
		createActionButton("Speed", "⚡", Theme.Colors.ToggleOff, function() playerFunctionStates[localPlayer].speedBoost = not playerFunctionStates[localPlayer].speedBoost; showToast("Speed " .. (playerFunctionStates[player].speedBoost and "ON" or "OFF"), playerFunctionStates[player].speedBoost and Theme.Colors.Success or Theme.Colors.Error) end, actionsPage)
	end

	playerFrames[player] = { MainFrame = playerMainFrame, Connection = nil, ESPBox = nil }

	-- [FIXED] This block now correctly calculates height, animates smoothly, and has the correct syntax.
	playerHeader.MouseButton1Click:Connect(function()
		uiState[player.Name] = not uiState[player.Name]
		local isExpanded = uiState[player.Name]

		-- Manually calculate the content height to avoid issues with AbsoluteSize on hidden elements.
		local contentHeight = tabContainer.Size.Y.Offset 
			+ pagesScrollingFrame.Size.Y.Offset 
			+ detailsLayout.Padding.Offset 
			+ detailsPadding.PaddingTop.Offset 
			+ detailsPadding.PaddingBottom.Offset

		local targetHeight = isExpanded and (40 + contentHeight) or 40

		-- Animate the frame size for a smooth expand/collapse effect
		local tweenInfo = TweenInfo.new(Theme.Animation.Speed, Theme.Animation.Easing, Theme.Animation.Direction)
		local goal = { Size = UDim2.new(1, -20, 0, targetHeight) }
		local tween = TweenService:Create(playerMainFrame, tweenInfo, goal)
		tween:Play()

		-- Show/hide the container and update icon
		detailsContainer.Visible = isExpanded
		icon.Text = isExpanded and "v" or ">"

		-- If we are expanding into the Explorer tab, refresh its content
		if isExpanded and pages["Explorer"].Visible then
			for _, child in ipairs(pages["Explorer"]:GetChildren()) do 
				if not child:IsA("UILayout") then child:Destroy() end 
			end
			pcall(function() createEntry(player, pages["Explorer"], 0) end)
			pcall(function() if player.Character then createEntry(player.Character, pages["Explorer"], 0) end end)
		end
	end)

	local espBox = Instance.new("BoxHandleAdornment"); espBox.Name = "ESP_Box"; espBox.AlwaysOnTop = true
	espBox.ZIndex = 5; espBox.Size = Vector3.new(4, 6, 2); espBox.Transparency = 0.5
	espBox.Visible = false; espBox.Parent = screenGui

	local connection = RunService.RenderStepped:Connect(function()
		if not playerFrames[player] or not playerFunctionStates[player] then return end
		local state = playerFunctionStates[player]
		pcall(function()
			local char = player.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if not humanoid then espBox.Visible = false; return end
			humanoid.PlatformStand = state.isFrozen
			humanoid.MaxHealth = state.isGodmode and math.huge or 100
			if state.isGodmode then humanoid.Health = humanoid.MaxHealth end

			if player == localPlayer then
				humanoid.WalkSpeed = state.speedBoost and localPlayerSettings.walkSpeed or 16
			end

			if state.isESP and char:FindFirstChild("HumanoidRootPart") then
				espBox.Adornee = char.HumanoidRootPart; espBox.Visible = true
				espBox.Color3 = (player.Team and player.Team == localPlayer.Team) and Theme.Colors.Success or Theme.Colors.Error
			else espBox.Visible = false end
		end)
	end)
	playerFrames[player].Connection = connection; playerFrames[player].ESPBox = espBox
end

-- Function to remove player entry
local function onPlayerRemoving(player)
	if playerFrames[player] then
		if playerFrames[player].Connection then playerFrames[player].Connection:Disconnect() end
		if playerFrames[player].ESPBox then playerFrames[player].ESPBox:Destroy() end
		if playerFrames[player].MainFrame then playerFrames[player].MainFrame:Destroy() end
		playerFrames[player] = nil; playerFunctionStates[player] = nil; uiState[player.Name] = nil
		if selectedPlayer == player then selectedPlayer = nil end
	end
end

-- #region Local Player Power Handlers
local flyGyro, flyVelocity
local function updateFly(state)
	pcall(function()
		local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not state or not hrp then
			if flyGyro then flyGyro:Destroy(); flyGyro = nil end
			if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
			local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.PlatformStand then humanoid.PlatformStand = false end
			return
		end

		local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end; humanoid.PlatformStand = true

		if not flyGyro or flyGyro.Parent ~= hrp then
			flyGyro = Instance.new("BodyGyro", hrp)
			flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			flyGyro.D = 100
			flyGyro.P = 5000
		end
		if not flyVelocity or flyVelocity.Parent ~= hrp then
			flyVelocity = Instance.new("BodyVelocity", hrp)
			flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			flyVelocity.P = 1250
		end

		flyGyro.CFrame = workspace.CurrentCamera.CFrame
		local moveVector = Vector3.new()
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += Vector3.new(0,0,-1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector += Vector3.new(0,0,1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector += Vector3.new(-1,0,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += Vector3.new(1,0,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector += Vector3.new(0,1,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveVector += Vector3.new(0,-1,0) end

		if moveVector.Magnitude > 0 then
			flyVelocity.Velocity = (workspace.CurrentCamera.CFrame.LookVector * -moveVector.Z + workspace.CurrentCamera.CFrame.RightVector * moveVector.X + Vector3.new(0, moveVector.Y, 0)).Unit * localPlayerSettings.flySpeed
		else
			flyVelocity.Velocity = Vector3.new()
		end
	end)
end


table.insert(globalConnections, RunService.RenderStepped:Connect(function()
	if playerFunctionStates[localPlayer] then
		updateFly(playerFunctionStates[localPlayer].isFlying)
	end
end))

-- Handle keybinds
table.insert(globalConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed and not isBindingKey then return end

	if isBindingKey and activeKeybindButton then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			local bindId = activeKeybindButton.Parent.Name:gsub("KeybindFrame", "")

			keybinds[bindId].key = key
			activeKeybindButton.Text = key.Name
			activeKeybindButton.BackgroundColor3 = Theme.Colors.Secondary
			showToast(keybinds[bindId].name .. " key set to " .. key.Name, Theme.Colors.Success)
			isBindingKey = false
			activeKeybindButton = nil
		end
		return
	end

	-- Check for action keybinds
	for id, bindInfo in pairs(keybinds) do
		if input.KeyCode == bindInfo.key then
			if id == "toggleUi" then
				mainContainer.Visible = not mainContainer.Visible
				showToast("UI " .. (mainContainer.Visible and "Unhidden" or "Hidden"), mainContainer.Visible and Theme.Colors.Success or Theme.Colors.Error)
			elseif playerFunctionStates[localPlayer] then
				if id == "fly" then
					playerFunctionStates[localPlayer].isFlying = not playerFunctionStates[localPlayer].isFlying
					showToast("Fly " .. (playerFunctionStates[localPlayer].isFlying and "ON" or "OFF"), playerFunctionStates[localPlayer].isFlying and Theme.Colors.Success or Theme.Colors.Error)
				elseif id == "speed" then
					playerFunctionStates[localPlayer].speedBoost = not playerFunctionStates[localPlayer].speedBoost
					showToast("Speed " .. (playerFunctionStates[localPlayer].speedBoost and "ON" or "OFF"), playerFunctionStates[localPlayer].speedBoost and Theme.Colors.Success or Theme.Colors.Error)
				end
			end
		end
	end
end))
-- #endregion

-- Main function to initialize
local function initialize()
	for _, player in ipairs(Players:GetPlayers()) do createPlayerEntry(player) end
	table.insert(globalConnections, Players.PlayerAdded:Connect(createPlayerEntry))
	table.insert(globalConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))
end

-- Graceful shutdown when the script is destroyed
script.Destroying:Connect(cleanupAndDestroy)

initialize()
showToast("Enhanced Player-Explorer Loaded!", Theme.Colors.Success)
print("CLIENT: Enhanced Player Explorer v33.1 finished loading.")
