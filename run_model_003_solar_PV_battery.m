clear all
close all
   
% options how to simulate
%   0 = no capacity optimization, just use fixed capacities
%   1 = optimize capacities
run_mode = 1;

%% Investment costs

% General
interest_rate           = 0.05;     % [-]
lifetime                = 20;       % [a]

% Battery https://atb.nrel.gov/electricity/2021/residential_battery_storage
% Convert 1.0 USD -> 0.92 EUR
capex_battery_power     = 1555;     % [€/kW]        
capex_battery_energy    = 326;      % [€/kWh]        
capex_battery_base      = 5503;     % [€]

% Solar PV
capex_pv                = 1200;     % [€/kW] 

%% Electricity

% [kWh/a] Demand per year
demand_total    = 15000; 

% Costs
cost_tax        = 2.8/100;      % €/kWh         electricity tax, class I. For class II, tax is 0.07812 c/kWh
cost_basic      = 30;           % €/month       basic cost per month
cost_trans_day  = 3/100;        % €/kWh         transmission cost during the night
cost_trans_nig  = 2/100;        % €/MWh         transmission cost during the day
cost_power      = 1/100;        % €/kW/month    cost of power connection

% Sensitivity analysis parameters (one for-loop for each, or then provide distribution for all with N values)
cost_ele_factor_all     = [1:6];   % [-]       factor for multiplication 

%% Structures and data

% Initialize structures to store data. 
RESULTS = struct;
INPUTS = struct;

% generate load data
demand_norm         = load('data/electricity_demand.mat');
demand_cap_factor   = sum(demand_norm.electricity_demand);
demand_peak         = demand_total/demand_cap_factor;
demand              = demand_peak*demand_norm.electricity_demand;

% solar PV production
solar_pv            = load('data/solar_pv.mat');                
solar_pv            = solar_pv.solar_pv;


%% Go through all parameter values

% number of case
n = 1; 

% loop all
for cost_ele_factor = cost_ele_factor_all

% Electricity price
cost_ele            = load('data/electricity_price.mat');
cost_ele            = cost_ele.electricity_price/1000;      % €/MWh -> €/kWh
cost_ele            = cost_ele*cost_ele_factor;             % modify electricity price

%% Save inputs to structure

% For sensitivity analysis, use for-loops for some parameters (capex of components, interest rate, ...) 
% and assign to array of structures (do same for RESULTS)
%       -> INPUTS(1), INPUTS(2), INPUTS(3), ...


INPUTS(n).capex_battery_power  = capex_battery_power;
INPUTS(n).capex_battery_energy = capex_battery_energy;
INPUTS(n).capex_battery_base   = capex_battery_base;
INPUTS(n).capex_pv             = capex_pv;
INPUTS(n).demand               = demand;
INPUTS(n).solar_pv             = solar_pv;
INPUTS(n).cost_ele             = cost_ele;
INPUTS(n).run_mode             = run_mode;
INPUTS(n).interest_rate        = interest_rate;
INPUTS(n).lifetime             = lifetime;
INPUTS(n).cost_tax             = cost_tax;
INPUTS(n).cost_basic           = cost_basic;
INPUTS(n).cost_trans_day       = cost_trans_day;
INPUTS(n).cost_trans_nig       = cost_trans_nig;
INPUTS(n).cost_power           = cost_power;


%% Simulate

% Don't optimize capacities -> use fixed capacities
if run_mode == 0

    % give capacities
    E_battery_max   = 1e-6;    % [kWh
    P_battery_max   = 1e-6;    % [kW]]
    solar_pv_max    = 1e-6;    % [kW]
    [~,results] = fun_003_solar_PV_battery(E_battery_max, P_battery_max, solar_pv_max, INPUTS(n));

    % show some results
    disp([' '])
    disp(['Peak demand: ' num2str(round(demand_peak*10)/10) ' kWh'])
    disp(['Average demand: ' num2str(round(mean(demand)*10)/10) ' kWh'])
    disp(['Battery capacity: ' num2str(round(E_battery_max*10)/10) ' kWh'])
    disp(['Battery power: ' num2str(round(P_battery_max*10)/10) ' kW'])
    disp(['Solar capacity: ' num2str(round(solar_pv_max*10)/10) ' kWh'])
    disp(['Cost of electricity: ' num2str(round(results.lcoe*1000)/10) ' c/kWh'])
    disp(['Average spot price: ' num2str(round(mean(results.cost_ele)*1000)/10) ' c/kWh'])


% Optimize capacities
elseif run_mode == 1
    
    % number of variables 
    nvars = 3;

    % Min values
    minbounds = [
        1e-5        % [kWh]     battery energy capacity    
        1e-5        % [kW]      battery max power 
        1e-5        % [kW]      solar capacity
    ];  

    % Max values
    maxbounds = [
        100         % [kWh]     battery energy capacity   
        100         % [kW]      battery max power
        100         % [kW]      solar capacity
    ];

    % optimize with genetic algorithm
    options = optimoptions('ga','FunctionTolerance',1e-4,'MaxStallGenerations',10,'PlotFcn', {@gaplotbestf, @gaplotbestindiv});
    [x,~] = ga(@(x) fun_003_solar_PV_battery(x(1),x(2),x(3),INPUTS(n)),nvars,[],[],[],[],minbounds,maxbounds,[],options); % give number of variables, min and max values

    % change mode and rerun for results and timeseries
    INPUTS(n).run_mode = 0;
    [~,results] = fun_003_solar_PV_battery(x(1),x(2),x(3), INPUTS(n));
    
    % show some results
    disp([' '])
    disp(['Peak demand: ' num2str(round(demand_peak*10)/10) ' kW'])
    disp(['Average demand: ' num2str(round(mean(demand)*10)/10) ' kW'])
    disp(['Battery capacity: ' num2str(round(x(1)*10)/10) ' kWh'])
    disp(['Battery power: ' num2str(round(x(2)*10)/10) ' kW'])
    disp(['Solar capacity: ' num2str(round(x(3)*10)/10) ' kWh'])
    disp(['Levelized cost of electricity: ' num2str(round(results.lcoe*1000)/10) ' c/kWh'])
    disp(['Average electricity price: ' num2str(round(mean(results.cost_ele)*1000)/10) ' c/kWh'])

    % Add results to structure (post-process afterwards with INPUTS)
    RESULTS(n).lcoe = results.lcoe;
    
end

% increase case index 
n = n + 1;
end




