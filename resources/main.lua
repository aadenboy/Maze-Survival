require "boiler"
require "keys"
require "vector"
require "camera"
math.randomseed(os.time())

require "settings"

love.filesystem.createDirectory("stats")
love.filesystem.createDirectory("shorts")
love.filesystem.createDirectory("shared")

--[[
    Maze algorithm based on "Origin Shift" algorithm by CaptainLuma on YouTube

    the maze is represented as a set of directioned nodes on a grid, each pointing to another node
    one node, the origin, has no direction and leads nowhere
    on every update or origin shift, follow these steps:
    
        1. have the origin node point to another neighboring node
            - the node it points to cannot have been the previous origin
        2. the neighboring node becomes the new origin
        3. make the new origin node directionless (or pointing to nothing)

    you can also see the set of nodes as a tree
    this algorithm will never create any loops or unreachable sections, ensuring the maze is a perfect maze
]]

-- just in case they don't exist

local nodes = {}
local board = Vector2.new(10, 10) -- size of board
local dirs   = {
    Vector2.new( 1, 0), -- right
    Vector2.new(-1, 0), -- left
    Vector2.new(0,  1), -- up
    Vector2.new(0, -1), -- down
}

local dpath = merged and "shared/" or (shorts and "shorts/" or "stats/")
local wins = {0, 0, 0, 0}

if not love.filesystem.read(dpath.."wins")    then love.filesystem.write(dpath.."wins",    "0;0;0;0") end
if not love.filesystem.read(dpath.."misc")    then love.filesystem.write(dpath.."misc",    "0;0;0")   end
if not love.filesystem.read(dpath.."betters") then love.filesystem.write(dpath.."betters", "0")       end

xw = string.split(love.filesystem.read(dpath.."wins"), ";")
wins = {tonumber(xw[1]), tonumber(xw[2]), tonumber(xw[3]), tonumber(xw[4])}

love.window.setMode(shorts and 405 or 1300, shorts and 720 or 730, {
    fullscreen  = false,
    msaa        = 2,
    resizable   = false,
    borderless  = true,
    centered    = true,
    highdpi     = true,
    usedpiscale = true,
})

-- sounds generated with jsfxr
local sounds = {
    explosion  = love.audio.newSource("sounds/explosion.wav",  "static"),
    pickupCoin = love.audio.newSource("sounds/pickupCoin.wav", "static"),
    powerUp    = love.audio.newSource("sounds/powerUp.wav",    "static"),
    random     = love.audio.newSource("sounds/random.wav",     "static"),
    synth      = love.audio.newSource("sounds/synth.wav",      "static"),
    jump       = love.audio.newSource("sounds/jump.wav",       "static"),
    boing      = love.audio.newSource("sounds/boing.wav",      "static"),
    wuauwuau   = love.audio.newSource("sounds/wuauwuau.wav",   "static"),
    woosh      = love.audio.newSource("sounds/woosh.wav",      "static"),
    laserShoot = love.audio.newSource("sounds/laserShoot.wav", "static"),
}

local pwcolors = {
    [1] = {fromHEX("#a5a")}, -- teleport
    [2] = {fromHEX("#aa5")}, -- speed
    [3] = {fromHEX("#5aa")}, -- shift
    [4] = {fromHEX("#5a5")}, -- ghost
    [5] = {fromHEX("#a55")}, -- attack
    [6] = {fromHEX("#aaa")}, -- decoy
}
local blcolors = {
    [0] = {0, 0, 0},
    [1] = {fromHEX("#f00")},
    [2] = {fromHEX("#ff0")},
    [3] = {fromHEX("#0f0")},
    [4] = {fromHEX("#00f")},
}

-- used for the enemies and player debris
local function thing(pos)
    love.graphics.polygon("fill", CamPoly({
        math.random(-25, 25), math.random(-25, 25),
        math.random(-25, 25), math.random(-25, 25),
        math.random(-25, 25), math.random(-25, 25),
        math.random(-25, 25), math.random(-25, 25),
        math.random(-25, 25), math.random(-25, 25),
        math.random(-25, 25), math.random(-25, 25),
        math.random(-25, 25), math.random(-25, 25),
        math.random(-25, 25), math.random(-25, 25)
    }, pos, math.random(0, 360), math.random(10, 20)/10, math.random(10, 20)/10, math.random(0, 10)/10, math.random(0, 10)/10))
