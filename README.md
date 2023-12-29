# semibrute
## semi-brute force method to optimize systems with storage
1. An explicit time-marching solver for energy and mass balance with a one-hour time step. Optimize various problems that have storage, and variable costs and demands as time series. Optimize both operation and capacities
2. For an optimization horizon, for example 24 h, there are 24+1 options to charge storage starting from no charge at all: charge during the cheapest hour, during two of the cheapest hours, during three of the cheapest hours etc.
3. Operation of the system is optimized with the semi-brute force method
4. Unit capacities can be optimized with additional optimization methods, such as genetic algorithms. 

---
### Example week

![example week](figures/week1.png)

### Example year
![example week](figures/year1.png)
