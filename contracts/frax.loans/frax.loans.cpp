#include "frax.loans.hpp"

[[eosio::action]]
void fraxloans::addtoken(name contract, symbol ticker) {
    require_auth( _self );

    check(ticker.is_valid(), "invalid symbol name");
    check(ticker.precision() == 4, "to simplify price calculations, only tokens with 4 decimal places are currently supported");

    stats statstable(_self, _self.value);
    auto contract_sym_index = statstable.get_index<name("byctrsym")>();
    uint128_t merged = merge_contract_symbol(contract, ticker);
    auto existing = contract_sym_index.find(merged);
    check(existing == contract_sym_index.end(), "Token is already registered");
    check(statstable.find(ticker.code().raw()) == statstable.end(), "Another token with that ticker already exists");

    statstable.emplace(_self, [&](auto& s) {
        s.contract = contract;
        s.available = asset(0, ticker);
        s.loaned = asset(0, ticker);
        s.price = asset(0, USDT_SYMBOL);
        s.allowed_as_collateral = true;
        s.can_deposit = true;
        s.interest_counter = 1e11;
        s.last_interest_update = current_time_point().sec_since_epoch();
        s.interest_rate_lower = 0.02;
        s.interest_rate_upper = 0.2;
        s.loan_limit = 0.7;
    });
}

[[eosio::on_notify("*::transfer")]] 
void fraxloans::deposit( name from, name to, asset quantity, string memo ) {
    if (from == _self) return; // sending tokens, ignore

    auto symbol = quantity.symbol;
    check(symbol.is_valid(), "invalid symbol name");
    check(to == _self, "stop trying to hack the contract");
    check(is_account(from), "from account does not exist");
    check(is_account(to), "to account does not exist");

    // make sure contract and symbol are accepted by contract
    stats statstable(_self, _self.value);
    auto contract_sym_index = statstable.get_index<name("byctrsym")>();
    uint128_t merged = merge_contract_symbol(get_first_receiver(), symbol);
    auto existing = contract_sym_index.find(merged);
    check(existing != contract_sym_index.end(), "Token is not yet supported");

    // validate arguments
    check(quantity.is_valid(), "invalid quantity");
    check(quantity.amount < 1e10, "quantity is suspiciously high. send a smaller amount");
    check(quantity.amount > 0, "must deposit positive quantity");
    check(memo.size() < 256, "memo must be less than 256 bytes");

    // create/update entry in table
    accounts deptbl( _self, from.value );
    auto account_it = deptbl.find(symbol.code().raw());
    if (account_it == deptbl.end()) {
        deptbl.emplace( _self, [&](auto& a) {
            a.balance = quantity;
            a.borrowing = asset(0, quantity.symbol);
            a.interest_counter_start = 0;
        });
    }
    else {
        deptbl.modify( account_it, _self, [&](auto& a) {
            a.balance += quantity;
        });
    }
    
    // update interest counters
    update_interest_counter(quantity.symbol);

    // update stats
    contract_sym_index.modify( existing, _self, [&](auto& s) {
        s.available += quantity;
    });

}

[[eosio::action]]
void fraxloans::borrow(name borrower, asset quantity) {
    require_auth(borrower);

    check(quantity.amount > 0, "Must borrow positive amount");

    // Check ticker is borrowable
    stats statstbl( _self, _self.value );
    auto& stat_it = statstbl.get(quantity.symbol.code().raw(), "Token is not supported");
    check(stat_it.available > quantity, "Not enough supply available for requested quantity");

    // update interest counters
    update_interest_counter(quantity.symbol);

    // Check if sufficient collateral is present to back loan
    // NOTE: Both sum_collateral and sum_borrow are in units 1e-8 USDT
    accounts acctstbl( _self, borrower.value );
    auto account_it = acctstbl.begin();
    uint64_t sum_collateral = 0;
    while (account_it != acctstbl.end()) {
        auto token_price_it = statstbl.get(account_it->balance.symbol.code().raw(), "Token is not supported");
        if (!token_price_it.allowed_as_collateral) continue;
        sum_collateral += account_it->balance.amount * token_price_it.price.amount;
        account_it++;
    }
    uint64_t sum_borrow = quantity.amount * stat_it.price.amount;
    while (account_it != acctstbl.end()) {
        auto token_price_it = statstbl.get(account_it->balance.symbol.code().raw(), "Token is not supported");
        sum_borrow += account_it->borrowing.amount * token_price_it.price.amount;
        account_it++;
    }
    check((static_cast<int64_t>(sum_collateral * COLLATERAL_RATIO) > sum_borrow), "Insufficient collateral to back loan");
    
    // Update supply
    statstbl.modify( stat_it, _self, [&](auto s) {
        s.available -= quantity;
        s.loaned += quantity;
    });
    check(double(stat_it.loaned.amount) / double(stat_it.available.amount + stat_it.loaned.amount) < stat_it.loan_limit, "loan puts token over its loan limit");

    // Update borrower account
    account_it = acctstbl.find(quantity.symbol.code().raw());
    if (account_it == acctstbl.end()) {
        acctstbl.emplace( _self, [&](auto& a) {
            a.balance = quantity;
            a.borrowing = quantity;
            a.interest_counter_start = stat_it.interest_counter;
        });
    }
    else {
        uint64_t interest_counter_start = account_it->interest_counter_start + (stat_it.interest_counter - account_it->interest_counter_start) * (account_it->borrowing.amount + quantity.amount) / account_it->borrowing.amount;
        check(account_it->borrowing.symbol == quantity.symbol, "Mismatched symbols");
        acctstbl.modify( account_it, _self, [&](auto& a) {
            a.balance += quantity;
            a.borrowing += quantity;
            a.interest_counter_start = stat_it.interest_counter;
        });
    }
}

