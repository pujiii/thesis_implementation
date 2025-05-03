using PDDL

"""
    get_parent_type(name::Symbol, domain::PDDL.Domain) :: PType

Retrieve the parent type of a given type name within a specified PDDL domain.

# Arguments
- `name::Symbol`: The name of the type whose parent type is to be retrieved.
- `domain::PDDL.Domain`: The PDDL domain in which the type is defined.

# Returns
- `PType`: The parent type of the specified type name.

"""
function get_parent_type(name::Symbol, domain::PDDL.Domain) :: PType
    type_tree =  PDDL.get_typetree(domain)
    parent_type = only(key for (key, value) in type_tree if name in value)
    if parent_type == :object
        return PObjectType()
    else
        return PCustomType(parent_type, get_parent_type(parent_type, domain))
    end
end

"""
    get_predicates(domain::PDDL.Domain) :: Dict{Symbol, PPred}

Retrieve the predicates from a given PDDL domain.

# Arguments
- `domain::PDDL.Domain`: The PDDL domain from which to extract the predicates.

# Returns
- `Dict{Symbol, PPred}`: A dictionary where the keys are predicate names (as symbols) and the values are the corresponding predicate objects (`PPred`).

"""
function get_predicates(domain::PDDL.Domain) :: Dict{Symbol, PPred}
    predicates = Dict{Symbol, PPred}()
    for pred in collect(values(PDDL.get_predicates(domain)))
        predicates[pred.name] = PPred(pred.name, [get_parent_type(t, domain) for t in collect(pred.argtypes)])
    end
    if PDDL.get_requirements(domain)[:equality]
        predicates[:(==)] = PPred(:(==), [PAny(), PAny()])
    end
    return predicates
end

function convert_action(action::PDDL.Action, domain::PDDL.Domain) :: PAction
    predicates = get_predicates(domain)
    preconditions = convert_expr(PDDL.get_precond(action), predicates)
    effects = convert_expr(PDDL.get_effect(action), predicates)
    argtypes = map(t -> PParam(t[1].name, t[2] == :object ? PObjectType() : PCustomType(t[2], get_parent_type(t[2], domain))), collect(zip(PDDL.get_argvars(action), PDDL.get_argtypes(action))))
    return PAction(action.name, argtypes, preconditions, effects)
end

function convert_action(action::PAction) :: PDDL.GenericAction
    # Extract the name
    name = action.name

    # Convert params to Vector{Var} and Vector{Symbol}
    args = [Var(param.name) for param in action.params]  # Vector{Var}
    types = [param.type isa PObjectType ? :object : param.type.name for param in action.params]

    precond = convert_expr(action.pre)
    effect = convert_expr(action.eff)

    return PDDL.GenericAction(name, args, types, precond, effect)
end

function convert_expr(expr:: PExpr) :: Term
    if expr isa PPredCall
        return Compound(Symbol(expr.pred.name), [Var(arg.name) for arg in expr.args])
    elseif expr isa PNot
        return Compound(:not, [convert_expr(expr.arg)])
    elseif expr isa PAnd
        return Compound(:and, [convert_expr(arg) for arg in expr.args])
    end
end

function convert_expr(term::Term, predicates::Dict{Symbol, PPred}) :: PExpr
    if term.name == :and
        return PAnd([convert_expr(arg, predicates) for arg in term.args])
    elseif term.name == :not
        return PNot(convert_expr(term.args[1], predicates))
    else
        return PPredCall(predicates[Symbol(term.name)], [PParamRef(arg.name) for arg in term.args])
    end
end