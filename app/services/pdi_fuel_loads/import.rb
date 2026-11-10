module PdiFuelLoads
  # Upserts PdiFuelLoads from a GetFuelLoads document (or a feed of several <PDIFuelLoads>) by load number.
  class Import
    Result = Struct.new(:created, :updated, :unchanged, keyword_init: true)

    def self.call(xml)
      new(xml).run
    end

    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      @doc.remove_namespaces!
    end

    def run
      result = Result.new(created: 0, updated: 0, unchanged: 0)
      @doc.xpath('//PDIFuelLoad').each { |node| result[save(LoadNode.new(node).attrs)] += 1 }
      result
    end

    private

    def save(attrs)
      load = PdiFuelLoad.find_or_initialize_by(load_no: attrs[:load_no])
      action = load.new_record? ? :created : :updated
      load.assign_attributes(attrs)
      return :unchanged unless load.changed?

      load.save!
      action
    end
  end
end
