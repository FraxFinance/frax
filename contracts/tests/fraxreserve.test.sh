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

echo -e "${CYAN}-----------------------DEPOSIT TOKENS-----------------------${NC}"
OLD_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')
OLD_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')
OLD_BALANCE3=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep FXS | tr -d '"' | awk '{ print $2 }')
OLD_BALANCE4=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep FXS | tr -d '"' | awk '{ print $2 }')

cleos push action tethertether transfer '["dcbtestusera", "fraxreserves", "2000.0000 USDT", "deposit USDT"]' -p dcbtestusera
assert $(bc <<< "$? == 0")
cleos push action tethertether transfer '["dcbtestuserb", "fraxreserves", "3000.0000 USDT", "deposit USDT"]' -p dcbtestuserb
assert $(bc <<< "$? == 0")
cleos push action fraxfitokens transfer '["dcbtestusera", "fraxreserves", "1000.0000 FXS", "deposit FXS"]' -p dcbtestusera
assert $(bc <<< "$? == 0")
cleos push action fraxfitokens transfer '["dcbtestuserb", "fraxreserves", "1000.0000 FXS", "deposit FXS"]' -p dcbtestuserb
assert $(bc <<< "$? == 0")

NEW_BALANCE1=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')
NEW_BALANCE2=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep USDT | tr -d '"' | awk '{ print $2 }')
NEW_BALANCE3=$(cleos get table fraxreserves dcbtestusera accounts | jq '.rows[]' | grep FXS | tr -d '"' | awk '{ print $2 }')
NEW_BALANCE4=$(cleos get table fraxreserves dcbtestuserb accounts | jq '.rows[]' | grep FXS | tr -d '"' | awk '{ print $2 }')

assert $(bc <<< "$NEW_BALANCE1 - $OLD_BALANCE1 == 2000")
assert $(bc <<< "$NEW_BALANCE2 - $OLD_BALANCE2 == 3000")
assert $(bc <<< "$NEW_BALANCE3 - $OLD_BALANCE3 == 1000")
assert $(bc <<< "$NEW_BALANCE4 - $OLD_BALANCE4 == 1000")

echo -e "${CYAN}-----------------------DEPOSIT UNSUPPORTED TOKENS-----------------------${NC}"
cleos transfer dcbtestusera fraxreserves "1 EOS" "deposit EOS"
assert $(bc <<< "$? == 1")
cleos push action everipediaiq transfer '["dcbtestusera", "fraxreserves", "1000.000 IQ", "deposit IQ"]' -p dcbtestusera
assert $(bc <<< "$? == 1")
cleos push action fraxfitokens transfer '["dcbtestusera", "fraxreserves", "1000.0000 FRAX", "deposit FRAX"]' -p dcbtestusera
assert $(bc <<< "$? == 1")


echo -e "${CYAN}-----------------------SET FULLY-BACKED TARGET-----------------------${NC}"
cleos push action fraxreserves settarget '["2000.0000 USDT", "0.0000 FXS", 1e4]' -p fraxreserves
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------BUY FRAX WITH USDT-----------------------${NC}"
#OLD_FRAX_BALANCE1=$(cleos get table fraxfitokens dcbtestusera accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
#OLD_FRAX_BALANCE2=$(cleos get table fraxfitokens dcbtestuserb accounts | jq '.rows[]' | grep FRAX | tr -d '"' | awk '{ print $2 }')
OLD_FRAX_BALANCE1=0
OLD_FRAX_BALANCE2=0
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

echo $OLD_FRAX_BALANCE1
echo $OLD_FRAX_BALANCE2
echo $OLD_USDT_BALANCE1
echo $OLD_USDT_BALANCE2
echo $NEW_FRAX_BALANCE1
echo $NEW_FRAX_BALANCE2
echo $NEW_USDT_BALANCE1
echo $NEW_USDT_BALANCE2
assert $(bc <<< "$NEW_FRAX_BALANCE1 - $OLD_FRAX_BALANCE1 == 1000")
assert $(bc <<< "$NEW_FRAX_BALANCE2 - $OLD_FRAX_BALANCE2 == 1000")
assert $(bc <<< "$OLD_USDT_BALANCE1 - $NEW_USDT_BALANCE1 == 1000")
assert $(bc <<< "$OLD_USDT_BALANCE2 - $NEW_USDT_BALANCE2 == 1000")

echo -e "${CYAN}-----------------------SET PARTIALLY-BACKED TARGET-----------------------${NC}"
cleos push action fraxreserves settarget '["4000.0000 USDT", "10.0000 FXS", 1e4]' -p fraxreserves
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
cleos push action fraxreserves buyfrax '["dcbtestuserb", "100.0000 FRAX"]' -p dcbtestuserb
assert $(bc <<< "$? == 1")
# not enough USDT
cleos push action fraxreserves buyfrax '["dcbtestusera", "10000.0000 FRAX"]' -p dcbtestusera
assert $(bc <<< "$? == 1")
