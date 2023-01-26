clear;
instance = 0;
no_runs = 30;
fails_base = 1;

total_fails = 7;

no_task_sets = 3;
task_set_base = 20;
%get results from specific range folder
comm_range = 20;
if comm_range > 100
    folder_root = ['jan23-res/rangeInf/'];
else
    folder_root = ['jan23-res/range' int2str(comm_range) '/'];
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


hold all;
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
yaxis = ["Cycles", "# msgs", "# tot tasks", "# reqs2planner", "# tot missions", "# agents failed"];

%metrics = ["Mission Duration", "# Messages", "# Reqs to Planner"];
%yaxis = ["Cycles", "# msgs", "# reqs2planner"];

metric_idx = [1, 2, 3, 4, 6, 7];
%metric_idx = [1, 2, 4];

for m=1:length(metrics)
    subfig = 1;
    figure();
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

        %% Uncomment lines below for boxplots
        %     subplot(6,total_fails+1,subfig);
        %     boxplot(dur)
        %     xlabel('Approach')
        %     ylabel('Cycles')
        %     title_str = "Nr of msgs -- fail " + int2str(i-1);
        %     title(title_str)
        %     set(gca,'XTick',1:3,'XTickLabel',{'planner','agent','hybrid'})
        %     subfig = subfig + 1;
        for j=1:no_task_sets
            aves_all{j}(i,:) = mean(dur{j},1, 'omitnan');
            stds_all{j}(i,:) = std(dur{j},1, 'omitnan');

            %aves_all_pl{j}(i,:) = mean(dur_planning{j},1, 'omitnan');
            %stds_all_pl{j}(i,:) = std(dur_planning{j},1, 'omitnan');
        end
        
        subplot(4,2,subfig);
        hold on
        plot([0:2], [aves_all{1}(i,1) aves_all{2}(i,1) aves_all{3}(i,1)], 'b-o');
        plot([0:2], [aves_all{1}(i,2) aves_all{2}(i,2) aves_all{3}(i,2)], 'gx-');
        plot([0:2], [aves_all{1}(i,3) aves_all{2}(i,3) aves_all{3}(i,3)], 'r-+');

        xlabel('Instances')
        ylabel(yaxis(m))
        
        title_str = metrics(m) ;

        legend('planner','agent', 'hybrid', 'Location','northwest')

        errorbar([0:2], [aves_all{1}(i,1) aves_all{2}(i,1) aves_all{3}(i,1)], [stds_all{1}(i,1) stds_all{2}(i,1) stds_all{3}(i,1)], 'bp','HandleVisibility','off');
        errorbar([0:2], [aves_all{1}(i,2) aves_all{2}(i,2) aves_all{3}(i,2)], [stds_all{1}(i,2) stds_all{2}(i,2) stds_all{3}(i,2)], 'gp','HandleVisibility','off');
        errorbar([0:2], [aves_all{1}(i,3) aves_all{2}(i,3) aves_all{3}(i,3)], [stds_all{1}(i,3) stds_all{2}(i,3) stds_all{3}(i,3)], 'rp','HandleVisibility','off');

        %     %Plot planning duration
        %     plot([0:total_fails], aves_all_pl(:,1), 'b--o');
        %     plot([0:total_fails], aves_all_pl(:,2), 'gx--');
        %     plot([0:total_fails], aves_all_pl(:,3), 'r--+');
        %     errorbar([0:total_fails], aves_all_pl(:,1), stds_all_pl(:,1), 'bp','HandleVisibility','off');
        %     errorbar([0:total_fails], aves_all_pl(:,2), stds_all_pl(:,2), 'gp','HandleVisibility','off');
        %     errorbar([0:total_fails], aves_all_pl(:,3), stds_all_pl(:,3), 'rp','HandleVisibility','off');

        title(title_str+' #fails='+int2str(i-1))
        subfig = subfig + 1;

    end
    filename = title_str + int2str(comm_range) + '.tex';
    filename = regexprep(filename, '\s+', '');
    %matlab2tikz(char(filename)); 
    
    nameoffile = regexprep(title_str + '_' + int2str(comm_range) + '_2D', '\s+', '')
    fig = fig2plotly(gcf, 'offline', true, 'filename', char(nameoffile));
end

