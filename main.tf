###############################################################################
# tf_mod_azuread_directory_role — main
#
# Composite: one keystone resource (azuread_directory_role.this) activates a
# built-in Entra ID directory role from its template; three for_each child
# collections add standing assignments, legacy members, and PIM eligibility.
#
# main.tf is a thin, total renderer — no business logic. Every optional nested
# field is read with try()/coalesce() so an absent map key never errors.
###############################################################################

# Current tenant context (tenant_id, etc.) — surfaced as an output for callers.
data "azuread_client_config" "current" {}

# Read-only discovery of every activated role and every role template in the
# tenant. Exposed via outputs so callers can resolve template IDs / object IDs
# without hard-coding GUIDs. Requires RoleManagement.Read.Directory.
data "azuread_directory_roles" "all" {}

data "azuread_directory_role_templates" "all" {}

# -----------------------------------------------------------------------------
# Keystone — activate the built-in directory role from its template.
# Built-in roles are immutable and are NOT deactivated on destroy.
# -----------------------------------------------------------------------------
resource "azuread_directory_role" "this" {
 display_name = var.display_name
 template_id = var.template_id

 dynamic "timeouts" {
 for_each = length(keys(var.timeouts)) > 0 ? [var.timeouts]: []
 content {
 create = try(timeouts.value.create, null)
 read = try(timeouts.value.read, null)
 delete = try(timeouts.value.delete, null)
 }
 }
}

# -----------------------------------------------------------------------------
# Standing (permanent) role assignments — immediate, indefinite access.
# role_id defaults to the activated role's template_id when the caller omits it.
# -----------------------------------------------------------------------------
resource "azuread_directory_role_assignment" "assignments" {
 for_each = var.role_assignments

 role_id = coalesce(each.value.role_id, azuread_directory_role.this.template_id)
 principal_object_id = each.value.principal_object_id
 directory_scope_id = try(each.value.directory_scope_id, null)
 app_scope_id = try(each.value.app_scope_id, null)
}

# -----------------------------------------------------------------------------
# Legacy directory role members (deprecated — prefer assignments above).
# role_object_id defaults to the activated role's object_id when omitted.
# -----------------------------------------------------------------------------
resource "azuread_directory_role_member" "members" {
 for_each = var.role_members

 role_object_id = coalesce(each.value.role_object_id, azuread_directory_role.this.object_id)
 member_object_id = each.value.member_object_id
}

# -----------------------------------------------------------------------------
# PIM role eligibility schedule requests — just-in-time eligibility (P2).
# role_definition_id defaults to the activated role's template_id; the scope
# defaults to tenant-wide ("/"). No duration field exists on this resource.
# -----------------------------------------------------------------------------
resource "azuread_directory_role_eligibility_schedule_request" "eligibility" {
 for_each = var.eligibility_schedule_requests

 role_definition_id = coalesce(each.value.role_definition_id, azuread_directory_role.this.template_id)
 principal_id = each.value.principal_id
 directory_scope_id = coalesce(each.value.directory_scope_id, "/")
 justification = each.value.justification
}
