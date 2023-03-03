clear;
instance = 0;
no_runs = 30;
fails_base = 1;

total_fails = 7;

no_task_sets = 3;
task_set_base = 50;
%get results from specific range folder
comm_range = 1000;
if comm_range > 100
    folder_root = ['mar3_range100/rangeInf/'];
else
    folder_root = ['mar3_range100/range' int2str(comm_range) '/'];
end

pl_data = cell(no_task_sets,total_fails);
ag_data = cell(no_task_sets,total_fails);
hy_data = cell(no_task_sets,total_fails);

%Get data from csv files
for j=1:no_task_sets
    instance = j-1;
    for i=fails_base:total_fails+1
       pf = folder_root+"planner/inst"+instance+"_planner_fails_"+int2str(i-1)+"_";
       pl_data{j,i} = table2array(readtable(pf,'DatetimeType','text', 'Delimiter', ' '));

       af = folder_root+"agent/inst"+instance+"_agent_fails_"+int2str(i-1)+"_";
       ag_data{j,i} = table2array(readtable(af,'DatetimeType','text', 'Delimiter', ' '));

       hf = folder_root+"hybrid/inst"+instance+"_hybrid_fails_"+int2str(i-1)+"_";
       hy_data{j,i} = table2array(readtable(hf,'DatetimeType','text', 'Delimiter', ' '));
    end
end
%ag_data = hy_data;

%Plot mission durations
timeout = 50000 - 1;

aves_all = cell(no_task_sets, 1);
stds_all = cell(no_task_sets, 1);

aves_all_pl = cell(no_task_sets, 1);
stds_all_pl = cell(no_task_sets, 1);

for j=1:no_task_sets
    aves_all{j} = zeros(total_fails+1,3);
    stds_all{j} = zeros(total_fails+1,3);

    aves_all_pl{j} = zeros(total_fails+1,3);
    stds_all_pl{j} = zeros(total_fails+1,3);
end

metrics = ["Mission Duration", "# Messages", "# Compl Task", "# Reqs to Planner", "# Missions Compl", "# Failed Agents"];

%metrics = ["Mission Duration", "# Messages", "# Reqs to Planner"];

metric_idx = [1, 2, 3, 4, 6, 7];
%metric_idx = [1, 2, 4];

for m=1:length(metrics)
    for i=fails_base:total_fails+1  
        dur = cell(no_task_sets, 1);
        dur_planning = cell(no_task_sets, 1);
        for j=1:no_task_sets
            if m ~= 5 %we want to consider uncomplete missions for # Missions Compl metric
                pl_data{j,i}(find(pl_data{j,i}(:,6) == 0),metric_idx(m)) = NaN;
                ag_data{j,i}(find(ag_data{j,i}(:,6) == 0),metric_idx(m)) = NaN;
                hy_data{j,i}(find(hy_data{j,i}(:,6) == 0),metric_idx(m)) = NaN;
            end
            %pl_data{j,i}(find(pl_data{j,i}(:,6) == 0),8) = NaN;
            %ag_data{j,i}(find(ag_data{j,i}(:,6) == 0),8) = NaN;
            %hy_data{j,i}(find(hy_data{j,i}(:,6) == 0),8) = NaN;

            dur{j} = [pl_data{j,i}(:,metric_idx(m)) ag_data{j,i}(:,metric_idx(m)) hy_data{j,i}(:,metric_idx(m))];
            %get valus for planning duration only
            %dur_planning{j} = [pl_data{j,i}(:,8) ag_data{j,i}(:,8) hy_data{j,i}(:,8)];
        end

        for j=1:no_task_sets
            aves_all{j}(i,:) = mean(dur{j},1, 'omitnan');
            stds_all{j}(i,:) = std(dur{j},1, 'omitnan');

            %aves_all_pl{j}(i,:) = mean(dur_planning{j},1, 'omitnan');
            %stds_all_pl{j}(i,:) = std(dur_planning{j},1, 'omitnan');
        end

    end


    figure;
    h1=surf([0:2], [0:7], [aves_all{1}(:,1), aves_all{2}(:,1), aves_all{3}(:,1)], 'FaceColor',"#EDB120", 'FaceAlpha',0.5, 'EdgeColor','none');
    hold on;
    h2=surf([0:2], [0:7], [aves_all{1}(:,2), aves_all{2}(:,2), aves_all{3}(:,2)], 'FaceColor',	"#A2142F", 'FaceAlpha',0.5, 'EdgeColor','none');
    h3=surf([0:2], [0:7], [aves_all{1}(:,3), aves_all{2}(:,3), aves_all{3}(:,3)], 'FaceColor',"#0072BD", 'FaceAlpha',0.5, 'EdgeColor','none');

    %legend('planner','agent','hybrid', 'Location','northwest')

    ylabel('Fails')
    xlabel('Instances')
    title_str = metrics(m);
    zlabel(title_str)
    title(title_str)
    filename = title_str + int2str(comm_range) + '_3D.tex';
    filename = regexprep(filename, '\s+', '');
    %matlab2tikz(char(filename)); 
    nameoffile = regexprep(title_str + '_' + int2str(comm_range) + '_3D', '\s+', '')
    fig = fig2plotly(gcf, 'TreatAs', 'surf', 'offline', true, 'filename', char(nameoffile));
    
    %     errorbar([0:2], [aves_all{1}(i,1) aves_all{2}(i,1) aves_all{3}(i,1)], [stds_all{1}(i,1) stds_all{2}(i,1) stds_all{3}(i,1)], 'bp','HandleVisibility','off');
    %     errorbar([0:2], [aves_all{1}(i,2) aves_all{2}(i,2) aves_all{3}(i,2)], [stds_all{1}(i,2) stds_all{2}(i,2) stds_all{3}(i,2)], 'gp','HandleVisibility','off');
    %     errorbar([0:2], [aves_all{1}(i,3) aves_all{2}(i,3) aves_all{3}(i,3)], [stds_all{1}(i,3) stds_all{2}(i,3) stds_all{3}(i,3)], 'rp','HandleVisibility','off');

end

