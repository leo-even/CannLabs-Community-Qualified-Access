# frozen_string_literal: true

# name: cannlabs-community-qualified-access
# about: Reconciles CannLabs Community derived restricted-access groups from authoritative native memberships.
# version: 0.1.0
# authors: CannLabs Community
# url: https://github.com/leo-even/CannLabs-Community-Qualified-Access

enabled_site_setting :cannlabs_qualified_access_enabled

module ::CannLabsQualifiedAccess
  PLUGIN_NAME = "cannlabs-community-qualified-access"

  ACTIVE_GROUP = "membros_ativos"
  PROFESSIONAL_IDENTITY_GROUPS = %w[
    medicos_verif
    farmaceuticos_verif
    agronomos_verif
    advogados_verif
  ].freeze
  LEADERSHIP_SOURCE_GROUP = "liderancas_aprov"
  DERIVED_PROFESSIONAL_GROUP = "acesso_profissionais"
  DERIVED_LEADERSHIP_GROUP = "acesso_liderancas"

  SOURCE_GROUPS = ([ACTIVE_GROUP] + PROFESSIONAL_IDENTITY_GROUPS + [LEADERSHIP_SOURCE_GROUP]).freeze
  DERIVED_GROUPS = [DERIVED_PROFESSIONAL_GROUP, DERIVED_LEADERSHIP_GROUP].freeze
  ALL_GROUPS = (SOURCE_GROUPS + DERIVED_GROUPS).freeze
  RECONCILIATION_JOB = "cannlabs_qualified_access_reconcile_user"
end

require_relative "lib/cannlabs_qualified_access/engine"
require_relative "lib/cannlabs_qualified_access/reconciliation_service"

after_initialize do
  on(:user_added_to_group) do |user, group, **|
    next unless SiteSetting.cannlabs_qualified_access_enabled
    next unless CannLabsQualifiedAccess::SOURCE_GROUPS.include?(group.name)

    Jobs.enqueue(CannLabsQualifiedAccess::RECONCILIATION_JOB, user_id: user.id)
  end

  on(:user_removed_from_group) do |user, group|
    next unless SiteSetting.cannlabs_qualified_access_enabled
    next unless CannLabsQualifiedAccess::SOURCE_GROUPS.include?(group.name)

    Jobs.enqueue(CannLabsQualifiedAccess::RECONCILIATION_JOB, user_id: user.id)
  end
end
