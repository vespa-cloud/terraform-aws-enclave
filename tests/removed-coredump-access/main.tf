# This negative fixture must fail during init from a clean candidate tree.
# Version 2 deliberately provides no compatibility module at the old path.

module "removed_coredump_access" {
  source = "../../modules/coredump-access"
}
