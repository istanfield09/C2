class User < ActiveRecord::Base
  include PropMixin
  validates_presence_of :email_address
  validates_uniqueness_of :email_address

  has_many :user_roles
  has_many :approval_groups, through: :user_roles
  has_many :approvals
  has_many :carts, through: :approvals
  has_many :properties, as: :hasproperties
  has_many :comments

  def full_name
    if first_name && last_name
      "#{first_name} #{last_name}"
    else
      email_address
    end
  end

  def requested_carts
    self.carts.merge(Approval.requesting)
  end

  def approver_of?(cart)
    cart.approvers.include? self
  end

  def last_requested_cart
    self.requested_carts.order('carts.created_at DESC').first
  end

  def self.from_oauth_hash(auth_hash)
    user_data = auth_hash.extra.raw_info.to_hash
    self.find_or_create_by(email_address: user_data['email'])
  end
end
