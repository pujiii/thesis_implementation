using PDDL, PlanningDomains, SymbolicPlanners, Julog, SHA, SQLite, DataFrames, DBInterface, Tables

function transform_expression(expr::String)
    # Remove the trailing close parenthesis
    expr = replace(expr, ")" => "")
    
    # Split the string into the function name and the arguments
    parts = split(expr, "(")
    
    # Extract the function name and the arguments
    func_name = parts[1]
    args = split(parts[2], ", ")
    
    # Join the function name and arguments into the desired format
    transformed_expr = "($func_name " * join(args, " ") * ")"
    
    return transformed_expr
end

function hash_file(filepath::String, algorithm=sha256)
    open(filepath, "r") do file
        return bytes2hex(algorithm(file))
    end
end

function add_or_update_macro_action(domain, db, hash, sub_actions, num_uses, size)
    # Check if the row already exists
    result = DBInterface.execute(db, """
        SELECT num_uses FROM macro_actions
        WHERE domain_hash = ? AND sub_actions = ?
    """, (hash, sub_actions))

    if !isempty(result)
        # a_1 + a_2 + ... + a_n was included in the domain, set cycles_last_included to 0. Otherwise increment it.
        sub_actions = split(sub_actions)
        macro_action_name = join(sub_actions, "-plus-")
        if macro_action_name in keys(domain.actions)
            DBInterface.execute(db, """
                UPDATE macro_actions
                SET cycles_last_included = 0
                WHERE domain_hash = ? AND sub_actions = ?
            """, (hash, join(sub_actions, " ")))
            # println("Updated Cycles: ($hash, " * join(sub_actions, " ") * ")")
        else
            DBInterface.execute(db, """
                UPDATE macro_actions
                SET cycles_last_included = cycles_last_included + 1
                WHERE domain_hash = ? AND sub_actions = ?
            """, (hash, join(sub_actions, " ")))
            # println("Updated Cycles: ($hash, " * join(sub_actions, " ") * ")")
        end

        # If the row exists, increment num_uses
        DBInterface.execute(db, """
            UPDATE macro_actions
            SET num_uses = num_uses + ?
            WHERE domain_hash = ? AND sub_actions = ?
        """, (num_uses, hash, join(sub_actions, " ")))
        # println("Updated: ($hash, " * join(sub_actions, " ") * ")")
    else
        # If the row doesn't exist, insert a new row
        DBInterface.execute(db, """
            INSERT INTO macro_actions (domain_hash, sub_actions, size, num_uses)
            VALUES (?, ?, ?, ?)
        """, (hash, sub_actions, size, num_uses))
        # println("Inserted: ($hash, $sub_actions)")
    end
end

function action_list(domain, actions)
    action_list = []

    for action_name in split(actions)
        push!(action_list, domain.actions[Symbol(action_name)])
    end
    return action_list
end

function store_macros(domain, db_name, sol, domain_hash)
    
    # Add to database
    db = SQLite.DB(db_name)

    # Define the table schema with a composite primary key
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS macro_actions (
            domain_hash TEXT,
            sub_actions TEXT,
            size INTEGER,
            num_uses INTEGER,
            cycles_last_included INTEGER DEFAULT -1,
            PRIMARY KEY (domain_hash, sub_actions)
        )
    """)

    plan = (PDDL.parse_pddl.(transform_expression.(string.(sol.plan))))

    # println(plan)
    # println("==========================")
    # First update all the used macro-actions
    for action in plan
        # println(action.name)
        # if action name contains "+"
        if occursin("-plus-", string(action.name))
            sub_actions = split(string(action.name), "-plus-")
            add_or_update_macro_action(domain, db, domain_hash, join(sub_actions, " "), 1, length(sub_actions))
        end
    end

    # Find all sublists n > 1 of the plan
    macro_actions = [plan[i:j] for i in 1:length(plan) for j in i:length(plan) if length(plan[i:j]) > 1]

    # turn into tuple (macro_action, number of uses in plan, length of macro action)
    macro_actions_info = [(domain_hash, join(split(replace(join([action.name for action in macro_action], " "), "-plus-" => " "), " "), " "), count(x -> x == macro_action, macro_actions), length(macro_action)) for macro_action in macro_actions]

    for entry in macro_actions_info
        add_or_update_macro_action(domain, db, entry...)
    end
    result = DBInterface.execute(db, "SELECT * FROM macro_actions") |> DataFrame
    # println(result)

    SQLite.close(db)
end

function pick_macros(db_name, domain, domain_hash, num_macros)
    # Add to database
    db = SQLite.DB(db_name)

    # Define the table schema with a composite primary key
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS macro_actions (
            domain_hash TEXT,
            sub_actions TEXT,
            size INTEGER,
            num_uses INTEGER,
            cycles_last_included INTEGER DEFAULT -1,
            PRIMARY KEY (domain_hash, sub_actions)
        )
    """)

    result = DBInterface.execute(db, """
    SELECT * FROM macro_actions 
    WHERE domain_hash = ? 
    ORDER BY (num_uses * size) DESC LIMIT ?""", (domain_hash, num_macros)) |> DataFrame

    SQLite.close(db)

    list_of_tuples = [Tuple(row) for row in eachrow(result)]

    # macro actions to add
    return [action_list(domain, row[2]) for row in list_of_tuples]
end