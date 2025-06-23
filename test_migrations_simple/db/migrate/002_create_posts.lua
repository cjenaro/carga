return {
    up = function(db)
        db:create_table("posts", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            title = "TEXT NOT NULL",
            content = "TEXT",
            user_id = "INTEGER",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
    end,
    
    down = function(db)
        db:drop_table("posts")
    end
}
