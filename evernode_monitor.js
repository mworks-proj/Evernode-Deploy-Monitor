const { XrplClient } = require('xrpl-client')
const lib = require('xrpl-accountlib');
const { exit } = require('process');
const { createTransport } = require('nodemailer');
const { ALPN_ENABLED } = require('constants');
const { Console } = require('console');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '.env') });


// log setup  ......................................................................
const verboseLog = process.env.verboseLog === 'true' ? true : false;
const consoleLog = (msg) => {
    console.log(new Date().toISOString() + " " + msg)
}
const logVerbose = (msg) => {
  if (verboseLog) {
    consoleLog(msg)
  }
}

//...............................................................................................................................................................................................
// varible setups  ..............................................................................................................................................................................

const command = process.argv.slice(2)[0];
const run_wallet_setup = process.env.run_wallet_setup === 'true' ? true : false;
const run_transfer_funds = process.env.run_transfer_funds === 'true' ? true : false;
const run_monitor_balance = process.env.run_monitor_balance === 'true' ? true : false;
const run_monitor_heartbeat = process.env.run_monitor_heartbeat === 'true' ? true : false;
const use_testnet = process.env.use_testnet === 'true' ? true : false;

const evrSetupamount = process.env.evrSetupamount;
const xahSetupamount = process.env.xahSetupamount;
const feeStartAmount = process.env.fee;
const auto_adjust_fee = process.env.auto_adjust_fee === 'true' ? true : false;
const fee_adjust_amount = process.env.fee_adjust_amount;
const minutes_from_last_heartbeat_alert_threshold = process.env.minutes_from_last_heartbeat_alert_threshold;
const alert_repeat_interval_in_minutes = process.env.alert_repeat_interval_in_minutes;
const xah_balance_threshold = process.env.xah_balance_threshold * 1000000;
const evr_balance_threshold = process.env.evr_balance_threshold * 1;
const minimum_evr_transfer = process.env.minimum_evr_transfer * 1;
const refill_amount = process.env.refill_amount * 1000000;
const evr_refill_amount = process.env.evr_refill_amount * 1 ;

let xahaud, network_id, trustlineAddress, heartbeatAccount, heartbeatClient, client;
async function networkSetup(){
  if (use_testnet) {
    logVerbose("using testnet varibles");
    xahaud = await process.env.xahaud_test;
    network = "testnet"
    network_id = "21338";
    trustlineAddress="r9gYbjBfANRfA1JHfaCVfPPGfXYiqQvmhS";
    heartbeatAccount = await process.env.heartbeatAccount_testnet;
  } else {
    logVerbose("using mainnet varibles");
    xahaud = await process.env.xahaud;
    network = "mainnet"
    network_id = "21337";
    trustlineAddress="rEvernodee8dJLaFsujS6q1EiXvZYmHXr8";
    heartbeatAccount = await process.env.heartbeatAccount;
  }
  client = await new XrplClient(xahaud);

  // setup evernode.js.client
  const evernode = require('evernode-js-client');
  await evernode.Defaults.useNetwork(network)
  await evernode.Defaults.set({ rippledServer: xahaud });
  heartbeatClient = await evernode.HookClientFactory.create(evernode.HookTypes.heartbeat);
}

// email setup  ......................................................................

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
const myDate = new Date().toUTCString();

// account handling  ....................................................................

