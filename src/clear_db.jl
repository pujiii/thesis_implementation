using SQLite, DataFrames

function clear_database(db)
    # Connect to the database
    db = SQLite.DB(db)

    # Delete all rows from the table
    SQLite.execute(db, "DELETE FROM macro_actions")

    # Close the connection
    SQLite.close(db)

    println("All rows deleted from the table.")

end

function select_all(db)
    # Connect to the database
    db = SQLite.DB(db)

    # Delete all rows from the table
    result = DBInterface.execute(db, "SELECT sub_actions, size, num_uses FROM macro_actions ORDER BY (size * num_uses) DESC") |> DataFrame
    println(result)

    # Close the connection
    SQLite.close(db)

end

# clear_database("mydatabase.db")