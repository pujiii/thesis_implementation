# using Pkg; Pkg.add("BenchmarkTools"); Pkg.add("PlanningDomains"); Pkg.add("PDDL"); Pkg.add("SymbolicPlanners"); Pkg.add("Julog"); Pkg.add("SHA"); Pkg.add("SQLite"); Pkg.add("DataFrames"); Pkg.add("DBInterface"); Pkg.add("Tables")
using BenchmarkTools, Base.Threads, Timeout


include("merge_actions.jl")
include("parse_solution.jl")
include("conversion.jl")
include("utils.jl")
include("clear_db.jl")


function experiment_domain(domain_name::String, num_macros::Int, control::Bool = false)
    #################################
    # ENTER DOMAIN NAME HERE TO USE #
    #################################
    # domain_name = "baking"

    #################################

    test_files_location = "pddlgym-problems/"
    domain_location = test_files_location * domain_name * ".pddl"
    problems_locations = test_files_location * domain_name

    domain_hash = hash_file(domain_location)

    # get all filenames in folder problems_locations
    problem_files = readdir(problems_locations)

    # randomise the order of the files
    # shuffle!(problem_files)

    # divide into training and test set
    train_problems = problem_files[1:floor(Int, length(problem_files) * 0.8)]
    test_problems = problem_files[floor(Int, length(problem_files) * 0.8) + 1:end]

    planner = AStarPlanner(HAdd())
    planner.max_time = 600 # 1 hour
    # planner = RealTimeDynamicPlanner()

    domain = load_domain(domain_location)

    if control
        # stats_lock = ReentrantLock()
        # stats = []
        # @threads for i in eachindex(test_problems)
        #     problem_name = test_problems[i]
        #     println("Start solving: $problem_name")
        #     problem = load_problem(problems_locations * "/" * problem_name)

        #     # solve problem
        #     state = initstate(domain, problem)
        #     spec = MinStepsGoal(problem)
        #     # time how long it takes to solve the problem
        #     # bench = @benchmark sol = $planner($domain, $state, $spec) evals=1 samples=1
        #     # time_taken = mean(bench.times) / 1e9
        #     sol = planner(domain, state, spec)
        #     if sol.status == :max_time
        #         println("Timed out")
        #         lock(stats_lock) do
        #             push!(stats, ("before training", problem_name, "Timed out"))
        #             # num_solved += 1
        #             println("$problem_name solved")
        #         end
        #         continue
        #     end
        #     time_taken = sol.expanded

        #     println("Plan: " * string(sol.plan))

        #     lock(stats_lock) do
        #         push!(stats, ("before training", problem_name, time_taken))
        #         # num_solved += 1
        #         println("$problem_name solved")
        #     end
        # end
        # println(stats)
        # open("output_experiments.txt", "a") do file
        #     println(file, "$domain_name: $stats" )
        # end

        # Without using threading
        stats = []
        for i in eachindex(test_problems)
            problem_name = test_problems[i]
            println("Start solving: $problem_name")
            problem = load_problem(problems_locations * "/" * problem_name)

            # solve problem
            state = initstate(domain, problem)
            # spec = MinStepsGoal(problem)
            # costs = Dict([(action.name, !occursin("-plus-", string(action.name))) for action in values(domain.actions)])
            costs = Dict([(action.name, -(length(split(string(action.name), "-plus-")) - 1)) for action in values(domain.actions)])
            spec = MinActionCosts([PDDL.get_goal(problem)::Term], costs)
            # time how long it takes to solve the problem
            # bench = @benchmark sol = $planner($domain, $state, $spec) evals=1 samples=1
            # time_taken = mean(bench.times) / 1e9
            sol = planner(domain, state, spec)
            if sol.status == :max_time
                println("Timed out")
                push!(stats, ("before training", problem_name, "Timed out"))
                continue
            end
            time_taken = sol.expanded

            println("Plan: " * string(sol.plan))

            push!(stats, ("before training", problem_name, time_taken))
            println("$problem_name solved")
        end
        println(stats)
        open("output_experiments.txt", "a") do file
            println(file, "$domain_name: $stats" )
        end
    end



    stats = []

    old_domain = deepcopy(domain)
    db_name = "params_mydatabase.db"

    if (control) # If its the first run then train the database
        # Clear the database to prevent old knowledge from seeping in
        clear_database(db_name)
        # Now train the model on the training files
        for problem_name in train_problems
            println("Analysing: $problem_name")
            domain = deepcopy(old_domain)
            problem = load_problem(problems_locations * "/" * problem_name)

            # get the macro actions from the database
            picked = pick_macros(db_name, domain, domain_hash, num_macros, true)
            # merged_macros = [mergeActions([convert_action(action, domain) for action in macro_action], [convert_action(action, domain) for action in macro_action]) for macro_action in picked]
            converted_merged_macros = [convert_action(macro_action) for macro_action in picked]

            for macro_action in converted_merged_macros
                domain.actions[macro_action.name] = macro_action
            end

            # solve problem
            state = initstate(domain, problem)
            spec = MinStepsGoal(problem)
            # time how long it takes to solve the problem
            sol = planner(domain, state, spec)
            if sol.status == :max_time
                println("Timed out")
                continue
            end

            store_macros(domain, db_name, sol, domain_hash, true)
            println("Analysed $problem_name")
        end
    end

    # get the macro actions from the database
    picked = pick_macros(db_name, domain, domain_hash, num_macros, true)
    # merged_macros = [mergeActions([convert_action(action, domain) for action in macro_action], [convert_action(action, domain) for action in macro_action]) for macro_action in picked]
    converted_merged_macros = [convert_action(macro_action) for macro_action in picked]

    for macro_action in converted_merged_macros
        domain.actions[macro_action.name] = macro_action
    end

    # Now test the model on the test files again
    # stats_lock = ReentrantLock()
    # @threads for i in eachindex(test_problems)
    #     problem_name = test_problems[i]
    #     println("Start solving: $problem_name")
    #     problem = load_problem(problems_locations * "/" * problem_name)

    #     # solve problem
    #     state = initstate(domain, problem)
    #     spec = MinStepsGoal(problem)
    #     # time how long it takes to solve the problem
    #     # bench = @benchmark sol = $planner($domain, $state, $spec) evals=1 samples=1
    #     # time_taken = mean(bench.times) / 1e9
    #     sol = planner(domain, state, spec)
    #     if sol.status == :max_time
    #         println("Timed out")
    #         lock(stats_lock) do
    #             push!(stats, ("after training", problem_name, "Timed out"))
    #             println("Problem solved")
    #         end
    #         continue
    #     end
    #     println(sol.plan)
    #     time_taken = sol.expanded
        
    #     lock(stats_lock) do
    #         push!(stats, ("after training", problem_name, time_taken))
    #         println("Problem solved")
    #     end
    # end
    
    # Without using threading
    for i in eachindex(test_problems)
        problem_name = test_problems[i]
        println("Start solving: $problem_name")
        problem = load_problem(problems_locations * "/" * problem_name)

        # solve problem
        state = initstate(domain, problem)
        # spec = MinStepsGoal(problem)
        # costs = Dict([(action.name, !occursin("-plus-", string(action.name))) for action in values(domain.actions)])
        costs = Dict([(action.name, -(length(split(string(action.name), "-plus-")) - 1)) for action in values(domain.actions)])
        spec = MinActionCosts([PDDL.get_goal(problem)::Term], costs)
        # time how long it takes to solve the problem
        # bench = @benchmark sol = $planner($domain, $state, $spec) evals=1 samples=1
        # time_taken = mean(bench.times) / 1e9
        sol = planner(domain, state, spec)
        if sol.status == :max_time
            println("Timed out")
            push!(stats, ("after training", problem_name, "Timed out"))
            continue
        end
        println(sol.plan)
        time_taken = sol.expanded
        
        push!(stats, ("after training", problem_name, time_taken))
        println("Problem solved")
    end

    println(stats)
    open("output_experiments.txt", "a") do file
        println(file, "$domain_name ($num_macros macros): $stats" )
    end
end

function run_experiments()
    problem = "baking"
    for i in 1:10
        # for _ in 1:20
            
        # end
        if i == 1
                experiment_domain(problem, i, true)
        else
                experiment_domain(problem, i, false)
        end
    end
end

run_experiments()