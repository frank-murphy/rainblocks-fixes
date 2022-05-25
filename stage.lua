local stage = {
	maxLevel = 10,
	levelStrings =	{	"01",	"02",	"03",	"04",	"05",	"06",	"07",	"08",	"09",	"10"	},
	speeds =				{	1000,	793,	618,	473,	355,	262,	190,	135,	94,		64		},

	create = function()
		local s = {
			width = 10,
			height = 22,
			visibleHeight = 20,

			tetromino = nil,
			enablePreview = true,
			preview = nil,
			enableHold = true,
			hold = nil,
			enableGhost = true,
			ghost = nil,
			
			tiles = {},
			bag = {},

			score = 0,
			scoreDisplay = 0,
			combo = -1,
			linesCleared = 0,
			level = 1,

			speed = 1000,
			lockDelay = 500,
			lockTimer = nil,
			tickTimer = nil,
			holdDelay = 500,
			isHardDropping = false,
			isWaitingForHoldLock = false,

			mode = "regular",
			sceneIndex = 1,

			setup = function(self)
				for row = 1, self.height do
					self.tiles[row] = {}
					for col = 1, self.width do
						self.tiles[row][col] = 0
					end
				end
				self.tickTimer = playdate.timer.new(self.speed, function() self:tick() end)
				self.tickTimer.repeats = true
				self:resetBag()
			end,

			gameOver = function(self)
				print("GAME OVER")
				self.tickTimer:remove()
			end,

			setMode = function(self, mode)
				if self.mode ~= mode then
					self.mode = mode
					modeOption:setValue(mode)
				end
			end,

			setLevel = function(self, level, setManually)
				if level ~= self.level then
					if level > self.level and not setManually then
						-- sceneIndex = sceneIndex + 1
					end

					if self.mode == "chill" and not setManually then
						level = self.level
					end

					if level > stage.maxLevel then
						level = stage.maxLevel
					end

					self.level = level

					self.speed = stage.speeds[level]
					if self.tickTimer then
						self.tickTimer.duration = self.speed
					end
 
					if not setManually then
						levelOption:setValue(stage.levelStrings[level])
					end
				end
			end,

			resetBag = function(self)
				self.bag = {}
				for i = 1, #tetromino.types do
					table.insert(self.bag, tetromino.types[i])
				end
				for i = #self.bag, 2, -1 do
					local j = math.random(i)
					self.bag[i], self.bag[j] = self.bag[j], self.bag[i]
				end
			end,

			chooseFromBag = function(self)
				local type = self.bag[1]
				table.remove(self.bag, 1)
				if #self.bag == 0 then
					self:resetBag()
				end
				return type
			end,

			spawnTetromino = function(self)
				local type = self:chooseFromBag()
				local x = 4
				local y = 2
				if type == "I" then
					y = 1
				end
				
				self.tetromino = tetromino.create(type, x, y)

				if self.enableGhost then
					self.ghost = tetromino.create(type, x, y)
					self.ghost.isGhost = true
				end

				if self.enablePreview then
					self.preview = tetromino.create(self.bag[1], 0, 0)
				end

				if not self.tetromino:moveDown(self) then
					self:gameOver() -- block out
				end
			end,

			shiftLeft = function(self)
				if self.tetromino and not self.isHardDropping then
					local success = self.tetromino:moveLeft(self)
				end
			end,

			shiftRight = function(self)
				if self.tetromino and not self.isHardDropping then
					local success = self.tetromino:moveRight(self)
				end
			end,

			rotateClockwise = function(self)
				if self.tetromino and not self.isHardDropping then
					local success = self.tetromino:rotateClockwise(self)
				end
			end,

			rotateCounterClockwise = function(self)
				if self.tetromino and not self.isHardDropping then
					local success = self.tetromino:rotateCounterClockwise(self)
				end
			end,

			startSoftDrop = function(self)
				if self.tetromino and not self.isHardDropping then
					self.tickTimer.duration = math.floor(self.speed / 20)
				end
			end,

			stopSoftDrop = function(self)
				if self.tetromino then
					self.tickTimer.duration = self.speed
				end
			end,

			hardDrop = function(self)
				if self.tetromino then
					self.isHardDropping = true
					self.tickTimer.duration = 1
				end
			end,

			switchHold = function(self)
				if self.enableHold and not self.isWaitingForHoldLock then
					if self.hold then
						table.insert(self.bag, 1, self.hold.type)
						self.isWaitingForHoldLock = true
					end
					self.hold = self.tetromino
					self:spawnTetromino()
				end
			end,

			lock = function(self)
				self.isWaitingForHoldLock = false

				if self.isHardDropping then
					self.isHardDropping = false
					self.tickTimer.duration = self.speed
				end

				if self.lockTimer then
					self.lockTimer:remove()
					self.lockTimer = nil
				end

				if self.tetromino and self.tetromino:checkCollision(self, 0, 1) then
					self:tetrominoToTiles()
					self.tetromino = nil
					local lineCount = self:checkForLines()
					self:calculateScore(lineCount)
					if self:checkForLockOut() then
						self:gameOver()
					end
				end
			end,

			checkForLockOut = function(self)
				local tilesAboveVisibleStage = false
				for row = 1, 2 do
					for col = 1, self.width do
						if self.tiles[row][col] > 0 then
							tilesAboveVisibleStage = true
							break
						end
					end
				end
				return tilesAboveVisibleStage
			end,

			checkForLines = function(self)
				local lineCount = 0
				for row = 3, self.height do
					local isLine = true
					for col = 1, self.width do
						if self.tiles[row][col] == 0 then
							isLine = false
						end
					end
					if isLine then
						self:clearLine(row)
						lineCount = lineCount + 1
					end
				end
				return lineCount
			end,

			clearLine = function(self, y)
				print("clear line " .. y)
				for row = y, 2, -1 do
					for col = 1, self.width do
						self.tiles[row][col] = self.tiles[row - 1][col]
					end
				end
			end,

			tetrominoToTiles = function(self)
				local pattern = tetromino.pattern[self.tetromino.type]
				local rotation = pattern[self.tetromino.rotationIndex]
				for row = 1, #rotation do
					for col = 1, #rotation[row] do
						if rotation[row][col] > 0 then
							local x = self.tetromino.x + col - 1
							local y = self.tetromino.y + row - 1
							self.tiles[y][x] = rotation[row][col]
						end
					end
				end
			end,

			calculateScore = function(self, lineCount)
				local score = 0

				if lineCount == 1 then
					score = 100 * self.level
				elseif lineCount == 2 then
					score = 300 * self.level
				elseif lineCount == 3 then
					score = 500 * self.level
				elseif lineCount >= 4 then
					score = 800 * self.level
				end

				if lineCount >= 1 then
					self.combo = self.combo + 1
					score = score + (50 * self.combo * self.level)
				else
					self.combo = -1
				end

				self.linesCleared = self.linesCleared + lineCount
				if self.linesCleared >= 10 then
					self.linesCleared = 0
					self:setLevel(self.level + 1)
				end

				self.score = self.score + score
			end,

			tick = function(self)
				if self.tetromino then

					local success = self.tetromino:moveDown(self)

					if success then
						if self.lockTimer then
							self.lockTimer:remove()
							self.lockTimer = nil
						end
					else
						local lockDelay = self.lockDelay
						if self.isHardDropping then
							lockDelay = 1
						end
						self.lockTimer = playdate.timer.new(lockDelay, function() self:lock() end)
					end

				else
					self:spawnTetromino()
				end
			end,

			drawTile = function(self, tx, ty)
				local x = tx * tetromino.minoSize
				local y = ty * tetromino.minoSize
				playdate.graphics.fillRect(x, y, tetromino.minoSize - 1, tetromino.minoSize - 1) 
			end,

			draw = function(self)
				local displayWidth = self.width * tetromino.minoSize
				local displayHeight = self.visibleHeight * tetromino.minoSize

				if self.score > self.scoreDisplay then
					if self.score - self.scoreDisplay >= 1000 then
						self.scoreDisplay = math.min(self.score, self.scoreDisplay + 100)
					else
						self.scoreDisplay = math.min(self.score, self.scoreDisplay + 10)
					end
				end
				playdate.graphics.drawText("Score", displayWidth + 10, displayHeight - 40)
				playdate.graphics.drawText(self.scoreDisplay, displayWidth + 10, displayHeight - 20)

				playdate.graphics.drawText("Level", -50, displayHeight - 40)
				playdate.graphics.drawText(self.level, -50, displayHeight - 20)

				if self.enablePreview then
					playdate.graphics.drawText("Next", displayWidth + 10, 0)
					if self.preview then
						self.preview.x = self.width + 2
						self.preview.y = 6
						self.preview:draw()
					end
				end

				if self.enableHold then
					playdate.graphics.drawText("Hold", -50, 0)
					if self.hold then
						self.hold.x = -4
						self.hold.y = 6
						self.hold:draw()
					end
				end
				
				playdate.graphics.setClipRect(0, 0, displayWidth, displayHeight)
				playdate.graphics.drawRect(0, 0, displayWidth, displayHeight)

				if self.tetromino then
					if self.ghost and self.enableGhost then
						self.ghost.x = self.tetromino.x
						self.ghost.y = self.tetromino.y
						self.ghost.rotationIndex = self.tetromino.rotationIndex
						while self.ghost:moveDown(self) do end
						self.ghost:draw()
					end

					self.tetromino:draw()
				end

				for row = 1, self.height do
					for col = 1, self.width do
						if self.tiles[row][col] ~= 0 then
							local x = col - 1
							local y = row - 3
							self:drawTile(x, y)
						end
					end
				end

			end,
		}

		s:setup()
		return s
	end
}

return stage