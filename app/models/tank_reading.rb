# One level reading from a feed (stored in UTC, shown in Eastern). Never moves inventory.
class TankReading < ApplicationRecord
  belongs_to :feed_tank
  belongs_to :sync_log, optional: true
end
