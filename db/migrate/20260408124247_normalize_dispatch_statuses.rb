class NormalizeDispatchStatuses < ActiveRecord::Migration[7.0]
  DISPATCH_STATUS_MAP = {
    "New"            => %w[new NEW],
    "Sent to Driver" => ["sent_to_driver", "Sent-to-driver", "sent-to-driver",
                         "Sent To Driver", "SENT TO DRIVER", "senttodriver",
                         "SentToDriver", "sent to driver"],
    "Complete"       => %w[complete completed COMPLETE Completed],
    "Billed"         => %w[billed BILLED],
    "Deleted"        => %w[deleted DELETED]
  }.freeze

  def up
    DISPATCH_STATUS_MAP.each do |canonical, variants|
      execute <<~SQL
        UPDATE dispatches
        SET status = #{quote(canonical)}
        WHERE status IN (#{variants.map { |v| quote(v) }.join(', ')})
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
