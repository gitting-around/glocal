# Instructions on running the GLocal simulations

## Requirements

* Tested OS: Windows 10
* Gama version: v1.8.1, download as bundle with jdk, from https://gama-platform.org/.
* [INSERT other dependencies]

## Setup the Gama environment

After downloading Gama, load the project (```models/``` folder).

## Run the simulation

* Open Gama, and load the ```gitagent_batch_refactored.gaml``` file in the editor. Here you can potentially change parameters like the communication range etc.
* Run the planner executable (```GLocal planner.exe```).
* Run the experiment in Gama. You should observe in the terminal view of the planner that a ```ping``` message has been received. This means that the simulation
has been initiated correctly, and will continue until all simulations are run.
* At the end of all simulations, a red line will be printed on the Gama console with the following: ```Simulation End!```.

### Configuring the simulation

The problem instances (consisting of number of agents and task set sizes are given).
There are 10 agents, and three problem instances of 50, 100, 150 tasks each. 
Information on these can be found in the files ```Agents_#tasks.csv```, ```Tasks_#tasks.csv``` found in the ```models/``` folder.
Initial locations, and equipment are defined.

> **Warning** You cannot run with the files present in the system, arbitrary scenarios with different number of agents and tasks!!

Nevertheless, there are parameters that you can configure such as:

* The communication range (given in m). 
**FIX in line** https://github.com/gitting-around/glocal/blob/479fdc42fcc4dbcd4fb699c1643a678cc016a32c/models/gitagent_batch_refactored.gaml#L56
* Subset of the problem instances (if you want to run 1 and not all), instance 0 -> 50 tasks, instance 1 -> 100 tasks, instance 2 -> 150 tasks.
**FIX in line** https://github.com/gitting-around/glocal/blob/479fdc42fcc4dbcd4fb699c1643a678cc016a32c/models/gitagent_batch_refactored.gaml#L23
* Approaches (similar to the previous).
**FIX in line** https://github.com/gitting-around/glocal/blob/479fdc42fcc4dbcd4fb699c1643a678cc016a32c/models/gitagent_batch_refactored.gaml#L25
* \# of failed agents (similar to previous).
**FIX in line** https://github.com/gitting-around/glocal/blob/479fdc42fcc4dbcd4fb699c1643a678cc016a32c/models/gitagent_batch_refactored.gaml#L28
* Total # of runs for one scenario by changing the seed.
**FIX in line** https://github.com/gitting-around/glocal/blob/479fdc42fcc4dbcd4fb699c1643a678cc016a32c/models/gitagent_batch_refactored.gaml#L33
* Seed calculation (also used by the planner).
**FIX in code** https://github.com/gitting-around/glocal/blob/479fdc42fcc4dbcd4fb699c1643a678cc016a32c/models/gitagent_batch_refactored.gaml#L73

> **Note** If you have set up a batch of simulations, and something happens (Windows decides to update...AGAIN!), it is possible to resume the simulations 
where you left off.

You can do this by:

* Setting the number of run you want to start from.
**FIX in line** https://github.com/gitting-around/glocal/blob/479fdc42fcc4dbcd4fb699c1643a678cc016a32c/models/gitagent_batch_refactored.gaml#L71
* Specifying from which approach to start from (the index depends on the order when that list is initialised in line 25.).
Assume I have declared the approaches as ```list<string> param_approach <- ['agent', 'hybrid', 'planner'];``` (line 25). Assume I want to restart from 
hybrid, to do so in line 41 we would write ```int idx_approach <- 1;```.
* Specifying from which problem instance, similar to the previous.
Assume I have declared the approaches as ```list<int> param_instance <- [0,1,2];``` (line 23). Assume I want to restart from 
the last instance, to do so in line 40 we would write ```int idx_instance <- 2;```.
* Specifying the failure case, similar to the previous.
Assume I have declared the approaches as ```list<int> param_tofail <- [0,1,2,3,4,5,6,7];``` (line 28). Assume I want to restart from 
the case with 4 failures, to do so in line 42 we would write ```int idx_tofail <- 5;```.

The loops over the parameters to setup the next simulation look like below:
```code
loop #instances:
  loop #approaches:
    loop #fails:
      loop #runs:
```

> **Warning** You are of course free to change the rest of the code, however do so at own peril.

