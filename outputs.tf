###############################################################################
# tf_mod_azuread_directory_role — outputs
#
# Primary output is `object_id` (the universal key for azuread resources).
# Child-collection outputs are keyed maps — wire a specific instance back by its
# caller-supplied key (empty map when the collection is unused).
#
# No output is sensitive: directory roles carry no credentials — only object IDs,
# template IDs, and principal IDs, none of which are secrets.
###############################################################################

output "object_id" {
 description = "Object ID of the activated directory role — the universal key consumed by role assignments, group membership, and access-package resource associations."
 value = azuread_directory_role.this.object_id
}

output "template_id" {
 description = "Template ID of the activated directory role (the tenant-independent built-in role GUID). Use this as role_id / role_definition_id when assigning the role."
 value = azuread_directory_role.this.template_id
}

output "display_name" {
 description = "Display name of the activated directory role."
 value = azuread_directory_role.this.display_name
}

output "description" {
 description = "Description of the activated directory role, as reported by Entra ID."
 value = azuread_directory_role.this.description
}

output "tenant_id" {
 description = "Tenant ID resolved from the current provider credentials."
 value = data.azuread_client_config.current.tenant_id
}

# --- Standing assignments --------------------------------------------------

output "role_assignment_ids" {
 description = "Map of role_assignments key => role assignment resource ID. Empty when no standing assignments are defined."
 value = { for k, a in azuread_directory_role_assignment.assignments: k => a.id }
}

output "role_assignment_principal_ids" {
 description = "Map of role_assignments key => principal object ID granted the role."
 value = { for k, a in azuread_directory_role_assignment.assignments: k => a.principal_object_id }
}

# --- Legacy members --------------------------------------------------------

output "role_member_ids" {
 description = "Map of role_members key => directory role member resource ID. Empty when no legacy members are defined."
 value = { for k, m in azuread_directory_role_member.members: k => m.id }
}

# --- PIM eligibility -------------------------------------------------------

output "eligibility_schedule_request_ids" {
 description = "Map of eligibility_schedule_requests key => eligibility schedule request resource ID. Empty when no PIM eligibility is defined."
 value = { for k, e in azuread_directory_role_eligibility_schedule_request.eligibility: k => e.id }
}

output "eligible_principal_ids" {
 description = "Map of eligibility_schedule_requests key => principal object ID made eligible for just-in-time activation."
 value = { for k, e in azuread_directory_role_eligibility_schedule_request.eligibility: k => e.principal_id }
}

# --- Tenant discovery (from read-only data sources) ------------------------

output "directory_roles" {
 description = "Map of display_name => object_id for every directory role currently activated in the tenant. Useful for resolving the object ID of a role activated elsewhere."
 value = { for r in data.azuread_directory_roles.all.roles: r.display_name => r.object_id }
}

output "directory_role_templates" {
 description = "Map of display_name => template object_id for every built-in directory role template in the tenant. Useful for resolving the template_id to activate without hard-coding GUIDs."
 value = { for t in data.azuread_directory_role_templates.all.role_templates: t.display_name => t.object_id }
}
