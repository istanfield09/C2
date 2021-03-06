describe Step do
  describe "Associations" do
    it { should belong_to(:user) }
    it { should belong_to(:proposal) }
  end

  describe "Validations" do
    it { should validate_presence_of(:proposal) }
    it do
      create(:approval) # needed for spec, see https://github.com/thoughtbot/shoulda-matchers/issues/194
      should validate_uniqueness_of(:user_id).scoped_to(:proposal_id)
    end
  end

  let(:approval) { create(:approval) }

  describe '#api_token' do
    let!(:token) { create(:api_token, step: approval) }

    it "returns the token" do
      expect(approval.api_token).to eq(token)
    end

    it "returns nil if the token's been used" do
      token.update_attribute(:used_at, 1.day.ago)
      approval.reload
      expect(approval.api_token).to eq(nil)
    end

    it "returns nil if the token's expired" do
      token.expire!
      approval.reload
      expect(approval.api_token).to eq(nil)
    end
  end

  describe '#completed_at' do
    it 'is nil when pending' do
      expect(approval.completed_at).to be_nil
    end

    it 'is nil when actionable' do
      approval.initialize!
      expect(approval.completed_at).to be_nil
    end

    it 'is set when approved' do
      approval.initialize!
      approval.complete!
      expect(approval.completed_at).not_to be_nil
      approval.reload
      expect(approval.completed_at).not_to be_nil
    end
  end

  describe '#on_approved_entry' do
    it "notified the proposal if the root gets approved" do
      expect(approval.proposal).to receive(:complete!).once
      approval.initialize!
      approval.complete!
    end

    it "does not notify the proposal if a child gets approved" do
      proposal = create(:proposal)
      child1 = build(:approval, user: create(:user))
      child2 = build(:approval, user: create(:user))
      proposal.root_step = build(:parallel_step, child_steps: [child1, child2])

      expect(proposal).not_to receive(:complete!)
      child1.complete!
    end
  end

  describe "database constraints" do
    it "deletes steps when parent proposal is destroyed" do
      proposal = create(:proposal)
      step = create(:step, proposal: proposal)

      expect(Step.exists?(step.id)).to eq true
      expect(Proposal.exists?(proposal.id)).to eq true

      proposal.destroy

      expect(Step.exists?(step.id)).to eq false
      expect(Proposal.exists?(proposal.id)).to eq false
    end
  end

  describe "complicated approval chains" do
    # Approval hierarchy version of needing *two* of the following:
    # 1) Amy AND Bob
    # 2) Carrie
    # 3) Dan THEN Erin
    let!(:amy) { create(:user) }
    let!(:bob) { create(:user) }
    let!(:carrie) { create(:user) }
    let!(:dan) { create(:user) }
    let!(:erin) { create(:user) }
    let!(:proposal) { create(:proposal) }

    before :each do
      # @todo syntax for this will get cleaned up
      and_clause = create(:parallel_step, child_steps: [
        create(:approval, user: amy),
        create(:approval, user: bob)
      ])
      then_clause = create(:serial_step, child_steps: [
        create(:approval, user: dan),
        create(:approval, user: erin)
      ])
      proposal.root_step = create(:parallel_step, min_children_needed: 2, child_steps: [
        and_clause,
        create(:approval, user: carrie),
        then_clause
      ])
    end

    it "won't approve Amy and Bob -- needs two branches of the OR" do
      build_approvals
      expect_any_instance_of(Proposal).not_to receive(:complete!)
      proposal.existing_or_delegated_step_for(amy).complete!
      proposal.existing_or_delegated_step_for(bob).complete!
    end

    it "will approve if Amy, Bob, and Carrie approve -- two branches of the OR" do
      build_approvals
      expect_any_instance_of(Proposal).to receive(:complete!)
      proposal.existing_or_delegated_step_for(amy).complete!
      proposal.existing_or_delegated_step_for(bob).complete!
      proposal.existing_or_delegated_step_for(carrie).complete!
    end

    it "won't approve Amy, Bob, Dan as Erin is also required (to complete the THEN)" do
      build_approvals
      expect_any_instance_of(Proposal).not_to receive(:complete!)
      proposal.existing_or_delegated_step_for(amy).complete!
      proposal.existing_or_delegated_step_for(bob).complete!
      proposal.existing_or_delegated_step_for(dan).complete!
    end

    it "will approve Amy, Bob, Dan, Erin -- two branches of the OR" do
      build_approvals
      expect_any_instance_of(Proposal).to receive(:complete!)
      proposal.existing_or_delegated_step_for(amy).complete!
      proposal.existing_or_delegated_step_for(bob).complete!
      proposal.existing_or_delegated_step_for(dan).complete!
      proposal.existing_or_delegated_step_for(erin).complete!
    end

    it "will approve Amy, Bob, Dan, Carrie -- two branches of the OR as Dan is irrelevant" do
      build_approvals
      expect_any_instance_of(Proposal).to receive(:complete!)
      proposal.existing_or_delegated_step_for(amy).complete!
      proposal.existing_or_delegated_step_for(bob).complete!
      proposal.existing_or_delegated_step_for(dan).complete!
      proposal.existing_or_delegated_step_for(carrie).complete!
    end

    def build_approvals
      and_clause = build(
        :parallel_step,
        child_steps: [
          build(:approval, user: amy),
          build(:approval, user: bob)
        ]
      )
      then_clause = build(
        :parallel_step,
        child_steps: [
          build(:approval, user: dan),
          build(:approval, user: erin)
        ]
      )
      proposal.root_step = build(
        :parallel_step,
        min_children_needed: 2,
        child_steps: [
          and_clause,
          build(:approval, user: carrie),
          then_clause
        ]
      )
    end
  end
end
