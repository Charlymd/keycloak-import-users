# Keycloak Import User
Bash script

Add some functions from original repository (UKHomeOffice:keycloak-utils):
- autologon configuration file
- password fix
- group management (create / lookup /delete)
- Add Olvid Attributes
- use ';' like seperator and UTF-8
- clarify log

## [import-users.sh](./import-users.sh) - Administer Keycloak accounts from the command-line
See [users.csv](./users.csv.example) for example format.
### Prerequisites in the Keycloak realm:
1. Create client (eg. keycloak_acct_admin) for this script. Access Type: public.
1. Add the realm admin user (eg. realm_admin) to the realm
1. In the realm admin user's settings > Client Role > "realm-management", assign it all available roles
1. In realm, enable Direct Grant API at Settings > Login


Available flag :
./import-users [--test | --delete csv_file | --import csv_file | --login_only]

### Import users found in csv
./import-users.sh --import users.csv

### Delete users found in csv
./import-users.sh --delete users.csv

### autologon configuration file
Offer capability to store configuration and bypass prompt for configuration 
- copy keycloak.conf.example as keycloak.conf
- insert information and credential
- try it with this command ./import-users.sh --login_only 


### Unit test
Some basic test for check each function work good
Create, lookup, affect and delete an user (John Doe) and a group (test1)
./import_users.sh --test
