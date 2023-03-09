%get stats for all runs
clear;
no_agents = 10;
fails = 0:7;

runs = 1:30;
approach = ["planner" "agent" "hybrid"];
instance = [0,1,2];


folder_root = "jan23-res/range20/";

for i=1:length(approach)
    for j=1:length(instance)
        for k=1:length(fails)
            for l=1:length(runs)
                name = folder_root + approach(i) + "/inst"+instance(j)+"_" + approach(i) + "_fails_" + fails(k) + "_" 
                stats(name, runs(l), no_agents)
            end
        end
    end
end