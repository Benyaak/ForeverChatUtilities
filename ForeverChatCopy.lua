local addonName, FCC = ...

-- Compatibility shims across WoW Forever (16001 / camelot), Classic Era, and Mainline
local issecretvalue = issecretvalue or function() return false end
local AddMessageEventFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
local MAX_STATIC_CHAT_FRAMES = NUM_CHAT_WINDOWS or 10
local MAX_TOTAL_CHAT_FRAMES = 50

local DEFAULT_DB = {
	stripColors = false,
	interactiveLinks = false,
	urlColor = "00ccff",
}

local COMMON_TLDS = {
	com = true, org = true, net = true, gg = true, io = true, tv = true,
	me = true, co = true, uk = true, de = true, fr = true, eu = true,
	us = true, ca = true, au = true, ru = true, dev = true, app = true,
	xyz = true, info = true, edu = true, gov = true, be = true, ly = true,
	ai = true, cc = true, to = true, fm = true, tk = true, ch = true,
	nl = true, se = true, no = true, pl = true, es = true, it = true,
	br = true, jp = true, kr = true, cn = true, ro = true,
}

local CHAT_EVENTS = {
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_EMOTE",
	"CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_BN_WHISPER_INFORM",
	"CHAT_MSG_BN_INLINE_TOAST_BROADCAST",
	"CHAT_MSG_SYSTEM",
}

local hookedFrames = setmetatable({}, { __mode = "k" })

local function EnsureDB()
	if type(ForeverChatCopyDB) ~= "table" then
		ForeverChatCopyDB = {}
	end
	for key, defaultVal in pairs(DEFAULT_DB) do
		if ForeverChatCopyDB[key] == nil then
			ForeverChatCopyDB[key] = defaultVal
		end
	end
end

local function GetURLColor()
	if ForeverChatCopyDB and type(ForeverChatCopyDB.urlColor) == "string" and ForeverChatCopyDB.urlColor:match("^%x%x%x%x%x%x$") then
		return ForeverChatCopyDB.urlColor
	end
	return DEFAULT_DB.urlColor
end

local function ApplyBackdrop(frame, bgAlpha)
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.05, 0.05, 0.07, bgAlpha or 0.94)
	frame:SetBackdropBorderColor(0.65, 0.65, 0.7, 1)
end

local function MakeMovable(frame)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetClampedToScreen(true)
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
end

local function ExtractURLFromHyperlinkText(text)
	if not text or issecretvalue(text) then return nil end
	local cleaned = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]+:", ""):gsub("|r", "")
	cleaned = cleaned:gsub("^|H.-|h", ""):gsub("|h$", "")
	cleaned = cleaned:match("^%[(.*)%]$") or cleaned
	return cleaned
end

