#!/bin/bash

CYAN='\033[1;36m'
NC='\033[0m'

assert ()
{

    if [ $1 -eq 0 ]; then
        FAIL_LINE=$( caller | awk '{print $1}')
        echo -e "Assertion failed. Line $FAIL_LINE:"
        head -n $FAIL_LINE $BASH_SOURCE | tail -n 1
        exit 99
    fi
}

echo -e "${CYAN}-----------------------DEPLOY CONTRACT-----------------------${NC}"
cleos set contract fraxreserves ../build/frax.reserve/

echo -e "${CYAN}-----------------------ADD TOKENS-----------------------${NC}"
cleos push action fraxreserves addtoken '["tethertether", "4,USDT"]' -p fraxreserves
cleos push action fraxreserves addtoken '["fraxfitokens", "4,FXS"]' -p fraxreserves
cleos push action fraxreserves addtoken '["fraxfitokens", "4,FRAX"]' -p fraxreserves

echo -e "${CYAN}-----------------------DEPOSIT TOKENS-----------------------${NC}"
cleos push action tethertether transfer '["dcbtestusera", "fraxreserves", "2000.0000 USDT", "deposit USDT"]' -p dcbtestusera
assert $(bc <<< "$? == 0")
cleos push action tethertether transfer '["dcbtestuserb", "fraxreserves", "3000.0000 USDT", "deposit USDT"]' -p dcbtestuserb
assert $(bc <<< "$? == 0")
cleos push action fraxfitokens transfer '["dcbtestusera", "fraxreserves", "1000.0000 FXS", "deposit FXS"]' -p dcbtestusera
assert $(bc <<< "$? == 0")
cleos push action fraxfitokens transfer '["dcbtestuserb", "fraxreserves", "1000.0000 FXS", "deposit FXS"]' -p dcbtestuserb
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------DEPOSIT UNSUPPORTED TOKENS-----------------------${NC}"
cleos transfer dcbtestusera fraxreserves "1 EOS" "deposit EOS"
assert $(bc <<< "$? == 1")
cleos push action everipediaiq transfer '["dcbtestusera", "fraxreserves", "1000.000 IQ", "deposit IQ"]' -p dcbtestusera
assert $(bc <<< "$? == 1")


echo -e "${CYAN}-----------------------SET FULLY-BACKED TARGET-----------------------${NC}"
CURRENT_TARGET_USDT=$(cleos get table fraxreserves fraxreserves sysparams | jq ".rows[0].target_usdt" | tr -d '"' | awk '{ print $1 }')
if [ "$CURRENT_TARGET_USDT" = "null" ]; then
    NEW_TARGET_USDT=2000.0000
else
    NEW_TARGET_USDT=$(echo "$CURRENT_TARGET_USDT + 2000" | bc)
fi
CURRENT_SUPPLY_FXS=$(cleos get table fraxreserves fraxreserves stats | jq ".rows[]" | grep FXS | tr -d '"' | awk '{ print $2 }')
if [ "$CURRENT_TARGET_FXS" = "null" ]; then
    CURRENT_TARGET_FXS=0.0000
