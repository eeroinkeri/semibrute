function [lcoe,results] = fun_003_solar_PV_battery(E_battery_max, P_battery_max, P_pv_max, INPUTS)

% Get inputs
capex_battery_power     = INPUTS.capex_battery_power;
capex_battery_energy    = INPUTS.capex_battery_energy;
capex_battery_base      = INPUTS.capex_battery_base;
capex_pv                = INPUTS.capex_pv;
demand                  = INPUTS.demand;
P_solar                 = INPUTS.solar_pv*P_pv_max;
cost_ele                = INPUTS.cost_ele;
interest_rate           = INPUTS.interest_rate;
cost_tax                = INPUTS.cost_tax;
cost_basic              = INPUTS.cost_basic;
cost_trans_day          = INPUTS.cost_trans_day;   
cost_trans_nig          = INPUTS.cost_trans_nig;   
cost_power              = INPUTS.cost_power;

% Simulation parameters
sim_time    = 52*168;                       % simulation time in hours
opt_time    = 24;                           % optimization time period: n*12h ->  24, 36, 48, 60, 72... (defaulf 24 h)
opt_n       = floor(sim_time/opt_time)-1;   % find how many sets of full optimization periods ()
sim_time    = opt_n*opt_time;               % simulation time
idh         = [1:opt_time]';                % all ids for time steps
roll_time   = opt_time;                     % [h] Time step between starting point of new optimization period


% Initialize inputs and results structures
results  = struct;

% Add tax and transmission cost to electricity price
cost_ele_spot = cost_ele;
for i = 1:sim_time
    if mod(i,24) < 7 
        % night
        cost_ele(i) = cost_ele(i) + cost_trans_nig + cost_tax;
    elseif mod(i,24) < 23
        % day
        cost_ele(i) = cost_ele(i) + cost_trans_day  + cost_tax;
    else
        % night
        cost_ele(i) = cost_ele(i) + cost_trans_nig  + cost_tax;
    end
end

% cut data to fit the sim time
cost_ele        = cost_ele(1:sim_time + opt_time - roll_time);
cost_ele_spot   = cost_ele_spot(1:sim_time + opt_time - roll_time);
demand          = demand(1:sim_time + opt_time - roll_time); 

% Initialize battery
E_battery_init  = 0;

% initialize arrays for annual optimum
P_charge_opt        = [];
P_curt_opt          = [];
P_solar_direct_opt  = [];
P_charge_grid_opt   = [];
P_charge_solar_opt  = [];
P_discharge_opt     = [];
E_battery_opt       = [];
P_grid_balance_opt  = [];

% loop through the year by rolling time
for i = 1:sim_time/roll_time

