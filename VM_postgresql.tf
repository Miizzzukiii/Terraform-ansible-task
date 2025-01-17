
# Создание vApp для БД
resource "vcd_vapp" "vapp_InfraDev_PostgreSQL" {
  name    = "vapp-InfraDev-PostgreSQL"
  power_on = "true"

  depends_on = [module.network.Net]
}

# Создание сети в vApp для БД
resource "vcd_vapp_org_network" "PostgreSQL-routed-network" {
  vapp_name        = vcd_vapp.vapp_InfraDev_PostgreSQL.name
  org_network_name = module.network.Net.name
}

# Создание диска для PostgreSQL VM (объем переделать)
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
resource "vcd_vapp_vm" "vm_postgresql" {
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

#  Считываем основную Cloud-Init конфигурацию (cloud-config)

 locals {
  base_meta = file("${path.module}/devops/terraform/vm/Env_InfraDev/meta.yml")
}


  depends_on = [module.network.Net, vcd_vapp.vapp_InfraDev_PostgreSQL]

  network {
    type               = "org"
    name               = vcd_vapp_org_network.PostgreSQL-routed-network.org_network_name
    ip                 = var.postgresql-inf-d-01_ip
    ip_allocation_mode = "MANUAL"
  }

  customization {
    force                      = false
    enabled                    = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.admin_password

  }

  # Передача файла requirements.txt с требованиями по зависимостям (только python, так как python3-pip, ansible 
  # уже есть в файле meta)
  provisioner "file" {
    source      = "devops/???/requirements.txt"
    destination = "/tmp/requirements.txt"
#может тогда не использовать это  если нам дополнительно нужен только питон, можно и через скрипт 
#можно тогда просто в remote-exec provisioner дописать
    connection {
      type        = "ssh"
      host        = self.network[0].ip
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
    }
  }

  # Передача папки с ролями Ansible
  provisioner "file" {
    source      = "devops/infrastructure/roles/postgresql"
    destination = "/tmp/roles/postgresql"

    connection {
      type        = "ssh"
      host        = self.network[0].ip
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
    }
  }

  # Выполнение команд на целевой машине
  provisioner "local-exec" {
    inline = [
      "sudo apt-get update && sudo apt-get upgrade -y",
      
      # Установка зависимостей из requirements.txt
      "pip3 install -r /tmp/requirements.txt",

      # Запуск плейбука Ansible
      "ansible-playbook -i 'localhost,' -c local /tmp/roles/postgresql/tasks/main.yml"
    ]


    connection {
      type        = "ssh"
      host        = self.network[0].ip
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
    }
  }
}


# Переменные тут, чтобы не менять общий файл с vars
# Пока в сыром варианте можно просто тут их в тупую прописать даже не через Гитлаб env (секретов нет)

variable "vapp_name" {
  default = "vapp-InfraDev-PostgreSQL"
}

variable "postgresql_vm_name" {
  default = "postgresql-inf-d-01"
}

variable "postgresql_ip" {
  default = "10.5.2.10"
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

variable "admin_password" {
  default = "StrongPassword123" #сделать через гитлаб ENV
}
