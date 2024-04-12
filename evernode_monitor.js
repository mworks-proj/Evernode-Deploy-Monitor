const { XrplClient } = require('xrpl-client')
const lib = require('xrpl-accountlib');
const { exit } = require('process');

const fs = require('fs')
const { createTransport } = require('nodemailer');


const path = require('path');
const { ALPN_ENABLED } = require('constants');
const { Console } = require('console');
require('dotenv').config({ path: path.resolve(__dirname, '.env') })

const verboseLog = process.env.verboseLog == "true";

const consoleLog = (msg) => {
    console.log(new Date().toISOString() + " " + msg)
  
}

const logVerbose = (msg) => {
  if (verboseLog) {
    consoleLog(msg)
  }
}

logVerbose("Original account string = " + process.env.accounts);
logVerbose("accounts length after split = " + process.env.accounts.split('\n').length);

const accounts = process.env.accounts.split('\n');
const xahaudServers = [];

const evrDestinationAccount = process.env.evrDestinationAccount;

const evrDestinationAccountTag = process.env.evrDestinationAccountTag;

const xahSourceAccount = process.env.xahSourceAccount;

var secret = "";
var keypair;
if (process.env.secret) {
  secret = process.env.secret;
  lib.derive.familySeed(secret);
  keypair = lib.derive.familySeed(secret)
}
const run_evr_withdrawal = process.env.run_evr_withdrawal == "true";
const run_xah_balance_monitor = process.env.run_xah_balance_monitor == "true";
const run_heartbeat_monitor = process.env.run_heartbeat_monitor == "true";
const run_xahaud_monitor = process.env.run_xahaud_monitor == "true";

logVerbose("run_xahaud_monitor = " + run_xahaud_monitor);

const xahaud = process.env.xahaud;
const client = new XrplClient(xahaud);

const minutes_from_last_heartbeat_alert_threshold = process.env.minutes_from_last_heartbeat_alert_threshold;
const alert_repeat_interval_in_minutes = process.env.alert_repeat_interval_in_minutes;
const xah_balance_threshold = process.env.xah_balance_threshold * 1000000;
const refill_amount = process.env.refill_amount * 1000000;

const smtpKey = process.env.smtpKey;
const smtpEmail = process.env.smtpEmail;

const destinationEmail = process.env.destinationEmail || process.env.smtpEmail;

const transporter = createTransport({
  host: "smtp-relay.sendinblue.com",
  port: 587,
  auth: {
    user: smtpEmail,
    pass: smtpKey,
  },
});


const heartbeatAccount = process.env.heartbeatAccount;

const myDate = new Date().toUTCString();


const monitor_balance = async () => {

  consoleLog("Monitoring the account XAH balance...");

  var sourceAccountId = accounts[0];
  var sourceAccount = null;
  var sequence = 0;


  for (const account of accounts) {

    const { account_data } = await client.send({ command: "account_info", account: account });

    var sourceData = await client.send({ command: "account_info", account: xahSourceAccount });

    var sequence = sourceData.account_data.Sequence;

    if (account != xahSourceAccount) {
        logVerbose("Balance for account " + account + " is " + account_data.Balance);
      if (parseInt(account_data.Balance) < xah_balance_threshold) {
        const filePath = path.resolve(__dirname, 'balanceLow-' + account + '.txt');
        consoleLog("Account balance for " + account + " is " + account_data.Balance + ", sending funds");
        consoleLog("Source account balance = " + sourceData.account_data.Balance);
        if (sourceData.account_data.Balance < xah_balance_threshold) {
          consoleLog("Not enough funds in first account to fill other accounts");
          if (!fs.existsSync(filePath)) {
            await sendMail("Insufficient funds", "We tried to send XAH to " + account + " but the balance in " + xahSourceAccount + " is too low.\r\n\r\nPlease feed your source account.");
            fs.writeFileSync(filePath, "Balance is too low");
          }
        }
        else {

          const tx = {
            TransactionType: 'Payment',
            Account: xahSourceAccount,  //Destination account is use to fillEvernode accounts
            Amount: (refill_amount).toString(),
            //Destination: 'rYourWalletYouControl'
            Destination: account_data.Account, //the account that has to be filled
            DestinationTag: "", //*** set to YOUR exchange wallet TAG Note: no quotes << do not forget to set TAG
            Fee: '12', //12 drops aka 0.000012 XAH, Note: Fee is XAH NOT EVR
            NetworkID: '21337', //XAHAU Production ID
            Sequence: sequence
          }

          const { signedTransaction } = lib.sign(tx, keypair)

          consoleLog("sending the transaction " + JSON.stringify(tx));
          //SUBmit sign TX to ledger
          const submit = await client.send({ command: 'submit', 'tx_blob': signedTransaction })
          consoleLog(submit.engine_result, submit.engine_result_message, submit.tx_json.hash);

          if (fs.existsSync(filePath)) fs.rmSync(filePath);

          sequence++;

        }
      }

    }
  }
}

