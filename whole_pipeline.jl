include("merge_actions.jl")
include("parse_solution.jl")
include("conversion.jl")
include("utils.jl")

# Solve problem
domain_path = "Implementation/domain.pddl"
problem_path = "Implementation/problem.pddl"
db_name = "mydatabase.db"

# Load Blocksworld domain and problem
domain = load_domain(domain_path)
problem = load_problem(problem_path)

# for action in domain.actions
#     rename_key!(domain.actions, action.name, "_" * action.name)
# end

picked = pick_macros(db_name, domain)

merged_macros = [mergeActions([convert_action(action, domain) for action in macro_action], [convert_action(action, domain) for action in macro_action]) for macro_action in picked]

converted_merged_macros = [convert_action(macro_action) for macro_action in merged_macros]

# hard copy old domain and add picked macro actions
new_domain = deepcopy(domain)
for macro_action in converted_merged_macros
    new_domain.actions[macro_action.name] = macro_action
end

domain_hash = hash_file(domain_path)

# Construct initial state from domain and problem
state = initstate(new_domain, problem)

# Construct goal specification that requires minimizing plan length
spec = MinStepsGoal(problem)

# Construct A* planner with h_add heuristic
planner = AStarPlanner(HAdd())

# Find a solution given the initial state and specification
sol = planner(new_domain, state, spec)

store_macros(new_domain, db_name, sol, domain_hash)