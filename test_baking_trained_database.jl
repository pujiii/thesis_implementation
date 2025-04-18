test_files_location = "pddlgym-problems/baking"
domain_location = ".pddl"
problems_locations = test_files_location * "/"

db_name = "mydatabase.db"
domain = load_domain(domain_location)

# get the macro actions from the database
picked = pick_macros(db_name, domain, domain_hash, num_macros)
merged_macros = [mergeActions([convert_action(action, domain) for action in macro_action], [convert_action(action, domain) for action in macro_action]) for macro_action in picked]
converted_merged_macros = [convert_action(macro_action) for macro_action in merged_macros]

for macro_action in converted_merged_macros
    domain.actions[macro_action.name] = macro_action
end

problem_name = "problem6.pddl"
println("Start solving: $problem_name")
problem = load_problem(problems_locations * "/" * problem_name)

# solve problem
state = initstate(domain, problem)
spec = MinStepsGoal(problem)
# time how long it takes to solve the problem
# bench = @benchmark sol = $planner($domain, $state, $spec) evals=1 samples=5
# time_taken = mean(bench.times) / 1e9
sol = planner(domain, state, spec)
time_taken = sol.expanded

println("Problem solved")