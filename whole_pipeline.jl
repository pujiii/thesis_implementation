include("merge_actions.jl")
include("parse_solution.jl")
include("conversion.jl")

# Solve problem
domain_path = "Implementation/domain.pddl"
problem_path = "Implementation/problem.pddl"

domain_hash = hash_file(domain_path)

# Load Blocksworld domain and problem
domain = load_domain(domain_path)
problem = load_problem(problem_path)

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct goal specification that requires minimizing plan length
spec = MinStepsGoal(problem)

# Construct A* planner with h_add heuristic
planner = AStarPlanner(HAdd())

# Find a solution given the initial state and specification
sol = planner(domain, state, spec)

db_name = "mydatabase.db"

store_macros(db_name, sol, domain_hash)

picked = pick_macros(db_name, domain)

merged_macros = [mergeActions([convert_action(action, domain) for action in macro_action], [convert_action(action, domain) for action in macro_action]) for macro_action in picked]