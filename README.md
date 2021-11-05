In virtualbox:

1. run the mmt
2. run the planner
	a. manipulate the counter file to specify how and when seed is reset --> explain this in a clearer way

Run in GAMA> GLOCAL Batch. To change the parameters, go to the experiment section of the gitagent.gaml file.


-------------------------
configuration files for the planner

Delete the seed logging file before each re start of the planner

instance (0,1,2) approach (planner, agent, hybrid) case (0 - 3 failures) number of runs (1-30)

re_start.txt
	first line: -1, 0 , 1

		-1 for inverse instance 

		0 for normal run

		1 for reading data from the file and starting from there

		-1 also reads data from the file

	2nd line -> starting run (only here $desiredNumber - 1) $desiredNumber starts from 0

	3rd line -> max number of runs (no more than 30, starting from 1)

	4th line -> approach, starts from 0
	5th line -> approachMax, starts from 1, max is 3
	6th line -> case, starts from 0, max is 3
	7th line -> caseMax, starts from 1, max is 4
	8th line -> instance number, starts from 0

     
