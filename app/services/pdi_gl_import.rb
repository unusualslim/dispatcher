# PDI's GL journal import layout, one row per journal line. Lines of one entry share the
# reference number, date and description; each row has a debit or a credit, never both.
module PdiGlImport
  HEADERS = ['Reference Number', 'Reference Date', 'Description', 'Period', 'Year', 'Journal ID',
             'Reverse Entry', 'Account', 'Activity ID', 'Line Description', 'Debit', 'Credit',
             'Reverse Entry Period'].freeze

  module_function

  # journal responds to reference_number, reference_date, description, journal_id, lines and
  # full_account; lines respond to account, description, debit and credit.
  def rows(journal)
    entry = entry_fields(journal)
    journal.lines.map do |line|
      entry + [journal.full_account(line.account), nil, line.description.first(50),
               money(line.debit), money(line.credit), nil]
    end
  end

  def entry_fields(journal)
    date = journal.reference_date
    [journal.reference_number, date&.strftime('%m/%d/%Y'), journal.description,
     date&.strftime('%m'), date&.year, journal.journal_id, 'No']
  end

  def money(amount)
    amount && format('%.2f', amount)
  end
end
