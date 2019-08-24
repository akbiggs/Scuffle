pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- utils

function ternary(cond, x, y)
  if (cond) return x
  return y
end

-- class helpers (thanks dan!)

local class = {}

function class.build(superclass)
  local class = {}
  class.__index = class
  class._init = function() end

  local mt = {}
  mt.__call = function(
      self, ...)
    local instance = (
        setmetatable({}, self))
    instance:_init(...)
    return instance
  end

  if superclass then
    mt.__index = superclass
    mt.__metatable = superclass
  end

  return setmetatable(class, mt)
end

-- vector

vec = class.build()

function vec:_init(x, y)
  if type(x) == "table"
  then
    -- copy ctor
    self.x=x.x
    self.y=x.y
  else
    -- value ctor
    self.x=x
    self.y=y
  end
end

-- makes a binary operator for
-- the vector that can take
-- either two vectors or
-- a vector and a number
function _vec_binary_op(op)
  return function(v1, v2)
    if type(v1) == "table" and
       type(v2) == "table"
    then
      -- two vectors
      return vec(op(v1.x, v2.x),
                 op(v1.y, v2.y))
    end

    -- one of the arguments
    -- should be numeric
    if type(v1) == "table"
    then
      -- v2 is numeric
      return vec(op(v1.x, v2),
                 op(v1.y, v2))
    end
  
    -- v1 is numeric
    -- preserving the order of 
    -- operations is important
    return vec(op(v1, v2.x),
               op(v1, v2.y))
  end
end

vec.__add = _vec_binary_op(
    function(x,y) return x+y end)

vec.__sub = _vec_binary_op(
    function(x,y) return x-y end)

vec.__mul = _vec_binary_op(
    function(x,y) return x*y end)

vec.__div = _vec_binary_op(
    function(x,y) return x/y end)

vec.__pow = _vec_binary_op(
    function(x,y) return x^y end)

vec.__unm =
    function(v)
      return vec(-v.x, -v.y)
    end

vec.__eq =
    function(v1, v2)
      return v1.x == v2.x and
             v1.y == v2.y
    end

function vec:mag()
  return sqrt(self:sqr_mag())
end

function vec:sqr_mag()
  return self.x * self.x +
         self.y * self.y
end

function vec:normalized()
  local mag = self:mag()
  if (mag == 0) return vec(0, 0)
  return self / self:mag()
end

function vec:min(v)
  return vec(
      min(self.x, v.x),
      min(self.y, v.y))
end

function vec:max(v)
  return vec(
      max(self.x, v.x),
      max(self.y, v.y))
end

function vec:clamp(vmin, vmax)
  return vec(
      clamp(self.x, vmin.x,
            vmax.x),
      clamp(self.y, vmin.y,
            vmax.y))
end

-- math helpers

function sign(x)
  if (x < 0) return -1
  return 1
end

function clamp(x, xmin, xmax)
  if (x < xmin) return xmin
  if (x > xmax) return xmax
  return x
end

function in_range(x, xmin, xmax)
  return x >= xmin and x <= xmax
end

function wrap_idx(i, size)
  i = i % (size + 1)
  if (i == 0) return 1
  return i
end

-- table helpers

function addall(xs, ys)
  for y in all(ys)
  do
    add(xs, y)
  end
end

-- random helpers

function rndbool()
  return rnd(100) >= 50
end

-- hitbox

hbox = class.build()

function hbox:_init(pos, size)
  self.pos = vec(pos)
  self.size = vec(size)
end

-- get whether vector |v| is
-- inside the hitbox
function hbox:contains(v)
  return in_range(
      v.x,
      self.pos.x,
      self.pos.x + self.size.x
  ) and in_range(
      v.y,
      self.pos.y,
      self.pos.y + self.size.y)
end

function hbox:intersects(hb)
  -- assumes pos is top-left
  local pos1 = self.pos
  local size1 = self.size
  local pos2 = hb.pos
  local size2 = hb.size
      
  local xoverlap = in_range(
      pos1.x,
      pos2.x,
      pos2.x + size2.x
  ) or in_range(
      pos2.x,
      pos1.x,
      pos1.x + size1.x)
  
  local yoverlap = in_range(
      pos1.y,
      pos2.y,
      pos2.y + size2.y
  ) or in_range(
      pos2.y,
      pos1.y,
      pos1.y + size1.y)
               
  return xoverlap and yoverlap 
end

-- animation

anim = class.build()

function anim:_init(
    start_sprid, end_sprid,
    is_loop, duration)
  -- duration is how many ticks
  -- each frame should last
  duration = duration or 1
 
  self.start_sprid = start_sprid
  self.end_sprid = end_sprid
  self.is_loop = is_loop
  self.duration = duration
  self.ticks = 0
    
  self.sprid = start_sprid
  self.done = false