end

function nodes.get(pos)
    return nodes[tostring(pos)]
end
function nodes.set(pos, dir)
    nodes[tostring(pos)] = {pos = pos, dir = dir}
end
function nodes.remove(pos)
    nodes[tostring(pos)] = nil
end
function nodes.pathto(from, to) -- if there's a path to or from a node to another
    local f, t = nodes.get(from), nodes.get(to)
    return f.pos + f.dir == t.pos or t.pos + t.dir == f.pos
end
function nodes.paths(pos) -- all the paths of a single node
    local paths = {}
    for _,v in pairs(dirs) do
        local node = nodes.get(pos + v)
        if node then if nodes.pathto(pos, pos + v) then
            paths[#paths+1] = v 
        end end
    end
    return paths
end

-- creates the "maze" of nodes, each eventually leading to a direction-less node
for i=0, board.x * board.y - 1 do
    local pos = Vector2.new(i % board.x, math.floor(i / board.x))
    
    if pos.x < board.x - 1 then
        nodes.set(pos, Vector2.new(1, 0))
    elseif pos.y < board.y - 1 then
        nodes.set(pos, Vector2.new(0, 1))
    else
        nodes.set(pos, Vector2.new(0, 0))
    end
end

local origin = Vector2.new(board.x - 1, board.y - 1)
local lastp  = Vector2.new(0, 0) -- last direction, used to prevent backtracking

-- actually randomizes the maze
function randomize(amt)
    for i=1, amt or 10000 do
        -- checking valid directions
        local next = {}
        for _,v in pairs(dirs) do
            if nodes.get(origin + v) and v ~= lastp then table.insert(next, v) end
        end

        -- updating nodes
        lastp = next[math.random(1, #next)]  -- choose a direction
        nodes.set(origin, lastp)             -- point the origin in that direction
        origin = origin + lastp              -- move the origin
        nodes.set(origin, Vector2.new(0, 0)) -- make the new origin directionless
        lastp = -lastp                       -- update lastp
    end
end
randomize()

local balls = {}
local powerups = {}
local pwtotal = 0

local pwstotal = {0, 0, 0}
local xf = string.split(love.filesystem.read(dpath.."misc"), ";")
pwstotal = {tonumber(xf[1]), tonumber(xf[2]), tonumber(xf[3])}

for i=1, 5 do
    balls[#balls+1] = { -- moving thingy
        pos      = Vector2.new(math.random(0, board.x - 1), math.random(0, board.y - 1)),
        body     = Vector2.new(0, 0), -- visual
        bodylast = Vector2.new(0, 0),
        interp   = 0,
        speed    = 2,
        alive    = true,
        time     = 0, -- unused
        color    = i < 5 and i or 0, -- use 0 for enemies
        ghost    = i < 5 and 0 or 5, -- provides temporary protection
    }
    balls[#balls].bodylast = balls[#balls].pos
end

local particles = {}
function particle(pos, vel, time, func) -- helper function
    particles[#particles+1] = {pos = pos, vel = vel, time = time, func = func}
end

local t, ldt = 0, 0 -- time, last deltatime
local dying = 0
local lpt = 0                 -- last powerup time
local lrt = math.random(3, 7) -- powerup wait time
local spinsustain = 0 -- for maze shift powerup
local f = 0 -- frames
function love.update(dt)
    window:refresh()
    mouse:refresh()
    keyboard:refresh()
    camera:updatemouse()

    t = t + dt
    ldt = dt
    f = f + 1

    -- camera stuffs
    camera.position   = board / 2 * 100 - Vector2.new(50, 50)
    debugcam.position = camera.position
    camera.z          = math.min(window.width / (board.x * 100 + 50), window.height / (board.y * 100 + 50)) * (shorts and 0.8 or 1)
    debugcam.z        = camera.z
    
    for _,ball in pairs(balls) do
        -- interpolating ball's position as it moves
        local ndt = ldt * ball.speed
        ball.body   = ball.bodylast + (ball.pos - ball.bodylast) * ball.interp
        ball.interp = math.min(ball.interp + ndt, 1)
        ball.ghost  = math.max(ball.ghost - ndt, 0) -- protection time decrease

        -- gives the ball a trail if it's fast
        if ball.speed > 2 and f % 4 == 0 and ball.alive then
            particle(ball.body, Vector2.new(0, 0), 0.5, function(self)
                local r, g, b = unpack(blcolors[ball.color])
                love.graphics.setColor(r, g, b, 0.5)
                local x, y, _, s = CamPoint(self.pos.x * 100, self.pos.y * 100, 0, 20 * self.time, 0)
                love.graphics.circle("fill", x, y, s)
            end)
        end

        -- when it appears to move to the tile...
        if ball.interp == 1 and ball.alive then
            ball.time = t
            ball.interp = 0
            ball.speed = math.max(ball.speed - 0.1, 2)
            
            if ball.color > 0 then -- regular balls
                local paths = nodes.paths(ball.pos) -- get the paths
                local chosen = math.random(1, #paths) -- and then pick one
                if ball.bodylast == ball.pos + paths[chosen] and #paths == 2 then -- no backtracking in hallways
                    table.remove(paths, chosen)
                    chosen = math.random(1, #paths)
                end

                ball.bodylast = ball.pos
                ball.pos = ball.pos + paths[chosen] -- move

                -- powerup time
                local pw = powerups[tostring(ball.bodylast)] -- check for any
                if pw then
                    powerups[tostring(ball.bodylast)] = nil
                    pwtotal = pwtotal - 1
                    pw = pw[1] -- we only care about the type
                    
                    -- spawn particles
                    for i=1, 8 do
                        particle(ball.bodylast, Vector2.fromAngle(math.pi * (i / 4)) / 10, 2, function(self)
                            love.graphics.setColor(pwcolors[pw][1], pwcolors[pw][2], pwcolors[pw][3], 0.8)
                            love.graphics.polygon("fill", CamPoly({-10,0, 0,10, 10,0, 0,-10}, self.pos * 100, 0, self.time / 3, self.time / 3))
                            self.vel = self.vel * 0.8
                        end)
                    end

                    if pw == 1 then -- teleport
                        pwstotal[1] = pwstotal[1] + 1
                        local old = ball.bodylast
                        ball.bodylast = Vector2.new(math.random(0, board.x - 1), math.random(0, board.y - 1))
                        ball.pos = ball.bodylast
                        love.audio.play(sounds.jump)
                        ball.ghost = ball.ghost + 5
                        particle(old, Vector2.new(0, 0), 0.4, function(self) -- trail
                            local dist = old:distfrom(ball.bodylast)
                            love.graphics.setColor(unpack(blcolors[ball.color]))
                            love.graphics.setLineWidth(camera.z * 15)
                            local x,  y  = CamPoint(ball.bodylast.x * 100, ball.bodylast.y * 100, 0, 0, 0)
                            local x2, y2 = CamPoint(self.pos.x      * 100, self.pos.y      * 100, 0, 0, 0)
                            love.graphics.line(x, y, x2, y2)
                            self.pos = self.pos + (ball.bodylast - self.pos) / 3
                        end)
                    elseif pw == 2 then -- speed
                        pwstotal[2] = pwstotal[2] + 1
                        ball.speed = ball.speed * 3
                        love.audio.play(sounds.boing)
                    elseif pw == 3 then -- maze shift
                        pwstotal[3] = pwstotal[3] + 1
                        spinsustain = spinsustain + 60*4 -- roughly four seconds
                        love.audio.play(sounds.wuauwuau)
                    end

                    if track then love.filesystem.write(dpath.."misc", table.concat(pwstotal, ";")) end
                end
            else -- enemy
                -- find the closest circle
                local cand, dist = Vector2.new(0, 0), math.huge
                for i=1, 4 do
                    local oball = balls[i]
                    if ball.pos:distfrom(oball.pos) < dist and ball.alive then
                        cand, dist = oball.pos, ball.pos:distfrom(oball.pos)
                    end
                end
                
                -- now choose a good path
                local paths = nodes.paths(ball.pos)
                local cand2, dist2 = Vector2.new(0, 0), math.huge
                if #paths == 1 then cand2 = paths[1] -- if we have no choice...
                else
                    for i,v in pairs(paths) do -- run through them all
                        -- only if it doesn't lead to a dead end
                        if (ball.pos + v):distfrom(cand) < dist2 and ball.pos + v ~= ball.bodylast and #nodes.paths(ball.pos + v) > 1 then
                            cand2, dist2 = v, (ball.pos + v):distfrom(cand)
                        end
                    end
                end

                ball.bodylast = ball.pos
                ball.pos = ball.pos + cand2 -- move
            end
        end
    end

    -- constraining the origin to be within the maze
    origin = Vector2.new(math.min(origin.x, board.x - 1), math.min(origin.y, board.y - 1))

    -- powerup spawning
    if t - lpt > lrt and pwtotal < math.sqrt(board.x^2 + board.y^2) then
        lpt = t
        lrt = math.random(10, 30) / 10

        -- finding a blank tile
        local locs = {}
        for i=0, board.x * board.y - 1 do
            local loc = Vector2.new(i % board.x, math.floor(i / board.x))
            if not powerups[tostring(loc)] then
                locs[#locs+1] = loc
            end
        end

        -- if there was any
        if #locs > 0 then
            local loc = locs[math.random(1, #locs)]
            local pw  = math.random(1, 3)
            powerups[tostring(loc)] = {pw, loc}
            pwtotal = pwtotal + 1
        end
    end

    -- shifting
    if spinsustain > 0 then randomize(1) spinsustain = spinsustain - 1 end 
end

local nextpause = false
local lasttime = 0
local winner = 0
local wt = 0 -- win timer, for win screen

local noto = love.graphics.newFont("notosansmono.ttf", 64, "light", 1)
local text = love.graphics.newText(noto)

local cmain  = love.graphics.newCanvas()
local canvas = love.graphics.newCanvas()
local shader = love.graphics.newShader([[
    extern vec4  wc;
    extern float rad;
    extern vec2  mid;

    vec4 effect(vec4 color, Image tex, vec2 tpos, vec2 spos){
        vec4 tcolor = Texel(tex, tpos);
        
        if (length(spos - mid) <= rad) {
            return wc - (vec4(1, 1, 1, 1) - tcolor)*wc/2;
        }
        return tcolor;
    }
]]) -- glass pane shader effect
function love.draw()
    love.graphics.setCanvas(cmain)
    love.graphics.clear(fromHEX("aaa"))

    -- death sleep + win check
    if nextpause then
        love.timer.sleep(0.5)
        nextpause = false

        -- count circles
        local hit, l = 0, 0
        for i=1, 4 do
            hit = hit + (balls[i].alive and 1 or 0)
            l = balls[i].alive and i or l
        end
        if hit == 1 then
            winner = l
            for i=5, #balls do balls[i] = nil end
        end
    end

    -- draw the maze
    love.graphics.setColor(fromHEX("555"))
    love.graphics.setLineWidth(75*camera.z)
    for _,v in pairs(nodes) do
        if type(v) == "table" and v.dir:magnitude() > 0 then
            local p = v.pos + v.dir/2
            local r = v.pos:anglefrom(p)
            love.graphics.polygon("line", CamPoly({-25,0, 25,0, -25,0}, p * 100, r, 3.5, 0))
        end
    end

    -- powerups
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    local register = {}
    for i,v in pairs(powerups) do
        love.graphics.setColor(unpack(pwcolors[v[1]]))
        love.graphics.polygon("fill", CamPoly({-15,0, 0,15, 15,0, 0,-15}, v[2] * 100, 0, 1, 1))
    end

    -- ball render
    for i,ball in pairs(balls) do
        if ball.alive and ball.color > 0 then -- normal
            local r, g, b = unpack(blcolors[ball.color])
            love.graphics.setColor(r, g, b, math.cos(ball.ghost * 2 * math.pi) / 2 + 0.5)
            local x, y, _, s = CamPoint(ball.body.x * 100, ball.body.y * 100, 0, 20, 0)
            love.graphics.circle("fill", x, y, s)

            -- for collision detection
            if ball.ghost == 0 then register[tostring(ball.body:round(1))] = ball end
        elseif ball.alive and ball.color == 0 then -- enemy
            love.graphics.setColor(math.random(1, 100) / 100, math.random(1, 10) / 50, math.random(1, 10) / 50, math.cos(ball.ghost * 2 * math.pi) / 2 + 0.5)
            thing(ball.body * 100)
            local x, y, _, s = CamPoint(ball.body.x * 100, ball.body.y * 100, 0, 10, 0)
            love.graphics.circle("fill", x, y, s)

            -- trail
            if f % 4 == 0 and ball.ghost == 0 then
                particle(Vector2.new(x, y), Vector2.new(0, 0), 1, function(self)
                    love.graphics.setColor(math.random(1, 100) / 100, math.random(1, 10) / 50, math.random(1, 10) / 50, 0.5)
                    love.graphics.circle("fill", self.pos.x, self.pos.y, 10 * camera.z * self.time)
                end)
            end
            
            -- collision detection
            local at = register[tostring(ball.body:round(1))]
            if at and at.body:distfrom(ball.body) < 0.1 and ball.ghost == 0 then
                -- SCARY DEATH!!!!!!
                love.graphics.setCanvas(cmain)
                love.graphics.clear()
                love.graphics.setColor(0, 0, 0)
                love.graphics.rectangle("fill", 0, 0, window.width * 2, window.height * 2)
                love.graphics.setColor(1, 0, 0)
                thing(ball.body * 100)
                love.graphics.setColor(1, 1, 1)
                local x, y, _, s = CamPoint(ball.body.x * 100, ball.body.y * 100, 0, 20, 0)
                love.graphics.circle("fill", x, y, s)
                love.audio.stop()
                love.audio.play(sounds.explosion)
                at.alive = false
                nextpause = true
                for i=1, 4 do -- debris after animation
                    particle(ball.body, Vector2.new(math.random(-20, 20), math.random(5, 20)) / 100, 10, function(self)
                        self.vel = self.vel - Vector2.new(0, 0.01)
                        love.graphics.setColor(unpack(blcolors[at.color]))
                        thing(self.pos * 100)
                    end)
                end
                goto ending
            end
        end
    end

    love.graphics.setCanvas(cmain)
    for i in ipairs(particles) do -- drawing the particles BEFORE everything else
        v = particles[i]
        v.pos = v.pos + v.vel
        v.time = v.time - ldt
        v:func(i)
        if v.time <= 0 then table.remove(particles, i) end
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas) -- now draw above particles

    do -- timer and win count
        local n = math.floor(t - lasttime) / (10)
        local cx, cy = CamPoint(-25, board.y * 100, 0, 10, 0)
        cx, cy = cx + 50, cy
        local cx2, cy2 = CamPoint(board.x * 100, 0, 0, 10, 0)
        if not shorts then
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle("fill", 50, 50, 40)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", 50, 50, 35)
            love.graphics.setColor(0, 0, 0)
            love.graphics.setLineWidth(2.5, 0)
            love.graphics.line(50, 50, 50+math.cos(t*math.pi*2-math.pi/2)*30, 50+math.sin(t*math.pi*2-math.pi/2)*30)
            love.graphics.line(50, 50, 50+math.cos(n*math.pi*2-math.pi/2)*25, 50+math.sin(n*math.pi*2-math.pi/2)*25)
            love.graphics.setColor(1, 1, 1)
            if track then
                text:set({
                    {1, 0, 0}, "Red wins: "..wins[1],
                    {1, 1, 0}, "\nYellow wins: "..wins[2],
                    {0, 1, 0}, "\nGreen wins: "..wins[3],
                    {0, 0, 1}, "\nBlue wins: "..wins[4],
                })
                love.graphics.draw(text, 100, 0, 0, 0.3, 0.3)
                text:set({
                    {1, 0, 0}, "Red wins: "..wins[1],
                    {1, 1, 0}, "\nYellow wins: "..wins[2],
                    {0, 1, 0}, "\nGreen wins: "..wins[3],
                    {0, 0, 1}, "\nBlue wins: "..wins[4],
                })
                love.graphics.draw(text, 101, 0, 0, 0.3, 0.3)

                -- ugly code but WHATEVER I'm not making a function for this one bit
                love.graphics.setLineWidth(1)
                love.graphics.setColor(unpack(pwcolors[1]))
                love.graphics.polygon("fill", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(board.x*100,board.y*100-100), 0, 1, 1))
                love.graphics.setColor(0, 0, 0)
                love.graphics.polygon("line", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(board.x*100,board.y*100-100), 0, 1, 1))
                love.graphics.setColor(unpack(pwcolors[2]))
                love.graphics.polygon("fill", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(board.x*100,board.y*100-150), 0, 1, 1))
                love.graphics.setColor(0, 0, 0)
                love.graphics.polygon("line", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(board.x*100,board.y*100-150), 0, 1, 1))
                love.graphics.setColor(unpack(pwcolors[3]))
                love.graphics.polygon("fill", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(board.x*100,board.y*100-200), 0, 1, 1))
                love.graphics.setColor(0, 0, 0)
                love.graphics.polygon("line", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(board.x*100,board.y*100-200), 0, 1, 1))
                text:set(pwstotal[1])
                local x3, y3 = CamPoint(board.x*100+35,board.y*100-100,0,0,0)
                love.graphics.draw(text, x3, y3, 0, 0.35, 0.35, 0, text:getHeight() / 2)
                text:set(pwstotal[2])
                local x3, y3 = CamPoint(board.x*100+35,board.y*100-150,0,0,0)
                love.graphics.draw(text, x3, y3, 0, 0.35, 0.35, 0, text:getHeight() / 2)
                text:set(pwstotal[3])
                local x3, y3 = CamPoint(board.x*100+35,board.y*100-200,0,0,0)
                love.graphics.draw(text, x3, y3, 0, 0.35, 0.35, 0, text:getHeight() / 2)
            end
            if credits then
                love.graphics.setColor(0, 0, 0)
                text:set("https://github.com/aadenboy/Maze-Survival")
                local x3, y3 = CamPoint(-25,board.y*100-60,0,0,0)
                love.graphics.draw(text, x3, y3, 0, 0.3, 0.3, 0, text:getHeight())
                love.graphics.draw(text, x3+0.5, y3, 0, 0.3, 0.3, 0, text:getHeight())
            end
        else
            cy = cy - 5
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle("fill", 72, cy, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", 72, cy, 17.5)
            love.graphics.setColor(0, 0, 0)
            love.graphics.setLineWidth(1.72, 0)
            love.graphics.line(72, cy, 72+math.cos(t*math.pi*2-math.pi/2)*15, cy+math.sin(t*math.pi*2-math.pi/2)*15)
            love.graphics.line(72, cy, 72+math.cos(n*math.pi*2-math.pi/2)*17.5, cy+math.sin(n*math.pi*2-math.pi/2)*17.5)
            love.graphics.setColor(1, 1, 1)
            if track then
                text:set({
                    {1, 0, 0}, "Red wins: "..wins[1],
                    {1, 1, 0}, "  Yellow wins: "..wins[2],
                    {0, 1, 0}, "\nGreen wins: "..wins[3],
                    {0, 0, 1}, "  Blue wins: "..wins[4],
                })
                love.graphics.draw(text, 100, cy - 25, 0, 0.24, 0.24)
                text:set({
                    {1, 0, 0}, "Red wins: "..wins[1],
                    {1, 1, 0}, "  Yellow wins: "..wins[2],
                    {0, 1, 0}, "\nGreen wins: "..wins[3],
                    {0, 0, 1}, "  Blue wins: "..wins[4],
                })
                love.graphics.draw(text, 101, cy - 25, 0, 0.24, 0.24)

                -- ugly code part 2 electric boogaloo
                love.graphics.setLineWidth(1)
                love.graphics.setColor(unpack(pwcolors[1]))
                love.graphics.polygon("fill", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(0, board.y*100+150), 0, 1.5, 1.5))
                love.graphics.setColor(0, 0, 0)
                love.graphics.polygon("line", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(0, board.y*100+150), 0, 1.5, 1.5))
                love.graphics.setColor(unpack(pwcolors[2]))
                love.graphics.polygon("fill", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(200, board.y*100+150), 0, 1.5, 1.5))
                love.graphics.setColor(0, 0, 0)
                love.graphics.polygon("line", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(200, board.y*100+150), 0, 1.5, 1.5))
                love.graphics.setColor(unpack(pwcolors[3]))
                love.graphics.polygon("fill", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(400, board.y*100+150), 0, 1.5, 1.5))
                love.graphics.setColor(0, 0, 0)
                love.graphics.polygon("line", CamPoly({-20,0, 0,20, 20,0, 0,-20}, Vector2.new(400, board.y*100+150), 0, 1.5, 1.5))
                text:set(pwstotal[1])
                local x3, y3 = CamPoint(50,board.y*100+150,0,0,0)
                love.graphics.draw(text, x3, y3, 0, 0.35, 0.35, 0, text:getHeight() / 2)
                text:set(pwstotal[2])
                local x3, y3 = CamPoint(250,board.y*100+150,0,0,0)
                love.graphics.draw(text, x3, y3, 0, 0.35, 0.35, 0, text:getHeight() / 2)
                text:set(pwstotal[3])
                local x3, y3 = CamPoint(450,board.y*100+150,0,0,0)
                love.graphics.draw(text, x3, y3, 0, 0.35, 0.35, 0, text:getHeight() / 2)
            end
            if credits then
                love.graphics.setColor(0, 0, 0)
                text:set("https://github.com/aadenboy/Maze-Survival")
                love.graphics.draw(text, window.width / 2, cy2 + 70 + text:getHeight() / 2, 0, 0.2, 0.2, text:getWidth() / 2, text:getHeight() / 2)
                love.graphics.draw(text, window.width / 2+0.5, cy2 + 70 + text:getHeight() / 2, 0, 0.2, 0.2, text:getWidth() / 2, text:getHeight() / 2)
            end
        end

        if n == 1 then -- spawning enemy
            lasttime = math.floor(t)
            balls[#balls+1] = {
                pos      = Vector2.new(math.random(0, board.x - 1), math.random(0, board.y - 1)),
                body     = Vector2.new(0, 0),
                bodylast = Vector2.new(0, 0),
                interp   = 0,
                speed    = 2,
                alive    = true,
                time     = 0,
                color    = 0,
                ghost    = 5,
            }
            balls[#balls].bodylast = balls[#balls].pos
            love.audio.play(sounds.powerUp)
        end

        love.graphics.setFont(noto)
        love.graphics.setColor(1, 1, 1)
        
        if shorts and not nextpause then -- lol
            love.graphics.setColor(0.3, 0.3, 0.3)
            text:set("Last one")
            love.graphics.draw(text, window.width / 2, cy2 + 35, 0, 0.6, 0.6, text:getWidth() / 2, text:getHeight() / 2)
            text:set("standing wins!")
            love.graphics.draw(text, window.width / 2, cy2 + 35 + text:getHeight() / 2, 0, 0.6, 0.6, text:getWidth() / 2, text:getHeight() / 2)
        end
    end

    ::ending::

    love.graphics.setCanvas()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1)

    local function a()
        if not nextpause then love.graphics.clear(fromHEX("aaa")) end
        love.graphics.draw(cmain)
    end

    if winner > 0 then -- winn!!!!!
        if wt == 0 and track then
            wins[winner] = wins[winner] + 1
            love.filesystem.write(dpath.."wins", table.concat(wins, ";"))
            love.filesystem.write(dpath.."betters", tostring(winner))
        end
        t = 0
        wt = wt + ldt
        shader:send("wc", blcolors[winner])
        shader:send("rad", math.min(window.width, window.height) / 2.5)
        shader:send("mid", {window.width / 2, window.height / 2})
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1)
        a()
        love.graphics.setShader()
        love.graphics.setColor(fromHEX(({
            [1] = "#000",
            [2] = "#000",
            [3] = "#000",
            [4] = "#fff",
        })[winner]))
        text:set(({"RED", "YELLOW", "GREEN", "BLUE"})[winner].." WINS")
        love.graphics.draw(text, window.width / 2, window.height / 2, 0, shorts and 0.75 or 1.3, shorts and 0.75 or 1.3, text:getWidth() / 2, text:getHeight() / 2)
    else
        wt = 0
        a()
    end

    if wt >= 5 then -- reset
        nextpause = false
        lasttime = 0
        winner = 0
        wt = 0
        origin = Vector2.new(board.x - 1, board.y - 1)
        lastp  = Vector2.new(0, 0) -- last direction, used to prevent backtracking

        randomize()
        balls = {}
        for i=1, 5 do
            balls[#balls+1] = { -- moving thingy
                pos      = Vector2.new(math.random(0, board.x - 1), math.random(0, board.y - 1)),
                body     = Vector2.new(0, 0),
                bodylast = Vector2.new(0, 0),
                interp   = 0,
                speed    = 2,
                alive    = true,
                time     = 0,
                color    = i < 5 and i or 0,
                ghost    = i < 5 and 0 or 5,
            }
            balls[#balls].bodylast = balls[#balls].pos
        end
        
        t, ldt = 0, 0
        dying = 0
        lpt = 0
        lrt = math.random(3, 7)

        powerups = {}
        pwtotal = 0
        particles = {}
        spinsustain = 0
    end
end