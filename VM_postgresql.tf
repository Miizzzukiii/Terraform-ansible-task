# Создание vApp для PostgreSQL
resource "vcd_vapp" "vapp_InfraDev_PostgreSQL" {
  name    = "vapp-InfraDev-PostgreSQL"
  power_on = "true"

  depends_on = [module.network.Net]
}

# Создание сети в vApp для PostgreSQL
resource "vcd_vapp_org_network" "PostgreSQL-routed-network" {
  vapp_name        = vcd_vapp.vapp_InfraDev_PostgreSQL.name
  org_network_name = module.network.Net.name
}

# Создание диска для PostgreSQL VM
resource "vcd_vm_internal_disk" "postgresql-inf-d-01-disk1" {
  vapp_name      = vcd_vapp.vapp_InfraDev_PostgreSQL.name
  vm_name        = vcd_vapp_vm.postgresql-inf-d-01.name
  size_in_mb     = "20480"
  bus_type       = "parallel"
  storage_profile = var.storage_profile
  bus_number     = 1
  unit_number    = 1
  depends_on     = [vcd_vapp_vm.postgresql-inf-d-01]
}

# Создание VM для PostgreSQL
resource "vcd_vapp_vm" "postgresql-inf-d-01" {
  vapp_name     = vcd_vapp.vapp_InfraDev_PostgreSQL.name
  name          = "postgresql-inf-d-01"
  computer_name = "postgresql-inf-d-01"
  catalog_name  = var.vcd_org_catalog
  template_name = var.template_vm
  memory        = 2048
  cpus          = 2
  cpu_cores     = 1

  metadata = {
    managed = "terraform"
  }

  # Передача кастомного Cloud-Init через переменную
  user_data = var.cloud_config

  depends_on = [module.network.Net, vcd_vapp.vapp_InfraDev_PostgreSQL]

  network {
    type               = "org"
    name               = vcd_vapp_org_network.PostgreSQL-routed-network.org_network_name
    ip_allocation_mode = "pool"  # Автоматическое распределение IP из пула
  }

  customization {
    force                      = false
    enabled                    = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.admin_password
  }


  # Импортирование роли Ansible
  provisioner "file" {
    source      = "devops/infrastructure/roles/postgresql"
    destination = "/tmp/roles/postgresql"
  }

  # Запуск Ansible 
  provisioner "local-exec" {
    inline = [
      "sudo apt-get update && sudo apt-get upgrade -y",
        "ansible-playbook -i ${self.network[0].ip}, -l cloud_InfraDev -t postgresql_role /tmp/roles/postgresql/tasks/main.yml"
    ]
  }
}

# Переменные - пока тут, чтобы не портить общий файл
variable "cloud_config" {
  description = "Cloud-init конфигурация"
  type        = string
}

variable "vapp_name" {
  default = "vapp-InfraDev-PostgreSQL"
}

variable "vcd_org_catalog" {
  default = "default-catalog"
}

variable "template_vm" {
  default = "ubuntu-template"
}

variable "storage_profile" {
  default = "default-storage-profile"
}

# Генерация и передача Cloud-init конфигурации в Terraform
output "cloud_config_output" {
  value = var.cloud_config
}
