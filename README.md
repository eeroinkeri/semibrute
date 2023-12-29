# semibrute
## semi-brute force method to optimize household solar PV and battery capacity
- An explicit time-marching solver for energy balance with a one-hour time step. Optimize both operation and capacities.
- Operation of the system is optimized with the semi-brute force method
   - For an optimization horizon, for example 24 h, there are 24+1 options to charge storage starting from no charge at all: charge during the cheapest hour, during two of the cheapest hours, during three of the cheapest hours etc.
   - The objective is to minimize the levelized cost of electricity
- Unit capacities are optimized with additional optimization methods, such as genetic algorithm in this case example.

## How to run the model? (in Matlab)
1. Modify settings and input data in `run_model_003_solar_PV_battery.m` and run it
   - Input time series are used for solar power profile, electricity market price, and household electricity demand
   - There is a possibility to either optimize some variables (battery capacity, battery power, and solar capacity) or to use fixed values
3. `fun_003_solar_PV_battery.m` is called and does the main work
4. Plot results with `plot_003.m`

---
### Example week

![example week](figures/week1.png)

### Example year
![example week](figures/year1.png)
