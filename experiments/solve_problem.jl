using BenchmarkTools, Base.Threads, Timeout, CSV, Dates, DataFrames, ArgParse, DynamicMacros, PDDL, PlanningDomains, SymbolicPlanners, Julog, SHA, SQLite, DataFrames, DBInterface, Tables

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--domainname", "-d"
            help = "another option with an argument"
            arg_type = String
            default = "baking"
        "--problem", "-p"
            help = "another option with an argument"
            arg_type = String
            default = "p01.pddl"
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    domain = load_domain("temp/domain.pddl")
    problem = load_problem("pddlgym-problems/$(parsed_args["domainname"])/$(parsed_args["problem"])")

    state = initstate(domain, problem)
    spec = MinStepsGoal(problem) 

    planner = AStarPlanner(HAdd())

    sol = planner(domain, state, spec)
    if sol.status == :success 
        println(sol.expanded) 
        for term in sol.plan
            print("$term ~ ")
        end
    else
        println("-1")
    end
end

main()