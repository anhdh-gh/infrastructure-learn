aws ssm start-session --target i-00a840ae1dea36d81
aws ssm start-session --target i-0daa48834a379cae6
http://alb-352920564.ap-southeast-1.elb.amazonaws.com
http://alb-352920564.ap-southeast-1.elb.amazonaws.com/dynamodb.html

terraform import aws_ami.ec2-image ami-035bad0417fc1fa64


https://5877yy7d9f.execute-api.ap-southeast-1.amazonaws.com/
https://5877yy7d9f.execute-api.ap-southeast-1.amazonaws.com/dynamodb.html


Register
curl --location 'https://cognito-idp.ap-southeast-1.amazonaws.com/' \
--header 'Content-Type: application/x-amz-json-1.1' \
--header 'X-Amz-Target: AWSCognitoIdentityProviderService.SignUp' \
--data-raw '{
    "ClientId": "ckjc1cq3eqli893dlo4d22oru",
    "Username": "leeit",
    "Password": "Leeit123@",
    "UserAttributes": [
      {
        "Name": "email",
        "Value": "leeit.work@gmail.com"
      }
    ]
  }'

Verify
curl --location 'https://cognito-idp.ap-southeast-1.amazonaws.com/' \
--header 'Content-Type: application/x-amz-json-1.1' \
--header 'X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth' \
--data-raw '{
    "AuthFlow": "USER_PASSWORD_AUTH",
    "ClientId": "ckjc1cq3eqli893dlo4d22oru",
    "AuthParameters": {
      "USERNAME": "leeit",
      "PASSWORD": "Leeit123@"
    }
  }'

Login
curl --location 'https://cognito-idp.ap-southeast-1.amazonaws.com/' \
--header 'Content-Type: application/x-amz-json-1.1' \
--header 'X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth' \
--data-raw '{
    "AuthFlow": "USER_PASSWORD_AUTH",
    "ClientId": "ckjc1cq3eqli893dlo4d22oru",
    "AuthParameters": {
      "USERNAME": "leeit",
      "PASSWORD": "Leeit123@"
    }
  }'

Path need auth
curl --location 'https://5877yy7d9f.execute-api.ap-southeast-1.amazonaws.com/dynamodb' \
--header 'Authorization: Bearer {{access_token}}'