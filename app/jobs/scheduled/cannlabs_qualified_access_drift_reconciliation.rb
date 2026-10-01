# frozen_string_literal: true

module Jobs
  class CannlabsQualifiedAccessDriftReconciliation < ::Jobs::Scheduled
    every 15.minutes

    def execute(_args)
      return unless SiteSetting.cannlabs_qualified_access_enabled

      groups = Group.where(name: CannLabsQualifiedAccess::ALL_GROUPS)
      user_ids = GroupUser.where(group_id: groups.select(:id)).distinct.pluck(:user_id)
      user_ids.each do |user_id|
        Jobs.enqueue(CannLabsQualifiedAccess::RECONCILIATION_JOB, user_id: user_id)
      end

      Rails.logger.info(
        "[cannlabs-qualified-access] drift reconciliation enqueued #{user_ids.length} users",
      )
    end
  end
end
