/// File the ledger tests read and write. Deleted again in Destroy, along with its backup.
#define TEST_LEDGER_PATH "data/unit_test_persistent_economy.json"

/**
 * Base for the ledger tests, handling the file each one needs.
 *
 * A ledger owns a real file and a real [/datum/json_database], and a database refuses to open twice on
 * one path, so the ledger has to be torn down and the file removed between tests rather than left for
 * the next one to trip over.
 */
/datum/unit_test/economy_ledger
	abstract_type = /datum/unit_test/economy_ledger
	/// The ledger under test, opened fresh for each test.
	var/datum/economy_ledger/ledger

/datum/unit_test/economy_ledger/New()
	. = ..()
	fdel(TEST_LEDGER_PATH)
	fdel("[TEST_LEDGER_PATH].savebac")
	ledger = get_economy_ledger(TEST_LEDGER_PATH)

/datum/unit_test/economy_ledger/Destroy()
	QDEL_NULL(ledger)
	fdel(TEST_LEDGER_PATH)
	fdel("[TEST_LEDGER_PATH].savebac")
	return ..()

/// A record written to the ledger reads back as it was written.
/datum/unit_test/economy_ledger/round_trip

/datum/unit_test/economy_ledger/round_trip/Run()
	ledger.write_record(
		key = "test:round_trip",
		balance = 1234,
		debt = 56,
		holder = "Test Subject",
		history = list(list("adjusted_money" = -40, "reason" = "Vending: Machinery Using")),
	)

	TEST_ASSERT_EQUAL(ledger.read_balance("test:round_trip"), 1234, "Balance did not survive a write and read.")
	TEST_ASSERT_EQUAL(ledger.read_debt("test:round_trip"), 56, "Debt did not survive a write and read.")
	TEST_ASSERT_EQUAL(ledger.read_holder("test:round_trip"), "Test Subject", "Holder did not survive a write and read.")

	var/list/history = ledger.read_history("test:round_trip")
	TEST_ASSERT_EQUAL(length(history), 1, "History did not survive a write and read.")
	TEST_ASSERT_EQUAL(history[1]["adjusted_money"], -40, "History entry lost its amount.")
	TEST_ASSERT_EQUAL(history[1]["reason"], "Vending: Machinery Using", "History entry lost its reason.")

/// A key that was never written reads as absent, not as zero.
/datum/unit_test/economy_ledger/unknown_key

/datum/unit_test/economy_ledger/unknown_key/Run()
	TEST_ASSERT_NULL(ledger.read_balance("test:never_written"), "An unwritten key returned a balance instead of null. First-time accounts cannot be told apart from spent-out ones.")
	TEST_ASSERT_EQUAL(ledger.read_debt("test:never_written"), 0, "An unwritten key returned a debt.")
	TEST_ASSERT_EQUAL(length(ledger.read_history("test:never_written")), 0, "An unwritten key returned history.")
	TEST_ASSERT_NULL(ledger.read_holder("test:never_written"), "An unwritten key returned a holder.")

/// A record whose balance is not a number is refused rather than read as zero.
/datum/unit_test/economy_ledger/malformed_record

/datum/unit_test/economy_ledger/malformed_record/Run()
	ledger.store.set_key("test:malformed", list("balance" = "not a number", "debt" = "also not"))

	TEST_ASSERT_NULL(ledger.read_balance("test:malformed"), "A malformed balance read as a number. A half-written file would zero an account instead of leaving it alone.")
	TEST_ASSERT_EQUAL(ledger.read_debt("test:malformed"), 0, "A malformed debt did not fall back to no debt.")

/// A record that is not a list at all is refused.
/datum/unit_test/economy_ledger/non_list_record

/datum/unit_test/economy_ledger/non_list_record/Run()
	ledger.store.set_key("test:garbage", "this is not a record")

	TEST_ASSERT_NULL(ledger.read_record("test:garbage"), "A non-list record was returned instead of refused.")
	TEST_ASSERT_NULL(ledger.read_balance("test:garbage"), "A non-list record produced a balance.")

/// Writing clamps a balance to what a record is allowed to hold.
/datum/unit_test/economy_ledger/balance_limit

