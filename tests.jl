include("merge_actions.jl")
include("conversion.jl")

domain_str = """
(define (domain blocksworld)
  (:requirements :strips :typing :equality)
  (:types block)
  (:predicates (on ?x ?y - block) (ontable ?x - block) (clear ?x - block)
               (handempty) (holding ?x - block))
  (:action pick-up
   :parameters (?x - block)
   :precondition (and (clear ?x) (ontable ?x) (handempty))
   :effect (and (not (ontable ?x)) (not (clear ?x))
                (not (handempty))  (holding ?x)))
  (:action put-down
   :parameters (?x - block)
   :precondition (holding ?x)
   :effect (and (not (holding ?x)) (clear ?x)
                (handempty) (ontable ?x)))
  (:action stack
   :parameters (?x ?y - block)
   :precondition (and (holding ?x) (clear ?y) (not (= ?x ?y)))
   :effect (and (not (holding ?x)) (not (clear ?y)) (clear ?x)
                (handempty) (on ?x ?y)))
  (:action unstack
   :parameters (?x ?y - block)
   :precondition (and (on ?x ?y) (clear ?x) (handempty) (not (= ?x ?y)))
   :effect (and (holding ?x) (clear ?y) (not (clear ?x))
                (not (handempty)) (not (on ?x ?y))))
)
"""

domain = parse_domain(domain_str)

# stack = PDDL.get_actions(domain)[:stack]
# unstack = PDDL.get_actions(domain)[:unstack]

# pa_1 = convert_action(stack, domain)
# pa_2 = convert_action(unstack, domain)

# a_12 = mergeActions(pa_1, pa_2, [pa_1, pa_2])


pred_p1 = PPred(:p1, [PObjectType()])
pred_p2 = PPred(:p2, [PObjectType()])

a₁ = PAction(:b, 
            [PParam(:x, PObjectType())], 
            PAnd(
                [PPredCall(pred_p2, [PParamRef(:x)])]
                ), 
            PAnd(
                [PPredCall(pred_p1, [PParamRef(:x)]),
                 PNot(PPredCall(pred_p2, [PParamRef(:x)]))]
                )
            )

a₂ = PAction(:a, 
            [PParam(:x, PObjectType())], 
            PAnd(
                [PPredCall(pred_p1, [PParamRef(:x)])]
                ), 
            PAnd(
                [PNot(PPredCall(pred_p2, [PParamRef(:x)]))]
                )
            )

a1_converted = convert_action(a₁, domain)
a2_converted = convert_action(a₂, domain)

# a₃ = mergeActions(a₁, a₂, [a₁, a₂])

# Action(Symbol("b+a"),
#         PParam[PParam(:x_, PObjectType()), PParam(:x, PObjectType())], 
#         PAnd(
#             Union{PNot{PPredCall}, PPredCall}[
#                 PPredCall(PPred(:p1, PType[PObjectType()]), PParamRef[PParamRef(:x)]), 
#                 PPredCall(PPred(:p2, PType[PObjectType()]), PParamRef[PParamRef(:x)])]), 
#         PAnd(
#             Union{PNot{PPredCall}, PPredCall}[
#                 PNot{PPredCall}(
#                     PPredCall(PPred(:p2, PType[PObjectType()]), PParamRef[PParamRef(:x)])), 
#                 PPredCall(PPred(:p1, PType[PObjectType()]), PParamRef[PParamRef(:x)]), 
#                 PNot{PPredCall}(
#                     PPredCall(PPred(:p2, PType[PObjectType()]), PParamRef[PParamRef(:x)]))])
#     )