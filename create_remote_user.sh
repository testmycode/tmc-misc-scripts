#!/bin/bash -e

echo
echo "This script creates a user on a given remote machine and either copies their .ssh/authorized_keys over,"
echo "if it exists, or generates a random password for them."
echo "It requires the current user to have passwordless sudo both on this host as well as on the other host."

if [ -z "$1" -o -z "$2" -o "$1" = "--help" -o "$1" = "-h" ]; then
  echo "Usage: $0 remote-hostname username"
  exit
fi

if [ `whoami` == "root" ]; then
  echo "This script should NOT be run as root, but you should have passwordless sudo on this machine!"
  exit 1
fi

if [ -z `which pwgen` ]; then
  echo "Please install pwgen."
  exit 1
fi

REMOTE="$1"
USERNAME="$2"

confirm() {
  echo "Press enter to contiunue."
  read
}

echo
echo "Will now create the user $USERNAME on $REMOTE."
confirm
ssh $REMOTE sudo useradd --create-home --user-group --shell /bin/bash $USERNAME

echo
echo "Will now add the user $USERNAME to the sudo group on $REMOTE."
confirm
ssh $REMOTE sudo adduser $USERNAME sudo

AUTH_KEYS_PATH="/home/$USERNAME/.ssh/authorized_keys"

if sudo [ -f $AUTH_KEYS_PATH ]; then
  echo
  echo "$AUTH_KEYS_PATH exists. Copying it over."
  confirm
  ssh $REMOTE sudo mkdir "/home/$USERNAME/.ssh"
  DEST="/home/$USERNAME/.ssh/authorized_keys"
  sudo cat "$AUTH_KEYS_PATH" | ssh $REMOTE 'sudo /bin/sh -c "cat > '$DEST'"'
  ssh $REMOTE sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
  ssh $REMOTE sudo chmod -R og-rwx "/home/$USERNAME/.ssh"
else
  PASSWORD=`pwgen -s 40 1`
  echo
  echo "Random password: $PASSWORD"

  echo
  echo "Will now set that as the password of $USERNAME on $REMOTE."
  confirm
  ssh $REMOTE sudo chpasswd <<< "$USERNAME:$PASSWORD"
fi
