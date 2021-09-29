/**
* Name: gitagent_batch
* Based on the internal empty template. 
* Author: Super PC
* Tags: 
*/


model gitagent_batch

global{
	
	///////////////////////////////////////////////////////////////////
	//Defining parameters for batch experiments////////////////////////
	//list<int> param_instance <- [0,1,2];
	list<int> param_instance <- [0,1,2];
	list<string> param_approach <- ['planner', 'agent', 'hybrid'];
	//list<string> param_approach <- ['agent', 'hybrid'];
	list<int> param_tofail <- [0,1,2,3];
	int total_runs <- 30;
	//list<string> param_approach <- ['agent'];
	//list<int> param_tofail <- [3];
	//int total_runs <- 1;
	list<int> param_seed <- range(1,total_runs);
	int idx_instance <- 0;
	int idx_approach <- 0;
	int idx_tofail <- 0;
	int idx_seed <- 0;
	///////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////
	
	int total_nr_simAgents <- 0;
	int simAgents_nr_hardcoded <- 10; //TODO keep in mind the nr of agents need to be preset here
	int msgs_sent <- 0;
	int completed_tasks <- 0;
	int completed_tasks_zeroed <- 0;
	bool mission_complete <- false;
	bool simulation_init <- true;
	geometry shape <- rectangle(150#m,150#m);
	float communication_range <- 20#m;
	int mission_count <-0;
	bool stop <- false;
	bool ping  <- true; 
	
	//Related to inducing failures
	float fail_prob <- 0.001;
	bool plan_active <- false;
	bool asking_planner <- false;
	string approach <- param_approach[0];
	int still_to_fail <- 0;
	int instance <- 0;
	int run_number <- 1;
	float seed <- float(run_number);
	
	string output_file_base <- "inst" + instance + "_" + approach + "_fails_" + still_to_fail + "_" + run_number + "_";
	
	list known_failed <- [];//Look at this!!!
	
	bool verbose <- true;
	
	int simAgent_idx <- 0;
	//Initialization of the sockets should be done already here
	init {
		
		write "Initializing";
		//This server receives the requests from the planner executing externally somewhere

		write "Initializing server";
		create simulation_server number:1
		{
			do connect to: "130.243.73.174" protocol: "tcp_server" port: 10002 with_name: name;
			do join_group with_name:"server_group";
		}
		//Agents that will actually perform the tasks. They can also send messages directly to the planner.
		create simAgents number: simAgents_nr_hardcoded
	    {
	    	
	    	do connect to: "130.243.73.174" protocol: "tcp_client" port: 10000 with_name: name;
			do join_group with_name:"client_group";
			loop i over: range(1,simAgents_nr_hardcoded){
				
				add [] to: pending_tasks;
			}
			
	    }
		//as there is only one server, the code below has no weight here. 
		//However, in the off chance this might change, this can be useful.
		//so we keep it.
		ask one_of(simulation_server) {
			isLeader <- true;
		}
		
		write "Running experiment with instance " + instance + " with approach " + approach + " with failures " + still_to_fail + " and run number " + run_number;
		
	}
	
	reflex shutdown when: stop{
		
		write "Simulation end!!" color: #red;
		do die;
	}
	
}

species simulation_server skills: [network]{
	rgb color <- rgb(255,0,0);
	bool isLeader <- false;
	float size <- 5.0;
	point location <- {5.0, 10.0};
	int startTime <- 0;
	
	list<int> alive_agents;
	list<int> dead_agents;

	//Reflexes are executed on every cycle, it is possible to define conditionals with when:
	//The reflex below executes only when there are messages in the queue
	reflex receive when:has_more_message()
	{   
		loop while:has_more_message()
		{
			mission_count <- mission_count +1;
			message mm <- fetch_message();
			write name + " received : " + mm.contents + ", at time:" + cycle color: color;
			
			//Parse message from the Planner
			list items <- string(mm.contents) split_with ('+');
			list ag <- items[0] split_with ('$');
			list ta <- items[1] split_with ('$');
			write ag;
			write ta;
			//On simulation init, initialize both simAgents and tasks with the locations and equipments as defined in the plan
			if simulation_init{
				startTime <- cycle;
				total_nr_simAgents <- length(ag);
				if total_nr_simAgents != simAgents_nr_hardcoded{
					write "[ERROR]: number of agents doesn't match" color: #red;
				}
				write "Initializing "+total_nr_simAgents+" agents";
				//Ask each agent to update its attributes -- this is similar to a for loop
			    ask simAgents {
			    	length_original_taskset <- length(ta);
			    	starttime <- cycle;
			    	list ag_attr <- ag[simAgent_idx] split_with(';');
			    	add ag_attr[0] as_int 10 to: myself.alive_agents;
			    	write ag_attr;
			    	name <- ag_attr[0];
					
					location <- {float(ag_attr[1]), float(ag_attr[2])};
					equipment <- ag_attr[3] split_with (',');
					//TODO check what to do with speed
					//speed <- float(ag_attr[3]);
					write "agent " + name + " at location " + location + " with equipment " + equipment + " at speed " + speed; 
					if verbose{
						save ("agent " + name + " at location " + location + " with equipment " + equipment + " at speed " + speed) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					
			    	simAgent_idx <- simAgent_idx + 1;
			    }
				write "Alive agents: " + alive_agents;
				write "Initializing "+length(ta)+" tasks";
				if verbose{
					save ( "Alive agents: " + alive_agents + "\n" + "Initializing "+length(ta)+" tasks") to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
				int t_idx <- 0;
				//Create as many tasks as there are in the plan, and initialize the locations and equipments.
				
				create tasks number: length(ta){
					list ta_attr <- ta[t_idx] split_with(';');
					write ta_attr;
					
					taskID <- int(ta_attr[0]);
					location <- {float(ta_attr[1]), float(ta_attr[2])};
					equipment <- ta_attr[3] split_with (',');
					startTime <- float(ta_attr[5]);
					endTime <- float(ta_attr[6]);
					assigned_ag <- int(ta_attr[7]);
					write "task " + taskID + " " + name + " at location " + location + " with equipment " + equipment + " for agent " + assigned_ag; 
					if verbose{
						save ("task " + taskID + " " + name + " at location " + location + " with equipment " + equipment + " for agent " + assigned_ag) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					//Ask assigned simAgent to add this task to its list
					//independent of the approach, the initial assignment will come from the planner
					if approach = "planner" or approach = "hybrid" or approach = "agent"{
						ask simAgents.population[assigned_ag-1] {
							add myself.taskID to: tasks_todo;
							add t_idx to: tasks_todo_idx;
							
							msgs_sent <- msgs_sent + 1;
						}
						// Set task color to agent color
						color <- simAgents.population[assigned_ag-1].color;
					}
					t_idx <- t_idx + 1;
				}
				plan_active <- true;
				simulation_init <- false;
			}
			else{
				//destroy previous task agents
				ask tasks{
					do die;
				}
				
				asking_planner <- false;
				write "New plan. Initializing remaining "+length(ta)+" tasks";
				if verbose{
					save ("New plan. Initializing remaining "+length(ta)+" tasks") to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
				int t_idx <- 0;
				//Create as many tasks as there are in the plan, and initialize the locations and equipments.
				create tasks number: length(ta){
					list ta_attr <- ta[t_idx] split_with(';');
					write ta_attr;
					
					taskID <- int(ta_attr[0]);
					location <- {float(ta_attr[1]), float(ta_attr[2])};
					equipment <- ta_attr[3] split_with (',');
					startTime <- float(ta_attr[5]);
					endTime <- float(ta_attr[6]);
					assigned_ag <- int(ta_attr[7]);
					write "task " + name + " at location " + location + " with equipment " + equipment + " for agent " + assigned_ag; 
					if verbose{
						save ("task " + name + " at location " + location + " with equipment " + equipment + " for agent " + assigned_ag) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					//Ask assigned simAgent to add this task to its list
					if approach = "planner" or approach = "hybrid"{
						ask simAgents.population[assigned_ag-1] {
							add myself.taskID to: tasks_todo;
							add t_idx to: tasks_todo_idx;
							msgs_sent <- msgs_sent + 1;
						}
					}
					else{
						write "It shouldn't be here. There is no replanning in the agent approach" color: #red;
					}
					// Set task color to agent color
					color <- simAgents.population[assigned_ag-1].color;
					t_idx <- t_idx + 1;
					
				}
				save ("tasks " + tasks.population) to: output_file_base+"results.txt" type: "text" rewrite: false;
				
				plan_active <- true;
			}
			ask simAgents{
				write "agent " + name + " should do " + tasks_todo;
				
				if verbose{
					write "agent " + name + " should do " + tasks_todo_idx;
					save ("agent " + name + " should do tasks" + tasks_todo + "\n" + "agent " + name + " should do " + tasks_todo_idx) to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
				
			}
		}

	}
	
	reflex fail_agent when: still_to_fail > 0 and plan_active{//fail an agent only during the execution of a plan
	//and when there still failures to induce left.
		if rnd(1.0) < fail_prob{
			//ask one of the agents to fail
			bool failing <- false;
			
			loop while: !failing{
				ask one_of(simAgents){
					if !failed{
						write "I Robot: " + name + " am out." + " At time: " + cycle color: #red; 
						if verbose{
							save ("I Robot: " + name + " am out." + " At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
						failed <- true;
						tasks_todo <- [];
						tasks_todo_idx <- [];
						
						failing <- true;
						
					}
					else{
						write "I Robot: " + name + " am already dead, try again At time: " + cycle color: #red; 
						if verbose{
							save ("I Robot: " + name + " am already dead At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
					}
				}
			}
			still_to_fail <- still_to_fail - 1;
		}
		
	}
	
	
	//deals with visualization of the agent
	aspect base {
    draw square(size) color: color ;
    }
	
}

//species simAgents  schedules: shuffle(simAgents) skills: [moving, network]{
species simAgents skills: [moving, network]{
	float size <- 1.0;
	rgb color <- rgb(rnd(0,255),rnd(0,255),rnd(0,255));
	point location <- {rnd(0.0,9.9), rnd(0.0,19.9)};
	list equipment <- [];
	
	list<int> tasks_left_unassigned <- [];//tasks which the agent failed to reallocate initially
	list<tasks> wanderTo <- [];//tasks for which the agent doesn't know what has happened
	
	int length_original_taskset <- -1;
	int goingToward <- -1;
	list<int> tasks_todo <- [];
	list<int> tasks_done_by_me <- []; //list of completed task ids
	list<int> tasks_dropped <- [];
	list<int> tasks_completed_global <- [];//list of all completed tasks ids (from all agents) 
	list<int> tasks_todo_idx <- [];
	list pending_tasks <- []; //list of lists of tasks that are not assigned yet, agent id - 1 used as index to list
	list<int> new_tasks <- []; // list of tasks that the agent was assigned through negotiation
	
	list<point> pathFollowed <- []; //keep a list of the locations visited by the agent
	bool send2thrift <- false;
	
	bool failed <- false;
	
	list<int> known_failed_global <- [];//use this in the gossip for failed agents.
	
	list already_talked_this_cycle <- [];
	
	int nextTaskID <- -1;
	bool onLocation <- false;
	bool taskCompleted <- false;
	point taskLocation;
	
	//variables to be recorded at every timestep.
	/////////////////////////////////////////////
	int completed_task_id <- -1;//if a task is completed at that timestep, put the task id, otherwise -1
	int sent_msgs <- 0;//nr of messages sent in a time step
	int sent_msgs_allocation  <- 0; //only messages sent when allocating tasks
	int active <- 0;//this is like a bool, 1/0 for active/inactive at a timestep
	int plan_request <- 0;//this is like a bool, 1/0 for plan_request/no plan request at a timestep
	int mcomplete <- 0;//this is like a bool, 1/0 for mission complete/no mission complete at a timestep
	
	int starttime <- 0;
		
		
	action reset{
		//Reset attributes of global agent
		total_nr_simAgents <- 0;
		simAgents_nr_hardcoded <- 10;
		msgs_sent <- 0;
		completed_tasks <- 0;
		completed_tasks_zeroed <- 0;
		mission_complete <- false;
		mission_count <-0;
		stop <- false;
		ping  <- true; 
		
		fail_prob <- 0.05;
		plan_active <- false;
		asking_planner <- false;
		known_failed <- [];//Look at this!!!
		
		//update these values
		run_number <- run_number + 1;
		if run_number > total_runs{
			
			//reset run number
			run_number <- 1;
			idx_tofail <- idx_tofail + 1;
			if idx_tofail > length(param_tofail) - 1{
				//Reset failures
				idx_tofail <- 0;
				
				idx_approach <- idx_approach + 1;
				if idx_approach > length(param_approach) - 1{
					//Reset approach
					idx_approach <- 0;
					
					idx_instance <- idx_instance + 1;
					if idx_instance > length(param_instance) - 1{
						idx_instance <- 0;
						idx_approach <- 0;
						idx_tofail  <- 0;
						write "We are done";
						stop <- true;
					}
					instance <- param_instance[idx_instance];
				}
				approach <- param_approach[idx_approach];
			}
			
			write "RESETTING " + still_to_fail + " with idx " + idx_tofail;
			
		}
		still_to_fail <- param_tofail[idx_tofail];
		seed <- float(run_number);
		
		output_file_base <- "inst" + instance + "_" + approach + "_fails_" + still_to_fail + "_" + run_number + "_";
		
		simAgent_idx <- 0;

		//Reset attributes of agents
		ask simAgents{
			starttime <- cycle;
			write "Resetting agent " + name;
			size <- 1.0;
			color <- rgb(rnd(0,255),rnd(0,255),rnd(0,255));
			location <- {rnd(0.0,9.9), rnd(0.0,19.9)};
			equipment <- [];
			
			tasks_left_unassigned <- [];//tasks which the agent failed to reallocate initially
			wanderTo <- [];//tasks for which the agent doesn't know what has happened
			
			length_original_taskset <- -1;
			goingToward <- -1;
			tasks_todo <- [];
			tasks_done_by_me <- []; //list of completed task ids
			tasks_dropped <- [];
			tasks_completed_global <- [];//list of all completed tasks ids (from all agents) 
			tasks_todo_idx <- [];
	        pending_tasks <- [];
	        new_tasks <- [];
	        loop i over: range(1,simAgents_nr_hardcoded){
				
				add [] to: pending_tasks;
			}
			
			pathFollowed <- []; //keep a list of the locations visited by the agent
			send2thrift <- false;
			
			failed <- false;
			
			known_failed_global <- [];//use this in the gossip for failed agents.
			
			already_talked_this_cycle <- [];
			
			nextTaskID <- -1;
			onLocation <- false;
			taskCompleted <- false;
			
			//variables to be recorded at every timestep.
			/////////////////////////////////////////////
			completed_task_id <- -1;//if a task is completed at that timestep, put the task id, otherwise -1
			sent_msgs <- 0;//nr of messages sent in a time step
			sent_msgs_allocation  <- 0; //only messages sent when allocating tasks
			active <- 0;//this is like a bool, 1/0 for active/inactive at a timestep
			plan_request <- 0;//this is like a bool, 1/0 for plan_request/no plan request at a timestep
			mcomplete <- 0;//this is like a bool, 1/0 for mission complete/no mission complete at a timestep
		}
		
		//Resetting server
		ask simulation_server{
			alive_agents <- [];
			dead_agents <- [];
		}
				
		//kill tasks
		ask tasks{
			do die;
		}
		
		write "Running experiment with instance " + instance + " with approach " + approach + " with failures " + still_to_fail + " and run number " + run_number;
		simulation_init <- true;
	}
		
   	reflex pinkopalino when: ping{//This will run only once at the beginning of each simulation
		//Ping planner
    	ask one_of(simAgents){
    		write "Agent " + name + " Pinging" color:#green;
			do send contents: "Ping" to:"130.243.73.174";
			ping <- false;
    	}
		
    }
    
    reflex timeout{
    	if cycle > starttime + 1000*(instance+1){
    		write "TIMEOUT reset";
    		save ("TIMEOUT reset") to: output_file_base+"results.txt" type: "text" rewrite: false;
    		do reset;
    	}
    }
    
	list<float> calculate_willingness(int task_idx){
		//calculate w without utility
		float wlocal <- 0.0;
		
		//If the necessary equipment not present, then return w=-1.0
		bool equip_present <- true;
		//write "My equipment: " + equipment + " task equipment: " + tasks.population[task_idx].equipment;
		if verbose{
			save ("task idx " +task_idx + " task population: " +  tasks.population) to: output_file_base+"results.txt" type: "text" rewrite: false;
		
			save ("Agent " + name + " My equipment: " + equipment + " task equipment: " + tasks.population[task_idx].equipment) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		loop eq over: tasks.population[task_idx].equipment {
			if ! (equipment contains eq){
				equip_present <- false;
				return [-1.0, -1];
			}
		}
		
		//calculate utility
		float utility <- 0.0;
		int index_of_min;
		if length(tasks_todo) = 0{
			float dst <- self distance_to tasks.population[task_idx].location;
			if dst = 0.0{
				utility <- 1.0;
			}
			else{
				utility <- 1/(dst);
			}
			index_of_min <- 0;
			if verbose{
				//write "Distances " + self distance_to tasks.population[task_idx].location;
				save ("Distances " + self distance_to tasks.population[task_idx].location) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
		}
		else{
			list distances <- [self.location distance_to tasks.population[task_idx].location];
			loop t over:tasks_todo_idx{
				add tasks.population[t].location distance_to tasks.population[task_idx].location to: distances; 
			}
			index_of_min <- distances index_of min(distances);

			float dst <- (min(distances));
			if dst = 0.0{
				utility <- 1.0;
			}
			else{
				utility <- 1/dst;
			}
			if verbose{
				//write "Tasks: " + tasks_todo;
				//write "Distances " + distances;
				save ("Tasks: " + tasks_todo + "\n" + "Distances " + distances) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
		}
		if verbose{
			//write "Utility " + utility;
			//write "index " + index_of_min;
			save ("Utility " + utility + "\n" + "index " + index_of_min) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		wlocal <- wlocal + utility;
		
		return [wlocal, index_of_min];
	}
	
	action ask_for_replan(list<int> tasks_completed){
		sent_msgs <- sent_msgs + 1;
		sent_msgs_allocation <- sent_msgs_allocation + 1;
		write "Agent: "+name+" sending a request for a replan";
		save ("remaining agents: " + simulation_server[0].alive_agents + ", completed tasks " + tasks_completed_global) to: output_file_base+"results.txt" type: "text" rewrite: false;
		do send contents: "{\"msg_type\":\"replan\"," + "\"tasks\":"+tasks_completed_global+ ",\"agents\":"+simulation_server[0].alive_agents + "}";
	}
	
	reflex doTasks when: length(tasks_todo) > 0{
		save ("Agent: " + name + " step: " + cycle + " todo: " + tasks_todo) to: output_file_base+"results.txt" type: "text" rewrite: false;
		if nextTaskID = -1{
			nextTaskID <- tasks_todo[0];
			taskLocation <- tasks.population[tasks_todo_idx[0]].location;
			save ("Agent: " + name + " started with: " + nextTaskID) to: output_file_base+"results.txt" type: "text" rewrite: false;
			
			
		}
		//check whether this has already been completed
		if (tasks_completed_global contains nextTaskID){
			//write "This task has already been completed: " + nextTaskID + " so dropping now";
			add nextTaskID to: tasks_dropped;
			nextTaskID <- -1;
			onLocation <- false;
			// remove task from list
			remove index: 0 from: tasks_todo; 
			remove index: 0 from: tasks_todo_idx; 
			//write "Remainig: " +tasks_todo + " " + tasks_todo_idx;
			if verbose{
				save ("This task has already been completed: " + nextTaskID + " so dropping now" + "\n" + "Remainig: " +tasks_todo + " " + tasks_todo_idx + " global known: " + tasks_completed_global ) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
		}
		
		if onLocation{//start doing the iterations
			tasks.population[tasks_todo_idx[0]].currentIteration <- tasks.population[tasks_todo_idx[0]].currentIteration +1;
			if name = "simAgent_2"{
				write "Iteration " + tasks.population[tasks_todo_idx[0]].currentIteration;
				write "start: " + tasks.population[tasks_todo_idx[0]].startTime + " end:" + tasks.population[tasks_todo_idx[0]].endTime;
					
			}
			if tasks.population[tasks_todo_idx[0]].startTime + tasks.population[tasks_todo_idx[0]].currentIteration >= tasks.population[tasks_todo_idx[0]].endTime{
				// check if task complete
				tasks.population[tasks_todo_idx[0]].complete <- true;
				add tasks_todo[0] to:tasks_done_by_me;
				completed_task_id <- tasks_todo[0];
				completed_tasks <- completed_tasks + 1;
				completed_tasks_zeroed <- completed_tasks_zeroed + 1;
				nextTaskID <- -1;
				onLocation <- false;
				// remove task from list
				remove index: 0 from: tasks_todo; 
				remove index: 0 from: tasks_todo_idx; 
				if verbose{
					save ("Agent" +name+ " Done: " +nextTaskID ) to: output_file_base+"results.txt" type: "text" rewrite: false;
					
					save ("Remaining: " +tasks_todo + " " + tasks_todo_idx) to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
				//write "Remainig: " +tasks_todo + " " + tasks_todo_idx;
			}
			
		}
		else{//keep moving towards the task location
			add location to: pathFollowed;
			do goto target: taskLocation;
			// if the distance between agent and task smaller than 0.5m consider on location.
			if location distance_to taskLocation < 0.5{
				onLocation <- true;
			}
			
		}
		
	}

	//when a call to the planner is made clear the tasks_todo
	reflex clear_tasks when: asking_planner{
		tasks_todo <- [];
		tasks_todo_idx <- [];
        pending_tasks <- [];
        loop i over: range(1,simAgents_nr_hardcoded){
			add [] to: pending_tasks;
		}
        new_tasks <- [];
		nextTaskID <- -1;
		onLocation <- false;
		
		known_failed_global <- simulation_server[0].dead_agents;
		
	}

	reflex gossip when: !failed and !simulation_init and !asking_planner{
		//Get list of agents close by
		list agents_close_by <- agents_at_distance(communication_range) of_species simAgents;
		list filtered_agents_close_by <- agents_at_distance(communication_range) of_species simAgents;
		filtered_agents_close_by <- (filtered_agents_close_by sort_by (each.name)) ;
		if verbose{
			//write "Agents close by: " + agents_close_by + " to agent " + name ;
			//write "Already talked to: " + already_talked_this_cycle;
			save ("Agents close by: " + agents_close_by + " to agent " + name) to: output_file_base+"results.txt" type: "text" rewrite: false;
			save ("Already talked to: " + already_talked_this_cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		loop a over: agents_close_by {
			
			//write "Locally known as dead: " + known_failed_global + " checking agent with name: " + a.name;
			int id <- a.name as_int 10;
			if (already_talked_this_cycle contains id) or (known_failed_global contains id){
				remove a from: filtered_agents_close_by;
			}
		}
		if verbose{
			//write "Locally known as dead: " + known_failed_global;
			//write "Agents close by: " + filtered_agents_close_by;
			
			save ("Locally known as dead: " + known_failed_global + "\n" + "Agents close by: " + filtered_agents_close_by) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		//if list of agents is not empty, go ahead and ask one of them
		int agent_has_failed <- -1;
		if length(filtered_agents_close_by) > 0{
			sent_msgs <- sent_msgs + 1;
			//Exchange data with a randomly picked agent in the list
			ask one_of(filtered_agents_close_by) as: simAgents{//ask agents with id below or above the agent's own id.
			if verbose{
				save ("Agent: " + myself.name + " talking to: " + name) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			 //write "Agent: " + myself.name + " talking to: " + name;
				add myself.name as_int 10 to: already_talked_this_cycle;
				if failed {//If agent has failed, it is detected here
					agent_has_failed <- name as_int 10;
					add name to: known_failed;
					add name as_int 10 to: myself.known_failed_global;
					write "Detected failure of " + agent_has_failed + " at time" + cycle;
				}
				else {
					//update these agents with the status of the requesting agent
					//Agreggate info wrt to tasks
					list<int> combined <- myself.tasks_completed_global;
					if verbose{
						//write "The global state requesting agent knows: " + combined;
						save ("The global state requesting agent knows: " + combined) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					loop i over: myself.tasks_done_by_me{
						if ! (combined contains i){
							add i to: combined;
						}
					}
					if verbose{
						//write "Adding own tasks: " + myself.tasks_done_by_me + " to " + combined;
						save ("Adding own tasks: " + myself.tasks_done_by_me + " to " + combined) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					loop i over: tasks_done_by_me{
						if ! (combined contains i){
							add i to: combined;
						}
					}
					if verbose{
						//write "Adding other agent own tasks: " + tasks_done_by_me + " to " + combined;
						save ("Adding other agent own tasks: " + tasks_done_by_me + " to " + combined) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					loop i over: tasks_completed_global{
						if ! (combined contains i){
							add i to: combined;
						}
					}
					if verbose{
						//write "Adding other agent known global: " + tasks_completed_global + " to " + combined;
						save ("Adding other agent known global: " + tasks_completed_global + " to " + combined) to: output_file_base+"results.txt" type: "text" rewrite: false;
					} 
					//list<int> combined <- combine(myself.tasks_completed_global, myself.tasks_done_by_me, tasks_completed_global, tasks_done_by_me);
					//Update agent that asks
					myself.tasks_completed_global <- combined;
					//Update agent that receives
					tasks_completed_global <- combined;
					
					//Aggregate info wrt to failed agents
					combined <- myself.known_failed_global;
					if verbose{
						save ("Self knows failed: " + combined) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					//write "Self knows failed: " + combined;
					loop i over: known_failed_global{
						if ! (combined contains i){
							add i to: combined;
						}
					}
					if verbose{
						save ("Updated knows failed: " + combined) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					//write "Updated knows failed: " + combined;
					myself.known_failed_global <- combined;
					known_failed_global <- combined;
					
					int tt <- myself.name as_int 10;
					myself.pending_tasks[tt - 1] <- myself.tasks_left_unassigned + myself.new_tasks;
					
					int tt2 <- name as_int 10;
					pending_tasks[tt2 - 1] <-tasks_left_unassigned + new_tasks;
					
					//combine pending_tasks
					list<list> combined_pending_tasks <- myself.pending_tasks;
					int j <- 0;
					loop lst over: pending_tasks{
						loop i over: lst{
							if ! (combined_pending_tasks[j] contains i){
							add i to: combined_pending_tasks[j];
							}
						}
						j  <- j + 1;
					}
					myself.pending_tasks <- combined_pending_tasks;
					pending_tasks <- combined_pending_tasks;
					
					
					if verbose{
						save ("tasks_left_unassigned, for asking agent: " + myself.pending_tasks + " for responding agent> " + pending_tasks) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
				}
				
			}
			
			if ! (agent_has_failed = -1){
				ask simulation_server{
					add agent_has_failed to: dead_agents;
				}
				if approach = "planner"{
					if !asking_planner{
						asking_planner <- true;
						plan_active <- false;
						completed_tasks_zeroed <- 0;
						ask simulation_server{
							remove agent_has_failed from: alive_agents;
							write "Asking planner, dead agent " + agent_has_failed + " remaining alive " + alive_agents;
							save ("remaining agents: " + alive_agents) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
						do ask_for_replan(tasks_completed_global); 
					}
					else {
						if verbose{
							write "Already being taken care of";
						}
					}
				}
				else if approach = "hybrid" or approach = "agent"{
					
					//get list of tasks assigned to failed agent
					list<int> tasks_assigned <- [];
					list<int> all_task_ids <- [];
					loop t over:tasks.population{
						add t.taskID to: all_task_ids; 
						if agent_has_failed = t.assigned_ag{
							add t.taskID to: tasks_assigned;
						}
					}
					
					list<int> temptasks <- pending_tasks[agent_has_failed-1];
					loop t over: temptasks{
						add t to: tasks_assigned;
					}
					
					if verbose{
						save ("Temp tasks " +  temptasks + " index in pending_tasks + 1 " + agent_has_failed ) to: output_file_base+"results.txt" type: "text" rewrite: false;
					
						save ("Failed agent " + agent_has_failed + " assigned " + tasks_assigned) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					//write "Failed agent " + agent_has_failed + " assigned " + tasks_assigned;
					//get list of uncompleted tasks
					list tasks_uncompleted <- [];
					loop t over:tasks_assigned{
						if !(tasks_completed_global contains t){
							add t to: tasks_uncompleted;
						}
					}
					
					if verbose{
						save ("Failed agent " + agent_has_failed + " uncompleted " + tasks_uncompleted) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					//write "Failed agent " + agent_has_failed + " uncompleted " + tasks_uncompleted;
					//reassign
					float willingness <- -1.0;
					int agent_to_assign <- -1;
					int insert_location <- -2;
					loop t over: tasks_uncompleted{
						list my_out <- calculate_willingness(all_task_ids index_of t);
						willingness <- my_out[0];
						insert_location <- my_out[1];
						agent_to_assign <- name as_int 10;
						if verbose{
							//write "Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location;
							save ("Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
						//get agents in the range
						list agents_to_ask <- simAgents at_distance communication_range;
						//remove dead agents
						list filtered_agents_to_ask <- [];
						loop a over:agents_to_ask{
							if ! a.failed{
								add a to: filtered_agents_to_ask; // this we can keep because in a real scenario sending a message to a dead agent will not yield a response anyway. 
							}
							//TODO maybe add here to known_failed_global the id of the failed agent if not there yet.
						}
						//ask for help agents in the range that are not dead
						sent_msgs <- sent_msgs + length(filtered_agents_to_ask);
						
						sent_msgs_allocation <- sent_msgs_allocation + length(filtered_agents_to_ask);
						ask filtered_agents_to_ask{
							list out <- calculate_willingness(all_task_ids index_of t);
							if verbose{
								save ("Agent " + name + " out: " + out) to: output_file_base+"results.txt" type: "text" rewrite: false;
							}
							//write "Agent " + name + " out: " + out;
							if out[0] >= willingness{
								willingness <- out[0];
								insert_location <- out[1];
								agent_to_assign <- name as_int 10;
								if verbose{
									//write "Agent " + name + " w: " + willingness + " il: " + insert_location;
									save ("Agent " + name + " w: " + willingness + " il: " + insert_location) to: output_file_base+"results.txt" type: "text" rewrite: false;
								}
							}
						}
						//assign 
						if !(willingness < 0.0){
							sent_msgs <- sent_msgs + 1;
							sent_msgs_allocation <- sent_msgs_allocation + 1;
							ask simAgents.population[agent_to_assign-1] {
								if verbose{
									//write "agent " + name + " assigned task" + t;
									//write "tasks todo " + tasks_todo;
									//write "indices " + tasks_todo_idx;
									save ("agent " + name + " assigned task " + t + "\n" + "tasks todo " + tasks_todo +"\n" + "indices " + tasks_todo_idx) to: output_file_base+"results.txt" type: "text" rewrite: false;
								}
								// TODO add only if not already present
								if !(tasks_todo contains t){
									if !(new_tasks contains t){
										add t to: new_tasks;
									}
									add t to: tasks_todo at: insert_location;
									add all_task_ids index_of t to: tasks_todo_idx at: insert_location;
									if verbose{
										//write "agent " + name + " assigned task" + t;
										//write "tasks todo " + tasks_todo;
										//write "indices " + tasks_todo_idx;
										save ("agent " + name + " assigned task" + t + "\n" + "tasks todo " + tasks_todo +"\n" + "indices " + tasks_todo_idx + "\n" + "new_tasks " + new_tasks) to: output_file_base+"results.txt" type: "text" rewrite: false;
									}
								}
								else{
									if verbose{
										save ("Already assigned") to: output_file_base+"results.txt" type: "text" rewrite: false;
									}
								}
								
							}
						
							//completed_tasks_zeroed <- 0;
							//TODO what does the code below do?
							ask simulation_server{
								remove agent_has_failed from: alive_agents;
							}
						}
						else{
							if approach = "hybrid"{
								write "Self-allocation failed. Ask planner for plan";
								if !asking_planner{
								asking_planner <- true;
								plan_active <- false;
								completed_tasks_zeroed <- 0;
								ask simulation_server{
									remove agent_has_failed from: alive_agents;
								}
								
								do ask_for_replan(tasks_completed_global); 
								}
								else {
									if verbose{
										write "Already being taken care of";
									}
								}
								write "Breaking";
								break;
							}
							else if approach = "agent"{
								//add the task to the list: tasks_left_unassigned idx
								add t to: tasks_left_unassigned;
								write "The list of uncompleted task: " + tasks_left_unassigned;
								if verbose{
									save ("The list of uncompleted task: " + tasks_left_unassigned) to: output_file_base+"results.txt" type: "text" rewrite: false;
									
								}
								
							}
							
						}
						// Set task color to agent color
						color <- simAgents.population[agent_to_assign-1].color;
						
					}
				}
			}
		
		}
		already_talked_this_cycle <- [];	
	}
	
	//Only in the agent approach, once an agent is done with its tasks, it'll start moving toward the uncompleted tasks
	reflex tendUnallocatedTasks when: approach = 'agent' and length(tasks_todo) <= 0 and length(tasks_left_unassigned) > 0 and !simulation_init and !failed{
		//get the list of neighbours
		list allocated <- [];
		bool done_or_allocated;
		list agents_close_by <- agents_at_distance(communication_range) of_species simAgents;
		list filtered_agents_close_by <- agents_at_distance(communication_range) of_species simAgents;
		if verbose{
			//write "Agents close by: " + agents_close_by + " to agent " + name ;
			//write "Already talked to: " + already_talked_this_cycle;
			save ("tendUnallocatedTask: Agents close by: " + agents_close_by + " to agent " + name + "\n" + "Already talked to: " + already_talked_this_cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		loop a over: agents_close_by {
			int id <- a.name as_int 10;
			if (known_failed_global contains id){
				remove a from: filtered_agents_close_by;
			}
		}
		//if list not empty try to allocate tasks
		list<int> all_task_ids <- [];
		loop t over:tasks.population{
			add t.taskID to: all_task_ids; 
		}
		save ("tendUnallocatedTask: Agents " + name + " still trying to assign  " +  tasks_left_unassigned) to: output_file_base+"results.txt" type: "text" rewrite: false;
		
		loop t over: tasks_left_unassigned{
			
			float willingness <- -1.0;
			int agent_to_assign <- -1;
			int insert_location <- -2;
			//we don't consider the asking agent here, because if it could, it would have already assigned this task to the self
			agent_to_assign <- name as_int 10;
			done_or_allocated <- false;
			if verbose{
				//write "Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location;
				save ("tendUnallocatedTask: Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			//ask for help agents in the range that are not dead
			sent_msgs <- sent_msgs + length(filtered_agents_close_by);
			sent_msgs_allocation <- sent_msgs_allocation + length(filtered_agents_close_by);
			ask filtered_agents_close_by{
				if(tasks_completed_global contains t or tasks_done_by_me contains t or tasks_todo contains t){
					done_or_allocated <- true;
				}
				else{
					list out <- calculate_willingness(all_task_ids index_of t);
					write "Agent " + name + " out: " + out;
					if out[0] >= willingness{
						willingness <- out[0];
						insert_location <- out[1];
						agent_to_assign <- name as_int 10;
						if verbose{
							write "Agent " + name + " w: " + willingness + " il: " + insert_location;
							save ("tendUnallocatedTask: Agent " + name + " w: " + willingness + " il: " + insert_location) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
					}
				}
				
			}
			
			if done_or_allocated{
				add t to: allocated;
			}
			else{
				//assign 
				if !(willingness < 0.0){
					sent_msgs <- sent_msgs + 1;
					sent_msgs_allocation <- sent_msgs_allocation + 1;
					ask simAgents.population[agent_to_assign-1] {
						if verbose{
							//write "agent " + name + " assigned " + t;
							//write "tasks todo " + tasks_todo;
							//write "indices " + tasks_todo_idx;
							
							save ("tendUnallocatedTask: agent " + name + " assigned " + t + "\n" + "tasks todo " + tasks_todo + "\n" + "indices " + tasks_todo_idx) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
						if !(new_tasks contains t){
							add t to: new_tasks;
						}
						add t to: tasks_todo at: insert_location;
						add all_task_ids index_of t to: tasks_todo_idx at: insert_location;
						if verbose{
							//write "agent " + name + " assigned " + t;
							//write "tasks todo " + tasks_todo;
							//write "indices " + tasks_todo_idx;
							save ("tendUnallocatedTask: agent " + name + " assigned " + t + "\n" + "tasks todo " + tasks_todo +"\n" + "indices " + tasks_todo_idx+"\n" + "new_tasks " + new_tasks) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
					}
					
					//since task has been assigned, mark down, to be removed later
					add t to: allocated;
				}
				
				// Set task color to agent color
				// color <- simAgents.population[agent_to_assign-1].color;
			}
			
		}

		loop t over: allocated{
			remove t from: tasks_left_unassigned;
		}		
	}
	
	//If too much time has passed start trying to reallocate those tasks that are pending
	reflex watchdog when: cycle-starttime>800*(instance+1) and !asking_planner and !simulation_init and !failed and length(tasks_todo) <= 0{
		if length(tasks_completed_global) < length_original_taskset{
			int nr_tasks_unknown <- length_original_taskset - length(tasks_completed_global);
			//write "There are " + nr_tasks_unknown + " tasks, the status of which is unknown" ;
			if verbose{
				save ("WATCHDOG: There are " + nr_tasks_unknown + " tasks, the status of which is unknown") to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			list tasks_pending <- [];
			//get location of the first such task in the list
			loop task over: tasks.population{
				if !(tasks_completed_global contains task.taskID) and ! (dead(task)){
					//move toward this task
					add task.taskID to: tasks_pending;
					
				}
			}
			//get the list of neighbours
			list allocated <- [];
			bool done_or_allocated;
			list agents_close_by <- agents_at_distance(communication_range) of_species simAgents;
			list filtered_agents_close_by <- agents_at_distance(communication_range) of_species simAgents;
			if verbose{
				//write "Agents close by: " + agents_close_by + " to agent " + name ;
				//write "Already talked to: " + already_talked_this_cycle;
				save ("WATCHDOG: Agents close by: " + agents_close_by + " to agent " + name + "\n" + "Already talked to: " + already_talked_this_cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			loop a over: agents_close_by {
				int id <- a.name as_int 10;
				if (known_failed_global contains id){
					remove a from: filtered_agents_close_by;
				}
			}
			//if list not empty try to allocate tasks
			list<int> all_task_ids <- [];
			loop t over:tasks.population{
				add t.taskID to: all_task_ids; 
			}
			save ("WATCHDOG: Agents " + name + " still trying to assign  " +  tasks_pending) to: output_file_base+"results.txt" type: "text" rewrite: false;
			if length(tasks_pending) > 0{
				loop t over: tasks_pending{
				
					float willingness <- -1.0;
					int agent_to_assign <- -1;
					int insert_location <- -2;
					//we don't consider the asking agent here, because if it could, it would have already assigned this task to the self
					agent_to_assign <- name as_int 10;
					done_or_allocated <- false;
					if verbose{
						//write "Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location;
						save ("WATCHDOG: Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					//ask for help agents in the range that are not dead
					sent_msgs <- sent_msgs + length(filtered_agents_close_by);
					sent_msgs_allocation <- sent_msgs_allocation + length(filtered_agents_close_by);
					ask filtered_agents_close_by{
						if(tasks_completed_global contains t or tasks_done_by_me contains t or tasks_todo contains t){
							done_or_allocated <- true;
						}
						else{
							list out <- calculate_willingness(all_task_ids index_of t);
							write "Agent " + name + " out: " + out;
							if out[0] >= willingness{
								willingness <- out[0];
								insert_location <- out[1];
								agent_to_assign <- name as_int 10;
								if verbose{
									write "Agent " + name + " w: " + willingness + " il: " + insert_location;
									save ("WATCHDOG: Agent " + name + " w: " + willingness + " il: " + insert_location) to: output_file_base+"results.txt" type: "text" rewrite: false;
								}
							}
						}
						
					}
					
					if !done_or_allocated{
						//assign 
						if !(willingness < 0.0){
							sent_msgs <- sent_msgs + 1;
							sent_msgs_allocation <- sent_msgs_allocation + 1;
							ask simAgents.population[agent_to_assign-1] {
								if verbose{
									//write "agent " + name + " assigned " + t;
									//write "tasks todo " + tasks_todo;
									//write "indices " + tasks_todo_idx;
									
									save ("WATCHDOG: agent " + name + " assigned " + t + "\n" + "tasks todo " + tasks_todo + "\n" + "indices " + tasks_todo_idx) to: output_file_base+"results.txt" type: "text" rewrite: false;
								}
								if !(new_tasks contains t){
									add t to: new_tasks;
								}
								add t to: tasks_todo at: insert_location;
								add all_task_ids index_of t to: tasks_todo_idx at: insert_location;
								if verbose{
									//write "agent " + name + " assigned " + t;
									//write "tasks todo " + tasks_todo;
									//write "indices " + tasks_todo_idx;
									save ("WATCHDOG: agent " + name + " assigned " + t + "\n" + "tasks todo " + tasks_todo +"\n" + "indices " + tasks_todo_idx+"\n" + "new_tasks " + new_tasks) to: output_file_base+"results.txt" type: "text" rewrite: false;
								}
							}
						}
						// Set task color to agent color
						// color <- simAgents.population[agent_to_assign-1].color;
					}
					
				}
			
			}
			
		}
	}
	
	//If the known global state of tasks is not fully known, walk toward tasks for which the robot has no info
	//this is basically trying to help the gossip propagate.
	reflex wanderTillComplete when: !asking_planner and !simulation_init and !failed and length(tasks_todo) <= 0{
		if length(tasks_completed_global) < length_original_taskset{
			int nr_tasks_unknown <- length_original_taskset - length(tasks_completed_global);
			//write "There are " + nr_tasks_unknown + " tasks, the status of which is unknown" ;
			if verbose{
				save ("There are " + nr_tasks_unknown + " tasks, the status of which is unknown") to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			//get location of the first such task in the list
			loop task over: tasks.population{
				if !(tasks_completed_global contains task.taskID) and ! (wanderTo contains task) and ! (dead(task)){
					//move toward this task
					add task to: wanderTo;
					
				}
				else if (tasks_completed_global contains task.taskID) and (wanderTo contains task){
					remove task from: wanderTo;
				}
				else if (dead(task)){
					save ("task already dead " + task.taskID) to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
			}
			//write "list of tasks to wander around " + wanderTo;
			//write "tasks known to be completed" + tasks_completed_global;
			if verbose{
				save ("list of tasks to wander around " + wanderTo) to: output_file_base+"results.txt" type: "text" rewrite: false;
				save ("tasks known to be completed" + tasks_completed_global) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			if length(wanderTo) > 0{
				//Check if already at location of the 1st task in the list
				if self distance_to wanderTo[0] < 0.001{
					wanderTo <- shuffle(wanderTo);
					//write "list of tasks to wander around after shuffle " + wanderTo;
				}
				
				//write "Going toward task " +  wanderTo[0].taskID + ", at location: " + wanderTo[0].location;
				do goto target: wanderTo[0].location;
				
				if verbose{
					save ("Going toward task " +  wanderTo[0].taskID + ", at location: " + wanderTo[0].location) to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
			}
			else{
				do wander;
				if verbose{
					save ("Just wander") to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
			}
			
		}
	}
	
	//On mission complete ask one of the agents to confirmation to the planner
	//Finally kill all agents
	action checkMissionComplete{
		if !mission_complete and simulation_init = false{//note that completed_tasks is not zeroed on new plan
		//if completed_tasks is bigger than the original taskset size, then some tasks have been done twice
			write "Mission is complete";
			write "Sending mission complete";
			mission_complete <- true;
			if verbose{
				save ("Mission is complete" + "\n" + "Sending mission complete") to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			do send contents: "Mission Complete";
			
			//Reset everything
			do reset;
	
		}
		else{
			//write "Agent " + name + " has still to do " + tasks_todo ;
		}
	}
	
	reflex save_data when: !simulation_init{
		//if length(tasks_completed_global) >= length(tasks.population) and !simulation_init {
		if length(tasks_completed_global) >= length_original_taskset and !simulation_init {
			mcomplete <- 1;
		} 
		save [cycle, location.x, location.y, taskLocation.x, taskLocation.y, completed_task_id, sent_msgs, int(failed), mission_count, mcomplete, int(asking_planner), time, total_duration, sent_msgs_allocation] to: output_file_base+name+"_agent.csv" type: "csv" rewrite:false;
		
		/*if name = "1"{
			write location;
			write taskLocation;
			write completed_task_id;
			write sent_msgs;
			write failed;
			write mission_count;
			write mcomplete;
			write asking_planner;
		}*/
		completed_task_id <- -1;
		
		if mcomplete = 1{
			do checkMissionComplete;
		}
	}
	
	aspect base {
		// Draw agent
		if !failed{
	    	draw circle(size) color: color ;
		}
		else{
	    	draw ellipse(4*size, 2*size) color: color;
		}
		
    	draw name font: font('Default', 12, #bold) color:color;
		// Draw trail
	    loop loc over: pathFollowed{
	    	draw circle(size-0.9) color: color at: loc;
	    }
    }
}

species tasks{
	float size <- 2.0;
	rgb color <- rgb(rnd(0,255),rnd(0,255),rnd(0,255));
	float startTime <- 0.0;
	float endTime <- 0.0;
	int iterations <- 0;
	int currentIteration <- 0;
	int taskID <- -1;
	bool complete <- false;
	list equipment <- [];
	int assigned_ag;
    
	aspect base {
    draw triangle(size) color: color ;
    draw string(taskID) font: font('Default', 12, #bold) color:color;
    }
    
    reflex checkComplete{
    	if complete{
    		size <- 5.0;
    	}
    }
}

experiment "GLOCAL Test" type: gui {
	float minimum_cycle_duration <- 0.0;
	float step <- 1#s;

	output
	{
		display main_display {
	        species simAgents aspect: base ;
	        species simulation_server aspect: base ;
	        species tasks aspect: base ;
    	}
    	monitor "approach" value: approach refresh: every(1); 
    	monitor "fails" value: still_to_fail refresh: every(1);
    	monitor "instance" value: instance refresh: every(1);
    	monitor "run number" value: seed refresh: every(1);
    	monitor "completed tasks" value: completed_tasks refresh: every(1);
	}
	
	reflex compacting when: every(100000#cycle){
		do compact_memory();
	}
	
	reflex slow_down_2RT when:asking_planner or simulation_init{
		 minimum_cycle_duration <- 1.0;
	}
	reflex speed_up_2RT when:!asking_planner and !simulation_init{
		 minimum_cycle_duration <- 0.0;
	}
	reflex save_RT_data {
		save [cycle, time, duration, total_duration] to: output_file_base+name+"_agent_RT.csv" type: "csv" rewrite:false;

	}

}