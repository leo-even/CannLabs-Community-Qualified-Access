# CannLabs Community Qualified Access

Bounded Discourse plugin for reconciling CannLabs Community derived restricted-access groups from authoritative native group memberships.

## Source and derived groups

Source state:

- `membros_ativos`
- `medicos_verif`
- `farmaceuticos_verif`
- `agronomos_verif`
- `advogados_verif`
- `liderancas_aprov`

Derived state:

- `acesso_profissionais`
- `acesso_liderancas`

Professional access requires active membership plus at least one professional identity. Leadership access requires active membership plus `liderancas_aprov`.

## Behavior

- Feature flag: `cannlabs_qualified_access_enabled` (default `false`).
- Source group add/remove events enqueue idempotent per-user reconciliation.
- A 15-minute scheduled drift sweep reconciles users found in source or derived groups.
- Missing source groups fail closed for the affected predicate and log an operator-visible error.
- Missing derived groups are never created automatically.
- Native `Group.add` / `Group.remove` and `GroupActionLogger` provide membership history.
- No database tables, migrations, custom ACLs, UI, or frontend assets are used.

## Local development

Keep this repository as a sibling checkout of the Community application. Mount it into the Community container at `/src/plugins/cannlabs-community-qualified-access`; do not copy it into the application Git history.

Run plugin specs from the Discourse application checkout with the plugin mounted:

```bash
bundle exec rspec plugins/cannlabs-community-qualified-access/spec
```

This plugin is local-development validation only. It does not implement verification, association onboarding, billing, payment, moderation, authentication, notifications, or production deployment.
