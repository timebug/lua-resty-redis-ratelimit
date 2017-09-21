# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);
use Test::Nginx::Socket 'no_plan';

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;/usr/local/openresty/lualib/resty/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_REDIS_PORT} ||= 6379;

no_long_string();
#no_diff();

run_tests();

__DATA__
=== TEST 1: limit req
--- http_config eval: $::HttpConfig
--- config
    location /a {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "2r/s")
            if not lim then
                return ngx.exit(500)
            end

            local delay, err = lim:incoming(ngx.var.remote_addr)

            if not delay then
                if err == "rejected" then
                    return ngx.exit(503)
                end

                ngx.log(ngx.ERR, "failed to limit req: ", err)
                return ngx.exit(500)
            end
        ';

        echo Logged in;
    }
    location /b {
        content_by_lua '
            ngx.sleep(0.6)

            for i = 0, 9 do
                local res = ngx.location.capture("/a")
                ngx.say("#0", i, ": ", res.status)
                ngx.sleep(0.2)
            end

            ngx.sleep(0.6)
            ngx.say()

            for i = 0, 9 do
                local res = ngx.location.capture("/a")
                ngx.say("#1", i, ": ", res.status)
                ngx.sleep(0.4)
            end

            ngx.sleep(0.6)
            ngx.say()

            for i = 0, 9 do
                local res = ngx.location.capture("/a")
                ngx.say("#2", i, ": ", res.status)
                ngx.sleep(0.6)
            end
        ';
    }
--- request
GET /b
--- response_body
#00: 200
#01: 503
#02: 503
#03: 200
#04: 503
#05: 503
#06: 200
#07: 503
#08: 503
#09: 200

#10: 200
#11: 503
#12: 200
#13: 503
#14: 200
#15: 503
#16: 200
#17: 503
#18: 200
#19: 503

#20: 200
#21: 200
#22: 200
#23: 200
#24: 200
#25: 200
#26: 200
#27: 200
#28: 200
#29: 200
--- no_error_log
[error]
[warn]
--- timeout: 20


=== TEST 2: limit req with interval
--- http_config eval: $::HttpConfig
--- config
    location /a {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "2r/s", 0, 2)
            if not lim then
                return ngx.exit(500)
            end

            local delay, err = lim:incoming(ngx.var.remote_addr)

            if not delay then
                if err == "rejected" then
                    return ngx.exit(503)
                end

                ngx.log(ngx.ERR, "failed to limit req: ", err)
                return ngx.exit(500)
            end
        ';

        echo Logged in;
    }
    location /b {
        content_by_lua '
            ngx.sleep(0.6)

            for i = 0, 1 do
                local res = ngx.location.capture("/a")
                ngx.say("#0", i, ": ", res.status)
            end

            ngx.sleep(0.6)
            ngx.say()

            for i = 0, 1 do
                local res = ngx.location.capture("/a")
                ngx.say("#1", i, ": ", res.status)
                ngx.sleep(0.6)
            end

            ngx.sleep(0.6)
            ngx.say()

            for i = 0, 1 do
                local res = ngx.location.capture("/a")
                ngx.say("#2", i, ": ", res.status)
                ngx.sleep(0.6)
            end
        ';
    }
--- request
GET /b
--- response_body
#00: 200
#01: 503

#10: 503
#11: 503

#20: 200
#21: 200
--- no_error_log
[error]
[warn]
--- timeout: 20


=== TEST 3: limit req with different key
--- http_config eval: $::HttpConfig
--- config
    location /a {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()
            local method = ngx.req.get_method()

            local lim, _ = ratelimit.new(zone, "2r/s", 0, 2)
            if not lim then
                return ngx.exit(500)
            end

            local delay, err = lim:incoming(method)

            if not delay then
                if err == "rejected" then
                    return ngx.exit(503)
                end

                ngx.log(ngx.ERR, "failed to limit req: ", err)
                return ngx.exit(500)
            end
        ';

        echo Logged in;
    }
    location /b {
        content_by_lua '
            ngx.sleep(0.6)

            for i = 0, 1 do
                local res = ngx.location.capture("/a")
                ngx.say("#0", i, ": ", res.status)
            end

            ngx.sleep(0.6)
            ngx.say()

            for i = 0, 1 do
                local res = ngx.location.capture("/a",
                                 { method = ngx.HTTP_HEAD })
                ngx.say("#1", i, ": ", res.status)
                ngx.sleep(0.6)
            end

            ngx.sleep(0.6)
            ngx.say()

            for i = 0, 1 do
                local res = ngx.location.capture("/a")
                ngx.say("#2", i, ": ", res.status)
                ngx.sleep(0.6)
            end
        ';
    }
--- request
GET /b
--- response_body
#00: 200
#01: 503

#10: 200
#11: 200

#20: 200
#21: 200
--- no_error_log
[error]
[warn]
--- timeout: 20


=== TEST 4: limit req with burst
--- http_config eval: $::HttpConfig
--- config
    location /a {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "2r/s", 2)
            if not lim then
                return ngx.exit(500)
            end

            local delay, err = lim:incoming(ngx.var.remote_addr)

            if not delay then
                if err == "rejected" then
                    return ngx.exit(503)
                end

                ngx.log(ngx.ERR, "failed to limit req: ", err)
                return ngx.exit(500)
            end
        ';

        echo Logged in;
    }
    location /b {
        content_by_lua '
            ngx.sleep(0.6)

            for i = 0, 9 do
                local res = ngx.location.capture("/a")
                ngx.say("#0", i, ": ", res.status)
                ngx.sleep(0.2)
            end

            ngx.sleep(0.6)
            ngx.say()

            for i = 0, 9 do
                local res = ngx.location.capture("/a")
                ngx.say("#1", i, ": ", res.status)
                ngx.sleep(0.4)
            end

            ngx.sleep(0.6)
            ngx.say()

            for i = 0, 9 do
                local res = ngx.location.capture("/a")
                ngx.say("#2", i, ": ", res.status)
                ngx.sleep(0.6)
            end
        ';
    }
