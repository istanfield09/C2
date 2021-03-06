describe StepManager do
  describe "#add_initial_step" do
    it "creates a new step series with the steps" do
      proposal = create(:proposal)
      expect(proposal.steps).to be_empty
      new_step1 = create(:approval)
      new_step2 = create(:approval)
      proposal.add_initial_steps([new_step1, new_step2])

      aggregate_failures "testing steps" do
        expect(proposal.steps.first).to be_a Steps::Serial
        expect(proposal.steps.first).to be_actionable
        expect(proposal.steps.first.child_steps).to include(new_step1, new_step2)
        expect(proposal.steps.last).to eq new_step2
        expect(new_step1).to be_actionable
      end
    end
  end

  describe '#root_step=' do
    it 'sets initial approvers' do
      proposal = create(:proposal)
      approvers = 3.times.map{ create(:user) }
      individuals = approvers.map{ |u| Steps::Approval.new(user: u) }

      proposal.root_step = Steps::Parallel.new(child_steps: individuals)

      expect(proposal.steps.count).to be 4
      expect(proposal.approvers).to eq approvers
    end

    it 'initates parallel' do
      approver1 = create(:user)
      approver2 = create(:user)
      approver3 = create(:user)
      proposal = create(:proposal)
      individuals = [approver1, approver2, approver3].map{ |u| Steps::Approval.new(user: u)}

      proposal.root_step = Steps::Parallel.new(child_steps: individuals)

      expect(proposal.approvers.count).to be 3
      expect(proposal.steps.count).to be 4
      expect(proposal.individual_steps.actionable.count).to be 3
      expect(proposal.steps.actionable.count).to be 4
    end

    it 'initates linear' do
      approver1 = create(:user)
      approver2 = create(:user)
      approver3 = create(:user)
      proposal = create(:proposal)
      individuals = [approver1, approver2, approver3].map{ |u| Steps::Approval.new(user: u)}

      proposal.root_step = Steps::Serial.new(child_steps: individuals)

      expect(proposal.approvers.count).to be 3
      expect(proposal.steps.count).to be 4
      expect(proposal.individual_steps.actionable.count).to be 1
      expect(proposal.steps.actionable.count).to be 2
    end

    it 'fixes modified parallel proposal approvals' do
      approver1 = create(:user)
      approver2 = create(:user)
      approver3 = create(:user)
      proposal = create(:proposal)
      individuals = [Steps::Approval.new(user: approver1)]
      proposal.root_step = Steps::Parallel.new(child_steps: individuals)

      expect(proposal.steps.actionable.count).to be 2
      expect(proposal.individual_steps.actionable.count).to be 1

      individuals = individuals + [approver2, approver3].map{ |u| Steps::Approval.new(user: u)}
      proposal.root_step = Steps::Parallel.new(child_steps: individuals)

      expect(proposal.steps.actionable.count).to be 4
      expect(proposal.individual_steps.actionable.count).to be 3
    end

    it 'fixes modified linear proposal steps' do
      approver1 = create(:user)
      approver2 = create(:user)
      approver3 = create(:user)
      proposal = create(:proposal)
      approver1, approver2, approver3 = 3.times.map{ create(:user) }
      individuals = [approver1, approver2].map{ |u| Steps::Approval.new(user: u) }
      proposal.root_step = Steps::Serial.new(child_steps: individuals)

      expect(proposal.steps.actionable.count).to be 2
      expect(proposal.individual_steps.actionable.count).to be 1

      individuals.first.complete!
      individuals[1] = Steps::Approval.new(user: approver3)
      proposal.root_step = Steps::Serial.new(child_steps: individuals)

      expect(proposal.steps.completed.count).to be 1
      expect(proposal.steps.actionable.count).to be 2
      expect(proposal.individual_steps.actionable.count).to be 1
      expect(proposal.individual_steps.actionable.first.user).to eq approver3
    end

    it 'does not modify a full completed parallel proposal' do
      approver1 = create(:user)
      approver2 = create(:user)
      proposal = create(:proposal)
      individuals = [approver1, approver2].map{ |u| Steps::Approval.new(user: u)}
      proposal.root_step = Steps::Parallel.new(child_steps: individuals)

      proposal.individual_steps.first.complete!
      proposal.individual_steps.second.complete!

      expect(proposal.steps.actionable).to be_empty
    end

    it 'does not modify a full completed linear proposal' do
      approver1 = create(:user)
      approver2 = create(:user)
      proposal = create(:proposal)
      individuals = [approver1, approver2].map{ |u| Steps::Approval.new(user: u)}
      proposal.root_step = Steps::Serial.new(child_steps: individuals)

      proposal.individual_steps.first.complete!
      proposal.individual_steps.second.complete!

      expect(proposal.steps.actionable).to be_empty
    end

    it 'deletes approvals' do
      proposal = create(:proposal, :with_parallel_approvers)
      approval1, approval2 = proposal.individual_steps
      proposal.root_step = Steps::Serial.new(child_steps: [approval2])

      expect(Step.exists?(approval1.id)).to be false
    end
  end
end
