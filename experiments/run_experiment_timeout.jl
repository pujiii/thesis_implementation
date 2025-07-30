# using Pkg; Pkg.add("BenchmarkTools"); Pkg.add("PlanningDomains"); Pkg.add("PDDL"); Pkg.add("SymbolicPlanners"); Pkg.add("Julog"); Pkg.add("SHA"); Pkg.add("SQLite"); Pkg.add("DataFrames"); Pkg.add("DBInterface"); Pkg.add("Tables")
using BenchmarkTools, Base.Threads, Timeout, CSV, Dates, DataFrames, ArgParse, DynamicMacros, PDDL, PlanningDomains, SymbolicPlanners, Julog, SHA, SQLite, DataFrames, DBInterface, Tables

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--trainonly", "-t"
            help = "Use if you only want to train the database."
            action = :store_true
            default = false
        "--domain", "-d"
            help = "another option with an argument"
            arg_type = String
            default = "baking"
        "--lower", "-l"
            help = "Lower bound of the number of macros to test"
            default = 0
        "--upper", "-u"
            help = "Upper bound of the number of macros to test"
            default = 10
        "--output", "-o"
            help = "Output folder"
            arg_type = String
            default = "output_experiments"
        "--num_macros_training", "-m"
            help = "Number of macros to train with"
            default = 5
        "--newdomainoutput", "-n"
            help = "Output folder for the domain"
            arg_type = String
        "--onlytest"
            help = "Use if you do not want to train the database."
            action = :store_true
            default = false
    end

    return parse_args(s)
end

function run_with_timeout(domain_name::String, problem_name::String; timeout_sec::Real=0.1)
    println("aaaaa")
    output = IOBuffer()
    # process = Base.open(cmd, output, read=true)
    # process = Base.open(, output, read=true)
    
    # task = @async wait(process)

    # while !istaskdone(task) && (time() - start_time < timeout_sec)
    #     sleep(0.1)  # Check every 100ms
    # end
    output = read(`python Implementation/experiments/timeout.py $(domain_name) $(problem_name)`, String)
    
    println("output: $output")

    expanded = parse(Int, split(output, "\n")[1])
    plan = split(split(output, "\n")[2], " ~ ")[1:end-1]

    return (; expanded=expanded, plan=plan)
end

mutable struct ExperimentTools
    db_name::String
    domain::Domain
    domain_hash::String
    planner::Planner
    test_problems::Vector{String}
    train_problems::Vector{String}
    all_problems::Vector{String}
    problems_location::String
    domain_name::String
    num_macros_training::Int
end

function train(experiment_tools::ExperimentTools, newdomainoutput::Union{String, Nothing})
    # Clear the database to prevent old knowledge from seeping in
    clear_database(experiment_tools.db_name, experiment_tools.domain)
    # Now train the model on the training files
    for problem_name in experiment_tools.train_problems
        println("Analysing: $problem_name")
        domain = deepcopy(experiment_tools.domain)
        problem = load_problem(experiment_tools.problems_location * "/" * problem_name)

        # get the macro actions from the database
        picked = pick_macros(experiment_tools.db_name, experiment_tools.domain, experiment_tools.domain_hash, experiment_tools.num_macros_training)
        converted_merged_macros = [convert_action(macro_action) for macro_action in picked]

        for macro_action in converted_merged_macros
            domain.actions[macro_action.name] = macro_action
        end

        # solve problem
        state = initstate(experiment_tools.domain, problem)
        spec = MinStepsGoal(problem)
        # time how long it takes to solve the problem
        sol = experiment_tools.planner(domain, state, spec)
        if sol.status == :max_time
            println("Timed out")
            continue
        end

        store_macros(experiment_tools.domain, experiment_tools.db_name, sol, experiment_tools.domain_hash)
        println("Analysed $problem_name")
        # if last iteration, save the domain
        save_domain(domain, "temp/domain.pddl")
    end
end

function dynamically_test(experiment_tools::ExperimentTools, num_macros::Int, output_folder::String, output_file::String, mode::String, sort_by::String)
    
    df = DataFrame(
        domain_name = String[],
        num_macros = Int[],
        problem_name = String[],
        expanded = Int[],
        mode=String[],
        sort_by=String[]
    )
    
    # Clear the database to prevent old knowledge from seeping in
    clear_database(experiment_tools.db_name, experiment_tools.domain)
    # Now train the model on the training files
    for problem_name in experiment_tools.all_problems
        println("Solving+analysing: $problem_name")
        domain = deepcopy(experiment_tools.domain)
        problem = load_problem(experiment_tools.problems_location * "/" * problem_name)

        # get the macro actions from the database
        picked = pick_macros(experiment_tools.db_name, experiment_tools.domain, experiment_tools.domain_hash, experiment_tools.num_macros_training, mode, sort_by)
        converted_merged_macros = [convert_action(macro_action) for macro_action in picked]

        println(converted_merged_macros)
        for macro_action in converted_merged_macros
            domain.actions[macro_action.name] = macro_action
        end

        println("Saving domain")
        save_domain("temp/domain.pddl", domain)

        sol = run_with_timeout(experiment_tools.domain_name, problem_name)

        if sol.expanded == -1
            println("Timed out")
            push!(df, (experiment_tools.domain_name, num_macros, problem_name, -1, mode, sort_by))
            continue
        end

        store_macros(experiment_tools.domain, experiment_tools.db_name, sol, experiment_tools.domain_hash)
        println("Solved+analysed $problem_name")
        
        push!(df, (experiment_tools.domain_name, num_macros, problem_name, sol.expanded, mode, sort_by))
    end
    
    mkpath(output_folder)
    CSV.write("$(output_folder)/$(output_file).csv", df, append=true)
