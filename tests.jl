include("merge_actions.jl")
pred_p1 = PPred(:p1, [PObjectType()])
pred_p2 = PPred(:p2, [PObjectType()])

a₁ = Action(:b, 
            [PParam(:x, PObjectType())], 
            PAnd(
                [PPredCall(pred_p2, [PParamRef(:x)])]
                ), 
            PAnd(
                [PPredCall(pred_p1, [PParamRef(:x)]),
                 PNot(PPredCall(pred_p2, [PParamRef(:x)]))]
                )
            )

a₂ = Action(:a, 
            [PParam(:x, PObjectType())], 
            PAnd(
                [PPredCall(pred_p1, [PParamRef(:x)])]
                ), 
            PAnd(
                [PNot(PPredCall(pred_p2, [PParamRef(:x)]))]
                )
            )

a₃ = mergeActions(a₁, a₂, [a₁, a₂])

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