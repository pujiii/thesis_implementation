"""
    MacroCountHeuristic(dir=:forward)

Heuristic that counts the number of macro_actions in the current plan.
"""
struct MacroCountHeuristic <: Heuristic end

function compute(h::MacroCountHeuristic,
                 domain::Domain, state::State, spec::Specification)

    count = sum(!satisfy(domain, state, g) for g in goals)
    return h.dir == :backward ? length(goals) - count : count
end