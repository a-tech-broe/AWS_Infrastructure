module "state_backend" {
  source = "../modules/backend-state"

  bucket_name = var.bucket_name
  table_name  = var.table_name
}
