return {
    up = function(db)
        db:add_column("users", "email", "TEXT UNIQUE")
    end,
    
    down = function(db)
        db:drop_column("users", "email")
    end
}
