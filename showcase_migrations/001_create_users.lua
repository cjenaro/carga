return {
    up = function(db)
        db:create_table("users", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            name = "TEXT NOT NULL",
            email = "TEXT UNIQUE",
            age = "INTEGER",
            company_id = "INTEGER",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
        db:add_index("users", "email")
    end,
    down = function(db)
        db:drop_table("users")
    end
}