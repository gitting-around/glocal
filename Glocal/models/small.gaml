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
	float seed  <- 1;
	
	bool stop <- false;
	
	int smth <- 1;
	bool ping  <- true;
	bool temp <- false; 
	init{
		    	write "creating";
		int i <- 1;
		create simAgents number: 5
		    {
				//loop i over: range(1,5){
					list temp <-  [3,4];
					if length(temp) > 0 {
						write "length bigger than zero";
					}
					temp <-  [1];
					if length(temp) > 0{
						write "length bigger than zero";
					}
					id <-  i;
					i <- i + 1;
					name <- string(i);
					list tmp <-  [3,4] +[3,4] ;
					add 1 to: tmp;
					write tmp;
					write rnd(1.0);
				//}
		    }
		write simAgents.population;
	}
	
}

species simAgents  skills: [moving]{
	point location <- {1.25,2.0};
	int id <- -1;
	bool dontrun <- true;
	
	list pending_tasks <- [];
	 reflex pinging{//This will run only once at the beginning
	 		
	 		//write "Self knows failed: " + combined;
			loop i over:  range(1,5){
				write i;
				add [] to: pending_tasks;
				
			}
			if id=1{
				
			write agents_at_distance(5);
			write  (agents_at_distance(5) sort_by (each.name));
			write agents_at_distance(5);
			}
	 		write pending_tasks;
			loop i over:  range(0,4){
				write i;
				pending_tasks[i] <- [1,2];
			}
	 		write pending_tasks;
	 		
    		if id = 1{
    			ask simAgents{
    				write "ID " + id;
    				if ! (id=1){
    				do die;
    				}
    			}
    			
		write simAgents.population;
    		}	
    }
	
	reflex testWander when: !dontrun{
		if id=1{
				
			write location;
			do wander;
			write location;
		}
	}
}

experiment "small test" type: batch repeat: 1 until: stop {//the stop condition is contained in the agent model
	float minimum_cycle_duration <- 1.0#s;
	float step <- 1#s;
	init{
		write "creating from exp";
	}

	reflex end{
		write "end";
	}

}