# Create Resource Group
module "resource_group" {
  source = "../terraform-azure-platform/modules/resource_group"
  name   = var.rg_name
}

# Create Storage Account
module "storage_account" {
  source = "../terraform-azure-platform/modules/storage_account"

  name = var.sa_name

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  default_network_action     = "Allow"
  virtual_network_subnet_ids = []
  ip_rules                   = []

  tags = {
    Environment = "dev"
  }
}

# Create App Service Plan
module "app_service_plan" {
  source = "../terraform-azure-platform/modules/app_service_plan"

  name                = var.app_service_plan_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
}

# Create Function App
module "windows_function_app" {
  source = "../terraform-azure-platform/modules/function_app"

  name                       = var.function_app_name
  location                   = module.resource_group.location
  resource_group_name        = module.resource_group.name
  service_plan_id            = module.app_service_plan.id
  storage_account_name       = module.storage_account.name
  storage_account_access_key = module.storage_account.primary_access_key

  tags = var.tags
}

# Create PowerShell Function
module "function" {
  source          = "../terraform-azure-platform/modules/functions"
  name            = "StartStopVM"
  function_app_id = module.windows_function_app.id
  language        = "PowerShell"
  config_json = jsonencode({
    bindings = [
      {
        authLevel = "Function"
        type      = "httpTrigger"
        direction = "in"
        name      = "Request" # matches $Request
        methods   = ["get", "post"]
      },
      {
        type      = "http"
        direction = "out"
        name      = "Response" # matches Push-OutputBinding -Name Response
      }
    ]
  })
  test_data = "{\"name\": \"Terraform\"}"

  # Provide example PowerShell code for run.ps1 file
  run_ps1_content = <<-EOT
    param($Request, $TriggerMetadata)
    $name = $Request.Query.name
    if (-not $name) {
        $name = ($Request.Body | ConvertFrom-Json).name
    }
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 200
        Body       = "Hello, $name!"
    })
  EOT
}

# Create Network Security Group
module "nsg" {
  source              = "../terraform-azure-platform/modules/network_security_group"
  nsg_name            = var.nsg_name
  resource_group_name = module.resource_group.name
  security_rules = {
    ssh = {
      name                       = "AllowSSH"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

# Create VNET and Subnet
module "vnet_subnets" {
  source              = "../terraform-azure-platform/modules/spoke_virtual_network"
  vnet_name           = var.vnet_name
  address_space       = var.add_space
  resource_group_name = module.resource_group.name

  subnets = [
    {
      name             = var.subnet_name
      address_prefixes = var.sub_prefix
      nsg_id           = module.nsg.nsg_id
    }
  ]
}

# Create Linux VMs
module "linux_vms" {
  source = "../terraform-azure-platform/modules/linux_vm"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.vnet_subnets.subnet_ids["funcapp-subnet"]

  vms = {
    "linux-vm-01" = {
      admin_username = "azureuser"
      admin_password = var.linux_vm_password
      vm_size        = "Standard_B1ls"
    }

    "linux-vm-02" = {
      admin_username = "azureuser"
      admin_password = var.linux_vm_password
      vm_size        = "Standard_B1ls"
    }
  }
  tags = {
    Environment = "dev"
  }
}