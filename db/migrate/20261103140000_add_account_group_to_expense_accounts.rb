# PDI's account group (Operating Expenses, Cost of Sales, Labor Expense...), to group the account picker.
class AddAccountGroupToExpenseAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :expense_accounts, :account_group, :string
  end
end