[[eosio::action]]
void fraxloans::repay(name borrower, asset quantity) {
    require_auth(borrower);

    check(quantity.amount > 0, "Must repay positive amount");

    // Check ticker is borrowable
    stats statstbl( _self, _self.value );
    auto& stat_it = statstbl.get(quantity.symbol.code().raw(), "Token is not supported");
    
    // get borrower account
    accounts acctstbl( _self, borrower.value );
    auto& account_it = acctstbl.get(quantity.symbol.code().raw(), "No borrow balance found for this user");

    // update interest
    update_interest_counter(quantity.symbol);
    uint64_t interest_owed = account_it.borrowing.amount * (stat_it.interest_counter - account_it.interest_counter_start) / stat_it.interest_counter;
    uint64_t total_owed = account_it.borrowing.amount + interest_owed;
    check(quantity.amount <= total_owed, "Attempting to repay too much");
        
    // Update supply
    statstbl.modify( stat_it, _self, [&](auto& s) {
        s.available += quantity;
        s.loaned -= quantity;
    });

    // update borrower account with interest and repayment
    acctstbl.modify( account_it, _self, [&](auto& a) {
        a.balance.amount += interest_owed;
        a.balance -= quantity;
        a.borrowing -= quantity;
        a.interest_counter_start = stat_it.interest_counter;
    });
}

[[eosio::action]]
void fraxloans::setprice(asset price) {
    require_auth( _self );

    stats statstable(_self, _self.value);
    auto stats_it = statstable.find(price.symbol.code().raw());
    check(stats_it != statstable.end(), "symbol is not supported. check decimal places");

    statstable.modify( stats_it, _self, [&](auto &s) {
        s.price = price;
    });

}

// For testing purposes only, advances the time of the interest counter
// for the specified asset by the specified number of seconds
// the password is a hindrance to make sure it isn't accidentally called
[[eosio::action]]
void fraxloans::advancetime(symbol ticker, uint64_t seconds, string password) {
    require_auth( _self );
    check(password == "g76333sse2l$K", "You really shouldn't be running this in production");

    stats statstable(_self, _self.value);
    auto& stats_it = statstable.get(ticker.code().raw(), "symbol is not supported. check decimal places");

    double loan_ratio = double(stats_it.loaned.amount) / double(stats_it.available.amount + stats_it.loaned.amount);
    double interest_rate = stats_it.interest_rate_lower + (stats_it.interest_rate_upper - stats_it.interest_rate_lower) * (loan_ratio / stats_it.loan_limit);
    const uint64_t SECS_PER_YEAR = 86400 * 365;
    //uint64_t now = current_time_point().sec_since_epoch();
    uint64_t now = stats_it.last_interest_update + seconds;
    uint64_t secs_since_last_update = now - stats_it.last_interest_update;

    statstable.modify( stats_it, _self, [&](auto &s) {
        s.interest_counter += uint64_t(s.interest_counter * interest_rate * secs_since_last_update / SECS_PER_YEAR);
        s.last_interest_update = now;
    });
}

void fraxloans::update_interest_counter(symbol ticker) {
    stats statstable(_self, _self.value);
    auto& stats_it = statstable.get(ticker.code().raw(), "symbol is not supported. check decimal places");

    double loan_ratio = double(stats_it.loaned.amount) / double(stats_it.available.amount + stats_it.loaned.amount);
    double interest_rate = (stats_it.interest_rate_upper - stats_it.interest_rate_lower) * (loan_ratio / stats_it.loan_limit);
    const uint64_t SECS_PER_YEAR = 86400 * 365;
    uint64_t now = current_time_point().sec_since_epoch();
    uint64_t secs_since_last_update = stats_it.last_interest_update - now;

    statstable.modify( stats_it, _self, [&](auto &s) {
        s.interest_counter += uint64_t(interest_rate * secs_since_last_update / SECS_PER_YEAR);
        s.last_interest_update = now;
    });
}

//[[eosio::action]]
//void liquidate(name user, name executor) {
//     Check if sufficient collateral is present to back loan
//     NOTE: Both sum_collateral and sum_borrow are in units 1e-8 USDT
//    accounts acctstbl( _self, user.value );
//    auto account_it = acctstbl.begin();
//    uint64_t sum_collateral = 0;
//    while (account_it != acctstbl.end()) {
//        auto token_price_it = statstbl.get(account_it->balance.symbol.code().raw(), "Token is not supported");
//        if (!token_price_it->allowed_as_collateral) continue;
//        sum_collateral += account_it->balance.amount * token_price_it->price.amount;
//        account_it++;
//    }
//    uint64_t sum_borrow = quantity.amount * stat_it->price.amount;
//    while (account_it != acctstbl.end()) {
//        auto token_price_it = statstbl.get(account_it->balance.symbol.code().raw(), "Token is not supported");
//        sum_borrow += account_it->borrowing.amount * token_price_it->price.amount;
//        account_it++;
//    }
//    check((static_cast<int64_t>(sum_collateral * COLLATERAL_RATIO) < sum_borrow), "Loans are sufficiently backed");
//
//    // TODO: Send to auction contract
//    
//}