const transfer_funds = async () => {
  consoleLog("Starting the funds transfer batch...");

  for (const account of accounts) {
    logVerbose("start the transferring process on account " + account);
    if (account != evrDestinationAccount) {
      logVerbose("getting account data on account " + account);
      const { account_data } = await client.send({ command: "account_info", account })

      let marker = ''
      const l = []
      var balance = 0
      while (typeof marker === 'string') {
        const lines = await client.send({ command: 'account_lines', account, marker: marker === '' ? undefined : marker })

        marker = lines?.marker === marker ? null : lines?.marker
        //consoleLog(`Got ${lines.lines.length} results`)
        lines.lines.forEach(t => {
          if (t.currency == "EVR") {
            logVerbose(JSON.stringify(t))

            balance = balance + t.balance

          }
        })
      }

      //check just the EVRs balance is > 0 if not go to start of for loop with continue
      if (balance <= 0) {
        logVerbose('# Evr Balance is zero in account ' + account);
        continue;
      }


      //Destination Adress and TAG set in.env file
      const tag = process.env.tag;

      //send all funds to your chosen Exchange, Xaman or other Xahau account 
      logVerbose("Balance = " + balance + ", preparing the payment transaction on account " + account);
      const tx = {
        TransactionType: 'Payment',
        Account: account,
        Amount: {
          "currency": "EVR",
          "value": balance, //*** Change to balance (no quotes) or use "0.01" for testing low payment
          "issuer": "rEvernodee8dJLaFsujS6q1EiXvZYmHXr8" //DO NOT CHANGE - this is the EVR Trustline Issuer address
        },
        //Destination: 'rYourWalletYouControl'
        Destination: evrDestinationAccount, //your exchnage or xaman wallet address
        DestinationTag: evrDestinationAccountTag, //*** set to YOUR exchange wallet TAG Note: no quotes << do not forget to set TAG
        Fee: '12', //12 drops aka 0.000012 XAH, Note: Fee is XAH NOT EVR
        NetworkID: '21337', //XAHAU Production ID
        Sequence: account_data.Sequence
      }
      logVerbose("signing the transaction on account " + account);
      const { signedTransaction } = lib.sign(tx, keypair)
      logVerbose(JSON.stringify(tx))

      //SUBmit sign TX to ledger
      consoleLog("sending the EVR payment transaction on account " + account);
      const submit = await client.send({ command: 'submit', 'tx_blob': signedTransaction })
      consoleLog("Payment sent, result = " + submit.engine_result);


    } //end of for loop
  }
}

const monitor_heartbeat = async () => {
  consoleLog("Checking account heartbeat...");
  for (const account of accounts) {
    logVerbose("checking account heartbeat on account " + account);
    await checkAccountHeartBeat(account);
  }
}

function getMinutesBetweenDates(startDate, endDate) {
  const diff = endDate - startDate;
  return (diff / 60000);
}

const monitor_xahaud_nodes = async () => {
  consoleLog("Monitoring xahaud nodes...");
  xahaudServers = process.env.xahaudServers.split('\n');
  for (const xahaudServer of xahaudServers) {
    const filePath = path.resolve(__dirname, btoa(xahaudServer) + '_xahaud.txt');
    var serverFailed = fs.existsSync(filePath);
    var date_failure = new Date();
    
    if (serverFailed) {
      date_failure = new Date(Date.parse(fs.readFileSync(filePath, 'utf8')));
      logVerbose("xahaud server " + xahaudServer + " is in status failed since " + date_failure);
      const diffMinutes = getMinutesBetweenDates(date_failure, new Date());
      if (alert_repeat_interval_in_minutes > 0 && diffMinutes > alert_repeat_interval_in_minutes) {
        serverFailed = false;
      }
    }
    var xahaudClient = new XrplClient(xahaudServer, {
      assumeOfflineAfterSeconds: 2, connectAttemptTimeoutSeconds: 2
    });
    logVerbose("pinging xahaud node " + xahaudServer);
    const tx = {
      "id": 1,
      "command": "ping"
    }
    try {
      var result = await xahaudClient.send({ command: "ping", id: 1 }, { timeoutSeconds: 2 });
      logVerbose("successfully pinged xahaud node " + xahaudServer);
      xahaudClient.close();
      if (fs.existsSync(filePath)) {
        await sendMail('Xahaud node restored', 'Xahaud node ' + xahaudServer + ' restored');
        fs.rmSync(filePath);
      }
    }
    catch (error) {
      var message = `A en error has occured while checking  ${xahaudServer}\n\nError message: ${error.message}`;
      consoleLog(message);
      if(!serverFailed)
      {
          await sendMail('Failure in checking Xahaud node', message);
          fs.writeFileSync(filePath, new Date().toString())
      }
    }
  }
}

