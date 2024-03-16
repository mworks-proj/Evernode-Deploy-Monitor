# Evernode monitor

Script to monitor your evernodes hosts. 

If you have many nodes, using this script you will have to check only one account instead of all of them.

It is made of 3 modules:

1. Withdraw all EVRs from your node accounts to your first account.
2. Monitor the heartbeat of all your nodes and send an alert email in case no heartbeat was sent in the last N (configurable) minutes.
3. Send a few XAH to your Evernode accounts when the balance is below a certain threshold (configurable).

## 1. Withdraw EVRs

This script cycles through your accounts, gets their EVR balance and sends all of the EVR balance to your first EVR account (that is of course skipped). 
This script uses a single signing address, that requires the same Regular Key is set on all accounts.
 
To set the Regular Key for a node, open the Linux terminal and run the following command: 

```
evernode regkey set rWalletAddressThatYouOwnThatCanSignTransactions
```

Setting the same regular key on a Xahau account list will let you sign the transaction for all of them using the same secret (doc: https://docs.xahau.network/technical/protocol-reference/transactions/transaction-types/setregularkey )

## 2. Monitor the heartbeat

This script cycles through your accounts and checks whether each account sent a heartbeat transaction in the last N (configurable) minutes. In case no heartbeat is found an alert email is sent to the configured email address. The alert email is repeated after N (configurable) minutes in case the down is not solved. A restore email is sent a soon as the issue is solved.

## 3. Send XAH to the account if balance is too low

As a minimum numer of XAH is required to run an evernode host, this script sends N (configurable) XAH from the first account when the balance is below a certain threshold (configurable). In case the first account balance is too low to send XAH, an alert email is sent to the configured email. This means you will only have to check the first account XAH balance and you can ignore the others that are automatically filled when needed.

## SMTP server

In order to send emails from the script you need an SMTP server. Follow these instruction to setup your free account in BREVO: https://www.programonaut.com/how-to-send-an-email-in-node-js-using-an-smtp-step-by-step/. 

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

You can now setup a scheduled task that runs the script regularly using Cron.
The example below runs the transfer script every 30 minutes and logs the results to a file called log.log

crontab -e

0,30 * * * * /usr/bin/node /root/evernode_monitor/evernode_monitor.js >> /root/evernode_monitor/log.log

Cron documentation: https://www.cherryservers.com/blog/how-to-use-cron-to-automate-linux-jobs-on-ubuntu-20-04


## Use at your own risk. Double check your addresses before running the script!