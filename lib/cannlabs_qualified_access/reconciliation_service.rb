# frozen_string_literal: true

module CannLabsQualifiedAccess
  class ReconciliationService
    def self.call(user_id)
      new(user_id).call
    end

    def initialize(user_id)
      @user_id = user_id
      @groups = Group.where(name: ALL_GROUPS).index_by(&:name)
    end

    def call
      user = User.find_by(id: @user_id)
      return { status: :missing_user } unless user

      reconcile_professional(user)
      reconcile_leadership(user)
    end

    private

    def reconcile_professional(user)
      active = source_member?(user, ACTIVE_GROUP)
      identity = PROFESSIONAL_IDENTITY_GROUPS.any? { |name| source_member?(user, name) }
      reconcile_derived(user, DERIVED_PROFESSIONAL_GROUP, active && identity)
    end

    def reconcile_leadership(user)
      active = source_member?(user, ACTIVE_GROUP)
      approved = source_member?(user, LEADERSHIP_SOURCE_GROUP)
      reconcile_derived(user, DERIVED_LEADERSHIP_GROUP, active && approved)
    end

    def source_member?(user, name)
      group = @groups[name]
      unless group
        Rails.logger.error("[cannlabs-qualified-access] missing source group: #{name}")
        return false
      end

      GroupUser.exists?(group_id: group.id, user_id: user.id)
    end

    def reconcile_derived(user, name, desired)
      group = @groups[name]
      unless group
        Rails.logger.error("[cannlabs-qualified-access] missing derived group: #{name}")
        return :missing_derived_group
      end

      current = GroupUser.exists?(group_id: group.id, user_id: user.id)
      return :noop if desired == current

      if desired
        group.add(user)
        GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(user)
        :added
      else
        group.remove(user)
        GroupActionLogger.new(Discourse.system_user, group).log_remove_user_from_group(user)
        :removed
      end
    rescue StandardError => e
      Rails.logger.error(
        "[cannlabs-qualified-access] reconciliation mutation failed for user=#{user.id} " \
          "group=#{name}: #{e.class}: #{e.message}",
      )
      :mutation_failed
    end
  end
end
