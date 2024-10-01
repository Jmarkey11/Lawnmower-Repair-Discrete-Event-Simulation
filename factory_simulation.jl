using DataStructures
using Distributions
using StableRNGs

abstract type Event end # Creating Event types

mutable struct Arrival <: Event
    id::Int64
    time::Float64
end

mutable struct Departure <: Event
    id::Int64
    time::Float64
end

mutable struct Breakdown <: Event
    id::Int64
    time::Float64
end

mutable struct RepairCompletion <: Event
    id::Int64
    time::Float64
end

mutable struct Entity # To create lawnmower entities
    id::Int64
    arrival_time::Float64
    start_service_time::Union{Float64, Nothing}
    completion_time::Union{Float64, Nothing}
    interrupted::Int64
end

function Entity() # convenience constructor function for entities
    return Entity(
        0,
        0.0,
        nothing,
        nothing,
        0
    )
end

mutable struct State
    time::Float64
    event_queue::PriorityQueue{Event,Float64}
    waiting_queue::Queue{Entity}
    in_service::Union{Entity, Nothing}
    machine_status::Int64
    num_completed::Int64
    num_interrupted::Int64
    total_downtime::Float64
    n_events::Int64
    arrival_n::Int64
    breakdown_n::Int64
end

struct Parameters
    seed::Int64
    mean_interarrival::Float64
    mean_construction_time::Float64
    mean_interbreakdown_time::Float64
    mean_repair_time::Float64
end

struct RandomNGs
    rng::StableRNGs.StableRNG
    interarrival_time::Function
    construction_time::Function
    interbreakdown_time::Function
    repair_time::Function
end

function State() # convenience constructor function for state
    return State(
        0.0,
        PriorityQueue{Event,Float64}(),
        Queue{Entity}(),
        nothing,
        0,
        0,
        0,
        0.0,
        0,
        1,
        1
    )
end

function initialise(P::Parameters) # initialisation
    rng = StableRNG(P.seed) # setting stablerng with seed value
    R = RandomNGs(
        rng, 
        () -> rand(rng, Exponential(P.mean_interarrival)),
        () -> P.mean_construction_time,
        () -> rand(rng, Exponential(P.mean_interbreakdown_time)),
        () -> rand(rng, Exponential(P.mean_repair_time))
    )

    t0 = 0.0 # initial arrival time
    t1 = 150.0 # initial breakdown time

    system = State()
    initial_arrival_event = Arrival(system.arrival_n, t0)
    enqueue!(system.event_queue, initial_arrival_event, initial_arrival_event.time)
    breakdown_event = Breakdown(system.breakdown_n, t1)
    enqueue!(system.event_queue, breakdown_event, breakdown_event.time)
    return (system, R)
end

function move_into_service(S::State, R::RandomNGs) # Function to move lawnmower into service. Created for use in arrival, departure, and repair completion functions
    entity = dequeue!(S.waiting_queue) # Removing first lawnmower in waiting room queue as per FIFO
    entity.start_service_time = S.time
    entity.completion_time = entity.start_service_time + R.construction_time() # Departure Time is deterministic
    departure_event = Departure(entity.id, entity.completion_time) # creating departure event
    S.in_service = entity # moving entity into service
    enqueue!(S.event_queue, departure_event, entity.completion_time) # adding departure event to event queue
end

function update!(S::State, R::RandomNGs, E::Arrival)
    S.time = E.time
    new_entity = Entity()  # Creating new lawnmower entity
    new_entity.id = S.arrival_n
    new_entity.arrival_time = E.time

    if S.machine_status == 1 # If the machine is broken, mark the new entity as interrupted
        new_entity.interrupted = 1
        S.num_interrupted += 1
    end

    enqueue!(S.waiting_queue, new_entity)  # adding lawnmower entity to waiting queue
    S.arrival_n += 1
    S.n_events += 1
    next_arrival_time = E.time + R.interarrival_time()  # determining next arrival time
    arrival_event = Arrival(S.arrival_n, next_arrival_time)  # creating next arrival event
    enqueue!(S.event_queue, arrival_event, next_arrival_time)  # adding arrival event to event queue

    if S.machine_status == 0 && S.in_service === nothing # Move into service if machine is operational and no lawnmower entity is in service
        move_into_service(S, R)
    end
end

function update!(S::State, R::RandomNGs, E::Departure)
    S.time = E.time
    S.in_service = nothing  # remove lawnmower entity form service
    S.num_completed += 1
    S.n_events += 1

    if !isempty(S.waiting_queue) # if waiting room is not empty move next lawnmower entity into service
        move_into_service(S, R)
    end
end

function update!(S::State, R::RandomNGs, E::Breakdown)
    S.time = E.time
    S.machine_status = 1  # changing status to broken
    repair_duration = R.repair_time()  # getting repair duration
    S.total_downtime += repair_duration 
    S.n_events += 1

    if S.in_service !== nothing # If a lawnmower was in service during the breakdown
        S.num_interrupted += 1
        S.in_service.completion_time += repair_duration  # delay completion time by repair duration
        S.in_service.interrupted = 1
        for (event, _) in S.event_queue # Adjusting the departure event in the event queue
            if isa(event, Departure)
                other_events = [(ev, time) for (ev, time) in S.event_queue if ev !== event]  # get all other events
                S.event_queue = PriorityQueue{Event, Float64}()  # clear and reinitialize the event queue
                for (ev, time) in other_events
                    enqueue!(S.event_queue, ev, time)  # re-enqueue other events
                end
                enqueue!(S.event_queue, Departure(event.id, S.in_service.completion_time), S.in_service.completion_time)  # enqueue the delayed departure
                break
            end
        end
    end

    num_waiting = length(S.waiting_queue) # Mark all entities in the waiting queue as interrupted and update the count
    for entity in S.waiting_queue
        entity.interrupted = 1
    end
    S.num_interrupted += num_waiting
    
    repair_event = RepairCompletion(S.breakdown_n, S.time + repair_duration)  # creating repair completion event
    enqueue!(S.event_queue, repair_event, S.time + repair_duration)  # adding repair completion event to event queue
    S.breakdown_n += 1
end

function update!(S::State, R::RandomNGs, E::RepairCompletion)
    S.time = E.time
    S.machine_status = 0 # making machine status back to being operational
    S.n_events +=1
    breakdown_time = S.time + R.interbreakdown_time() # getting time for next breakdown event
    next_breakdown_event = Breakdown(S.breakdown_n, breakdown_time) # creating next breakdown event
    enqueue!(S.event_queue, next_breakdown_event, breakdown_time) # adding breakdown event to event queue

    if S.in_service == nothing && !isempty(S.waiting_queue) # if machine wan't previously in service and there is now entities in waiting room, move into service
        move_into_service(S, R)
    end
end