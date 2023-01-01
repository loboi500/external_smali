#!/bin/bash
#
# This script runs antlr3 generating java code based on .g (ANLTR3) files.
# antlr3 tool itself can be downloaded by running the gradle build.
#
# The script can be run from anywhere (it does not depend on current working directory)
# Set $ANTLR to overwrite antlr location, if desired
#
# After making any changes to the lexer, the update source file(s) generated by
# this script should be checked in to the repository

# Update when switching to a different version of antlr
EXPECTED_ANTLR_VERSION_STR="ANTLR Parser Generator  Version 3.5.2"

# Get the location of this script used to find locations of other things in the tree.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Point to the directory which contains the ANTLR jars.
if [[ -z  "$ANTLR" ]]
then
  # Best effort to find it inside of the gradle cache
  ANTLR="$(find $HOME/.gradle/caches/artifacts-* -name 'org.antlr' | head -n 1)"
fi

# Class that contains the static main function.
ANTLR_MAIN="org.antlr.Tool"

if ! [[ -d "$ANTLR" ]]; then
  echo >&2 "ERROR: Could not find ANTLR jars directory"
  exit 1
fi

# Build up the classpath by finding all the JARs
ANTLR_JARS=""

for jar_file_name in $(find "$ANTLR" -name '*.jar'); do
  if ! [[ -z "$ANTLR_JARS" ]]; then
    ANTLR_JARS+=":"
  fi
  ANTLR_JARS+="$jar_file_name"
done

if [[ -z "$ANTLR_JARS" ]]; then
  echo >&2 "Could not find any JARs in the ANTLR directory"
  echo >&2 "Is '"$ANTLR"' the correct path to the JARs?"
  exit 1
fi

function run_antlr() {
  CLASSPATH="$ANTLR_JARS" java 2>&1 "$ANTLR_MAIN" "$@"
}

ANTLR_VERSION="$(run_antlr -version)"

if [[ -z "$ANTLR_VERSION" ]]
then
  echo >&2 "ERROR: Failed to execute antlr at \"$ANTLR\""
  exit 1
fi

if [[ "$EXPECTED_ANTLR_VERSION_STR" != "$ANTLR_VERSION" ]]
then
  echo >&2 "ERROR: Wrong version of jflex: \"$ANTLR_VERSION\". Expected: \"$EXPECTED_ANTLR_VERSION_STR\""
  exit 1
fi


function generate_file {
  local JAVA_FILE="$1"
  local G_FILE="$2"

  if ! [[ -f "$JAVA_FILE" ]]; then
    echo >&2 "ERROR: File \"$JAVA_FILE\" not found"
    exit 1
  fi

  echo "Re-generating \"$JAVA_FILE\"..."

  [[ -f "$JAVA_FILE" ]] && rm -f "$JAVA_FILE"

  local JAVA_DIR="$(dirname "$JAVA_FILE")"
  # Generate the java file from the antlr file
  run_antlr -verbose -fo "$JAVA_DIR" "$G_FILE"

  # delete trailing space from end of each line to make gerrit happy
  sed 's/[ ]*$//' "$JAVA_FILE" > "$JAVA_FILE.tmp"
  [[ -f "$JAVA_FILE" ]] && rm "$JAVA_FILE"
  mv "$JAVA_FILE.tmp" "$JAVA_FILE"

  echo "DONE"
  echo ""
  echo ""
}

function cleanup_tokens {
  local JAVA_FILE="$1"

  # delete the tokens file, they are not necessary to actually build from Android.mk
  local TOKEN_FILE="${JAVA_FILE%%\.java}.tokens"
  [[ -f "$TOKEN_FILE" ]] && rm "$TOKEN_FILE"
}

generate_file "$SCRIPT_DIR/src/main/java/org/jf/smali/smaliParser.java" "$SCRIPT_DIR/src/main/antlr/smaliParser.g"
generate_file "$SCRIPT_DIR/src/main/java/org/jf/smali/smaliTreeWalker.java" "$SCRIPT_DIR/src/main/antlr/smaliTreeWalker.g"

# Clean up the tokens, no longer necessary once the tree walker is generated
cleanup_tokens "$SCRIPT_DIR/src/main/java/org/jf/smali/smaliParser.java"
cleanup_tokens "$SCRIPT_DIR/src/main/java/org/jf/smali/smaliTreeWalker.java"

# Uncomment to run interactively
#run_antlr "$@"
