LuaExpat
--------

[![Unix build](https://img.shields.io/github/actions/workflow/status/lunarmodules/luaexpat/unix_build.yml?branch=master&label=Unix%20build&logo=linux)](https://github.com/lunarmodules/luaexpat/actions/workflows/unix_build.yml)
[![Luacheck](https://github.com/lunarmodules/luaexpat/actions/workflows/luacheck.yml/badge.svg)](https://github.com/lunarmodules/luaexpat/actions/workflows/luacheck.yml)
[![License](https://img.shields.io/badge/license-MIT-success)](https://lunarmodules.github.io/luaexpat/license.html)

# Overview

LuaExpat is a SAX XML parser based on the Expat library. LuaExpat is free
software and uses the same license as Lua 5.1.

## Build

```shell
make LUA_V=jit-5.1 LUA_LDIR=/usr/local/share/lua/5.1 LUA_CDIR=/usr/local/lib/lua/5.1 LUA_INC=-I/usr/local/include/luajit-2.1 EXPAT_INC=-I/usr/local/opt/expat/include EXPAT_LIB="-L/usr/local/lib -lluajit-5.1 -L/usr/local/opt/expat/lib -lexpat"
make LUA_V=jit-5.1 LUA_LDIR=/usr/local/share/lua/5.1 LUA_CDIR=/usr/local/lib/lua/5.1 LUA_INC=-I/usr/local/include/luajit-2.1 EXPAT_INC=-I/usr/local/opt/expat/include EXPAT_LIB="-L/usr/local/lib -lluajit-5.1 -L/usr/local/opt/expat/lib -lexpat" INSTALL_PROGRAM=/usr/local/bin/ginstall install
```

## Download

LuaExpat source can be downloaded from the [github releases](https://github.com/lunarmodules/luaexpat/releases)
or from [LuaRocks](https://luarocks.org/search?q=luaexpat).

## History

For version history please [see the documentation](https://lunarmodules.github.io/luaexpat/index.html#history)

### Release instructions:

- ensure [the changelog](https://lunarmodules.github.io/luaexpat/index.html#history) is up to date and has
  the correct version and release date.
- update the [status](https://lunarmodules.github.io/luaexpat/index.html#status) section
- update copyright years at the [license page](https://lunarmodules.github.io/luaexpat/license.html) and
  the [LICENSE file](https://github.com/lunarmodules/luaexpat/blob/master/LICENSE).
- update version info and copyright in file
  [`lxplib.h`](https://github.com/lunarmodules/luaexpat/blob/master/src/lxplib.h)
- create a new rockspec file for the new version
- commit the above changes and create a PR
- after merging the PR tag it in `x.y.z` format, and push the tag (make sure the
  rockspec file is touched in the same commit that gets the version tag)
- the Github actions CI will automatically push a new LuaRocks release
- test the uploaded rock using: `luarocks install luaexpat`
- add the new release to the [Github releases](https://github.com/lunarmodules/luaexpat/releases)

## License

[MIT license](https://lunarmodules.github.io/luaexpat/license.html)