-- Protect existing WoW escape sequences before scanning plain text for URLs.
local function ProtectEscapes(msg)
	local saved = {}
	local function stash(match)
		saved[#saved + 1] = match
		return "\001" .. #saved .. "\002"
	end

	local out = msg:gsub("||", stash)
	out = out:gsub("|H.-|h.-|h", stash)
	out = out:gsub("|T.-|t", stash)
	out = out:gsub("|A.-|a", stash)
	out = out:gsub("|K.-|k", stash)
	out = out:gsub("|cn[^:]+:", stash)
	out = out:gsub("|c%x%x%x%x%x%x%x%x", stash)
	out = out:gsub("|r", stash)
	return out, saved
end

local function RestoreEscapes(msg, saved)
	if #saved == 0 then return msg end
	return (msg:gsub("\001(%d+)\002", function(idx)
		return saved[tonumber(idx)] or ""
	end))
end

local function CountChar(str, ch)
	local count = 0
	local start = 1
	while true do
		local pos = str:find(ch, start, true)
		if not pos then break end
		count = count + 1
		start = pos + 1
	end
	return count
end

local function TrimTokenWrappers(token)
	local prefix = ""
	local suffix = ""
	local core = token

	while #core > 0 do
		local first = core:sub(1, 1)
		if first == "(" or first == "[" or first == "{" or first == "<" or first == '"' or first == "'" then
			prefix = prefix .. first
			core = core:sub(2)
		else
			break
		end
	end

	-- Handle inline prefixes like "link:https://..." or "url=https://..."
	local protoStart = core:find("https?://") or core:find("ftp://")
	if protoStart and protoStart > 1 then
		local lead = core:sub(1, protoStart - 1)
		if lead:match("^[^/]+[:=]$") then
			prefix = prefix .. lead
			core = core:sub(protoStart)
		end
	end

	while #core > 0 do
		local last = core:sub(-1)
		if last == "." or last == "," or last == ";" or last == "!" or last == "?" or last == ":" or last == '"' or last == "'" or last == ">" or last == "}" then
			suffix = last .. suffix
			core = core:sub(1, -2)
		elseif last == ")" and CountChar(core, ")") > CountChar(core, "(") then
			suffix = last .. suffix
			core = core:sub(1, -2)
		elseif last == "]" and CountChar(core, "]") > CountChar(core, "[") then
			suffix = last .. suffix
			core = core:sub(1, -2)
		else
			break
		end
	end

	return prefix, core, suffix
end

local function IsValidURL(candidate)
	if #candidate < 4 then return false end
	if candidate:find("[%s%c\"|<>]") then return false end

	if candidate:match("^https?://[%w%-%.]+") or candidate:match("^ftp://[%w%-%.]+") then
		return true
	end

	if candidate:match("^www%.[%w%-%.]+%.[%a][%a]+") then
		return true
	end

	-- Host + path or query (e.g., discord.gg/abc, wowhead.com/classic, example.org:8080/test, wowhead.com?item=1)
	local host, path = candidate:match("^([^/?:#]+)(:?%d*[/?].+)$")
	if host and path then
		local tld = host:match("%.([%a]+)$")
		if tld and #tld >= 2 and host:match("^[%a%d][%w%-%.]*%.[%a]+$") then
			return true
		end
	end

	-- Bare domain (must match a known TLD to avoid false positives like 5.5k, 1.60.1, or file.lua)
	local bareHost = candidate:match("^([^/:]+)")
	if bareHost and (candidate == bareHost or candidate:match("^[^/:]+:%d+$")) then
		local tld = bareHost:match("%.([%a]+)$")
		if tld and COMMON_TLDS[tld:lower()] and bareHost:match("^[%a][%w%-%.]*%.[%a]+$") then
			return true
		end
	end

	return false
end

local function FormatURLHyperlink(url)
	return "|cff" .. GetURLColor() .. "|Hgarrmission:FCC:|h[" .. url .. "]|h|r"
end

function FCC:LinkifyURLs(msg)
	if not msg or issecretvalue(msg) then return msg, false end
	local protected, saved = ProtectEscapes(msg)
	local changed = false

	local linked = protected:gsub("([^%s%c]+)", function(token)
		local prefix, core, suffix = TrimTokenWrappers(token)
		if IsValidURL(core) then
			changed = true
			return prefix .. FormatURLHyperlink(core) .. suffix
		end
		return token
	end)

	if not changed then
		return msg, false
	end
	return RestoreEscapes(linked, saved), true
end

local function URLFilter(_, _, msg, ...)
	if not msg or issecretvalue(msg) then return end
	local newMsg, changed = FCC:LinkifyURLs(msg)
	if changed then
		return false, newMsg, ...
	end
end

local function CreateURLPopup()
	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local popup = CreateFrame("Frame", "ForeverChatCopyURLPopup", UIParent, template)
	popup:SetSize(520, 100)
	popup:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	popup:SetFrameStrata("DIALOG")
	popup:SetFrameLevel(100)
	popup:Hide()
	ApplyBackdrop(popup, 0.96)
	MakeMovable(popup)

	if UISpecialFrames then
		table.insert(UISpecialFrames, "ForeverChatCopyURLPopup")
	end

	local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -3, -3)
	closeBtn:SetScript("OnClick", function()
		popup:Hide()
	end)

	local label = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -16)
	label:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
	label:SetJustifyH("LEFT")
	label:SetText("Press Ctrl+C (or Cmd+C) to copy link:")
	popup.label = label

	local editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
	editBox:SetSize(480, 28)
	editBox:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 20, 18)
	editBox:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -20, 18)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnEscapePressed", function()
		popup:Hide()
	end)
	editBox:SetScript("OnEnterPressed", function()
		popup:Hide()
	end)
	editBox:SetScript("OnKeyUp", function(self, key)
		local isCopyKey = (key == "C" or key == "c")
		local hasCopyModifier = IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())
		if isCopyKey and hasCopyModifier then
			label:SetText("|cff00ff00Link copied to clipboard!|r")
			self:HighlightText(0)
		end
	end)
	popup.editBox = editBox

	FCC.urlPopup = popup
	return popup
end

