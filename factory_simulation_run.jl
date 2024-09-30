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
    run!(S, R, 1000.0,fid_state, fid_entities)
    close(fid_state)
    close(fid_entities)
end

P = Parameters(1, 60.0, 25.0, 2880.0, 180.0)
write_to_csv(P)