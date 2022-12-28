# Keycloak Import User
Bash script

Add some functions from original repository (UKHomeOffice:keycloak-utils):
- autologon configuration file
- password fix
- group management (create / lookup /delete)
- Add Olvid Attributes (position, company)
- use ';' like seperator and UTF-8
- clarify log
- update account from CSV



## [manage-users.sh](./manage-users.sh) - Administer Keycloak accounts from the command-line
See [users.csv](./users.csv.example) for example format.
### Prerequisites in the Keycloak master realm:
1. Create client (eg. keycloak_acct_admin) for this script. Access Type: public.
1. Remove right of this client on master realm, and add right on your new realm only (client roles)
- mange-users
- query-client
- query-groups
- query-realms
- query-users
1. Add a realm script user (eg. olvid_import_users) to the master realm
1. In the realm user's settings > Client Role > "realm-management", assign it this available roles
- mange-users
- query-client
- query-groups
- query-realms
- query-users
1. In realm, enable Direct Grant API at Settings > Login


Available flag :
./manage-users.sh [--test | --delete csv_file | --import csv_file | --login_only | --ex
~                                                                                              port_users | --update_users csv_file

### Import users found in csv
./manage-users.sh --import users.csv

### Delete users found in csv
./manage-users.sh --delete users.csv

### autologon configuration file
Offer capability to store configuration and bypass prompt for configuration 
- copy keycloak.conf.example as keycloak.conf
- insert information and credential
- try it with this command ./manage-users.sh --login_only 


### Unit test
Some basic test for check each function work good
Create, lookup, affect and delete an user (John Doe) and a group (test1)
./import_users.sh --test

## know issues
error 500 or special caracteres appear during importing
-> check encoding of your csv file
to fix it in vim editor, you can use this command : set fileencoding=utf-8

Error during long import (> 150 accounts)
Actual script don't support refresh token and lifespan of access token is 1 minute by default
-> Master realm settings > tokens : set Access Token Lifespan to 3 minutes for example
