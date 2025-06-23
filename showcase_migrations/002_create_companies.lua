return {
    up = function(db)
        db:create_table("companies", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            name = "TEXT NOT NULL",
            industry = "TEXT"
        })
    end,
    down = function(db)
        db:drop_table("companies")
    end
}