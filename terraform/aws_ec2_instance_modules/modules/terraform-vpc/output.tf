output "vpc_id" {
    value = "${aws_vpc.vpc.id}"
}

output "subnets" {
    value = "${aws_subnet.public_subnet.*.id}"
}

output "priv_subnet" {
     value = element(aws_subnet.private_subnet.*.id,0)
}