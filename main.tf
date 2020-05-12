provider "aws" {
  region = var.region
  profile = var.profile
}

# Get current user (the managed user using OrganizationAccountAccessRole)
data "aws_caller_identity" "current" {}

# set a strict password policy
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length = 6
  require_lowercase_characters = true
  require_numbers = true
  require_uppercase_characters = true
  require_symbols = true
  allow_users_to_change_password = true
}

# create an administrators group
resource "aws_iam_group" "administrators" {
  name = "Administrators"
  path = "/administrators/"
}

# assign AdministratorAccess policy to the group
resource "aws_iam_group_policy_attachment" "administrators_policy" {
  group = aws_iam_group.administrators.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# create a new user called cli
resource "aws_iam_user" "cli" {
  name = "cli"

  tags = {
    Organization = var.organization
    Type = "user"
  }
}

# create an access and secret key using keybase :)
resource "aws_iam_access_key" "cli_access_key" {
  user = aws_iam_user.cli.id
  pgp_key = "keybase:${var.keybase_username}"
}

# assign the user created to the administrators group
resource "aws_iam_user_group_membership" "administrators_membership" {
  user = aws_iam_user.cli.name
  groups = [
    aws_iam_group.administrators.name
  ]
}

# create a private bucket to store the keys generated to the user
resource "aws_s3_bucket" "user_credentials" {
  bucket = "${var.profile}-credentials"
  acl = "private"
  region = var.region

  tags = {
    Organization = var.organization
    Type = "bucket"
  }
}

# create a bucket policy to allow access to the credentials only to the managed account
# the userId should be formatted in the way AROAEXAMPLEID:*
data "aws_iam_policy_document" "bucket_restriction" {
  statement {
    effect = "Deny"
    actions = ["s3:*"]
    resources = ["${aws_s3_bucket.user_credentials.arn}/*"]
    principals {
      identifiers = ["*"]
      type = "AWS"
    }
    condition {
      test = "StringNotLike"
      variable = "aws:userId"
      values = [
        "${split(":", data.aws_caller_identity.current.user_id)[0]}:*"
      ]
    }
  }
}

# assign the policy to the bucket created
resource "aws_s3_bucket_policy" "bucket_restriction" {
  bucket = aws_s3_bucket.user_credentials.id
  policy = data.aws_iam_policy_document.bucket_restriction.json
}

# place an object with the contents of the access and secret key, in json format for better reading
resource "aws_s3_bucket_object" "cli_keys" {
  bucket = aws_s3_bucket.user_credentials.id
  key = "credentials.json"
  server_side_encryption = "AES256"
  content_type = "application/json"
  content = "{\"profile\": \"${var.profile}/${aws_iam_user.cli.name}\", \"aws_access_key_id\": \"${aws_iam_access_key.cli_access_key.id}\", \"aws_secret_access_key\": \"${aws_iam_access_key.cli_access_key.encrypted_secret}\"}"

  tags = {
    Organization = var.organization
    Type = "object"
  }
}
