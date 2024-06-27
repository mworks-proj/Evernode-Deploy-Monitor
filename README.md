# Evernode monitor

This nodejs script (requires v20.11.1) will help you in the monitoring and managering all of your evernodes hosts accounts.

this fork adds;
wallet_setp module, 
the abbility to run each module manually by using the module name after the evernode_monitor.js,
auto fee escalation, 
and also fixes a number bugs (like with balance)


If you have many nodes, using this script you will have to check only one account instead of all of them.

It is made of 4 modules:

1. wallet_setup, used to setup new un-activated wallets, so they are fully ready for evernode install (activating, settng trustline, sending EVR, settng regularkey, pushing data to .ev file)
2. transfer_funds, Move all EVR/XAH from your node accounts to source account.
3. monitor_balance, check and send EVR/XAH to your accounts when the balance is below a certain threshold (configurable).
4. monitor_heartbeat, cheaks hook heartbeats of your nodes, and sends an alert email in case no heartbeat was sent in the last N (configurable) minutes.

source, and destination accounts can be one of your evernode accounts or a unique address of your choice.

and the EVR destinaton account, can be an exchange as tag is supported.

## 1. wallet_setup, is a tool to setup Wallets for use in evernode

for this module it exclusively uses a `key_pair.txt` file, 

which uses the same format as many opensource (vanity) wallet generators, which is; 

layout per line is `Address: rzErPRJ178T5ZKN7AjVYLphYo7HP84spT      Seed: sEdVLsDtbUT44ZaovrmHvxnTCtzP8FG`

for example this github is a perfect source of a vanity account generator,

https://github.com/nhartner/xrp-vanity-address

(which gives many ways to run it, with its main output format of above, and what key_pair.txt needs to be in and why i used that format)

FIRST line address/seccret of key_pair.txt, 

is used for the source of the XAH and EVR which gets sent to all other keypair lines

SECOND line address/secret of key_pair.txt, 

is used as a reputation account


so when module is ran, 

it 1st sends `xahSetupamount` amount to activate the account, 

it then sets the trustline, then sends `evrSetupamount` amount of EVR, 

and finishes by setting the regular key as the source account.

after it completes the above on all accounts succesfully, 

it then saves these addresses(not 1st line or second line of course), to the `accounts` in the .env file,

along with setting `evrDestinationAccount`, and `xahSourceAccount` and `secret` of that 1st listed addresss, and then setting `reputationAccounts` with that second address in key_pair.txt

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

As a minimum amount of XAH is required to run an evernode host, this script sends N (configurable) XAH from the first account when the balance is below a certain threshold (configurable). In case the first account balance is too low to send XAH, an alert email is sent to the configured email. This means you will only have to check the first account XAH balance and you can ignore the others that are automatically filled when needed.

The module also manages the reputation accounts XAH and EVR balance.  

## 4. monitor_heartbeat, will Monitor the heartbeat

This script cycles through your accounts and checks whether each account sent a heartbeat transaction in the last N (configurable) minutes.
In cases where no heartbeat is found an alert is sent,
two alert types can be confinured;
 - to a configured email address, 
 where the alert email is repeated after N (configurable) minutes in case the down is not solved. A restore email is sent as soon as the issue is solved.
 - to a configured "uptime robot" / "uptime kuma", via a push URL monitor type

#### SMTP server

In order to send emails from the script you need an SMTP server. Follow these instruction to setup your free account in BREVO: https://www.programonaut.com/how-to-send-an-email-in-node-js-using-an-smtp-step-by-step/. 

#### Uptime robot / kuma

- uptime robot, can be found and signed upto here, https://uptimerobot.com/ you would need the paid version to get "heartbeat monitoring" to support the type this uses

- uptime kuma, can be found on github here, where there are simple install instructions, https://github.com/louislam/uptime-kuma this is the free open source, self host, of uptime robot
follow install intsructions above, once created logins etc, you "add new monitor", selecting "push" monitor type, which is under the passive listing, fill in frendly name, use 1800 seconds (30 mins), 
then paste/use the "Push URL" in the .env file, as below

once configured, you add the push URLs within the `push_addresses` section in the .env file, in a list form like you do in the `accounts` section.
push_addresses, should ONLY incluse the URL and NOT the query, so DO NOT include the `?status=up&msg=OK&ping=` part of the URL, for example could look like this, http://192.168.0.100:3001/api/push/Cyn0DuXkVi
where each line indexes and corrosponds to the accounts line. so the 1st listed URL in push_addresses will be used for the 1st listed account, and 2nd listed for 2nd account etc etc... 

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

You can now setup a scheduled task that runs the script regularly using cronjob.

where you can even tailer different cronjobs to happen at different times, using the module name after.

The example below runs the monitor_heartbeat script every 30 minutes (and logs the results to a file called logs.log)
which would typically used for the setup to support uptime kuma

crontab -e

0,30 * * * * /usr/bin/node /root/evernode_monitor/evernode_monitor.js monitor_heartbeat >> /root/evernode_monitor/logs.log

some cron documentation: https://www.cherryservers.com/blog/how-to-use-cron-to-automate-linux-jobs-on-ubuntu-20-04

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