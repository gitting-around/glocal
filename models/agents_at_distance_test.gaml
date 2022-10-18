/**
* Name: small
* Based on the internal empty template. 
* Author: Super PC
* Tags: 
*/


model agentsatdistancetest

/* Insert your model definition here */

global{
	int run_number <- 1;
	float seed  <- 1;
	
	bool stop <- false;
	
	int smth <- 1;
	bool ping  <- true;
	bool temp <- false; 
	init{
		write "creating";
		
		write seed;
		int i <- 1;
		create simAgents number: 5
		    {
				id <-  i;
				i <- i + 1;
				name <- string(i);
				
		    }
		write simAgents.population;
	}
	
}

species simAgents  skills: [moving]{
	point location <- {1.25,2.0};
	int id <- -1;
	
	 reflex pinging{//This will run only once at the beginning
	 		
			if id=1{
				write agents_at_distance(1.0);
			}
    }
	
	reflex testWander{
	
		do wander;

	}
}

experiment "small test" type: batch repeat: 5 until: cycle>10 {//the stop condition is contained in the agent model
	float minimum_cycle_duration <- 1.0#s;
	float step <- 1#s;
	init{
		write "creating from exp";
	}
}



