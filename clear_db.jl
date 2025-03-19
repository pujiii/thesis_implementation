using SQLite


function clear_database(db)
    # Connect to the database
    db = SQLite.DB(db)

    # Delete all rows from the table
    SQLite.execute(db, "DELETE FROM mytable")

    # Close the connection
    SQLite.close(db)

    println("All rows deleted from the table.")

end

clear_database("mydatabase.db")