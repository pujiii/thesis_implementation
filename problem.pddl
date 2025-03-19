(define 
    (problem letseat-simple)
	(:domain letseat)
	(:objects
    	arm - robot
    	cupcake1 - cupcake
		cupcake2 - cupcake
    	table - location
    	plate - location
	)

	(:init
		(on arm table)
		(on cupcake1 plate)
		(on cupcake2 table)
		(arm-empty)
		(path plate table)
		(path table plate)
	)

	(:goal 
		(on cupcake1 table)
		(on cupcake2 plate)
	)
)