# Purchasing → Planning Assumptions (Planning::AssumptionReport): the missing lead times, delivery dates and
# standard costs that make the planning pages fall back on defaults, with a link to fix each.
class PlanningAssumptionsController < ApplicationController
  permission_area :purchasing

  def index
    @report = Planning::AssumptionReport.new
  end
end