function FCC:ShowURLPopup(url)
	if not url or url == "" then return end
	local popup = self.urlPopup or CreateURLPopup()
	popup.label:SetText("Press Ctrl+C (or Cmd+C) to copy link:")
	popup.editBox:SetText(url)
	popup:Show()
	popup.editBox:SetFocus()
	popup.editBox:HighlightText(0)
end

local function GetChatFrameTitle(chatFrame)
	local id = chatFrame and chatFrame.GetID and chatFrame:GetID()
	if id and FCF_GetChatWindowInfo then
		local name = FCF_GetChatWindowInfo(id)
		if name and name ~= "" then
			return name
		end
	end
	local frameName = chatFrame and chatFrame.GetName and chatFrame:GetName()
	local tab = frameName and _G[frameName .. "Tab"]
	if tab and tab.GetText then
		local tabText = tab:GetText()
		if tabText and tabText ~= "" then
			return tabText
		end
	end
	return frameName or "Chat"
end

local function SanitizeChatLine(helperFont, rawLine, interactiveLinks, stripColors)
	if not rawLine or issecretvalue(rawLine) then return nil end

	helperFont:SetText(rawLine .. "\n")
	local line = helperFont:GetText()
	if not line or issecretvalue(line) then return nil end

	-- Convert raid target markers into readable {rtN} tags and strip other textures/atlases
	line = line:gsub("|T[^\\]+\\[^\\]+\\[Uu][Ii]%-[Rr][Aa][Ii][Dd][Tt][Aa][Rr][Gg][Ee][Tt][Ii][Nn][Gg][Ii][Cc][Oo][Nn]_(%d)[^|]+|t", "{rt%1}")
	line = line:gsub("|T13700([1-8])[^|]+|t", "{rt%1}")
	line = line:gsub("|T[^|]+|t", "")
	line = line:gsub("|A[^|]+|a", "")
	line = line:gsub("|K[^|]+|k", "[BNet]")

	if interactiveLinks then
		line = FCC:LinkifyURLs(line)
	else
		line = line:gsub("|Hgarrmission:FCC:|h%[(.-)%]|h", "%1")
		line = line:gsub("|H.-|h(.-)|h", "%1")
	end

	if stripColors then
		line = line:gsub("|c%x%x%x%x%x%x%x%x", "")
		line = line:gsub("|cn[^:]+:", "")
		line = line:gsub("|r", "")
	end

	return line
end

local function UpdateCopyWindowButtons(frame)
	EnsureDB()
	if ForeverChatCopyDB.interactiveLinks then
		frame.modeBtn:SetText("Mode: Click Links")
		frame.hintText:SetText("Click any link below (Shift-click to paste in chat)")
		frame.editBox:SetHyperlinksEnabled(true)
	else
		frame.modeBtn:SetText("Mode: Copy Text")
		frame.hintText:SetText("Highlight text & press Ctrl+C / Cmd+C")
		frame.editBox:SetHyperlinksEnabled(false)
	end

	if ForeverChatCopyDB.stripColors then
		frame.colorBtn:SetText("Colors: OFF")
	else
		frame.colorBtn:SetText("Colors: ON")
	end
end

local function PopulateCopyWindow(frame)
	local chatFrame = frame.activeChatFrame or DEFAULT_CHAT_FRAME
	if not chatFrame or not chatFrame.GetNumMessages then return end

	UpdateCopyWindowButtons(frame)
	frame.titleText:SetText("Chat Copy - " .. GetChatFrameTitle(chatFrame))

	local interactiveLinks = ForeverChatCopyDB.interactiveLinks
	local stripColors = ForeverChatCopyDB.stripColors
	local lines = {}
	local numMessages = chatFrame:GetNumMessages()

	for i = 1, numMessages do
		local rawLine = chatFrame:GetMessageInfo(i)
		local cleanLine = SanitizeChatLine(frame.helperFont, rawLine, interactiveLinks, stripColors)
		if cleanLine then
			lines[#lines + 1] = cleanLine
		end
	end

	local fullText = table.concat(lines)
	frame.editBox:SetText(fullText)
	frame.scrollFrame:UpdateScrollChildRect()

	C_Timer.After(0, function()
		if frame:IsShown() and frame.scrollFrame and frame.scrollFrame.GetVerticalScrollRange then
			local maxScroll = frame.scrollFrame:GetVerticalScrollRange() or 0
			frame.scrollFrame:SetVerticalScroll(maxScroll)
		end
	end)
end

local function CreateToolbarButton(parent, width, text, onClick)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width, 22)
	btn:SetText(text)
	btn:SetScript("OnClick", onClick)
	return btn
end

