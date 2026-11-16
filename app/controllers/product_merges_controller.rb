# Admin → Merge Products: folds an obsolete product into the one that replaced it (FPS001 → 901), with a preview
# first (ProductMerge).
class ProductMergesController < ApplicationController
  before_action :require_admin!

  # source_id = the obsolete product; with target_id (the one to keep), preview the merge.
  def new
    @source = Product.find_by(id: params[:source_id])
    @target = Product.find_by(id: params[:target_id])
    @merge = ProductMerge.new(@source, @target) if @source && @target
  rescue ArgumentError => e
    @error = e.message
  end

  def create
    merge = ProductMerge.new(Product.find(params[:source_id]), Product.find(params[:target_id]))
    notice = merged_notice(merge) # counted before the records move
    merge.merge!
    redirect_to product_path(merge.target), notice: notice
  rescue ArgumentError, ActiveRecord::ActiveRecordError => e
    failed(e)
  end

  # Product search for both pickers (inactive products included: the obsolete one usually is).
  def products
    term = "%#{Product.sanitize_sql_like(params[:q].to_s.strip)}%"
    products = Product.where('products.id ILIKE :t OR products.name ILIKE :t', t: term).order(:id).limit(25)
    render json: products.map { |p| { id: p.id, text: "#{p.id} — #{p.name}#{' (inactive)' unless p.active}" } }
  end

  private

  def failed(error)
    Rails.logger.warn "[ProductMerge] #{params[:source_id]} → #{params[:target_id]} failed: " \
                      "#{error.class}: #{error.message}"
    redirect_to new_product_merge_path(source_id: params[:source_id], target_id: params[:target_id]),
                alert: t('product_merges.create.failed', error: error.message)
  end

  def merged_notice(merge)
    t('product_merges.create.merged', source: merge.source.id, target: merge.target.id,
                                      summary: merge.summary.presence || t('product_merges.create.nothing_moved'))
  end
end
