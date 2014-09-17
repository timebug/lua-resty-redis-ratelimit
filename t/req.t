# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (4 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;/usr/local/openresty/lualib/resty/*.lua;;";
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
            local req = require "resty.limit.req"

            local ok = req.limit{ key = ngx.var.remote_addr, zone = "test",
                                  rate = "2r/s", interval = 0, log_level = ngx.NOTICE,
                                  rds = { host = "127.0.0.1", port = 6379 } }

            if not ok then
                return ngx.exit(503)
            end
        ';

        echo Logged in;
    }
    location /b {
        content_by_lua '
            ngx.sleep(0.5)

            for i = 1, 10 do
                local res = ngx.location.capture("/a")
                ngx.say("#0: ", res.status)
                ngx.sleep(0.2)
            end

            ngx.sleep(0.5)
            ngx.say()

            for i = 1, 10 do
                local res = ngx.location.capture("/a")
                ngx.say("#1: ", res.status)
                ngx.sleep(0.4)
            end

            ngx.sleep(0.5)
            ngx.say()

            for i = 1, 10 do
                local res = ngx.location.capture("/a")
                ngx.say("#2: ", res.status)
                ngx.sleep(0.5)
            end
        ';
    }
--- request
GET /b
--- response_body
#0: 200
#0: 503
#0: 503
#0: 200
#0: 503
#0: 503
#0: 200
#0: 503
#0: 503
#0: 200

#1: 200
#1: 503
#1: 200
#1: 503
#1: 200
#1: 503
#1: 200
#1: 503
#1: 200
#1: 503

#2: 200
#2: 200
#2: 200
#2: 200
#2: 200
#2: 200
#2: 200
#2: 200
#2: 200
#2: 200
--- no_error_log
[error]
[warn]
--- timeout: 20


=== TEST 2: limit req with interval
--- http_config eval: $::HttpConfig
--- config
    location /a {
        rewrite_by_lua '
            local req = require "resty.limit.req"

            local ok = req.limit{ key = ngx.var.remote_addr, zone = "test",
                                  rate = "2r/s", interval = 2, log_level = ngx.NOTICE }

            if not ok then
                return ngx.exit(503)
            end
        ';

        echo Logged in;
    }
    location /b {
        content_by_lua '
            ngx.sleep(0.5)

            for i = 1, 2 do
                local res = ngx.location.capture("/a")
                ngx.say("#0: ", res.status)
            end

            ngx.sleep(0.5)
            ngx.say()

            for i = 1, 2 do
                local res = ngx.location.capture("/a")
                ngx.say("#1: ", res.status)
                ngx.sleep(0.5)
            end

            ngx.sleep(0.5)
            ngx.say()

            for i = 1, 2 do
                local res = ngx.location.capture("/a")
                ngx.say("#2: ", res.status)
                ngx.sleep(0.5)
            end
        ';
    }
--- request
GET /b
--- response_body
#0: 200
#0: 503

#1: 503
#1: 503

#2: 200
#2: 200
--- no_error_log
[error]
[warn]
--- timeout: 20


=== TEST 3: limit req with different key
--- http_config eval: $::HttpConfig
--- config
    location /a {
        rewrite_by_lua '
            local req = require "resty.limit.req"
            local method = ngx.req.get_method()

            local ok = req.limit{ key = method, zone = "test",
                                  rate = "2r/s", interval = 2, log_level = ngx.NOTICE }

            if not ok then
                return ngx.exit(503)
            end
        ';

        echo Logged in;
    }
    location /b {
        content_by_lua '
            ngx.sleep(0.5)

            for i = 1, 2 do
                local res = ngx.location.capture("/a")
                ngx.say("#0: ", res.status)
            end

            ngx.sleep(0.5)
            ngx.say()

            for i = 1, 2 do
                local res = ngx.location.capture("/a", { method = ngx.HTTP_HEAD })
                ngx.say("#1: ", res.status)
                ngx.sleep(0.5)
            end

            ngx.sleep(0.5)
            ngx.say()

            for i = 1, 2 do
                local res = ngx.location.capture("/a")
                ngx.say("#2: ", res.status)
                ngx.sleep(0.5)
            end
        ';
    }
--- request
GET /b
--- response_body
#0: 200
#0: 503

#1: 200
#1: 200

#2: 200
#2: 200
--- no_error_log
[error]
[warn]
--- timeout: 20