local function CreateCopyWindow()
	local frameTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "ForeverChatCopyFrame", UIParent, frameTemplate)
	frame:SetSize(720, 520)
	frame:SetPoint("CENTER", UIParent, "CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(50)
	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(440, 260, 1200, 900)
	elseif frame.SetMinResize then
		frame:SetMinResize(440, 260)
		frame:SetMaxResize(1200, 900)
	end
	frame:Hide()
	ApplyBackdrop(frame, 0.95)
	MakeMovable(frame)

	if UISpecialFrames then
		table.insert(UISpecialFrames, "ForeverChatCopyFrame")
	end

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)

	local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
	titleText:SetText("Chat Copy")
	frame.titleText = titleText

	local hintText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hintText:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
	hintText:SetTextColor(0.75, 0.85, 0.95)
	frame.hintText = hintText

	local selectAllBtn = CreateToolbarButton(frame, 90, "Select All", function()
		if ForeverChatCopyDB.interactiveLinks then
			ForeverChatCopyDB.interactiveLinks = false
			PopulateCopyWindow(frame)
		end
		frame.editBox:SetFocus()
		frame.editBox:HighlightText(0)
	end)
	selectAllBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -36)

	local modeBtn = CreateToolbarButton(frame, 130, "Mode: Copy Text", function()
		ForeverChatCopyDB.interactiveLinks = not ForeverChatCopyDB.interactiveLinks
		PopulateCopyWindow(frame)
	end)
	modeBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 6, 0)
	frame.modeBtn = modeBtn

	local colorBtn = CreateToolbarButton(frame, 95, "Colors: ON", function()
		ForeverChatCopyDB.stripColors = not ForeverChatCopyDB.stripColors
		PopulateCopyWindow(frame)
	end)
	colorBtn:SetPoint("LEFT", modeBtn, "RIGHT", 6, 0)
	frame.colorBtn = colorBtn

	local refreshBtn = CreateToolbarButton(frame, 80, "Refresh", function()
		PopulateCopyWindow(frame)
	end)
	refreshBtn:SetPoint("LEFT", colorBtn, "RIGHT", 6, 0)

	local scrollTemplate = "ScrollFrameTemplate"
	if C_XMLUtil and C_XMLUtil.GetTemplateInfo and not C_XMLUtil.GetTemplateInfo("ScrollFrameTemplate") then
		scrollTemplate = "UIPanelScrollFrameTemplate"
	end

	local scrollFrame = CreateFrame("ScrollFrame", "ForeverChatCopyScrollFrame", frame, scrollTemplate)
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -66)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 16)
	frame.scrollFrame = scrollFrame

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	editBox:SetMultiLine(true)
	editBox:SetMaxLetters(0)
	editBox:EnableMouse(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetWidth(670)
	editBox:SetHeight(430)
	editBox:SetTextInsets(4, 4, 4, 4)
	editBox:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	editBox:SetScript("OnTextChanged", function()
		scrollFrame:UpdateScrollChildRect()
	end)
	editBox:SetScript("OnHyperlinkClick", function(_, link, text, button)
		if not link then return end
		local linkType, addonTag = strsplit(":", link)
		if linkType == "garrmission" and addonTag == "FCC" then
			local url = ExtractURLFromHyperlinkText(text)
			if url and url ~= "" then
				if IsShiftKeyDown() and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
					ChatEdit_InsertLink(url)
				else
					FCC:ShowURLPopup(url)
				end
			end
			return
		end
		if SetItemRef then
			SetItemRef(link, text, button)
		end
	end)
	editBox:SetScript("OnHyperlinkEnter", function(self, link, text)
		if not link or not GameTooltip then return end
		local linkType, addonTag = strsplit(":", link)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		if linkType == "garrmission" and addonTag == "FCC" then
			local url = ExtractURLFromHyperlinkText(text)
			GameTooltip:AddLine(url or "Link", 0, 0.8, 1, true)
			GameTooltip:AddLine("Click to copy URL", 1, 1, 1)
			GameTooltip:Show()
		elseif GameTooltip.SetHyperlink then
			local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
			if ok then
				GameTooltip:Show()
			else
				GameTooltip:Hide()
			end
		end
	end)
	editBox:SetScript("OnHyperlinkLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	scrollFrame:SetScrollChild(editBox)
	scrollFrame:SetScript("OnMouseDown", function()
		if not ForeverChatCopyDB.interactiveLinks then
			editBox:SetFocus()
		end
	end)
	scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
		editBox:SetWidth(math.max(100, (width or self:GetWidth()) - 12))
		editBox:SetHeight(math.max(100, (height or self:GetHeight()) - 8))
		self:UpdateScrollChildRect()
	end)
	frame.editBox = editBox

	local helperFont = frame:CreateFontString(nil, nil, "GameFontNormal")
	helperFont:Hide()
	frame.helperFont = helperFont

	local resizeBtn = CreateFrame("Button", nil, frame)
	resizeBtn:SetSize(16, 16)
	resizeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
	resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	resizeBtn:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			frame:StartSizing("BOTTOMRIGHT")
		end
	end)
	resizeBtn:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
	end)

	FCC.copyFrame = frame
	return frame
