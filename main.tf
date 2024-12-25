# Создание vApp для БД
resource "vcd_vapp" "vapp_InfraDev_PostgreSQL" {
  name = "vapp-InfraDev-PostgreSQL"
  power_on = "true"

  depends_on = [module.network.Net]
}

# Создание сети в vApp для БД
resource "vcd_vapp_org_network" "PostgreSQL-routed-network" {
  vapp_name         = vcd_vapp.vapp_InfraDev_PostgreSQL.name
  org_network_name  = module.network.Net.name
}

# Создание диска для PostgreSQL VM (объем переделать)
resource "vcd_vm_internal_disk" "postgresql-inf-d-01-disk1" {
  vapp_name     = vcd_vapp.vapp_InfraDev_postgresql.name
  vm_name       = vcd_vapp_vm.postgresql-inf-d-01-disk1.name
  size_in_mb    = "20480"  
  bus_type      = "parallel"
  storage_profile = var.storage_profile
  bus_number    = 1
  unit_number   = 1
}
