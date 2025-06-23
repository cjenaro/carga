return {
    up = function(db)
        db:create_table("users", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            name = "TEXT NOT NULL",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
    end,
    
    down = function(db)
        db:drop_table("users")
    end
}
