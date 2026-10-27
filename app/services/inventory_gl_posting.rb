# Posts costed inventory movements to the GL for categories where the app owns the inventory side
# (reporting_groups.post_inventory_gl): one FPST entry per source document and date (InventoryJournal),
# sent to PDI with the scheduled PDI GL Export. Production moves stay on the production order's journal.
# Only movements on or after both the inventory start date and the GL posting start date post.
module InventoryGlPosting
  POSTED_TYPES = InventoryJournal::OFFSET_ROLES.keys.freeze

  module_function

  def start_date
    dates = [InventoryRevaluation.start_date, ProductionGlPosting.start_date]
    dates.max if dates.all?
  end

  # Movements waiting to post.
  def pending
    start = start_date
    return InventoryTransaction.none unless start

    InventoryTransaction.where(gl_posted_at: nil, movement_type: POSTED_TYPES, occurred_on: start..)
                        .joins(product: :reporting_group).where(reporting_groups: { post_inventory_gl: true })
  end

  # Posts every ready document; returns how many entries were posted. Documents with missing accounts wait.
  def post_pending!
    documents.count do |date, moves|
      post_document!(InventoryJournal.new(moves, date))
    rescue StandardError => e
      Rails.logger.error "[InventoryGlPosting] #{moves.first.reference_number}: #{e.message}"
      false
    end
  end

  # { [date, moves] } grouped by source document (or reference, for adjustments and syncs) and date.
  def documents
    pending.preload(:location, :transactable, product: :reporting_group).order(:id).to_a
           .group_by { |move| [move.occurred_on, document_key(move)] }
           .map { |(date, _), moves| [date, moves] }
  end

  # Adjustments and PDI syncs have no source record: their reference is the document.
  def document_key(move)
    move.transactable_id ? [move.transactable_type, move.transactable_id] : move.reference_number
  end

  # Why waiting documents can't post (missing accounts or sites).
  def problems
    documents.flat_map { |date, moves| InventoryJournal.new(moves, date).problems }.uniq
  end

  # Movements that net to nothing are marked posted with no entry.
  def post_document!(journal)
    return false unless journal.ready?

    LedgerEntry.transaction do
      entry = create_entry!(journal) if journal.lines.any?
      posted = { ledger_entry_id: entry&.id, gl_posted_at: Time.current }
      InventoryTransaction.where(id: journal.moves.map(&:id)).update_all(posted) # rubocop:disable Rails/SkipsModelValidations
      entry.present?
    end
  end

  def create_entry!(journal)
    LedgerEntry.create!(
      source: journal.source, reference_number: reference_for(journal), reference_date: journal.reference_date,
      description: journal.description, journal_id: journal.journal_id, approved_at: Time.current,
      ledger_lines: journal.lines.each_with_index.map do |line, i|
        LedgerLine.new(position: i + 1, posting: 'inventory', account: line.account,
                       line_description: line.description, debit: line.debit, credit: line.credit)
      end
    )
  end

  # The document's reference (PO, PDI order, ADJ-…), with -2, -3… when it posts again.
  def reference_for(journal)
    base = (journal.moves.first.reference_number.presence || "INV-#{journal.moves.first.id}").first(26)
    taken = LedgerEntry.where('reference_number = ? OR reference_number LIKE ?', base, "#{base}-%")
                       .pluck(:reference_number)
    return base unless taken.include?(base)

    "#{base}-#{(2..).find { |n| taken.exclude?("#{base}-#{n}") }}"
  end
end
