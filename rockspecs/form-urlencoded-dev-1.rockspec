package = "form-urlencoded"
version = "dev-1"
source = {
    url = "git+https://github.com/mah0x211/lua-form-urlencoded.git",
}
description = {
    summary = "encode/decode the application/x-www-form-urlencoded format.",
    homepage = "https://github.com/mah0x211/lua-form-urlencoded",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "errno >= 0.3.0",
    "isa >= 0.3.0",
    "url >= 2.0.0",
}
build = {
    type = "builtin",
    modules = {
        ['form.urlencoded'] = "lib/urlencoded.lua",
    },
}