/datum/unit_test/economy_ledger/balance_limit/Run()
	ledger.write_record(key = "test:rich", balance = LEDGER_BALANCE_LIMIT * 10, debt = 0, holder = "Rich")
	TEST_ASSERT_EQUAL(ledger.read_balance("test:rich"), LEDGER_BALANCE_LIMIT, "An over-limit balance was stored whole.")

	ledger.write_record(key = "test:owing", balance = 0, debt = -500, holder = "Owing")
	TEST_ASSERT_EQUAL(ledger.read_debt("test:owing"), 0, "A negative debt was stored instead of clamped to zero.")

/// History is trimmed to the cap on the way in, so the file cannot grow without bound.
/datum/unit_test/economy_ledger/history_is_bounded

/datum/unit_test/economy_ledger/history_is_bounded/Run()
	var/list/overlong_history = list()
	for(var/entry_number in 1 to LEDGER_HISTORY_LENGTH * 2)
		overlong_history += list(list("adjusted_money" = entry_number, "reason" = "Test: Entry [entry_number]"))

	ledger.write_record(key = "test:chatty", balance = 0, debt = 0, holder = "Chatty", history = overlong_history)

	var/list/stored_history = ledger.read_history("test:chatty")
	TEST_ASSERT_EQUAL(length(stored_history), LEDGER_HISTORY_LENGTH, "History was not trimmed to its cap on write.")
	TEST_ASSERT_EQUAL(stored_history[length(stored_history)]["adjusted_money"], LEDGER_HISTORY_LENGTH * 2, "Trimming dropped the newest entries instead of the oldest.")

/// History entries that are not shaped like transactions are dropped, since the panel renders them raw.
/datum/unit_test/economy_ledger/malformed_history

/datum/unit_test/economy_ledger/malformed_history/Run()
	ledger.store.set_key("test:bad_history", list(
		"balance" = 0,
		"history" = list(
			list("adjusted_money" = 10, "reason" = "Test: Good"),
			list("adjusted_money" = "ten", "reason" = "Test: Bad Amount"),
			list("adjusted_money" = 10),
			"not even a list",
		),
	))

	var/list/history = ledger.read_history("test:bad_history")
	TEST_ASSERT_EQUAL(length(history), 1, "Malformed history entries were loaded instead of dropped.")
	TEST_ASSERT_EQUAL(history[1]["reason"], "Test: Good", "The wrong history entry survived.")

/// Attaching tells a first-time key from a returning one, and adopts stored state on return.
/datum/unit_test/economy_ledger/attach_adopts_stored_state

/datum/unit_test/economy_ledger/attach_adopts_stored_state/Run()
	var/datum/job/test_job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/first_account = new("First Holder", test_job)

	TEST_ASSERT(!first_account.attach_ledger(ledger, "test:attach"), "Attaching to a key with no record reported a returning account.")
	first_account.adjust_money(700, "Test: Earnings", LEVY_EXEMPT)
	qdel(first_account)

	var/datum/bank_account/second_account = new("Second Holder", test_job)
	TEST_ASSERT(second_account.attach_ledger(ledger, "test:attach"), "Attaching to a key with a record reported a first-time account.")
	TEST_ASSERT_EQUAL(second_account.account_balance, 700, "A returning account did not adopt its stored balance.")
	qdel(second_account)

/// One key carries one live account. The account that had it is cut loose rather than left writing.
/datum/unit_test/economy_ledger/one_account_per_key

/datum/unit_test/economy_ledger/one_account_per_key/Run()
	var/datum/job/test_job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/original_account = new("Original", test_job)
	var/datum/bank_account/usurper_account = new("Usurper", test_job)

	original_account.attach_ledger(ledger, "test:contested")
	original_account.adjust_money(1000, "Test: Earnings", LEVY_EXEMPT)
	usurper_account.attach_ledger(ledger, "test:contested")

	TEST_ASSERT_NULL(original_account.ledger, "Two accounts held one key at once. Both write their own balance over the other's, so credits spent from one are restored by the next write from the other.")
	TEST_ASSERT(original_account.income_suspended, "An account that lost its key kept drawing income.")
	TEST_ASSERT_EQUAL(ledger.live_accounts["test:contested"], usurper_account, "The ledger did not hand the key to the account that claimed it.")

	original_account.adjust_money(-1000, "Test: Spending")
	TEST_ASSERT_EQUAL(ledger.read_balance("test:contested"), 1000, "A detached account still wrote to the ledger.")

	qdel(original_account)
	qdel(usurper_account)

