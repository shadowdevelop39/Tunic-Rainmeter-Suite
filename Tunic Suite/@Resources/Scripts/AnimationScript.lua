-- AnimationScript.lua

-- Global variables to manage animation state
local meterName          -- Name of the meter to animate (read from.ini)
local defaultText        -- Default text for the meter (read from.ini)
local targetText         -- Target text for the meter on hover (read from.ini)
local animationFrames    -- Total frames for one animation phase (read from.ini)
local randomPhaseDuration -- Number of frames dedicated to the initial random character display
local currentFrame       -- Current frame counter within the active animation phase
local animationState     -- Current state of the animation (e.g., "IDLE", "HOVER_RANDOMIZING", etc.)
local randomCharacters   -- Pool of characters for randomization
local currentDisplayedText -- The text currently displayed on the meter

-- Helper function to get a random lowercase character
function getRandomChar()
    local index = math.random(1, #randomCharacters) -- Get a random index within the string length
    return string.sub(randomCharacters, index, index) -- Return the character at that index
end

-- Function called once when the skin loads or is refreshed
function Initialize()
    -- Read configuration options from the script measure's.ini section [1]
    meterName = SELF:GetOption('MeterName', 'MeterAnimatedText')
    defaultText = SELF:GetOption('DefaultText', 'cope ra')
    targetText = SELF:GetOption('TargetText', 'opera')
    animationFrames = SELF:GetNumberOption('AnimationFrames', 7)

    -- Calculate the duration for the initial random phase (e.g., 1/3 of total frames)
    randomPhaseDuration = math.floor(animationFrames / 3)

    -- Initialize animation state variables
    animationState = "IDLE"
    currentFrame = 0
    currentDisplayedText = defaultText -- Start with the default text

    -- Seed the random number generator using current time for true randomness
    -- This ensures different random sequences each time the skin is loaded [1]
    math.randomseed(os.time())

    -- Define the pool of characters for random generation
    randomCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    -- Set the initial text of the target meter using a Rainmeter bang [1]
    SKIN:Bang('!SetOption', meterName, 'Text', defaultText)
    SKIN:Bang('!UpdateMeter', meterName) -- Force the meter to update its display
    SKIN:Bang('!Redraw')               -- Force the skin to redraw to show changes

    -- Print a debug message to the Rainmeter About window log [1]
    print("Animation script initialized. Meter: ".. meterName.. ", Default: ".. defaultText.. ", Target: ".. targetText)
end

-- Function called when the mouse hovers over the trigger area
function HoverStart()
    -- Only start the hover animation if not already in a hover state
    if animationState ~= "HOVER_RANDOMIZING" and animationState ~= "HOVER_TRANSITIONING" then
        animationState = "HOVER_RANDOMIZING" -- Transition to the initial random phase
        currentFrame = 0                    -- Reset frame counter for the new animation
        print("HoverStart triggered. State: HOVER_RANDOMIZING") -- Debugging
    end
end

-- Function called when the mouse leaves the trigger area
function HoverEnd()
    -- Only start the unhover animation if not already in an unhover state
    if animationState ~= "UNHOVER_TRANSITIONING" then
        animationState = "UNHOVER_TRANSITIONING" -- Transition to the unhover phase
        currentFrame = 0                         -- Reset frame counter for the new animation
        print("HoverEnd triggered. State: UNHOVER_TRANSITIONING") -- Debugging
    end
end

-- Function called repeatedly by Rainmeter based on UpdateDivider [1]
function Update()
    local newText = currentDisplayedText -- Start with the currently displayed text

    if animationState == "HOVER_RANDOMIZING" then
        currentFrame = currentFrame + 1
        local targetLen = #targetText -- Length of the final target string

        -- Generate a string of random characters matching the target length
        local tempText = ""
        for i = 1, targetLen do
            tempText = tempText.. getRandomChar()
        end
        newText = tempText

        if currentFrame >= randomPhaseDuration then
            animationState = "HOVER_TRANSITIONING" -- Move to the next phase
            currentFrame = randomPhaseDuration -- Maintain continuity for the next phase
            print("Transitioning to HOVER_TRANSITIONING") -- Debugging
        end

    elseif animationState == "HOVER_TRANSITIONING" then
        currentFrame = currentFrame + 1
        local targetLen = #targetText
        local tempText = ""

        -- Calculate how many characters should be revealed from the target string
        local charsToReveal = math.floor((currentFrame - randomPhaseDuration) / (animationFrames - randomPhaseDuration) * targetLen)
        charsToReveal = math.min(charsToReveal, targetLen) -- Ensure it doesn't exceed target length

        for i = 1, targetLen do
            if i <= charsToReveal then
                tempText = tempText.. string.sub(targetText, i, i) -- Reveal character from target
            else
                tempText = tempText.. getRandomChar() -- Fill remaining with random characters
            end
        end
        newText = tempText

        if currentFrame >= animationFrames then
            newText = targetText -- Ensure final text is exactly the target
            animationState = "IDLE" -- Animation complete, go to idle
            print("Hover animation complete. State: IDLE") -- Debugging
        end

    elseif animationState == "UNHOVER_TRANSITIONING" then
        currentFrame = currentFrame + 1
        local defaultLen = #defaultText
        local currentLen = #currentDisplayedText -- Use the length of the currently displayed text
        local maxLength = math.max(defaultLen, currentLen) -- Handle different lengths

        local tempText = ""
        -- Calculate how many characters should be revealed from the default string
        local charsToReveal = math.floor(currentFrame / animationFrames * maxLength)
        charsToReveal = math.min(charsToReveal, defaultLen) -- Ensure it doesn't exceed default length

        for i = 1, maxLength do
            if i <= charsToReveal then
                -- Reveal character from defaultText
                tempText = tempText.. string.sub(defaultText, i, i)
            else
                -- If defaultText is shorter, or character not yet revealed, keep current character or pad
                if i <= currentLen then
                    tempText = tempText.. string.sub(currentDisplayedText, i, i)
                else
                    tempText = tempText.. " " -- Pad with space if current text is shorter
                end
            end
        end
        newText = tempText

        if currentFrame >= animationFrames then
            newText = defaultText -- Ensure final text is exactly the default
            animationState = "IDLE" -- Animation complete, go to idle
            print("Unhover animation complete. State: IDLE") -- Debugging
        end

    end

    -- Update the meter text only if it has changed to avoid redundant bangs
    if newText ~= currentDisplayedText then
        SKIN:Bang('!SetOption', meterName, 'Text', newText) -- Update meter text [1]
        SKIN:Bang('!UpdateMeter', meterName) -- Force meter update [1]
        SKIN:Bang('!Redraw')               -- Force skin redraw [1]
        currentDisplayedText = newText     -- Update the stored displayed text
        print("Frame: ".. currentFrame.. ", State: ".. animationState.. ", Text: ".. newText) -- Debugging
    end

    return 1, newText -- Return a dummy number and the current text for the measure value [1]
end