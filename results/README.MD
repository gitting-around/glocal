# Processing results

Once the batch of simulations is finished, it is possible to process the data and create different plots for visualisation.

Requirements: the following scripts are run in matlab (2020a).

## Format of generated logs

For each distinct simulation, several log files are generated:

    * 1 log file per agent (.csv), logging different metrics for each cycle.
    * 1 (.txt) file with verbose logs from all agents and the simulation itself.
    * other log files which are not discussed here.

The name for the .csv files looks like shown below:

inst#instance_approach_fails_#fails_#runNumber_#agentID_agent.csv

E.g. consider the following:

inst2_planner_fails_0_5_3_agent.csv contains tabular logs for the simulation with the second instance (150 tasks), using the planner approach
with zero failures, run 5 (affects the simulation seed), for agent 3.

## Extract metrics from .csv logs

In order to estimate the different metrics, the results have to first be organised in three different folders namely: planner, agent, hybrid. 
You can use other names, however in that case you need to modify the folder names in the script by hand.

To aggregate the data for every run, we use the ```process_raw_data.m``` script (has to be in the same folder as the three created folders).
By opening the script, one can modify some of the parameters, e.g., # of failures, approaches, and instances considered.
Additionally, the folder where the script will look for the raw data can be modified through the variable ```folder_root```.
This script will call the ```stats.m```, which will produce a file named as:

inst#instance_approach_fails_#fails_.csv, an example is given below:

inst2_agent_fails_5_.csv which contains results aggregated over agents for each run (seed) for instance 2, agent approach, and 5 failures. If
you have 30 runs, this table will contain 30 rows.

Note that ```process_raw_data.m``` has to be called for every distinct communication range. It will not loop for a set of communication ranges.

## Plot the data

At this point it is possible to plot the aggregated data in different ways.

Here we provide three scripts for different visualisations.

### 3D plots

If you are interested in generating 3D plots for each metric, over instance size and #fails, then run ```plot3D.m```.
The ```folder_root``` variable has to be the same as in the previous step. 
Here we need to set the ```comm_range``` variable accordingly.

In lines 55, and 59, you can set a subset of the metrics for plotting, see the commented example, and be careful that the ```metric_idx```
does not increase with an increment of 1.

### 2D plots over instance sizes

If you are interested in 2D plots over the instance sizes, use the script ```plotres2.m```.
The ```folder_root``` variable has to be the same as in the previous step. 
Here we need to set the ```comm_range``` variable accordingly.

In lines 58, and 59, you can set a subset of the metrics for plotting, see the commented example, and be careful that the ```metric_idx```
does not increase with an increment of 1.

### 2D plots over #fails

If you are interested in 2D plots over the #fails, use the script ```plotres.m```.
The ```folder_root``` variable has to be the same as in the previous step. 

This script does not have currently a variable for the ```comm_range```. Additionally, it is not possible to plot a subset of the metrics as in the previous steps. All metrics will be plotted in one figure with subfigures.
Here it is necessary to set the instance (line 2).