%     % Show variables
%     if mod(i*roll_time,168) == 0
%         clc
%         disp(['Heat storage: ' num2str(TES_max) ' MWh'])
%         disp(['Compressor: ' num2str(P_comp_max) ' MW'])
%         disp(['Electrical heater: ' num2str(P_ele_max) ' MW'])
%         disp(['CO2 emission price: ' num2str(price_CO2) ' €/ton'])
%         disp(['Wood price: ' num2str(price_KPA) ' €/MWh'])
%         disp(['Oil price: ' num2str(price_POK) ' €/MWh'])
% 
%         % show general data
%         disp(['Week: ' num2str(round(i*roll_time/168)) '/' num2str(round(sim_time/168))])
%         disp(['Computational time, total: ' num2str(round(sum(time_all)/60*100)/100) ' min'])
%         disp(['Computational time, last: ' num2str(round(time_all(end)*100)/100) ' sec'])
%         disp(['Estimated time left: ' num2str(round(mean(time_all)*(prod(MC_n)-var)/60*100)/100) ' min'])
%     end
    
    
    % spot prices and some other useful stuff for the optimization period
    spot_set    = cost_ele((i-1)*roll_time+1:(i-1)*roll_time+opt_time);
    demand_set  = demand((i-1)*roll_time+1:(i-1)*roll_time+opt_time);
    spot_sort   = [sort(spot_set); 1e9];
    spot_sort0  = [sort(spot_set)];
    [~,id_sort] = sort(spot_set,'descend');  
    
    % initiate arrays
    n_try_limits    = opt_time+1;
    E_battery       = zeros(opt_time,n_try_limits);
    P_grid_balance          = zeros(opt_time,n_try_limits);
    P_charge_grid   = zeros(opt_time,n_try_limits);
    P_charge_solar  = zeros(opt_time,n_try_limits);
    P_charge        = zeros(opt_time,n_try_limits);
    P_discharge     = zeros(opt_time,n_try_limits);
    
    % initialize j column 
    j = 0;

    % Charge heat storage with increasing cost threshold (max power)        
    while j < n_try_limits    
        % increase column index -> next price limit to charge
        j = j + 1;

        % loop through optmization period (wall time 1 -> 24 h)
        h_discharge = zeros(opt_time,1);
        for h = 1:opt_time 
        
            % hour of the whole year: 1...8760
            ih = (i-1)*roll_time+h;         

            % spot limits to heat with electricity
            spot_limit_full = spot_sort(j); % full power
            
            % Energy in battery
            if h > 1
                E_battery_previous = E_battery(h-1,j);
            elseif i > 1 && h == 1 
                E_battery_previous = E_battery_opt(ih-1);
            else
                E_battery_previous = E_battery_init;
            end
            

            %% free space in TES during this time step (MWh)
            E_battery_free = (E_battery_max-E_battery_previous) + demand(ih) - P_solar(ih);
            E_battery_free = max([E_battery_free 0]); % cannot be negative

            % Storage limitation. Do not produce more than is needed
            % during the rest of the optimization period.
            E_rest = sum(demand(ih:ih+(opt_time-h))) - sum(P_solar(ih:ih+(opt_time-h)));
            E_rest = max([E_rest 0]); % cannot be negative

            % choose the limit
            E_battery_limit = min([E_battery_free E_rest]);

            
            %% Charge or not

            % charge, electricity price is below the threshold
            if spot_set(h) < spot_limit_full 
                
                % Storage is not limiting 
                if P_battery_max < E_battery_limit
                    P_charge_grid(h,j)  = P_battery_max;

                % Storage is limiting
                else
                    P_charge_grid(h,j) = E_battery_limit;
                end

            % don't charge
            else
                P_charge_grid(h,j) = 0;
            end

            %% Discharge or not
            
            % For how many of the most expensive hours TES can provide heat?
            n_discharge = floor((E_battery_previous + P_charge_grid(h,j) + P_solar(ih))/demand_set(h))+1;                           % less accurate but fast
            %n_discharge = floor(E_TES/mean(q_DH_set(h:h+(opt_time-h))))+1;      % more accurate but slow

            % logical 1 or 0, allow discharge or not
            if n_discharge >= 1 && n_discharge <= opt_time
                h_discharge(idh(id_sort(1:n_discharge))) = 1;       
            elseif n_discharge > opt_time
                h_discharge(:) = 1;
            end 

            % discharge is allowed
            if h_discharge(h) == 1

                % Try to cover the demand
                P_discharge(h,j) = demand(ih) - (P_charge_grid(h,j) + P_solar(ih));
                if P_discharge(h,j) < 0
                    P_discharge(h,j) = 0;
                end

                % limit by storage state of charge
                if P_discharge(h,j) > E_battery_previous
                    P_discharge(h,j) = E_battery_previous;

                % limit by the maximum power output
                elseif P_discharge(h,j) > P_battery_max
                    P_discharge(h,j) = P_battery_max;
                end

            % discharge not allowed
            else
                P_discharge(h,j) = 0;
            end

            %% Is there more solar power than demand?
            P_charge_solar(h,j) = P_solar(ih) - demand(ih);

            % cannot be negative
            if P_charge_solar(h,j) < 0
                P_charge_solar(h,j) = 0;
            end

            % check upper limit
            if P_charge_solar(h,j) > P_battery_max
                P_curt_charge = P_charge_solar(h,j) - P_battery_max;
                P_charge_solar(h,j) = P_battery_max;
            else
                P_curt_charge = 0;
            end

            % cannot exceed empty capacity
            E_battery_free_solar = (E_battery_max-E_battery_previous);
            E_battery_free_solar = max([E_battery_free_solar 0]); % cannot be negative
            if P_charge_solar(h,j) > E_battery_free_solar
                P_charge_solar(h,j) = E_battery_free_solar;
            end

            %% Check curtailment of solar

            % less solar than consumption -> no curtailment
            if P_solar(ih) < demand(ih)
                P_curt(h,j) = 0;
                P_solar_used(h,j) = P_solar(ih);

            % surplus solar -> no space in battery -> curtailment
            else            
                P_curt(h,j) = P_solar(ih) - demand(ih) - P_charge_solar(h,j);
                P_curt(h,j) = max([P_curt(h,j) 0]); % cannot be negative
                P_solar_used(h,j) = P_solar(ih) - P_curt(h,j);
            end

            % direcetly used solar
            P_solar_direct(h,j) = P_solar(ih) - P_charge_solar(h,j) - P_curt(h,j);


            %% Check if additional grid electricity is needed
            P_net(h,j) = P_charge_grid(h,j) ...
                       + P_discharge(h,j) ... 
                       + P_solar(ih) ...
                       - demand(ih); 


            %% More power is needed
            if P_net(h,j) < 0
                P_grid_balance(h,j) = abs(P_net(h,j));
            else
                P_grid_balance(h,j) = 0;
            end
            
            %% correct grid direct use and charge. Charge only if over demand
            if P_grid_balance(h,j) + P_solar_direct(h,j) + P_discharge(h,j) < demand(ih) && P_charge_grid(h,j) > 0
                real_charge_grid = P_charge_grid(h,j) + P_solar_direct(h,j) + P_discharge(h,j) + P_grid_balance(h,j) - demand(ih);
                non_charge_grid = demand(ih) - P_solar_direct(h,j) - P_grid_balance(h,j) - P_discharge(h,j);
                P_charge_grid(h,j) = real_charge_grid;
                P_grid_balance(h,j) = P_grid_balance(h,j) + non_charge_grid;
            end



            %% update battery
            P_charge(h,j) = + P_charge_grid(h,j) + P_charge_solar(h,j) - P_discharge(h,j);
            E_battery(h,j)  = E_battery_previous + P_charge(h,j);
 
            % Prevent overcharge, however it should not be possible
            if E_battery(h,j) > E_battery_max
                E_battery(h,j) = E_battery_max;
            end

            
            % Check energy balance
            err_check   = abs((...
                        + P_solar(ih) ...
                        + P_grid_balance(h,j) ...
                        + P_charge_grid(h,j) ...
                        - P_curt(h,j) ...
                        - P_charge(h,j) ...
                        - demand(ih))./demand(ih)*100);
            if err_check > 0.1 
                warning('Check energy balance');    % or add breakpoint here 
            end
            
            
        end        
    end

    % calculate operational cost for the optimization period
    opex_set    = sum(spot_set.*(P_charge_grid + P_grid_balance), 1);

    % find minimum cost and price threshold
    [~, id_min] = min(opex_set(:,1:j));
  
    % optimum j-column with id_min
    P_charge_opt        = [P_charge_opt(1:(i-1)*roll_time,:); P_charge(:,id_min)]; % roll
    P_curt_opt        = [P_curt_opt(1:(i-1)*roll_time,:); P_curt(:,id_min)]; % roll
    P_solar_direct_opt        = [P_solar_direct_opt(1:(i-1)*roll_time,:); P_solar_direct(:,id_min)]; % roll
    P_charge_grid_opt   = [P_charge_grid_opt(1:(i-1)*roll_time,:); P_charge_grid(:,id_min)]; % roll
    P_charge_solar_opt   = [P_charge_solar_opt(1:(i-1)*roll_time,:); P_charge_solar(:,id_min)]; % roll
    P_grid_balance_opt          = [P_grid_balance_opt(1:(i-1)*roll_time,:); P_grid_balance(:,id_min)]; % roll
    P_discharge_opt     = [P_discharge_opt(1:(i-1)*roll_time,:); P_discharge(:,id_min)]; % roll
    E_battery_opt       = [E_battery_opt(1:(i-1)*roll_time,:); E_battery(:,id_min)]; % roll
   
