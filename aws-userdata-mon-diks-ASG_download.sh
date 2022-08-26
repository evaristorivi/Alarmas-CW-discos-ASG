#!/bin/bash
#user-data for disk monitoring on ASG instances.
#Evaristo R. Rivieccio Vega

aws ssm get-parameter --name "alarm_creator.sh" --with-decryption --query 'Parameter.Value' --output text | cat  > /root/create_alarms.sh
chmod +x /root/create_alarms.sh
/root/create_alarms.sh
rm -f /root/create_alarms.sh