let accounts = [];
let accounts_seed = [];
let keypair = ""
let xahSourceAccount;
let evrDestinationAccount = "";
let evrDestinationAccountTag = "";
async function getAccounts() {
  consoleLog("gettings accounts...");
  const use_keypair_file = process.env.use_keypair_file;
  const keypair_file = process.env.keypair_file;
  if (use_keypair_file) {
    try {
      logVerbose("using key_pair.txt for accounts");
      const data = await fs.promises.readFile(keypair_file, 'utf8');
      accounts = await data.match(/Address:\s([a-zA-Z0-9]+)/g).map(match => match.split(' ')[1]);
      accounts_seed = await data.match(/Seed:\s([a-zA-Z0-9]+)/g).map(match => match.split(' ')[1]);
      logVerbose("accounts string = " + accounts);
      logVerbose("accounts length = " + accounts.length);
      xahSourceAccount = accounts[0];
      evrDestinationAccount = accounts[0];
      evrDestinationAccountTag = "";
      reputationAccounts = accounts[1]
      var secret = accounts_seed[0];
      keypair = lib.derive.familySeed(secret);
    } catch (err) {
      console.error('Error reading key_pair.txt file:', err);
      accounts = [];
    }
  } else {
    logVerbose("using .env file for accounts");
    xahSourceAccount = process.env.xahSourceAccount;
    evrDestinationAccount = process.env.evrDestinationAccount;
    evrDestinationAccountTag = process.env.evrDestinationAccountTag;
    accounts = process.env.accounts.split('\n');
    logVerbose("accounts string = " + accounts);
    logVerbose("accounts length = " + accounts.length);
    if (process.env.secret) {
      var secret = process.env.secret;
      keypair = lib.derive.familySeed(secret);
    } else {
      console.error('Error reading secret from .env file');
    }
  }
}

var reputationAccounts =[];
if(process.env.reputationAccounts != "") {
  reputationAccounts = process.env.reputationAccounts.split('\n');
  logVerbose("populating reputationAccounts -->", reputationAccounts)
}

//...............................................................................................................................................................................................
// Main balance monitor  ........................................................................................................................................................................

async function monitor_balance(){
  console.log(" ---------------- ");
  consoleLog("Monitoring the account XAH balance...");

  var sequence = 0;
  if (reputationAccounts != [] ) {
    var allAccounts = accounts.concat(reputationAccounts);
  } else {
    logVerbose("no reputation accounts to check")
    var allAccoounts = acounts;
  }

  logVerbose("accounts = " + allAccounts.length);
  for (const account of allAccounts) {

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
            Account: xahSourceAccount, 
            Amount: (refill_amount).toString(),
            Destination: account_data.Account, 
            DestinationTag: evrDestinationAccountTag,
            Fee: feeAmount, 
            NetworkID: network_id,
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
      } else {
        logVerbose("Balance for account " + account + " is " + account_data.Balance + " below threshold");
      }

    }
  }

  if (reputationAccounts != [] ) {
    for (const account of reputationAccounts) {

      const { account_data } = await client.send({ command: "account_info", account: account });

      var sourceData = await client.send({ command: "account_info", account: xahSourceAccount });

      var sequence = sourceData.account_data.Sequence;

      if (account != xahSourceAccount) {
        var balance = await GetEvrBalance(account);
        var sourceBalance = await GetEvrBalance(xahSourceAccount);
        
        logVerbose("EVR Balance for account " + account + " is " + balance);
        logVerbose("EVR Balance for source account " + xahSourceAccount + " is " + sourceBalance);
        if (parseInt(balance) < evr_balance_threshold) {
          const filePath = path.resolve(__dirname, 'balanceLow-' + account + '.txt');
          
          consoleLog("Account EVR balance for " + account + " is " + balance + ", sending funds");
          
          if (sourceBalance < evr_refill_amount) {
            consoleLog("Not enough funds in first account to fill other accounts with EVR");
            logVerbose("sourceBalance in EVR " + sourceBalance);
            logVerbose("evr_refill_amount =  " + evr_refill_amount);
            if (!fs.existsSync(filePath)) {
              await sendMail("Insufficient EVR funds", "We tried to send EVR to " + account + " but the balance in " + xahSourceAccount + " is too low.\r\n\r\nPlease feed your source account.");
              fs.writeFileSync(filePath, "EVR Balance is too low");
            }
          }
          else {

            const tx = { 
              TransactionType: 'Payment',
              Account: xahSourceAccount,  //Destination account
              Amount: {
                "currency": "EVR",
                "value": evr_refill_amount,
                "issuer": trustlineAddress 
              },
              Destination: account, //the account that has to be filled
              DestinationTag: evrDestinationAccountTag, 
              Fee: feeAmount,
              NetworkID: network_id,
              Sequence: sequence
            }

            const { signedTransaction } = lib.sign(tx, keypair)

            consoleLog("sending the EVR transaction " + JSON.stringify(tx));
            const submit = await client.send({ command: 'submit', 'tx_blob': signedTransaction })
            consoleLog(submit.engine_result, submit.engine_result_message, submit.tx_json.hash);

            if (fs.existsSync(filePath)) fs.rmSync(filePath);

            sequence++;

          }
        } else {
          consoleLog("Account EVR balance for " + account + " is " + balance + " below threshold");
        }

      }
    }
  }
}

