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
ScatterJS.connect('Frax', {network}).then(connected => {
    document.getElementById('checking-scatter-alert').style.display = 'none';
    console.log(connected);
    if(!connected) {
        document.getElementById('no-scatter-alert').style.display = 'block';
    }
    else {
        document.getElementById('login-scatter').style.display = 'block';
    }

    eos = ScatterJS.eos(network, Api, {rpc});

    ScatterJS.login().then(id => {
        if(!id) return console.error('no identity');
        account = ScatterJS.account('eos');
    })
});

//eos.transact({
//    actions: [{
//        account: 'eosio.token',
//        name: 'transfer',
//        authorization: [{
//            actor: account.name,
//            permission: account.authority,
//        }],
//        data: {
//            from: account.name,
//            to: 'safetransfer',
//            quantity: '0.0001 EOS',
//            memo: account.name,
//        },
//    }]
//}, {
//    blocksBehind: 3,
//    expireSeconds: 30,
//}).then(res => {
//    console.log('sent: ', res);
//}).catch(err => {
//    console.error('error: ', err);
//});
