#!/bin/bash
ver=1

###################################################################################
# message functions for script

color() {
  YW=$(echo "\033[33m")
  BL=$(echo "\033[36m")
  RD=$(echo "\033[01;31m")
  BGN=$(echo "\033[4;92m")
  GN=$(echo "\033[1;92m")
  DGN=$(echo "\033[32m")
  CL=$(echo "\033[m")
  CM="${GN}✓${CL}"
  CROSS="${RD}✗${CL}"
  BFR="\\r\\033[K"
  HOLD=" "
}

spinner() {
    local chars="/-\|"
    local spin_i=0
    printf "\e[?25l"
    while true; do
        printf "\r \e[36m%s\e[0m" "${chars:spin_i++%${#chars}:1}"
        sleep 0.1
    done
}

msg_info() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null && printf "\e[?25h"; fi
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}   "
  spinner &
  SPINNER_PID=$!
}

msg_info_() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null && printf "\e[?25h"; fi
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}   "
  spinner &
  SPINNER_PID=$!
}

msg_ok() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null && printf "\e[?25h"; fi
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null && printf "\e[?25h"; fi
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

# setup error catching
SPINNER_PID=""
set -Eeuo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
function error_handler() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null && printf "\e[?25h"; fi
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  if mount | grep -q '/mnt/evernode-mount'; then
    guestunmount /mnt/evernode-mount/
  fi
  msg_error "error occured, clearing half built stuff, TMP files, then cleanly exiting"
}

function cleanup() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null && printf "\e[?25h"; fi
  if mountpoint -q /mnt/evernode-mount; then guestunmount /mnt/evernode-mount; fi
  popd >/dev/null
  rm -rf $TEMP_DIR
}

function exit-script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

TEMP_DIR=$(mktemp -d)
gadget_encrypt="ipinfo.io/ip"
pushd $TEMP_DIR >/dev/null

###################################################################################
# used for testnet account setup/generation
function extract_json_add_to_file() {
  local capture_json=false
  local json=""

  while IFS= read -r line; do
    if [[ $line == "Wallet:" ]]; then
      local capture_json=true
      continue
    fi

    if $capture_json; then
      local json+="$line"$'\n'
      # Check if the line contains a closing curly brace, indicating the end of the JSON block
      if [[ $line == *"}"* ]]; then
        break
      fi
    fi
  done

  # Ensure we only capture valid JSON by trimming leading/trailing whitespace, then save address/seed
  local json=$(echo "$json" | sed "s/'/\"/g" | sed 's/\([a-zA-Z0-9_]*\):/\1:/g')
  local address=$(echo "$json" | awk '/address:/ {print $2}' | tr -d '",')
  local seed=$(echo "$json" | awk '/secret:/ {print $2}' | tr -d '",')

  # Format output, and add a properly generated line to key_pair.txt
  if [ "$address" != "" ]; then 
    printf "Address: %s Seed: %s\n" $address $seed >> "$keypair_file"
    return 0
  fi
  return 1
}

####################################################################################
# installing of dependancies
function check_for_needed_program_installs() {
  local arg1="${1:-}"

  msg_info_ "checking and installing dependencies (jq, git, curl, unzip, libguestfs-tools, node, npm, npm-ws)..."
  cd /root/
  
  if [ -z "$arg1" ] && ! command -v guestmount &> /dev/null; then
    msg_info_ "installing libquestfs-tools...                                                                    "
    apt update >/dev/null 2>&1
    apt install -y libguestfs-tools 2>&1 | awk '{ printf "\r\033[K   installing libquestfs-tools.. "; printf "%s", $0; fflush() }'
    msg_ok "libquestfs-tools installed."
  fi
  
  if ! command -v jq &> /dev/null; then
    msg_info_ "installing jq...                                                                                  "
    apt update >/dev/null 2>&1
    apt install -y jq 2>&1 | awk '{ printf "\r\033[K   installing jq.. "; printf "%s", $0; fflush() }'
    msg_ok "jq installed."
  fi

  if ! command -v git &> /dev/null; then
    msg_info_ "installing git...                                                                                  "
    apt update >/dev/null 2>&1
    apt install -y git 2>&1 | awk '{ printf "\r\033[K   installing git.. "; printf "%s", $0; fflush() }'
    msg_ok "git installed."
  fi

  if ! command -v dialog &> /dev/null; then
    msg_info_ "installing dialog...                                                                                  "
    apt update >/dev/null 2>&1
    apt install -y dialog 2>&1 | awk '{ printf "\r\033[K   installing dialog.. "; printf "%s", $0; fflush() }'
    msg_ok "dialog installed."
  fi

  if ! command -v bc &> /dev/null; then
    msg_info_ "installing bc...                                                                                  "
    apt update >/dev/null 2>&1
    apt install -y bc 2>&1 | awk '{ printf "\r\033[K   installing bc.. "; printf "%s", $0; fflush() }'
    msg_ok "bc installed."
  fi

  if ! command -v unzip &> /dev/null; then
    msg_info_ "installing unzip...                                                                                  "
    apt update >/dev/null 2>&1
    apt install -y unzip 2>&1 | awk '{ printf "\r\033[K   installing unzip.. "; printf "%s", $0; fflush() }'
    msg_ok "unzip installed."
  fi

  if ! command -v node &> /dev/null; then
    msg_info_ "installing nodejs...                                                                                  "
    apt update >/dev/null 2>&1
    apt install -y nodejs 2>&1 | awk '{ printf "\r\033[K   installing nodejs.."; printf "%s", $0; fflush() }'
    msg_ok "nodejs installed."
  else
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d. -f1)
    if [ "$NODE_VERSION" -lt 20 ]; then
      msg_info_ "installing npm...                                                                                  "
      curl -fsSL https://fnm.vercel.app/install | bash > /dev/null | awk '{ printf "\r\033[K   installing npm.."; printf "%s", $0; fflush() }'
      FNM_PATH="/root/.local/share/fnm"
      if [ -d "$FNM_PATH" ]; then
        export PATH="$FNM_PATH:$PATH"
        eval "`fnm env`"
      fi
      fnm use --install-if-missing 20  2>&1 | awk '{ printf "\r\033[K   installing npm.. "; printf "%s", $0; fflush() }'
      msg_ok "nodejs updated to newest."
    fi
  fi

  if ! command -v npm &> /dev/null; then
    msg_info_ "installing npm...                                                                                  "
    curl -fsSL https://fnm.vercel.app/install | bash > /dev/null | awk '{ printf "\r\033[K   installing npm.. "; printf "%s", $0; fflush() }'
    FNM_PATH="/root/.local/share/fnm"
    if [ -d "$FNM_PATH" ]; then
      export PATH="$FNM_PATH:$PATH"
      eval "`fnm env`"
    fi
    fnm use --install-if-missing 20  2>&1 | awk '{ printf "\r\033[K   installing npm.. "; printf "%s", $0; fflush() }'
    msg_ok "npm installed, needs loging out and back in to take effect"
  fi

  if [ "$(node -e "try { require.resolve('ws'); console.log('true'); } catch (e) { console.log('false'); }")" = "false" ]; then
    msg_info_ "installing node websocket (ws)...                                                                                  "
    npm install -g ws  2>&1 | awk '{ printf "\r\033[K   installing node ws.. "; printf "%s", $0; fflush() }'
    npm install ws  2>&1 | awk '{ printf "\r\033[K   installing node ws.. "; printf "%s", $0; fflush() }'
    msg_ok "node ws installed."
  fi

  msg_ok "all dependencies checked, and installed."
}

