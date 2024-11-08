# Maze Survival
Maze Survival is a zero-player game! You can... watch it, I guess?

![](footage/wwiwiwin.gif)

# what is this
It's more of a simulation rather than a game, however [Conway's Game of Life is considered a zero-player game](https://en.wikipedia.org/wiki/Zero-player_game#:~:text=Cellular%20automaton%20games%20that%20are%20determined%20by%20initial%20conditions%20including%20Conway%27s%20Game%20of%20Life%20are%20examples%20of%20this.), so who actually cares?

Those four colored balls on the screen are trying<sup>1</sup> to survive being killed by those glitching shapes and be the last one standing. They have powerups at their disposal, whether or not to their benefit—the purple one teleporting them to a random location, the yellow one giving them a speed boost, and the blue one causing the maze's walls to shift.

<sup>1</sup> They don't try. They move randomly.

# how do i use it
You'll need [Love2D](https://love2d.org/) downloaded first. After you have it downloaded and ready, simply drag the folder into it and watch. For hours. Ten hours even. Twelve decades!

There's some extra configuration options in [settings.lua](resources/settings.lua) if you want to turn off the statistics, get rid of the link or... watch it in portrait mode? If you're into that??
Not much to actually say.

# well what exactly are the thingies doing
The circles move from one tile to another at a rate of about half a second. Each time they step onto a new tile, they check for how many paths there are. If there's only one, they just move in that direction. If there's two (like in a hallway) they continue going where they were moving towards (no turning around essentially). If there's three or more, they pick any path at random. This causes them to often bounce back and forth in the same hallway, but I consider that a strategic tactic rather than a nuisance.

The enemies are slightly different—spawning every ten seconds and moving at the same rate, they try to close the distance to the nearest circle Pac-Man ghost style. They refuse to turn around and refuse to step into the tips of dead ends, only picking paths that would get them closer to their target circle. It's smart enough to where it's a danger, but still easily manipulatable given you have enough distance.

The maze itself is generated with the [Origin Shift](https://www.youtube.com/watch?v=zbXKcDVV4G0) algorithm created by [CaptainLuma](https://www.youtube.com/@captainluma7991).
Snippet from [main.lua](resources/main.lua)
```lua
--[[
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
```

# modding????
You could... do you want to look through my code though? (perchance)
