clear;
instance = 2;
no_runs = 30;
fails_base = 1;

total_fails = 7;

pl_data = cell(1,total_fails);
ag_data = cell(1,total_fails);
hy_data = cell(1,total_fails);

folder_root = "mar3_range100/range100/";

%Get data from csv files
for i=fails_base:total_fails+1
   pf = folder_root+"planner/inst"+instance+"_planner_fails_"+int2str(i-1)+"_";
   pl_data{i} = table2array(readtable(pf,'DatetimeType','text', 'Delimiter', ' '));
   
   af = folder_root+"agent/inst"+instance+"_agent_fails_"+int2str(i-1)+"_";
   ag_data{i} = table2array(readtable(af,'DatetimeType','text', 'Delimiter', ' '));
   
   hf = folder_root+"hybrid/inst"+instance+"_hybrid_fails_"+int2str(i-1)+"_";
   hy_data{i} = table2array(readtable(hf,'DatetimeType','text', 'Delimiter', ' '));
end

%ag_data = hy_data;

subfig = 1;
figure();
hold all;
%Plot mission durations
timeout = 50000 - 1;

aves_all = zeros(total_fails+1,3);
stds_all = zeros(total_fails+1,3);

aves_all_pl = zeros(total_fails+1,3);
stds_all_pl = zeros(total_fails+1,3);

for i=fails_base:total_fails+1   
    pl_data{i}(find(pl_data{i}(:,6) == 0),1) = NaN;
    ag_data{i}(find(ag_data{i}(:,6) == 0),1) = NaN;
    hy_data{i}(find(hy_data{i}(:,6) == 0),1) = NaN;
    
    pl_data{i}(find(pl_data{i}(:,6) == 0),8) = NaN;
    ag_data{i}(find(ag_data{i}(:,6) == 0),8) = NaN;
    hy_data{i}(find(hy_data{i}(:,6) == 0),8) = NaN;

    dur = [pl_data{i}(:,1) ag_data{i}(:,1) hy_data{i}(:,1)];
    
    %get valus for planning duration only
    dur_planning = [pl_data{i}(:,8) ag_data{i}(:,8) hy_data{i}(:,8)];
    
    %dur = [pl_data{i}(pl_data{i}(:,1) < timeout,1) ag_data{i}(ag_data{i}(:,1) < timeout,1) hy_data{i}(hy_data{i}(:,1) < timeout,1)];
    
%% Uncomment lines below for boxplots
%     subplot(6,total_fails+1,subfig);
%     boxplot(dur)
%     xlabel('Approach')
%     ylabel('Cycles')
%     title_str = "Nr of msgs -- fail " + int2str(i-1);
%     title(title_str)
%     set(gca,'XTick',1:3,'XTickLabel',{'planner','agent','hybrid'})
%     subfig = subfig + 1;
    
    aves_all(i,:) = mean(dur,1, 'omitnan');
    stds_all(i,:) = std(dur,1, 'omitnan');
    
    aves_all_pl(i,:) = mean(dur_planning,1, 'omitnan');
    stds_all_pl(i,:) = std(dur_planning,1, 'omitnan');
    
end

subplot(3,2,subfig);
hold on
plot([0:total_fails], aves_all(:,1), 'b-o');
plot([0:total_fails], aves_all(:,2), 'gx-');
plot([0:total_fails], aves_all(:,3), 'r-+');

xlabel('Fails')
ylabel('Cycles')
title_str = "Mission Duration";
    
legend('planner','agent', 'hybrid', 'Location','northwest')

errorbar([0:total_fails], aves_all(:,1), stds_all(:,1), 'bp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,2), stds_all(:,2), 'gp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,3), stds_all(:,3), 'rp','HandleVisibility','off');

%Plot planning duration
plot([0:total_fails], aves_all_pl(:,1), 'b--o');
plot([0:total_fails], aves_all_pl(:,2), 'gx--');
plot([0:total_fails], aves_all_pl(:,3), 'r--+');
errorbar([0:total_fails], aves_all_pl(:,1), stds_all_pl(:,1), 'bp','HandleVisibility','off');
errorbar([0:total_fails], aves_all_pl(:,2), stds_all_pl(:,2), 'gp','HandleVisibility','off');
errorbar([0:total_fails], aves_all_pl(:,3), stds_all_pl(:,3), 'rp','HandleVisibility','off');

