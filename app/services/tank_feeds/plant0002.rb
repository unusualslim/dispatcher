# The site 0002 tank email, saved whole by Power Automate as FPS_TANKS_0002_<anything>.eml: an HTML email, one line
# per tank ("<tank> <n> Gallons"). The reading belongs to the day the email was SENT (it goes out about 11:55 PM and
# its subject carries the next day's date), so the time is the email's Date header (Eastern). The mail filter's
# banner and the hidden preview line that runs every reading together are ignored. A plain text file of the same
# lines (FPS_TANKS_0002_yyyyMMdd_HHmm.txt, time from the name) or a time given on upload still works. Each named line
# is a feed tank; DI Water is created ignored, and nameless "0 Gallons" lines are skipped. Map the Bulk DEF tanks
# (Tank 1-6, T-8 500 K, P-1..P-3, Tank 11-16) to one app tank to get the plant's total.
module TankFeeds
  class Plant0002 < Base
    FEED = 'plant_0002'.freeze
    LINE = /\A(?<name>.*?)\s*(?<gallons>-?[\d,]+(?:\.\d+)?)\s+gallons\s*\z/i
    NAME_STAMP = /(\d{8})[_-](\d{4})/
    NO_TIME = 'No reading time: save the whole email (.eml), name a text file FPS_TANKS_0002_yyyyMMdd_HHmm.txt ' \
              'or enter the time'.freeze
    HIDDEN = /display\s*:\s*none|mso-hide\s*:\s*all|max-height\s*:\s*0|font-size\s*:\s*0|visibility\s*:\s*hidden/i
    BLOCKS = 'p,div,tr,li,table,h1,h2,h3,h4,h5,h6'.freeze

    # FPS_TANKS_0002_20261111_0600.txt → 2026-11-11 06:00 Eastern
    def self.time_from_name(filename)
      match = File.basename(filename.to_s).match(NAME_STAMP)
      Time.find_zone!(EASTERN).strptime("#{match[1]} #{match[2]}", '%Y%m%d %H%M') if match
    rescue ArgumentError
      nil
    end

    def initialize(path, read_at: nil, file_name: nil, **)
      super
      @email = email?(file_name || path)
      @read_at = read_at || (@email && email_time) || self.class.time_from_name(file_name || path)
    end

    private

    def parse
      raise ArgumentError, NO_TIME unless @read_at

      lines.filter_map { |line| row_for(line) }
    end

    def lines
      @email ? email_lines : File.read(@path, mode: 'rb').force_encoding('UTF-8').scrub.each_line.to_a
    end

    def email?(name)
      File.extname(name.to_s).casecmp?('.eml') || File.read(@path, 2048, mode: 'rb').to_s.match?(/^MIME-Version:/i)
    end

    def mail
      @mail ||= Mail.read(@path)
    end

    # When the email was sent, in Eastern (a reading belongs to the day it was sent, not the date in its subject).
    def email_time
      mail.date&.to_time&.in_time_zone(EASTERN)
    end

    # The visible text, a line per block or <br>: hidden elements (the filter's preview line) and styles are dropped.
    def email_lines
      doc = Nokogiri::HTML((mail.html_part || mail).decoded.to_s)
      drop_unseen(doc)
      doc.css('br').each { |node| node.replace("\n") }
      doc.css(BLOCKS).each { |node| node.add_previous_sibling("\n") && node.add_next_sibling("\n") }
      doc.text.split("\n")
    end

    def drop_unseen(doc)
      doc.css('script,style,head').each(&:remove)
      doc.css('[style]').each { |node| node.remove if node['style'].match?(HIDDEN) }
    end

    def row_for(line)
      match = line.strip.match(LINE)
      # A name that itself holds "Gallons" is several readings run together on one line: not a tank.
      return unless match && match[:name].present? && !match[:name].match?(/gallons/i)

      name = match[:name].squish
      Row.new(external_id: name, name: name, read_at: @read_at, gallons: number(match[:gallons]),
              default_ignored: name.match?(/\bDI\s*water\b/i), details: {})
    end
  end
end
