# frozen_string_literal: true

module Jobs
  class CannlabsQualifiedAccessReconcileUser < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.cannlabs_qualified_access_enabled

      CannLabsQualifiedAccess::ReconciliationService.call(args[:user_id])
    end
  end
end
