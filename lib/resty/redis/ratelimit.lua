-- Copyright (C) Monkey Zhang (timebug), UPYUN Inc.


local type = type
local assert = assert
local floor = math.floor
local tonumber = tonumber


local _M = {
    _VERSION = "0.03",

    BUSY = 2,
    FORBIDDEN = 3
}

local mt = {
    __index = _M
}

local is_str = function(s) return type(s) == "string" end
local is_num = function(n) return type(n) == "number" end

local redis_limit_req_script_sha
local redis_limit_req_script = [==[
local key = KEYS[1]
local rate, burst = tonumber(KEYS[2]), tonumber(KEYS[3])
local now, duration = tonumber(KEYS[4]), tonumber(KEYS[5])

local excess, last, forbidden = 0, 0, 0

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
        return {3, excess} -- FORBIDDEN
    end

    local ms = math.abs(now - last)
    excess = excess - rate * ms / 1000 + 1000

    if excess < 0 then
        excess = 0
    end

    if excess > burst then
        if duration > 0 then
            local res = redis.pcall('SET', key,
                                    cjson.encode({excess, now, 1}))
            if type(res) == "table" and res.err then
                return {err=res.err}
            end

            local res = redis.pcall('EXPIRE', key, duration)
            if type(res) == "table" and res.err then
                return {err=res.err}
            end
        end

        return {2, excess} -- BUSY
    end
end

local res = redis.pcall('SET', key, cjson.encode({excess, now, 0}))
if type(res) == "table" and res.err then
    return {err=res.err}
end

local res = redis.pcall('EXPIRE', key, 60)
if type(res) == "table" and res.err then
    return {err=res.err}
end

return {1, excess}
]==]


local function redis_create(host, port, timeout, pass, dbid)
    local ok, redis = pcall(require, "resty.redis")
    if not ok then
        return nil, "failed to require redis"
    end

    timeout = timeout or 1
    host = host or "127.0.0.1"
    port = port or 6379

    local red = redis:new()

    red:set_timeout(timeout * 1000)

    local redis_err = function(err)
        local msg = "failed to create redis"
        if is_str(err) then
            msg = msg .. " - " .. err
        end

        return msg
    end

    local ok, err = red:connect(host, port)
    if not ok then
        return nil, redis_err(err)
    end

    if pass then
        local ok, err = red:auth(pass)
        if not ok then
            return nil, redis_err(err)
        end
    end

    if dbid then
        local ok, err = red:select(dbid)
        if not ok then
            return nil, redis_err(err)
        end
    end

    return red
end


local function redis_commit(red, zone, key, rate, burst, duration)
    if not redis_limit_req_script_sha then
        local res, err = red:script("LOAD", redis_limit_req_script)
        if not res then
            return nil, err
        end

        redis_limit_req_script_sha = res
    end

    local now = ngx.now() * 1000
    local res, err = red:evalsha(redis_limit_req_script_sha, 5,
                                 zone .. ":" .. key, rate, burst, now,
                                 duration)
    if not res then
        redis_limit_req_script_sha = nil
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


-- local lim, err = class.new(zone, rate, burst, duration)
function _M.new(zone, rate, burst, duration)
    local zone = zone or "ratelimit"
    local rate = rate or "1r/s"
    local burst = burst or 0
    local duration = duration or 0

    local scale = 1
    local len = #rate

    if len > 3 and rate:sub(len - 2) == "r/s" then
        scale = 1
        rate = rate:sub(1, len - 3)
    elseif len > 3 and rate:sub(len - 2) == "r/m" then
        scale = 60
        rate = rate:sub(1, len - 3)
    end

    rate = tonumber(rate)

    assert(rate > 0 and burst >= 0 and duration >= 0)

    burst = burst * 1000
    rate = floor(rate * 1000 / scale)

    return setmetatable({
            zone = zone,
            rate = rate,
            burst = burst,
            duration = duration,
    }, mt)
end


-- lim:set_burst(burst)
function _M.set_burst(self, burst)
    assert(burst >= 0)

    self.burst = burst * 1000
end


-- local delay, err = lim:incoming(key, redis)
function _M.incoming(self, key, redis)
    if type(redis) ~= "table" then
        redis = {}
    end

    if not pcall(redis.get_reused_times, redis) then
        local cfg = redis
        local red, err = redis_create(cfg.host, cfg.port, cfg.timeout,
                                      cfg.pass, cfg.dbid)
        if not red then
            return nil, err
        end

        redis = red
    end

    local res, err = redis_commit(
        redis, self.zone, key, self.rate, self.burst, self.duration)
    if not res then
        return nil, err
    end

    local state, excess = res[1], res[2]
    if state == _M.BUSY or state == _M.FORBIDDEN then
        return nil, "rejected"
    end

    -- state = _M.OK
    return excess / self.rate, excess / 1000
end


return _M