end

function FCC:OpenCopyWindow(chatFrame, forceInteractive)
	EnsureDB()
	local targetFrame = chatFrame or SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	local frame = self.copyFrame or CreateCopyWindow()

	if forceInteractive ~= nil then
		ForeverChatCopyDB.interactiveLinks = forceInteractive
	end

	frame.activeChatFrame = targetFrame
	PopulateCopyWindow(frame)
	frame:Show()
end

local function AttachToChatFrame(chatFrame, index)
	if not chatFrame or hookedFrames[chatFrame] then return end
	hookedFrames[chatFrame] = true

	local frameName = chatFrame:GetName()
	local tab = frameName and _G[frameName .. "Tab"]
	if tab and tab.HookScript then
		tab:HookScript("OnClick", function(_, button)
			if button == "LeftButton" and IsShiftKeyDown() then
				FCC:OpenCopyWindow(chatFrame)
			end
		end)
	end

	-- Skip placing an overlay button on ChatFrame2 (Combat Log) to avoid colliding with its filter bar
	if index == 2 then return end

	local copyBtn = CreateFrame("Button", nil, chatFrame)
	copyBtn:SetSize(20, 20)
	copyBtn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -4, -4)
	copyBtn:SetFrameLevel(chatFrame:GetFrameLevel() + 5)
	copyBtn:SetAlpha(0.35)
	copyBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
	copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

	copyBtn:SetScript("OnEnter", function(self)
		self:SetAlpha(1.0)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("ForeverChatCopy", 0, 0.8, 1)
			GameTooltip:AddLine("Left-Click: Open Chat Copy Window", 1, 1, 1)
			GameTooltip:AddLine("Right-Click: Open in Click Links Mode", 0.85, 0.85, 0.85)
			GameTooltip:Show()
		end
	end)
	copyBtn:SetScript("OnLeave", function(self)
		self:SetAlpha(0.35)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	copyBtn:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			FCC:OpenCopyWindow(chatFrame, true)
			return
		end
		if FCC.copyFrame and FCC.copyFrame:IsShown() and FCC.copyFrame.activeChatFrame == chatFrame then
			FCC.copyFrame:Hide()
		else
			FCC:OpenCopyWindow(chatFrame)
		end
	end)
end

local function AttachAllChatFrames()
	for i = 1, MAX_TOTAL_CHAT_FRAMES do
		local chatFrame = _G["ChatFrame" .. i]
		if chatFrame then
			AttachToChatFrame(chatFrame, i)
		elseif i > MAX_STATIC_CHAT_FRAMES then
			break
		end
	end
end

-- Register chat message filters immediately so login/MOTD/initial messages are linkified
for _, eventName in ipairs(CHAT_EVENTS) do
	AddMessageEventFilter(eventName, URLFilter)
end

-- Securely observe SetItemRef without overwriting it (zero taint)
hooksecurefunc("SetItemRef", function(link, text)
	if not link or issecretvalue(link) then return end
	local linkType, addonTag = strsplit(":", link)
	if linkType == "garrmission" and addonTag == "FCC" then
		local url = ExtractURLFromHyperlinkText(text)
		if url and url ~= "" then
			if IsShiftKeyDown() and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
				ChatEdit_InsertLink(url)
			else
				FCC:ShowURLPopup(url)
			end
		end
	end
end)

-- Register slash commands
SLASH_FOREVERCHATCOPY1 = "/chatcopy"
SLASH_FOREVERCHATCOPY2 = "/copychat"
SLASH_FOREVERCHATCOPY3 = "/cc"
SlashCmdList["FOREVERCHATCOPY"] = function()
	FCC:OpenCopyWindow(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		EnsureDB()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		AttachAllChatFrames()
		if hooksecurefunc and FCF_OpenTemporaryWindow then
			hooksecurefunc("FCF_OpenTemporaryWindow", AttachAllChatFrames)
		end
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)
