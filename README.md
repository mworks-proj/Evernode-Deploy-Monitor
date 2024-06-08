# Evernode monitor

This nodejs script (requires v20.11.1) will help you in the monitoring and managering all of your evernodes hosts accounts.

(this fork adds, wallet_setp, the abbility to run each mudle manually by using the module name after the evernode_monitor.js, auto fee escalation, and also fixes a number bugs (like with balance))


If you have many nodes, using this script you will have to check only one account instead of all of them.

It is made of 4 modules:

1. wallet_setup, to setup new un-activated wallets, to be fully ready for evernode (activateing, settng trustline, sending EVR, settng regularkey, pushing data to .ev file)
2. transfer_funds, Move all EVR/XAH from your node accounts to a single account.
3. monitor_balance, and Send EVR/XAH to your Evernode accounts when the balance is below a certain threshold (configurable).
4. monitor_heartbeat, the heartbeat of all your nodes and send an alert email in case no heartbeat was sent in the last N (configurable) minutes.


The hub accounts can be one of your evernode accounts or another one of your choice. 

The EVR destinaton account can be an exchange. 

## 1. wallet_setup, is a tool to setup Wallets for use in evernode

for this module it exclusively uses a `key_pair.txt` file, which uses the same format as opensource (vanity) wallet generators, so.. 

layout per line is `Address: rzErPRJ178T5ZKN7AjVYLphYo7HP84spT      Seed: sEdVLsDtbUT44ZaovrmHvxnTCtzP8FG`

for example this github is a perfect source of one, https://github.com/nhartner/xrp-vanity-address

which gives many ways to run it, with its main output is the format that key_pair.txt needs to be in

it uses the FIRST line address/seccret, for the source for the XAH and EVR which gets sent to all other keypair lines

it 1st sends `xahSetupamount` amount to activate the account, it then sets the trustline, (checks its set) then sends `evrSetupamount` amount of EVR, and finishes by setting the regular key as the source account.

after it completes the above on all accounts succesfully, it then saves these addresses, to the `accounts` in the .env file, along with setting `evrDestinationAccount`, `xahSourceAccount` and `secret` of that 1st listed account.

(it also sets `run_wallet_setup` to false, so it doesnt get ran accidentally again)

## 2. transfer_funds, is a funds sweeper

This script cycles through your accounts, gets their EVR/XAH balance and sends all of the EVR balance to your first EVR account. 

This script uses a single signing address, that requires the same Regular Key is set on all accounts.
 
To set the Regular Key for a node, open the Linux terminal and run the following command: 

```
evernode regkey set rWalletAddressThatYouOwnThatCanSignTransactions
```

Setting the same regular key on a Xahau account list will let you sign the transaction for all of them using the same secret (doc: https://docs.xahau.network/technical/protocol-reference/transactions/transaction-types/setregularkey )

(or use the wallet_setup module)

## 3. monitor_balance, Send XAH/EVR to the account if balance is too low

As a minimum numer of XAH is required to run an evernode host, this script sends N (configurable) XAH from the first account when the balance is below a certain threshold (configurable). In case the first account balance is too low to send XAH, an alert email is sent to the configured email. This means you will only have to check the first account XAH balance and you can ignore the others that are automatically filled when needed.

The module also manages the reputation accounts XAH and EVR balance.  

## 4. monitor_heartbeat, will Monitor the heartbeat

This script cycles through your accounts and checks whether each account sent a heartbeat transaction in the last N (configurable) minutes. In case no heartbeat is found an alert email is sent to the configured email address. The alert email is repeated after N (configurable) minutes in case the down is not solved. A restore email is sent as soon as the issue is solved.

## SMTP server

In order to send emails from the script you need an SMTP server. Follow these instruction to setup your free account in BREVO: https://www.programonaut.com/how-to-send-an-email-in-node-js-using-an-smtp-step-by-step/. 

# Install & run

First you need to ensure you have the latest version of node.js in your server (https://github.com/nodesource/distributions)

Then you can download and configure the script:

```
git clone https://github.com/gadget78/evernode_monitor/

cd evernode_monitor

cp .env.sample .env 
```

Set the variables in the .env file (all variables are described in the file) with this command:

```
sudo nano .env
```

now, setup all the dependencies that evernode_monitor.js needs by running

```
npm install
```

then you can either run it based on how the .env is setup 

```
node evernode_monitor.js
```

OR you can run each individual "module" seperatly with `node evernode_monitor.js <module>`

`<module>` being one of the module listed above for example, if you wanted to just initiate a funds sweep, you would do..

```
node evernode_monitor.js transfer_funds
```

You can now setup a scheduled task that runs the script regularly using Cron.

and you can even tailer different cronjobs to happen at different times, using the module name after.

The example below runs the transfer script every 30 minutes and logs the results to a file called log.log

crontab -e

0,30 * * * * /usr/bin/node /root/evernode_monitor/evernode_monitor.js >> /root/evernode_monitor/log.log

Cron documentation: https://www.cherryservers.com/blog/how-to-use-cron-to-automate-linux-jobs-on-ubuntu-20-04

## Update to last version

In order to update the script to the last version without losing your configuration, first go in evernode_monitor folder:

```
cd evernode_monitor
```

then give execute permission to the script:

```
chmod +x update.sh
```

and finally execute the script update.sh:

```
sudo ./update.sh
```

Here's the one line version of the command sequence:

```
cd evernode_monitor && chmod +x update.sh && sudo ./update.sh
```


## Use at your own risk. Double check your addresses before running the script!