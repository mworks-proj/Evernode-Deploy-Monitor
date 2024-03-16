// MAIN file to send EVR to XAHAU Wallet

// This Script will cycle through an array of addresses, get their EVR balance
// then send all of the EVR balance to a single receiving address with TAG.
// This script is designed to use a single signing address where all nodes
// have set their Regular Key to the signing address.
// To set the Regular Key for a node..on each node issue the command from the terminal
// $ evernode regkey set rWalletAddressThatYouOwnThatCanSignTransactions, 
// the secret for this address is set below

//create client to connect to xahau blockchain RPC server
const { XrplClient } = require('xrpl-client')
const lib = require('xrpl-accountlib');
const { exit } = require('process');
//const path = require('path')

const fs = require('fs')
const { createTransport } = require('nodemailer');


//get variables from .env files
//const env = require("dotenv").config({path:".env"});
//const env = require("dotenv").config({path: __dirname + '.env'})
const path = require('path');
const { ALPN_ENABLED } = require('constants');
require('dotenv').config({ path: path.resolve(__dirname, '.env') })

//accounts = your Node Wallets r Addresses 
//replace with one or more of your rAddresses for each node in .env file
const accounts = process.env.accounts.split('\n');

//Signing Wallet which is set as Regular Key for all Nodes
//set secret in .env file from regular key set for nodes
const secret = process.env.secret;
const keypair = lib.derive.familySeed(secret)

//connect to xahau blockchain WSS server
const xahaud = process.env.xahaud;
const client = new XrplClient(xahaud);

const minutes_from_last_heartbeat_alert_threshold =   process.env.minutes_from_last_heartbeat_alert_threshold;
const alert_repeat_interval_in_minutes =   process.env.alert_repeat_interval_in_minutes;
const xah_balance_threshold =   process.env.xah_balance_threshold;
const refund_amount =   process.env.alert_minutes;

const smtpKey =   process.env.smtpKey;
const smtpEmail =   process.env.smtpEmail;

const transporter = createTransport({
  host: "smtp-relay.sendinblue.com",
  port: 587,
  auth: {
      user: smtpEmail,
      pass: smtpKey,
  },
});


const heartbeatAccount =   process.env.heartbeatAccount;

const wallets = []

const myDate = new Date().toUTCString();


const transfer_funds = async () => {
    for(const account of accounts) {
      //console.log('\nGetting ready...'); 
   
        const { account_data } = await client.send({ command:"account_info", account })
        //console.log('Printing Account INFO...');

        //console.log(account); //print address
        //console.log(account_data); // FULL Output

    ////GET Trustline Details - Get EVR Balance
    // Ensure only ONE Trustline per node wallet which is set to EVERNODE
    // currency: EVR
    // issuer: rEvernodee8dJLaFsujS6q1EiXvZYmHXr8
      let marker = ''
      const l = []
      var balance = 0
      while (typeof marker === 'string') {
        const lines = await client.send({ command: 'account_lines', account, marker: marker === '' ? undefined : marker })
        marker = lines?.marker === marker ? null : lines?.marker
        //console.log(`Got ${lines.lines.length} results`)
        lines.lines.forEach(t => {

            //t is the details for the EVR trustline to evernode and the balance
            console.log(account,',',t.balance)

            l.push(t.account) // t.account = evernode wallet trustline issuer NOT USED
            wallets.push(account, t.balance)

            balance = t.balance
        })
      }

      //check just the EVRs trustline is set
      if (l.length > 1) {
        console.log('# TOO MANY Trust Lines:', l.length, '\n\n')
        exit();
      }

       //check just the EVRs balance is > 0 if not go to start of for loop with continue
      if (balance <= 0) {
        console.log('# Evr Balance TOO LOW:', balance)
        continue;
      }

    
    //Destination Adress and TAG set in.env file
    const destination = process.env.destination;
    const tag = process.env.tag;

    //send all funds to your chosen Exchange, Xaman or other Xahau account 
    const tx = {
      TransactionType: 'Payment',
      Account: account,
      Amount: {
          "currency": "EVR",
          "value": balance, //*** Change to balance (no quotes) or use "0.01" for testing low payment
          "issuer": "rEvernodee8dJLaFsujS6q1EiXvZYmHXr8" //DO NOT CHANGE - this is the EVR Trustline Issuer address
      },
      //Destination: 'rYourWalletYouControl'
      Destination: destination, //your exchnage or xaman wallet address
      DestinationTag: tag, //*** set to YOUR exchange wallet TAG Note: no quotes << do not forget to set TAG
      Fee: '12', //12 drops aka 0.000012 XAH, Note: Fee is XAH NOT EVR
      NetworkID: '21337', //XAHAU Production ID
      Sequence: account_data.Sequence
    }

    const {signedTransaction} = lib.sign(tx, keypair)
    console.log(tx)

    //SUBmit sign TX to ledger
    const submit = await client.send({ command: 'submit', 'tx_blob': signedTransaction })
    console.log(submit.engine_result, submit.engine_result_message, submit.tx_json.hash)
    

    } //end of for loop
}

