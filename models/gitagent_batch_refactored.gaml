/**
* Name: gitagentbatchrefactored
* Based on the internal empty template. 
* Author: Super PC
* Tags: 
*/


model gitagentbatchrefactored
/**
* Name: gitagent_batch
* Based on the internal empty template. 
* Author: Super PC
* Tags: 
*/

global{
	
	///////////////////////////////////////////////////////////////////
	//Defining parameters for batch experiments////////////////////////
	list<int> taskset_lengths <- [50,100,150,300,500];
	//list<int> param_instance <- [0];
	list<int> param_instance <- [0,1,2];
	//list<int> param_instance <- [0];
	list<string> param_approach <- ['agent', 'hybrid', 'planner'];
	//list<string> param_approach <- ['agent'];
	//list<int> param_tofail <- [1,2,3];
	list<int> param_tofail <- [0,1,2,3,4,5,6,7];
	list unique_agent_equipment <- [];
	list unique_task_equipment <- [];
	list<tasks> total_completed_tasks_global <- []; // this list is not used by agents, it's only for the checking feasibility of the plan
	//list<int> param_tofail <- [0];
	int total_runs <- 30;
	list<list<list<int>>> failing_agents <- [[], [], [], [], [], [], [], []];

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
	geometry shape <- rectangle(300#m,300#m);
	//float communication_range <- 5#m;
    //float communication_range <- 10000000#m;
	float communication_range <- 100#m;
	int mission_count <-0;
	bool stop <- false;
	bool ping  <- true; 
	bool infeasible <- false;
	int timeout_trigger_VALUE <- 1;
	int timeout_trigger <- timeout_trigger_VALUE;
	
	//Related to inducing failures
	float fail_prob <- 0.05;
	bool plan_active <- false;
	bool asking_planner <- false;
	string approach <- param_approach[idx_approach];
	int still_to_fail <- param_tofail[idx_tofail];
	int instance <- param_instance[idx_instance];
	int run_number <- 1;
	list<int> agents2fail <- [];
	float seed <- run_number + 3165658666.0;
	float keep_seed <- seed;
	int new_plan <- 1;
	int temp_cycle <- 0;
	int watchdog_trigger <- 20*(instance+1);
	int progress <- 0; 
	int progress_diff  <- 0;
	//float seed <- run_number; #comment line 137 to reproduce run 18 error with 3 failures and communication range of 5. start from run 17
	
	string output_file_base <- "inst" + instance + "_" + approach + "_fails_" + still_to_fail + "_" + run_number + "_";
	
	list known_failed <- [];//Look at this!!!
	
	bool verbose <- true;
	
	int DELTA <- 10; 
	
	int simAgent_idx <- 0;
	//Initialization of the sockets should be done already here
	init {
		
		write "Initializing";
		//This server receives the requests from the planner executing externally somewhere

		write "Initializing server";
		create simulation_server number:1
		{
			do connect to: "127.0.0.1" protocol: "tcp_server" port: 10002 with_name: name;
			do join_group with_name:"server_group";
		}
		
		//Agents that will actually perform the tasks. They can also send messages directly to the planner.
		create simAgents number: simAgents_nr_hardcoded
	    {
	    	
	    	do connect to: "localhost" protocol: "tcp_client" port: 10000 with_name: name;
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
		save ("Running experiment with instance " + instance + " with approach " + approach + " with failures " + still_to_fail + " and run number " + run_number + " seed " + seed) to: output_file_base+"results.txt" type: "text" rewrite: false;
		
		write "Running experiment with instance " + instance + " with approach " + approach + " with failures " + still_to_fail + " and run number " + run_number + " seed " + seed;

		loop el over: range(0,length(failing_agents)-1){
			loop t over: range(0,total_runs-1){
				add [] to: failing_agents[el,t];
			}
		}
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
	int time_to_fail <- -1;
	
	list<int> alive_agents;
	list<int> all_agents;
	list<int> dead_agents;//updated based on the local view on an agent discovering another dead agent

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
			list items <- string(mm.contents) split_with (';');

			//Read agent and task properties from file
			csv_file agf  <- csv_file("Agents_"+string(taskset_lengths[instance])+".csv", ";", true);
			matrix agent_data <- matrix(agf);
				
			csv_file tf  <- csv_file("Tasks_"+string(taskset_lengths[instance])+".csv", ";", true);
			matrix task_data <- matrix(tf);
			
			//On simulation init, initialize both simAgents and tasks with the locations and equipments as defined in the plan
			if simulation_init{
				
				temp_cycle <- 0;
				seed <- run_number + 3165658666.0;
				infeasible <- false;
				
				unique_agent_equipment <- [];
				unique_task_equipment <- [];
				
				startTime <- cycle;
				//total_nr_simAgents <- length(ag);
				total_nr_simAgents  <- length(agent_data)/5 as int;//because there are 5 columns in the file
				if total_nr_simAgents != simAgents_nr_hardcoded{
					write "[ERROR]: number of agents doesn't match" color: #red;
				}
				write "Initializing "+total_nr_simAgents+" agents";
				//Ask each agent to update its attributes -- this is similar to a for loop
			    ask simAgents {
			    	//length_original_taskset <- length(ta);
			    	length_original_taskset <- length(task_data)/5 as int;//because there are 4 columns in the file
			    	write length_original_taskset;
					//for the case of no failures, the guard is placed in the fail reflex below.
			    	progress_diff <- int(floor(length_original_taskset/(still_to_fail + 2)));

			    	starttime <- cycle;
			    	//list ag_attr <- ag[simAgent_idx] split_with(';');
			    	//add ag_attr[0] as_int 10 to: myself.alive_agents;
			    	add int( agent_data[0, simAgent_idx]) to: myself.alive_agents;
			    	add int( agent_data[0, simAgent_idx]) to: myself.all_agents;
			    	//write ag_attr;
			    	//name <- ag_attr[0];
			    	name <- string(int( agent_data[0, simAgent_idx]));
					
					location <- {float(agent_data[1, simAgent_idx]), float(agent_data[2, simAgent_idx])};
					//equipment <- ag_attr[3] split_with (',');
					speed <- float(agent_data[3, simAgent_idx])/2;
					equipment <- string(agent_data[4, simAgent_idx]) split_with (',');
					
					loop eq over: equipment{
						if!(eq in unique_agent_equipment){
							add eq to: unique_agent_equipment;
						}
						
					}
					save ("unique agent equipment" + unique_agent_equipment) to: output_file_base+"results.txt" type: "text" rewrite: false;
					
					//TODO check what to do with speed
					//speed <- float(ag_attr[3]);
					write "agent " + name + " at location " + location + " with equipment " + equipment + " at speed " + speed; 
					if verbose{
						save ("agent " + name + " at location " + location + " with equipment " + equipment + " at speed " + speed) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					
			    	simAgent_idx <- simAgent_idx + 1;
			    }
				write "Alive agents: " + alive_agents;
				write "Initializing "+ length(task_data)/5 +" tasks";
				if verbose{
					save ( "Alive agents: " + alive_agents + "\n" + "Initializing "+ length(task_data)/5 +" tasks") to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
				int t_idx <- 0;
				//Create as many tasks as there are in the plan, and initialize the locations and equipments.
				
				list<string> allocations <- items[2] split_with("|") ;
				
				loop el_in_item over: allocations {
					list sp <- el_in_item split_with(":");
					int assigned_agent <- sp[0] as_int 10;
					if length(sp) > 1 and length( sp[1]) > 0{
						list tasks4thisagent <- sp[1] split_with(",");
						write  length(tasks4thisagent);
						int tippity <- 0;
					
						create tasks number: length(tasks4thisagent){
							int tip <- (tasks4thisagent[tippity] as int);
							//taskID <- int(ta_attr[0]);
							taskID <- int( task_data[0, tip]);
							//location <- {float(ta_attr[1]), float(ta_attr[2])};
							location <- {float(task_data[1, tip]), float(task_data[2, tip])};
							//equipment <- ta_attr[3] split_with (',');
							duration <- float(task_data[3, tip]);
							equipment <- string(task_data[4, tip]);
							loop eq over: equipment{
								if!(eq in unique_task_equipment){
									add eq to: unique_task_equipment;
								}
						
							}
							save ("unique task equipment" + unique_task_equipment) to: output_file_base+"results.txt" type: "text" rewrite: false;
					
							startTime <- 0;
							endTime <- 1;
							assigned_ag <- int(assigned_agent);
							write "task " + taskID + " " + name + " at location " + location + " with equipment " + equipment + " for agent " + assigned_ag; 
							if verbose{
								save ("task " + taskID + " " + name + " at location " + location + " with equipment " + equipment + " for agent " + assigned_ag) to: output_file_base+"results.txt" type: "text" rewrite: false;
							}
							//Ask assigned simAgent to add this task to its list
							//independent of the approach, the initial assignment will come from the planner
							if approach = "planner" or approach = "hybrid" or approach = "agent"{
								ask simAgents.population[assigned_ag] {
									add myself.taskID to: tasks_todo;
									add t_idx to: tasks_todo_idx;
									
									msgs_sent <- msgs_sent + 1;
								}
								// Set task color to agent color
								color <- simAgents.population[assigned_ag].color;
							}
							
							tippity <- tippity + 1;
							t_idx <- t_idx + 1;
						}
				
					}
				}
				
				//Calculate the max expected duration
				int max_duration <- 0;
				
				ask simAgents{
					int dur <- 0;
					
					if length(tasks_todo) > 0{
						dur <- calc_duration();
					}
					
					if dur > max_duration{
						max_duration <- dur;
					}
				}
				
				//Adjust the tirgger to the watchdog based on the max duration.
				watchdog_trigger <- max_duration;
				
				save ("INIT watchdog trigger: " + watchdog_trigger ) to: output_file_base+"results.txt" type: "text" rewrite: false;
				
				plan_active <- true;
				simulation_init <- false;
			}
			else{
				new_plan <- new_plan + 1;
				temp_cycle <- 0;
				//destroy previous task agents
				ask tasks{
					//do die;
				}
				
				asking_planner <- false;
				write "New plan. Initializing remaining "+ (length(task_data)/5 as int) +" tasks";
				if verbose{
					save ("New plan. Initializing remaining "+ (length(task_data)/5 as int) +" tasks") to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
				int t_idx <- 0;
				//Create as many tasks as there are in the plan, and initialize the locations and equipments.
/*
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
				
 */				
				list<string> allocations <- items[2] split_with("|") ;
				loop el_in_item over: allocations {
					list sp <- el_in_item split_with(":");
					int assigned_agent <- sp[0] as_int 10;
					write "Agent:" + assigned_agent;
					if length(sp) > 1 and length(sp[1]) > 0{
						list tasks4thisagent <- sp[1] split_with(",");
						int tippity <- 0;
						write "Tasks for agent: " + tasks4thisagent;
						
						loop task over: tasks4thisagent{
							write int(task);
							write tasks.population;
							list taskids <- tasks.population collect each.taskID;
							int thetaskindex <- taskids index_of int(task);
							write thetaskindex;
							ask tasks.population[thetaskindex] {
								int tip <- (tasks4thisagent[tippity] as int) ;
	
								write tip;
								write tippity;
								assigned_ag <- int(assigned_agent);
								write "task " + taskID + " " + name + " at location " + location + " with equipment " + equipment + " for agent " + assigned_ag; 
								if verbose{
									save ("task " + taskID + " " + name + " at location " + location + " with equipment " + equipment + " for agent " + assigned_ag) to: output_file_base+"results.txt" type: "text" rewrite: false;
								}
								//Ask assigned simAgent to add this task to its list
								//independent of the approach, the initial assignment will come from the planner
								if approach = "planner" or approach = "hybrid" or approach = "agent"{
									ask simAgents.population[assigned_ag] {
										add myself.taskID to: tasks_todo;
										add thetaskindex to: tasks_todo_idx;
										msgs_sent <- msgs_sent + 1;
									}
									// Set task color to agent color
									color <- simAgents.population[assigned_ag].color;
								}
								
								tippity <- tippity + 1;
								t_idx <- t_idx + 1;
							}
						}						
					}
					
				}
				save ("tasks " + tasks.population) to: output_file_base+"results.txt" type: "text" rewrite: false;
				
				//Re-Calculate the max expected duration
				int max_duration <- 0;
				
				ask simAgents{
					int dur <- 0;
					
					if length(tasks_todo) > 0{
						dur <- calc_duration();
					}
					
					if dur > max_duration{
						max_duration <- dur;
					}
				}
				
				//Adjust the tirgger to the watchdog based on the max duration.
				watchdog_trigger <-max_duration;
				
				save ("REPLAN watchdog trigger: " + watchdog_trigger ) to: output_file_base+"results.txt" type: "text" rewrite: false;
				
				plan_active <- true;
			}

		}

	}
	
	reflex fail_agent when: still_to_fail > 0 and plan_active and false {//fail an agent only during the execution of a plan and if there are still fails to be injected
		if completed_tasks >= progress + progress_diff{
			progress <- progress + progress_diff;
			if verbose{
				save ("Time to fail where completed tasks:"+completed_tasks+" progress: " + progress + " and progress diff: " + progress_diff + " At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			bool failing <- false;
			list<int> agts <-  [];
			
			
			loop while: !failing and (length(agts) < simAgents_nr_hardcoded - still_to_fail){

				ask one_of(simAgents){
					if !failed and length(tasks_todo) > 0{
						write "I Robot: " + name + " am out." + " At time: " + cycle color: #red; 
						remove int(name) from: myself.alive_agents;
						if verbose{
							save ("I Robot: " + name + " am out." + " At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
						failed <- true;
						tasks_todo <- [];
						tasks_todo_idx <- [];
						
						failing <- true;
						
					}
					else{
						if ! (agts contains name){
							add int(name) to: agts;
						}
						write "I Robot: " + name + " am already dead, or my taskset is empty> "+ tasks_todo+", try again At time: " + cycle color: #red; 
						if verbose{
							save ("I Robot: " + name + " am already dead At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
					}
				}
			}
			if failing{
				
				still_to_fail <- still_to_fail - 1;

				write "still to fail: " + still_to_fail + "  at time " + time_to_fail;
				
				
				save ("Check feasibility " ) to: output_file_base+"results.txt" type: "text" rewrite: false;
					
				do check_feasibility;
				
			}
		}
		
	}
	
	reflex fail_agent_fixed when: still_to_fail > 0 and plan_active{
		if completed_tasks >= progress + progress_diff{
			progress <- progress + progress_diff;
			if verbose{
				save ("Time to fail where completed tasks:"+completed_tasks+" progress: " + progress + " and progress diff: " + progress_diff + " At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}			
			
			bool failing <- false;
			list<int> agts <-  [];
			
							
			//param_tofail[idx_tofail];
			
			write failing_agents[param_tofail[idx_tofail]][run_number-1];
			write length(failing_agents[param_tofail[idx_tofail]][run_number-1]);
			if length(failing_agents[param_tofail[idx_tofail]][run_number-1]) < param_tofail[idx_tofail]{

				loop while: !failing and (length(agts) < simAgents_nr_hardcoded - still_to_fail){
	
					ask one_of(simAgents){
						if !failed and length(tasks_todo) > 0{
							write "I Robot: " + name + " am out." + " At time: " + cycle color: #red; 
							remove int(name) from: myself.alive_agents;
							if verbose{
								save ("I Robot: " + name + " am out." + " At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
							}
							failed <- true;
							tasks_todo <- [];
							tasks_todo_idx <- [];
							
							failing <- true;
							
							add int(name) to: failing_agents[param_tofail[idx_tofail]][run_number-1];
							
						}
						else{
							if ! (agts contains name){
								add int(name) to: agts;
							}
							write "I Robot: " + name + " am already dead, or my taskset is empty> "+ tasks_todo+", try again At time: " + cycle color: #red; 
							if verbose{
								save ("I Robot: " + name + " am already dead At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
							}
						}
					}
				}
			}
			else{
				save ("\nfailing agents: " + failing_agents + " failing this simulation" + failing_agents[param_tofail[idx_tofail]][run_number-1]) to: output_file_base+"results.txt" type: "text" rewrite: false;
				list tofail <- failing_agents[param_tofail[idx_tofail]][run_number-1];
				int tofail_idx <- tofail[length(tofail) - still_to_fail];
				save ("\ntofail:  idx" + tofail_idx) to: output_file_base+"results.txt" type: "text" rewrite: false;
				
				ask simAgents[tofail_idx] {
					if !failed{
						write "I Robot: " + name + " am out." + " At time: " + cycle color: #red; 
						remove int(name) from: myself.alive_agents;
						if verbose{
							save ("I Robot: " + name + " am out." + " At time: " + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
						}
						failed <- true;
						tasks_todo <- [];
						tasks_todo_idx <- [];
						
						failing <- true;
						if !(length(tasks_todo) > 0){
							save ("WARNING: this agent was doing nothing when it failed") to: output_file_base+"results.txt" type: "text" rewrite: false;
							
						}
						
					}
					else{
						save ("WARNING: why did this robot fail " + failed + " " + length(tasks_todo)) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					
				}
			}
			
			if failing{
				
				still_to_fail <- still_to_fail - 1;

				write "still to fail: " + still_to_fail + "  at time " + time_to_fail;
				
				
				save ("Check feasibility " ) to: output_file_base+"results.txt" type: "text" rewrite: false;
					
				do check_feasibility;
				
			}

			
			
		}
	}
	
	action check_feasibility{
		list pop <- [];
		loop temp over:simAgents.population{
			add temp.name to: pop;
		}
		list remaining_agent_equipment <- [];
		loop ag over: simulation_server[0].alive_agents{
			int idx <- pop index_of string(ag);
			loop eq over: simAgents.population[idx].equipment{
				if !(eq in remaining_agent_equipment){
					add eq to: remaining_agent_equipment;
				}
			}
		}
		unique_agent_equipment  <- [];//needed for the remaining tasks.
		
		loop comp over:total_completed_tasks_global{
			save ("total_completed_tasks_global: " + comp.taskID) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		
		//dont consider the equipment of tasks that have already been completed, total_completed_tasks_global
		loop tsk over:tasks.population{
			if !(total_completed_tasks_global contains tsk){
				loop eq over: tsk.equipment{
					save ("remaining needed eq: " + eq + " for task " + tsk.taskID) to: output_file_base+"results.txt" type: "text" rewrite: false;
					if!(eq in unique_agent_equipment){
						add eq to: unique_agent_equipment;
					}	
				}
			}
		}
		
		save ("remaining agent equipment: " + remaining_agent_equipment) to: output_file_base+"results.txt" type: "text" rewrite: false;
		save ("unique agent equipment: " + unique_agent_equipment) to: output_file_base+"results.txt" type: "text" rewrite: false;
		save ("Plan infeasible: " + unique_agent_equipment) to: output_file_base+"results.txt" type: "text" rewrite: false;
		infeasible <- !(remaining_agent_equipment contains_all unique_agent_equipment);
	}
	
	reflex update_temp_cycle{
		
    	temp_cycle <- temp_cycle + 1;
    	if verbose{
				save ("temp cyclet" + temp_cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
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
	point depot <- {6,11};
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
		//temp_cycle <- 0;
		ping  <- true; 
		
		fail_prob <- 0.05;
		plan_active <- false;
		asking_planner <- false;
		known_failed <- [];//Look at this!!!
		
		total_completed_tasks_global <- [];
		timeout_trigger <- timeout_trigger_VALUE;
		
		new_plan <- 1;
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
		seed <- run_number + 3165658666.0;
		
		progress <- 0; 
		
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
			all_agents <- [];
		}
				
		//kill tasks
		ask tasks{
			do die;
		}
		write "Running experiment with instance " + instance + " with approach " + approach + " with failures " + still_to_fail + " and run number " + run_number + " seed " + seed;
		save ("Running experiment with instance " + instance + " with approach " + approach + " with failures " + still_to_fail + " and run number " + run_number + " seed " + seed) to: output_file_base+"results.txt" type: "text" rewrite: false;
		
		simulation_init <- true;
	}
		
   	reflex pinkopalino when: ping{//This will run only once at the beginning of each simulation
		//Ping planner
    	ask one_of(simAgents){
    		write "Agent " + name + " Pinging" color:#green;
			do send contents: "Ping;" + instance + ";" + seed + ";"  to:"localhost";
			ping <- false;
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
	
	action ask_for_replan(list<int> tasks_completed, list<int> remaining_agents){
		sent_msgs <- sent_msgs + 1;
		sent_msgs_allocation <- sent_msgs_allocation + 1;
		write "Agent: "+name+" sending a request for a replan";
		save ("remaining agents global: " + simulation_server[0].alive_agents + ", completed tasks " + tasks_completed_global) to: output_file_base+"results.txt" type: "text" rewrite: false;
		save ("remaining agents local: " + remaining_agents + ", completed tasks " + tasks_completed_global) to: output_file_base+"results.txt" type: "text" rewrite: false;
		save ("agents: " + simAgents.population ) to: output_file_base+"results.txt" type: "text" rewrite: false;
		
		list xpos <- [];//follows the order in alive_agents
		list ypos <- [];//follows the order in alive_agents
		
		list pop <- [];
		loop temp over:simAgents.population{
			add temp.name to: pop;
		}
		write pop;
		loop ag over: simulation_server[0].alive_agents{
			int idx <- pop index_of string(ag);
			write ag;
			write simulation_server[0].alive_agents;
			write simAgents.population;
			write "Index " + idx;
			add simAgents.population[idx].location.x to: xpos;
			add simAgents.population[idx].location.y to: ypos;
		}
		save ("position: " + xpos + " and ypos " + ypos ) to: output_file_base+"results.txt" type: "text" rewrite: false;
	  	//do send contents: "{\"msg_type\":\"replan\"," + "\"tasks\":"+tasks_completed_global+ ",\"agents\":"+simulation_server[0].alive_agents +",\"xpos\":"+xpos + ",\"ypos\":"+ypos +"}";
		do send contents: "{\"msg_type\":\"replan\"," + "\"tasks\":"+tasks_completed_global+ ",\"agents\":"+remaining_agents +",\"xpos\":"+xpos + ",\"ypos\":"+ypos +"}";
		
		//save ("{\"msg_type\":\"replan\"," + "\"tasks\":"+tasks_completed_global+ ",\"agents\":"+simulation_server[0].alive_agents + "}") to: output_file_base+"results.txt" type: "text" rewrite: false;
	
		save ("{\"msg_type\":\"replan\"," + "\"tasks\":"+tasks_completed_global+ ",\"agents\":"+remaining_agents + "}") to: output_file_base+"results.txt" type: "text" rewrite: false;
	
	}
	
	//Filter agents that are dead, from the ones within the range.
	list<simAgents> filter_dead_agents{
		//refactor loop a over: agents_close_by
		//get agents in the range
		list agents_to_ask <- simAgents at_distance communication_range;
		//remove dead agents
		list filtered_agents_close_by <- [];
		loop a over:agents_to_ask{
			if ! a.failed{
				add a to: filtered_agents_close_by; // this we can keep because in a real scenario sending a message to a dead agent will not yield a response anyway. 
			}
			//TODO maybe add here to known_failed_global the id of the failed agent if not there yet.
		}
		
		return filtered_agents_close_by;
	}
	
	//Filter agents that I know to be dead or whom I talked to, from the ones within the range.
	list<simAgents> filter_agents{
		//refactor loop a over: agents_close_by
		list agents_close_by <- agents_at_distance(communication_range) of_species simAgents;
		list filtered_agents_close_by <- agents_at_distance(communication_range) of_species simAgents;
		filtered_agents_close_by <- (filtered_agents_close_by sort_by (each.name)) ;
		if verbose{
			save ("Agents close by: " + agents_close_by + " to agent " + name) to: output_file_base+"results.txt" type: "text" rewrite: false;
			save ("Already talked to: " + already_talked_this_cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		loop a over: agents_close_by {
			
			int id <- a.name as_int 10;
			if (already_talked_this_cycle contains id) or (known_failed_global contains id){
				remove a from: filtered_agents_close_by;
			}
		}
		
		return filtered_agents_close_by;
	}
	
	int talk(list<simAgents> filtered_agents_close_by){
		//refactor ask one_of(filtered_agents_close_by) as: simAgents
		int agent_has_failed <- -1;
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
				save ("Detected failure of " + agent_has_failed + " at time" + cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
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
					write "Adding other agent known global: " + tasks_completed_global + " to " + combined;
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
				myself.pending_tasks[tt] <- myself.tasks_left_unassigned + myself.new_tasks;
				
				int tt2 <- name as_int 10;
				pending_tasks[tt2] <-tasks_left_unassigned + new_tasks;
				
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
		
		return agent_has_failed;
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
				add tasks.population[tasks_todo_idx[0]] to:total_completed_tasks_global;
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
		loop f over: simulation_server[0].dead_agents{
			if !(known_failed_global contains f){
				add f to: known_failed_global;
			}
		}
	}

	reflex gossip when: !failed and !simulation_init and !asking_planner{
		
		//Get list of agents close by
		list<simAgents> filtered_agents_close_by;
		filtered_agents_close_by <- filter_agents();

		if verbose{
			save ("Locally known as dead: " + known_failed_global + "\n" + "Agents close by: " + filtered_agents_close_by) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		
		//if list of agents is not empty, go ahead and ask one of them
		int agent_has_failed <- -1;
		if length(filtered_agents_close_by) > 0{
			sent_msgs <- sent_msgs + 1;

			agent_has_failed <- talk(filtered_agents_close_by);

			if ! (agent_has_failed = -1){
				ask simulation_server{
					if !(dead_agents contains agent_has_failed){
						add agent_has_failed to: dead_agents;
					}
				}
				if approach = "planner"{
					if !asking_planner{
						ask simulation_server{
							remove agent_has_failed from: alive_agents;
							write "Asking planner, dead agent " + agent_has_failed + " remaining alive " + alive_agents;
							save ("remaining agents: " + alive_agents) to: output_file_base+"results.txt" type: "text" rewrite: false;

						}
						do go_with_planner([]);
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
					
					list<int> temptasks <- pending_tasks[agent_has_failed];
					loop t over: temptasks{
						add t to: tasks_assigned;
					}
					
					if verbose{
						save ("Temp tasks " +  temptasks + " index in pending_tasks + 1 " + agent_has_failed ) to: output_file_base+"results.txt" type: "text" rewrite: false;
					
						save ("Failed agent " + agent_has_failed + " assigned " + tasks_assigned) to: output_file_base+"results.txt" type: "text" rewrite: false;
					}
					//write "Failed agent " + agent_has_failed + " assigned " + tasks_assigned;
					//get list of uncompleted tasks
					list<int> tasks_uncompleted <- [];
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
					filtered_agents_close_by <- filter_dead_agents();
					loop t over: tasks_uncompleted{
						list output <- request_willingness(t, filtered_agents_close_by, all_task_ids);
						willingness <- output[0];
						insert_location <- output[1];
						agent_to_assign <- output[2];
						bool done_or_allocated <- output[3];
						//assign?
						if !(willingness < 0.0){
							if !done_or_allocated{
								do allocate_tokeep(agent_to_assign, t, insert_location, all_task_ids);	
							}
							else{
								save ("Already allocated wow ") to: output_file_base+"results.txt" type: "text" rewrite: false;	
							}

							ask simulation_server{
								remove agent_has_failed from: alive_agents;
							}
						}
						//if not assigned this round
						else{
							if approach = "hybrid"{
								write "Self-allocation failed. Ask planner for plan";
								if !asking_planner{
									ask simulation_server{
										remove agent_has_failed from: alive_agents;
									}
									do go_with_planner([]);
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
						color <- simAgents.population[agent_to_assign].color;
						
					}
				
				
				//Re-Calculate the max expected duration
				int max_duration <- adjust_watchdog_trigger();
						
				//Adjust the tirgger to the watchdog based on the max duration.
				if !(max_duration = 0){
					
					watchdog_trigger <- max_duration;
					save ("READJUST (gossip) watchdog trigger: " + watchdog_trigger ) to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
				temp_cycle <- 0;
				save ("Same (gossip) watchdog trigger: " + watchdog_trigger ) to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
			}
		
		}
		
		already_talked_this_cycle <- [];	
	}
	
	//Only in the agent approach, once an agent is done with its tasks, it'll start handling the tasks it couldn\t assign when it noticed a dead agent
	reflex tendUnallocatedTasks when: approach = 'agent' and length(tasks_todo) <= 0 and length(tasks_left_unassigned) > 0 and !simulation_init and !failed{
		//get the list of neighbours
		list allocated <- [];
		bool done_or_allocated;
		
		//Get list of agents close by
		list<simAgents> filtered_agents_close_by;
		filtered_agents_close_by <- filter_dead_agents();
		
		//if list not empty try to allocate tasks
		list<int> all_task_ids <- [];
		loop t over:tasks.population{
			add t.taskID to: all_task_ids; 
		}
		save ("tendUnallocatedTask: Agents " + name + " still trying to assign  " +  tasks_left_unassigned) to: output_file_base+"results.txt" type: "text" rewrite: false;
		
		loop t over: tasks_left_unassigned{
			list output <- request_willingness(t, filtered_agents_close_by, all_task_ids);
			float willingness <- output[0];
			int insert_location <- output[1];
			int agent_to_assign <- output[2];
			done_or_allocated <- output[3];
			
			if done_or_allocated{
				add t to: allocated;
			}
			else{
				//assign 
				if !(willingness < 0.0){
					
					do allocate_tokeep(agent_to_assign, t, insert_location, all_task_ids);
					
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
		
		//Re-Calculate the max expected duration
		int max_duration <- adjust_watchdog_trigger();
				
		//Adjust the tirgger to the watchdog based on the max duration.
		if length(tasks_left_unassigned) > 0 and !(max_duration = 0){
			watchdog_trigger <- max_duration;
		}
		temp_cycle <- 0;
		save ("READJUST watchdog trigger: " + watchdog_trigger ) to: output_file_base+"results.txt" type: "text" rewrite: false;	
	}
	
	//discover which tasks are incomplete
	list discover_undone{
		list<int> tasks_pending <- [];
		list<int> agents_pending <- []; 
		//get location of the first such task in the list
		loop task over: tasks.population{
			if !(tasks_completed_global contains task.taskID) and ! (dead(task)){
				//move toward this task
				add task.taskID to: tasks_pending;
				add task.assigned_ag to: agents_pending;
				if !(known_failed_global contains task.assigned_ag){
					add task.assigned_ag to: known_failed_global;
				}
			}
		}
		return [tasks_pending, agents_pending];
	}
	
	//request willingness
	list request_willingness(int t, list<simAgents> filtered_agents_close_by, list<int> all_task_ids){
		list my_out <- calculate_willingness(all_task_ids index_of t);
		float willingness <- my_out[0];
		int insert_location <- my_out[1];
		//we consider the asking agent here
		int agent_to_assign <- name as_int 10;
		bool done_or_allocated <- false;
		if verbose{
			//write "Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location;
			save ("request_willingness: Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location) to: output_file_base+"results.txt" type: "text" rewrite: false;
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
		
		return [willingness, insert_location, agent_to_assign, done_or_allocated];
	}
	
	//request willingness / not to keep
	list request_willingness_temp(int t, list<simAgents> filtered_agents_close_by, list<int> all_task_ids){
		list my_out <- calculate_willingness(all_task_ids index_of t);
		float willingness <- my_out[0];
		int insert_location <- my_out[1];
		int agent_to_assign <- name as_int 10;
		bool done_or_allocated <- false;
		if verbose{
			//write "Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location;
			save ("Agent re-allocating " + name + " w: " + willingness + " il: " + insert_location) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		sent_msgs <- sent_msgs + length(filtered_agents_close_by);
		
		sent_msgs_allocation <- sent_msgs_allocation + length(filtered_agents_close_by);
		ask filtered_agents_close_by{
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
		return [willingness, insert_location, agent_to_assign, done_or_allocated];
	}
	
	//call planner
	action go_with_planner(list agents_pending){
		asking_planner <- true;
		plan_active <- false;
		completed_tasks_zeroed <- 0;
		
		list<int> remaining_agents_local;
		ask simulation_server{
			loop a over: all_agents{
				if ! (myself.known_failed_global contains a) and ! (agents_pending contains a){
					add a to: remaining_agents_local;
				}
			}
		}
		
		do ask_for_replan(tasks_completed_global, remaining_agents_local); 	
	}
	
	//allocate // this one should be kept for all. to replace allocate below as well
	action allocate_tokeep(int agent_to_assign, int t, int insert_location, list<int> all_task_ids){
		sent_msgs <- sent_msgs + 1;
		sent_msgs_allocation <- sent_msgs_allocation + 1;
		ask simAgents.population[agent_to_assign] {
			if verbose{
				//write "agent " + name + " assigned task" + t;
				//write "tasks todo " + tasks_todo;
				//write "indices " + tasks_todo_idx;
				save ("agent " + name + " assigned task " + t + "\n" + "tasks todo " + tasks_todo +"\n" + "indices " + tasks_todo_idx) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			// TODO add only if not already present
			if !(tasks_todo contains t){
				if !(new_tasks contains t){
					 if !(tasks_completed_global contains t){
						add t to: new_tasks;
					 }
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
	}
	
	//allocate-temp
	action allocate(int agent_to_assign, int t, int insert_location, list<int> all_task_ids){
		sent_msgs <- sent_msgs + 1;
		sent_msgs_allocation <- sent_msgs_allocation + 1;
		ask simAgents.population[agent_to_assign] {
			if verbose{
				save ("ALLOCATE: agent " + name + " assigned " + t + "\n" + "tasks todo " + tasks_todo + "\n" + "indices " + tasks_todo_idx) to: output_file_base+"results.txt" type: "text" rewrite: false;
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
				save ("ALLOCATE: agent " + name + " assigned " + t + "\n" + "tasks todo " + tasks_todo +"\n" + "indices " + tasks_todo_idx+"\n" + "new_tasks " + new_tasks) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
		}	
		
	}
	
	//If too much time has passed start trying to reallocate those tasks that are pending
	reflex watchdog when: temp_cycle>watchdog_trigger and !asking_planner and !simulation_init and !failed and length(tasks_todo) <= 0{
		if verbose{
				save ("WATCHDOG agent" + name + " There are " + (length_original_taskset - length(tasks_completed_global)) + " tasks, the status of which is unknown") to: output_file_base+"results.txt" type: "text" rewrite: false;
				save ("temp cyclet" + temp_cycle + "wathcodg trigger " + watchdog_trigger) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
		if length(tasks_completed_global) < length_original_taskset{
			temp_cycle <- 0;
			int nr_tasks_unknown <- length_original_taskset - length(tasks_completed_global);
			//write "There are " + nr_tasks_unknown + " tasks, the status of which is unknown" ;
			if verbose{
				save ("WATCHDOG: There are " + nr_tasks_unknown + " tasks, the status of which is unknown") to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			
			//get tasks which have not been completed
			list output <- discover_undone();
			list<int> tasks_pending <- output[0];
			list<int> agents_pending <- output[1]; 
			
			if verbose{
				save ("WATCHDOG: known_failed_global " + known_failed_global) to: output_file_base+"results.txt" type: "text" rewrite: false;
				save ("WATCHDOG: tasks pending " + tasks_pending) to: output_file_base+"results.txt" type: "text" rewrite: false;
				save ("WATCHDOG: agents pending " + agents_pending) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
			//if planner approach, then ask planner otherwise.
			if approach = "planner"{
				if !asking_planner{
					do go_with_planner(agents_pending);
				}
				else {
					if verbose{
						write "Already being taken care of";
					}
				}
			}
			else {
				list allocated <- [];
				bool done_or_allocated;
				float willingness;
				int insert_location;
				int agent_to_assign;
				
				//Get list of agents close by
				list<simAgents> filtered_agents_close_by;
				filtered_agents_close_by <- filter_dead_agents();
				
				//if list not empty try to allocate tasks
				list<int> all_task_ids <- [];
				loop t over:tasks.population{
					add t.taskID to: all_task_ids; 
				}
				save ("WATCHDOG: Agents " + name + " still trying to assign  " +  tasks_pending) to: output_file_base+"results.txt" type: "text" rewrite: false;
				if length(tasks_pending) > 0{
					loop t over: tasks_pending{
					
						list output <- request_willingness(t, filtered_agents_close_by, all_task_ids);
						willingness <- output[0];
						insert_location <- output[1];
						agent_to_assign <- output[2];
						done_or_allocated <- output[3];
						
						if !done_or_allocated{
							//assign 
							if !(willingness < 0.0){
								do allocate_tokeep(agent_to_assign, t, insert_location, all_task_ids);
							}
							else{
								if approach = "hybrid"{
									write "Self-allocation failed. Ask planner for plan";
									if !asking_planner{
										do go_with_planner(agents_pending);
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
						}
						
					}
				
				}
				
				//Re-Calculate the max expected duration
				int max_duration <- adjust_watchdog_trigger();
						
				//Adjust the tirgger to the watchdog based on the max duration.
				if !(max_duration = 0){
					
					watchdog_trigger <- max_duration;
					save ("READJUST (watchdog) watchdog trigger: " + watchdog_trigger ) to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
				temp_cycle <- 0;
				save ("SAME (watchdog) watchdog trigger: " + watchdog_trigger ) to: output_file_base+"results.txt" type: "text" rewrite: false;
			}
		}
	}
	
	int adjust_watchdog_trigger{
		//Re-Calculate the max expected duration
		int max_duration <- 0;
				
		ask simAgents{
			int dur <- 0;
					
			if length(tasks_todo) > 0{
				dur <- int(calc_duration());
			}
					
			if dur > max_duration{
				max_duration <- dur;
				}
		}
				
		//Adjust the tirgger to the watchdog based on the max duration.
		return max_duration;
	}
	
	reflex goToDepot when: !asking_planner and !simulation_init and !failed and length(tasks_todo) <= 0{
		if self distance_to depot < 0.001{
			save (name + " at the depot") to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		else{
			do goto target: depot;				
			save ("Agent:"+name+" Going towards the depot at time: "+cycle) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
			
		
	}
	
	//If the known global state of tasks is not fully known, walk toward tasks for which the robot has no info
	//this is basically trying to help the gossip propagate.
	reflex wanderTillComplete when: !asking_planner and !simulation_init and !failed and length(tasks_todo) <= 0 and false{
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
				if rnd(1.0) > 0.2  {
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
				}
				
			}
			else{
				do wander;	
				if verbose{
					save ("Just go to the depot") to: output_file_base+"results.txt" type: "text" rewrite: false;
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
			//do send contents: "Mission Complete";
			
			//Reset everything
			do reset;
	
		}
		else{
			//write "Agent " + name + " has still to do " + tasks_todo ;
		}
	}
	
	float calc_duration{
		float max_duration <- 0.0;
		//Calculate time to go to the first task + 1 (time at the task)
		float task_x <- tasks.population[tasks_todo_idx[0]].location.x;
		float task_y <- tasks.population[tasks_todo_idx[0]].location.y;
		float rruga <- sqrt((location.x - task_x)*(location.x - task_x) + (location.y - task_y)*(location.y - task_y));
		max_duration <- rruga / speed + 2;
		
		if verbose{
			//save ("calc_duration tasks " + tasks_todo ) to: output_file_base+"results.txt" type: "text" rewrite: false;
			//save ("calc_duration agent " + name + " location " + location + " task " + tasks_todo[0] + " location " +tasks.population[tasks_todo_idx[0]].location ) to: output_file_base+"results.txt" type: "text" rewrite: false;
			//save ("calc_duration rruga " + rruga ) to: output_file_base+"results.txt" type: "text" rewrite: false;
			//save ("calc_duration max_duration" + max_duration ) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		
		//Add times from task to task, + 1 each
		float xdiff;
		float ydiff;
		int i <- 0;
		if length(tasks_todo_idx) > 1{
			loop i from: 0 to: length(tasks_todo_idx)-2{
				xdiff <- tasks.population[tasks_todo_idx[i]].location.x - tasks.population[tasks_todo_idx[i+1]].location.x;
				ydiff <- tasks.population[tasks_todo_idx[i]].location.y - tasks.population[tasks_todo_idx[i+1]].location.y;
				
				rruga <- sqrt(xdiff*xdiff + ydiff*ydiff);
				max_duration <- max_duration + rruga / speed + 2;
				if verbose{
					//save ("calc_duration task 1 " + tasks_todo[i] + " location " + tasks.population[tasks_todo_idx[i]].location + " task 2 " + tasks_todo[i+1] + " location " + tasks.population[tasks_todo_idx[i+1]].location ) to: output_file_base+"results.txt" type: "text" rewrite: false;
					//save ("calc_duration rruga " + rruga ) to: output_file_base+"results.txt" type: "text" rewrite: false;
					//save ("calc_duration max_duration " + max_duration ) to: output_file_base+"results.txt" type: "text" rewrite: false;
				}
			}			
		}

		//Add time from last task to depot
		task_x <- tasks.population[tasks_todo_idx[length(tasks_todo_idx)-1]].location.x;
		task_y <- tasks.population[tasks_todo_idx[length(tasks_todo_idx)-1]].location.y;
		rruga <- sqrt((depot.x - task_x)*(depot.x - task_x) + (depot.y - task_y)*(depot.y - task_y));
		max_duration <- max_duration + rruga / speed + 2;
		if verbose{
			//save ("calc_duration task 1 " + tasks_todo[length(tasks_todo_idx)-1] + " location " + tasks.population[tasks_todo_idx[length(tasks_todo_idx)-1]].location + " depot " + depot ) to: output_file_base+"results.txt" type: "text" rewrite: false;
			//save ("calc_duration rruga " + rruga ) to: output_file_base+"results.txt" type: "text" rewrite: false;
			//save ("calc_duration max_duration " + max_duration ) to: output_file_base+"results.txt" type: "text" rewrite: false;
		}
		//Add some delta
		max_duration <- max_duration + DELTA;
		
		return max_duration;
	}
	
	reflex save_data when: !simulation_init{
		//if length(tasks_completed_global) >= length(tasks.population) and !simulation_init {
		if length(tasks_completed_global) >= length_original_taskset and !simulation_init {
			mcomplete <- 1;
		} 
		float xpos <- -1.0;
		float ypos <- -1.0;
		float xpostask <- -1.0;
		float ypostask <- -1.0;
		if location != nil{
			xpos <- location.x;
			ypos <- location.y;
		}
		if taskLocation != nil{
			xpostask <- taskLocation.x;
			ypostask <-  taskLocation.y;
		}
		save [cycle, xpos, ypos, xpostask, ypostask, completed_task_id, sent_msgs, int(failed), mission_count, mcomplete, int(asking_planner), time, total_duration, sent_msgs_allocation, seed] to: output_file_base+name+"_agent.csv" type: "csv" rewrite:false;
		
		completed_task_id <- -1;
		
		if mcomplete = 1{
			do checkMissionComplete;
		}

	}
	
	reflex timeout when: (infeasible or (cycle - starttime > 5000)) and !simulation_init and !asking_planner{//timeout only if plan not feasible, close in the next step
	
		if timeout_trigger = 0{
			infeasible <- false;
    		write "TIMEOUT reset";
    		save ("TIMEOUT reset") to: output_file_base+"results.txt" type: "text" rewrite: false;
    		do reset;
		}
		else{
			timeout_trigger <- timeout_trigger - 1;
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
	float duration <- 0.0;
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
    	monitor "temp_cycle" value: temp_cycle refresh: every(1); 
    	monitor "cycle" value: cycle refresh: every(1); 
    	monitor "fails" value: still_to_fail refresh: every(1);
    	monitor "instance" value: instance refresh: every(1);
    	monitor "run number" value: run_number refresh: every(1);
    	monitor "seed" value: seed refresh: every(1);
    	monitor "completed tasks" value: completed_tasks refresh: every(1);
    	monitor "dead agents" value: simulation_server[0].dead_agents refresh: every(1);
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

