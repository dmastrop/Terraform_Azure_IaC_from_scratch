#Azure required provider(s) to start out with
# this allows terraform to communicate with the Azure API
# this is how terraform can deploy resources to Azure.  This is
# very similar to the AWS provider setup for terraform.
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli
# # Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      #version = "=3.0.0"
      version = "=2.97.0"
    }
  }

}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "mtc-rg" {
  name     = "mtc-resources"
  location = "East Us"
  tags = {
    environment = "dev"
  }
}
# for billing, etc. the tags help to identify the resource object

# Virtual network
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
resource "azurerm_virtual_network" "mtc-vn" {
  name                = "mtc-network"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  # you could use the actual name "mtc-resources" here but it would be very hard if 
  # that name needs to change. Then each occurrance of its usage would need to be changed.
  # DO not do this. Always use this dot syntax to refer to resources. By referencing we also create
  # dependency. The resrouce group cannot be destroyed until the virtual network that references it is destroyed
  # in this way there is a graceful termination and destruction of resources in the proper order.
  # this virtual network group is DEPENDENT on the resource group above.
  location      = azurerm_resource_group.mtc-rg.location
  address_space = ["10.123.0.0/16"]
  # note that this is CIDR block in AWS terminology and is a list []
  # so multiple subnets can be listed here.

  tags = {
    environment = "dev"
  }
}

# Subnet
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
resource "azurerm_subnet" "mtc-subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.mtc-rg.name
  virtual_network_name = azurerm_virtual_network.mtc-vn.name
  address_prefixes     = ["10.123.1.0/24"]
  # note that like the CIDR block on the virtual network, this is also a list
  # so one can have many subnets defined here within that CIDR block of the virtual network.
}

# Security group (we will be adding as separate resource, rather than inline)
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
resource "azurerm_network_security_group" "mtc-sg" {
  name                = "mtc-sg"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  tags = {
    environment = "dev"
  }
}

# Network security rule
# this rule will allow for development access to the Azure dev-node
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule
resource "azurerm_network_security_rule" "mtc-dev-rule" {
  name                        = "mtc-dev-rule"
  priority                    = 100 #direction                   = "Outbound"
  direction                   = "Inbound"
  access                      = "Allow" #protocol                    = "Tcp"
  protocol                    = "*"     # this will allow ICMP, etc as well.
  source_port_range           = "*"
  destination_port_range      = "*"                #source_address_prefix       = "*"
  source_address_prefix       = "98.234.32.176/32" # we want to limit this to my own ip address.
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  network_security_group_name = azurerm_network_security_group.mtc-sg.name
}

# Security group association
# Need to associate the subnet with the security group and rules above
# so that the subnet can be protected by the rules
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association
resource "azurerm_subnet_network_security_group_association" "mtc-sga" {
  subnet_id                 = azurerm_subnet.mtc-subnet.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id
  # note that we are referencing the ids of both, not the name. The ids are assigned by Azure
  # and are know after the terraform apply and instantiation of the resource.
}
