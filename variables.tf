###############################################################################
# tf_mod_azuread_directory_role — variables
#
# Composite module. The keystone resource is azuread_directory_role (activates a
# built-in Entra ID directory role from its template). Child collections add
# permanent role assignments, legacy directory role members, and PIM role
# eligibility schedule requests, each driven by a for_each map keyed on a
# caller-supplied stable string.
#
# Variable order (composite): display_name -> parent identity refs ->
# per-collection config maps -> timeouts.
###############################################################################

variable "display_name" {
 description = <<EOT
Display name of the built-in directory role to activate (e.g. "Security Administrator",
"Cloud Application Administrator").

Built-in directory roles are immutable and pre-defined by Entra ID; this module does NOT
create a role — it activates an existing role template so assignments can be made against it.

Provide EITHER `display_name` OR `template_id` (template_id is the stabler choice — display
names can be localized / change). Changing this forces re-activation (new resource).
EOT
 type = string
 default = null
}

variable "template_id" {
 description = <<EOT
Object ID of the directory role template to activate (the well-known, tenant-independent
GUID for a built-in role — e.g. "194ae4cb-b126-40b2-bd5b-6091b380977d" for Security
Administrator).

Preferred over `display_name` because template IDs are stable and identical across every
tenant. Provide EITHER `template_id` OR `display_name`. Changing this forces a new resource.
EOT
 type = string
 default = null

 validation {
 condition = var.template_id != null || var.display_name != null
 error_message = "Either template_id or display_name must be set to identify the built-in directory role to activate."
 }
}

variable "role_assignments" {
 description = <<EOT
Permanent (standing) directory role assignments to create, keyed by a caller-supplied
stable string. Each assignment grants the principal the role IMMEDIATELY and indefinitely.

map(object({
 principal_object_id = string # object ID of the User, Group, or Service Principal to assign
 role_id = optional(string, null) # template ID (built-in) / object ID (custom) of the role.
 # Defaults to this module's activated role template_id.
 directory_scope_id = optional(string, null) # directory object scope, e.g. "/" (tenant-wide) or "/<admin-unit-object-id>".
 # Mutually exclusive with app_scope_id. Provider defaults to tenant-wide when null.
 app_scope_id = optional(string, null) # app-specific scope identifier. Mutually exclusive with directory_scope_id.
}))

Every field except principal_object_id is ForceNew at the provider. Renaming a map KEY
destroys and recreates that assignment — keys must be stable, meaningful identifiers
(e.g. "platform-team", "svc-pipeline"), never array indices.
EOT
 type = map(object({
 principal_object_id = string
 role_id = optional(string, null)
 directory_scope_id = optional(string, null)
 app_scope_id = optional(string, null)
 }))
 default = {}

 validation {
 condition = alltrue([
 for k, v in var.role_assignments:
 !(v.directory_scope_id != null && v.app_scope_id != null)
 ])
 error_message = "Each role_assignments entry may set at most one of directory_scope_id or app_scope_id — they are mutually exclusive."
 }
}

variable "role_members" {
 description = <<EOT
Legacy directory role memberships (azuread_directory_role_member), keyed by a
caller-supplied stable string.

map(object({
 member_object_id = string # object ID of the User, Group, or Service Principal to add
 role_object_id = optional(string, null) # object ID of the directory role. Defaults to this module's activated role object_id.
}))

> DEPRECATION: azuread_directory_role_member is superseded by
> azuread_directory_role_assignment. Prefer `role_assignments` for new work; this collection
> exists only for backwards compatibility with state created before the assignment resource.
> Both fields are ForceNew — renaming a map KEY destroys and recreates the membership.
EOT
 type = map(object({
 member_object_id = string
 role_object_id = optional(string, null)
 }))
 default = {}
}

variable "eligibility_schedule_requests" {
 description = <<EOT
PIM role eligibility schedule requests (azuread_directory_role_eligibility_schedule_request),
keyed by a caller-supplied stable string. These make a principal ELIGIBLE for just-in-time
activation of the role rather than granting standing access — the principal must still
activate the role (with MFA / justification / approval per the Entra role management policy)
before it takes effect.

map(object({
 principal_id = string # object ID of the User, Group, or Service Principal to make eligible
 justification = string # business justification recorded on the eligibility request (REQUIRED)
 role_definition_id = optional(string, null) # template ID (built-in) / object ID (custom). Defaults to this module's activated role template_id.
 directory_scope_id = optional(string, "/") # directory object scope; defaults to "/" (tenant-wide)
}))

> LICENSING: PIM (eligible assignments) requires Microsoft Entra ID P2 (or Entra ID
> Governance). Without a P2 license in the tenant the Graph request fails.
>
> PROVIDER LIMITATION: azuread v3.x exposes NO duration / expiration / schedule field on this
> resource — the request grants PERMANENT eligibility ("adminAssign"). The maximum activation
> duration, MFA, and approval requirements are governed by the role management policy in Entra
> (configured outside this module), not by a per-request duration here. All four fields are
> ForceNew; renaming a map KEY destroys and recreates the request.
EOT
 type = map(object({
 principal_id = string
 justification = string
 role_definition_id = optional(string, null)
 directory_scope_id = optional(string, "/")
 }))
 default = {}
}

variable "timeouts" {
 description = <<EOT
Optional Terraform operation timeouts applied to the directory role activation
(azuread_directory_role). The directory role resource supports create, read, and delete
only (no update — built-in roles are immutable and are never deactivated on destroy).

object({
 create = optional(string)
 read = optional(string)
 delete = optional(string)
})
EOT
 type = object({
 create = optional(string)
 read = optional(string)
 delete = optional(string)
 })
 default = {}
}
