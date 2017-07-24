local floor = math.floor
local tonumber = tonumber
local cjson = require("cjson")
local redis = nil
if not package.loaded['redis'] then
    local ok
    ok, redis = pcall(require, "resty.redis")
    if not ok then
        ngx.log(ngx.ERR, "failed to require resty.redis")
        return _M.OK
    end
end

local _M = { _VERSION = "0.03", OK = 1, BUSY = 2, FORBIDDEN = 3 }

local log_level = ngx.INFO

local function _redis_connect(rds)
    rds.host = rds.host or "127.0.0.1"
    rds.port = rds.port or 6379
    rds.timeout = rds.timeout or 1

    local red = redis:new()

    red:set_timeout(rds.timeout * 1000)

    local r, err
    if rds.socket then
        _, err = red:connect(rds.socket)
        r = rds.socket
    else
        _, err = red:connect(rds.host, rds.port)
        r  = rds.host
    end

    if err then
        ngx.log(log_level, "failed to connect to redis host: " .. r .. " ", err)
        return
    end

    if rds.pass then
        local _, err = red:auth(rds.pass)
        if err then
            ngx.log(log_level, "failed to authenticate to redis host" .. r .. " ", err)
            return
        end
    end

    return red
end


local function _redis_keepalive(conn, timeout, size)
    local _, err = conn:set_keepalive(timeout, size)
    if err then
        ngx.log(log_level, "failed to set keepalive: ", err)
    end
end


local function _redis_lookup(redis_conn, zone, key, rate, interval, burst)
    local excess, last, forbidden = 0, 0, 0
    local res, err = nil, nil
    local now = ngx.now() * 1000
    local ms = math.abs(now - last)

    local res, err = redis_conn:get(zone .. ":" .. key)

    if err then
        ngx.log(log_level, "redis lookup error for key " .. zone .. ":" .. key .. " " .. err)
        return {_M.OK}
    end

    if type(res) == "string" then
        local v = cjson.decode(res)
        if v and #v > 2 then
            excess, last, forbidden = v[1], v[2], v[3]
        end

        if forbidden == 1 then
            return {_M.FORBIDDEN, excess}
        end

        excess = excess - rate * ms / 1000 + 1000

        if excess < 0 then
            excess = 0
        end

        if excess > burst then
            if interval > 0 then
                -- res, err = redis_conn:setex(zone .. ":" .. key, interval, cjson.encode({excess, now, 1}))

                if err then
                    ngx.log(log_level, "redis update error for key " .. zone .. ":" .. key .. " " .. err)
                    return {_M.OK}
                end
            end
            return {_M.BUSY, excess}
        end
    end

    -- res, err = redis_conn:setex(zone .. ":" .. key, 10, cjson.encode({excess, now, 0}))

    if err then
        ngx.log(log_level, "redis update error for key " .. zone .. ":" .. key .. " " .. err)
    end

    return {_M.OK}
end


function _M.limit(cfg)
    if not package.loaded['redis'] then
        local ok, redis = pcall(require, "resty.redis")
        if not ok then
            ngx.log(log_level, "failed to require resty.redis")
            return _M.OK
        end
    end

    local zone = cfg.zone or "limit_req"
    local key = cfg.key or ngx.var.remote_addr
    local rate = cfg.rate or "1r/s"
    local burst = cfg.burst * 1000 or 0
    local interval = cfg.interval or 0
    log_level = cfg.log_level or log_level

    local redis_conn = _redis_connect(cfg.redis)
    if not redis_conn then
        ngx.log(log_level, "failed to connect to redis")
        return _M.OK
    end

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

    local res = _redis_lookup(redis_conn, zone, key, rate, interval, burst)
    if res and (res[1] == _M.BUSY or res[1] == _M.FORBIDDEN) then
       if res[1] == _M.BUSY then
           ngx.log(log_level, "excess requests " ..
                   zone .. ":" .. key .. " - " .. res[2]/1000 )
       end
       return
    end

    _redis_keepalive(redis_conn, 10000, 100)

    return _M.OK
end


return _M