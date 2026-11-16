require 'csv'

# The Tank Feeds export: every Kii and Smartank tank linked to an app tank, with the app location number and product
# ID to key back into the monitor (Kii Parameter_1 / Parameter_2, Smartank User Defined A / User Product ID), so later
# imports link the tank by themselves. Tanks whose monitor doesn't carry the right IDs yet come first.
class TankFeedExport
  FIELDS = {
    'kii' => %w[Parameter_1 Parameter_2],
    'smartank' => ['User Defined (A)', 'User Product ID']
  }.freeze
  HEADERS = ['Monitor', 'Monitor tank ID', 'Serial', 'Monitor tank name', 'Location number', 'Location',
             'Product ID', 'Product', 'Location field', 'Product field', 'Monitor has location number',
             'Monitor has product ID'].freeze

  def rows
    @rows ||= linked.map { |feed_tank| row(feed_tank) }
                    .sort_by { |r| [r[:done] ? 1 : 0, r[:values][0], r[:values][5].to_s, r[:values][3].to_s] }
  end

  def to_csv
    CSV.generate do |csv|
      csv << HEADERS
      rows.each { |r| csv << r[:values] }
    end
  end

  private

  def linked
    FeedTank.where(feed: FIELDS.keys).where.not(tank_id: nil).includes(tank: %i[location product])
  end

  def row(feed_tank)
    tank = feed_tank.tank
    location_ok = feed_tank.details['location_id'].to_s.strip == tank.location_id.to_s
    product_ok = tank.product_id.blank? || feed_tank.details['product_id'].to_s.strip == tank.product_id
    { done: location_ok && product_ok, values: values(feed_tank, tank, location_ok, product_ok) }
  end

  def values(feed_tank, tank, location_ok, product_ok)
    location_field, product_field = FIELDS[feed_tank.feed]
    [feed_tank.feed_name, feed_tank.external_id, feed_tank.details['serial'], feed_tank.name, tank.location_id,
     tank.location&.company_name, tank.product_id, tank.product&.name, location_field, product_field,
     location_ok ? 'Yes' : 'No', product_ok ? 'Yes' : 'No']
  end
end
