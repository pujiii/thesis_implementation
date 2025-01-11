abstract type PType end

struct PObject <: PType end

struct PCustomType <: PType
    name::Symbol
    type::PType
end

struct PPred 
    name::Symbol
    params::Vector{PType}
end

struct PParam
    name::Symbol
    type::PType
end

abstract type PExpr end

struct PPredCall <: PExpr
    pred::PPred
    args::Vector{PParam}
end

struct PAnd <: PExpr
    args::Vector{PExpr}
end

struct PNot{T <: PExpr} <: PExpr
    arg::T
end

struct Action
    name::Symbol
    params::Vector{PParam}
    pre::PExpr
    eff::PExpr
end