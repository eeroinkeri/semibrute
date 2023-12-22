close all

% set x-axis limits
tstart_week = 1;
tend_week = 52;

tstart  = (tstart_week-1)*168+1;
tend    = (tend_week-1)*168+168;

fig = figure;
tiledlayout(3,1)

nexttile
hold on
x   = [1:length(results.demand)];  
y1  = results.P_solar_direct;             
y2  = results.P_grid_balance;
y3  = results.P_discharge;
y4  = results.P_charge_solar;
y5  = results.P_charge_grid;
y6  = -results.P_curt;
y1  = [y1'; y1'];                               
y2  = [y2'; y2'];                               
y3  = [y3'; y3'];
y4  = [y4'; y4'];
y5  = [y5'; y5'];
y6  = [y6'; y6'];
x   = [x; x];                                   
aplot = area(x([2:end end]), [y1(1:end)' y2(1:end)' y3(1:end)' y4(1:end)' y5(1:end)']);         % Create stacked area plot
aplot(1).EdgeAlpha = 0;
aplot(1).FaceColor=[255 255 153]./256; % direct solar use
aplot(2).EdgeAlpha = 0;
aplot(2).FaceColor=[161 91 167]./256; % direct grid power use
aplot(3).EdgeAlpha = 0;
aplot(3).FaceColor=[127 201 127]./256; % battery discharge 
aplot(4).EdgeAlpha = 0;
aplot(4).FaceColor=[253 192 134]./256; % charge with solar
aplot(5).EdgeAlpha = 0;
aplot(5).FaceColor=[56 108 176]./256; % charge with grid

aplot_curt = area(x([2:end end]), y6(1:end)');
aplot_curt(1).EdgeAlpha = 0;
aplot_curt(1).FaceColor=[0.5       0.5       0.5]; % solar curtailment
stairs(results.demand,'-k','linewidth',0.2)
legend('Solar','Grid','Discharge','Charge with solar','Charge with grid','Curtailment','Demand','location','eastoutside')
set(gca,'xlim',[tstart tend])
ylabel('Power (kW)')
xlabel('Time (h)')

nexttile
stairs(results.E_battery)
set(gca,'xlim',[tstart tend])
ylabel({'Battery state'; 'of charge (kWh)'})
xlabel('Time (h)')

nexttile
hold on
stairs(results.cost_ele*100)
stairs(results.cost_ele_spot*100)
set(gca,'xlim',[tstart tend])
ylabel({'Grid electricity'; ' cost (c/kWh)'})
xlabel('Time (h)')
legend('Total','Spot','location','eastoutside')