#define DOGMOS_IPC_ITERATIONS 100000
#define DOGMOS_IPC_COMPOUND_ITERATIONS 20000
#define DOGMOS_IPC_DIAGNOSTIC_BYTES 536870912
#define DOGMOS_IPC_CALLBACK_CAPACITY 65536
#define DOGMOS_IPC_BASELINE_TICKS 200
#define DOGMOS_IPC_CALLBACK_TICKS 200
#define DOGMOS_IPC_ALLOCATED_TICKS 200
#define DOGMOS_IPC_RELEASED_TICKS 100

/** Minimal world used to measure the Dogmos process boundary through DreamDaemon's real call_ext path. */
/world
	fps = 10

/world/New()
	. = ..()
	spawn(0)
		run_dogmos_ipc_benchmark()

/** Runs the marker-delimited call_ext latency and process-isolation experiment. */
/proc/run_dogmos_ipc_benchmark()
	if(!dogmos_ipc_benchmark_start("./dogmosd.exe"))
		world.log << "DOGMOS_IPC_ERROR phase=start"
		return

	var/service_pid = dogmos_ipc_benchmark_service_pid()
	world.log << "DOGMOS_IPC_BASELINE service_pid=[service_pid]"
	sleep(DOGMOS_IPC_BASELINE_TICKS)

	var/scalar_total = 0
	var/start_microseconds = dogmos_ipc_benchmark_clock_microseconds()
	for(var/iteration in 1 to DOGMOS_IPC_ITERATIONS)
		scalar_total += dogmos_ipc_benchmark_scalar_get()
	var/elapsed_microseconds = dogmos_ipc_benchmark_clock_microseconds() - start_microseconds
	var/average_microseconds = elapsed_microseconds / DOGMOS_IPC_ITERATIONS
	world.log << "DOGMOS_IPC_LATENCY iterations=[DOGMOS_IPC_ITERATIONS] elapsed_us=[elapsed_microseconds] average_us=[average_microseconds] checksum=[scalar_total]"

	var/lifecycle_total = 0
	start_microseconds = dogmos_ipc_benchmark_clock_microseconds()
	for(var/iteration in 1 to DOGMOS_IPC_COMPOUND_ITERATIONS)
		lifecycle_total += dogmos_ipc_benchmark_lifecycle_batch()
	elapsed_microseconds = dogmos_ipc_benchmark_clock_microseconds() - start_microseconds
	average_microseconds = elapsed_microseconds / DOGMOS_IPC_COMPOUND_ITERATIONS
	world.log << "DOGMOS_IPC_COMPOUND kind=lifecycle_64 iterations=[DOGMOS_IPC_COMPOUND_ITERATIONS] elapsed_us=[elapsed_microseconds] average_us=[average_microseconds] checksum=[lifecycle_total]"

	var/state_seeded = dogmos_ipc_benchmark_state_batch()
	if(state_seeded != 64)
		world.log << "DOGMOS_IPC_ERROR phase=state_seed expected=64 actual=[state_seeded]"
		return
	world.log << "DOGMOS_IPC_STATE_SEEDED mixtures=[state_seeded]"

	var/snapshot_total = 0
	start_microseconds = dogmos_ipc_benchmark_clock_microseconds()
	for(var/iteration in 1 to DOGMOS_IPC_COMPOUND_ITERATIONS)
		snapshot_total += dogmos_ipc_benchmark_snapshot()
	elapsed_microseconds = dogmos_ipc_benchmark_clock_microseconds() - start_microseconds
	average_microseconds = elapsed_microseconds / DOGMOS_IPC_COMPOUND_ITERATIONS
	world.log << "DOGMOS_IPC_COMPOUND kind=snapshot iterations=[DOGMOS_IPC_COMPOUND_ITERATIONS] elapsed_us=[elapsed_microseconds] average_us=[average_microseconds] checksum=[snapshot_total]"

	var/adjacency_total = 0
	start_microseconds = dogmos_ipc_benchmark_clock_microseconds()
	for(var/iteration in 1 to DOGMOS_IPC_COMPOUND_ITERATIONS)
		adjacency_total += dogmos_ipc_benchmark_adjacency_batch()
	elapsed_microseconds = dogmos_ipc_benchmark_clock_microseconds() - start_microseconds
	average_microseconds = elapsed_microseconds / DOGMOS_IPC_COMPOUND_ITERATIONS
	world.log << "DOGMOS_IPC_COMPOUND kind=adjacency_64 iterations=[DOGMOS_IPC_COMPOUND_ITERATIONS] elapsed_us=[elapsed_microseconds] average_us=[average_microseconds] checksum=[adjacency_total]"

	var/stage_total = 0
	start_microseconds = dogmos_ipc_benchmark_clock_microseconds()
	for(var/iteration in 1 to DOGMOS_IPC_COMPOUND_ITERATIONS)
		stage_total += dogmos_ipc_benchmark_simulation_stage()
	elapsed_microseconds = dogmos_ipc_benchmark_clock_microseconds() - start_microseconds
	average_microseconds = elapsed_microseconds / DOGMOS_IPC_COMPOUND_ITERATIONS
	world.log << "DOGMOS_IPC_COMPOUND kind=simulation_stage iterations=[DOGMOS_IPC_COMPOUND_ITERATIONS] elapsed_us=[elapsed_microseconds] average_us=[average_microseconds] checksum=[stage_total]"

	var/callback_accepted = dogmos_ipc_benchmark_callback_enqueue(DOGMOS_IPC_CALLBACK_CAPACITY)
	var/callback_backpressure = dogmos_ipc_benchmark_callback_enqueue(1)
	world.log << "DOGMOS_IPC_CALLBACK_SATURATED service_pid=[service_pid] accepted=[callback_accepted] backpressure=[callback_backpressure]"
	sleep(DOGMOS_IPC_CALLBACK_TICKS)

	var/callback_drained = 0
	var/callback_batches = 0
	var/callback_remaining = 1
	var/callback_high_water = 0
	var/callback_rejected = 0
	var/previous_sequence = 0
	while(callback_remaining)
		var/list/callback_summary = splittext(dogmos_ipc_benchmark_callback_drain(DOGMOS_IPC_CALLBACK_CAPACITY), ",")
		var/callback_returned = text2num(callback_summary[1])
		callback_remaining = text2num(callback_summary[2])
		callback_high_water = text2num(callback_summary[4])
		callback_rejected = text2num(callback_summary[5])
		var/first_sequence = text2num(callback_summary[6])
		var/last_sequence = text2num(callback_summary[7])
		if(callback_returned && previous_sequence && first_sequence != previous_sequence + 1)
			world.log << "DOGMOS_IPC_ERROR phase=callback_sequence expected=[previous_sequence + 1] actual=[first_sequence]"
			return
		if(callback_returned)
			previous_sequence = last_sequence
		callback_drained += callback_returned
		callback_batches++
	world.log << "DOGMOS_IPC_CALLBACK_DRAINED events=[callback_drained] batches=[callback_batches] remaining=[callback_remaining] high_water=[callback_high_water] rejected=[callback_rejected] last_sequence=[previous_sequence]"

	var/allocated_bytes = dogmos_ipc_benchmark_allocate(DOGMOS_IPC_DIAGNOSTIC_BYTES)
	world.log << "DOGMOS_IPC_ALLOCATED service_pid=[service_pid] bytes=[allocated_bytes]"
	sleep(DOGMOS_IPC_ALLOCATED_TICKS)

	dogmos_ipc_benchmark_allocate(0)
	world.log << "DOGMOS_IPC_RELEASED service_pid=[service_pid]"
	sleep(DOGMOS_IPC_RELEASED_TICKS)

	if(!dogmos_ipc_benchmark_stop())
		world.log << "DOGMOS_IPC_ERROR phase=stop"
		return
	world.log << "DOGMOS_IPC_COMPLETE"

#undef DOGMOS_IPC_ITERATIONS
#undef DOGMOS_IPC_COMPOUND_ITERATIONS
#undef DOGMOS_IPC_DIAGNOSTIC_BYTES
#undef DOGMOS_IPC_CALLBACK_CAPACITY
#undef DOGMOS_IPC_BASELINE_TICKS
#undef DOGMOS_IPC_CALLBACK_TICKS
#undef DOGMOS_IPC_ALLOCATED_TICKS
#undef DOGMOS_IPC_RELEASED_TICKS