const monitor_heartbeat = async () => {
    
    for(const account of accounts)
    {
        await checkAccountHeartBeat(account);
    }
}

function getMinutesBetweenDates(startDate, endDate) {
  const diff = endDate - startDate;
  return (diff / 60000);
}

async function checkAccountHeartBeat(account)
  {
    const path = './.' + account + '.txt'
    var accountFailed = fs.existsSync(path);
    var date_failure = new Date();
    if(accountFailed)
    {
        date_failure = Date.parse(fs.readFileSync(path, 'utf8'));
        
        const diffMinutes = getMinutesBetweenDates(date_failure, new Date());
        console.log(diffMinutes, alert_repeat_interval_in_minutes);
        if(alert_repeat_interval_in_minutes > 0 && diffMinutes > alert_repeat_interval_in_minutes)
        {
            accountFailed = false;
        }
    } 
    let marker = '';
    const l = []; 
    while (typeof marker === 'string') {
    const  response  = await client.send({
      "id": 2,
      "command": "account_tx",
      "account": account,
      "ledger_index_min": -1,
      "ledger_index_max": -1,
    "binary": false,
    "limit": 10,
    "forward": false, marker: marker === '' ? undefined : marker 
    })
    marker = response?.marker === marker ? null : response?.marker
    // It gets the last 10 transactions and looks for the last heartbeat
    var i = 0;
    for(var tIndex = 0; tIndex<10; tIndex++)
    { 
        var transaction = response.transactions[tIndex];
        
          if(transaction.tx.Destination == heartbeatAccount ){
              var utcMilliseconds =1000 * (transaction.tx.date + 946684800);
              var transactionDate = new Date(0); // The 0 there is the key, which sets the date to the epoch
              var date = new Date();
              var now_utc = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(),
                  date.getUTCDate(), date.getUTCHours(),
                  date.getUTCMinutes(), date.getUTCSeconds());
              if(now_utc - utcMilliseconds > 1000 * 60 * minutes_from_last_heartbeat_alert_threshold)
              {
                  console.log("Handling failure for too hold heartbeat transaction, account failed = " + accountFailed );
                  await handleFailure(account, accountFailed, path);
                  return;
              }
              console.log("System running regularly " + account + "");
              if(fs.existsSync(path)) 
                  {
                      await sendSuccess(account);
                      fs.rmSync(path);
                  }
                  return;
          }
    }
    console.log("Handling failure for no heartbeat transactions, account failed = " + accountFailed);
    await handleFailure(account, accountFailed, path);
  }
}

async function handleFailure(account, accountFailed, path)
{
   if(!accountFailed) 
   {
      await sendFailure(account);
      fs.writeFileSync(path, new Date().toString())
   }
   console.log("ALERT, SYSTEM STOPPED " + account);
}

  async function sendFailure(account)
  {
      var subject = "Failure in Evernode heartbeat";
      var text = "Failure in retrieving Evernode heartbeat for account " + account;
      await sendMail(subject, text);
  }

  async function sendSuccess(account)
  {
    var subject = "Evernode heartbeat restored";
    var text = "Evernode heartbeat restored in account " + account;
    await sendMail(subject, text);
  }

  async function sendMail(subject, text)
  {
      var mailOptions = {
          from: smtpEmail,
          to: smtpEmail,
          subject: subject,
          text: text
      };
      console.log("SENDING MAIL " + JSON.stringify(mailOptions));
      transporter.sendMail(mailOptions, function(error, info){
        if (error) {
            console.log(error);
        } else {
            console.log('Email sent: ' + info.response);
        }
    }); 
  }

  const main = async () => {
    await transfer_funds();
    await monitor_heartbeat();
    console.log('Shutting down...');

    client.close()
  };

  main()

