// THIS IS AN APHELION UI FILE
import { Box, Button, LabeledList, Section, Table } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Account = {
  ref: string;
  holder: string;
  account_id: string;
  balance: number;
  debt: number;
  job: string | null;
  persistent: boolean;
  key: string | null;
};

type StoredRecord = {
  key: string;
  holder: string | null;
  balance: number | null;
  debt: number;
  live: boolean;
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

const AccountTable = (props: { accounts: Account[] }) => {
  const { act } = useBackend<Data>();
  const { accounts } = props;

  if (!accounts.length) {
    return <Box color="label">No accounts.</Box>;
  }

  return (
    <Table>
      <Table.Row header>
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
        <Table.Row key={account.ref} className="candystripe">
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
                <Table.Row key={record.key} className="candystripe">
                  <Table.Cell>{record.key}</Table.Cell>
                  <Table.Cell color="label">{record.holder || '-'}</Table.Cell>
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
                      onClick={() => act('delete_stored', { key: record.key })}
                    />
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
