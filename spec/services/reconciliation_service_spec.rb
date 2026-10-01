# frozen_string_literal: true

require "rails_helper"

RSpec.describe CannLabsQualifiedAccess::ReconciliationService do
  fab!(:user) { Fabricate(:user) }

  let(:group_names) do
    CannLabsQualifiedAccess::ALL_GROUPS + ["unrelated_group"]
  end
  let!(:groups) do
    group_names.index_with { |name| Fabricate(:group, name: name) }
  end

  before { SiteSetting.cannlabs_qualified_access_enabled = true }

  def add(*names)
    names.each { |name| groups.fetch(name).add(user) }
  end

  def remove(*names)
    names.each { |name| groups.fetch(name).remove(user) }
  end

  def member?(name)
    GroupUser.exists?(group: groups.fetch(name), user: user)
  end

  def reconcile
    described_class.call(user.id)
  end

  describe "professional access" do
    it "does not grant access to an inactive user without identity" do
      reconcile
      expect(member?("acesso_profissionais")).to eq(false)
    end

    it "does not grant access to an active user without identity" do
      add "membros_ativos"
      reconcile
      expect(member?("acesso_profissionais")).to eq(false)
    end

    it "does not grant access to an inactive user with identity" do
      add "medicos_verif"
      reconcile
      expect(member?("acesso_profissionais")).to eq(false)
    end

    it "grants access to an active physician" do
      add "membros_ativos", "medicos_verif"
      reconcile
      expect(member?("acesso_profissionais")).to eq(true)
    end

    it "grants access to an active pharmacist" do
      add "membros_ativos", "farmaceuticos_verif"
      reconcile
      expect(member?("acesso_profissionais")).to eq(true)
    end

    it "keeps one derived membership for two identities" do
      add "membros_ativos", "medicos_verif", "farmaceuticos_verif"
      reconcile
      expect(groups.fetch("acesso_profissionais").users.where(id: user.id).count).to eq(1)
    end

    it "retains access when one of two identities is removed" do
      add "membros_ativos", "medicos_verif", "farmaceuticos_verif"
      reconcile
      remove "medicos_verif"
      reconcile
      expect(member?("acesso_profissionais")).to eq(true)
    end

    it "removes access when the last identity is removed" do
      add "membros_ativos", "medicos_verif"
      reconcile
      remove "medicos_verif"
      reconcile
      expect(member?("acesso_profissionais")).to eq(false)
    end

    it "removes access when active membership is removed" do
      add "membros_ativos", "medicos_verif"
      reconcile
      remove "membros_ativos"
      reconcile
      expect(member?("acesso_profissionais")).to eq(false)
    end

    it "restores access when membership is reactivated and identity remains" do
      add "membros_ativos", "medicos_verif"
      reconcile
      remove "membros_ativos"
      reconcile
      add "membros_ativos"
      reconcile
      expect(member?("acesso_profissionais")).to eq(true)
    end
  end

  describe "leadership access" do
    it "requires active membership and leadership approval" do
      add "liderancas_aprov"
      reconcile
      expect(member?("acesso_liderancas")).to eq(false)

      add "membros_ativos"
      reconcile
      expect(member?("acesso_liderancas")).to eq(true)
    end

    it "removes and restores leadership access around membership expiry" do
      add "membros_ativos", "liderancas_aprov"
      reconcile
      remove "membros_ativos"
      reconcile
      expect(member?("acesso_liderancas")).to eq(false)

      add "membros_ativos"
      reconcile
      expect(member?("acesso_liderancas")).to eq(true)
    end

    it "removes leadership access when approval is revoked" do
      add "membros_ativos", "liderancas_aprov"
      reconcile
      remove "liderancas_aprov"
      reconcile
      expect(member?("acesso_liderancas")).to eq(false)
    end
  end

  describe "drift and safety" do
    it "removes invalid manual professional access" do
      add "acesso_profissionais"
      reconcile
      expect(member?("acesso_profissionais")).to eq(false)
    end

    it "restores valid professional access removed manually" do
      add "membros_ativos", "medicos_verif"
      reconcile
      remove "acesso_profissionais"
      reconcile
      expect(member?("acesso_profissionais")).to eq(true)
    end

    it "repairs invalid manual leadership access" do
      add "acesso_liderancas"
      reconcile
      expect(member?("acesso_liderancas")).to eq(false)
    end

    it "does not mutate for an unrelated group" do
      add "membros_ativos", "medicos_verif"
      reconcile
      before = GroupUser.where(user: user).pluck(:group_id)
      add "unrelated_group"
      reconcile
      expect(GroupUser.where(user: user).pluck(:group_id)).to contain_exactly(*before, groups.fetch("unrelated_group").id)
    end

    it "is idempotent" do
      add "membros_ativos", "medicos_verif"
      reconcile
      expect { reconcile }.not_to change { GroupUser.where(user: user).count }
    end

    it "fails closed when the active source group is missing" do
      add "medicos_verif", "acesso_profissionais"
      groups.fetch("membros_ativos").destroy!
      reconcile
      expect(member?("acesso_profissionais")).to eq(false)
    end

    it "treats a missing profession source as empty" do
      add "membros_ativos", "medicos_verif", "acesso_profissionais"
      groups.fetch("medicos_verif").destroy!
      reconcile
      expect(member?("acesso_profissionais")).to eq(false)
    end

    it "fails leadership closed when the leadership source is missing" do
      add "membros_ativos", "acesso_liderancas"
      groups.fetch("liderancas_aprov").destroy!
      reconcile
      expect(member?("acesso_liderancas")).to eq(false)
    end

    it "does not mutate while the feature is disabled through the regular job" do
      add "membros_ativos", "medicos_verif"
      SiteSetting.cannlabs_qualified_access_enabled = false
      expect { Jobs::CannlabsQualifiedAccessReconcileUser.new.execute(user_id: user.id) }.
        not_to change { GroupUser.where(user: user).count }
    end
  end
end
