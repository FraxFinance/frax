import ScatterJS from '@scatterjs/core';
import ScatterEOS from '@scatterjs/eosjs2';
import {JsonRpc, Api} from 'eosjs';

ScatterJS.plugins( new ScatterEOS() );

const network = ScatterJS.Network.fromJson({
    blockchain:'eos',
    chainId:'aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906',
    host:'nodes.get-scatter.com',
    port:443,
    protocol:'https'
});
const rpc = new JsonRpc(network.fullhost());

let eos; 
let account;
const scatter = ScatterJS.scatter;

function updateBalances () {
    // Get Contract Deposit Data
    fetch("https://mainnet.libertyblock.io:7777/v1/chain/get_table_rows", {
        method: "POST",
        body: JSON.stringify({
            code: "fraxreserves",
            scope: scatter.identity.accounts[0].name,
            table: "accounts",
            json: true
        })
    })
    .then(response => response.json())
    .then(json => {
        json.rows.forEach(function (row) {
            if (row.balance.includes("USDT"))
                document.getElementById('usdt-contract').textContent = row.balance.split(' ')[0];
            else if (row.balance.includes("FXS"))
                document.getElementById('fxs-contract').textContent = row.balance.split(' ')[0];
            else if (row.balance.includes("FRAX"))
                document.getElementById('frax-contract').textContent = row.balance.split(' ')[0];
        });
    })
    .catch(console.error);

    // Get Frax Tokens Balance Data
    fetch("https://mainnet.libertyblock.io:7777/v1/chain/get_table_rows", {
        method: "POST",
        body: JSON.stringify({
            code: "fraxfitokens",
            scope: scatter.identity.accounts[0].name,
            table: "accounts",
            json: true
        })
    })
    .then(response => response.json())
    .then(json => {
        json.rows.forEach(function (row) {
            if (row.balance.includes("FXS"))
                document.getElementById('fxs-balance').textContent = row.balance.split(' ')[0];
            else if (row.balance.includes("FRAX"))
                document.getElementById('frax-balance').textContent = row.balance.split(' ')[0];

        });
    })
    .catch(console.error);
    
    // Get Tether Tokens Balance Data
    fetch("https://mainnet.libertyblock.io:7777/v1/chain/get_table_rows", {
        method: "POST",
        body: JSON.stringify({
            code: "tethertether",
            scope: scatter.identity.accounts[0].name,
            table: "accounts",
            json: true
        })
    })
    .then(response => response.json())
    .then(json => {
        json.rows.forEach(function (row) {
            if (row.balance.includes("USDT"))
                document.getElementById('usdt-balance').textContent = row.balance.split(' ')[0];
        });
    })
    .catch(console.error);
}

// Login to Scatter
scatter.connect('Frax').then(connected => {
    document.getElementById('checking-scatter-alert').style.display = 'none';
    if(!connected) {
        // Scatter isn't open
        document.getElementById('no-scatter-alert').style.display = 'block';
    }
    else if (scatter.identity) {
        // Scatter is open and user has previously logged in
        document.getElementById('welcome-user-alert').textContent = `Welcome ${scatter.identity.accounts[0].name}!`;
        document.getElementById('welcome-user-alert').style.display = 'block';
    }
    else {
        // Scatter is open and user has not previously logged in
        document.getElementById('login-scatter').style.display = 'block';
        document.getElementById('login-scatter').addEventListener('click', function () {
            scatter.getIdentity({ accounts: [network] }).then(id => {
                if(!id) return console.error('no identity');
                document.getElementById('login-scatter').style.display = 'none';
                document.getElementById('welcome-user-alert').textContent = `Welcome ${id.accounts[0]}!`;
                document.getElementById('welcome-user-alert').style.display = 'block';
            })
        });
    }

    updateBalances();
    eos = ScatterJS.eos(network, Api, {rpc});

});

// Deposit USDT
document.getElementById('deposit-usdt').addEventListener('click', function () {
    const quantity = document.getElementById("usdt-amount").valueAsNumber.toFixed(4);
    if (quantity <= 0) return false;
    eos.transact({
        actions: [{
            account: 'tethertether',
            name: 'transfer',
            authorization: [{
                actor: scatter.identity.accounts[0].name,
                permission: scatter.identity.accounts[0].authority,
            }],
            data: {
                from: scatter.identity.accounts[0].name,
                to: "fraxreserves",
                quantity: quantity + " USDT",
                memo: "deposit USDT"
            },
        }]
    }, {
        blocksBehind: 3,
        expireSeconds: 30,
    }).then(res => {
       document.getElementById('tx-error-alert').style.display = 'none';
       updateBalances();
    }).catch(err => {
       document.getElementById('tx-error-alert').style.display = 'block'; 
    });
});

// Deposit FXS
document.getElementById('deposit-fxs').addEventListener('click', function () {
    const quantity = document.getElementById("fxs-amount").valueAsNumber.toFixed(4);
    if (quantity <= 0) return false;
    eos.transact({
        actions: [{
            account: 'fraxfitokens',
            name: 'transfer',
            authorization: [{
                actor: scatter.identity.accounts[0].name,
                permission: scatter.identity.accounts[0].authority,
            }],
            data: {
                from: scatter.identity.accounts[0].name,
                to: "fraxreserves",
                quantity: quantity + " FXS",
                memo: "deposit FXS"
            },
        }]
    }, {
        blocksBehind: 3,
        expireSeconds: 30,
    }).then(res => {
       document.getElementById('tx-error-alert').style.display = 'none';
       updateBalances();
    }).catch(err => {
       document.getElementById('tx-error-alert').style.display = 'block'; 
    });
});

// Buy FRAX
document.getElementById('mint-frax').addEventListener('click', function () {
    const quantity = document.getElementById("frax-amount").valueAsNumber.toFixed(4);
    console.log(quantity);
    if (quantity <= 0) return false;
    eos.transact({
        actions: [{
            account: 'fraxreserves',
            name: 'buyfrax',
            authorization: [{
                actor: scatter.identity.accounts[0].name,
                permission: scatter.identity.accounts[0].authority,
            }],
            data: {
                buyer: scatter.identity.accounts[0].name,
                frax: quantity + " FRAX",
            },
        }]
    }, {
        blocksBehind: 3,
        expireSeconds: 30,
    }).then(res => {
        document.getElementById('tx-error-alert').style.display = 'none';
        updateBalances();
    }).catch(err => {
        document.getElementById('tx-error-alert').style.display = 'block'; 
        console.error(err);
    });
});
