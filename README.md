# lua-resty-limit-req

It is used to limit the request processing rate per a defined key with multiple NGINX instances. The limitation is done using the "[leaky bucket](http://en.wikipedia.org/wiki/Leaky_bucket)" method.

# Status

Ready for testing. Probably production ready in most cases, though not yet proven in the wild. Please check the issues list and let me know if you have any problems / questions.

## Synopsis

````lua
lua_package_path "/path/to/lua-resty-limit-req/lib/?.lua;;";

server {

    listen 9090;

    location /t {
        access_by_lua '
            local req = require "resty.limit.req"

            local ok = req.limit{ key = ngx.var.remote_addr, zone = "one",
                                  rate = "2r/s", interval = 2, log_level = ngx.NOTICE,
                                  rds = { host = "127.0.0.1", port = 6379 }}

            if not ok then
                return ngx.exit(503)
            end
        ';

        echo Logged in;
    }

}
````

# Author

Monkey Zhang <timebug.info@gmail.com>, UPYUN Inc.

Inspired from http://nginx.org/en/docs/http/ngx_http_limit_req_module.html.

# Licence

This module is licensed under the 2-clause BSD license.

Copyright (c) 2014, Monkey Zhang <timebug.info@gmail.com>, UPYUN Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
