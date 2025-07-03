-- Example: Creating a well-typed Movie model with Carga
-- This example demonstrates the inline type annotations for full LSP support
local carga = require("carga")

-- Configure Carga
carga.configure({
    database_path = "examples/movies.db",
    enable_logging = true
})

-- Connect to database
carga.connect()

---@class Movie : Model
---@field id number Primary key
---@field title string Movie title
---@field director string Movie director
---@field year number Release year
---@field rating number Rating (1-10)
---@field genre string Movie genre
---@field duration number Duration in minutes
---@field description string Movie description
---@field created_at string Creation timestamp
---@field updated_at string Update timestamp
local Movie = carga.Model:extend("Movie", "movies")

-- Define schema with proper field types
Movie.schema = {
    id = { type = "integer", primary_key = true, auto_increment = true },
    title = { type = "text" },
    director = { type = "text" },
    year = { type = "integer" },
    rating = { type = "real" },
    genre = { type = "text" },
    duration = { type = "integer" },
    description = { type = "text" },
    created_at = { type = "datetime" },
    updated_at = { type = "datetime" }
}

-- Define validations with proper types
Movie.validations = {
    title = { required = true, type = "string" },
    director = { required = true, type = "string" },
    year = { required = true, type = "number", min = 1900, max = 2030 },
    rating = { type = "number", min = 1, max = 10 },
    genre = { required = true, type = "string" },
    duration = { type = "number", min = 1 }
}

-- Example usage with full type safety
local function demonstrate_typed_model()
    print("=== Carga Typed Model Example ===")
    
    -- Create a new movie instance (fully typed)
    local movie = Movie:new({
        title = "The Matrix",
        director = "The Wachowskis", 
        year = 1999,
        rating = 8.7,
        genre = "Sci-Fi",
        duration = 136,
        description = "A computer programmer discovers reality is a simulation."
    })
    
    -- Type-safe attribute access
    local title = movie:get_attribute("title")  -- string
    local year = movie:get_attribute("year")    -- number
    
    print("Movie: " .. title .. " (" .. year .. ")")
    
    -- Validate before saving (returns boolean)
    if movie:valid() then
        local success = movie:save()  -- boolean
        if success then
            print("Movie saved successfully!")
            print("Movie ID: " .. movie:get_attribute("id"))
        else
            print("Failed to save movie")
        end
    else
        print("Validation errors:")
        local errors = movie:get_errors()  -- table<string, string[]>
        for field, field_errors in pairs(errors) do
            for _, error_msg in ipairs(field_errors) do
                print("  " .. field .. ": " .. error_msg)
            end
        end
    end
    
    -- Type-safe querying
    local all_movies = Movie:all()  -- Movie[]
    print("Total movies: " .. #all_movies)
    
    -- Find by ID (returns Movie? - might be nil)
    local found_movie = Movie:find(1)  -- Movie?
    if found_movie then
        print("Found movie: " .. found_movie:get_attribute("title"))
    end
    
    -- Query with conditions (returns Movie[])
    local sci_fi_movies = Movie:where({ genre = "Sci-Fi" })  -- Movie[]
    print("Sci-Fi movies: " .. #sci_fi_movies)
    
    -- Find by conditions (returns Movie? - might be nil)
    local matrix = Movie:find_by({ title = "The Matrix" })  -- Movie?
    if matrix then
        -- Update with type safety
        local update_success = matrix:update({
            rating = 9.0,
            description = "A groundbreaking sci-fi film about simulated reality."
        })  -- boolean
        
        if update_success then
            print("Movie updated successfully!")
        end
    end
    
    -- Advanced querying with method chaining
    -- Note: These would need to be implemented in QueryBuilder for full type safety
    -- local recent_movies = Movie:where("year > ?", {2020}):order("year", "DESC"):limit(10)
    
    print("=== Example completed ===")
end

-- Run the example
demonstrate_typed_model()

-- Clean up
carga.disconnect()

return Movie