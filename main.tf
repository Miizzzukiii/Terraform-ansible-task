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
  template_name = var.template_vm #?
  memory        = 2048
  cpus          = 2
  cpu_cores     = 1

  depends_on = [module.network.Net, vcd_vapp.vapp_InfraDev_postgresql]

  network {
    type               = "org"
    name               = var.network_name
    ip                 = var.postgresql_ip
    ip_allocation_mode = "MANUAL"
  }

  customization {
    enabled                    = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.admin_password
  }

}