--- request
GET /b
--- response_body
#00: 200
#01: 200
#02: 200
#03: 200
#04: 503
#05: 200
#06: 503
#07: 503
#08: 200
#09: 503

#10: 200
#11: 200
#12: 200
#13: 200
#14: 200
#15: 200
#16: 200
#17: 503
#18: 200
#19: 200

#20: 200
#21: 200
#22: 200
#23: 200
#24: 200
#25: 200
#26: 200
#27: 200
#28: 200
#29: 200
--- no_error_log
[error]
[warn]
--- timeout: 20


=== TEST 5: a single key
--- http_config eval: $::HttpConfig
--- config
    location /t {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "40r/s", 40)
            if not lim then
                return ngx.exit(500)
            end

            local begin = ngx.now()

            for i = 1, 80 do
                local delay, err = lim:incoming(ngx.var.uri)

                if not delay then
                    ngx.say("failed to limit request: ", err)
                    return
                end
                ngx.sleep(delay)
            end
            ngx.say("elapsed: ", ngx.now() - begin, " sec.")
        ';
    }
--- request
GET /t
--- response_body_like eval
qr/^elapsed: 1\.9[6-9]\d* sec\.$/
--- no_error_log
[error]
[lua]
--- timeout: 10


=== TEST 6: multiple keys
--- http_config eval: $::HttpConfig
--- config
    location /t {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "2r/s", 10)
            if not lim then
                return ngx.exit(500)
            end

            local delay1, excess1 = lim:incoming("foo")
            local delay2, excess2 = lim:incoming("foo")
            local delay3, excess3 = lim:incoming("bar")
            local delay4, excess4 = lim:incoming("bar")
            ngx.say("delay1: ", delay1)
            ngx.say("excess1: ", excess1)
            ngx.say("delay2: ", delay2)
            ngx.say("excess2: ", excess2)
            ngx.say("delay3: ", delay3)
            ngx.say("delay4: ", delay4)
        ';
    }
--- request
GET /t
--- response_body
delay1: 0
excess1: 0
delay2: 0.5
excess2: 1
delay3: 0
delay4: 0.5
--- no_error_log
[error]
[lua]
--- timeout: 10


=== TEST 7: burst
--- http_config eval: $::HttpConfig
--- config
    location /t {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "2r/s", 0)
            if not lim then
                return ngx.exit(500)
            end

            for burst = 0, 5 do
                local key = "foo" .. tostring(burst)
                if burst > 0 then
                    lim:set_burst(burst)
                end

                for i = 1, 10 do
                    local delay, err = lim:incoming(key)
                    if not delay then
                        ngx.say(i, ": error: ", err)
                        break
                    end
                end
            end
        ';
    }
--- request
GET /t
--- response_body
2: error: rejected
3: error: rejected
4: error: rejected
5: error: rejected
6: error: rejected
7: error: rejected
--- no_error_log
[error]
[lua]
--- timeout: 10


=== TEST 8: forbidden state
--- http_config eval: $::HttpConfig
--- config
    location /t {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "2r/s", 0, 2)
            if not lim then
                return ngx.exit(500)
            end

            for i = 1, 20 do
                local delay, err = lim:incoming("foo")
                if not delay then
                    ngx.say(i, ": error: ", err)
                else
                    ngx.say(i, ": delay: ", delay)
                end
                ngx.sleep(0.2)
            end
        ';
    }
--- request
GET /t
--- response_body
1: delay: 0
2: error: rejected
3: error: rejected
4: error: rejected
5: error: rejected
6: error: rejected
7: error: rejected
8: error: rejected
9: error: rejected
10: error: rejected
11: error: rejected
12: delay: 0
13: error: rejected
14: error: rejected
15: error: rejected
16: error: rejected
17: error: rejected
18: error: rejected
19: error: rejected
20: error: rejected
--- no_error_log
[error]
[lua]
--- timeout: 10


=== TEST 9: create redis err
--- http_config eval: $::HttpConfig
--- config
    location /t {
        rewrite_by_lua '
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "2r/s")
            if not lim then
                return ngx.exit(500)
            end

            local red = { host = "127.0.0.1", port = 6388 }
            local delay, err = lim:incoming("foo", red)
            if not delay then
                ngx.say("error: ", err)
            end
        ';
    }
--- request
GET /t
--- response_body
error: failed to create redis - connection refused
--- no_error_log
[lua]
--- timeout: 10


=== TEST 10: create redis independent
--- http_config eval: $::HttpConfig
--- config
    location /t {
        rewrite_by_lua '
            local redis = require "resty.redis"
            local ratelimit = require "resty.redis.ratelimit"
            local zone = "test_" .. ngx.worker.pid()

            local lim, _ = ratelimit.new(zone, "2r/s")
            if not lim then
                return ngx.exit(500)
            end

            local limit_req = function(key)
                local red = redis:new()

                red:set_timeout(1000)

                local ok, err = red:connect("127.0.0.1", 6379)
                if not ok then
                    return nil, err
                end

                return lim:incoming("foo", red)
            end

            for i = 1, 5 do
                local delay, err = limit_req("foo")
                if not delay then
                    ngx.say(i, ": error: ", err)
                else
                    ngx.say(i, ": delay: ", delay)
                end
                ngx.sleep(0.2)
            end
        ';
    }
--- request
GET /t
--- response_body
1: delay: 0
2: error: rejected
3: error: rejected
4: delay: 0
5: error: rejected
--- no_error_log
[error]
[lua]
--- timeout: 10
