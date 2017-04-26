-- Copyright (C) 2014 Monkey Zhang (timebug), UPYUN Inc.


local floor = math.floor
local tonumber = tonumber

local _M = { _VERSION = "0.01", OK = 1, BUSY = 2, FORBIDDEN = 3 }

local redis_limit_req_lookup_script_sha
local redis_limit_req_lookup_script = [==[
local key = KEYS[1]
local rate = tonumber(KEYS[2])
local now, interval = tonumber(KEYS[3]), tonumber(KEYS[4])
local burst = tonumber(KEYS[5])

local excess, last, forbidden = 0, 0, 0

local OK = 1, BUSY = 2, FORBIDDEN = 3

local res = redis.pcall('GET', key)
if type(res) == "table" and res.err then
    return {err=res.err}
end

if res and type(res) == "string" then
    local v = cjson.decode(res)
    if v and #v > 2 then
        excess, last, forbidden = v[1], v[2], v[3]
    end

    if forbidden == 1 then
        return {FORBIDDEN, excess}
    end

    local ms = math.abs(now - last)
    excess = excess - rate * ms / 1000 + 1000

    if excess < 0 then
        excess = 0
    end

    if excess > burst then
      return {BUSY, excess}
    end
end

return(OK, excess)
]==]

local redis_limit_req_update_script_sha
local redis_limit_req_update_script = [==[
local key = KEYS[1]
local excess = tonumber(KEYS[2])
local now, interval = tonumber(KEYS[3]), tonumber(KEYS[4])
local burst = tonumber(KEYS[5])

local OK = 1
local res = ''

if excess > burst and interval > 0 then
    local res = redis.pcall('SETEX', key, interval,
                            cjson.encode({excess, now, 1}))
else
    local res = redis.pcall('SETEX', key, 60,
                            cjson.encode({excess, now, 0}))
end

if type(res) == "table" and res.err then
    return {err=res.err}
end

return {OK, excess}
]==]

local function redis_connect(rds)
  rds.host = rds.host or "127.0.0.1"
  rds.port = rds.port or 6379
  rds.timeout = rds.timeout or 1

  local red = redis:new()

  red:set_timeout(rds.timeout * 1000)

  local ok, err
  if rds.socket then
      ok, err = red:connect(rds.socket)
  else
      ok, err = red:connect(rds.host, rds.port)
  end

  if not ok then
      ngx.log(ngx.WARN, "redis connect err: ", err)
      return _M.OK
  end

  if rds.pass then
      local ok, err = red:auth(rds.pass)
      if not ok then
          ngx.log(ngx.ALERT, "Lua failed to authenticate to Redis")
          return _M.OK
      end
  end

  return red
end

local function redis_lookup(conn, zone, key, rate, duration, burst)
    local red = conn

    if not redis_limit_req_lookup_script then
        local res, err = red:script("LOAD", redis_limit_req_lookup_script)
        if not res then
            return nil, err
        end

        ngx.log(ngx.NOTICE, "load redis limit req lookup script")

        redis_limit_req_lookup_script_sha = res
    end

    local now = ngx.now() * 1000

    local res, err = red:evalsha(redis_limit_req_lookup_script_sha, 5,
                                 zone .. ":" .. key, rate, now, duration, burst)
    if not res then
        redis_limit_req_lookup_script_sha = nil
        return nil, err
    end

    -- put it into the connection pool of size 100,
    -- with 10 seconds max idle timeout
    local ok, err = red:set_keepalive(10000, 100)
    if not ok then
        ngx.log(ngx.WARN, "failed to set keepalive: ", err)
    end

    return res
end


local function redis_update(conn, zone, key, excess, duration, burst)
    local red = conn

    if not redis_limit_req_update_script_sha then
        local res, err = red:script("LOAD", redis_limit_req_update_script)
        if not res then
            return nil, err
        end

        ngx.log(ngx.NOTICE, "load redis limit req script")

        redis_limit_req_update_script_sha = res
    end

    local now = ngx.now() * 1000

    local res, err = red:evalsha(redis_limit_req_update_script_sha, 5,
                                 zone .. ":" .. key, excess, now, duration, burst)
    if not res then
        redis_limit_req_update_script_sha = nil
        return nil, err
    end

    -- put it into the connection pool of size 100,
    -- with 10 seconds max idle timeout
    local ok, err = red:set_keepalive(10000, 100)
    if not ok then
        ngx.log(ngx.WARN, "failed to set keepalive: ", err)
    end

    return res
end


function _M.limit(cfg)
    if not package.loaded['redis'] then
        local ok, redis = pcall(require, "resty.redis")
        if not ok then
            ngx.log(ngx.ERR, "failed to require redis")
            return _M.OK
        end
    end

    local conn_master = nil
    local conn_slave = nil
    local zone = cfg.zone or "limit_req"
    local key = cfg.key or ngx.var.remote_addr
    local rate = cfg.rate or "1r/s"
    local burst = cfg.burst * 1000 or 0
    local interval = cfg.interval or 0
    local log_level = cfg.log_level or ngx.NOTICE

    local scale = 1
    local len = #rate

    if not conn_master then
        conn_master = redis_connect(cfg.redis.master)
    end

    if not conn_slave then
        conn_slave = redis_connect(cfg.redis.slave)
    end

    if len > 3 and rate:sub(len - 2) == "r/s" then
        scale = 1
        rate = rate:sub(1, len - 3)
    elseif len > 3 and rate:sub(len - 2) == "r/m" then
        scale = 60
        rate = rate:sub(1, len - 3)
    end

    rate = floor((tonumber(rate) or 1) * 1000 / scale)

    local res, err = redis_lookup(conn_slave, zone, key, rate, interval, burst)
    if res and (res[1] == _M.BUSY or res[1] == _M.FORBIDDEN) then
        if res[1] == _M.BUSY then
            ngx.log(log_level, 'limiting requests, excess ' ..
                        res[2]/1000 .. ' by zone "' .. zone .. '"')
        end
        return
    end
    if not res and err then
        ngx.log(ngx.WARN, "redis lookup err: ", err)
        return _M.OK
    end

    local res, err = redis_update(conn_master, zone, key, res[2], interval, burst)
    if not res and err then
        ngx.log(ngx.WARN, "redis update err: ", err)
    end

    return _M.OK
end


return _M