title(title_str)
subfig = subfig + 1;


%Plot no_msgs
for i=fails_base:total_fails+1
    pl_data{i}(find(pl_data{i}(:,6) == 0),2) = NaN;
    ag_data{i}(find(ag_data{i}(:,6) == 0),2) = NaN;
    hy_data{i}(find(hy_data{i}(:,6) == 0),2) = NaN;
    
    dur = [pl_data{i}(:,2) ag_data{i}(:,2) hy_data{i}(:,2)];
    aves_all(i,:) = mean(dur,1, 'omitnan');
    stds_all(i,:) = std(dur,1, 'omitnan');
    
%% Uncomment lines below for boxplots
%     subplot(6,total_fails+1,subfig);
%     boxplot(dur)
%     xlabel('Approach')
%     ylabel('Cycles')
%     title_str = "Nr of msgs -- fail " + int2str(i-1);
%     title(title_str)
%     set(gca,'XTick',1:3,'XTickLabel',{'planner','agent','hybrid'})
%     %saveas(gcf,'Duration -- fail0.png')
%     subfig = subfig + 1;

end

subplot(3,2,subfig);
hold on
plot([0:total_fails], aves_all(:,1), 'b-o');
plot([0:total_fails], aves_all(:,2), 'gx-');
plot([0:total_fails], aves_all(:,3), 'r-+');

xlabel('Fails')
ylabel('# messages')
title_str = "Number of messages";
    
legend('planner','agent', 'hybrid', 'Location','northwest')

errorbar([0:total_fails], aves_all(:,1), stds_all(:,1), 'bp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,2), stds_all(:,2), 'gp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,3), stds_all(:,3), 'rp','HandleVisibility','off');
title(title_str)
subfig = subfig + 1;


%Plot nr of completed tasks
for i=fails_base:total_fails+1
    pl_data{i}(find(pl_data{i}(:,6) == 0),3) = NaN;
    ag_data{i}(find(ag_data{i}(:,6) == 0),3) = NaN;
    hy_data{i}(find(hy_data{i}(:,6) == 0),3) = NaN;
    
    dur = [pl_data{i}(:,3) ag_data{i}(:,3) hy_data{i}(:,3)];
    aves_all(i,:) = mean(dur,1, 'omitnan');
    stds_all(i,:) = std(dur,1, 'omitnan');
    
%% Uncomment lines below for boxplots
%     subplot(6,total_fails+1,subfig);
%     boxplot(dur)
%     xlabel('Approach')
%     ylabel('Cycles')
%     title_str = "Compl. tasks -- fail " + int2str(i-1);
%     title(title_str)
%     set(gca,'XTick',1:3,'XTickLabel',{'planner','agent','hybrid'})
%     %saveas(gcf,'Duration -- fail0.png')
%     subfig = subfig + 1;

end

subplot(3,2,subfig);
hold on
plot([0:total_fails], aves_all(:,1), 'b-o');
plot([0:total_fails], aves_all(:,2), 'gx-');
plot([0:total_fails], aves_all(:,3), 'r-+');
yline(50*(instance+1),'--','# Individual Tasks', 'LineWidth', 2, 'Color', 'm');

xlabel('Fails')
ylabel('# completed tasks')
title_str = "Number of completed tasks";
    
legend('planner','agent', 'hybrid', 'Location','northwest')

errorbar([0:total_fails], aves_all(:,1), stds_all(:,1), 'bp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,2), stds_all(:,2), 'gp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,3), stds_all(:,3), 'rp','HandleVisibility','off');
title(title_str)
subfig = subfig + 1;


%Plot nr of requests to planner
for i=fails_base:total_fails+1
    pl_data{i}(find(pl_data{i}(:,6) == 0),4) = NaN;
    ag_data{i}(find(ag_data{i}(:,6) == 0),4) = NaN;
    hy_data{i}(find(hy_data{i}(:,6) == 0),4) = NaN;
    
    dur = [pl_data{i}(:,4) ag_data{i}(:,4) hy_data{i}(:,4)];
    aves_all(i,:) = mean(dur,1, 'omitnan');
    stds_all(i,:) = std(dur,1, 'omitnan');   
