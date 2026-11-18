# The History panel (shared/_history): a record's audit trail, plus its child records' (order lines, components),
# newest first, with who changed which fields.
module AuditHelper
  HISTORY_LIMIT = 100
  HIDDEN_FIELDS = %w[id updated_at created_at].freeze
  # Fields shown only to users who may see that data (the same data flags as the pages).
  FLAGGED_FIELDS = { costs: /cost|value|margin|repack_fee|unit_cost|rate/, customer_pricing: /price/ }.freeze

  # children: { 'CustomerOrderProduct' => 'customer_order_id' } — versions of child rows pointing at the record.
  def audit_versions(record, children: {})
    scope = PaperTrail::Version.where(item_type: record.class.base_class.name, item_id: record.id.to_s)
    children.each do |type, key|
      scope = scope.or(child_versions(type, key, record.id))
    end
    scope.order(created_at: :desc, id: :desc).limit(HISTORY_LIMIT)
  end

  # users: { id string => email }, looked up once per panel.
  def audit_user(version, users)
    return 'system' if version.whodunnit.blank?

    users[version.whodunnit] || "user #{version.whodunnit}"
  end

  def audit_users(versions)
    ids = versions.filter_map { |v| v.whodunnit.presence&.to_i }
    User.where(id: ids).pluck(:id, :email).to_h.transform_keys(&:to_s)
  end

  # ["Price: 4.75 → 5.10", …] (creates list the values set; destroys say Deleted).
  def audit_changes(version)
    return ['Deleted'] if version.event == 'destroy'

    visible_changes(version).map do |field, (from, to)|
      next "#{field.humanize}: #{to}" if version.event == 'create'

      "#{field.humanize}: #{from.presence || '—'} → #{to.presence || '—'}"
    end
  end

  private

  def visible_changes(version)
    (version.object_changes || {}).except(*HIDDEN_FIELDS).reject do |field, _|
      FLAGGED_FIELDS.any? { |flag, pattern| field.match?(pattern) && !sees?(flag) }
    end
  end

  def child_versions(type, key, id)
    PaperTrail::Version.where(item_type: type)
                       .where('object ->> :key = :id OR object_changes -> :key ->> 1 = :id', key: key, id: id.to_s)
  end
end
