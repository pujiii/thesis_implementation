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

function add_or_update_macro_action_with_params(domain, db, hash, sub_actions, num_uses, size)
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

function add_or_update_macro_action(domain, db, hash, sub_actions, num_uses, size, merge_params=false)
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

function anonymize_terms(terms::Vector{Compound})
    new_terms = []
    # Collect all unique variables from all terms
    all_vars = unique(reduce(vcat, [t.args for t in terms], init=Symbol[]))
    
    # Create mapping from original vars to anonymized vars
    var_mapping = Dict{Symbol,Symbol}()
    for (i, var) in enumerate(all_vars)
        var_mapping[var.name] = Symbol("var$i")
    end
    
    for term in terms
        args = [Const(var_mapping[arg.name]) for arg in term.args]
        push!(new_terms, Compound(term.name, args))
    end

    return new_terms
end

function store_macros_with_params(domain, db_name, sol, domain_hash)

     # Add to database
    db = SQLite.DB(db_name)

    # Define the table schema with a composite primary key
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS macro_actions (
            domain_hash TEXT,
            sub_actions TEXT,
            size INTEGER,
            num_uses INTEGER,
            cycles_last_included INTEGER DEFAULT $(length(domain.actions) * 100),
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

    for i in eachindex(macro_actions) 
        macro_actions[i] = anonymize_terms(macro_actions[i])
    end

    # turn into tuple (macro_action, number of uses in plan, length of macro action)
    macro_actions_info = [(domain_hash, join(split(replace(join([string(action.name) * "|" * join(["-" * string(param) for param in action.args]) for action in macro_action], " "), "-plus-" => " "), " "), " "), count(x -> x == macro_action, macro_actions), length(macro_action)) for macro_action in macro_actions]

    for entry in macro_actions_info
        add_or_update_macro_action(domain, db, entry...)
    end
    # result = DBInterface.execute(db, "SELECT * FROM macro_actions") |> DataFrame
    # println(result)

    SQLite.close(db)
end

function store_macros(domain, db_name, sol, domain_hash, merge_params=false)
    if merge_params return store_macros_with_params(domain, db_name, sol, domain_hash) end

        # Add to database
    db = SQLite.DB(db_name)

    # Define the table schema with a composite primary key
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS macro_actions (
            domain_hash TEXT,
            sub_actions TEXT,
            size INTEGER,
            num_uses INTEGER,
            cycles_last_included INTEGER DEFAULT $(length(domain.actions) * 100),
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
            add_or_update_macro_action(domain, db, domain_hash, join(sub_actions, " "), 1, length(sub_actions), true)
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

function pick_macros_with_params(db_name, domain, domain_hash, num_macros)
    # Add to database
    db = SQLite.DB(db_name)

    # Define the table schema with a composite primary key
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS macro_actions (
            domain_hash TEXT,
            sub_actions TEXT,
            size INTEGER,
            num_uses INTEGER,
            cycles_last_included INTEGER DEFAULT $(length(domain.actions) * 100),
            PRIMARY KEY (domain_hash, sub_actions)
        )
    """)

    result = DBInterface.execute(db, """
    SELECT * FROM macro_actions 
    WHERE domain_hash = ? 
    ORDER BY (num_uses * size) DESC LIMIT ?""", (domain_hash, num_macros)) |> DataFrame

    SQLite.close(db)

    list_of_tuples = [Tuple(row) for row in eachrow(result)]

    merged_actions :: Vector{PAction} = []

    for row in list_of_tuples
        actions = [split(action, "|") for action in split(row[2])]
        action_objects :: Vector{PAction}= []
        param_calls = []
        final_params = Set{PParam}()
        for i in eachindex(actions)
            action = domain.actions[Symbol(actions[i][1])]
            push!(action_objects, convert_action(action, domain))
            param_names = [Symbol(x) for x in split(actions[i][2], "-")[2:end]]
            param_types = [typename == :object ? PObjectType() : PCustomType(typename, get_parent_type(typename, domain)) for typename in PDDL.get_argtypes(action)]
            params = [PParam(param_names[i], param_types[i]) for i in eachindex(param_names)]
            union!(final_params, Set(params))
            push!(param_calls, param_names)
        end
        push!(merged_actions, merge_actions_params(action_objects, collect(param_calls), collect(final_params)))
    end
    
    return merged_actions
end

function pick_macros(db_name, domain, domain_hash, num_macros, merge_params=false)
    if merge_params return pick_macros_with_params(db_name, domain, domain_hash, num_macros) end
    # Add to database
    db = SQLite.DB(db_name)

    # Define the table schema with a composite primary key
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS macro_actions (
            domain_hash TEXT,
            sub_actions TEXT,
            size INTEGER,
            num_uses INTEGER,
            cycles_last_included INTEGER DEFAULT $(length(domain.actions) * 100),
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
    picked = [action_list(domain, row[2]) for row in list_of_tuples]
    return [mergeActions([convert_action(action, domain) for action in macro_action], [convert_action(action, domain) for action in macro_action]) for macro_action in picked]
end