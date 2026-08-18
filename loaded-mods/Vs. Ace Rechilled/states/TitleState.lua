local path = 'menus/'
local LOOP_POINT = 16100

local EGG_CHANCE = 2
local EGG_VIDEO = 'unrestricted_internet_access' -- videos/video_name.mp4

local canEnter = true
local introDone = false
local introLines = {}
local step = 0
local videoPlaying = false

local intro = {
    {1, function()
        setProperty('introText.alpha', 1)
    end},

    {2, function()
        doTweenAlpha('hilogo', 'teamLogo', 1, 1.25)
        doTweenAngle('logospeen', 'teamLogo', 360, 0.75, 'cubeOut')
        startTween('tween_logoscale', 'teamLogo.scale', {x = 0.65, y = 0.65}, 1.25, {ease = 'backOut'})
    end},

    {1, function()
        setTextString('introText', 'FANMADE MOD BY')
        setProperty('introText.y', getProperty('introText.y') - 10)
        setProperty('teamLogo.alpha', 0)
    end},

    {1.25, function()
        setTextString('introText2', 'THIS LOSER')
        setProperty('introText2.alpha', 1)
        setProperty('loser.alpha', 1)
    end},

    {1.5, function()
        local txt = getRandomText()
        setProperty('introText2.alpha', 0)
        setProperty('loser.alpha', 0)
        setProperty('introText.y', getProperty('introText.y') + 100)
        setProperty('introText2.y', getProperty('introText.y') + 70)
        setTextString('introText', txt[1])
        setTextString('introText2', txt[2] or '')
    end},

    {1, function()
        setProperty('introText2.alpha', 1)
    end},

    {0.775, function()
        setProperty('introText2.alpha', 0)
        setTextString('introText', 'VS. ACE')
        setTextString('introText2', 'RECHILLED')
    end},

    {0.775, function()
        setProperty('introText2.alpha', 1)
    end},

    {1, function()
        setProperty('introText.alpha', 0)
        setProperty('introText2.alpha', 0)
    end}
}

function onCreate()
    openSubState(nil)

    local firstTime = not getPropertyFromClass('states.TitleState', 'initialized')
    setPropertyFromClass('states.TitleState', 'initialized', true)
    local playEgg = firstTime and getRandomInt(1, 100) <= EGG_CHANCE
    loadIntroText()

    createLuaSprite('bg', 'title/bg', 0, 0, 1, 0.75, 0.75)
    createLuaSprite('logo', 'title/aceLogo', 40, 20, 1, 0.5, 0.5)

    createAnimatedLuaSprite('enter', 'title/titleEnter', 0, 570, 'begin', 'Press Enter to Begin', 24, true, 1, 1, 1)
    addAnimationByPrefix('enter', 'pressed', 'ENTER PRESSED', 24, true)
    setProperty('enter.animation.curAnim.paused', true)

    createLuaGraphic('blackscr', 1920, 1080, 'black', 1, 0, 0, false)

    createLuaSprite('loser', 'title/yup', 0, 300, 0, 0.65, 0.65)
    createLuaText('introText', 'NOT ASSOCIATED\nWITH', 400, 0, 170, 0, 'white', 60, 'retrofont1')
    createLuaText('introText2', '', 400, 0, 220, 0, 'white', 60, 'retrofont1')
    createLuaSprite('teamLogo', 'title/team', 0, 370, 0, 0.25, 0.25)

    screenCenter('bg', 'xy')
    for _, tag in ipairs({'teamLogo', 'loser', 'enter', 'introText', 'introText2'}) do
        screenCenter(tag, 'x')
    end
    for _, tag in ipairs({'introText', 'introText2'}) do
        setTextAlignment(tag, 'center')
    end

    setPropertyFromClass('backend.Conductor', 'bpm', 90)

    -- con l'easter egg la musica non parte qui: la fa partire onVideoFinished
    if not playEgg then startMenuMusic(firstTime and 2 or 0) end

    doTweenAngle('logoleft', 'logo', -5, 2.5, 'sineInOut')

    if firstTime then
        if playEgg and startVideo(EGG_VIDEO, true) then
            videoPlaying = true
        else
            if playEgg then startMenuMusic(2) end
            runTimer('intro', 0.25)
        end
    else endIntro(0) cameraFlash('camOther', 'white', 1.5, true) end
end

function startMenuMusic(fadeTime)
    if isMusicPlaying() then return end

    playMusic('freakyMenu', 1, true)
    setPropertyFromClass('flixel.FlxG', 'sound.music.loopTime', LOOP_POINT)
    if fadeTime > 0 then soundFadeIn(nil, fadeTime, 0, 1) end
