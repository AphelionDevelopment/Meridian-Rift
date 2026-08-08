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
	first_account.adjust_money(700, "Test: Earnings")
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
	original_account.adjust_money(1000, "Test: Earnings")
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
	abandoned_account.adjust_money(500, "Test: Opening Balance")
	abandoned_account.suspend_income()

	TEST_ASSERT(!abandoned_account.payday(1, free = TRUE), "A suspended account was paid. A player cycling characters banks one income stream per character.")
	TEST_ASSERT_EQUAL(abandoned_account.account_balance, 500, "A suspended account's balance moved on payday.")
	TEST_ASSERT(abandoned_account.adjust_money(-100, "Test: Spending"), "A suspended account could not be spent from. Suspension stops income, not access.")

	qdel(abandoned_account)

/// The transaction levy takes its cut of crew-to-crew transfers and leaves department money alone.
/datum/unit_test/transaction_levy

/datum/unit_test/transaction_levy/Run()
	var/datum/job/test_job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/seller_account = new("Seller", test_job)
	var/datum/bank_account/buyer_account = new("Buyer", test_job)
	var/datum/bank_account/department_account = SSeconomy.get_dep_account(ACCOUNT_CIV)

	TEST_ASSERT_NOTNULL(department_account, "No civilian budget exists to test the departmental exemption against.")

	var/expected_levy = round(1000 * TRANSACTION_LEVY_FRACTION)
	TEST_ASSERT_EQUAL(seller_account.get_transaction_levy(buyer_account, 1000), expected_levy, "No levy was taken on a crew-to-crew transfer. The economy has no continuous sink.")
	TEST_ASSERT_EQUAL(seller_account.get_transaction_levy(department_account, 1000), 0, "A levy was taken on money leaving a department budget. Payday would be docked.")
	TEST_ASSERT_EQUAL(department_account.get_transaction_levy(buyer_account, 1000), 0, "A levy was taken on money paid to a department budget.")
	TEST_ASSERT_EQUAL(seller_account.get_transaction_levy(buyer_account, 0), 0, "A levy was taken on a transfer of nothing.")

	buyer_account.adjust_money(1000, "Test: Opening Balance")
	seller_account.transfer_money(buyer_account, 1000, "Test: Sale")

	TEST_ASSERT_EQUAL(buyer_account.account_balance, 0, "The buyer paid something other than the agreed sum.")
	TEST_ASSERT_EQUAL(seller_account.account_balance, 1000 - expected_levy, "The seller did not carry the levy.")

	qdel(seller_account)
	qdel(buyer_account)

#undef TEST_LEDGER_PATH
