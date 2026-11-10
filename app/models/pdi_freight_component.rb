# One rule's share of a PDI fuel line's freight ("freight in detail"), from the nightly PDI SQL export
# (docs/pdi_sql/freight_detail.sql, imported by PdiFreightComponents::Import):
# - source load: a load line's purchase freight (Order_Fuel_Load_Freight), with load, order, BOL and product
# - source order: an order fuel line's sale freight (Order_Details_Fuel_Freight), with order and product
# charge = the PDI freight rule (FPLFSC, TA-TP-DEF-NUTAUG…); rule_type 0 = base freight rate, 1 per load,
# 2 fuel surcharge, 4 split load, 6 minimum load, 9 total freight override. purchase / sale = the rule's sides.
class PdiFreightComponent < ApplicationRecord
  SOURCES = %w[load order].freeze
  BASE_TYPE = 0
  OVERRIDE_TYPE = 9

  validates :source, inclusion: { in: SOURCES }
  validates :component_key, :line_key, :charge, presence: true

  def load? = source == 'load'
  def override? = rule_type == OVERRIDE_TYPE

  # Line freight proper (a base rate, or an override replacing the rules), as opposed to surcharges and fees.
  def base? = rule_type == BASE_TYPE || override?
end
