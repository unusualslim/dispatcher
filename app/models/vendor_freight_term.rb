class VendorFreightTerm < ApplicationRecord
  # [code, description] — matches PDI freight/payment terms
  TERMS = [
    ['COD',        'COD — Due Upon Receipt'],
    ['EFT5',       'EFT5 — EFT 5 Days'],
    ['EFT10',      'EFT10 — EFT 10 Days'],
    ['EFTDUR',     'EFTDUR — EFT on Receipt'],
    ['LOADBEHIND', 'LOADBEHIND — 1 Load Behind'],
    ['NET10',      'NET10 — Net 10 Days'],
    ['NET10TH',    'NET10TH — 10th of Next Month'],
    ['NET15',      'NET15 — Net 15 Days'],
    ['NET30',      'NET30 — Net 30 Days'],
    ['NET35',      'NET35 — Net 35 Days'],
    ['NET45',      'NET45 — Net 45 Days'],
    ['NET60',      'NET60 — Net 60 Days'],
    ['NET90',      'NET90 — Net 90 Days'],
    ['1%, 10DAYS', '1%, 10DAYS — 1%, 10 Days'],
    ['2%, 10DAYS', '2%, 10DAYS — 2%, 10 Days'],
    ['2%, 10TH',   '2%, 10TH — 2%, 10th of Month'],
    ['2%, 30DAYS', '2%, 30DAYS — 2%, 30 Days'],
    ['15/31st',    '15/31st — Due 15th and 31st'],
    ['20NM',       '20NM — 20th of Following Month'],
    ['CIA',        'CIA — Cash in Advance'],
    ['DUR',        'DUR — Due Upon Receipt'],
  ].freeze

  CODES = TERMS.map(&:first).freeze

  belongs_to :vendor

  validates :freight_term, presence: true
  validates :freight_term, uniqueness: { scope: :vendor_id, message: "already assigned to this vendor" }
end