async function GetEvrBalance(account){
  logVerbose("getting the EVR balance for " + account);
  let marker = ''
  const l = []
  var balance = 0
  while (typeof marker === 'string') {
    const lines = await client.send({ command: 'account_lines', account, marker: marker === '' ? undefined : marker })

    marker = lines?.marker === marker ? null : lines?.marker
    //consoleLog(`Got ${lines.lines.length} results`)
    lines.lines.forEach(t => {
      if (t.currency == "EVR" && t.account == trustlineAddress) {
        logVerbose(JSON.stringify(t))

        balance = parseFloat(balance) + parseFloat(t.balance);
        logVerbose("EVR balance for account " + account + " increased by " + t.balance);
      }
    })
  }
  return balance;
}

//.................................................................................................................................................................................................
// Fund Sweeper  ..................................................................................................................................................................................

async function transfer_funds(){
  console.log(" ---------------- ");
  consoleLog("Starting the funds transfer batch...");

  for (const account of accounts) {
    logVerbose("start the transferring process on account " + account);
    if (account != evrDestinationAccount) {
      var { account_data } = await client.send({ command: "account_info", account })
      var tesSUCCESS = true;
      var attempt = 1;
      var feeAmount = feeStartAmount;

      while (true) {
        // auto fee calculations
        let feeResponse = await client.send({ command: 'fee' });
        if ( feeResponse.drops.open_ledger_fee > feeAmount && auto_adjust_fee == true ) { feeAmount = ( parseInt(feeResponse.drops.open_ledger_fee) + parseInt(fee_adjust_amount) ).toString() };
        logVerbose("account_data -- >" + JSON.stringify(account_data) + "\nfee calculations --> feeStartAmount:" + feeStartAmount + " feeAmount:" + feeAmount + " feeResponse:" + JSON.stringify(feeResponse));

        // sweep XAH
        if ( process.env.xah_transfer == "true" && parseInt(account_data.Balance) > 4000000 ) {
          const XAHtx = {
            TransactionType: 'Payment',
            Account: account,
            Amount: (account_data.Balance - 4000000).toString(),
            Destination: evrDestinationAccount,
            Fee: feeAmount,
            NetworkID: network_id,
            Sequence: account_data.Sequence++
          };
          const { signedTransaction: signedXAH } = lib.sign(XAHtx, keypair)
          const XAHsubmit = await client.send({ command: 'submit', 'tx_blob': signedXAH });
          if (XAHsubmit.engine_result !== "tesSUCCESS" ) {
            tesSUCCESS = false;
            consoleLog("XAH paymentSweep FAILED TO SEND, " + (account_data.Balance - 2000000) + "XAH " + account + " > xx " + evrDestinationAccount + ", result: " + XAHsubmit.engine_result);
          } else {   
          consoleLog("XAH paymentSweep sent, " + (account_data.Balance - 2000000) + "XAH " + account + " --> " + evrDestinationAccount + ", result: " + XAHsubmit.engine_result);
          };
        } else {
          consoleLog("XAH Balance is " + account_data.Balance + " XAH, either you have XAH sweep turned off, or its below 4 XAH which is minumum required to sweep XAH funds, skipping account...");
        }

        
        // fee check
        feeResponse = await client.send({ command: 'fee' });
        if ( feeResponse.drops.open_ledger_fee > feeAmount && auto_adjust_fee == true ) { feeAmount = ( parseInt(feeResponse.drops.open_ledger_fee) + parseInt(fee_adjust_amount) ).toString()};

        // sweep EVR
        let marker = ''
        const l = []
        var balance = 0
        // check EVR exsists, and get EVR balance
        while (typeof marker === 'string') {
          const lines = await client.send({ command: 'account_lines', account, marker: marker === '' ? undefined : marker })
          marker = lines?.marker === marker ? null : lines?.marker
          //consoleLog(`Got ${lines.lines.length} results`)
          lines.lines.forEach(t => {
            if (t.currency == "EVR" && t.account == trustlineAddress) {
              logVerbose("line data -->" + JSON.stringify(t));
              balance = parseFloat(balance) + parseFloat(t.balance);
            }
          })
        };

        // check if the EVR balance is enough to sweep
        if (balance <= minimum_evr_transfer) {
          consoleLog("EVR Balance is " + balance + " EVR, below minumum required of " + minimum_evr_transfer + " to sweep EVR funds, skipping account...");
        } else {
          // sweep EVR to evrDestinationAccount
          const EVRtx = {
            TransactionType: 'Payment',
            Account: account,
            Amount: {
              "currency": "EVR",
              "value": balance,
              "issuer": trustlineAddress
            },
            Destination: evrDestinationAccount,
            DestinationTag: evrDestinationAccountTag,
            Fee: feeAmount,
            NetworkID: network_id,
            Sequence: account_data.Sequence++
          }
          const { signedTransaction: signedEVR } = lib.sign(EVRtx, keypair)
          const EVRsubmit = await client.send({ command: 'submit', 'tx_blob': signedEVR })
          if (EVRsubmit.engine_result !== "tesSUCCESS" ) {
            tesSUCCESS = false;
            consoleLog("EVR paymentSweep FAILED TO SEND, " + balance + "EVR " + account + " > xx " + evrDestinationAccount + ", result: " + EVRsubmit.engine_result);
          } else {   
          consoleLog("EVR paymentSweep sent, " + balance + "EVR " + account + " --> " + evrDestinationAccount + ", result: " + EVRsubmit.engine_result);
          };
        }

        if ( tesSUCCESS == true ) {
          break 
        } else { 
          attempt++;
          if ( attempt > 4 ) { process.exit() };
          logVerbose("\nsomething failed, retying, " + attempt + " of 4");
        };
      }

    } else {
      logVerbose("skipping as its the source account.");
    };
    consoleLog(" ---------------- ");
    consoleLog(" ");
  }
}

