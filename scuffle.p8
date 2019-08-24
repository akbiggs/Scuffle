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
-- walks towards the player
-- and beats the living ****
-- out of them
local walker = class.build()

function walker:_init(pos)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  self.left = false
  self.cooldown = 100
  
  self.walk_cooldown = 50
  self.walk_dist = 50
end

function walker:walk_towards(
    player)
  self.vel = vec(0, 0)
  self.walk_cooldown = max(0,
      self.walk_cooldown - 1)
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
  self.vel = vec(0, 0)
  self.cooldown = 100
  local bullet_offset =
      ternary(
          self.left,
          vec(8, 0),
          vec(-8, 0))
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

function walker:update(
    player, bullets)
  self.cooldown = max(0,
      self.cooldown - 1)
  
  -- measure distance
  local direc = player.pos -
      self.pos
  local attack_dist = 0.01
  local wants_attack =
      direc:mag() <= attack_dist
  
  -- states
  if not wants_attack then
    self:walk_towards(player)
  elseif self.cooldown <= 0 then
    self:swing(bullets)
  end
  
  self.pos += self.vel
end

function walker:draw()
  
  print(self.cooldown, 0, 100)
  spr(1, self.pos.x,
      self.pos.y,
      1, 1,
      -- flip_x
      self.left)
end
-->8
-- game

local state = {}

local player = class.build()

function player:_init(pos)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  self.life = 3
  self.invuln_cooldown = 100
  self.left = false
end

function player:vulnerable()
  return (
      self.invuln_cooldown
      <= 0)
end

function player:update(bullets)
  self.vel = vec(0, 0)

  local direc = vec(0, 0)

  if (btn(⬅️)) direc.x = -1
  if (btn(➡️)) direc.x = 1
  if (btn(⬆️)) direc.y = -1
  if (btn(⬇️)) direc.y = 1
  
  direc = direc:normalized()

  local speed = 0.3
  self.vel = direc * speed
  
  self.pos += self.vel
end

function player:draw()
  spr(2, self.pos.x, self.pos.y,
      1, 1,
      self.left)
end

function reset()
  -- mock
  state.player = player(
      vec(20, 20))
  
  state.enemies = {
    walker(vec(80, 30))
  }
  state.bullets = {}
end

function _init()
  reset()
end

function _update60()
  -- player
  state.player:update(
      state.bullets)

  -- enemies
  for e in all(state.enemies)
  do
    e:update(state.player,
             state.bullets)
  end
  
  -- bullets
  for b in all(state.bullets)
  do
    b:update()
    
    if b.is_enemy then
      b:collide(state.player)
    else
      for e in all(
          state.enemies)
      do
        b:collide(e)
      end
    end
  end

  state.bullets = filter_alive(
      state.bullets)
end

function _draw()
  cls()
  print(state.player.life)

  for e in all(state.enemies)
  do
    e:draw()
  end
  
  state.player:draw()
  
  for b in all(state.bullets)
  do
    b:draw()
  end
end
__gfx__
00000000999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000999999996666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000006666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
