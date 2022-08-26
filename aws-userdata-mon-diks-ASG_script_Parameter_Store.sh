#!/bin/bash
#user-data for disk monitoring on ASG instances.
#Evaristo R. Rivieccio Vega - Operaciones - Grupo SM

#Poner en true si es QA
QA=false

#CONFIG SNS
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
#LATAM
if [ $REGION == "us-east-1a" ]
then
    ARN_SNS="#######################"
#ESP
elif [ $REGION == "eu-west-1b" ]
then
    ARN_SNS="#######################"
fi

if [ $QA == true ]
then
    ARN_SNS="#######################"
fi

INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)


NAME=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].Tags[?Key == `Name`].Value' --output text)
#Comprueba el tipo de métrica que lleva
grep "InstanceType" /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml
OUTPUT=$?

AUTOSCALING=$(aws autoscaling describe-auto-scaling-instances --query=AutoScalingInstances[].AutoScalingGroupName --instance-ids=$INSTANCE_ID --output text)

#Detecta todos los volúmens configurados en fstab para montar y parametriza la creación de las alarmas de discos.
PART=
FSTYPE=
findmnt --fstab -nt ext4,xfs > /tmp/list_volumes.txt

for line in $(cat "/tmp/list_volumes.txt" | cut -d " " -f1)
do
    
    if [ $(lsblk -nl | grep $line$ | tr -s ' ' | cut -d ' ' -f6) == lvm ]
    then
        PART="mapper/"$(lsblk -fnl | grep $line$ | tr -s ' ' | cut -d ' ' -f1)
        echo "El volumen $line tiene PART=$PART"
    else
        PART=$(lsblk -fnl | grep $line$ | tr -s ' ' | cut -d ' ' -f1)
        echo "El volumen $line tiene PART=$PART"
    fi
    FSTYPE=$(lsblk -fnl | grep $line$ | tr -s ' ' | cut -d ' ' -f 2)
    echo "El volumen $line tiene FSTYPE=$FSTYPE"
    
    #Crea las alarmas con autoscalingroup, InstanceType e ImageId dependiendo de lo que haga falta.
    DIMENSIONS="Name=InstanceId,Value=$INSTANCE_ID Name=device,Value=$PART Name=path,Value=$line Name=fstype,Value=$FSTYPE"
    if [ ! -z "$AUTOSCALING" ]
    then
        DIMENSIONS="$DIMENSIONS Name=AutoScalingGroupName,Value=$AUTOSCALING"
    fi

    if [ $OUTPUT -eq 0 ]
    then
        AMI_ID=$(curl http://169.254.169.254/latest/meta-data/ami-id)
        INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type)
        DIMENSIONS="$DIMENSIONS Name=ImageId,Value=$AMI_ID Name=InstanceType,Value=$INSTANCE_TYPE"
    fi
    echo "Dimensiones configuradas:  $DIMENSIONS"
    aws cloudwatch put-metric-alarm \
    --alarm-name "Automatic_Alarm - $NAME - *$INSTANCE_ID* - disk_used_percent $line >80%"  \
    --comparison-operator GreaterThanThreshold \
    --threshold 80 \
    --alarm-description "$NAME - $INSTANCE_ID - disk_used_percent $line >80%" \
    --metric-name disk_used_percent \
    --evaluation-periods 1 \
    --period 60 \
    --namespace "CWAgent" \
    --statistic Maximum \
    --dimensions $DIMENSIONS \
    --alarm-actions $ARN_SNS
     
done


echo "Alarmas creadas."




