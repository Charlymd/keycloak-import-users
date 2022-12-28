#!/bin/bash

#### Globals
base_url=""
access_token=""
refresh_token=""
userid=""
realm=""
client_id=""
groupid=""
declare -i compteur_exist=0
declare -i compteur_notexist=0

#### Helpers
process_result() {
  expected_status="$1"
  result="$2"
  msg="$3"

  err_msg=${result% *}
  actual_status=${result##* }

  printf "[HTTP $actual_status] $msg "
  if [ "$actual_status" == "$expected_status" ]; then
    echo "[successful]"
    return 0
  else
    echo "[failed]"
    echo -e "\t$err_msg"
    return 1
  fi
}

kc_login() {
  if [ -f "keycloak.conf" ]; then
    source keycloak.conf && conf=1
    else echo "no configuration file keycloak.conf"; conf=0
  fi
  if [ $conf -ne 1 ]; then
    read -p "Base URL (e.g: https://myhostname/auth): " base_url
    read -p "Realm: " realm
    read -p "Client ID (create this client in the above Keycloak realm): " client_id
    read -p "Admin username: " admin_id
    read -s -p "Admin Password: " admin_pwd
  fi

  result=$(curl --write-out " %{http_code}" -s -k --request POST \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "username=$admin_id&password=$admin_pwd&client_id=$client_id&grant_type=password" \
    "$base_url/realms/master/protocol/openid-connect/token")

  admin_pwd=""  #clear password
  msg="Login"
  process_result "200" "$result" "$msg"
  if [ $? -ne 0 ]; then
    echo "Please correct error before retrying. Exiting."
    exit 1  #no point continuing if login fails
  fi

  # Extract access_token
  access_token=$(sed -E -n 's/.*"access_token":"([^"]+)".*/\1/p' <<< "$result")
  refresh_token=$(sed -E -n 's/.*"refresh_token":"([^"]+)".*/\1/p' <<< "$result")
}

kc_create_user() {
  #first name;last name;username;email;function;company
  firstname="$1"
  lastname="$2"
  username="$3"
  email="$4"
  position="$5"
  company="$6"

  result=$(curl -i -s -k --request POST \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $access_token" \
  --data '{
    "enabled": "true",
    "username": "'"$username"'",
    "email": "'"$email"'",
    "firstName": "'"$firstname"'",
    "lastName": "'"$lastname"'",
    "attributes": {"olvid-position":"'"$position"'","olvid-company":"'"$company"'"},
    "requiredActions":["UPDATE_PASSWORD"]
  }' "$base_url/admin/realms/$realm/users")

  http_code=$(sed -E -n 's,HTTP[^ ]+ ([0-9]{3}) .*,\1,p' <<< "$result") #parse HTTP coded
  msg="action:create user   value:$username"
  process_result "201" "$http_code" "$msg"
  return $? #return status from process_result
}

# update only information of user without password
kc_update_user() {
  #first name;last name;username;email;position;company
  firstname="$1"
  lastname="$2"
  username="$3"
  email="$4"
  position="$5"
  company="$6"
  
  kc_lookup_username "$username"
  echo $fistname $lastname $position $company
  result=$(curl -i -s -k --request PUT \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $access_token" \
  --data '{
    "enabled": "true",
    "username": "'"$username"'",
    "firstName": "'"$firstname"'",
    "lastName": "'"$lastname"'",
    "email": "'"$email"'",
    "attributes": {"olvid-position":"'"$position"'","olvid-company":"'"$company"'"}
  }' "$base_url/admin/realms/$realm/users/$userid")

  http_code=$(sed -E -n 's,HTTP[^ ]+ ([0-9]{3}) .*,\1,p' <<< "$result") #parse HTTP coded
  msg="action:update user   value:$username"
  process_result "204" "$http_code" "$msg"
  return $? #return status from process_result

}


kc_delete_user() {
  userid="$1"

  result=$(curl --write-out " %{http_code}" -s -k --request DELETE \
  --header "Authorization: Bearer $access_token" \
  "$base_url/admin/realms/$realm/users/$userid")

  msg="action:delete user   value:$username"
  process_result "204" "$result" "$msg"
  return $? #return status from process_result
}

## Convert name to global userid
kc_lookup_username() {
  username="$1"
  echo "username="$username
  result=$(curl --write-out " %{http_code}" -s -k --request GET \
  --header "Authorization: Bearer $access_token" \
  "$base_url/admin/realms/$realm/users?username=${username}")

  userid=`echo $result | grep -Eo '"id":".*?"' | cut -d':'  -f 2 | sed -e 's/"//g' | cut -d',' -f 1`
  msg="action:lookup user   value:$username  userid:$userid"
  process_result "200" "$result" "$msg"
 return $? #return status from process_result
}

## Check existing of user
kc_exist_username() {
  username="$1"
  result=$(curl --write-out " %{http_code}" -s -k --request GET \
  --header "Authorization: Bearer $access_token" \
  "$base_url/admin/realms/$realm/users?username=${username}")

  userid=`echo $result | grep -Eo '"id":".*?"' | cut -d':'  -f 2 | sed -e 's/"//g' | cut -d',' -f 1`
  #msg="action:check existing user   value:$username  userid:$userid"
  process_result "200" "$result" "$msg"
  
  echo "action:check user exist   value:$username  userid:$userid";
  if [ -z $userid ];  then
      echo "result: NOK user not exist   value:$username";
      echo "result: NOK user not exist   value:$username" >> /tmp/compare_users.log;

    else
      echo "result: OK user exist   value:$username  userid:$userid";
      echo "result: OK user exist   value:$username  userid:$userid" >> /tmp/compare_users.log;
  fi
  #return $? #return status from process_result
}


kc_create_group() {
  groupname="$1"

  result=$(curl -i -s -k --request POST \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $access_token" \
  --data '{
    "name": "'"$groupname"'"
  }' "$base_url/admin/realms/$realm/groups")

  http_code=$(sed -E -n 's,HTTP[^ ]+ ([0-9]{3}) .*,\1,p' <<< "$result") #parse HTTP coded
  msg="action:create group  value:$groupname"
  process_result "201" "$http_code" "$msg"
  return $? #return status from process_result
}

kc_delete_group() {
  groupname="$1"
  kc_lookup_group $groupname

  result=$(curl -i -s -k --request DELETE \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $access_token" \
  "$base_url/admin/realms/$realm/groups/$groupid")

  http_code=$(sed -E -n 's,HTTP[^ ]+ ([0-9]{3}) .*,\1,p' <<< "$result") #parse HTTP coded
  msg="action:delete group  value:$groupname"
  process_result "204" "$http_code" "$msg"
  return $? #return status from process_result
}


# Convert group name to groupid
kc_lookup_group() {
  group="$1"

  result=$(curl --write-out " %{http_code}" -s -k --request GET \
  --header "Authorization: Bearer $access_token" \
  "$base_url/admin/realms/$realm/groups?first=0&last=1&search=$group")
  groupid=`echo $result | grep -Eo '"id":".*?"' | cut -d':'  -f 2 | sed -e 's/"//g' | cut -d',' -f 1`
  msg="action:lookup group  value:$group  id=$groupid"
  process_result "200" "$result" "$msg"
  return $? #return status from process_result

}


kc_set_group() {
  userid="$1"
  groupid="$2"
  result=$(curl --write-out " %{http_code}" -s -k --request PUT \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $access_token" \
   "$base_url/admin/realms/$realm/users/$userid/groups/$groupid")
  msg="action:group set     value:$groupid"
  process_result "204" "$result" "$msg"
  return $? #return status from process_result
}


kc_set_pwd() {
  userid="$1"
  password="$2"
  result=$(curl --write-out " %{http_code}" -s -k --request PUT \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $access_token" \
  --data '{
    "type": "password",
    "value": "'"$password"'",
    "temporary": "true"
  }' \
  "$base_url/admin/realms/$realm/users/$userid/reset-password")
  msg="action:setpassword   value:$password     userid:$userid"
  process_result "204" "$result" "$msg"
  return $? #return status from process_result
}


kc_logout() {
  result=$(curl --write-out " %{http_code}" -s -k --request POST \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data "client_id=$client_id&refresh_token=$refresh_token" \
  "$base_url/realms/master/protocol/openid-connect/logout")

  msg="action:logout"
  process_result "204" "$result" "$msg" #print HTTP status message
  return $? #return status from process_result
}


######### autonomous functions #############

## Unit tests for helper functions
# Use this to check that the helper functions work
unit_test() {
  echo "Testing normal behaviour with static information. These operations should succeed"
  kc_login
  kc_create_user john doe john.doe john@example.com
  kc_lookup_username "john.doe"
  kc_set_pwd $userid "1@test"
  kc_exist_username $userid
  kc_create_group "group1"
  kc_lookup_group $groupid
  kc_set_group $userid $groupid
  kc_delete_user $userid
  kc_delete_group "group1"
  kc_logout
}


# check existing of user from CSV in Keycloak
compare_users() {
  kc_login
  rm -f /tmp/compare_users.csv
  rm -f /tmp/compare_users.log
  # Import accounts line-by-line
  while read -r line; do
    IFS=';' read -ra arr <<< "$line"
    # CSV file format: "first name[0];last name[1];username[2];email[3];position[4];company[5];group[6];password[7]"
    kc_exist_username "${arr[2]}"
    if [ -z  $userid]; then
      echo "$line" >> /tmp/compare_users.csv
      compteur_notexist=$compteur_notexist+1
    else
      compteur_exist=$compteur_exist+1
    fi
  done < "$csv_file"
  kc_logout
  echo "log: /tmp/compare_users.log";
  echo "not found users csv : /tmp/compare_users.csv";
  echo 'nombre de comptes deja existants : '"$compteur_exist"
  echo 'nombre de comptes absents : '"$compteur_notexist"
}



# export every users
export_users() {
  kc_login
  result=$(curl --write-out " %{http_code}" -s -k --request GET \
  --header "Authorization: Bearer $access_token" \
  "$base_url/admin/realms/$realm/users?briefRepresentation=true&first=0&max=10") ;
  #"$base_url/admin/realms/$realm/users?first=0") 
  #"$base_url/admin/realms/$realm/users?first=0&max=10") ;
  echo "$result"; 
  
  rm -f /tmp/export_users_keycloak.csv
  echo "$result" | jq -r '.[] | [.username,.lastName,.firstName,.attributes."olvid-company"[0],.attributes."olvid-position"[0]] | @csv' >> /tmp/export_users_keycloak.csv
  #echo "$result"  >> /tmp/export_users_keycloak.csv

  msg="action:export list of users"
  process_result "200" "$result" "$msg"
  #echo "200 iterate error is normal, it's HTTP status at the end of request"
  echo "export file: /tmp/export_users_keycloak.csv";
  kc_logout
  #return $? #return status from process_result
}


update_users() {
  kc_login
  # Import accounts line-by-line
  while read -r line; do
    IFS=';' read -ra arr <<< "$line"

    # CSV file format: "first name[0];last name[1];username[2];email[3];position[4];company[5];group[6];password[7]"
    kc_update_user "${arr[0]}" "${arr[1]}" "${arr[2]}" "${arr[3]}" "${arr[4]}" "${arr[5]}"

    # update or skip when no group	    
    if [ -z "${arr[6]}" ]; then
      kc_lookup_group "${arr[6]}"	    
      if [ -z "$groupid" ]; then
           echo "group does not exist";
           kc_create_group "${arr[6]}";
           kc_lookup_group "${arr[6]}";
         else
           echo "group already exist"
           kc_lookup_group "${arr[6]}";
      fi
      kc_set_group "$userid" "$groupid"
      echo "Set group $groupid to $userid" 
    fi
    
    # update or skip when no password
    if [ "${arr[7]}" ]; then kc_set_pwd "$userid" "${arr[7]}" ; fi
  done < "$csv_file"

  kc_logout
}


# Bulk import accounts
# Reads and creates accounts using a CSV file as the source
import_accts() {
  kc_login
  # Import accounts line-by-line
  while read -r line; do
    IFS=';' read -ra arr <<< "$line"

    # CSV file format: "first name[0];last name[1];username[2];email[3];position[4];company[5];group[6];password[7]"
    kc_create_user "${arr[0]}" "${arr[1]}" "${arr[2]}" "${arr[3]}" "${arr[4]}" "${arr[5]}"

    # find user_id of new user
    kc_lookup_username "${arr[2]}"

    if [ "${arr[6]}" ]; then
      kc_lookup_group "${arr[6]}";
      if [ "$groupid" == "" ]; then
           echo "group does not exist";
           kc_create_group "${arr[6]}";
           kc_lookup_group "${arr[6]}";
         else
           echo "group already exist"
           kc_lookup_group "${arr[6]}";
      fi

      kc_set_group "$userid" $groupid
    fi #skip no group

    if [ "${arr[7]}" ]; then kc_set_pwd "$userid" "${arr[7]}" ; fi  #skip if no password
  done < "$csv_file"

  kc_logout
}


delete_accts(){
  kc_login
  while read -r line; do
    IFS=';' read -ra arr <<< "$line"
          kc_lookup_username "${arr[2]}"
          kc_delete_user $userid
  done < "$csv_file"
}

#### Main
if [ $# -lt 1 ]; then
  echo "Keycloak account admin script"
  echo "Usage: $0 [--test | --delete csv_file | --import csv_file | --login_only | --export_users | --compare_user csv_file | --update_users csv_file]"
  echo "Usage: $0 [-t | -d csv_file | -i csv_file | -l | -e | -c csv_file |-u csv_file]"
  exit 1
fi

flag=$1

case $flag in
  -t|--test)
    unit_test
    ;;
  -d|--delete)
    csv_file="$2"
    if [ -z "$csv_file" ]; then
      echo "Error: missing 'csv_file' argument"
      exit 1
    fi
    delete_accts $csv_file
    ;;
  -l|--login_only)
    kc_login
    ;;
  -u|--update_users)
    csv_file="$2"
    update_comment="$3"
    if [ -z "$csv_file" ]; then
      echo "Error: missing 'csv_file' argument"
      exit 1
    fi
    update_users $csv_file $update_comment
    ;;
  -i|--import)
    csv_file="$2"
    if [ -z "$csv_file" ]; then
      echo "Error: missing 'csv_file' argument"
      exit 1
    fi
    import_accts $csv_file
    ;;
  -c|--compare_users)
    csv_file="$2"
    compare_users
    ;;
  -e|--export_users)
    export_users
    ;;
  *)
    echo "Unrecognised flag '$flag'"
    exit 1
    ;;
esac

exit 0
