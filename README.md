# wp_search_replace
This is a script that takes an WordPress SQL file, replaces all occurrences of a given string by another, and outputs the result in another SQL file.

It is very helpful to safely replace URLs when you move your WordPress:
- from `example.com` to `new-example.com`
- from `localhost` to your production website
- from your production website to your `localhost`

# Requirements
- Install [wp-cli](https://wp-cli.org/#installing) before running the script

# Usage
```
./wp_search_replace.sh
 * (required) -u, --dbuser           username of your local database
 * (required) -i, --input_db_file    path to the original SQL file
 * (required) -o, --output_db_file   where to save the replaced DB
 * (required) -s, --search           string to look for
 * (required) -r, --replace          replace search string with that string
 *            -p, --db_has_password  if your DB has a password
 *            -h, --help             show this message
```

# Example
```
./wp_search_replace.sh \
 -u root \
 -p \
 -i my_original_db.sql \
 -o my_replaced_db.sql \
 -s old-url.com \
 -r new-url.com

```