fi
cleos push action fraxreserves settarget "[\"$NEW_TARGET_USDT USDT\", \"$CURRENT_SUPPLY_FXS FXS\", 1e4]" -p fraxreserves
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------BUY FRAX WITH USDT-----------------------${NC}"
OLD_FRAX_BALANCE1=$(cleos get table fraxfitokens dcbtestusera accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
OLD_FRAX_BALANCE2=$(cleos get table fraxfitokens dcbtestuserb accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
if [ -z $OLD_FRAX_BALANCE1 ]; then
    OLD_FRAX_BALANCE1=0
    OLD_FRAX_BALANCE2=0
fi
OLD_USDT_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')
OLD_USDT_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')

cleos push action fraxreserves buyfrax '["dcbtestusera", "1000.0000 FRAX"]' -p dcbtestusera
assert $(bc <<< "$? == 0")
cleos push action fraxreserves buyfrax '["dcbtestuserb", "1000.0000 FRAX"]' -p dcbtestuserb
assert $(bc <<< "$? == 0")

NEW_FRAX_BALANCE1=$(cleos get table fraxfitokens dcbtestusera accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
NEW_FRAX_BALANCE2=$(cleos get table fraxfitokens dcbtestuserb accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
NEW_USDT_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')
NEW_USDT_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')

assert $(bc <<< "$NEW_FRAX_BALANCE1 - $OLD_FRAX_BALANCE1 == 1000")
assert $(bc <<< "$NEW_FRAX_BALANCE2 - $OLD_FRAX_BALANCE2 == 1000")
assert $(bc <<< "$OLD_USDT_BALANCE1 - $NEW_USDT_BALANCE1 == 1000")
assert $(bc <<< "$OLD_USDT_BALANCE2 - $NEW_USDT_BALANCE2 == 1000")

echo -e "${CYAN}-----------------------SET PARTIALLY-BACKED TARGET-----------------------${NC}"
NEW_TARGET_FXS=$(echo "$CURRENT_SUPPLY_FXS + 10" | bc)
CURRENT_TARGET_USDT=$(cleos get table fraxreserves fraxreserves sysparams | jq ".rows[0].target_usdt" | tr -d '"' | awk '{ print $1 }')
NEW_TARGET_USDT=$(echo "$CURRENT_TARGET_USDT + 2000" | bc)
cleos push action fraxreserves settarget "[\"$NEW_TARGET_USDT USDT\", \"$NEW_TARGET_FXS FXS\", 1e4]" -p fraxreserves
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------BUY FRAX WITH USDT + FXS-----------------------${NC}"
OLD_FRAX_BALANCE1=$(cleos get table fraxfitokens dcbtestusera accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
OLD_FRAX_BALANCE2=$(cleos get table fraxfitokens dcbtestuserb accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
OLD_FXS_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep FXS | tr -d '"' | awk '{ print $2 }')
OLD_FXS_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep FXS | tr -d '"' | awk '{ print $2 }')

cleos push action --force-unique fraxreserves buyfrax '["dcbtestusera", "1000.0000 FRAX"]' -p dcbtestusera
assert $(bc <<< "$? == 0")
cleos push action --force-unique fraxreserves buyfrax '["dcbtestuserb", "1000.0000 FRAX"]' -p dcbtestuserb
assert $(bc <<< "$? == 0")

NEW_FRAX_BALANCE1=$(cleos get table fraxfitokens dcbtestusera accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
NEW_FRAX_BALANCE2=$(cleos get table fraxfitokens dcbtestuserb accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
NEW_FXS_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep FXS | tr -d '"' | awk '{ print $2 }')
NEW_FXS_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep FXS | tr -d '"' | awk '{ print $2 }')


assert $(bc <<< "$NEW_FRAX_BALANCE1 - $OLD_FRAX_BALANCE1 == 1000")
assert $(bc <<< "$NEW_FRAX_BALANCE2 - $OLD_FRAX_BALANCE2 == 1000")
assert $(bc <<< "$OLD_FXS_BALANCE1 > $NEW_FXS_BALANCE1")
assert $(bc <<< "$OLD_FXS_BALANCE2 > $NEW_FXS_BALANCE2")


echo -e "${CYAN}-----------------------SET BAD PRICE-----------------------${NC}"
cleos push action fraxreserves settarget '["2000.0000 USDT", "0.0000 FXS", 0]' -p fraxreserves
assert $(bc <<< "$? == 1")

echo -e "${CYAN}-----------------------BAD FRAX PURCHASES-----------------------${NC}"
# target already reached
cleos push action fraxreserves buyfrax '["dcbtestusera", "100000.0000 FRAX"]' -p dcbtestusera
assert $(bc <<< "$? == 1")

echo -e "${CYAN}-----------------------DEPOSIT FRAX-----------------------${NC}"
cleos push action fraxfitokens transfer '["dcbtestusera", "fraxreserves", "2000.0000 FRAX", "deposit FRAX"]' -p dcbtestusera
assert $(bc <<< "$? == 0")
cleos push action fraxfitokens transfer '["dcbtestuserb", "fraxreserves", "2000.0000 FRAX", "deposit FRAX"]' -p dcbtestuserb
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------SELL FRAX-----------------------${NC}"
OLD_FRAX_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
OLD_FRAX_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
OLD_USDT_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')
OLD_USDT_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')

cleos push action fraxreserves sellfrax '["dcbtestusera", "2000.0000 FRAX"]' -p dcbtestusera
assert $(bc <<< "$? == 0")
cleos push action fraxreserves sellfrax '["dcbtestuserb", "2000.0000 FRAX"]' -p dcbtestuserb
assert $(bc <<< "$? == 0")

NEW_FRAX_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
NEW_FRAX_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
NEW_USDT_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')
NEW_USDT_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')

assert $(bc <<< "$OLD_FRAX_BALANCE1 - $NEW_FRAX_BALANCE1 == 2000")
assert $(bc <<< "$OLD_FRAX_BALANCE2 - $NEW_FRAX_BALANCE2 == 2000")
assert $(bc <<< "$NEW_USDT_BALANCE1 - $OLD_USDT_BALANCE1 == 2000")
assert $(bc <<< "$NEW_USDT_BALANCE2 - $OLD_USDT_BALANCE2 == 2000")
