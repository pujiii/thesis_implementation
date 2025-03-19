include("grammar.jl")


function mergeActions(actions::Vector{PAction}, all_actions ::Vector{PAction}) :: PAction
    # base cases
    if length(actions) == 1
        return actions[1]
    elseif length(actions) == 2
        return mergeActions(actions[1], actions[2], all_actions)
    end

    # recursive case
    return mergeActions(actions[1], mergeActions(actions[2:end], all_actions), all_actions)
end

function is_unique(p :: PParam, actions :: Vector{PAction})
    return !any([any([p.name == q.name for q in a.params]) for a in actions])
end

function uniquifyActions!(a₁::PAction, other_actions::Vector{PAction})
    # change the names of the parameters of a₁ to avoid conflicts with a₂
    for p in a₁.params
        while !is_unique(p, other_actions)
            # recursively change names of all uses of p in a₁ to p_
            for e in vcat(to_list(a₁.pre), to_list(a₁.eff))
                args = e isa PPredCall ? e.args : e.arg.args
                for arg in args
                    if arg.name == p.name
                        setfield!(arg, :name, Symbol(string(arg.name) * "_"))
                    end
                end
            end
            setfield!(p, :name, Symbol(string(p.name) * "_"))
        end
    end
end

function mergeActions(a₁::PAction, a₂::PAction, all_actions :: Vector{PAction}) :: PAction
    
    other_actions = filter(x -> x != a₁, all_actions)
    uniquifyActions!(a₁, other_actions)

    other_actions = filter(x -> x != a₂, all_actions)
    uniquifyActions!(a₂, other_actions)

    pre = Set{PExpr}()
    eff = Set{PExpr}()
    # add all preconditions of a₁
    for p in a₁.pre.args push!(pre, p) end

    # for each precondition of a₂
    for p in to_list(a₂.pre)
        # check if it is satisfied by the effects of a₁. if not, add it to the preconditions
        if !any([p == q for q in a₁.eff.args])
            push!(pre, p)
        end
    end

    # add all effects of a₂
    for e in a₂.eff.args push!(eff, e) end

    # add each effect of a₁ that is not negated by a₂
    for e in a₁.eff.args
        if !any([e == get_name(q) for q in a₂.eff.args])
            push!(eff, e)
        end
    end

    combined_params = vcat(a₁.params, a₂.params)

    combined_name = Symbol(string(a₁.name) * "+" * string(a₂.name))
    
    return PAction(combined_name, combined_params, PAnd(collect(pre)), PAnd(collect(eff)))

end

function get_name(expr::PExpr) :: Symbol
    if expr isa PPredCall
        return expr.pred.name
    elseif expr isa PNot
        return expr.arg.pred.name
    end
end

function to_list(expr::PExpr) :: Vector{Union{PPredCall, PNot{PPredCall}}}
    if expr isa PPredCall
        return [expr.pred]
    elseif expr isa PNot
        return [expr.arg]
    elseif expr isa PAnd
        return expr.args
    end
    # else throw an error
    error("Invalid expression type")
end