end

% total consumed electricity
sum_cons_electricity   = sum(demand); % MWh

% operational cost of CO2 and electrolyser
opex        = (P_grid_balance_opt + P_charge_grid_opt).*cost_ele(1:length(P_grid_balance_opt));
opex_sum    = sum(opex);

% cost fixed and power
cost_pow = 12*cost_power*P_battery_max/1e3 + 12*cost_basic;

% levelied cost
lifetime = 20;
crf = interest_rate*(1+interest_rate)^lifetime/((1+interest_rate)^lifetime-1);
capex_solar     = capex_pv*P_pv_max;
capex_battery   = capex_battery_power*P_battery_max + capex_battery_energy*E_battery_max + capex_battery_base;

% levelized cost of electricity
lcoe = (crf*(capex_solar + capex_battery) + opex_sum + cost_pow)/sum_cons_electricity;

if E_battery_max < 0
    lcoe = lcoe - E_battery_max;
end
if P_battery_max < 0
    lcoe = lcoe - P_battery_max;
end 
if P_pv_max < 0
    lcoe = lcoe - P_pv_max;
end

%% gather results
results.lcoe = lcoe;

% Save timeseries only for the optimum case (avoid huge pile of data)
if INPUTS.run_mode == 0
    results.P_solar_direct  = P_solar_direct_opt;
    results.P_grid_balance  = P_grid_balance_opt;
    results.P_discharge     = P_discharge_opt;
    results.P_charge_solar  = P_charge_solar_opt;
    results.P_charge_grid   = P_charge_grid_opt;
    results.P_curt          = P_curt_opt;
    results.cost_ele        = cost_ele;
    results.cost_ele_spot   = cost_ele_spot;
    results.E_battery       = E_battery_opt;
    results.demand          = demand;
end


end


