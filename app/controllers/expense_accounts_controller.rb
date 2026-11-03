# Accounting → Expense Accounts: the GL expense accounts that expense PO lines are charged to.
class ExpenseAccountsController < ApplicationController
  permission_area :accounting
  before_action :set_expense_account, only: %i[update destroy]

  def index
    @expense_accounts = ExpenseAccount.ordered
    @line_counts = PurchaseOrderLineItem.where.not(expense_account_id: nil).group(:expense_account_id).count
  end

  def create
    account = ExpenseAccount.new(expense_account_params)
    save_and_redirect(account, "Added #{account.account}.")
  end

  def update
    @expense_account.assign_attributes(expense_account_params)
    save_and_redirect(@expense_account, "Saved #{@expense_account.account}.")
  end

  def destroy
    if @expense_account.destroy
      redirect_to expense_accounts_path, notice: "Deleted #{@expense_account.account}."
    else
      redirect_to expense_accounts_path,
                  alert: "#{@expense_account.account} is used on PO lines; untick Active instead."
    end
  end

  private

  def set_expense_account
    @expense_account = ExpenseAccount.find(params[:id])
  end

  def expense_account_params
    params.require(:expense_account).permit(:account, :name, :active, :notes)
  end

  def save_and_redirect(account, notice)
    if account.save
      redirect_to expense_accounts_path, notice: notice
    else
      redirect_to expense_accounts_path, alert: "#{account.account}: #{account.errors.full_messages.to_sentence}"
    end
  end
end
