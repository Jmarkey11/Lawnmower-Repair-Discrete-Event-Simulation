# Lawnmower Repair Discrete Event Simulation

## Overview

This project implements a discrete event simulation in Julia that models a factory production line for building lawnmowers to order. The key focus of the simulation is the primary bottleneck in the process—attaching blades to the motor using a single machine that frequently breaks down. The simulation models key aspects such as order arrivals, construction times, and machine breakdowns to evaluate how these disruptions impact production efficiency.

The simulation addresses the following research questions:
- **RQ1**: How much production time is lost due to machine repairs?  
- **RQ2**: How many lawnmowers experience interruptions in their construction because of breakdowns?  
- **RQ3**: How long do orders wait before completion, and how much would wait times improve with a more reliable machine?

The model incorporates exponential and deterministic distributions to simulate various aspects of the system, such as order inter-arrival times, lawnmower construction times, and machine breakdowns. The simulation results will help the factory owner determine the benefits of purchasing a new machine with fewer breakdowns, focusing on reducing wait times and improving production efficiency.

### Simulation Parameters
- **Simulation Length**: 30000.0
- **Inter-arrival Time**: Exponential(mean = 60.0 minutes)
- **Construction Time**: 25.0 minutes
- **Inter-breakdown Time**: Exponential(mean = 2880.0 minutes)
- **Repair Time**: Exponential(mean = 180.0 minutes)

At the start of the simulation, the first lawnmower arrival is scheduled at time 0.0, and the first machine breakdown occurs at time 150.0. A test harness consisting of 30 simulations is run to ensure that the simulation is representative.

### Repository Files
- **`factory_simulation.jl`**: Contains the functions, structures, and events required to simulate the factory production line.
- **`factory_simulation_run.jl`**: Runs the simulation and outputs entity and state data to CSV files.
- **`Entities.csv`**: Captures entity-specific data (from a single test simulation), such as arrival time, start of service time, service completion time, and whether construction was interrupted by a machine breakdown.
- **`State.csv`**: Logs the state of the system at each event (from a single test simulation), including event type, queue length, and machine status.

## Key Processes

The key processes used in the factory simulation Julia file are:

- **`initialise(P::Parameters)`**: Sets up the initial state of the system, including random number generators and the event queue. It schedules the first `Arrival` (new lawnmower order) and `Breakdown` (machine failure) events, establishing the start of the simulation.
  
- **`move_into_service(S::State, R::RandomNGs)`**: Moves a lawnmower from the waiting queue into active service, calculates its deterministic completion time, and schedules a `Departure` event. This ensures that production continues when the machine is operational and idle.

- **`update!(S::State, R::RandomNGs, E::Arrival)`**: Processes new lawnmower arrivals by adding them to the waiting queue and scheduling the next arrival event. If the machine is available, the arriving lawnmower is immediately moved into service. This models the random nature of lawnmower orders and triggers production as needed. If the lawnmower arrives when the machine is broken down, it is marked as interrupted.

- **`update!(S::State, R::RandomNGs, E::Departure)`**: Handles the completion of lawnmower construction. Once a lawnmower finishes production, it is removed from service, and the system checks if another lawnmower is waiting in the queue. If so, the next one is moved into production, maintaining the flow of orders.

- **`update!(S::State, R::RandomNGs, E::Breakdown)`**: Simulates a machine breakdown event, marking the machine as non-operational and increasing the total downtime. If a lawnmower is in construction, its completion is delayed, and a `RepairCompletion` event is scheduled to resume work after repairs are complete. In addition, the lawnmower being repaired and any lawnmowers in the queue are marked as interrupted.

- **`update!(S::State, R::RandomNGs, E::RepairCompletion)`**: Restores the machine to working order after a repair, schedules the next breakdown, and resumes production if lawnmowers are in the waiting queue. This ensures the system recovers from breakdowns and continues processing orders efficiently.

## Results

To answer the research questions key metrics relating to the average system downtime percentage, average number of interrupted lawnmowers %, and average number of orders completed needed to be gathered for different machine breakdown times. To achieve this the breakdown parameter was tested at different factors ranging from 1.0 - 3.0 at increments of 0.2. This in combination with the test harness of 30 simulations at each breakdown factor provide the results seen in the table below. 

### Testing different Inter-breakdown Times

| Breakdown Factor | Avg Downtime (%) | Avg Interrupted Mowers (%) | Avg Orders Completed |
|------------------|------------------|----------------------------|----------------------|
| 1.0              | 0.06458          | 0.07911                    | 501.77               |
| 1.2              | 0.05509          | 0.06849                    | 496.50               |
| 1.4              | 0.04810          | 0.05572                    | 502.70               |
| 1.6              | 0.04778          | 0.05687                    | 506.37               |
| 1.8              | 0.03989          | 0.04783                    | 500.43               |
| 2.0              | 0.03517          | 0.04408                    | 499.33               |
| 2.2              | 0.03343          | 0.03716                    | 506.43               |
| 2.4              | 0.02981          | 0.03931                    | 499.83               |
| 2.6              | 0.02808          | 0.03225                    | 490.33               |
| 2.8              | 0.02827          | 0.02995                    | 500.23               |
| 3.0              | 0.02723          | 0.03241                    | 495.17               |


- **RQ1:** Based on the test results, the average downtime as a percentage of total time ranges from **0.0646%** (at the original inter-breakdown time, factor 1.0) to **0.0272%** (at the highest inter-breakdown time, factor 3.0). As the inter-breakdown time increases, downtime decreases, but even at the least reliable setting, only a small percentage of time is lost to repairs. This suggests that machine downtime has a minimal effect on overall production time, indicating that repairs do not cause significant production delays.

- **RQ2:** The percentage of interrupted mowers decreases from **7.91%** at the original inter-breakdown time (factor 1.0) to **3.22%** at the highest inter-breakdown time (factor 3.0). As the machine becomes more reliable, fewer lawnmowers are interrupted during construction. Even at the lower reliability levels, less than 8% of mowers face interruptions. This implies that breakdowns do not drastically disrupt the system's ability to process mowers, although improvements in machine reliability do reduce the frequency of interruptions.

- **RQ3:** The number of orders completed remains relatively stable across all reliability factors, ranging from **490.33** to **506.43** orders completed during the simulation period. This indicates that even when the machine breaks down more frequently, the overall throughput of completed orders is not significantly impacted. Thus, machine reliability has only a minor effect on overall order completion times, and improving reliability results in only slight improvements in order processing efficiency.

## Conclusion:

The analysis shows that machine downtime and interruptions do not significantly hinder production in this simulation. The percentage of production time lost to repairs and the percentage of interrupted mowers remain small, even at lower reliability levels. Additionally, the number of completed orders stays relatively consistent across different reliability settings. This suggests that machine breakdowns are not a major bottleneck in the system, and improving reliability leads to only marginal gains in overall production efficiency.

## Technologies Used
The following Julia libraries were utilised in this project
- Julia
- CSV
- Printf
- Dates
- DataStructures
- Distributions
- StableRNGs