end

function build_experiment_tools(domain_name::String, db_name::String, num_macros_training::Int, timeout::Int = 600)
    test_files_location = "pddlgym-problems/"
    domain_location = test_files_location * domain_name * ".pddl"
    problems_locations = test_files_location * domain_name

    # get all filenames in folder problems_locations
    problem_files = readdir(problems_locations)

    # divide into training and test set
    train_problems = problem_files[1:floor(Int, length(problem_files) * 0.8)]
    test_problems = problem_files[floor(Int, length(problem_files) * 0.8) + 1:end]

    planner = AStarPlanner(HAdd())
    planner.max_time = timeout # 1 hour

    domain = load_domain(domain_location)
    domain_hash = hash_file(domain_location)

    return ExperimentTools(db_name, domain, domain_hash, planner, test_problems, train_problems, problem_files, problems_locations, domain_name, num_macros_training)
end

function test_problems(experiment_tools::ExperimentTools, num_macros::Int, output_folder::String, output::String)

    df = DataFrame(
        domain_name = String[],
        num_macros = Int[],
        problem_name = String[],
        expanded = Int[]
    )

    domain = deepcopy(experiment_tools.domain)

    if num_macros > 0
        # get the macro actions from the database
        picked = pick_macros(experiment_tools.db_name, domain, experiment_tools.domain_hash, num_macros)
        converted_merged_macros = [convert_action(macro_action) for macro_action in picked]

        for macro_action in converted_merged_macros
            domain.actions[macro_action.name] = macro_action
        end
    end

    save_domain("temp/domain.pddl", domain)


    for i in eachindex(experiment_tools.all_problems)
        problem_name = experiment_tools.all_problems[i]
        println("Start solving: $problem_name")
        # problem = load_problem(experiment_tools.problems_location * "/" * problem_name)

        # # solve problem
        # state = initstate(domain, problem)
        # # spec = MinStepsGoal(problem)
        # # costs = Dict([(action.name, !occursin("-plus-", string(action.name))) for action in values(domain.actions)])
        # costs = Dict([(action.name, -(length(split(string(action.name), "-plus-")) - 1)) for action in values(domain.actions)])
        # spec = MinActionCosts([PDDL.get_goal(problem)::Term], costs)
        # spec = MinStepsGoal(problem) # use the original goal for the problem

        # sol = experiment_tools.planner(domain, state, spec)
        # if sol.status == :max_time
        #     println("Timed out")
        #     push!(df, (experiment_tools.domain_name, num_macros, problem_name, -1))
        #     continue
        # end
        sol = run_with_timeout(experiment_tools.domain_name, problem_name)

        if sol.expanded == -1
            println("Timed out")
            push!(df, (experiment_tools.domain_name, num_macros, problem_name, -1))
            continue
        end

        # println(sol.plan)
        time_taken = sol.expanded
        
        push!(df, (experiment_tools.domain_name, num_macros, problem_name, time_taken))
        println("Problem solved")
    end
    mkpath(output_folder)
    CSV.write("$(output_folder)/$(output).csv", df, append=(num_macros > 0))
end

function main()
    parsed_args = parse_commandline()

    problem = parsed_args["domain"]
    datetime = Dates.format(Dates.now(), "yyyy-mm-dd_HHMMSS")
    db_name = "params_mydatabase.db"
    
    experiment_tools = build_experiment_tools(problem, db_name, parsed_args["num_macros_training"], 60)

    # if !parsed_args["onlytest"] train(experiment_tools, parsed_args["newdomainoutput"]) end
    # if parsed_args["trainonly"] return end # Do not test if train_only
    
    # for i in parsed_args["lower"]:parsed_args["upper"]
    #     test_problems(experiment_tools, i, "output_experiments", datetime)
    # end

    # first test all problems with no macros
    if !parsed_args["trainonly"]
        test_problems(experiment_tools, 0, parsed_args["output"], datetime) 
    end

    if parsed_args["onlytest"] return end

    sort_by = ["num_uses", "size", "num_uses * size", "num_uses * num_unique_actions", "num_unique_actions", "random()"]
    # sort_by = ["size", "num_uses * size", "num_uses * num_unique_actions", "num_unique_actions", "random()"]

    # sort_by = ["num_uses * size", "num_uses * num_unique_actions", "num_unique_actions", "random()"]

    # sort_by = ["num_uses"]

    for s in sort_by
        dynamically_test(experiment_tools, parsed_args["num_macros_training"], parsed_args["output"], datetime, "best", s)
    end
end

main()
