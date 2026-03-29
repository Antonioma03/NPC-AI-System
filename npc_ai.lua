

------------------ SERVICIOS ------------------
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

------------------ NPC ------------------
local npc = workspace:WaitForChild("EnemyNPC")
local humanoid = npc:WaitForChild("Humanoid")
local root = npc:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed = 20

------------------ CONFIG ------------------
local CONFIG = {
	DetectionRadius = 70,
	AttackDistance = 6,
	AttackCooldown = 1,
	PathRecalcTime = 0.5,
	UpdateRate = 0.05
}

------------------ ESTADOS ------------------
local STATES = {
	Idle = "Idle",
	Chase = "Chase",
	Attack = "Attack",
	Escape = "Escape"
}

local currentState = STATES.Idle
local targetPlayer = nil
local lastAttack = 0
local lastPathTime = 0

------------------ PATH ------------------
local currentPath = nil
local waypoints = {}
local waypointIndex = 1
local lastMoveTarget = nil

------------------ UTIL ------------------
local function getHRP(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function isAlive(char)
	local hum = char and char:FindFirstChild("Humanoid")
	return hum and hum.Health > 0
end

local function getDistance(a, b)
	return (a - b).Magnitude
end

------------------ DETECCIÓN ------------------
local function getClosestPlayer()
	local closest = nil
	local shortest = CONFIG.DetectionRadius

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = getHRP(char)

		if hrp and isAlive(char) then
			local dist = getDistance(hrp.Position, root.Position)

			if dist < shortest then
				shortest = dist
				closest = player
			end
		end
	end

	return closest
end

------------------ PATHFINDING ------------------
local function computePath(destination)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true
	})

	path:ComputeAsync(root.Position, destination)

	if path.Status == Enum.PathStatus.Success then
		currentPath = path
		waypoints = path:GetWaypoints()
		waypointIndex = 1
	end
end

local function followPath()
	if not currentPath or not waypoints[waypointIndex] then return end

	local waypoint = waypoints[waypointIndex]

	if waypoint.Action == Enum.PathWaypointAction.Jump then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	if lastMoveTarget ~= waypoint.Position then
		humanoid:MoveTo(waypoint.Position)
		lastMoveTarget = waypoint.Position
	end

	if getDistance(root.Position, waypoint.Position) < 6 then
		waypointIndex += 1
	end
end

------------------ COMBATE ------------------
local function canAttack()
	return time() - lastAttack >= CONFIG.AttackCooldown
end

local function attack(player)
	if not canAttack() then return end

	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = getHRP(char)

	if hum and hrp then
		local dist = getDistance(hrp.Position, root.Position)

		if dist <= CONFIG.AttackDistance then
			hum:TakeDamage(10)
			lastAttack = time()
		end
	end
end

------------------ ESCAPE ------------------
local function getEscapePosition(player)
	local hrp = getHRP(player.Character)
	if not hrp then return root.Position end

	local diff = root.Position - hrp.Position

	if diff.Magnitude == 0 then
		return root.Position + Vector3.new(1,0,0) * 40
	end

	return root.Position + diff.Unit * 40
end

------------------ ESTADOS ------------------

local function setState(state)
	currentState = state
end

local function updateIdle()
	targetPlayer = getClosestPlayer()
	if targetPlayer then
		setState(STATES.Chase)
	end
end

local function updateChase()
	targetPlayer = getClosestPlayer()

	if not targetPlayer or not isAlive(targetPlayer.Character) then
		setState(STATES.Idle)
		return
	end

	local hrp = getHRP(targetPlayer.Character)
	if not hrp then return end

	local dist = getDistance(hrp.Position, root.Position)


	if humanoid.Health <= 30 then
		setState(STATES.Escape)
		return
	end


	if dist < 15 then
		humanoid:MoveTo(hrp.Position)

		if dist <= CONFIG.AttackDistance then
			setState(STATES.Attack)
		end

		return
	end


	if time() - lastPathTime > CONFIG.PathRecalcTime then
		computePath(hrp.Position)
		lastPathTime = time()
	end

	followPath()
end

local function updateAttack()
	if not targetPlayer then
		setState(STATES.Idle)
		return
	end

	local hrp = getHRP(targetPlayer.Character)
	if not hrp then return end

	local dist = getDistance(hrp.Position, root.Position)

	if dist > CONFIG.AttackDistance then
		setState(STATES.Chase)
	else
		attack(targetPlayer)
	end
end

local function updateEscape()
	if not targetPlayer then
		setState(STATES.Idle)
		return
	end

	local pos = getEscapePosition(targetPlayer)
	local dist = getDistance(pos, root.Position)


	if dist < 15 then
		humanoid:MoveTo(pos)
	else
		if time() - lastPathTime > CONFIG.PathRecalcTime then
			computePath(pos)
			lastPathTime = time()
		end

		followPath()
	end


	if humanoid.Health > 30 then
		setState(STATES.Chase)
	end
end

------------------ LOOP ------------------

local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt

	if accumulator >= CONFIG.UpdateRate then
		accumulator = 0

		if currentState == STATES.Idle then
			updateIdle()
		elseif currentState == STATES.Chase then
			updateChase()
		elseif currentState == STATES.Attack then
			updateAttack()
		elseif currentState == STATES.Escape then
			updateEscape()
		end
	end
end)
