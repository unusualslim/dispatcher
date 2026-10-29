# Freight classes (how much fits on a full load) and which products are in each.
class FreightClassesController < ApplicationController
  permission_area :sales
  before_action :set_class, only: %i[update destroy]

  def index
    @classes = FreightClass.ordered
    @product_counts = Product.where.not(freight_class_id: nil).group(:freight_class_id).count
    @categories = Product.where(active: true).where.not(category: [nil, '']).distinct.order(:category).pluck(:category)
    @products_by_class = Product.where.not(freight_class_id: nil).order(:name).group_by(&:freight_class_id)
  end

  def create
    save_and_redirect(FreightClass.new(class_params), t('.created'))
  end

  def update
    @freight_class.assign_attributes(class_params)
    save_and_redirect(@freight_class, t('.updated'))
  end

  def destroy
    @freight_class.destroy!
    redirect_to freight_classes_path, notice: t('.deleted', code: @freight_class.code)
  end

  # Puts every product in a category (or a list of product IDs) in a class; a blank class takes them out.
  def assign
    changes = { freight_class_id: params[:freight_class_id].presence, updated_at: Time.current }
    count = products_to_assign.update_all(changes) # rubocop:disable Rails/SkipsModelValidations
    redirect_to freight_classes_path, notice: t('.assigned', count: count)
  end

  private

  def products_to_assign
    return Product.where(category: params[:category]) if params[:category].present?

    Product.where(id: params[:product_ids].to_s.split(/[\s,]+/).compact_blank)
  end

  def set_class
    @freight_class = FreightClass.find(params[:id])
  end

  def class_params
    params.require(:freight_class).permit(:code, :name, :full_load_quantity, :unit, :notes)
  end

  def save_and_redirect(record, notice)
    if record.save
      redirect_to freight_classes_path, notice: notice
    else
      redirect_to freight_classes_path, alert: record.errors.full_messages.to_sentence
    end
  end
end
