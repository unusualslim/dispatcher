module Freight
  # Splits an amount over weights ({ key => weight }) to the cent; the last key takes the rounding.
  module Allocation
    module_function

    def split(amount, weights)
      total = weights.values.sum
      return {} unless total.positive?

      remaining = amount.to_d
      weights.each_with_index.to_h do |(key, weight), i|
        share = i == weights.size - 1 ? remaining : (amount.to_d * weight / total).round(2)
        remaining -= share
        [key, share]
      end
    end
  end
end
