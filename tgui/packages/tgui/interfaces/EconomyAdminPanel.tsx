// THIS IS AN APHELION UI FILE
import { Fragment, useState } from 'react';
import { Box, Button, LabeledList, Section, Table } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Transaction = {
  amount: number;
  reason: string;
};

type Account = {
  ref: string;
  holder: string;
  account_id: string;
  balance: number;
  debt: number;
  job: string | null;
  persistent: boolean;
  key: string | null;
  income_suspended: boolean;
  history: Transaction[];
};

type StoredRecord = {
  key: string;
  holder: string | null;
  balance: number | null;
  debt: number;
  live: boolean;
  history: Transaction[];
};

type Data = {
  crew_accounts: Account[];
  station_accounts: Account[];
  stored_records: StoredRecord[];
  inspected_ckey: string | null;
  inflation_value: number;
  station_total: number;
  station_target: number;
};

const HistoryRow = (props: { history: Transaction[]; colSpan: number }) => {
  const { history, colSpan } = props;

  return (
    <Table.Row>
      <Table.Cell colSpan={colSpan} px={2} py={1}>
        {!history.length ? (
          <Box color="label">No recorded transactions.</Box>
        ) : (
          <Table>
            {history.map((entry, index) => (
              // Transactions carry nothing unique to key on, and the list is
              // append-only and never reordered, so the index is stable.
              <Table.Row key={index}>
                <Table.Cell
                  collapsing
                  textAlign="right"
                  pr={2}
                  color={entry.amount < 0 ? 'bad' : 'good'}
                >
                  {entry.amount > 0 ? `+${entry.amount}` : entry.amount}
                </Table.Cell>
                <Table.Cell color="label">{entry.reason}</Table.Cell>
              </Table.Row>
            ))}
          </Table>
        )}
      </Table.Cell>
    </Table.Row>
  );
};

const AccountTable = (props: { accounts: Account[] }) => {
  const { act } = useBackend<Data>();
  const { accounts } = props;
  const [expandedRef, setExpandedRef] = useState<string | null>(null);

  if (!accounts.length) {
    return <Box color="label">No accounts.</Box>;
  }

  return (
    <Table>
      <Table.Row header>
        <Table.Cell collapsing />
        <Table.Cell>Holder</Table.Cell>
        <Table.Cell>Job</Table.Cell>
        <Table.Cell collapsing>ID</Table.Cell>
        <Table.Cell collapsing textAlign="right">
          Balance
        </Table.Cell>
        <Table.Cell collapsing textAlign="right">
          Debt
        </Table.Cell>
        <Table.Cell collapsing>Ledger</Table.Cell>
        <Table.Cell collapsing />
      </Table.Row>
      {accounts.map((account) => (
        <Fragment key={account.ref}>
          <Table.Row className="candystripe">
            <Table.Cell collapsing>
              <Button
                icon={expandedRef === account.ref ? 'chevron-down' : 'chevron-right'}
                tooltip="Recent transactions"
                onClick={() =>
                  setExpandedRef(
                    expandedRef === account.ref ? null : account.ref,
                  )
                }
              />
            </Table.Cell>
            <Table.Cell>{account.holder}</Table.Cell>
            <Table.Cell color="label">{account.job || '-'}</Table.Cell>
            <Table.Cell collapsing color="label">
              {account.account_id}
            </Table.Cell>
            <Table.Cell collapsing textAlign="right">
              {account.balance}
            </Table.Cell>
            <Table.Cell
              collapsing
              textAlign="right"
              color={account.debt ? 'bad' : 'label'}
            >
              {account.debt}
            </Table.Cell>
            <Table.Cell collapsing>
              {account.persistent ? (
                <Box color="good">{account.key}</Box>
              ) : (
                <Box color="label">round only</Box>
              )}
            </Table.Cell>
            <Table.Cell collapsing>
              {!!account.income_suspended && (
                <Button
                  icon="ban"
                  color="average"
                  tooltip="Income suspended. This player is playing a different character."
                />
              )}
              <Button
                icon="plus-minus"
                tooltip="Adjust. Obeys debt collection, refuses overdraft."
                onClick={() => act('adjust_balance', { ref: account.ref })}
              />
              <Button
                icon="pen"
                tooltip="Set balance. Overwrites outright."
                onClick={() => act('set_balance', { ref: account.ref })}
              />
              <Button
                icon="file-invoice-dollar"
                tooltip="Set debt"
                onClick={() => act('set_debt', { ref: account.ref })}
              />
            </Table.Cell>
          </Table.Row>
          {expandedRef === account.ref && (
            <HistoryRow history={account.history} colSpan={8} />
          )}
        </Fragment>
      ))}
    </Table>
  );
};

