include("grammar.jl")

function mergeActions(actions::Vector{Action}) :: Action
    # base cases
    if length(actions) == 1
        return actions[1]
    elseif length(actions) == 2
        return mergeActions(actions[1], actions[2])
    end

    # recursive case
    return mergeActions(actions[1], mergeActions(actions[2:end]))
end

function uniquifyActions(a₁::Action, a₂::Action) :: Action
    # change the names of the parameters of a₁ to avoid conflicts with a₂
    for p in a₁.params
        while any([p.name == q.name for q in a₂.params])
            # recursively change names of all uses of p in a₁ to p_
            for e in vcat(to_list(a₁.pre)) vcat(to_list(a₁.eff))
                if e isa PPredCall
                    for arg in e.args
                        arg.name == p.name && (arg.name = Symbol(string(p.name, "_")))
                    end
                end
            end
        end
    end
end

function mergeActions(a₁::Action, a₂::Action) :: Action

    uniquifyActions(a₁, a₂)

    pre :: Set{PExpr} = []
    eff :: Set{PExpr} = []
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

    return Action(a₁.name * "+" * a₂.name, union(Set(a₁.params), Set(a₂.params)) , PAnd(pre), PAnd(eff))
end

function get_name(expr::PExpr) :: Symbol
    if expr isa PPredCall
        return expr.pred.name
    elseif expr isa PNot
        return expr.arg.pred.name
    end
end

function to_list(expr::PExpr) :: [Union{Ppred, PNot{PPred}}]
    if expr isa PPredCall
        return [expr.pred]
    elseif expr isa PNot
        return [expr.arg]
    elseif expr isa PAnd
        return expr.args
    end
end