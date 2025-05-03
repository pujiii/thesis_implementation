import Base: ==, hash

abstract type PType end

mutable struct PObjectType <: PType end

mutable struct PCustomType <: PType
    name::Symbol
    type::PType
end

mutable struct PAny <: PType end

mutable struct PPred 
    name::Symbol
    params::Vector{PType}
end

mutable struct PParam
    name::Symbol
    type::PType
end

# Define equality (==) for your types
==(a::PParam, b::PParam) = a.name == b.name && a.type == b.type
==(a::PObjectType, b::PObjectType) = true  # All PObjectTypes are equal
==(a::PCustomType, b::PCustomType) = a.name == b.name && a.type == b.type

# Define matching hash functions
hash(p::PParam, h::UInt) = hash((p.name, p.type), h)
hash(::PObjectType, h::UInt) = hash(:PObjectType, h)  # Singleton-like hashing
hash(p::PCustomType, h::UInt) = hash((p.name, p.type), h)

mutable struct PParamRef
    name::Symbol
end

abstract type PExpr end

mutable struct PPredCall <: PExpr
    pred::PPred
    args::Vector{PParamRef}
end

mutable struct PNot{T <: PExpr} <: PExpr
    arg::T
end

mutable struct PAnd <: PExpr
    args::Vector{Union{PPredCall, PNot{PPredCall}}}
end

mutable struct PAction
    name::Symbol
    params::Vector{PParam}
    pre::PExpr
    eff::PExpr
end

function Base.show(io::IO, obj::PObjectType)
    println(io, "object")
end

function Base.show(io::IO, obj::PCustomType)
    println(io, obj.name)
end

function Base.show(io::IO, pred::PPred)
    println(io, pred.name, " (pred)")
end

function Base.show(io::IO, param::PParam)
    println(io, param.name , " : ", param.type)
end

function Base.show(io::IO, paramRef::PParamRef)
    println(io, ":", paramRef.name)
end

function Base.show(io::IO, predCall::PPredCall)
    println(io, predCall.pred, "(", predCall.args, ")")
end

function Base.show(io::IO, notExpr::PNot)
    println(io, "¬(", notExpr.arg, ")")
end

function Base.show(io::IO, andExpr::PAnd)
    println(io, "PAnd(args: [")
    for (i, arg) in enumerate(andExpr.args)
        print(io, "  ", arg)
        if i < length(andExpr.args)
            println(io, ",")
        else
            println(io)
        end
    end
    println(io, "])")
end

function Base.show(io::IO, action::PAction)
    println(io, "PAction: ", action.name)
    println(io, "  Params: ", action.params)
    println(io, "  Preconditions: ", action.pre)
    println(io, "  Effects: ", action.eff)
end