//.................................................................................................................................................................................................
// Main heartbeat monitor  ........................................................................................................................................................................

async function monitor_heartbeat() {
  console.log(" ---------------- ");
  consoleLog("Checking account heartbeat...");
  heartbeatClientstatus = await heartbeatClient.connect();
  logVerbose("connecting to ledger/evernode registry, status:" + heartbeatClientstatus);

  var accountIndex = 1;
  for (const account of accounts) {
    consoleLog("checking account heartbeat on account " + account);
    await checkAccountHeartBeat(account, accountIndex);
    accountIndex++;
    consoleLog(" ---------------- ");
  }
  heartbeatClientstatus = await heartbeatClient.disconnect();
  logVerbose("all finished, disconnecting to ledger/evernode registry, status:" + heartbeatClientstatus);
}

function getMinutesBetweenDates(startDate, endDate) {
  const diff = endDate - startDate;
  return (diff / 60000);
}

async function checkAccountHeartBeat(account, accountIndex) {
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
    const hostInfo = await heartbeatClient.getHostInfo(account);
    let currentTimestamp = Math.floor(Date.now() / 1000);
    if (hostInfo){logVerbose("hostInfo ->" + hostInfo.lastHeartbeatIndex)} else { logVerbose("hostinfo ->not found") };
    logVerbose("time now -->" + currentTimestamp);

    if (!hostInfo || (currentTimestamp - hostInfo.lastHeartbeatIndex > 60 * minutes_from_last_heartbeat_alert_threshold)) {
      consoleLog("Handling failure for too old heartbeat transaction, previous data foe account? :" + accountFailed);
      await handleFailure(account, accountFailed, filePath, accountIndex);
      return;
    } else {
      const hoursElapsed = Math.floor((currentTimestamp - hostInfo.lastHeartbeatIndex)/ 3600);
      const minutesElapsed = Math.floor(((currentTimestamp - hostInfo.lastHeartbeatIndex) % 3600) / 60);
      consoleLog("heartbeat on this account looks good, last heartbeat was " + hoursElapsed + " hours and " + minutesElapsed + " minuets ago.");
      if (fs.existsSync(filePath)) {
        await sendSuccess(account, accountIndex);
        fs.rmSync(filePath);
      }
      return;
    }
  }
}

