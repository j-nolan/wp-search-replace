#!/bin/bash

set -e

show_usage() {
    echo "Usage: $0"
    echo -e " * (required) -u, --dbuser           username of your local database"
    echo -e " * (required) -i, --input_db_file    path to the original SQL file"
    echo -e " * (required) -o, --output_db_file   where to save the replaced DB"
    echo -e " * (required) -s, --search           string to look for"
    echo -e " * (required) -r, --replace          replace search string with that string"
    echo -e " *            -p, --DB_HAS_PASSWORD  if your DB has a password"
    echo -e " *            -h, --help             show this message"
    echo "-----"
    echo "Example: $0 \\"
    echo " -u root \\"
    echo " -p \\"
    echo " -i my_original_db.sql \\"
    echo " -o my_replaced_db.sql \\"
    echo " -s old_url.com \\"
    echo " -r new_url.com"
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -u|--dbuser)
    DB_USER="$2"
    shift
    shift
    ;;
    -i|--input_db_file)
    INPUT_DB_FILE="$2"
    shift
    shift
    ;;
    -o|--output_db_file)
    OUTPUT_DB_FILE="$2"
    shift
    shift
    ;;
    -s|--search)
    SEARCH_STRING="$2"
    shift
    shift
    ;;
    -r|--replace)
    REPLACE_STRING="$2"
    shift
    shift
    ;;
    -p|--db_has_password)
    DB_HAS_PASSWORD=1
    shift
    ;;
    -h|--help)
    SHOW_HELP=1
    shift
    ;;
    *)
    echo "unknown argument $1"
    exit 1
    ;;
esac
done
set -- "${POSITIONAL[@]}"

if [ -n "${SHOW_HELP}" ]; then
    show_usage
    exit 0
fi

if ! type "wp" > /dev/null; then
  echo "error:"
  echo " * WP CLI doesn't seem to be installed on this system."
  echo " * Install it from https://wp-cli.org/#installing and run this script again."
  exit 1
fi

if [ -z "${DB_USER}" ] || [ -z "${INPUT_DB_FILE}" ] || [ -z "${OUTPUT_DB_FILE}" ] || [ -z "${SEARCH_STRING}" ] || [ -z "${REPLACE_STRING}" ]; then
    show_usage
    exit 1
fi

if [ ! -f "$INPUT_DB_FILE" ]; then
    echo "input file does not exist: $INPUT_DB_FILE"
    exit 1
fi

if [ -f "$OUTPUT_DB_FILE" ]; then
    echo "output file already exists: $INPUT_DB_FILE"
    exit 1
fi

if [ -n "$DB_HAS_PASSWORD" ]; then
    read -s -p "enter DB password for user $DB_USER: " DB_PASSWORD
    echo
fi

TIMESTAMP="$(date +%s)"
TMP_DB_NAME="WP_SEARCH_REPLACE_TMP_$TIMESTAMP"
TMP_DIR="WP_SEARCH_REPLACE_TMP_$TIMESTAMP"
TMP_MYSQL_CREDENTIALS_FILE="mysql_credentials"

echo DB_USER = "$DB_USER"
if [ -n "$DB_PASSWORD" ]; then
    echo DB_PASSWORD = "******"
else
    echo DB_PASSWORD = "(none)"
fi
echo INPUT_DB_FILE = "$INPUT_DB_FILE"
echo OUTPUT_DB_FILE = "$OUTPUT_DB_FILE"
echo SEARCH_STRING = "$SEARCH_STRING"
echo REPLACE_STRING = "$REPLACE_STRING"
echo TMP_DB_NAME = "$TMP_DB_NAME"
echo TMP_DIR = "$TMP_DIR"
echo TMP_MYSQL_CREDENTIALS_FILE = "$TMP_MYSQL_CREDENTIALS_FILE"
echo "-----"

mkdir $TMP_DIR && cd "$_"

echo "[Step 0] preparing temporary mysql credentials file..."
echo "[client]" > $TMP_MYSQL_CREDENTIALS_FILE
echo "user=$DB_USER" >> $TMP_MYSQL_CREDENTIALS_FILE
if [ -n "$DB_PASSWORD" ]; then
    echo "password=$DB_PASSWORD" >> $TMP_MYSQL_CREDENTIALS_FILE
fi
echo done!
echo "-----"


echo "[Step 1] creating temporary db..."
mysql --defaults-extra-file="$TMP_MYSQL_CREDENTIALS_FILE" --execute="DROP DATABASE IF EXISTS $TMP_DB_NAME; CREATE DATABASE $TMP_DB_NAME;"
echo done!
echo "-----"

echo "[Step 2] importing original db file into temporary DB..."
echo "(next step can take up to a few minutes)"
mysql --defaults-extra-file="$TMP_MYSQL_CREDENTIALS_FILE" --database=$TMP_DB_NAME < $INPUT_DB_FILE
echo done!
echo "-----"

echo "[Step 3] installing temporary WordPress..."
wp core download
echo done!
echo "-----"

echo "[Step 4] linking temporary WordPress to temporary DB..."
mv wp-config-sample.php wp-config.php
perl -pi -e "s/database_name_here/$TMP_DB_NAME/g" wp-config.php
perl -pi -e "s/username_here/$DB_USER/g" wp-config.php
perl -pi -e "s/password_here/$DB_PASSWORD/g" wp-config.php
echo done!
echo "-----"

echo "[Step 5] search/replace and export to output DB..."
wp search-replace "$SEARCH_STRING" "$REPLACE_STRING" --export=$OUTPUT_DB_FILE
echo done!
echo "-----"

echo "[Step 6] remove tmp DB and directory..."
cd ..
rm -r $TMP_DIR
mysql --defaults-extra-file="$TMP_MYSQL_CREDENTIALS_FILE" --execute="DROP DATABASE IF EXISTS $TMP_DB_NAME;"
echo "-----"
