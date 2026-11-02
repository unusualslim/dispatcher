# The page a user lands on after signing in and when clicking the logo (a path in the app; blank = the
# role's default).
class AddHomePageToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :home_page, :string
  end
end
