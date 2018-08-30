#!/bin/bash


#
# ---------------------------------------------|
#   Infrastructure Slicing v01                 |
#   Written by Jungsu Han                      |
# ---------------------------------------------|
#



if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


IP=103.22.221.74
Port=35357

DB_HOST=172.20.90.167
DB_PASS="fn!xo!ska!"

KEYSTONE_ADMIN_PASS="secrete"


Flavor=$3
Image=$4



#Authentication
echo -n "Input your ID: "
read User_ID
echo -n "Input your Password: "
stty -echo
read Password
echo ""
stty echo

export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=$User_ID
export OS_USERNAME=$User_ID
export OS_PASSWORD=$Password
export OS_AUTH_URL=http://$IP:$Port/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

Output=`openstack token issue`

#echo "check is $Output"

if [ "$Output" == "" ]; then
   echo "Authentication Failed"
   exit 1
fi




##Need to check SLicing ID Part!!!
echo -n "Input Sllicing ID: "
read Slicing

read -ra vars <<< $(mysql -DSlicing_Management -uroot -p'$DB_PASS' -se "SELECT Slicing_ID FROM Slicing where Tenant_ID = '$User_ID' ")
for i in "${vars[i]}"
do echo ""
done
NAME=vars
tmp="${NAME}[@]"
size_var=("${!tmp}")
size="${#size_var[@]}"
((size_1=${size}-1))
#size_l=$(( size - 1 ))
check_val=0
for j in $(seq 0 $size_1 )  
do
# echo ${vars[j]}
if [ "${vars[j]}" == "$Slicing" ]; then
# echo "Correct"
((check_val=${check_val}+1))
else
# echo "Different"
((check_val=${check_val}+0))
fi
done

#for j in $(seq 0 $size_1)
#do
#echo $check_val
if [ "${check_val}" -eq  0 ] ; then
echo "Error: Invalid VLAN ID"
exit 1
else 
echo "VLAN ID checking complete"
fi
#done


export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$KEYSTONE_ADMIN_PASS
export OS_AUTH_URL=http://$IP:$Port/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2


# Flavor & Image
echo -n "Input your Region: "
read REGION

echo -n "Input Flavor: "
read Flavor
echo -n "Input Image: "
read Image

echo -n "Input Instance Name: "
read Instance_name

echo "done"

##Checking Network

net_list=`openstack network list --os-region-name $REGION | grep vlan_$Slicing`


if [ "$net_list" == "" ]; then

  echo "Creating Network.."
  echo

  # Create Network
  openstack network create --project $User_ID --provider-network-type vlan --provider-physical-network provider --provider-segment $Slicing vlan_$Slicing --os-region-name $REGION


  # Obtain Network ID
  Net_ID=`openstack network list --os-region-name $REGION | grep vlan_$Slicing | awk '{print $2}'`

  # Create Subnet
  subnet=`cat network_pool | grep $Slicing | awk '{print $3}'`
  allocation=`cat network_pool | grep $Slicing | awk '{print $4}'`

  openstack subnet create --project demo --subnet-range $subnet --ip-version 4 --network $Net_ID --dns-nameserver 8.8.8.8 --allocation-pool start=$allocation.100,end=$allocation.200 sub_$Slicing --os-region-name $REGION


  export OS_PROJECT_DOMAIN_NAME=default
  export OS_USER_DOMAIN_NAME=default
  export OS_PROJECT_NAME=$User_ID
  export OS_USERNAME=$User_ID
  export OS_PASSWORD=$Password
  export OS_AUTH_URL=http://$IP:$Port/v3
  export OS_IDENTITY_API_VERSION=3
  export OS_IMAGE_API_VERSION=2


  # Create Router
  openstack router create router_$Slicing --os-region-name $REGION

  # Setting External Gateway
  openstack router set --external-gateway public router_$Slicing --os-region-name $REGION

  # Add Port
  openstack router add subnet router_$Slicing sub_$Slicing --os-region-name $REGION
else

 echo "Network has been created"
 echo ""

fi



export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=$User_ID
export OS_USERNAME=$User_ID
export OS_PASSWORD=$Password
export OS_AUTH_URL=http://$IP:$Port/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2



# obtain Network ID
Net_ID=`openstack network list --os-region-name $REGION | grep vlan_$Slicing | awk '{print $2}'`



# Create Instance
openstack server create --os-region-name $REGION --flavor $Flavor --image $Image --nic net-id=$Net_ID $Instance_name



Instance_ID=`openstack server list --os-region-name $REGION | grep $Instance_name | awk '{print $2}'`
Instance_IP=`openstack server list --os-region-name $REGION | grep $Instance_name | awk '{print $8}' | cut -d "=" -f2`


check=0
while [ $check == 0 ]
do

  if [ "$Instance_IP" == "" ] || [ "$Instance_IP" == "|" ]; then
    Instance_IP=`openstack server list --os-region-name $REGION | grep $Instance_name | awk '{print $8}' | cut -d "=" -f2`
  else
    check=1
  fi

done


#Add DB

cat << EOF | mysql -h $DB_HOST -uroot -p$DB_PASS
use Slicing_Management;
INSERT INTO Instance VALUES ('$Instance_ID', '$Instance_IP', '$Slicing');
quit
EOF













