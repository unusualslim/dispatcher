class User < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :validatable
  
    # Validations
    validates :email, presence: true, uniqueness: true
  
    # Scope to filter workers
    scope :workers, -> { where(role: 'worker') }
  
    def full_name
      "#{first_name} #{last_name}"
    end
  end
  