%% Uncomment lines below for boxplots
%     subplot(6,total_fails+1,subfig);
%     boxplot(dur)
%     xlabel('Approach')
%     ylabel('Cycles')
%     title_str = "Reqs to planner -- fail " + int2str(i-1);
%     title(title_str)
%     set(gca,'XTick',1:3,'XTickLabel',{'planner','agent','hybrid'})
%     %saveas(gcf,'Duration -- fail0.png')
%     subfig = subfig + 1;

end

subplot(3,2,subfig);
hold on
plot([0:total_fails], aves_all(:,1), 'b-o');
plot([0:total_fails], aves_all(:,2), 'gx-');
plot([0:total_fails], aves_all(:,3), 'r-+');

xlabel('Fails')
ylabel('# requests to planner')
title_str = "Number of requests to planner";
    
legend('planner','agent', 'hybrid', 'Location','northwest')

errorbar([0:total_fails], aves_all(:,1), stds_all(:,1), 'bp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,2), stds_all(:,2), 'gp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,3), stds_all(:,3), 'rp','HandleVisibility','off');
title(title_str)
subfig = subfig + 1;



%Plot nr of missions completed
for i=fails_base:total_fails+1
    dur = [pl_data{i}(:,6) ag_data{i}(:,6) hy_data{i}(:,6)];
    aves_all(i,:) = mean(dur,1, 'omitnan');
    stds_all(i,:) = std(dur,1, 'omitnan');   
%% Uncomment lines below for boxplots
%     subplot(6,total_fails+1,subfig);
%     boxplot(dur)
%     xlabel('Approach')
%     ylabel('Cycles')
%     title_str = "Missions compl. -- fail " + int2str(i-1);
%     title(title_str)
%     set(gca,'XTick',1:3,'XTickLabel',{'planner','agent','hybrid'})
%     %saveas(gcf,'Duration -- fail0.png')
%     subfig = subfig + 1;

end

subplot(3,2,subfig);
hold on
plot([0:total_fails], aves_all(:,1), 'b-o');
plot([0:total_fails], aves_all(:,2), 'gx-');
plot([0:total_fails], aves_all(:,3), 'r-+');

xlabel('Fails')
ylabel('# missions completed')
title_str = "Number of missions completed";
    
legend('planner','agent', 'hybrid', 'Location','northwest')

errorbar([0:total_fails], aves_all(:,1), stds_all(:,1), 'bp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,2), stds_all(:,2), 'gp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,3), stds_all(:,3), 'rp','HandleVisibility','off');
title(title_str)
subfig = subfig + 1;


%Plot nr of failed agents
for i=fails_base:total_fails+1
    pl_data{i}(find(pl_data{i}(:,6) == 0),7) = NaN;
    ag_data{i}(find(ag_data{i}(:,6) == 0),7) = NaN;
    hy_data{i}(find(hy_data{i}(:,6) == 0),7) = NaN;
    
    dur = [pl_data{i}(:,7) ag_data{i}(:,7) hy_data{i}(:,7)];
    aves_all(i,:) = mean(dur,1, 'omitnan');
    stds_all(i,:) = std(dur,1, 'omitnan');   
%% Uncomment lines below for boxplots
%     subplot(6,total_fails+1,subfig);
%     boxplot(dur)
%     xlabel('Approach')
%     ylabel('Cycles')
%     title_str = "Failed agents -- fail " + int2str(i-1);
%     title(title_str)
%     set(gca,'XTick',1:3,'XTickLabel',{'planner','agent','hybrid'})
%     %saveas(gcf,'Duration -- fail0.png')
%     subfig = subfig + 1;

end

subplot(3,2,subfig);
hold on
plot([0:total_fails], aves_all(:,1), 'b-o');
plot([0:total_fails], aves_all(:,2), 'gx-');
plot([0:total_fails], aves_all(:,3), 'r-+');

xlabel('Fails')
ylabel('# failed agents')
title_str = "Number of failed agents";
    
legend('planner','agent', 'hybrid', 'Location','northwest')

errorbar([0:total_fails], aves_all(:,1), stds_all(:,1), 'bp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,2), stds_all(:,2), 'gp','HandleVisibility','off');
errorbar([0:total_fails], aves_all(:,3), stds_all(:,3), 'rp','HandleVisibility','off');
title(title_str)
subfig = subfig + 1;