/// A suspended account stops earning but can still be spent from.
/datum/unit_test/economy_ledger/suspended_income

/datum/unit_test/economy_ledger/suspended_income/Run()
	var/datum/job/test_job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/abandoned_account = new("Abandoned", test_job)
	abandoned_account.adjust_money(500, "Test: Opening Balance", LEVY_EXEMPT)
	abandoned_account.suspend_income()

	TEST_ASSERT(!abandoned_account.payday(1, free = TRUE), "A suspended account was paid. A player cycling characters banks one income stream per character.")
	TEST_ASSERT_EQUAL(abandoned_account.account_balance, 500, "A suspended account's balance moved on payday.")
	TEST_ASSERT(abandoned_account.adjust_money(-100, "Test: Spending"), "A suspended account could not be spent from. Suspension stops income, not access.")

	qdel(abandoned_account)

/**
 * Base for the levy tests, which need persistence switched on to measure anything.
 *
 * The stored setting is off until an admin throws it, and a test server has never thrown it, so a levy
 * test that did not force this would pass by asserting that nothing happens.
 */
/datum/unit_test/economy_levy
	abstract_type = /datum/unit_test/economy_levy
	/// Whatever the round was running under, put back afterwards.
	var/previous_state

/datum/unit_test/economy_levy/New()
	. = ..()
	previous_state = GLOB.persistent_economy_active
	GLOB.persistent_economy_active = TRUE

/datum/unit_test/economy_levy/Destroy()
	GLOB.persistent_economy_active = previous_state
	return ..()

/// The levy takes its cut at the right rate and leaves the exempt paths alone.
/datum/unit_test/economy_levy/rates

/datum/unit_test/economy_levy/rates/Run()
	var/datum/job/test_job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/seller_account = new("Seller", test_job)
	var/datum/bank_account/buyer_account = new("Buyer", test_job)
	var/datum/bank_account/department_account = SSeconomy.get_dep_account(ACCOUNT_CIV)

	TEST_ASSERT_NOTNULL(department_account, "No civilian budget exists to test the departmental exemption against.")

	var/expected_levy = round(1000 * TRANSACTION_LEVY_FRACTION)
	TEST_ASSERT_EQUAL(get_transaction_levy(seller_account, 1000), expected_levy, "No levy was taken on credits arriving in a crew account. The economy has no continuous sink.")
	TEST_ASSERT_EQUAL(get_transaction_levy(department_account, 1000), 0, "A levy was taken on money paid to a department budget.")
	TEST_ASSERT_EQUAL(get_transaction_levy(seller_account, 0), 0, "A levy was taken on a transfer of nothing.")
	TEST_ASSERT_EQUAL(get_transaction_levy(seller_account, 1000, LEVY_EXEMPT), 0, "An exempt path was levied anyway. Salary, grants and refunds would all be docked.")

	var/expected_deposit_levy = round(1000 * DEPOSIT_LEVY_FRACTION)
	TEST_ASSERT_EQUAL(get_transaction_levy(seller_account, 1000, DEPOSIT_LEVY_FRACTION), expected_deposit_levy, "No levy was taken on banked cash. Withdrawing, handing over a holochip and depositing moves credits between crew untaxed.")

	buyer_account.adjust_money(1000, "Test: Opening Balance", LEVY_EXEMPT)
	seller_account.transfer_money(buyer_account, 1000, "Test: Sale")

	TEST_ASSERT_EQUAL(buyer_account.account_balance, 0, "The buyer paid something other than the agreed sum.")
	TEST_ASSERT_EQUAL(seller_account.account_balance, 1000 - expected_levy, "The seller did not carry the levy.")

	qdel(seller_account)
	qdel(buyer_account)

/// Any surface that credits an account is levied, without having to name that surface.
/datum/unit_test/economy_levy/charged_centrally

