describe LinearDispatcher do
  let(:dispatcher) { LinearDispatcher.new }

  describe '#next_pending_approval' do
    context "no approvals" do
      it "returns nil" do
        proposal = create(:proposal)
        expect(dispatcher.next_pending_approval(proposal)).to eq(nil)
      end
    end

    it "returns nil if all are non-pending" do
      proposal = create(:proposal, :with_approver)
      proposal.individual_steps.first.complete!
      expect(dispatcher.next_pending_approval(proposal)).to eq(nil)
    end

    it "skips approved approvals" do
      proposal = create(:proposal, :with_serial_approvers)
      last_approval = proposal.individual_steps.last
      proposal.individual_steps.first.complete!

      expect(dispatcher.next_pending_approval(proposal)).to eq(last_approval)
    end

    it "skips non-approvers" do
      proposal = create(:proposal, :with_approver, :with_observers)
      approval = proposal.individual_steps.first
      expect(dispatcher.next_pending_approval(proposal)).to eq(approval)
    end
  end

  describe '#deliver_new_proposal_emails' do
    it "sends emails to the first approver" do
      proposal = create(:proposal, :with_approver)
      approval = proposal.individual_steps.first

      expect(dispatcher).to receive(:email_approver).with(approval)

      dispatcher.deliver_new_proposal_emails(proposal)
    end

    it "sends a proposal notification email to observers" do
      proposal = create(:proposal, :with_observers)

      expect(dispatcher).to receive(:email_observers).with(proposal)

      dispatcher.deliver_new_proposal_emails(proposal)
    end
  end

  describe '#on_approval_approved' do
    it "sends to the requester and the next approver" do
      proposal = create(:proposal, :with_serial_approvers)
      approval = proposal.individual_steps.first
      approval.complete!   # calls on_approval_approved
      expect(email_recipients).to eq([
        proposal.approvers.second.email_address,
        proposal.requester.email_address
      ].sort)
    end
  end
end
