
#Lambda orphan alarm cleaner.
#Evaristo R. Rivieccio Vega - Operaciones - Grupo SM
import boto3

cloudwatch = boto3.client('cloudwatch')
ec2_resource = boto3.resource('ec2')


def lambda_handler(event, context):
    # TODO implement
    ALARM_LIST=[]
    DELETE_ALARM_NAME=[]
    INSTANCES=[]

    paginator_cloudwatch = cloudwatch.get_paginator('describe_alarms')
    for response in paginator_cloudwatch.paginate(AlarmNamePrefix='Automatic_Alarm'):
        for alarms in response['MetricAlarms']:
            id=alarms["AlarmName"].split("*")[1]
            ALARM_LIST.append({'Name':alarms['AlarmName'],'id':id})
                
    for instance in ec2_resource.instances.all():
        INSTANCES.append(instance.id)

    for items in ALARM_LIST:
        instance = ec2_resource.Instance(items["id"])
        #print (instance.state['Name'])
        if items["id"] not in INSTANCES or instance.state['Name'] == 'shutting-down' or instance.state['Name'] == 'terminated':
            DELETE_ALARM_NAME.append(items["Name"])
        

    if DELETE_ALARM_NAME:
        print ("Se van a eliminar las siguintes alarmas:")
        for print_alarms_delete in DELETE_ALARM_NAME:
            print (print_alarms_delete)

        delete_Alarm = cloudwatch.delete_alarms(
            AlarmNames=DELETE_ALARM_NAME
        )

        body="\n Alarmas huérfanas limpadas." + str(DELETE_ALARM_NAME)
        print (body)
        

    else:
        body="No hay alarmas huérfanas para limpiar."
        print (body)

    return {
        'statusCode': 200,
        'body': body
    }


