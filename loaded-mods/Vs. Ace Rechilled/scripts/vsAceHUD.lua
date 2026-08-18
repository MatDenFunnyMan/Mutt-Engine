luaDebugMode = true

local path = 'healthbar/'

local hpBarY = 600
local health = 1 -- intial game health, aka 50% hp

-- had to make icons a bit smaller cause they looked off so... yeap
local iconScale = 0.9
local curIconScale = 0.9

local ratingSys = {
	["sick"] = {"SICK!!", "EEEB43"},
	["good"] = {"GOOD!", "1C98CA"},
	["bad"] = {"BAD", "FF0000"},
	["shit"] = {"SHIT", "FF0000"}
}

local dadImage = "icons/ace"

local barX, barY, barWidth = 0, 0, 0
local lastAceColor, lastBfColor
local lastSentHP, lastCombo, lastAcc, lastTime
local lastIconFrame = -1

local floor = math.floor
local format = string.format

-- math functions maaannn fuck this shit dawg
local function lerp(min, max, ratio)
	return min + ratio * (max-min)
end

local function boundTo(val, min, max)
	return math.max(min, math.min(max, val))
end

local function createLuaSprite(tag, img, x, y, alpha)
	makeLuaSprite(tag, path..img, x, y)
	setProperty(tag..'.alpha', alpha)
	setProperty(tag..'.antialiasing', true)
	setScrollFactor(tag, 1, 1)
	addLuaSprite(tag)
end

local function createLuaText(tag, strng, width, posX, posY, foreground, align, size, camera, color, outlineSize, outlineColor)
	makeLuaText(tag, strng, width, posX, posY)
	addLuaText(tag, foreground)
	setTextAlignment(tag, align)
	setTextSize(tag, size)
	setTextFont(tag, "retrohud.ttf")
	setObjectCamera(tag, camera)
	setTextColor(tag, color)
	setTextBorder(tag, outlineSize, outlineColor)
end

local function setComboString(str)
	if str ~= lastCombo then
		setTextString("retroComboNumber", str)
		lastCombo = str
	end
end

local function checkImageExists(image)
	return checkFileExists("images/"..image..".png")
end

local function findIcon(icon)
	local img = "icons/icon-"..icon
	if not checkImageExists(img) then
		img = "icons/"..icon
		if not checkImageExists(img) then
			img = nil
		end
	end
	return img
end

local function reloadIcons()
	dadImage = findIcon(getProperty("dad.healthIcon"))

	if dadImage ~= nil then
		makeLuaSprite("iconThing", dadImage) -- opponent icon lol!!!!
		local dadWidthLol = getProperty("iconThing.width")/3
		loadGraphic("iconP2", dadImage, dadWidthLol, getProperty("iconThing.height"))
		removeLuaSprite("iconThing", true)
		addAnimation("iconP2", "iconLol!", {0, 1, 2}, 0, false)
		playAnim("iconP2", "iconLol!", 0)
		lastIconFrame = 0
	end
end

function onCreatePost()
	if downscroll then hpBarY = 30 end
	setProperty('healthBar.visible', false)
	setProperty("timeBar.visible", false)
	setProperty("timeTxt.visible", false)
	setProperty("scoreTxt.visible", false)

	-- Ace bar
	createLuaSprite('aceBar', 'bar', 0, hpBarY, 1)
	scaleObject('aceBar', 0.5, 0.5)
	setObjectCamera('aceBar', 'camHUD')
	screenCenter('aceBar', 'x')
	updateHitbox('aceBar')

	-- BF bar
	createLuaSprite('bfBar', 'bar', 0, hpBarY, 1)
	scaleObject('bfBar', 0.5, 0.5)
	setObjectCamera('bfBar', 'camHUD')
	screenCenter('bfBar', 'x')
	updateHitbox('bfBar')

	-- overlay
	createLuaSprite('barOver', 'overlay', 0, hpBarY, 1)
	scaleObject('barOver', 0.5, 0.5)
	setObjectCamera('barOver', 'camHUD')
	screenCenter('barOver', 'x')
	updateHitbox('barOver')

	barX = getProperty('aceBar.x')
	barY = getProperty('aceBar.y')
	barWidth = getProperty('aceBar.width')

	-- had to use haxe for the fucking healthbar stuff i hate this
	runHaxeCode([[
		var bfBar = null;

		function updateBFBar(hpVal) {
			if (bfBar == null) bfBar = game.getLuaObject('bfBar');
			if (bfBar == null) return;

			if (hpVal > 1) hpVal = 1;
			if (hpVal < 0) hpVal = 0;

			var clipX = bfBar.frameWidth*(1-hpVal);
			if (bfBar.clipRect == null) bfBar.clipRect = new flixel.math.FlxRect();

			var rect = bfBar.clipRect;
			rect.set(clipX, 0, bfBar.frameWidth-clipX, bfBar.frameHeight);
			bfBar.clipRect = rect;
		}
	]])

	createLuaText("retroComboRating", "", 2000, 0, downscroll and 600 or 65, true, "center", 40, "hud", "000000", 2, "000000")
	screenCenter("retroComboRating", "x")
	setProperty("retroComboRating.alpha", 0)

	createLuaText("retroComboNumber", "0", 2000, 0, downscroll and 640 or 105, true, "center", 33.5, "hud", "FFFFFF", 2, "000000")
	screenCenter("retroComboNumber", "x")
	setProperty("retroComboNumber.alpha", 0)
	lastCombo = "0"
	setComboString(botPlay and "BOTPLAY" or "0")

	createLuaText("acc_miss", "ACC: XX%\nMISSES: 0", screenWidth - 30, 0, downscroll and 30 or 620, true, "right", 35, "hud", "FFFFFF", 2, "000000")
	setProperty("acc_miss.alpha", 0)

	createLuaText("timeLeftTxt", "00:00|00:00", screenWidth, 30, downscroll and 30 or 620, true, "left", 35, "hud", "FFFFFF", 2, "000000")
	setProperty('timeLeftTxt.alpha', 0)
	setTextAlignment("timeLeftTxt", "center")
	setProperty("timeLeftTxt.x", -520)
