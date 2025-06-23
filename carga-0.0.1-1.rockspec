package = "carga"
version = "0.0.1-1"
source = {
   url = "git://github.com/foguete/carga.git",
   tag = "v0.0.1"
}
description = {
   summary = "Active Record ORM for Lua with SQLite",
   detailed = [[
      Carga is a SQLite-based Active Record ORM that brings Rails-like 
      database patterns to Lua. Features include model inheritance, 
      associations, validations, callbacks, query builder, and migrations.
   ]],
   homepage = "https://github.com/foguete/carga",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "lsqlite3 >= 0.9.0"
}
build = {
   type = "builtin",
   modules = {
      ["carga"] = "src/init.lua",
      ["carga.src.database"] = "src/database.lua",
      ["carga.src.model"] = "src/model.lua",
      ["carga.src.query_builder"] = "src/query_builder.lua",
      ["carga.src.associations"] = "src/associations.lua",
      ["carga.src.migration"] = "src/migration.lua"
   }
}