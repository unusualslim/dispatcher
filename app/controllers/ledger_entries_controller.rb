class LedgerEntriesController < ApplicationController
  permission_area :accounting, approve: %i[create reverse export]

  def index
    @status = params[:status].presence_in(LedgerEntry::STATUSES)
    @entries = LedgerEntry.includes(:production_order, :approved_by, :ledger_lines, :reversal, :reversal_of)
                          .newest_first.limit(200)
    @entries = @entries.where(status: @status) if @status
    @pending_count = LedgerEntry.pending_export.count
    @exports = SyncLog.for_process(PdiGlExport::PROCESS_NAME).limit(10)
  end

  # Approve & post a production order's FPST journal.
  def create
    order = ProductionOrder.find(params[:production_order_id])
    entry = LedgerEntry.post!(ProductionOrderJournal.new(order), current_user)
    redirect_to gl_posting_path(order), notice: t('.posted', reference: entry.reference_number)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to gl_posting_path(order), alert: e.message
  end

  def reverse
    entry = LedgerEntry.find(params[:id])
    reversal = entry.reverse!(current_user)
    redirect_to entry.production_order ? gl_posting_path(entry.production_order) : ledger_entries_path,
                notice: t('.reversed', reference: reversal.reference_number)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to ledger_entries_path, alert: e.message
  end

  def export
    count = PdiGlExport.new.run
    redirect_to ledger_entries_path, notice: t('.exported', count: count)
  rescue PdiGlExport::NothingToExport => e
    redirect_to ledger_entries_path, alert: e.message
  rescue StandardError => e
    redirect_to ledger_entries_path, alert: t('.failed', error: e.message)
  end

  # The file the next export would send, for checking without marking anything exported.
  def download
    send_data PdiGlImport.csv(PdiGlExport.pending_entries),
              filename: PdiGlExport.filename.sub('.csv', '_preview.csv'), type: 'text/csv'
  end

  private

  def gl_posting_path(order)
    "#{production_order_path(order)}#gl-posting"
  end
end
