
moved {
  from = module.azure.module.aks_compute_cluster.azurerm_user_assigned_identity.aks[0]
  to   = module.azure.module.aks_umi_spendproof.azurerm_user_assigned_identity.this
}
