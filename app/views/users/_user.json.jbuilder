json.extract! user, :id, :email, :encrypted_password, :reset_password_token, :reset_password_sent_at, :remember_created_at, :first_name, :last_name, :phone_number, :role, :created_at, :updated_at
json.url user_url(user, format: :json)
