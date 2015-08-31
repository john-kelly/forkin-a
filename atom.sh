#!/bin/bash

if [ "$(uname)" == 'Darwin' ]; then
  OS='Mac'
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  OS='Linux'
elif [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  OS='Cygwin'
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

while getopts ":wtfvh-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        wait)
          WAIT=1
          ;;
        help|version)
          REDIRECT_STDERR=1
          EXPECT_OUTPUT=1
          ;;
        foreground|test)
          EXPECT_OUTPUT=1
          ;;
      esac
      ;;
    w)
      WAIT=1
      ;;
    h|v)
      REDIRECT_STDERR=1
      EXPECT_OUTPUT=1
      ;;
    f|t)
      EXPECT_OUTPUT=1
      ;;
  esac
done

if [ $REDIRECT_STDERR ]; then
  exec 2> /dev/null
fi

if [ $OS == 'Mac' ]; then
  # FIXME We are changing the app name to MyApp.app, but we have not changed
  # the name of the variable. Need to change all references to ATOM_APP_NAME
  echo Setting ATOM_APP_NAME to MyApp.app
  ATOM_APP_NAME=MyApp.app
  # FIXME Hardcoding the ATOM_PATH for now. Eventually we will change to
  # MYAPP_PATH to avoid confict with atom.
  echo Setting ATOM_PATH to ~/Desktop
  ATOM_PATH=~/Desktop

  # if [ -z "${ATOM_PATH}" ]; then
  #   # If ATOM_PATH isnt set, check /Applications and then ~/Applications for Atom.app
  #   if [ -x "/Applications/$ATOM_APP_NAME" ]; then
  #     ATOM_PATH="/Applications"
  #   elif [ -x "$HOME/Applications/$ATOM_APP_NAME" ]; then
  #     ATOM_PATH="$HOME/Applications"
  #   else
  #     # We havent found an Atom.app, use spotlight to search for Atom
  #     ATOM_PATH="$(mdfind "kMDItemCFBundleIdentifier == 'com.github.atom'" | grep -v ShipIt | head -1 | xargs -0 dirname)"
  #
  #     # Exit if Atom can't be found
  #     if [ ! -x "$ATOM_PATH/$ATOM_APP_NAME" ]; then
  #       echo "Cannot locate Atom.app, it is usually located in /Applications. Set the ATOM_PATH environment variable to the directory containing Atom.app."
  #       exit 1
  #     fi
  #   fi
  # fi

  # NOTE What is the difference between these two branches? The if branch
  # runs some MacOS/Atom file while the else branch simply uses open to open
  # the App.
  if [ $EXPECT_OUTPUT ]; then
    "$ATOM_PATH/$ATOM_APP_NAME/Contents/MacOS/Atom" --executed-from="$(pwd)" --pid=$$ "$@"
    exit $?
  else
    open -a "$ATOM_PATH/$ATOM_APP_NAME" -n --args --executed-from="$(pwd)" --pid=$$ --path-environment="$PATH" "$@"
  fi
elif [ $OS == 'Linux' ]; then
  SCRIPT=$(readlink -f "$0")
  USR_DIRECTORY=$(readlink -f $(dirname $SCRIPT)/..)
  ATOM_PATH="$USR_DIRECTORY/share/atom/atom"

  # NOTE Why is this being setup here instead of in main.cofee? Does the
  # app.getHomeDir() inside main.coffee not work on linux?
  ATOM_HOME="${ATOM_HOME:-$HOME/.atom}"

  mkdir -p "$ATOM_HOME"

  : ${TMPDIR:=/tmp}

  [ -x "$ATOM_PATH" ] || ATOM_PATH="$TMPDIR/atom-build/Atom/atom"

  if [ $EXPECT_OUTPUT ]; then
    "$ATOM_PATH" --executed-from="$(pwd)" --pid=$$ "$@"
    exit $?
  else
    (
    nohup "$ATOM_PATH" --executed-from="$(pwd)" --pid=$$ "$@" > "$ATOM_HOME/nohup.out" 2>&1
    if [ $? -ne 0 ]; then
      cat "$ATOM_HOME/nohup.out"
      exit $?
    fi
    ) &
  fi
fi

# Exits this process when Atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# If the wait flag is set, don't exit this process until Atom tells it to.
if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi
