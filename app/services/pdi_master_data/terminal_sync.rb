module PdiMasterData
  # PDI terminals → locations.pdi_terminal_id, matched to existing origin locations by name.
  # None are created: PDI has no coordinates for most terminals, so they couldn't go on the map.
  class TerminalSync < Sync
    SECTION = :terminals

    def call
      @linked = Location.where.not(pdi_terminal_id: nil).index_by(&:pdi_terminal_id)
      @unlinked = Location.where(location_category_id: 1, pdi_terminal_id: nil)
                          .group_by { |l| normalize(l.company_name) }
      @doc.xpath('//Origins/Terminals/Terminal').each do |node|
        id = text(node, 'ID')
        name = text(node, 'Description')
        guard(id, name) { sync(id, name) }
      end
    end

    private

    def sync(id, name)
      return record(:unchanged, id, name) if @linked[id]

      location = @unlinked[normalize(name)]&.shift
      return record(:skip, id, name, {}, 'No origin location with this name') unless location

      location.update!(pdi_terminal_id: id) if apply?
      record(:link, id, name, { pdi_terminal_id: id }, "Matched #{location.company_name}")
    end
  end
end
