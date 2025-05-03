module DynamicMacros

include("clear_db.jl")
include("grammar.jl")
include("conversion.jl")
include("merge_actions.jl")
include("parse_solution.jl")

export clear_database, pick_macros, store_macros, convert_action, hash_file

end # module DynamicMacros