export const EconomyAdminPanel = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    crew_accounts,
    station_accounts,
    stored_records,
    inspected_ckey,
    inflation_value,
    station_total,
    station_target,
  } = data;
  const [expandedKey, setExpandedKey] = useState<string | null>(null);

  return (
    <Window title="Economy Panel" width={900} height={700}>
      <Window.Content scrollable>
        <Section title="Sector">
          <LabeledList>
            <LabeledList.Item label="Vendor Prices">
              {Math.round(inflation_value * 100)}%
            </LabeledList.Item>
            <LabeledList.Item label="Station Total">
              {station_total} cr
            </LabeledList.Item>
            <LabeledList.Item label="Targeted Allowance">
              {station_target} cr
            </LabeledList.Item>
          </LabeledList>
        </Section>

        <Section title="Station Budgets">
          <AccountTable accounts={station_accounts} />
        </Section>

        <Section title={`Crew Accounts (${crew_accounts.length})`}>
          <AccountTable accounts={crew_accounts} />
        </Section>

        <Section
          title={
            inspected_ckey
              ? `Stored Records: ${inspected_ckey}`
              : 'Stored Records: Station Ledger'
          }
          buttons={
            <>
              <Button
                icon="magnifying-glass"
                onClick={() => act('inspect_ckey')}
              >
                Look Up Player
              </Button>
              {!!inspected_ckey && (
                <Button
                  icon="arrow-left"
                  onClick={() => act('inspect_station')}
                >
                  Station Ledger
                </Button>
              )}
            </>
          }
        >
          <Box color="label" mb={1}>
            What is written on disk. Editing a record marked live does nothing:
            the account in play overwrites it on its next transaction.
          </Box>
          {!stored_records.length ? (
            <Box color="label">No records in this ledger.</Box>
          ) : (
            <Table>
              <Table.Row header>
                <Table.Cell collapsing />
                <Table.Cell>Key</Table.Cell>
                <Table.Cell>Holder</Table.Cell>
                <Table.Cell collapsing textAlign="right">
                  Balance
                </Table.Cell>
                <Table.Cell collapsing textAlign="right">
                  Debt
                </Table.Cell>
                <Table.Cell collapsing>State</Table.Cell>
                <Table.Cell collapsing />
              </Table.Row>
              {stored_records.map((record) => (
                <Fragment key={record.key}>
                  <Table.Row className="candystripe">
                    <Table.Cell collapsing>
                      <Button
                        icon={
                          expandedKey === record.key
                            ? 'chevron-down'
                            : 'chevron-right'
                        }
                        tooltip="Stored transactions"
                        onClick={() =>
                          setExpandedKey(
                            expandedKey === record.key ? null : record.key,
                          )
                        }
                      />
                    </Table.Cell>
                    <Table.Cell>{record.key}</Table.Cell>
                    <Table.Cell color="label">
                      {record.holder || '-'}
                    </Table.Cell>
                    <Table.Cell collapsing textAlign="right">
                      {record.balance}
                    </Table.Cell>
                    <Table.Cell
                      collapsing
                      textAlign="right"
                      color={record.debt ? 'bad' : 'label'}
                    >
                      {record.debt}
                    </Table.Cell>
                    <Table.Cell
                      collapsing
                      color={record.live ? 'average' : 'good'}
                    >
                      {record.live ? 'live' : 'stored'}
                    </Table.Cell>
                    <Table.Cell collapsing>
                      <Button
                        icon="pen"
                        tooltip="Set stored balance"
                        onClick={() =>
                          act('set_stored_balance', { key: record.key })
                        }
                      />
                      <Button
                        icon="trash"
                        color="bad"
                        tooltip="Delete record"
                        onClick={() =>
                          act('delete_stored', { key: record.key })
                        }
                      />
                    </Table.Cell>
                  </Table.Row>
                  {expandedKey === record.key && (
                    <HistoryRow history={record.history} colSpan={7} />
                  )}
                </Fragment>
              ))}
            </Table>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
