#define DOGMOS_TEST_PROCESS_METRICS_WORDS 28
#define DOGMOS_TEST_PROCESS_WORD_BASE 65536

/** Verifies Dogmos process snapshots reject malformed words and keep process roles separate. */
/datum/unit_test/dogmos_kennel_process_metrics
	/// Original Kennel slow-mode setting restored after the test.
	var/original_slow_mode

/** Returns one hand-checked fixed-width process-metrics fixture. */
/datum/unit_test/dogmos_kennel_process_metrics/proc/valid_fixture()
	return list(
		1, 0,
		7, 0,
		3, 0,
		0, 0,
		1, 2, 3, 4,
		5, 6, 7, 8,
		9, 10, 11, 12,
		13, 14, 15, 16,
		17, 18, 19, 20,
	)

/datum/unit_test/dogmos_kennel_process_metrics/Run()
	var/list/valid_words = valid_fixture()
	var/list/decoded = SSdogmos.decode_process_metrics(valid_words)
	TEST_ASSERT_NOTNULL(decoded, "Dogmos rejected a valid fixed-width process snapshot.")
	TEST_ASSERT_EQUAL(length(decoded), 2, "Dogmos process telemetry exposed a combined or unexpected role record.")
	TEST_ASSERT_NULL(decoded["combined"], "Dogmos process telemetry exposed a combined process total.")

	var/list/dreamdaemon = decoded["dreamdaemon"]
	TEST_ASSERT_EQUAL(dreamdaemon["private_bytes"], 1 + 2 * DOGMOS_TEST_PROCESS_WORD_BASE + 3 * DOGMOS_TEST_PROCESS_WORD_BASE ** 2 + 4 * DOGMOS_TEST_PROCESS_WORD_BASE ** 3, "Dogmos changed DreamDaemon private-byte word ordering.")
	TEST_ASSERT_EQUAL(dreamdaemon["virtual_bytes"], 5 + 6 * DOGMOS_TEST_PROCESS_WORD_BASE + 7 * DOGMOS_TEST_PROCESS_WORD_BASE ** 2 + 8 * DOGMOS_TEST_PROCESS_WORD_BASE ** 3, "Dogmos changed DreamDaemon virtual-byte word ordering.")
	TEST_ASSERT_EQUAL(dreamdaemon["working_set_bytes"], 9 + 10 * DOGMOS_TEST_PROCESS_WORD_BASE + 11 * DOGMOS_TEST_PROCESS_WORD_BASE ** 2 + 12 * DOGMOS_TEST_PROCESS_WORD_BASE ** 3, "Dogmos changed DreamDaemon working-set word ordering.")
	TEST_ASSERT_EQUAL(dreamdaemon["available"], TRUE, "Dogmos did not mark a complete DreamDaemon sample available.")

	var/list/dogmosd = decoded["dogmosd"]
	TEST_ASSERT_EQUAL(dogmosd["rss_bytes"], 13 + 14 * DOGMOS_TEST_PROCESS_WORD_BASE + 15 * DOGMOS_TEST_PROCESS_WORD_BASE ** 2 + 16 * DOGMOS_TEST_PROCESS_WORD_BASE ** 3, "Dogmos changed dogmosd RSS word ordering.")
	TEST_ASSERT_EQUAL(dogmosd["cpu_total_milliseconds"], 17 + 18 * DOGMOS_TEST_PROCESS_WORD_BASE + 19 * DOGMOS_TEST_PROCESS_WORD_BASE ** 2 + 20 * DOGMOS_TEST_PROCESS_WORD_BASE ** 3, "Dogmos changed dogmosd CPU word ordering.")
	TEST_ASSERT_EQUAL(dogmosd["available"], TRUE, "Dogmos did not mark a complete dogmosd sample available.")

	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics("not a list"), "Dogmos accepted a non-list process snapshot.")
	var/list/short_words = valid_words.Copy()
	short_words.Cut(DOGMOS_TEST_PROCESS_METRICS_WORDS, DOGMOS_TEST_PROCESS_METRICS_WORDS + 1)
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(short_words), "Dogmos accepted a 27-word process snapshot.")
	var/list/long_words = valid_words.Copy()
	long_words += 0
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(long_words), "Dogmos accepted a 29-word process snapshot.")

	var/list/nonnumeric_words = valid_words.Copy()
	nonnumeric_words[9] = "invalid"
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(nonnumeric_words), "Dogmos accepted a nonnumeric process word.")
	var/list/fractional_words = valid_words.Copy()
	fractional_words[9] = 1.5
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(fractional_words), "Dogmos accepted a fractional process word.")
	var/list/negative_words = valid_words.Copy()
	negative_words[9] = -1
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(negative_words), "Dogmos accepted a negative process word.")
	var/list/oversized_words = valid_words.Copy()
	oversized_words[9] = 65536
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(oversized_words), "Dogmos accepted a process word above 65535.")

	var/list/wrong_layout = valid_words.Copy()
	wrong_layout[1] = 2
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(wrong_layout), "Dogmos accepted an unknown process-metrics layout.")
	var/list/unknown_host_flags = valid_words.Copy()
	unknown_host_flags[3] = 8
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(unknown_host_flags), "Dogmos accepted an unknown DreamDaemon availability flag.")
	var/list/unknown_service_flags = valid_words.Copy()
	unknown_service_flags[5] = 4
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(unknown_service_flags), "Dogmos accepted an unknown dogmosd availability flag.")
	var/list/nonzero_reserved = valid_words.Copy()
	nonzero_reserved[7] = 1
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(nonzero_reserved), "Dogmos accepted nonzero reserved process-metrics words.")

	var/list/unavailable_host_value = valid_words.Copy()
	unavailable_host_value[3] = 6
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(unavailable_host_value), "Dogmos accepted nonzero unavailable DreamDaemon private bytes.")
	var/list/unavailable_service_value = valid_words.Copy()
	unavailable_service_value[5] = 2
	TEST_ASSERT_NULL(SSdogmos.decode_process_metrics(unavailable_service_value), "Dogmos accepted nonzero unavailable dogmosd RSS bytes.")

	var/list/partial_words = valid_words.Copy()
	partial_words[3] = 6
	partial_words[9] = 0
	partial_words[10] = 0
	partial_words[11] = 0
	partial_words[12] = 0
	partial_words[5] = 2
	partial_words[21] = 0
	partial_words[22] = 0
	partial_words[23] = 0
	partial_words[24] = 0
	var/list/partial = SSdogmos.decode_process_metrics(partial_words)
	TEST_ASSERT_NOTNULL(partial, "Dogmos rejected canonical unavailable process slots.")
	TEST_ASSERT_EQUAL(partial["dreamdaemon"]["available"], FALSE, "Dogmos marked a partial DreamDaemon sample available.")
	TEST_ASSERT_EQUAL(partial["dogmosd"]["available"], FALSE, "Dogmos marked a partial dogmosd sample available.")

	original_slow_mode = SSair.kennel_slow_mode
	SSair.kennel_slow_mode = TRUE
	var/mob/living/carbon/human/observer = allocate(/mob/living/carbon/human/consistent)
	observer.set_hud_used(new observer.hud_type(observer))
	var/list/data = GLOB.dogmos_kennel.ui_data(observer)
	var/list/payload = data["process_metrics"]
	TEST_ASSERT_NOTNULL(payload, "The Dogmos Kennel omitted process_metrics from its live payload.")
	TEST_ASSERT_EQUAL(length(payload), 2, "The Dogmos Kennel exposed a combined or unexpected process role.")
	TEST_ASSERT("dreamdaemon" in payload, "The Dogmos Kennel omitted the DreamDaemon process role.")
	TEST_ASSERT("dogmosd" in payload, "The Dogmos Kennel omitted the dogmosd process role.")
	TEST_ASSERT_NULL(payload["combined"], "The Dogmos Kennel exposed combined process memory.")
	TEST_ASSERT_EQUAL(length(payload["dreamdaemon"]), 4, "The Dogmos Kennel changed the DreamDaemon metric contract.")
	TEST_ASSERT("private_bytes" in payload["dreamdaemon"], "The Dogmos Kennel omitted DreamDaemon private bytes.")
	TEST_ASSERT("virtual_bytes" in payload["dreamdaemon"], "The Dogmos Kennel omitted DreamDaemon virtual bytes.")
	TEST_ASSERT("working_set_bytes" in payload["dreamdaemon"], "The Dogmos Kennel omitted DreamDaemon working-set bytes.")
	TEST_ASSERT("available" in payload["dreamdaemon"], "The Dogmos Kennel omitted DreamDaemon availability.")
	TEST_ASSERT_EQUAL(length(payload["dogmosd"]), 3, "The Dogmos Kennel changed the dogmosd metric contract.")
	TEST_ASSERT("rss_bytes" in payload["dogmosd"], "The Dogmos Kennel omitted dogmosd resident-set bytes.")
	TEST_ASSERT("cpu_total_milliseconds" in payload["dogmosd"], "The Dogmos Kennel omitted dogmosd cumulative CPU milliseconds.")
	TEST_ASSERT("available" in payload["dogmosd"], "The Dogmos Kennel omitted dogmosd availability.")
	TEST_ASSERT(!("process_metrics" in GLOB.dogmos_kennel.vars), "The Dogmos Kennel retained the latest process snapshot.")
	TEST_ASSERT(!("process_metrics_history" in GLOB.dogmos_kennel.vars), "The Dogmos Kennel retained process-metrics history.")
	TEST_ASSERT(!("process_metrics" in SSair.vars), "SSair retained the latest process snapshot.")
	TEST_ASSERT(!("process_metrics_history" in SSair.vars), "SSair retained process-metrics history.")

/datum/unit_test/dogmos_kennel_process_metrics/Destroy()
	if(!isnull(original_slow_mode))
		SSair.kennel_slow_mode = original_slow_mode
	return ..()

#undef DOGMOS_TEST_PROCESS_METRICS_WORDS
#undef DOGMOS_TEST_PROCESS_WORD_BASE
