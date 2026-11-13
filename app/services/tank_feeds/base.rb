require 'csv'

# Shared parsing and storing for the tank feed importers (see TankFeeds).
module TankFeeds
  class Base
    EASTERN = 'America/New_York'.freeze
    READING_FIELDS = %i[read_at gallons water_inches temperature_f status].freeze

    attr_reader :unreadable

    def initialize(path, **)
      @path = path
      @unreadable = 0
    end

    def feed
      self.class::FEED
    end

    def rows
      @rows ||= parse
    end

    def summary
      ids = rows.map(&:external_id).uniq
      Summary.new(rows: rows.size, feed_tanks: ids.size, new_feed_tanks: (ids - existing.keys).size,
                  newest_read_at: rows.filter_map(&:read_at).max, unreadable: unreadable, **reading_counts)
    end

    def import!(sync_log: nil)
      counts = Hash.new(0)
      FeedTank.transaction { rows.each { |row| import_row(row, counts, sync_log) } }
      { created: counts[:created], updated: counts[:new_tanks], skipped: counts[:skipped], warnings: warnings(counts) }
    end

    private

    def import_row(row, counts, sync_log)
      feed_tank = upsert_feed_tank(row, counts)
      return counts[:skipped] += 1 if feed_tank.ignored || !row.readable?

      result = feed_tank.record_reading!(row.to_h.slice(*READING_FIELDS), sync_log: sync_log)
      counts[result == :created ? :created : :skipped] += 1
    end

    def upsert_feed_tank(row, counts)
      feed_tank = FeedTank.find_or_initialize_by(feed: feed, external_id: row.external_id)
      count_new(feed_tank, row, counts) if feed_tank.new_record?
      feed_tank.absorb(name: row.name, details: row.details)
      feed_tank
    end

    def count_new(feed_tank, row, counts)
      feed_tank.ignored = row.default_ignored ? true : false
      counts[:new_tanks] += 1
      counts[:new_tracked] += 1 unless feed_tank.ignored
    end

    def warnings(counts)
      list = []
      if counts[:new_tracked].positive?
        list << "#{counts[:new_tracked]} new feed tanks to set up (Dispatch → Tank Feeds)"
      end
      list << "#{unreadable} rows without a readable time or level" if unreadable.positive?
      list
    end

    # Feed tanks already in the app, by the feed's ID.
    def existing
      @existing ||= FeedTank.in_feed(feed).where(external_id: rows.map(&:external_id).uniq).index_by(&:external_id)
    end

    def reading_counts
      ignored, tracked = rows.partition { |row| ignored?(row) }
      readable = tracked.select(&:readable?)
      new_readings = new_reading_count(readable)
      { ignored: ignored.size, new_readings: new_readings, duplicates: readable.size - new_readings }
    end

    def ignored?(row)
      existing[row.external_id] ? existing[row.external_id].ignored : row.default_ignored
    end

    def new_reading_count(readable)
      stored = stored_keys(readable)
      readable.count { |row| stored.exclude?([existing[row.external_id]&.id, row.read_at.to_i]) }
    end

    def stored_keys(readable)
      ids = readable.filter_map { |row| existing[row.external_id]&.id }.uniq
      return Set.new if ids.empty?

      TankReading.where(feed_tank_id: ids, read_at: readable.map(&:read_at).uniq)
                 .pluck(:feed_tank_id, :read_at).to_set { |id, at| [id, at.to_i] }
    end

    # "1,234.5", "65%", "" → BigDecimal or nil
    def number(value)
      text = value.to_s.delete(',%').strip
      return if text.empty? || text == '-'

      BigDecimal(text)
    rescue ArgumentError
      nil
    end

    def time_in(zone, text, *formats)
      formats.each do |format|
        return Time.find_zone!(zone).strptime(text.to_s.strip, format)
      rescue ArgumentError
        next
      end
      nil
    end

    # A row with no time or level still registers its feed tank, but stores no reading.
    def readable(row)
      @unreadable += 1 unless row.readable?
      row
    end

    def read_csv
      text = File.read(@path, mode: 'rb').force_encoding('UTF-8').delete_prefix('﻿')
      text = text.encode('UTF-8', 'Windows-1252') unless text.valid_encoding?
      CSV.parse(text, liberal_parsing: true)
    end

    # Header row → hashes of the rows below it.
    def records(table, header_index = 0)
      header = table[header_index].to_a.map { |h| h.to_s.strip }
      table.drop(header_index + 1).map { |values| header.zip(values).to_h }
    end
  end
end
