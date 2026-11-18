# Keeps an audit trail of a model's changes (paper_trail): who changed which field, when, from what. Shown by the
# History panel on show pages (shared/_history). Extra fields that change on their own (stock, sync stamps) and
# secrets are passed as ignore: / skip:.
module Audited
  extend ActiveSupport::Concern

  class_methods do
    def audited(ignore: [], skip: [])
      has_paper_trail ignore: [:updated_at, :created_at, *ignore], skip: skip
    end
  end
end
