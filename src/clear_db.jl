using SQLite, DataFrames

function clear_database(db, domain)
    # Connect to the database
    db = SQLite.DB(db)

    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS macro_actions (
            domain_hash TEXT,
            sub_actions TEXT,
            size INTEGER,
            num_uses INTEGER,
            cycles_last_included INTEGER DEFAULT $(length(domain.actions) * 100),
            num_unique_actions INTEGER DEFAULT 0,
            PRIMARY KEY (domain_hash, sub_actions)
        )
    """)

    # Delete all rows from the table
    SQLite.execute(db, "DELETE FROM macro_actions")

    # Close the connection
    SQLite.close(db)

    println("All rows deleted from the table.")

end

function select_all(db, domain)
    # Connect to the database
    db = SQLite.DB(db)

    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS macro_actions (
            domain_hash TEXT,
            sub_actions TEXT,
            size INTEGER,
            num_uses INTEGER,
            cycles_last_included INTEGER DEFAULT $(length(domain.actions) * 100),
            num_unique_actions INTEGER DEFAULT 0,
            PRIMARY KEY (domain_hash, sub_actions)
        )
    """)

    # Delete all rows from the table
    result = DBInterface.execute(db, "SELECT sub_actions, size, num_uses FROM macro_actions ORDER BY (size * num_uses) DESC") |> DataFrame
    println(result)

    # Close the connection
    SQLite.close(db)

end

# clear_database("mydatabase.db")