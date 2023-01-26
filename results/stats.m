function stats(name, run, no_agents)

data = {};

%there are 11 columns in each raw data file.
% cycle location_x location_y taskLocation_x taskLocation_y completed_task_id 
% 1     2          3          4              5              6
% sent_msgs int_failed mission_count mcomplete int_asking_planner
% 7         8          9             10        11
for i = 1:no_agents
    agent_name = i - 1;
    fullname = name + run + "_" + agent_name + "_agent.csv"
    t = readtable(fullname,'DatetimeType','text', 'Delimiter', ',');
    data{i} = t{:,:};
end

tt_ms = [];
tt_me = [];
tt_comp = [];
no_msgs_agent = [];
finished_tasks = [];
new_plan_requests = [];
new_plans = [];
failed = [];
agents_failed = 0;
for i = 1:no_agents
    %find mission start
    tt_ms = [tt_ms data{i}(1,1)];
    %find mission end
    tt_me = [tt_me data{i}(end,1)];
    %find mission complete
    idx = find(data{i}(:,10));
    tt_comp = [tt_comp idx];
    %no_messages
    no_msgs_agent = [no_msgs_agent data{i}(end,7)];
    %finished tasks
    t_idx = data{i}(:,6) >= 0;
    finished_tasks = [finished_tasks; data{i}(t_idx,6)];
    %mission count
    new_plans = [new_plans data{i}(end,9)];
    %plan requests count 
    new_plan_requests = [new_plan_requests data{i}(end,11)];
    %failed
    if any( data{i}(end,8) == 1 )
        agents_failed = agents_failed + 1;
    end
    failed = [failed data{i}(end,8)]
end

if  ~all(tt_ms == tt_ms(1))
    disp('mission start not the same for all agents')
    tt_ms
end
if  ~all(tt_me == tt_me(1))
    disp('mission end not the same for all agents')
    tt_me
end
if  ~all(new_plans == new_plans(1))
    disp('mission count not the same for all agents')
    new_plans
end
if  ~all(new_plan_requests == new_plan_requests(1))
    disp('plan requests count not the same for all agents')
    new_plan_requests
end
if ~(new_plan_requests(1)+1)==new_plans(1)
    disp('mission count and planner requests don''t match')
    new_plans
    new_plan_requests
end


mission_start = min(tt_ms);
mission_end = max(tt_me);
mission_duration = mission_end - mission_start;
mission_complete_time = tt_comp ;
no_msgs_tot = sum(no_msgs_agent);
length(finished_tasks);

%get the time it took for replanning from the 1st agent - should be the
%same for all
planning_duration = sum(data{1}(:,11)>0);

output = [ name + '.csv' ];
fid = fopen( output, 'a+' );

fprintf( fid, '%d %d %d %d %d %d %d %d\n',mission_duration,no_msgs_tot,length(finished_tasks),max(new_plans),sum(failed), length(mission_complete_time), agents_failed, planning_duration );

fclose( fid );

end



