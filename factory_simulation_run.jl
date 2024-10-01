include("factory_simulation.jl")
using CSV
using Printf
using Dates

function run!(S::State, R::RandomNGs, T::Float64, fid_state::IO, fid_entities::IO)
    while S.time < T
        if isempty(S.event_queue)
            break
        end

        event = dequeue!(S.event_queue)
        temp = 0

        if S.in_service !== nothing
            temp = 1
        end
        
        if isa(event, Departure) && S.in_service !== nothing
            @printf(fid_entities, "%d,%.5f,%.5f,%.5f, %d\n",
                S.in_service.id,
                S.in_service.arrival_time,
                S.in_service.start_service_time,
                S.in_service.completion_time,
                S.in_service.interrupted
            )
        end

        events = S.n_events
        eq = length(S.event_queue)
        wq = length(S.waiting_queue)
        ms = S.machine_status

        customer = update!(S, R, event)

        @printf(fid_state, "%.3f,%d,%s,%d,%d,%d,%d\n",
            S.time,
            events,
            typeof(event),
            eq,
            wq,
            temp,
            ms)
    end
end

function write_to_csv(P::Parameters) # function to write the files as csv
    (S, R) = initialise(P)
    fid_state = open("State.csv", "w")
    fid_entities = open("Entities.csv", "w")
    current_time = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    write(fid_state, "File created on: $current_time\nFile created on code in factory_simulation.jl\nParameters$P\n")
    write(fid_entities, "File created on: $current_time\nFile created on code in factory_simulation.jl\nParameters$P\n")
    write(fid_state, "time,event_id,event_type,length_event_list,length_queue,in_service,machine_status\n")
    write(fid_entities, "id,arrival_time,start_service_time,completion_time,interrupted\n")
    run!(S, R, 30000.0,fid_state, fid_entities)
    close(fid_state)
    close(fid_entities)
end

P = Parameters(1, 60.0, 25.0, 2880.0, 180.0)
write_to_csv(P)

function run!(S::State, R::RandomNGs, T::Float64) # second run function to just get the metrics
    while S.time < T
        if isempty(S.event_queue)
            break
        end

        event = dequeue!(S.event_queue)
        update!(S, R, event)# Update the state based on the event type
    end

    return (S.total_downtime, S.num_interrupted, S.num_completed) # Return the necessary metrics
end


function test_harness(P::Parameters, num_runs::Int, T::Float64)
    interbreakdown_factors = 0.6:0.2:3.0  # Test from 100% to 200% of the original value, in increments of 20%

    println("Testing different Inter-breakdown Time values with random seeds:")
    println("-------------------------------------------------------------")
    println("Factor | Avg Downtime (%) | Avg Interrupted Mowers (%) | Avg Orders Completed")
    println("-------------------------------------------------------------")

    for factor in interbreakdown_factors # Loop over different factors of Inter-breakdown Time
        total_downtime_all_runs = 0.0
        total_interrupted_mowers_all_runs = 0.0
        total_orders_completed_all_runs = 0.0

        for i in 1:num_runs
            random_seed = rand(1:10^6)
            modified_P = Parameters(random_seed, P.mean_interarrival, P.mean_construction_time, P.mean_interbreakdown_time * factor, P.mean_repair_time)
            (S, R) = initialise(modified_P)
            (downtime, interrupted_mowers, completed_orders) = run!(S, R, T) # Run the simulation (collecting downtime, interrupted, and completed metrics)

            total_downtime_all_runs += downtime / T  # Downtime per unit time
            total_interrupted_mowers_all_runs += interrupted_mowers / completed_orders  # Interrupted per completed
            total_orders_completed_all_runs += completed_orders
        end

        avg_downtime = total_downtime_all_runs / num_runs
        avg_interrupted_mowers = total_interrupted_mowers_all_runs / num_runs
        avg_orders_completed = total_orders_completed_all_runs / num_runs

        # Print the results for this factor
        @printf("%.1f     | %.5f              | %.5f                       | %.2f\n", factor, avg_downtime, avg_interrupted_mowers, avg_orders_completed)
    end
end

# Usage Example:
P = Parameters(1, 60.0, 25.0, 2880.0, 180.0)  # Initial parameters
test_harness(P, 30, 30000.0)  # Test with 30 runs per factor and 30,000 units of time