// HEARTBEAT failure handling  ........................................................................................................................................................................

async function handleFailure(account, accountFailed, filePath, accountIndex) {
  if (!accountFailed) {
    await sendFailure(account, accountIndex);
    fs.writeFileSync(filePath, new Date().toString())
  }
  consoleLog("ALERT, SYSTEM STOPPED " + account);
}

// HEARBEAT email handling  ........................................................................................................................................................................

async function sendFailure(account, accountIndex) {
  var subject = "Failure in Evernode heartbeat " + accountIndex.toString();
  var text = "Failure in retrieving Evernode heartbeat for account " + account + " (" + accountIndex.toString() + ")";
  await sendMail(subject, text);
}

async function sendSuccess(account, accountIndex) {
  var subject = "Evernode heartbeat restored " +  accountIndex.toString();
  var text = "Evernode heartbeat restored in account " + account + " (" + accountIndex.toString() + ")";
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

//...............................................................................................................................................................................................
// Initial wallet setup  ........................................................................................................................................................................

//const wallet_setup = async () => {
async function wallet_setup(){
  console.log(" ---------------- ");
  consoleLog("Running initial wallet setup...");

  var loop = 0;
  for (const account of accounts) {
    logVerbose("starting initial wallet setup on account " + loop + "> " + account);
    
    if (account != xahSourceAccount) {
      var tesSUCCESS = true;
      var attempt = 1;
      var feeAmount = feeStartAmount;

      // get source account data
      const { account_data: account_dataSource } = await client.send({ command: "account_info", account: xahSourceAccount });
      logVerbose("xahSourceAccount >" + xahSourceAccount + "  account_data >" + JSON.stringify(account_dataSource));

      while (true) {
        // auto fee calculations
        let feeResponse = await client.send({ command: 'fee' });
        if ( feeResponse.drops.open_ledger_fee > feeAmount && auto_adjust_fee == true ) { feeAmount = ( parseInt(feeResponse.drops.open_ledger_fee) + parseInt(fee_adjust_amount) ).toString()};
        logVerbose("fee calculations, feeStartAmount:" + feeStartAmount + " feeAmount:" + feeAmount + " feeResponse:" + JSON.stringify(feeResponse));

        // Send xahSetupamount XAH ( activating account )
        if (xahSetupamount != 0){
          const xahTx = {
            TransactionType: 'Payment',
            Account: xahSourceAccount,
            Amount: (xahSetupamount * 1000000).toString(), // Convert to drops
            Destination: account,
            Fee: feeAmount,
            NetworkID: network_id,
            Sequence: account_dataSource.Sequence++
          };
          const { signedTransaction: signedXrpTx } = lib.sign(xahTx, keypair);
          const xahSubmit = await client.send({ command: 'submit', 'tx_blob': signedXrpTx });
          if (xahSubmit.engine_result !== "tesSUCCESS" && xahSubmit.engine_result !== "terQUEUED" ) {
            tesSUCCESS = false;
            consoleLog(xahSetupamount + "XAH FAILED TO SEND, " + xahSourceAccount + " xxx " + account + ", result: " + xahSubmit.engine_result);
          } else {   
          consoleLog(xahSetupamount + " XAH sent, " + xahSourceAccount + " --> " + account + ", result: " + xahSubmit.engine_result);
          };
        }

        //get account data (now its been acivated)
        const { account_data } = await client.send({ command: "account_info", account: account });
        logVerbose("account >" + account + "  account_data >" + JSON.stringify(account_data));

        // Set trustline and send tokens
        if (evrSetupamount != 0){
          // Set trustline
          const trustlineTx = {
            TransactionType: 'TrustSet',
            Account: account,
            LimitAmount: {
              currency: 'EVR',
              value: '73000000',
              issuer: trustlineAddress
            },
            Fee: feeAmount,
            NetworkID: network_id,
            Sequence: account_data.Sequence++
          };
          trustlineKeypair = lib.derive.familySeed(accounts_seed[loop]);
          const { signedTransaction: signedTrustline } = lib.sign(trustlineTx, trustlineKeypair);
          const trustSubmit = await client.send({ command: 'submit', 'tx_blob': signedTrustline });
          if ( trustSubmit.engine_result !== "tesSUCCESS" && trustSubmit.engine_result !== "terQUEUED" ) { 
            tesSUCCESS = false;
            consoleLog("EVR trustline FAILED TO SET on " + account + ", result: " + trustSubmit.engine_result);
          } else {
            consoleLog("EVR trustline set on " + account + ", result: " + trustSubmit.engine_result);
          }

          //wait for trustline to be established
          if ( tesSUCCESS == true ) {
            var truslineEstablished = false
            while (truslineEstablished == false) {
              const lines = await client.send({ command: 'account_lines', account })
              //marker = lines?.marker === marker ? null : lines?.marker
              logVerbose(`Got ${lines.lines.length} results`)
              lines.lines.forEach(t => {
                if (t.account == trustlineAddress) {
                  truslineEstablished = true
                }
              })
            }

            // fee check
            if ( trustSubmit.engine_result !== "terQUEUED" ){
              feeResponse = await client.send({ command: 'fee' });
              if ( feeResponse.drops.open_ledger_fee > feeAmount && auto_adjust_fee == true ) { feeAmount = ( parseInt(feeResponse.drops.open_ledger_fee) + parseInt(fee_adjust_amount) ).toString()};
            }

            // Send EVR tokens
            const tokenTx = {
              TransactionType: 'Payment',
              Account: xahSourceAccount,
              Amount: {
                "currency": "EVR",
                "value": evrSetupamount,
                "issuer": trustlineAddress
              },
              Destination: account,
              DestinationTag: "",
              Fee: feeAmount, 
              NetworkID: network_id,
              Sequence: account_dataSource.Sequence++
            };
            const { signedTransaction: signedTokenTx } = lib.sign(tokenTx, keypair);
            const evrSubmit = await client.send({ command: 'submit', 'tx_blob': signedTokenTx });
            if ( evrSubmit.engine_result !== "tesSUCCESS" && evrSubmit.engine_result !== "terQUEUED") { 
              tesSUCCESS = false;
              consoleLog(evrSetupamount + " EVR FAILED TO SEND, " + xahSourceAccount + " xxx " + account + ", result: " + evrSubmit.engine_result);
            } else {
              consoleLog(evrSetupamount + " EVR sent, " + xahSourceAccount + " --> " + account + ", result: " + evrSubmit.engine_result);
            }
          }
        }

        feeResponse = await client.send({ command: 'fee' });
        if ( feeResponse.drops.open_ledger_fee > feeAmount && auto_adjust_fee == true ) { feeAmount = ( parseInt(feeResponse.drops.open_ledger_fee) + parseInt(fee_adjust_amount) ).toString()};

        // Set regularKey
        const regularTx = {
          TransactionType: 'SetRegularKey',
          Account: account,
          Fee: feeAmount,
          RegularKey: xahSourceAccount,
          NetworkID: network_id,
          Sequence: account_data.Sequence++
        };
        regularKeypair = lib.derive.familySeed(accounts_seed[loop]);
        const { signedTransaction: signedRegular } = lib.sign(regularTx, regularKeypair);
        const regularSubmit = await client.send({ command: 'submit', 'tx_blob': signedRegular });
        if ( regularSubmit.engine_result !== "tesSUCCESS" && regularSubmit.engine_result !== "terQUEUED" ) { 
          tesSUCCESS = false;
          consoleLog("regular key " + xahSourceAccount + " FAILED TO BE SET on " + account + ", result: " + regularSubmit.engine_result);
        } else {
          consoleLog("regular key " + xahSourceAccount + " set on " + account + ", result: " + regularSubmit.engine_result);
        }

        if ( tesSUCCESS == true ) {
          break 
        } else {
          if ( attempt > 2 ) { process.exit() };
          logVerbose("something failed, retying, " + attempt + " of 2");
          attempt++;
          tesSUCCESS = true;
          
        };
      }
    } else {
      consoleLog("skipping " + account + " as its the source account.");
    };
    consoleLog(" ---------------- ");
    consoleLog(" ");
    loop++;
  };
  consoleLog("wallet setup complete, setting up .env file.");
  await updateEnv('run_wallet_setup', 'false');
  await updateEnv('xahSourceAccount', accounts[0]);
  await updateEnv('evrDestinationAccount', accounts[0]);
  await updateEnv('reputationAccounts', accounts[1]);
  await updateEnv('secret', accounts_seed[0]);
  let saveAccounts = accounts.slice(2);
  await updateEnv('accounts', saveAccounts.join('\n'));
};

// .env file handling  ........................................................................................................................................................................

async function updateEnv(key, value) {
  const envPath = path.resolve(__dirname, '.env');

  try {
    let envFileContent = await fs.promises.readFile(envPath, 'utf8');

    // regular expression to match the key (handles cases with or without spaces around '=', and new lines within accounts)
    const regex = new RegExp(`^\\s*${key}\\s*=\\s*(?:"[^"]*"|[^\\n]*)$`, 'm');

    // Replace the key-value pair if found
    if (regex.test(envFileContent)) {
      envFileContent = envFileContent.replace(regex, `${key}="${value}"`);
    } else {
      // If key is not found, append it at the end
      envFileContent += `\n${key}="${value}"\n`;
    }
    logVerbose(`Updating ${key} to ${value} in .env`);
    await fs.promises.writeFile(envPath, envFileContent, 'utf8');

    // Reload the environment variables to reflect the change
    dotenv.config();

    logVerbose(`Updated ${key} to ${value} in .env successfully`);
  } catch (err) {
    console.error('Error updating .env file:', err);
  }
}

//........................................................................................................................................................................................
// start sections ........................................................................................................................................................................

async function validate() {
  await getAccounts();
  if (!accounts || accounts.length == 0 || accounts[0] == "") {
    consoleLog("no accounts set");
    return false;
  }
  if (!keypair && (run_transfer_funds || run_monitor_balance)) {
    consoleLog("no secret/seed/keypair set")
    return false;
  }
  return true;
}

const main = async () => {
  if (run_wallet_setup) { use_keypair_file = true };
  const valid = await validate();
  if (valid) {
    if (run_wallet_setup) { await wallet_setup() };
    if (run_transfer_funds) { await transfer_funds() };
    if (run_monitor_balance) { await monitor_balance() };
    if (run_monitor_heartbeat) { await monitor_heartbeat() };
  }
};

// check if theres any command line arguments used
async function start(){
  await networkSetup();
  if (command) {
    if ( command == "wallet_setup" ) { use_keypair_file = true };
    const valid = await validate();
    if (valid) {
      switch (command) {
        case 'wallet_setup':
              await wallet_setup();
              break;
        case 'transfer_funds':
              await transfer_funds();
              break;
        case 'monitor_balance':
              await monitor_balance();
              break;
        case 'monitor_heartbeat':
              await monitor_heartbeat();
              break;
        default:
            console.log(`Unknown command: ${command}`);
            console.log('Usage: node evernode_monitor.js <command>');
            console.log('Commands available are:');
            console.log('  wallet_setup  - setup wallets in key_pair.txt file ready to deploy evernodes');
            console.log('  transfer_funds  - sweep funds (EVR/XAH) to chosen account');
            console.log('  monitor_balance  - Check balance (EVR/XAH), and top up if needed');
            console.log('  monitor_heartbeat  - Check for recent heartbeat, and email failures');
            break;
      };
    ;}
  } else {
    await main();
  };
  client.close();
  consoleLog('Shutting down...');
  // Workaround so all queued emails are sent. 
  // I had to explicitly call the exit() function as the application was not stopping 
  // in case of Xahaud request failure, I don't know why. 
  setTimeout(function () {
    exit();
  }, 10000);
};
start();