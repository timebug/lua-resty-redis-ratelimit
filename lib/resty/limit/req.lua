-- Copyright (C) 2014 Monkey Zhang (timebug), UPYUN Inc.


local floor = math.floor
local tonumber = tonumber


local _M = { _VERSION = "0.01", OK = 1, BUSY = 2, FORBIDDEN = 3 }


local redis_limit_req_script_sha
local redis_limit_req_script = [==[
local key = KEYS[1]
local rate = tonumber(KEYS[2])
local now, interval = tonumber(KEYS[3]), tonumber(KEYS[4])

local excess, last, forbidden = 0, 0, 0

local res = redis.pcall('GET', key)
if res then
    local v = cjson.decode(res)
    if v and #v > 2 then
        excess, last, forbidden = v[1], v[2], v[3]
    end

    if forbidden == 1 then
        return {3, excess} -- FORBIDDEN
    end

    local ms = math.abs(now - last)
    excess = excess - math.floor(rate * ms / 1000) + 1000

    if excess < 0 then
        excess = 0
    end

    if excess > 0 then
        if interval > 0 then
            local res, err = redis.pcall('SET', key,
                                         cjson.encode({excess, now, 1}))
            if not res then
                return {err=err}
            end

            local res, err = redis.pcall('EXPIRE', key, interval)
            if not res then
                return {err=err}
            end
        end

        return {2, excess} -- BUSY
    end
end

local res, err = redis.pcall('SET', key, cjson.encode({excess, now, 0}))
if not res then
    return {err=err}
end

local res, err = redis.pcall('EXPIRE', key, 60)
if not res then
    return {err=err}
end

return {1, excess}
]==]


local function redis_lookup(conn, zone, key, rate, duration)
    local red = conn

    if not redis_limit_req_script_sha then
        local res, err = red:script("LOAD", redis_limit_req_script)
        if not res then
            return nil, err
        end

        ngx.log(ngx.NOTICE, "load redis limit req script")

        redis_limit_req_script_sha = res
    end

    local now = math.floor(ngx.now() * 1000)
    local res, err = red:evalsha(redis_limit_req_script_sha, 4,
                                 zone .. ":" .. key, rate, now, duration)
    if not res then
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
    if not cfg.conn then
        local ok, redis = pcall(require, "resty.redis")
        if not ok then
            ngx.log(ngx.ERR, "failed to require redis")
            return _M.OK
        end

        local rds = cfg.rds or {}
        rds.timeout = rds.timeout or 1
        rds.host = rds.host or "127.0.0.1"
        rds.port = rds.port or 6379

        local red = redis:new()

        red:set_timeout(rds.timeout * 1000)

        local ok, err = red:connect(rds.host, rds.port)
        if not ok then
            ngx.log(ngx.WARN, "redis connect err: ", err)
            return _M.OK
        end

        cfg.conn = red
    end

    local conn = cfg.conn
    local zone = cfg.zone or "limit_req"
    local key = cfg.key or ngx.var.remote_addr
    local rate = cfg.rate or "1r/s"
    local interval = cfg.interval or 0
    local log_level = cfg.log_level or ngx.NOTICE

    local scale = 1
    local len = #rate

    if len > 3 and rate:sub(len - 2) == "r/s" then
        scale = 1
        rate = rate:sub(1, len - 3)
    elseif len > 3 and rate:sub(len - 2) == "r/m" then
        scale = 60
        rate = rate:sub(1, len - 3)
    end

    rate = floor((tonumber(rate) or 1) * 1000 / scale)

    local res, err = redis_lookup(conn, zone, key, rate, interval)
    if res and (res[1] == _M.BUSY or res[1] == _M.FORBIDDEN) then
        if res[1] == _M.BUSY then
            ngx.log(log_level, 'limiting requests, excess ' ..
                        res[2]/1000 .. ' by zone "' .. zone .. '"')
        end
        return
    end

    if not res and err then
        ngx.log(ngx.WARN, "redis lookup err: ", err)
    end

    return _M.OK
end


return _M
