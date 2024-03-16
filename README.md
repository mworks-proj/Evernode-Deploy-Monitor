# Evernode monitor

Script to monitor your evernodes hosts. 

If you have many nodes, using this script you will have to control only one account.

It is made of 3 modules:

1. Withdraw EVRs from your node accounts to your first account
2. Monitor the heartbeat of all your nodes and send an alert email in case no heartbeat where sent in the last N (configurable) minutes.
3. Send XAH to your Evernode accounts when the balance is below a certain threshold (configurable) 

## 1. Withdraw EVRs

This script will cycle through your accounts, get their EVR balance and send all of the EVR balance to your first EVR account (that is of course skipped). 
This script is designed to use a single signing address where all nodes have set their Regular Key to the signing address of an active account in Xaman or other wallet that you control.

To set the Regular Key for a node...open the Linux terminal and run the following command: 

```
evernode regkey set rWalletAddressThatYouOwnThatCanSignTransactions
```

Setting the same regular key on a Xahau account list will let you sign the transaction for all of them using the same secret (doc: https://docs.xahau.network/technical/protocol-reference/transactions/transaction-types/setregularkey )

## 2. Monitor the heartbeat

This script will cycle through your accounts, and will check whether each account sent a heartbeat transaction in the last N (configurable) minutes. In case no heartbeat was sent an alert email is sent to the configured email address. The alert email is sent the first time and repeted after N (configurable) minutes in case the down is not solved.

## 3. Send XAH to the account if balance is too low

As a minimum numer of XAH is required to run an evernode host, this script will send N (configurable) XAH from the first account when the balance is below a certain threshold (configurable). In case the first account balance is too low to send XAH, an alert email is sent to the configured email. This means you will only have to check the first account XAH balance and you can ignore the others that are automatically filled when needed.

## Install & run

```
git clone https://github.com/genesis-one-seven/evernode_monitor/

cd evernode_monitor

cp .env.sample .env 

sudo nano .env
```

Set the variables in the .env file (all variables are described in the file) and then run the script:

```
npm install

node evernode_monitor.js
```

*use at your own risk - double check all fields point to YOUR addresses that you CONTROL*

You can now setup a scheduled task that runs the script regularly using Cron.
The example below runs the transfer script every 4 hours and logs the results to a file called log.log

crontab -e

* */4 * * * /usr/bin/node /root/evernode_monitor/evernode_monitor.js >> /root/evernode_monitor/log.log

Cron documentation: https://www.cherryservers.com/blog/how-to-use-cron-to-automate-linux-jobs-on-ubuntu-20-04

END.