end

-- a single-frame animation
-- useful for passing sprites
-- to functions that expect
-- animations
function anim_single(sprid)
  return anim(
      sprid, sprid,
      --[[is_loop=]]false)
end

function anim:reset()
  self.sprid = self.start_sprid
  self.ticks = 0
  self.done = false
end

function anim:update()
  self.ticks = min(
      self.ticks + 1,
      self.duration)
  
  local done_frame = (
      self.ticks ==
      self.duration)
  local done_last_frame = (
      self.sprid ==
      self.end_sprid) and
      done_frame

  if done_last_frame and
     not self.is_loop
  then
    self.done = true
    return
  end
  
  if (not done_frame) return
  
  self.ticks = 0
  if done_last_frame
  then
    self.sprid = self.start_sprid
  else
    self.sprid += 1
  end
end

-- creates an animation
-- that chains together
-- several animation instances.
anim_chain = class.build()

function anim_chain:_init(
    anims, is_loop)
  self.anims = anims
  self.current = 1
  self.is_loop = is_loop
  self.done = false
  self.sprid = anims[1].sprid
end

function anim_chain:anim()
  return self.anims[
      self.current]
end

function anim_chain:update()
  local anim = self:anim()
  anim:update()
  self.sprid = anim.sprid
    
  if (not anim.done) return
  
  -- we just finished an anim
  local done_last_anim = (
      self.current ==
      #self.anims)
  if not done_last_anim
  then
    -- next anim in chain
    self.current += 1

    self:anim():reset()
  elseif self.is_loop
  then
    -- we're done the last anim
    -- in a loop, so restart
    -- loop
    self.current = 1

    self:anim():reset()
  else
    -- we're done the last anim
    -- and we're not looping,
    -- so this chain is done
    self.done = true
  end
end

-- button helpers

-- is a button just pressed?
-- relies on prev_btn being
-- updated at the end of the
-- game loop
-- different from btnp because
-- it doesn't use keyboard-style
-- repeating 
local prev_btn = {
  false,
  false,
  false,
  false,
  false,
  false,
}

function btnjp(i)
  -- todo: add support for more
  --       than one player
  return btn(i) and
         not prev_btn[i]
end

-- life utils

function filter_alive(xs)
  alive = {}
  for x in all(xs)
  do
    if x.life > 0 then
      add(alive, x)
    end
  end
  return alive 
end
-->8
-- bullets

local bullet = class.build()

function bullet:_init(
    anim, pos, vel, life,
    is_enemy, left, size,
    destroy_on_hit)
  if destroy_on_hit == nil
  then
    self.destroy_on_hit = true
  else
  		self.destroy_on_hit =
  		    destroy_on_hit
  end
  self.size = size or vec(8, 8)

  self.anim = anim
  self.pos = vec(pos)
  self.vel = vec(vel)
  -- lifetime in ticks
  self.life = life
  self.is_enemy = is_enemy
  self.left = left
  self.destroy_on_hit = (
      destroy_on_hit)
end

function bullet:update()
  self.pos += self.vel
  self.life -= 1
  self.anim:update()
end

function bullet:collide(other)
  local bullet_hb = hbox(
      self.pos,
      self.size)
  local other_hb = hbox(
      other.pos,
      other.size or vec(8, 8))
  
  if bullet_hb:intersects(
      other_hb)
  then
    if self.destroy_on_hit
    then
      bullet.life = 0
    end
    other.life -= 1
    return true
  end
  return false
end

function bullet:draw()
  spr(self.anim.sprid,
      self.pos.x, self.pos.y,
      1, 1,
      -- flip_x
      self.left)       
end
-->8
-- walker + player

local movement_min = vec(
    0, 4 * 8 - 4)
local movement_max = vec(
    30000, 12 * 8 - 8)

-- walks towards the player
-- and beats the living ****
-- out of them
local walker = class.build()

function walker:_init(pos)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  self.left = false
  self.swing_cooldown = 100
  self.life = 3
  
  self.walk_cooldown = 50
  self.walk_dist = 50
  
  self.invuln_cooldown = 0
  self.hitstun_cooldown = 0
end

function walker:walk_towards(
    player)
  if self.walk_cooldown > 0
  then
    return
  end
  
  local direc = player.pos -
      self.pos
  local speed = 0.2
  self.vel = (
      direc:normalized() *
      speed)
  local dist = self.vel:mag()
  self.walk_dist -= dist
  
  if self.walk_dist <= 0
  then
    self.walk_dist = 50 +
        rnd(50)
    self.walk_cooldown = 50 +
        rnd(50)
  end
end

function walker:swing(bullets)
  self.swing_cooldown = 100
  local bullet_offset =
      ternary(
          self.left,
          vec(-8, 0),
          vec(8, 0))
  add(bullets,
      bullet(
          anim(16, 20, false,
               6),
          self.pos +
              bullet_offset,
          vec(0, 0),
          30,
          --[[is_enemy]]true,
          self.left))
end

function walker:run_ai(
    player, bullets)
  -- measure distance
  local direc = player.pos -
      self.pos
  local attack_dist = 8
  local wants_attack =
      direc:mag() <= attack_dist
  
  -- states
  if not wants_attack then
    self:walk_towards(player)
    if self.vel.x < 0 then
      self.left = true
    elseif self.vel.x > 0 then
      self.left = false
    end
  elseif self.swing_cooldown
         <= 0 then
    self:swing(bullets)
  end
end

function walker:update(
    player, bullets)
  if player.life <= 0 then
    return
  end

  self.swing_cooldown = max(0,
      self.swing_cooldown - 1)
  self.walk_cooldown = max(0,
      self.walk_cooldown - 1)
  self.hitstun_cooldown = max(0,
      self.hitstun_cooldown - 1)
  self.invuln_cooldown = max(0,
      self.invuln_cooldown - 1)
  
  self.vel = vec(0, 0)
  
  if self.hitstun_cooldown
     <= 0
  then
    self:run_ai(player, bullets)
  end

  self.pos += self.vel
  self.pos = self.pos:clamp(
      movement_min,
      movement_max)
end

function walker:draw()
  local sprid = ternary(
      self.hitstun_cooldown > 0,
      3,
      1)
  spr(sprid, self.pos.x,
      self.pos.y,
      1, 1,
      -- flip_x
      self.left)
end

-- player

local player = class.build()

function player:_init(pos)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  self.life = 3
  self.invuln_cooldown = 100
  self.left = false
  
  self.walk_cooldown = 0
  self.swing_cooldown = 0
end

function player:vulnerable()
  return (
      self.invuln_cooldown
      <= 0)
end

function player:can_walk()
  return (
      self.walk_cooldown
      <= 0)
end

function player:can_swing()
  return (
      self.swing_cooldown
      <= 0)
end

function player:walk()
  local direc = vec(0, 0)

  if (btn(⬅️)) direc.x = -1
  if (btn(➡️)) direc.x = 1
  if (btn(⬆️)) direc.y = -1
  if (btn(⬇️)) direc.y = 1
  
  direc = direc:normalized()
  
  if direc.x < 0 then
    self.left = true
  elseif direc.x > 0 then
    self.left = false
  end

  local speed = 0.4
  self.vel = direc * speed
end

function player:swing(bullets)
  self.swing_cooldown = 50
  self.walk_cooldown = 20
  
  local bullet_offset =
      ternary(
          self.left,
          vec(-8, 0),
          vec(8, 0))
  add(bullets,
      bullet(
          anim(16, 20, false,
               6),
          self.pos +
              bullet_offset,
          vec(0, 0),
          30,
          --[[is_enemy]]false,
          self.left))
end

function player:update(bullets)  
  self.swing_cooldown = max(0,
      self.swing_cooldown - 1)
  self.walk_cooldown = max(0,
      self.walk_cooldown - 1)
  self.invuln_cooldown = max(0,
      self.invuln_cooldown - 1)
  self.vel = vec(0, 0)

  if self:can_walk() then
    self:walk()
  end
  
  if self:can_swing() and
      btnjp(❎)
  then
    self:swing(bullets)
  end

  self.pos += self.vel
  self.pos = self.pos:clamp(
      movement_min,
      movement_max)
end

function player:draw()
  spr(2, self.pos.x, self.pos.y,
      1, 1,
      self.left)
end
-->8
-- game

local state = {}

function reset()
  state.player = player(
      vec(20, 20))
  state.camera = cam(
      state.player)
  
  state.enemies = {
    walker(vec(80, 30))
  }
  state.bullets = {}
end

function _init()
  reset()
  random_tiles = tile_gen()
end

function _update60()
  -- player
  local p = state.player
  if p.life > 0 then
    p:update(state.bullets)
  end
  
  -- camera
  state.camera:update()
  
  -- enemies
  for e in all(state.enemies)
  do
    e:update(p, state.bullets)
  end
  
  -- bullets
  for b in all(state.bullets)
  do
    b:update()
    
    if b.is_enemy
    then
      if p.invuln_cooldown <= 0
          and b:collide(p)
      then
        p.invuln_cooldown = 100
        p.walk_cooldown = 20
      end
    else
      for e in all(
          state.enemies)
      do
        if e.invuln_cooldown <= 0
            and b:collide(e)       
        then
          e.invuln_cooldown =
              40
          e.hitstun_cooldown =
              60
        end
      end
    end
  end

  state.enemies = filter_alive(
      state.enemies)
  state.bullets = filter_alive(
      state.bullets)
end

function _draw()
  cls()
  state.camera:draw()
  map(0, 0, 0, 0)
  random_tiles:draw()
  print(state.player.life)

  for e in all(state.enemies)
  do
    e:draw()
  end

  if state.player.life > 0 then  
    state.player:draw()
  end

  for b in all(state.bullets)
  do
    b:draw()
  end
end
-->8
-- tile generation and drawing

tile_gen = class.build()

function tile_gen:_init()
  self.deets = {}
  local wall_deet_ids = {
      35, 36, 37, 38, 53, 54
  }
  local grnd_deet_ids = {
      39, 40, 55, 56
  }
  
  local function rnd_in(tbl)
    return tbl[flr(rnd(#tbl)) + 1]
  end

  local s_width = 12
  for s = 1,flr(128 / s_width) do
    local y = flr(rnd(8 * 9)) + 4 * 8
    if (y >= 12 * 8 - 4) y += 8
    local x = flr(rnd(s_width)) + s * s_width
    local t = rnd_in(
        ternary(
          y < 12 * 8,
          grnd_deet_ids,
          wall_deet_ids))
          
    add(self.deets, {x = x, y = y, t = t})
  end
end

function tile_gen:draw()
  for d in all(self.deets) do
    spr(d.t, d.x, d.y)
  end
end
-->8
-- camera

cam = class.build()

function cam:_init(p)
  self.p = p
  self.give = 16
  self.pos = vec(0, 0)
  self.min = vec(0, 0)
  self.max = vec(128, 0)
  self.center = vec(128, 128) / 2
end

function cam:update()
  local function center_on(
      target,
      current,
      give,
      minimum,
      maximum)
    return clamp(
      clamp(
        current,
        target - give,
        target + give),
      minimum,
      maximum)
  end

  self.pos = vec(
    center_on(
      self.p.pos.x - self.center.x,
      self.pos.x,
      self.give,
      self.min.x,
      self.max.x),
    center_on(
      self.p.pos.y - self.center.y,
      self.pos.y,
      self.give,
      self.min.y,
      self.max.y))
end

function cam:draw()
  camera(
      self.pos.x,
      self.pos.y)
end
__gfx__
000000009999999966666666aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000009999999966666666aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007009999999966666666aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770009999999966666666aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770009999999966666666aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007009999999966666666aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000009999999966666666aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000009999999966666666aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000008888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000088888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddddddddddd11111ddd02000000200000002020000020000000002000000220000000000000000000000000000000000000000000000000000000000000
1ddd111111ddd111111111110200000020000000020000000200220002d200002dd2000000000000000000000000000000000000000000000000000000000000
11111111111d111112dd1111200000000200000000000000002200002ddd20000111000000000000000000000000000000000000000000000000000000000000
1111122ddd11112dd2dddddd20000000020000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000
dddd222ddd11122dd2dddddd02000000200000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000
dddd222ddddd222dd2dddddd02000000200000000000000000000000000000000000000011100011111111110000000000000000000000000000000000000000
dddd222ddddd222dd2dddddd0000000000000000000000000000000000000000000000001111111111ddd1110000000000000000000000000000000000000000
dddd222ddddd222dd2dddddd000000000000000000000000000000000000000000000000dd11111ddddddddd0000000000000000000000000000000000000000
dddd222ddddd222dd2ddddddd2dddddddddd222d2000000002000000200000000200200000000000000000000000000000000000000000000000000000000000
ddd2222ddddd2222d2ddddddd2dddddddddd222d2000000020200000000000002022020000000000000000000000000000000000000000000000000000000000
ddd222ddddddd222d2ddddddd2dddddddddd222d2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddd222ddddddd222d2ddddddd2dddddddddd222d2000000000000000000000000000000000000000000011000000000000000000000000000000000000000000
ddd222ddddddd222dd2dddddd2dddddddddd222d0000000000000000000000000000000000000000001111000000000000000000000000000000000000000000
ddd2222ddddd2222dd2dddddd2dddddddddd222d00000000000000000000000000000000111111111111d1110000000000000000000000000000000000000000
dddd222ddddd222ddd2dddddd2dddddddddd222d000000000000000000000000000000001111111111ddd1110000000000000000000000000000000000000000
dddd222ddddd222dd2ddddddd2dddddddddd222d00000000000000000000000000000000dddddddddddddddd0000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a29393a2929392929292a3a29392a292a29393a390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2122212020222021202222212022212220222020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3033313430323034313332303432313234333031310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
