# AWS Account Setup

**What happens after creating an AWS account?**

Regularly you have two options: a) link the new account to an existing master one or b) start working and configuring resources.

Following [AWS Best Practices](https://d1.awsstatic.com/whitepapers/architecture/AWS_Well-Architected_Framework.pdf) you shouldn't use your root account for any other action than Billing purposes.

**Why?**

A root account handles everything in your AWS, even if you assign an `AdministratorAccess` role to a user. That's why you should protect it by enforcing multi-factor authentication (MFA) and removing their assigned access and secret keys.

**So** here's a baseline setup that you can use for getting started in the AWS Console as soon as you created or linked to a Master Account in your organization.

**What's included?**

A [terraform](https://terraform.io) template that performs the following actions:

```
- set a password policy
- create an IAM group with AdministratorAccess permissions
- create a new user called "cli"
- create an access and secret key using keybase :)
- create a private bucket to store the keys generated to the user
- create a bucket policy to allow access to the credentials only to the managed account
- place an object with the contents of the access and secret key, in json format for better reading
```

**How does it work?**

1. Use [keybase](https://keybase.io) and generate a pgp key (really, [you should do it](https://book.keybase.io/security) to simplify your life)
2. Make sure to have [terraform](https://terraform.io) installed
3. _If you're using a root account_, create a **TEMPORARILY** access and secret key to your root account to perform these actions, don't forget to place your credentials in your local `~/.aws/credentials` file. (This is not the recommended way, please remember to remove the root keys created after installing the resources of this template).
4. _If you're using a linked account managed by a master account_, accessing a member account by linked roles is definitely the best way to manage new AWS accounts. Just make sure to add a record in your `~/.aws/config` file that uses `OrganizationAccountAccessRole` role.

```ini
[profile my_new_account]
output = json
region = us-east-1
role_arn = arn:aws:iam::{my_master_account_id}:role/OrganizationAccountAccessRole
source_profile = {my_root_account_profile}
```

Then, run the command by providing some required parameters:
**keybase_username**: The keybase username to use their pgp key and encrypt our aws_secret_access_key
**organization**: Display name of your organization, just for tagging purposes
**profile**: The profile name from your `~/.aws/credentials` or `~/.aws/config` that you plan to use to install these resources
**region**: A valid region name where the resources will be installed

**Ok resources created now what?**

- Retrieve the credentials from the bucket
```sh
aws --profile YourProfile s3 cp s3://YourProfile-credentials/credentials.json - --sse AES256
```

- Wait, my secret key seems to be encrypted, how can I store use it?
```sh
aws --profile YourProfile s3 cp s3://YourProfile-credentials/credentials.json - --sse AES256 | jq -r '.aws_secret_access_key' | base64 --decode | keybase pgp decrypt
```

- All set, please delete any access and secret key generated to your root account if created.

- How can I create new records on my `~/.aws/credentials` file?

```sh
# Download your credentials file into /tmp
aws --profile MyProfile s3 cp s3://MyProfile-credentials/credentials.json /tmp/credentials.json --sse AES256
jq -r '. | .profile,.aws_access_key_id' /tmp/credentials.json | xargs printf 'aws --profile %s configure set aws_access_key_id  %s' $1 $2 | awk '{ system($0) }'
rm /tmp/credentials.json
``` 

**Are there better alternatives?**

Of course, please take a look at the [AWS Landing Zone](https://aws.amazon.com/solutions/aws-landing-zone/) solution.