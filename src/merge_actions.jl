# MERGE ACTIONS AND SHRINK PARAMETERS
function merge_actions_params(actions::Vector{PAction}, param_calls::Vector{Any}, final_params::Vector{PParam}) :: PAction
    # STEP 1: In each action, replace the parameter references with the corresponding parameter call names
    for i in 1:length(actions)
        action = actions[i]
        params_new = param_calls[i]
        for j in 1:length(action.params)
            param_original = action.params[j]
            param_new = params_new[j]
            replace_params!(action, param_original.name, param_new)
        end
    end

    # STEP 2: Divide & Conquer to merge the pre conditions and effects of the actions
    merged_action = div_conq_pre_post(actions)

    # STEP 3: Use merged preconditions and effects, together with `final_call_names` to create a new action
    # Make new name for the action (a_1-x-y-z-plus-a_2-y-z-plus-a_3-a-b, etc. for any number of actions)
    new_name = ""
    for i in 1:length(actions)
        action = actions[i]
        new_name *= string(action.name) * "--" * join([string(x) for x in param_calls[i]], "-")
        if i < length(actions)
            new_name *= "-plus-"
        end
    end

    merged_action.name = Symbol(new_name)
    merged_action.params = final_params
    return merged_action
end

function div_conq_pre_post(actions::Vector{PAction}) :: PAction
    if length(actions) == 1
        return action[1]
    elseif length(actions) == 2
        return div_conq_pre_post(actions[1], actions[2])
    end
    return div_conq_pre_post(actions[1], div_conq_pre_post(actions[2:end]))
end

function div_conq_pre_post(a₁::PAction, a₂::PAction) :: PAction
    # merge the preconditions and effects of a₁ and a₂
    pre = Set{PExpr}()
    eff = Set{PExpr}()
    
    # add all preconditions of a₁
    union!(pre, a₁.pre.args)

    # for each precondition of a₂
    for p in to_list(a₂.pre)
        # check if it is satisfied by the effects of a₁. if not, add it to the preconditions
        if !any([p == q for q in a₁.eff.args])
            push!(pre, p)
        end
    end

    # add all effects of a₂
    for e in to_list(a₂.eff) push!(eff, e) end

    # add each effect of a₁ that is not negated by a₂
    for e in to_list(a₁.eff)
        if !any([get_name(e) == q for q in get_names(a₂.eff)])
            push!(eff, e)
        end
    end

    res = deepcopy(a₁)
    res.pre = PAnd(collect(pre))
    res.eff = PAnd(collect(eff))
    return res
end

function replace_params!(action::PAction, from::Symbol, to::Symbol)
    # replace the parameter references in the preconditions and effects with the new names
    for e in vcat(to_list(action.pre), to_list(action.eff))
        args = e isa PPredCall ? e.args : e.arg.args
        for arg in args
            if arg.name == from
                setfield!(arg, :name, to)
            end
        end
    end
end

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
    for e in to_list(a₁.eff)
        if !any([get_name(e) == q for q in get_names(a₂.eff)])
            push!(eff, e)
        end
    end

    combined_params = vcat(a₁.params, a₂.params)

    combined_name = Symbol(string(a₁.name) * "-plus-" * string(a₂.name))
    
    return PAction(combined_name, combined_params, PAnd(collect(pre)), PAnd(collect(eff)))

end

function get_names(expr::PExpr) :: Vector{Symbol}
    list = to_list(expr)
    res = []
    for e in list
        if e isa PPredCall
            push!(res, e.pred.name)
        elseif e isa PNot{PPredCall}
            push!(res, e.arg.pred.name)
        end
    end
    return res
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
        return [expr]
    elseif expr isa PNot
        return [expr.arg]
    elseif expr isa PAnd
        return expr.args
    end
    # else throw an error
    error("Invalid expression type")
end