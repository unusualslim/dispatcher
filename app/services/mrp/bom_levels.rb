module Mrp
  # Low-level codes: 0 for products no planned BOM uses, else one below their deepest parent. Planning
  # parents before components lets a parent's planned production add demand to its components in time.
  class BomLevels
    def initialize(boms)
      @boms = boms
      @levels = Hash.new(0)
    end

    def call
      @boms.each_key { |parent| descend(parent, 0, Set.new) }
      @levels
    end

    private

    def descend(product_id, level, path)
      return if path.include?(product_id) # BOM loop: stop rather than recurse forever

      @levels[product_id] = [@levels[product_id], level].max
      Array(@boms[product_id]).map(&:first).each { |component| descend(component, level + 1, path | [product_id]) }
    end
  end
end