end

function onVideoFinished(name)
    if name ~= EGG_VIDEO or not videoPlaying then return end
    videoPlaying = false
    startMenuMusic(1)
    runTimer('intro', 0.25)
end

function onVideoSkipped(name)
    onVideoFinished(name)
end

function onUpdate(elapsed)
    --if keyboardJustPressed('ESCAPE') then switchState('MainMenuState') end

    if videoPlaying then return end

    if keyboardJustPressed('ENTER') then
        if not introDone then
            skipIntro()
        elseif canEnter then
            canEnter = false
            cameraFlash('camOther', 'white', 0.5, true)
            playAnim('enter', 'pressed', true)
            playSound('confirmMenu', 1, 'confirm', false)
            runTimer('byebye', 1.25)
        end
    end
end

function onTimerCompleted(t)
    if t == 'intro' then
        step = step + 1
        local s = intro[step]
        if s == nil then endIntro(3) return end

        s[2]()
        runTimer('intro', s[1])
    elseif t == 'byebye' then
        switchState('MainMenuState')
    end
end

function onTweenCompleted(t)
    if t == 'logoleft' then doTweenAngle('logoright', 'logo', 5, 3.5, 'sineInOut')
    elseif t == 'logoright' then doTweenAngle('logoleft', 'logo', -5, 3.5, 'sineInOut') end
end

function skipIntro()
    if getSoundTime('') < LOOP_POINT then setSoundTime('', 10550) setSoundVolume('', 1) end
    endIntro(0.75)
end

function endIntro(flash)
    if introDone then return end
    introDone = true

    cancelTimer('intro')
    cancelTween('hilogo')
    cancelTween('logospeen')
    cancelTween('tween_logoscale')

    removeLuaSprite('blackscr')
    for _, tag in ipairs({'introText', 'introText2', 'teamLogo', 'loser'}) do
        setProperty(tag..'.alpha', 0)
    end
    setProperty('enter.animation.curAnim.paused', false)

    if flash > 0 then cameraFlash('camOther', 'white', flash, true) end
end

function loadIntroText()
    local file = getTextFromFile('data/introText.txt')
    if file == nil then return end

    for _, l in ipairs(stringSplit(file, '\n')) do
        l = stringTrim(l)
        if l ~= '' then table.insert(introLines, stringSplit(string.upper(l), '--')) end
    end
end

function getRandomText()
    if #introLines == 0 then return {'IF YOU SEE THIS', 'IT DID NOT WORK'} end
    return introLines[getRandomInt(1, #introLines)]
end

function createLuaSprite(tag, img, x, y, alpha, sizeX, sizeY)
    makeLuaSprite(tag, path .. img, x, y)
    setProperty(tag..'.alpha', alpha)
    setProperty(tag..'.antialiasing', true)
    scaleObject(tag, sizeX, sizeY)
    addLuaSprite(tag)
end

function createAnimatedLuaSprite(tag, img, x, y, animName, prefix, fps, loop, alpha, sizeX, sizeY)
    makeAnimatedLuaSprite(tag, path .. img, x, y)
    addAnimationByPrefix(tag, animName, prefix, fps, loop)
    setProperty(tag..'.alpha', alpha)
    setProperty(tag..'.antialiasing', true)
    scaleObject(tag, sizeX, sizeY)
    addLuaSprite(tag)
end

function createLuaText(tag, text, width, x, y, alpha, color, size, font)
    makeLuaText(tag, text, width, x, y)
    setTextColor(tag, color)
    setTextFont(tag, font..'.ttf')
    setTextSize(tag, size)
    setTextBorder(tag, 1, 'black')
    setProperty(tag..'.alpha', alpha)
    addLuaText(tag)
end

function createLuaGraphic(tag, width, height, color, alpha, x, y, inFront)
    makeLuaSprite(tag, nil, x, y)
    makeGraphic(tag, width, height, color)
    setProperty(tag..'.alpha', alpha or 1)
    addLuaSprite(tag, inFront or false)
end

function createLuaBackdrop(tag, img, alpha, x, y, sizeX, sizeY, args, velX, velY)
    createInstance(tag, 'flixel.addons.display.FlxBackdrop', args)
    loadGraphic(tag, path .. img)
    addInstance(tag, true)
    scaleObject(tag, sizeX, sizeY)
    setProperty(tag..'.x', x)
    setProperty(tag..'.y', y)
    setProperty(tag..'.alpha', alpha)
    setProperty(tag..'.velocity.x', velX)
    setProperty(tag..'.velocity.y', velY)
end
