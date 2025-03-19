using Pkg
Pkg.activate("./PDDL.jl")

using PDDL

a_1 = """
(:action unstack
   :parameters (?x ?y - block)
   :precondition (and (on ?x ?y) (clear ?x) (handempty) (not (= ?x ?y)))
   :effect (and (holding ?x) (clear ?y) (not (clear ?x))
                (not (handempty)) (not (on ?x ?y))))
"""

domain = parse_domain(domain_str)