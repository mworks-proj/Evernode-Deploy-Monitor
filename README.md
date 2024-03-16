# Evernode monitor

Script to monitor your evernodes hosts.

It his made of three modules:

1. Withdraw EVRs from your node accounts to your first account
2. Monitor the heartbeat of all your nodes and send an alert email in case no heartbeat where sent in the last N (configurable) minutes.
3. Send XAH to your Evernode accounts when the balance is below a certain threshold (configurable) 

## 1. Withdraw EVRs

This Script will cycle through an array of addresses, get their EVR balance then send all of the EVR balance to the first EVR account (that is of course skipped). This script is designed to use a single signing address where all nodes have set their Regular Key to the signing address of an active account in Xaman or other wallet that you control.

To set the Regular Key for a node...on each node issue the command from the terminal 

$ evernode regkey set rWalletAddressThatYouOwnThatCanSignTransactions

## 2. Monitor the heartbeat

This Script will cycle through an array of addresses, and check whether each account sent a heartbeat transaction in the last N (configurable) minutes. In case no heartbeat was sent an alert email is sent to the configured email address. The alert email is sent the first time and repeted after N (configurable) minutes in case it's still down,

## 3. Send XAH to the account if balance is too low

As a minimum numer of XAH is required to run an evernode host, this script will send N (configurable) XAH from the first account when the balance is below a certain threshold (configurable). In case the first account balance is too low to send XAH, an alert email is sent to the configured email  

## Install & run

```
git clone https://github.com/genesis-one-seven/evernode_monitor/

cd evernode_monitor

cp .env.sample .env 

sudo nano .env
```

set the variables following the instructions in the .env file

```
npm install

node evernode_monitor.js
```

*use at your own risk - double check all fields point to YOUR addresses that you CONTROL*

You can use cron to setup a scheduled task. The example below runs the transfer script every 4 hours and logs the results to a file called log.log

crontab -e

* */4 * * * /usr/bin/node /root/evernode_montor/transfer_funds.js >> /root/evernode_montor/log.log

Here's some good cron documentation: https://www.cherryservers.com/blog/how-to-use-cron-to-automate-linux-jobs-on-ubuntu-20-04

END.