end

-- use onStartCountdown instead of something like onCreatePost because onCreatePost doesn't work if onStartCountdown is interrupted
function onStartCountdown()
	reloadIcons()
end

function onCountdownStarted()
	for _, obj in ipairs ({"showCombo", "showComboNum", "showRating"}) do
		setProperty(obj, false)
	end
	setProperty("timeBar.visible", false)
	setProperty("timeTxt.visible", false)
	setProperty("scoreTxt.visible", false)
end

function onSongStart()
	setProperty('timeLeftTxt.alpha', 1)
	setProperty("timeBar.visible", false)
	setProperty("timeTxt.visible", false)
	setProperty("scoreTxt.visible", false)
end

function onBeatHit()
	curIconScale = iconScale+0.2
end

function onEvent(n, v1, v2)
	if n == "Change Character" then
		reloadIcons()
	end
end

function onUpdatePost(elapsed)
	-- health colors
	local aceColor = getProperty('healthBar.leftBar.color')
	local bfColor = getProperty('healthBar.rightBar.color')

	if aceColor ~= lastAceColor then
		setProperty('aceBar.color', aceColor)
		lastAceColor = aceColor
	end
	if bfColor ~= lastBfColor then
		setProperty('bfBar.color', bfColor)
		lastBfColor = bfColor
	end

	local speed = boundTo(elapsed*9, 0, 1)
	health = lerp(health, getHealth(), speed)

	local percent = boundTo(health / 2, 0, 1)
	if lastSentHP == nil or math.abs(percent - lastSentHP) > 0.0005 then
		runHaxeFunction('updateBFBar', {percent})
		lastSentHP = percent
	end

	-- icons
	curIconScale = lerp(curIconScale, iconScale, speed)

	setProperty('iconP1.scale.x', curIconScale)
	setProperty('iconP1.scale.y', curIconScale)
	setProperty('iconP2.scale.x', curIconScale)
	setProperty('iconP2.scale.y', curIconScale)

	local itscX = barX + (barWidth * (1 - percent))
	local iconY = barY - 30

	setProperty('iconP1.x', itscX-35)
	setProperty('iconP1.y', iconY-17)

	setProperty('iconP2.x', itscX-(getProperty('iconP2.width')-20))
	setProperty('iconP2.y', iconY-15)

	local accTxt = format("ACC: %.2f\nMISSES: %s", rating*100, misses)
	if accTxt ~= lastAcc then
		setTextString("acc_miss", accTxt)
		lastAcc = accTxt
	end

	local songTimeLength = getProperty('songLength')
	local songPos = math.max(0, getSongPosition())
	if songPos >= songTimeLength then
		songTimeLength = songPos
	end

	local timeTxt = "Time Left:\n"..floor(songPos/60000)..':'..floor((songPos/10000) % 6)..floor((songPos/1000) % 10)..'|'..floor(songTimeLength/60000)..':'..floor((songTimeLength/10000) % 6)..floor((songTimeLength/1000) % 10)
	if timeTxt ~= lastTime then
		setTextString("timeLeftTxt", timeTxt)
		lastTime = timeTxt
	end

	-- Keep combo display as BOTPLAY while botplay is active
	setComboString(botPlay and "BOTPLAY" or tostring(combo))

	if dadImage ~= nil then
		local hpPercent = getProperty("healthBar.percent")
		local frame = 0
		if hpPercent > 80 then
			frame = 1
		elseif hpPercent < 20 then
			frame = 2
		end

		if frame ~= lastIconFrame then
			setProperty("iconP2.animation.curAnim.curFrame", frame)
			lastIconFrame = frame
		end
	end
end

function goodNoteHit(id, dir, type, sus)
	if not sus then
		local judge = getPropertyFromGroup("notes", id, "rating")
		setProperty("acc_miss.alpha", 1)
		cancelTween("rtTweenAlpha1")
		cancelTween("rtTweenAlpha2")
		setProperty("retroComboRating.scale.x", 1.1)
		doTweenX("rtTweenScale1", "retroComboRating.scale", 1, 0.25, "linear")
		setProperty("retroComboRating.alpha", 1)
		setProperty("retroComboNumber.alpha", 1)
		setComboString(getProperty('botplay') and "BOTPLAY" or tostring(combo))
		setTextString("retroComboRating", ratingSys[judge][1])
		setTextColor("retroComboRating", ratingSys[judge][2])
		runTimer("hideCombo", 2)
	end
end

function noteMiss(id, dir, type, sus)
	if not sus then
		setProperty("acc_miss.alpha", 1)
		cancelTween("rtTweenAlpha1")
		cancelTween("rtTweenAlpha2")
		setComboString(getProperty('botplay') and "BOTPLAY" or "0")
		setTextString("retroComboRating", "MISS")
		setTextColor("retroComboRating", "FF0000")
		runTimer("hideCombo", 2.5)
	end
end

function onTimerCompleted(t)
	if t == "hideCombo" then
		doTweenAlpha("rtTweenAlpha1", "retroComboRating", 0, 0.75, "linear")
		doTweenAlpha("rtTweenAlpha2", "retroComboNumber", 0, 0.75, "linear")
	end
end
