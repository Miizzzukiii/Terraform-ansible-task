# Создание vApp
resource "vcd_vapp" "vapp_InfraDev_test" {
  name = "vapp-InfraDev-test"
  power_on = "true"

  depends_on = [module.network.Net]
}

# Создание сети в vApp
resource "vcd_vapp_org_network" "test-routed-network" {
  vapp_name         = vcd_vapp.vapp_InfraDev_test.name
  org_network_name  = module.network.Net.name
}