/datum/unit_test/economy_levy/charged_centrally/Run()
	var/datum/job/test_job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/shopkeeper_account = new("Shopkeeper", test_job)

	// What a custom vendor, display case or pricetag does: credit an account directly, no transfer_money.
	shopkeeper_account.adjust_money(1000, "Test: Direct Sale")
	TEST_ASSERT_EQUAL(shopkeeper_account.account_balance, 1000 - round(1000 * TRANSACTION_LEVY_FRACTION), "Crediting an account directly escaped the levy. Every surface that does not go through transfer_money is then an untaxed path around the sink.")

	shopkeeper_account.adjust_money(-500, "Test: Spending")
	TEST_ASSERT_EQUAL(shopkeeper_account.account_balance, 450, "A withdrawal was levied. The levy is charged on credits arriving, not leaving.")

	qdel(shopkeeper_account)

/// Salary out of a department budget is income, not trade, and is not docked on the way out.
/datum/unit_test/economy_levy/exempts_salary

/datum/unit_test/economy_levy/exempts_salary/Run()
	var/datum/job/test_job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/crew_account = new("Crew", test_job)
	var/datum/bank_account/department_account = SSeconomy.get_dep_account(ACCOUNT_CIV)

	TEST_ASSERT_NOTNULL(department_account, "No civilian budget exists to pay a salary out of.")

	department_account.adjust_money(1000, "Test: Budget")
	crew_account.transfer_money(department_account, 1000, "Test: Salary")
	TEST_ASSERT_EQUAL(crew_account.account_balance, 1000, "Salary out of a department budget was levied. Every paycheck would be docked.")

	qdel(crew_account)

/// A record stamped newer than this build is refused rather than guessed at.
/datum/unit_test/economy_ledger/schema_version

/datum/unit_test/economy_ledger/schema_version/Run()
	ledger.store.set_key("test:from_the_future", list(
		LEDGER_FIELD_VERSION = LEDGER_SCHEMA_VERSION + 1,
		LEDGER_FIELD_BALANCE = 5000,
	))

	TEST_ASSERT_NULL(ledger.read_record("test:from_the_future"), "A record written by a newer build was read anyway. Rolling a server back would rewrite newer records into an older shape.")
	TEST_ASSERT_NULL(ledger.read_balance("test:from_the_future"), "A newer record produced a balance.")
	TEST_ASSERT_NULL(summarise_ledger_record(ledger.store.get_key("test:from_the_future")), "A newer record was counted in the cross-ledger totals.")

	ledger.store.set_key("test:unversioned", list(LEDGER_FIELD_BALANCE = 200))
	TEST_ASSERT_EQUAL(ledger.read_balance("test:unversioned"), 200, "A record predating versioning was refused. It is the same shape as version 1 and has to keep loading.")

/// Clearing a ledger erases it and cuts loose the accounts that would otherwise write it back.
/datum/unit_test/economy_ledger/clear_records

/datum/unit_test/economy_ledger/clear_records/Run()
	var/datum/job/test_job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/bound_account = new("Bound", test_job)

	bound_account.attach_ledger(ledger, "test:wiped")
	bound_account.adjust_money(900, "Test: Earnings", LEVY_EXEMPT)
	ledger.write_record(key = "test:untouched_by_anyone", balance = 100, debt = 0, holder = "Absent")

	TEST_ASSERT_EQUAL(ledger.clear_records(), 2, "Clearing the ledger did not report the records it erased.")
	TEST_ASSERT_EQUAL(length(ledger.read_all()), 0, "Records survived a clear.")
	TEST_ASSERT_NULL(bound_account.ledger, "A bound account kept its ledger through a clear. It writes itself back on its next transaction, so the wipe would undo itself one account at a time.")
	TEST_ASSERT_EQUAL(bound_account.account_balance, 900, "Clearing the ledger took credits off an account in play. Erasing what carries over is a separate thing from confiscating a balance mid-shift.")

	bound_account.adjust_money(50, "Test: Post-Wipe Earnings", LEVY_EXEMPT)
	TEST_ASSERT_EQUAL(length(ledger.read_all()), 0, "A detached account wrote itself back into a cleared ledger.")

	qdel(bound_account)

#undef TEST_LEDGER_PATH
