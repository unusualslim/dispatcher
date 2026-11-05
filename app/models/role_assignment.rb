# A user holding a role.
class RoleAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :role

  validates :role_id, uniqueness: { scope: :user_id }
end
