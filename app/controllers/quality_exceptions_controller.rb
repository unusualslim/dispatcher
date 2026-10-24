# Out-of-range quality results waiting for someone with Production approval to review.
class QualityExceptionsController < ApplicationController
  permission_area :production, approve: %i[review]

  def index
    @show_reviewed = params[:reviewed] == '1'
    scope = QualityResult.out_of_range.includes(:tested_by, :reviewed_by, production_order: :product)
    scope = @show_reviewed ? scope.where.not(reviewed_at: nil) : scope.unreviewed
    @results = scope.order(tested_at: :desc).limit(200)
    @unreviewed_count = QualityResult.out_of_range.unreviewed.count
  end

  def review
    QualityResult.out_of_range.find(params[:id]).review!(current_user, params[:resolution])
    redirect_to quality_exceptions_path, notice: t('.reviewed')
  rescue ArgumentError => e
    redirect_to quality_exceptions_path, alert: e.message
  end
end
