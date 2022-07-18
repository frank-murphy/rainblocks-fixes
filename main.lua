-- TODO:
-- line clear confetti
-- 4-line celebration
-- high score

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

Gfx = playdate.graphics
Tetromino = import "tetromino"
Stage = import "stage"
Scene = import "scene"

local currentStage
local buttonRepeatTimerLeft = nil
local buttonRepeatTimerRight = nil
local upHoldTimer = nil

local defaultFont

local scene = {}
local songs = {}
local songIndex = 1
local songNames = {
	"something_in_the_air",
	"glad_to_be_stuck_inside",
	"mundane",
	"pretty_little_lies",
	"shut_up_or_shut_in",
	"yesterday",
	"whatever",
}

local nextSong = function()
	songs[songIndex]:stop()
	songIndex = songIndex + 1
	if songIndex > #songs then
		songIndex = 1
	end
	songs[songIndex]:play(0)
end

local setup = function()
	math.randomseed(playdate.getSecondsSinceEpoch())

	defaultFont = Gfx.font.new("fonts/krull")
	Gfx.setFont(defaultFont)

	scene = Scene.create()
	scene:setup()

	for i, songName in pairs(songNames) do
		songs[i] = playdate.sound.fileplayer.new("music/" .. songName)
		songs[i]:setVolume(0.5)
	end
	songs[songIndex]:play(0)

	Tetromino:loadImages()
	currentStage = Stage.create(nextSong)

	local width, height = playdate.display.getSize()
	local stageWidth = (currentStage.width * Tetromino.minoSize)
	local stageHeight = (currentStage.visibleHeight * Tetromino.minoSize)
	local offsetX = math.floor((width - stageWidth) / 2)
	local offsetY = math.floor((height - stageHeight) / 2)
	Gfx.setDrawOffset(offsetX, offsetY)

	local menu = playdate.getSystemMenu()
	ModeOption = menu:addOptionsMenuItem("mode", { "regular", "dynamic", "chill" }, currentStage.mode, function(option)
		currentStage:setMode(option)
	end)
	LevelOption = menu:addOptionsMenuItem("level", Stage.levelStrings, Stage.levelStrings[1], function(option)
		currentStage:setLevel(math.tointeger(option), true)
	end)
	GhostOption = menu:addCheckmarkMenuItem("ghost", currentStage.enableGhost, function(value)
		currentStage.enableGhost = value
	end)
end

setup()

playdate.AButtonDown = function()
	if currentStage.isGameOver and not currentStage.fillTimer then
		currentStage:setup()
	else
		currentStage:rotateClockwise()
	end
end

playdate.BButtonDown = function()
	currentStage:rotateCounterClockwise()
end

playdate.upButtonDown = function()
	if currentStage.enableHold then
		currentStage.tickTimer:pause()
		upHoldTimer = playdate.timer.performAfterDelay(currentStage.holdDelay, function()
			currentStage:switchHold()
		end)
	else
		currentStage:hardDrop()
	end
end

playdate.upButtonUp = function()
	currentStage.tickTimer:start()
	if currentStage.enableHold and upHoldTimer.timeLeft > 0 then
		upHoldTimer:remove()
		currentStage:hardDrop()
	end
end

playdate.downButtonDown = function()
	currentStage:startSoftDrop()
end

playdate.downButtonUp = function()
	currentStage:stopSoftDrop()
end

playdate.leftButtonDown = function()
	buttonRepeatTimerLeft = playdate.timer.keyRepeatTimer(function() currentStage:shiftLeft() end)
end

playdate.leftButtonUp = function()
	buttonRepeatTimerLeft:remove()
end

playdate.rightButtonDown = function()
	buttonRepeatTimerRight = playdate.timer.keyRepeatTimer(function() currentStage:shiftRight() end)
end

playdate.rightButtonUp = function()
	buttonRepeatTimerRight:remove()
end

playdate.update = function()
	Gfx.clear()

	scene:draw()

	currentStage:draw()

	playdate.timer.updateTimers()
end
