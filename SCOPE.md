# SCOPE — terraform-azuread-directory-role

## Design intent
Manages Azure AD directory role activation and assignments. Built-in roles are activated via template_id.

## In scope
- `azuread_directory_role`
- `azuread_directory_role_assignment`
- `azuread_directory_role_member`
- `azuread_directory_role_eligibility_schedule_request`

### Data sources
- `data.azuread_directory_roles` (read-only)
- `data.azuread_directory_role_templates` (read-only)
- `data.azuread_client_config` (read-only)

## Out of scope / consumed by ID
- `azuread_user` / `azuread_group` / `azuread_service_principal` — consumed via
  `role_assignments[*].principal_object_id`, `role_members[*].member_object_id`,
  and `eligibility_schedule_requests[*].principal_id` (the principal being granted
  standing access, legacy membership, or PIM eligibility)
- `azuread_custom_directory_role` — consumed via `*.role_id` / `*.role_definition_id`
  (optional; a custom role's `object_id` overrides the default of this module's own
  activated `template_id`)
- `azuread_administrative_unit` — consumed via `*.directory_scope_id` (optional;
  formatted `/<object_id>` to scope an assignment or eligibility request to an AU
  instead of tenant-wide `"/"`)

## Consumes
| Input | Type | Source module |
|---|---|---|
| `principal_object_id` | string (per assignment) | `terraform-azuread-user.object_id, terraform-azuread-service-principal.object_id, or terraform-azuread-group.object_id` |
| `*.role_id` / `*.role_definition_id` (optional) | string | `terraform-azuread-custom-directory-role.object_id` (defaults to this role's `template_id`) |
| `*.directory_scope_id` (optional) | string | `terraform-azuread-administrative-unit.object_id` (formatted `/<id>`), or `"/"` for tenant-wide |

## Graph API permissions required
The Terraform service principal requires (application permissions, both **require admin consent**):
- `RoleManagement.Read.Directory` — least-privileged read of activated roles / role templates (the two data sources)
- `RoleManagement.ReadWrite.Directory` — activate the role, create assignments, members, and PIM eligibility requests.
  Graph identifier `9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8` ("Read and write all directory RBAC settings").

> ⚠️ `RoleManagement.ReadWrite.Directory` is **self-elevating** — per Microsoft, an app holding it "can grant
> additional privileges to itself, other applications, or any user." Treat the Terraform SP as a tier-0 identity.
>
> The eligibility schedule request additionally accepts `RoleEligibilitySchedule.ReadWrite.Directory`,
> but `RoleManagement.ReadWrite.Directory` is a superset and is sufficient for all four resources.
> When authenticated as a *user* principal, the caller must hold the **Privileged Role Administrator**
> or **Global Administrator** directory role.

## Emits
| Output | Description | Typically consumed by |
|---|---|---|
| `object_id` | Object ID of `azuread_directory_role` in Azure AD | Role assignments, group membership, access package resource associations |
| `template_id` | Template ID (tenant-independent built-in role GUID) | `role_id` / `role_definition_id` on downstream assignments |
| `role_assignment_*` (keyed maps) | Per-assignment IDs and principal object IDs | Audit, downstream wiring |
| `eligibility_schedule_request_ids`, `eligible_principal_ids` (keyed maps) | Per-eligibility-request IDs and eligible principals | PIM audit, governance reporting |
| `directory_roles`, `directory_role_templates` (maps) | `display_name => object_id` / `template_id` for the whole tenant | Resolving role IDs without hard-coding GUIDs |

## Provider gotchas
- Built-in directory roles cannot be created — `template_id` (or `display_name`) activates the existing role.
- `azuread_directory_role` performs **no action on destroy** — once activated, a role cannot be deactivated.
- All identity/scope fields on the three child resources are **ForceNew** — changing them recreates the child.
- Role assignments are immediate — there is no staging or preview mechanism.
- PIM eligibility uses `azuread_directory_role_eligibility_schedule_request`, not assignment.
- **PIM eligibility has NO duration/expiration/schedule field** in azuread v3.x (validated against v3.9.0):
  the request grants *permanent* eligibility ("adminAssign"). Activation duration, MFA, and approval are
  governed by the Entra **role management policy** (configured outside this module), not by a per-request
  duration. The design-context request to "model PIM schedule duration as optional(string)" was therefore
  intentionally **omitted** — no backing attribute exists and adding it would fail `terraform validate`.
- PIM eligibility requires **Microsoft Entra ID P2** (or Entra ID Governance) licensing in the tenant.
- Global Administrator assignment via Terraform is audited — treat with extra caution.
- `directory_role_member` (legacy) emits a deprecation warning (superseded by `directory_role_assignment`)
  but still functions in v3.9.0 under the `< 4.0` pin — retained only for backward compatibility.

## Design decisions
- **Composite boundary:** one keystone (`azuread_directory_role.this`) activates the role; the three child
  resource families are grouped behind it because every assignment/member/eligibility for a given role is
  meaningless without the activated role, and all naturally key off the role's `template_id`/`object_id`.
- **for_each keys:** every child collection is `map(object(...))` keyed by a caller-supplied stable string
  (e.g. `"platform-team"`, `"svc-pipeline"`). No `count`. Renaming a key destroys/recreates that child only.
- **Ergonomic defaults:** `role_id` / `role_definition_id` default to `this.template_id` and `role_object_id`
  defaults to `this.object_id`, so the common "assign THIS role" case needs no GUID. `directory_scope_id`
  defaults to `"/"` (tenant-wide) for eligibility.
- **Replication ordering:** `this` must exist before any child (implicit dependency via the defaulted IDs).
  Graph API is eventually consistent — allow brief propagation after role activation before assignments land.
- **No `sensitive` outputs:** directory roles carry no credentials — only object/template/principal IDs.
- **Data sources** (`directory_roles`, `directory_role_templates`, `client_config`) are surfaced as outputs
  so callers can resolve role/template object IDs and the tenant ID without hard-coding GUIDs.