async function checkAccountHeartBeat(account) {
  var ledgerIndex = -1;
  const filePath = path.resolve(__dirname, account + '.txt');
  var accountFailed = fs.existsSync(filePath);
  var date_failure = new Date();
  if (accountFailed) {
    date_failure = new Date(Date.parse(fs.readFileSync(filePath, 'utf8')));
    logVerbose("account " + account + " is in status failed since " + date_failure);
    const diffMinutes = getMinutesBetweenDates(date_failure, new Date());
    logVerbose("diffMinutes = " + diffMinutes);
    logVerbose("alert_repeat_interval_in_minutes = " + alert_repeat_interval_in_minutes);
    if (alert_repeat_interval_in_minutes > 0 && diffMinutes > alert_repeat_interval_in_minutes) {
      accountFailed = false;
    }
  }

  while (true) {
    let marker = '';
    const l = [];
    while (typeof marker === 'string') {
      logVerbose("getting last 5 transactions on account " + account + " with last ledger " + ledgerIndex);
      const response = await client.send({
        "id": 2,
        "command": "account_tx",
        "account": account,
        "ledger_index_min": -1,
        "ledger_index_max": ledgerIndex,
        "binary": false,
        "limit": 5,
        "forward": false, marker: marker === '' ? undefined : marker
      })
      marker = response?.marker === marker ? null : response?.marker
      // It gets the last 5 transactions and looks for the last heartbeat
      var i = 0;
      for (var tIndex = 0; tIndex < response.transactions.length; tIndex++) {
        var transaction = response.transactions[tIndex];
        ledgerIndex = transaction.tx.ledger_index - 1;
        logVerbose(JSON.stringify(transaction.tx));
        logVerbose(tIndex + " " +  2 +  " new ledgerIndex = " + ledgerIndex);
        var utcMilliseconds = 1000 * (transaction.tx.date + 946684800);
        var transactionDate = new Date(0); // The 0 there is the key, which sets the date to the epoch
        var date = new Date();
        var now_utc = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(),
          date.getUTCDate(), date.getUTCHours(),
          date.getUTCMinutes(), date.getUTCSeconds());
        if (now_utc - utcMilliseconds > 1000 * 60 * minutes_from_last_heartbeat_alert_threshold) {
          consoleLog("Handling failure for too old heartbeat transaction, account failed = " + accountFailed);
          await handleFailure(account, accountFailed, filePath);
          return;
        }
        if (transaction.tx.Destination == heartbeatAccount) {
          //consoleLog("System running regularly " + account + "");
          if (fs.existsSync(filePath)) {
            await sendSuccess(account);
            fs.rmSync(filePath);
          }
          return;
        }
      }
      if (response.transactions.length < 5) {
        consoleLog("Handling failure for no heartbeat transactions, account failed = " + accountFailed);
        await handleFailure(account, accountFailed, filePath);
        return;
      }
    }
  }
}

async function handleFailure(account, accountFailed, filePath) {
  if (!accountFailed) {
    await sendFailure(account);
    fs.writeFileSync(filePath, new Date().toString())
  }
  consoleLog("ALERT, SYSTEM STOPPED " + account);
}

async function sendFailure(account) {
  var subject = "Failure in Evernode heartbeat";
  var text = "Failure in retrieving Evernode heartbeat for account " + account;
  await sendMail(subject, text);
}

async function sendSuccess(account) {
  var subject = "Evernode heartbeat restored";
  var text = "Evernode heartbeat restored in account " + account;
  await sendMail(subject, text);
}

async function sendMail(subject, text) {
  var mailOptions = {
    from: smtpEmail,
    to: destinationEmail,
    subject: subject,
    text: text
  };
  consoleLog("SENDING MAIL " + JSON.stringify(mailOptions));

  if (!smtpEmail) {
    consoleLog("smtp email not set in .env file. Email is not sent");
    return;
  }

  await transporter.sendMail(mailOptions, function (error, info) {
    if (error) {
      consoleLog(error);
    } else {
      consoleLog('Email sent: ' + info.response);
    }
  });
}

function validate() {
  if (!accounts || accounts.length == 0 || accounts[0] == "") {
    consoleLog("no accounts set in .env file.");
    return false;
  }
  if (!secret && (run_evr_withdrawal || run_xah_balance_monitor)) {
    consoleLog("secret not set in .env file.");
    return false;
  }
  if ( run_xahaud_monitor && !process.env.xahaudServers) {
    consoleLog("no xahaud servers set in .env file.");
    return false;
  }

  return true;
}

const main = async () => {
  var valid = validate();
  if (valid) {
    if (run_evr_withdrawal) { await transfer_funds() };
    if (run_heartbeat_monitor) await monitor_heartbeat();
    if (run_xah_balance_monitor) await monitor_balance();
    if (run_xahaud_monitor) await monitor_xahaud_nodes();
  }
  client.close();
  consoleLog('Shutting down...');
  // Workaround so all queued emails are sent. 
  // I had to explicitly call the exit() function as the application was not stopping 
  // in case of Xahaud request failure, I don't know why. 
  setTimeout(function () {
    exit();
  }, 10000);
};

main()