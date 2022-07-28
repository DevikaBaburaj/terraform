provider "aws" {
   region     = "us-east-1"
}

# variable "user_names" {
#   description = "IAM usernames"
#   type        = list(string)
#   default     = ["user1", "user2", "user3"]
# }

# resource "aws_iam_user" "example" {
#   count = length(var.user_names)
#   name  = var.user_names[count.index]
# }

// for_each

# variable "user_names" {
#   description = "IAM usernames"
#   type        = set(string)
#   default     = ["user1", "user2", "user3"]
# }

# resource "aws_iam_user" "example" {
#   for_each = var.user_names
#   name  = each.value
# }


//for 

# variable "user_names" {
#   description = "IAM usernames"
#   type        = list(string)
#   default     = ["user1", "user2", "user3"]
# } 

# output "print_the_names" {
#   value = [for name in var.user_names : name]
# }
