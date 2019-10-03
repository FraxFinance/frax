#pragma once

using namespace eosio::testing;
using namespace eosio;
using namespace eosio::chain;

using mvo = fc::mutable_variant_object;
using action_result = base_tester::action_result;

class fraxloans_api {
public:
  account_name contract;

  fraxloans_api(account_name acnt, tester* tester) {
	contract = acnt;
	_tester = tester;

	_tester->create_accounts({contract});
	_tester->set_code(contract, contracts::fraxloans_wasm());
	_tester->set_abi(contract, contracts::fraxloans_abi().data());

	const auto &accnt = _tester->control->db().get<account_object, by_name>(contract);

	abi_def abi;
	BOOST_REQUIRE_EQUAL(abi_serializer::to_abi(accnt.abi, abi), true);
	abi_ser.set_abi(abi, abi_serializer_max_time);
  }

  action_result addtoken(const name& token_contract, string symb)
  {
	auto ticker = eosio::chain::symbol::from_string(symb);
	return push_action(
		contract, contract, N(addtoken),
		mvo()("contract", token_contract)("ticker", ticker));
  }

  action_result borrow(const name& borrower, asset quantity)
  {
	return push_action(
		borrower, contract, N(borrow),
		mvo()("borrower", borrower)("quantity", quantity));
  }

  action_result repay(const name& borrower, asset quantity)
  {
	return push_action(
		borrower, contract, N(repay),
		mvo()("borrower", borrower)("quantity", quantity));
  }

  action_result setprice(asset price)
  {
	return push_action(
		contract, contract, N(setprice),
		mvo()("price", price));
  }

  action_result advancetime(string symb, uint64_t seconds)
  {
    string password = "g76333sse2l$K";
	auto ticker = eosio::chain::symbol::from_string(symb);
	return push_action(
		contract, contract, N(advancetime),
		mvo()("ticker", ticker)("seconds", seconds)("password", password));
  }

  fc::variant get_account(const account_name& acc, const string& symbolname)
  {
	auto symb = eosio::chain::symbol::from_string(symbolname);
	auto symbol_code = symb.to_symbol_code().value;
	vector<char> data = _tester->get_row_by_account( contract, acc, N(accounts), symbol_code );
	return data.empty() ? fc::variant() : abi_ser.binary_to_variant( "account", data, abi_serializer_max_time );
  }

  fc::variant get_tokenstats(const string& symbolname)
  {
	auto symb = eosio::chain::symbol::from_string(symbolname);
	auto symbol_code = symb.to_symbol_code().value;
	vector<char> data = _tester->get_row_by_account( contract, contract, N(tokenstats), symbol_code );

	return data.empty() ? fc::variant() : abi_ser.binary_to_variant( "stats_t", data, abi_serializer_max_time );
  }

  action_result push_action(const account_name &signer,
							const account_name &cnt,
							const action_name &name,
							const variant_object &data) {
	string action_type_name = abi_ser.get_action_type(name);
	action act;
	act.account = cnt;
	act.name = name;
	act.data = abi_ser.variant_to_binary(action_type_name, data, abi_serializer_max_time);

	return _tester->push_action(std::move(act), uint64_t(signer));
  }

private:
  abi_serializer abi_ser;
  tester* _tester;
  fc::microseconds abi_serializer_max_time{1000*1000};
};
