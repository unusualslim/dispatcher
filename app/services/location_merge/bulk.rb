class LocationMerge
  # Merges many [remove_id, keep_id] pairs, each in its own transaction, so one failure doesn't stop the
  # rest. Pairs overlap (A↔B, A↔C, B↔C for three copies), so a location already merged away is followed
  # to the one it went into, and a pair whose two sides end up the same is skipped.
  class Bulk
    Result = Struct.new(:merged, :skipped, :errors, keyword_init: true)

    def initialize(pairs)
      @pairs = pairs
      @merged_into = {}
    end

    def run
      result = Result.new(merged: 0, skipped: 0, errors: [])
      @pairs.each { |remove_id, keep_id| merge_one(resolve(remove_id), resolve(keep_id), result) }
      result
    end

    private

    def merge_one(remove_id, keep_id, result)
      remove, keep = Location.where(id: [remove_id, keep_id]).index_by(&:id).values_at(remove_id, keep_id)
      return result.skipped += 1 unless remove && keep && remove != keep

      merge!(remove, keep, result)
    end

    def merge!(remove, keep, result)
      LocationMerge.new(remove, keep).merge!
      @merged_into[remove.id] = keep.id
      result.merged += 1
    rescue ArgumentError, ActiveRecord::ActiveRecordError => e
      result.errors << "#{remove.company_name} → #{keep.company_name}: #{e.message}"
    end

    def resolve(id)
      id = @merged_into[id] while @merged_into.key?(id)
      id
    end
  end
end
