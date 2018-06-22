region = "ap-northeast-1"

vpc_state_config = {
  bucket = "karakaram-tfstate"
  key    = "env:/production/my-vpc.tfstate"
  region = "ap-northeast-1"
}

name = "my-bastion"

instance_count = 1

instance_type = "t2.nano"

key_name = "my-key"

environment = "production"

topick_arn = "arn:aws:sns:ap-northeast-1:274682760725:my-topic"
