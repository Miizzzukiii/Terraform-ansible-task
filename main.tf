# Создание vApp для БД
resource "vcd_vapp" "vapp_InfraDev_PostgreSQL" {
  name = "vapp-InfraDev-PostgreSQL"
  power_on = "true"

  depends_on = [module.network.Net]
}

# Создание сети в vApp для БД
resource "vcd_vapp_org_network" "PostgreSQL-routed-network" {
  vapp_name         = vcd_vapp.vapp_InfraDev_postgresql.name
  org_network_name  = module.network.Net.name
}

# Создание диска для PostgreSQL VM (объем переделать)
resource "vcd_vm_internal_disk" "postgresql-inf-d-01-disk1" {
  vapp_name     = vcd_vapp.vapp_InfraDev_postgresql.name
  vm_name       = vcd_vapp_vm.postgresql-inf-d-01.name
  size_in_mb    = "20480"  
  bus_type      = "parallel"
  storage_profile = var.storage_profile
  bus_number    = 1
  unit_number   = 1
  depends_on = [vcd_vapp_vm.postgresql-inf-d-01]
}

# Создание VM для PostgreSQL
resource "vcd_vapp_vm" "vm_postgresql" {
  vapp_name     = vcd_vapp.vapp_InfraDev_postgresql.name
  name          = "postgresql-inf-d-01"
  computer_name = "postgresql-inf-d-01"
  catalog_name  = var.vcd_org_catalog
  template_name = var.template_vm 
  memory        = 2048
  cpus          = 2
  cpu_cores     = 1

  depends_on = [module.network.Net, vcd_vapp.vapp_InfraDev_postgresql]

  network {
    type               = "org"
    name               = vcd_vapp_org_network.postgresql_inf_d-routed-network.org_network_name
    ip                 = var.postgresql-inf-d-01_ip
    ip_allocation_mode = "MANUAL"
  }

  customization {
    force                      = false
    enabled                    = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.admin_password


    customization_script = <<EOT
#!/bin/bash
set -e

# Обновление системы
sudo apt-get update && sudo apt-get upgrade -y

# Установка необходимых зависимостей
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common git

# Установка Docker - тут тогда как? учитывая ИБ ПЕРЕДЕЛАТЬ ТУТ ВСЕ
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Добавление пользователя GitLab Runner в группу Docker
sudo usermod -aG docker gitlab-runner

# Установка GitLab Runner
curl -s https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install -y gitlab-runner

# Регистрация GitLab Runner с Docker executor
sudo gitlab-runner register --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "${var.gitlab_runner_token}" \
  --executor "docker" \
  --docker-image "docker:latest" \
  --description "PostgreSQL-VM-Runner" \
  --tag-list "postgresql,ci-cd" \
  --locked="false"

# Перезапуск сервиса GitLab Runner
sudo systemctl restart gitlab-runner
EOT

  }
}
 

# Почему гитлаб не через Provisioner? Для избежания неудачных запусков ВМ:
# Provisioner запускается только после успешного создания ресурса. Если настройка ВМ по какой-то причине завершится с ошибкой, Terraform может некорректно обработать завершение или повторный запуск.
# Совместимость:
# customization_script лучше интегрируется в экосистему VCD, что делает конфигурацию более чистой и согласованной с API провайдера.


