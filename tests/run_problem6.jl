using BenchmarkTools, Base.Threads

include("merge_actions.jl")
include("parse_solution.jl")
include("conversion.jl")
include("clear_db.jl")

# Function to export search tree to JSON
function export_search_tree_to_json(search_tree::Dict, static_predicates)
    # Find the root node
    root_id = nothing
    for (id, node) in search_tree
        if isnothing(node.parent.action)
            root_id = id
        end
    end

    # Reconstruct children relationships
    children_map = build_children_mapping(search_tree)

    # Convert the tree to a nested dictionary
    tree_dict = pathnode_to_dict(root_id, search_tree, children_map, static_predicates, 1)
    return tree_dict
end

# Recursive function to convert a node to a dictionary
function pathnode_to_dict(node_id, search_tree, children_map, static_predicates, current_depth)
    node = search_tree[node_id]  # Retrieve the node
    node_dict = Dict(
        "0_state" => [string(fact) for fact in node.state.facts if string(fact.name) ∉ static_predicates],  # Replace with proper serialization if needed
        "1_attributes" => Dict(
            "cost" => node.path_cost,  # Example attribute, adjust for your node structure
            "depth" => current_depth  # Example attribute, adjust as needed
        ),
        "children" => []
    )
    # Recursively process the children
    for child_id in children_map[node_id]
        push!(node_dict["children"], pathnode_to_dict(child_id, search_tree, children_map, static_predicates, current_depth + 1))
    end
    return node_dict
end

function build_children_mapping(search_tree::Dict)
    # Initialize an empty dictionary to store children for each node
    children_map = Dict(key => [] for key in search_tree.keys)
    for (node_id, node) in search_tree
        if !isnothing(node.parent.action)
            push!(children_map[node.parent.id], node_id)
        end
    end
    return children_map
end

function main()

    test_files_location = "pddlgym-problems/baking"
    domain_location = "pddlgym-problems/baking.pddl"
    problems_locations = test_files_location * "/"

    db_name = "mydatabase.db"
    domain = load_domain(domain_location)

    domain_hash = hash_file(domain_location)

    problem_name = "problem6.pddl"
    println("Start solving: $problem_name")
    problem = load_problem(problems_locations * "/" * problem_name)

    # solve problem
    state = initstate(domain, problem)
    spec = MinStepsGoal(problem)
    planner = AStarPlanner(NullHeuristic())
    # time how long it takes to solve the problem
    # bench = @benchmark sol = $planner($domain, $state, $spec) evals=1 samples=5
    # time_taken = mean(bench.times) / 1e9
    # sol = planner(domain, state, spec)

    # store_macros(domain, "params_" * db_name, sol, domain_hash, true)
    # return pick_macros("params_" * db_name, domain, domain_hash, 5, true)
    return problem

end

problem = main()

# converted_merged_macros = [convert_action(macro_action) for macro_action in macros]

# for macro_action in converted_merged_macros
#     show(macro_action)
#     println()
# end


# dict = export_search_tree_to_json(sol.search_tree, sol.static_predicates)