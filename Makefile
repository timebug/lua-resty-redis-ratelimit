# git clone https://github.com/timebug/lua-resty-redis-ratelimit.git
# cat Makefile
# make install DESTDIR= LUA_LIB_DIR=/usr/local/openresty/lualib
OPENRESTY_PREFIX=/usr/local/openresty

PREFIX ?=          /usr/local
LUA_INCLUDE_DIR ?= $(PREFIX)/include
LUA_LIB_DIR ?=     $(PREFIX)/lib/lua/$(LUA_VERSION)
INSTALL ?= install

.PHONY: all test install

all: ;

install: all
	$(INSTALL) -d $(DESTDIR)/$(LUA_LIB_DIR)/resty/redis
	$(INSTALL) lib/resty/redis/*.lua $(DESTDIR)/$(LUA_LIB_DIR)/resty/redis/

test: all
	# PATH=$(OPENRESTY_PREFIX)/nginx/sbin:$$PATH prove -I../test-nginx/lib -r t
	PATH=$(OPENRESTY_PREFIX)/nginx/sbin:$$PATH TEST_NGINX_NO_SHUFFLE=1 prove -I../test-nginx/lib -r t
	util/lua-releng
