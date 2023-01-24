/**
* Name: small
* Based on the internal empty template. 
* Author: Super PC
* Tags: 
*/


model small

/* Insert your model definition here */

global{
	list<int> param_instance <- [0,1,2];
	list<string> param_approach <- ['planner', 'agent', 'hybrid'];
	list<int> param_tofail <- [0,1,2,3];
	int total_runs <- 3;
	list<int> param_seed <- range(1,total_runs);
	int idx_instance <- 0;
	int idx_approach <- 0;
	int idx_tofail <- 0;
	int idx_seed <- 0;
	string approach <- 'planner';
	int still_to_fail <- 0;
	int instance <- 0;
	int run_number <- 1;
	
	bool stop <- false;
	
	int smth <- 1;
	bool ping  <- true;
	bool temp <- false; 
	
	list test <- [[[1],[2],[3],[4]], [[1,1],[2,2],[3,3],[4,4]] ,[[1,1,1],[2,2,2],[3,3,3],[4,4,4]]];
	
	init{
		
		float x  <- 1.3;
		int intx  <- ceil(x) ;
		write "this is x: " + intx;
		write "seed: " + seed;
		write "rng: " + rng_usage;
	
		csv_file agf  <- csv_file("agents.csv", ";", true);
		matrix agent_data <- matrix(agf);
		
		create simAgents number: 1 {
			
		}
		
	}
	
	reflex read {
		write test[0,2];
		write test[1,2];
		write test[2][2];
		
	}
	

	
}

species simAgents  skills: [moving]{
	point location <- {1.25,2.0};
	int id <- -1;
	bool dontrun <- true;
	int counter <- 0;
	bool init <- true;
	
	reflex start when: init {
		
		init <- false;
		//write name;
	}
	

	
	
}

experiment "small test" type: batch repeat: 1 until: stop {//the stop condition is contained in the agent model
	float minimum_cycle_duration <- 1.0#s;
	float step <- 1#s;
	float seed <- 2;


	reflex end{
		write "end";
	}

}