####################################################################################################################################################
###################################################################################
function wallet_management_script() {
  clear
  cd /root/
  msg_info "pre-checks..."
  check_for_needed_program_installs "no_guestmount_check"
  if [ -d "/root/evernode-deploy-monitor" ]; then
    echo "Pulling latest changes from github..."
    cd "/root/evernode-deploy-monitor"
    git pull
  else
    echo "Cloning https://github.com/gadget78/Evernode-Deploy-Monitor repository..."
    git clone https://github.com/gadget78/Evernode-Deploy-Monitor /root/evernode-deploy-monitor
    cd /root/evernode-deploy-monitor/
    cp .env.sample .env
    echo "updating NPM dependencies..."
    npm install -prefix /root/evernode-deploy-monitor
  fi
  cd "/root/evernode-deploy-monitor/"
  source .env

  if [ "$(node -e "try { require.resolve('evernode-js-client'); console.log('true'); } catch (e) { console.log('false'); }")" = "false" ]; then
    msg_info_ "installing node evernode-js-client...                                                                                  "
    npm install evernode-js-client  2>&1 | awk '{ printf "\r\033[K   installing node ws.. "; printf "%s", $0; fflush() }'
    msg_ok "node evernode-js-client installed."
  fi
  msg_ok "pre-checks complete."

  if [ -z "${monitor_ver:-}" ] || [ "${monitor_ver:-0}" -lt 2 ]; then
    if (whiptail --backtitle "Proxmox VE Helper Scripts: evernode deploy script $ver" --title ".env missmatch" --yesno ".env version missmatch, you may encounter errors,
do you want re-generate new .env file?
(old .env will be backed up to .old.env)" 10 58); then
      mv .env .old.env
      cp .env.sample .env
      source .env
    fi
  fi
  if [ "$use_testnet" == "true" ]; then DEPLOYMENT_NETWORK="testnet"; else DEPLOYMENT_NETWORK="mainnet"; fi

  # check key_pair files and .env for accounts etc and report
  if ( [ "$use_keypair_file" == "true" ] && [ ! -f "$keypair_file" ] && [ "$DEPLOYMENT_NETWORK" == "testnet" ] ) || ( [ "$use_keypair_file" == "true" ] && [ "$DEPLOYMENT_NETWORK" == "testnet" ] && [ $(grep -c '^Address' "$keypair_file" 2>/dev/null || 0 ) -lt 2 ] ); then 
    touch $keypair_file
    while true; do
      if NUM_VMS=$(whiptail --backtitle "Proxmox VE Helper Scripts: evernode deploy script $ver" --inputbox "the \"use_keypair_file\" is set to true,
with incorrect amount of key pairs in $keypair_file file
key pairs found in file :$(grep -c '^Address' "$keypair_file" 2>&1),

enter amount of testnet accounts to create. (minimum is 2) 
or 0 to skip (giving you access to manager)" 14 72 "3" --title "evernode count" 3>&1 1>&2 2>&3); then
        if ! [[ $NUM_VMS =~ $INTEGER ]]; then
          whiptail --backtitle "Proxmox VE Helper Scripts: evernode deploy script $ver" --msgbox "needs to be a number" 8 58
        elif [[ $NUM_VMS == 0 ]]; then
          break
        elif [ $NUM_VMS -gt 2 ]; then
          touch "$keypair_file"
          attempt=1
          if [  ! -f "$TEMP_DIR/test-account-generator.js" ]; then
            wget -q -O $TEMP_DIR/test-account-generator.js "https://gadget78.uk/test-account-generator.js" || msg_error "failed to download testnet account generator, restart script to try again"
          fi
          while true; do
            # Run the node testnet wallet generator, and capture address seed to key_pair.txt
            key_pair_count=$(grep -c '^Address' "$keypair_file" 2>&1) || true
            if [[ $NUM_VMS -gt $key_pair_count ]]; then
              msg_info_ "generating keypairs, total so far $key_pair_count of $NUM_VMS (attempt $attempt, CTRL+C to exit !)         "
              node $TEMP_DIR/test-account-generator.js  2>/dev/null | extract_json_add_to_file 2>/dev/null || msg_info_ "timed out generating number $(( key_pair_count + 1 )), waiting a bit then trying again (we are on attempt $attempt)   ";  sleep 20; attempt=$((attempt + 1)); continue
              sleep 2
            else
              msg_ok "generated $NUM_VMS key pairs, and saved them in $keypair_file ready for the evernode installs/wallet management"
              break 2
            fi
          done
        fi
      else
        exit-script
      fi
    done
  elif [ "$use_keypair_file" == "true" ] && [ ! -f "$keypair_file" ]; then
    msg_error "no $keypair_file file, you need to create one for mainnet use,
one good method is using a vanity generator like this https://github.com/nhartner/xrp-vanity-address"
    exit
  elif [ "$use_keypair_file" == "true" ] && [ $(grep -c '^Address' "$keypair_file" 2>&1) -lt 3 ]; then
    msg_error "use_keypair_file is set to true, but there is not enough key pairs in $keypair_file file, minimum is 2 (source, and one for a evernode account)"
    exit
  fi

  ####################################################################################################################################################
  #### START of main wallet management
  while true; do
    if WALLET_TASK=$(dialog --cancel-label "Exit" --backtitle "Proxmox VE Helper Scripts: Wallet Management. version $ver" \
       --title "Wallet Management" \
       --menu "Which module do you want to start?" 20 78 12 \
       "1" "Prepare un-activated key-pairs for evernode deployment" \
       "2" "Initiate a EVR/XAH sweep" \
       "3" "Initiate a balance check and topup" \
       "4" "Initiate a heartbeat checkup" \
       "5" "Initiate claim Reward (aka BalanceAdjustment)" \
       "6" "Install the automated fund sweep, balance and heartbeat monitor" \
       "7" "Install or setup Uptime Kuma" \
       "8" "edit .env file (to change settings)" \
       "9" "edit key_pair.txt accounts file" \
       "0" "edit key_pair_rep.txt file for reputation accounts" \
       "h" "help area" \
       "<" "<<<< return back to main menu" \
       2>&1 >/dev/tty
    ); then

      ######### prep
      if [ "$WALLET_TASK" == "1" ]; then
        if [ ! -f "$keypair_file" ]; then
          msg_error "no $keypair_file file, you need a key_pair.txt file to use this module, maybe use vanity generator https://github.com/nhartner/xrp-vanity-address"
          break
        fi
        if [ "$use_testnet" == "true" ]; then
          xahaud_server=$xahaud_test
        else
          xahaud_server=$xahaud
        fi
        xahaud_server=$(echo "$xahaud_server" | sed -e 's/^wss:/https:/' -e 's/^ws:/http:/')
        source_account=$(sed "1q;d" "$keypair_file" | awk '{for (r=1; r<=NF; r++) if ($r == "Address:") print $(r+1)}')

        if curl -s -f "$xahaud_server" > /dev/null; then
          xahaud_server_working=$(curl -s -f -m 10 -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' "${xahaud_server}"  | jq -r '.result.status // "\\Z1failed\\Zn"' | xargs -I {} echo "\Z2{}\Zn")
          xah_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_info", "params": [ { "account": "'"$source_account"'", "strict": true, "ledger_index": "current", "queue": true } ] }' "${xahaud_server}" | jq -r '.result.account_data.Balance // "\\Z1not activated\\Zn"' )
          if [[ "$xah_balance" != *"not activated"* ]]; then
            xahSetupamount_calculated=$(( xahSetupamount * ( $(grep -c '^Address' "$keypair_file") - 1 ) ))
            xah_balance=$(echo "scale=1; $xah_balance / 1000000" | bc)
            if (( $(echo "$xahSetupamount_calculated > $xah_balance" | bc -l) )); then
              xahSetupamount_calculated="\Z1$xahSetupamount_calculated\Zn"
              xah_balance="\Z1$xah_balance\Zn"
            else
              xahSetupamount_calculated="\Z2$xahSetupamount_calculated\Zn"
              xah_balance="\Z2$xah_balance\Zn"
            fi
          else
            xahSetupamount_calculated="\Z1$(( xahSetupamount * ( $(grep -c '^Address' "$keypair_file") - 1 ) ))\Zn"
          fi

          evr_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_lines", "params": [ { "account": "'"$source_account"'", "ledger_index": "current" } ] }' "${xahaud_server}" | jq -r 'try .result.lines[] catch "failed" | try select(.currency == "EVR") catch "failed" | try .balance catch "\\Z1no trustline\\Zn"' )
          if [[ "$evr_balance" != *"no trustline"* ]]; then
            evrSetupamount_calculated=$(( evrSetupamount * ( $(grep -c '^Address' "$keypair_file") -1 ) ))
            if (( $(echo "$evrSetupamount_calculated > $evr_balance" | bc -l) )); then
              evrSetupamount_calculated="\Z1$evrSetupamount_calculated\Zn"
              evr_balance="\Z1$evr_balance\Zn"
            else
              evrSetupamount_calculated="\Z2$evrSetupamount_calculated\Zn"
              evr_balance="\Z2$evr_balance\Zn"
            fi
          else
            evrSetupamount_calculated="\Z1$(( evrSetupamount * ( $(grep -c '^Address' "$keypair_file") - 1 ) ))\Zn"
          fi
        else
          xahaud_server_working="\Zb\Z1failed to connect\Zn"
          xah_balance="\Zb\Z1failed to connect\Zn"
          evr_balance="\Zb\Z1failed to connect\Zn"
        fi

        if dialog --backtitle "Proxmox VE Helper Scripts: Wallet Management $ver" \
       --title "Wallet Setup Module" --colors \
       --yesno "\
\Z0\ZbInfo on module:\Zn
    This module is used to prepare key-pairs in file \"$keypair_file\"
    It uses the first key pair in file for the source of XAH/EVR.
    Key pairs are prepared by:
    - Sending XAH to activate account,
    - Setting the EVR trustline, and sending EVR,
    - Setting regular key (using source account).
    It will then setup the .env so key_pair.txt file is not needed for other operations.
    This will leave all accounts ready to be used for Evernode deployment.

\Z0\ZbSettings:\Zn
    use_testnet = \"$use_testnet\"
    xahau server = \"$xahaud_server\"
    XAH to send = \"$xahSetupamount\"
    EVR to send = \"$evrSetupamount\"
    set_regular_key = \"$set_regular_key\"
    auto_adjust_fee = \"$auto_adjust_fee\"
    fee_adjust_amount = \"$fee_adjust_amount\"

\Z0\ZbCheckup:\Zn
    xahau server working = \"$xahaud_server_working\"
    total accounts to be activated = \"$(( $(grep -c '^Address' "$keypair_file") - 1 ))\"
    source account = \"$source_account\"
    total XAH needed = \"$xahSetupamount_calculated\" | amount in source account = \"$xah_balance\"
    total EVR needed = \"$evrSetupamount_calculated\" | amount in source account = \"$evr_balance\"

Do you want to use the above settings to setup accounts?" 32 100; then
          clear
          node evernode_monitor.js wallet_setup && echo "sucessfull pass"
          echo ""
          read -n 1 -s -r -p "Press any key to continue..."
        fi

      ######### sweep
      elif [ "$WALLET_TASK" == "2" ]; then
        if [ "$use_testnet" == "true" ]; then
          xahaud_server=$xahaud_test
        else
          xahaud_server=$xahaud
        fi
        xahaud_server=$(echo "$xahaud_server" | sed -e 's/^wss:/https:/' -e 's/^ws:/http:/')
        if [ "$use_keypair_file" == "true" ]; then
          source_account="$sourceAccount"
          total_accounts=$(( $(grep -c '^Address' "$keypair_file") -1 ))
        else
          source_account=$(sed "1q;d" "$keypair_file" | awk '{for (r=1; r<=NF; r++) if ($r == "Address:") print $(r+1)}')
          total_accounts=$(echo "$accounts" | wc -l)
        fi
        if curl -s -f "$xahaud_server" > /dev/null; then
          xahaud_server_working=$(curl -s -f -m 10 -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' "${xahaud_server}"  | jq -r '.result.status // "\\Z1failed\\Zn"' | xargs -I {} echo "\Z2{}\Zn")
          xah_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_info", "params": [ { "account": "'"$source_account"'", "strict": true, "ledger_index": "current", "queue": true } ] }' "${xahaud_server}" | jq -r '.result.account_data.Balance // "\\Z1not activated\\Zn"' )
          if [[ "$xah_balance" != *"not activated"* ]]; then
            xah_balance="\Z2$(echo "scale=1; $xah_balance / 1000000" | bc)\Zn"
          fi

          evr_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_lines", "params": [ { "account": "'"$source_account"'", "ledger_index": "current" } ] }' "${xahaud_server}" | jq -r 'try .result.lines[] catch "failed" | try select(.currency == "EVR") catch "failed" | try .balance catch "\\Z1no trustline\\Zn"' )
          if [[ "$evr_balance" != *"no trustline"* ]]; then
            evr_balance="\Z2$evr_balance\Zn"
          fi
        else
          xahaud_server_working="\Zb\Z1failed to connect\Zn"
          xah_balance="\Zb\Z1failed to connect\Zn"
          evr_balance="\Zb\Z1failed to connect\Zn"
        fi
        if dialog --backtitle "Proxmox VE Helper Scripts: Wallet Management $ver" \
       --title "transfer_funds module" --colors \
       --yesno "\
\Z0\ZbInfo on module:\Zn
    This module is used to sweep EVR and XAH from all accounts to the source account 
    it does this by utilising the regular key secret.
    so will need to be set on all accounts (can be done with wallet setup module)

\Z0\ZbSettings:\Zn
    use_testnet = \"$use_testnet\"
    xahau server = \"$xahaud_server\"
    XAH transfer/sweep = \"$xah_transfer\"
    minimum_EVR to trigger transfer = \"$minimum_evr_transfer\"
    auto_adjust_fee = \"$auto_adjust_fee\"
    fee_adjust_amount = \"$fee_adjust_amount\"

\Z0\ZbCheckup:\Zn
    xahau server working = \"$xahaud_server_working\"
    total accounts to be swept = \"$total_accounts\"
    source account/regular key = \"$source_account\"
    current XAH amount in account = \"$xah_balance\"
    current EVR amount in account = \"$evr_balance\"

Do you want to use the above settings to sweep accounts?" 25 100; then
          clear
          node evernode_monitor.js transfer_funds
          echo ""
          read -n 1 -s -r -p "Press any key to continue..."
        fi

      ######### check balance
      elif [ "$WALLET_TASK" == "3" ]; then
        if [ "$use_testnet" == "true" ]; then
          xahaud_server=$xahaud_test
        else
          xahaud_server=$xahaud
        fi
        xahaud_server=$(echo "$xahaud_server" | sed -e 's/^wss:/https:/' -e 's/^ws:/http:/')
        if [ "$use_keypair_file" == "true" ]; then
          source_account="$sourceAccount"
          total_accounts=$(( $(grep -c '^Address' "$keypair_file") -1 ))
          if [ -f "$keypair_rep_file" ]; then
            total_rep_accounts=$(grep -c '^Address' "$keypair_rep_file" || 0 )
            total_accounts=$(( total_accounts + total_rep_accounts ))
          fi
        else
          source_account=$(sed "1q;d" "$keypair_file" | awk '{for (r=1; r<=NF; r++) if ($r == "Address:") print $(r+1)}')
          total_accounts=$(echo "$accounts$reputationAccounts" | wc -l)
        fi
        if curl -s -f "$xahaud_server" > /dev/null; then
          xahaud_server_working=$(curl -s -f -m 10 -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' "${xahaud_server}"  | jq -r '.result.status // "\\Z1failed\\Zn"' | xargs -I {} echo "\Z2{}\Zn")
          xah_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_info", "params": [ { "account": "'"$source_account"'", "strict": true, "ledger_index": "current", "queue": true } ] }' "${xahaud_server}" | jq -r '.result.account_data.Balance // "\\Z1not activated\\Zn"' )
          if [[ "$xah_balance" != *"not activated"* ]]; then
            xah_balance="\Z2$(echo "scale=1; $xah_balance / 1000000" | bc)\Zn"
          fi

          evr_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_lines", "params": [ { "account": "'"$source_account"'", "ledger_index": "current" } ] }' "${xahaud_server}" | jq -r 'try .result.lines[] catch "failed" | try select(.currency == "EVR") catch "failed" | try .balance catch "\\Z1no trustline\\Zn"' )
          if [[ "$evr_balance" != *"no trustline"* ]]; then
            evr_balance="\Z2$evr_balance\Zn"
          fi
        else
          xahaud_server_working="\Zb\Z1failed to connect\Zn"
          xah_balance="\Zb\Z1failed to connect\Zn"
          evr_balance="\Zb\Z1failed to connect\Zn"
        fi

        if dialog --backtitle "Proxmox VE Helper Scripts: Wallet Management $ver" \
       --title "monitor_balance module" --colors \
       --yesno "\
\Z0\ZbInfo on module:\Zn
    This module iterates through all the accounts,
    and makes sure it has the correct amount of XAH and EVR 
    depending on settings, and account type.

\Z0\ZbSettings:\Zn
    use_testnet = \"$use_testnet\"
    xahau server = \"$xahaud_server\"
    XAH transfer sweep = \"$xah_transfer\"
    xah_balance_threshold to trigger topup = \"$xah_balance_threshold\"
    evr_balance_threshold to triiget topup = \"$evr_balance_threshold\"
    auto_adjust_fee = \"$auto_adjust_fee\"
    fee_adjust_amount = \"$fee_adjust_amount\"

\Z0\ZbCheckup:\Zn
    xahau server working = \"$xahaud_server_working\"
    total accounts to be swept = \"$total_accounts\"
    source account = \"$source_account\"
    current XAH amount in account = \"$xah_balance\"
    current EVR amount in account = \"$evr_balance\"

      Do you want to use the above settings to check balances and topup?" 25 100; then
          clear
          node evernode_monitor.js monitor_balance
          echo ""
          read -n 1 -s -r -p "Press any key to continue..."
        fi

      ######### check heartbeats
      elif [ "$WALLET_TASK" == "4" ]; then
        if [ "$use_testnet" == "true" ]; then
          xahaud_server=$xahaud_test
        else
          xahaud_server=$xahaud
        fi
        xahaud_server=$(echo "$xahaud_server" | sed -e 's/^wss:/https:/' -e 's/^ws:/http:/')
        if [ "$use_keypair_file" == "true" ]; then
          source_account=$sourceAccount
          total_accounts=$(( $(grep -c '^Address' "$keypair_file") -1 ))
        else
          source_account=$(sed "1q;d" "$keypair_file" | awk '{for (r=1; r<=NF; r++) if ($r == "Address:") print $(r+1)}')
          total_accounts=$(echo "$accounts" | wc -l)
        fi
        if curl -s -f "$xahaud_server" > /dev/null; then
          xahaud_server_working=$(curl -s -f -m 10 -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' "${xahaud_server}"  | jq -r '.result.status // "\\Z1failed\\Zn"' | xargs -I {} echo "\Z2{}\Zn")
          xah_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_info", "params": [ { "account": "'"$source_account"'", "strict": true, "ledger_index": "current", "queue": true } ] }' "${xahaud_server}" | jq -r '.result.account_data.Balance // "\\Z1not activated\\Zn"' )
          if [[ "$xah_balance" != *"not activated"* ]]; then
            xah_balance="\Z2$(echo "scale=1; $xah_balance / 1000000" | bc)\Zn"
          fi

          evr_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_lines", "params": [ { "account": "'"$source_account"'", "ledger_index": "current" } ] }' "${xahaud_server}" | jq -r 'try .result.lines[] catch "failed" | try select(.currency == "EVR") catch "failed" | try .balance catch "\\Z1no trustline\\Zn"' )
          if [[ "$evr_balance" != *"no trustline"* ]]; then
            evr_balance="\Z2$evr_balance\Zn"
          fi
        else
          xahaud_server_working="\Zb\Z1failed to connect\Zn"
          xah_balance="\Zb\Z1failed to connect\Zn"
          evr_balance="\Zb\Z1failed to connect\Zn"
        fi

        if [[ "$destinationEmail" != "" || "$destinationEmail" != "< your destination email >" ]]; then
          #email_used="$destinationEmail"
          email_used="\Z1NOT SET\Zn"
        else
          if [ "$smtpEmail" == "<your account email in Brevo>" ]; then
            email_used="\Z1NOT SET\Zn"
          else
            email_used="$smtpEmail"
          fi
        fi

        IFS=$'\n' read -r -d '' -a push_addresses <<< "$push_addresses" || true

        if dialog --backtitle "Proxmox VE Helper Scripts: Wallet Management $ver" \
       --title "monitor_heartbeats module" --colors \
       --yesno "\
\Z0\ZbInfo on module:\Zn
    This module iterates through all the accounts,
    and report back when the last heartbeat was of the evernode
    so you can check if the evernode has been working correctly. 

\Z0\ZbSettings:\Zn
    use_testnet = \"$use_testnet\"
    xahau server = \"$xahaud_server\"
    minutes_from_last_heartbeat_alert_threshold = \"$minutes_from_last_heartbeat_alert_threshold\"
    the interval (in minutes) between sending alert = \"$alert_repeat_interval_in_minutes\"
    email_notification enabled = \"$email_notification\"
    email being used = \"$email_used\"
    UptimeKuma push_notification enabled = \"$push_notification\"
    using UptimeKuma push_url = \"$push_url\"
    number of addresses in push_addresses = \"${#push_addresses[@]}\"

\Z0\ZbCheckup:\Zn
    xahau server working = \"$xahaud_server_working\"
    total evernodes to be checked = \"$total_accounts\"

      Do you want to use the above settings to check heartbeats?" 25 100; then
          clear
          node evernode_monitor.js monitor_heartbeat
          echo ""
          read -n 1 -s -r -p "Press any key to continue..."
        fi

      ######### check claimrewards
      elif [ "$WALLET_TASK" == "5" ]; then
        if [ "$use_testnet" == "true" ]; then
          xahaud_server=$xahaud_test
        else
          xahaud_server=$xahaud
        fi
        xahaud_server=$(echo "$xahaud_server" | sed -e 's/^wss:/https:/' -e 's/^ws:/http:/')
        if [ "$use_keypair_file" == "true" ]; then
          source_account=$sourceAccount
          total_accounts=$(( $(grep -c '^Address' "$keypair_file") -1 ))
        else
          source_account=$(sed "1q;d" "$keypair_file" | awk '{for (r=1; r<=NF; r++) if ($r == "Address:") print $(r+1)}')
          total_accounts=$(echo "$accounts" | wc -l)
        fi
        if curl -s -f "$xahaud_server" > /dev/null; then
          xahaud_server_working=$(curl -s -f -m 10 -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' "${xahaud_server}"  | jq -r '.result.status // "\\Z1failed\\Zn"' | xargs -I {} echo "\Z2{}\Zn")
          xah_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_info", "params": [ { "account": "'"$source_account"'", "strict": true, "ledger_index": "current", "queue": true } ] }' "${xahaud_server}" | jq -r '.result.account_data.Balance // "\\Z1not activated\\Zn"' )
          if [[ "$xah_balance" != *"not activated"* ]]; then
            xah_balance="\Z2$(echo "scale=1; $xah_balance / 1000000" | bc)\Zn"
          fi
        else
          xahaud_server_working="\Zb\Z1failed to connect\Zn"
          xah_balance="\Zb\Z1failed to connect\Zn"
        fi

        if dialog --backtitle "Proxmox VE Helper Scripts: Wallet Management $ver" \
       --title "monitor_claimrewards module" --colors \
       --yesno "\
\Z0\ZbInfo on module:\Zn
    This module iterates through all the accounts,
    checks if the account has been registered for balance adjustment rewards
    if it has not, it will register.
    then will check and report if it can claim,
    and will tell you the amount claimable, date, and claim if possible.

\Z0\ZbSettings:\Zn
    use_testnet = \"$use_testnet\"
    xahau server = \"$xahaud_server\"

\Z0\ZbCheckup:\Zn
    xahau server working = \"$xahaud_server_working\"
    total evernodes to be checked = \"$total_accounts\"

      Do you want to use the above settings to check registrations?" 25 100; then
          clear
          node evernode_monitor.js monitor_claimreward
          echo ""
          read -n 1 -s -r -p "Press any key to continue..."
        fi

      ######### install cronjob
      elif [ "$WALLET_TASK" == "6" ]; then
        if [ "$use_testnet" == "true" ]; then
          xahaud_server=$xahaud_test
        else
          xahaud_server=$xahaud
        fi
        xahaud_server=$(echo "$xahaud_server" | sed -e 's/^wss:/https:/' -e 's/^ws:/http:/')
        if [ "$use_keypair_file" == "true" ]; then
          source_account=$sourceAccount
          total_accounts=$(( $(grep -c '^Address' "$keypair_file") -1 ))
        else
          source_account=$(sed "1q;d" "$keypair_file" | awk '{for (r=1; r<=NF; r++) if ($r == "Address:") print $(r+1)}')
          total_accounts=$(echo "$accounts" | wc -l)
        fi
        if curl -s -f "$xahaud_server" > /dev/null; then
          xahaud_server_working=$(curl -s -f -m 10 -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' "${xahaud_server}"  | jq -r '.result.status // "\\Z1failed\\Zn"' | xargs -I {} echo "\Z2{}\Zn")
          xah_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_info", "params": [ { "account": "'"$source_account"'", "strict": true, "ledger_index": "current", "queue": true } ] }' "${xahaud_server}" | jq -r '.result.account_data.Balance // "\\Z1not activated\\Zn"' )
          if [[ "$xah_balance" != *"not activated"* ]]; then
            xah_balance="\Z2$(echo "scale=1; $xah_balance / 1000000" | bc)\Zn"
          fi
          evr_balance=$(curl -s -X POST -H "Content-Type: application/json" -d '{ "method": "account_lines", "params": [ { "account": "'"$source_account"'", "ledger_index": "current" } ] }' "${xahaud_server}" | jq -r 'try .result.lines[] catch "failed" | try select(.currency == "EVR") catch "failed" | try .balance catch "\\Z1no trustline\\Zn"' )
          if [[ "$evr_balance" != *"no trustline"* ]]; then
            evr_balance="\Z2$evr_balance\Zn"
          fi
        else
          xahaud_server_working="\Zb\Z1failed to connect\Zn"
          xah_balance="\Zb\Z1failed to connect\Zn"
          evr_balance="\Zb\Z1failed to connect\Zn"
        fi

        if dialog --backtitle "Proxmox VE Helper Scripts: Wallet Management $ver" \
       --title "install monitor as cronjob" --colors \
       --yesno "\
\Z0\ZbInfo on module:\Zn
    This module will install the evernode-deploy-monitor to run regularly depending on
    cronjob_main_hours setting in .env file, which is the amount of hours between triggers.
    it will also setup a seperate cronjob for the heartbeat module, that depends on
    cronjob_heartbeat_mins setting in .env file. which is the amount minutes between the triggers.
    you can manually run and test heartbeat module via main menu, option 4
    (setting cronjob times to zero, and running setting will disable/delete entry)

\Z0\ZbSettings:\Zn
    use_testnet = \"$use_testnet\"
    xahau server = \"$xahaud_server\"
    XAH transfer/sweep = \"$xah_transfer\"
    minimum_EVR to trigger transfer = \"$minimum_evr_transfer\"
    minutes_from_last_heartbeat_alert_threshold = \"$minutes_from_last_heartbeat_alert_threshold\"
    run_funds_transfer = \"$run_funds_transfer\"
    run_monitor_balance = \"$run_monitor_balance\"
    run_monitor_heartbeat = \"$run_monitor_heartbeat\"
    auto_adjust_fee = \"$auto_adjust_fee\"
    fee_adjust_amount = \"$fee_adjust_amount\"

\Z0\ZbCheckup:\Zn
    xahau server working = \"$xahaud_server_working\"
    total accounts to be monitored = \"$total_accounts\"
    source account = \"$source_account\"
    main cronjob to run every \"$cronjob_main_hours\" hours
    heartbeat module cronjob to run every \"$cronjob_heartbeat_mins\" minutes

      Do you want to use the above settings to install monitor?" 32 100; then
            clear
            existing_crontab=$(crontab -l 2>/dev/null)
            cronjob_main="* */$cronjob_main_hours * * * . $HOME/.bashrc && node /root/evernode-deploy-monitor/evernode_monitor.js"
            cronjob_heartbeat="*/$cronjob_heartbeat_mins * * * * . $HOME/.bashrc && node /root/evernode-deploy-monitor/evernode_monitor.js monitor_heartbeat"
            if crontab -l | grep -q "/usr/bin/node /root/evernode-deploy-monitor/evernode_monitor.js"; then
                existing_crontab=$(echo "$existing_crontab" | sed 'node \/root\/evernode-deploy-monitor\/evernode_monitor\.js/d')
                existing_crontab=$(echo "$existing_crontab" | sed 'node \/root\/evernode-deploy-monitor\/evernode_monitor\.js/d')
                if [ "$cronjob_main_hours" != "0" ]; then existing_crontab="${existing_crontab}"$'\n'"${cronjob_main}" ;fi
                if [ "$cronjob_heartbeat_mins" != "0" ]; then existing_crontab="${existing_crontab}"$'\n'"${cronjob_heartbeat}" ;fi
                echo -e "${DGN}Cron job updated to run evernode monitor every $cronjob_main_hours hour(s), and heartbeat module every $cronjob_heartbeat_mins minutes${CL}"
            else
                if [ "$cronjob_main_hours" != "0" ]; then existing_crontab="${existing_crontab}"$'\n'"${cronjob_main}" ;fi
                if [ "$cronjob_heartbeat_mins" != "0" ]; then existing_crontab="${existing_crontab}"$'\n'"${cronjob_heartbeat}" ;fi
                echo -e "${DGN}Cron job added to run evernode monitor every $cronjob_main_hours hours, and heartbeat module every $cronjob_heartbeat_mins minutes${CL}"
            fi
            echo "$existing_crontab" | crontab -
            echo ""
            read -n 1 -s -r -p "Press any key to continue..."
        fi
      ######### uptime kuma
      elif [ "$WALLET_TASK" == "7" ]; then
        while true; do
          if UPTIMEKUMA_TASK=$(dialog --cancel-label "Exit" --backtitle "Proxmox VE Helper Scripts: Wallet Management $ver" \
            --title "uptime kuma" \
            --menu "What operation to perform?" 15 78 6 \
            "1" "install uptime kuma" \
            "2" "auto populate monitors with addresses in key_pair.txt file" \
            "3" "start the console viewer for uptime kuma" \
            "4" "details to setup NPM" \
            "<" "<<<< return back to menu" \
            2>&1 >/dev/tty
          ); then
            ######### install uptime kuma
            if [ "$UPTIMEKUMA_TASK" == "1" ]; then
              clear
              msg_info_ "git clone uptime-kuma repo...                                                                       "
              if [ -d "/root/uptime-kuma" ]; then
                  # echo "Pulling latest changes from github..."
                  cd /root/uptime-kuma
                  #git pull https://github.com/louislam/uptime-kuma.git master 2>&1 | awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33mgit updating repo.. \033[0m%s", substr($0, 1, 65) }' || msg_error "error pulling updates" || true
              else
                  #echo "Cloning https://github.com/louislam/uptime-kuma.git repository..."
                  git clone https://github.com/louislam/uptime-kuma.git /root/uptime-kuma 2>&1 | awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33mcloning repo.. \033[0m%s", substr($0, 1, 65) }' || msg_error "cloning repo" || true
                  cd /root/uptime-kuma
                  npm run setup  2>&1 | awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33msetting up.. \033[0m%s", substr($0, 1, 65) }' || msg_error "error running uptime kuma setup" || true
                  #echo "updating NPM dependencies..."
              fi
              msg_ok "uptime-kumo repo cloned."
              

              msg_info_ "installing pm2...                                                                                    "
              apt update >/dev/null 2>&1
              npm install pm2 -g 2>&1 | awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33minstalling pm2.. \033[0m%s", substr($0, 1, 75) }' || msg_error "installing pm2" || true
              pm2 install pm2-logrotate -g 2>&1| awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33minstalling pm2-logrotate.. \033[0m%s", substr($0, 1, 75) }' || true
              msg_ok "pm2 installed."

              msg_info_ "setting up pm2... and starting uptime-kuma                                                           "
              pm2 start /root/uptime-kuma/server/server.js --name uptime-kuma 2>&1 | awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33mstarting server.. \033[0m%s", substr($0, 1, 75) }' || msg_error "error starting uptime kuma (already running?)" || true 
              pm2 save 2>&1 | awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33minstalling at startup.. \033[0m%s", substr($0, 1, 75) }' || msg_error "error while saving setup" || true
              pm2 startup 2>&1 | awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33minstalling at startup.. \033[0m%s", substr($0, 1, 75) }' || msg_error "error while setting startup" || true
              msg_ok "uptime-kuma installed, and started"

              msg_info_ "checking firewall                                                                            "
              if command -v ufw &> /dev/null; then
                ufw allow 3001 2>&1 | awk '{ gsub(/[\r\n\t\v\f\b\033\/\-\|\\]/, ""); printf "\033[K\r     \033[33mchecking firewall.. \033[0m%s", substr($0, 1, 75) }'
                msg_ok "firewall checked and setup"
              else
                msg_ok "firewall app ufw not installed."
              fi
              echo
              LOCAL_IP=$(hostname -I | awk '{print $1}')
              echo -e "${CM}${DGN} uptime-kuma installed, and started, you can now configure admin login, and view it at ${BGN}http://${LOCAL_IP}:3001${CL}"

              echo
              read -n 1 -s -r -p "finished, Press any key to continue..."

            ######### auto populate uptime kuma monitors
            elif [ "$UPTIMEKUMA_TASK" == "2" ]; then
              clear
              if [ -z "$push_url" ] || [ -z "$push_user" ] || [ -z "$push_pass" ]; then
                echo ".env file not setup will all needed settings, check push_url, push_user, and push_pass entries and retry"
              elif [ ! -f "$keypair_file" ] || [ "$(( $(grep -c '^Address' "$keypair_file") - 2 ))" -eq 0 ]; then
                echo "Not enough addresses to create files in $keypair_file."
              elif ! curl -s -f "$push_url" > /dev/null; then
                echo "unable to communicate with $push_url, this needs to be set properly as a fully working URL to your UptimeKuma page"
              else
                if [ ! -f kuma_cli ]; then 
                  wget -q -O /root/uptime-kuma/kuma_cli https://gadget78.uk/kuma_cli || msg_error "failed to download kuma command line (kuma_cli), restart script to try again"
                  chmod +x /root/uptime-kuma/kuma_cli
                fi
                push_addresses=""
                if [[ "$push_url" != */ ]]; then push_url="$push_url/"; fi

                kuma_monitor_list=$(/root/uptime-kuma/kuma_cli --url $push_url --username $push_user --password $push_pass monitor list)
                echo "Amount of monitors found already on your uptime kuma = $(echo "$kuma_monitor_list" | jq 'length')"

                for (( id=3; id<=$(( $(grep -c '^Address' "$keypair_file") )); id++ ))
                do
                  # Extract the token_id (first 16 characters of the line)
                  token_id=$(grep '^Address' "$keypair_file" | sed -n "${id}p" | cut -c 10-26)
                  kuma_monitor_list_id=$(echo "$kuma_monitor_list" | jq -r 'to_entries[] | select(.value.pushToken == "'"$token_id"'") | .key')
                  #echo "$id, $token_id, $kuma_monitor_list"
                  if [ "$kuma_monitor_list_id" == "" ]; then
                    echo "adding monitor \"evernode $((id - 2))\" with token \"$token_id\""
                    json_content=$(cat <<EOF
{
  "name": "evernode$((id - 2))",
  "type": "push",
  "active": "true",
  "interval": "1800",
  "retryInterval": "1800",
  "maxretries": "48",
  "push_token": "$token_id"
}
EOF
                    )
                    echo "$json_content" > "$TEMP_DIR/push_monitor_$id.json"
                    /root/uptime-kuma/kuma_cli --url $push_url --username $push_user --password $push_pass monitor add "$TEMP_DIR/push_monitor_$id.json"
                  else
                    echo "monitor already exists with token \"$token_id\" editing name to \"evernode $((id - 2))\""
                    json_content=$(cat <<EOF
{
  "id": "$kuma_monitor_list_id",
  "name": "evernode$((id - 2))",
  "type": "push",
  "active": "true",
  "interval": "1800",
  "retryInterval": "1800",
  "maxretries": "48",
  "push_token": "$token_id"
}
EOF
                    )
                    echo "$json_content" > "$TEMP_DIR/push_monitor_$id.json"
                    /root/uptime-kuma/kuma_cli --url $push_url --username $push_user --password $push_pass monitor edit "$TEMP_DIR/push_monitor_$id.json"
                  fi

                  push_addresses="${push_addresses}${push_url}api/push/${token_id}"$'\n'
                  sleep 2
                done
                echo
                push_addresses=$(printf '%s\n' "$push_addresses" | sed '$!N;s/\n$//')                 # removed the now undeeded last add newline
                push_addresses=$(echo "$push_addresses" | sed ':a;N;$!ba;s/[&/\]/\\&/g;s/\n/\\n/g')   # checks and adds breakout characters for special characters including newline characters etc
                sed -i -e "/^push_addresses=/,/^[[:space:]]*$/ {
                  /^push_addresses=/!d
                  s|^push_addresses=.*|push_addresses=\"${push_addresses}\"\\n|
                }" /root/evernode-deploy-monitor/.env
              fi
              echo
              read -n 1 -s -r -p "finished, Press any key to continue..."

            ######### pm2 monit
            elif [ "$UPTIMEKUMA_TASK" == "3" ]; then
              clear
              pm2 monit || msg_error "problem with running or finding pm2 monitor"
              echo
              read -n 1 -s -r -p "finished, Press any key to continue..."
            
            ######### NPM info
            elif [ "$UPTIMEKUMA_TASK" == "4" ]; then
              clear
              LOCAL_IP=$(hostname -I | awk '{print $1}')
              echo "use NPM, and setup a new proxy host, using preferred Domain, with IP of http://${LOCAL_IP} and port 3001"
              read -n 1 -s -r -p "finished, Press any key to continue..."
            
            ######### return to main menu
            elif [ "$UPTIMEKUMA_TASK" == "<" ]; then
              break
            fi

          else
            exit-script
          fi
        done

      ######### config .env
      elif [ "$WALLET_TASK" == "8" ]; then
        nano /root/evernode-deploy-monitor/.env
        source /root/evernode-deploy-monitor/.env
      ######### key_pait.txt edit
      elif [ "$WALLET_TASK" == "9" ]; then
        nano $keypair_file
      ######### key_pait_rep.txt edit
      elif [ "$WALLET_TASK" == "0" ]; then
        nano $keypair_rep_file
      ######### help area
      elif [ "$WALLET_TASK" == "h" ]; then
        while true; do
          if HELP_PAGES=$(dialog --cancel-label "Exit" --backtitle "Proxmox VE Helper Scripts: Wallet Management $ver" \
            --title "help pages" \
            --menu "Which help page to you want to view?" 15 78 6 \
            "1" "main wallet managerment help file" \
            "2" "help with key_pair.txt files" \
            "3" "help setting up uptime kuma" \
            "4" "FAQ" \
            "<" "<<<< return back to menu" \
            2>&1 >/dev/tty
          ); then
          
          if [ "$HELP_PAGES" == "1" ]; then
            dialog --backtitle "README Viewer" --title "README.md" --textbox "README.md" 40 90
          elif [ "$HELP_PAGES" == "<" ]; then
            break
          fi

          fi
        done
      ######### return
      elif [ "$WALLET_TASK" == "<" ]; then
        start_
      fi
    ######### exit
    else
      exit-script
    fi
  done
}

####################################################################################################################################################
###################################################################################
function install_npmplus() {
  clear
  cat <<"EOF"
    _   __      _               ____                           __  ___                                 
   / | / /___ _(_)___  _  __   / __ \_________ __  ____  __   /  |/  /___ _____  ____ _____ ____  _____
  /  |/ / __  / / __ \| |/_/  / /_/ / ___/ __ \| |/_/ / / /  / /|_/ / __  / __ \/ __  / __  / _ \/ ___/
 / /|  / /_/ / / / / />  <   / ____/ /  / /_/ />  </ /_/ /  / /  / / /_/ / / / / /_/ / /_/ /  __/ /    
/_/ |_/\__, /_/_/ /_/_/|_|  /_/   /_/   \____/_/|_|\__, /  /_/  /_/\__,_/_/ /_/\__,_/\__, /\___/_/      PLUS
      /____/                                      /____/                            /____/             
 
EOF
  echo -e "Loading..."
  source <(curl -s https://raw.githubusercontent.com/tteck/Proxmox/main/misc/build.func)
  APP="NginxProxyManagerPlus"
  export var_disk="4"
  export var_cpu="2"
  export var_ram="2048"
  export var_os="debian"
  export var_version="12"
  variables
  catch_errors
  color
  export NEXTID=$(pvesh get /cluster/nextid)
  export CT_TYPE="1"
  export PW=""
  export CT_ID=$NEXTID
  export HN="$APP"
  export DISK_SIZE="$var_disk"
  export CORE_COUNT="$var_cpu"
  export RAM_SIZE="$var_ram"
  export BRG="vmbr0"
  export NET="dhcp"
  export GATE=""
  export APT_CACHER=""
  export APT_CACHER_IP=""
  export DISABLEIP6="no"
  export MTU=""
  export SD=""
  export NS=""
  export MAC=""
  export VLAN=""
  export SSH="no"
  export VERB="no"
  export STD=""
  echo_default

  if ! (whiptail --backtitle "Proxmox VE Helper Scripts" --title "${APP} LXC" --yesno "This will create a New ${APP} LXC. Proceed?" 10 58); then
    clear
    echo -e "⚠  User exited script \n"
    exit
  fi
  SPINNER_PID=""
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "${APP} LXC" --yesno "change advanced settings?" 10 58); then
    advanced_settings
  fi
  
  build_container

  lxc-attach -n "$CTID" -- bash -c "$(wget -qLO - https://gadget78.uk/npmplus-install.sh)" || msg_error "fault setting up container"; exit

  IP=$(pct exec "$CTID" ip a s dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
  pct set "$CTID" -description "<div align='center'><a href='https://github.com/ZoeyVid/NPMplus'><img src='https://github.com/ZoeyVid/NPMplus/blob/2024-07-11-r1/frontend/app-images/logo-text-vertical-grey.png?raw=true' /></a>
  
<a href='https://$IP:81' target='_blank'>https://${IP}:81</a>

<a href='https://Helper-Scripts.com' target='_blank' rel='noopener noreferrer'><img src='https://raw.githubusercontent.com/tteck/Proxmox/main/misc/images/logo-81x112.png'/></a></div>"

  echo "checkpoint"
  exit

}

###################################################################################
function update_script() {
    msg_info "starting xahau node script..."
    bash -c "$(wget -qLO - https://raw.githubusercontent.com/gadget78/xahl-node/main/setup.sh)"
    msg_ok "install/update complete."
    exit
}

###################################################################################
function evernode_deploy_script() {
  if curl -s -f "https://deploy.zerp.network/" > /dev/null; then
    ENTRY_STRING=$(curl -s $gadget_encrypt | base64 | tr '+/' '-_' | tr -d '=' )
    DEPLOY_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" https://deploy.zerp.network/$ENTRY_STRING.sh)
    if [ "$DEPLOY_STATUS" == "403" ]; then
      whiptail --backtitle "Proxmox VE Helper Scripts: evernode deploy script $ver" --msgbox "you dont have access to the evernode deploy script,
contact @gadget78 for access.
giving him this code $ENTRY_STRING" 10 58
      exit
    elif [ "$DEPLOY_STATUS" == "404" ]; then
      whiptail --backtitle "Proxmox VE Helper Scripts: evernode deploy script $ver" --msgbox "deploy script not present ?
contact @gadget78 with your code $ENTRY_STRING
or just try again in 15 mins" 10 58
      exit
    else
      bash -c "$(wget -qLO - https://deploy.zerp.network/$ENTRY_STRING.sh)"
    fi
  else
    whiptail --backtitle "Proxmox VE Helper Scripts: evernode deploy script $ver" --msgbox "unable to connect to deploy server?
contact @gadget78" 8 58
    exit
  fi
}

###################################################################################################################################################################################################################################
###################################################################################################################################################################################################################################
# It All Starts Here !

function start_() {
  if command -v pveversion >/dev/null 2>&1; then
    if MODULE=$(whiptail --backtitle "Proxmox VE Helper Scripts: Evernode Deploy Script $ver" \
                  --title "ProxMox detected..." \
                  --menu "Which module do you want to start?" 12 42 4 \
                  "1" "Wallet Management" \
                  "2" "Evernode Deployment" \
                  "3" "Install NPMplus" \
                  --ok-button "Select" \
                  --cancel-button "Exit" \
                  3>&1 1>&2 2>&3); then
      if [ "$MODULE" == "1" ]; then
        wallet_management_script 
      elif [ "$MODULE" == "2" ]; then
        evernode_deploy_script
      elif [ "$MODULE" == "3" ]; then
        install_npmplus
      fi
    else
      exit-script
    fi
  fi

  if ! command -v pveversion >/dev/null 2>&1; then
    if MODULE2=$(whiptail --backtitle "Proxmox VE Helper Scripts: Evernode Deploy Script $ver" \
                  --title "ProxMox NOT detected..." \
                  --menu "Which module do you want to start?" 10 42 3 \
                  "1" "Wallet Management" \
                  "2" "Xahau Server install or Update" \
                  --ok-button "Select" \
                  --cancel-button "Exit" \
                  3>&1 1>&2 2>&3); then
      if [ "$MODULE2" == "1" ]; then
        wallet_management_script
      else
        update_script
      fi
    else
      exit-script
    fi
  fi
}
if ! command -v curl &> /dev/null; then
  echo "installing curl .... "
  apt update >/dev/null 2>&1
  apt install -y curl 2>&1
fi
export timezone=$(cat /etc/timezone)
color
start_
