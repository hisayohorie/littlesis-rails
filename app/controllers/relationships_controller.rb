class RelationshipsController < ApplicationController
  before_action :set_relationship, only: [:show, :edit, :update, :destroy, :reverse_direction]
  before_action :authenticate_user!, except: [:show]
  before_action -> { check_permission('deleter') }, only: [:destroy]

  def show
  end

  # GET /relationships/:id/edit
  def edit
    @selected_ref = params[:new_ref].present? ? @relationship.references.try(:last).try(:id) : nil
  end

  # PATCH /relationships/:id
  def update
    if existing_reference_params['reference_id'].blank? && existing_reference_params['just_cleaning_up'].blank?
      # If user has not checked the 'just cleaning up' or selected an existing reference
      # then a  new reference must be created
      @reference = Reference.new(reference_params)
      # if not valid: re-render the edit page with the reference error
      return render :edit unless @reference.validate_before_create.empty?
      # if the reference is valid assign the other attribute required
      @reference.assign_attributes(object_id: @relationship.id, object_model: "Relationship")
    end
    if @relationship.update_attributes prepare_update_params(update_params)
      @reference.save unless @reference.nil? # save the reference
      update_entity_last_user
      redirect_to relationship_path(@relationship)
    else
      render :edit
    end
  end

  # Creates a new Relationship and a Reference
  # Returns status code 201 if successful or a json of errors with status code 400
  def create
    @relationship = Relationship.new(relationship_params)
    @reference = Reference.new(reference_params)

    if @relationship.valid? and @reference.validate_before_create.empty?
      @relationship.save!
      @reference.assign_attributes(object_id: @relationship.id, object_model: "Relationship")
      @reference.save
      # updated last_user_id of the entities in the relationship
      update_entity_last_user
      render json: {'relationship_id' => @relationship.id}, status: :created
    else
      errors = {
        relationship: @relationship.errors.to_h,
        reference: @reference.validate_before_create
      }
      render json: errors, status: :bad_request
    end
  end

  def destroy
    @relationship.soft_delete
    redirect_to home_dashboard_path, notice: 'Relationship successfully deleted'
  end

  # POST /relationships/:id/reverse_direction
  def reverse_direction
    @relationship.reverse_direction
    redirect_to :action => "edit", :id => @relationship.id
  end

  def find_similar
    if has_required_find_similar_params?
      render json: Relationship.find_similar(similar_relationships_params).map { |r| r.as_json(:url => true) }
    else
      head :bad_request
    end
  end

  # POST /relationships/bulk_add
  def bulk_add
    # Users without the bulker permission cannot submit more than 8 bulk relationships at a time
    if params[:relationships].length > 8 && !(current_user.bulker? || current_user.admin?)
      return head :unauthorized
    end

    return head :bad_request unless Reference.new(reference_params).validate_before_create.empty?
    @errors = []
    @new_relationships = []

    entity1 = Entity.find(params.fetch('entity1_id'))

    # Looping through each relationship
    bulk_relationships_params.each do |relationship|
      ActiveRecord::Base.transaction do
        make_or_get_entity(relationship) do |entity2|
          rollback_if(relationship) do
            create_bulk_relationship(entity1, entity2, relationship)
          end
        end
      end
    end # end loop of submitted relationships

    # Always send back a sucuessful responce,
    # even if every relationship is an error
    render :json => bulk_json_response
  end

  private

  ####################
  # Bulk Add Helpers #
  ####################

  # Hash -> Nil | yield
  # creating or finding the entity for the relationship
  def make_or_get_entity(relationship)
    if relationship.fetch('name').to_i.zero?
      attributes = relationship.slice('name', 'blurb', 'primary_ext').merge('last_user_id' => current_user.sf_guard_user_id)
      entity = Entity.create(attributes)
    else
      entity = Entity.find_by_id(relationship.fetch('name').to_i)
    end

    if entity.try(:persisted?)
      yield entity
    else
      @errors << relationship.merge('errorMessage' => 'Failed to find or create entity')
    end
  end

  def rollback_if(relationship)
    yield
  rescue ActiveRecord::StatementInvalid
    # The rails documentation recommends not catching this exception: http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html
    # ...and we shall OBEY the rails docs...
    raise
  rescue ActiveRecord::ActiveRecordError => e
    @errors << relationship.merge('errorMessage' => e.message)
    Rails.logger.warn "BulkAdd Relationship Error: #{e.message}"
    raise ActiveRecord::Rollback, "Error creating a Relationship"
  end

  def create_bulk_relationship(entity1, entity2, relationship)
    r = Relationship.new(relationship_attributes(entity1, entity2, relationship))
    r.save!
    # if the relationship is not persisted (meaning an error occurred)
    # creating the reference for that relationship
    Reference.create(reference_params.merge(object_id: r.id, object_model: 'Relationship'))
    # some relationships will have additional fields:
    if extension?
      # get only the category fields from the relationship hash
      new_category_attr = relationship.delete_if { |key| (r.attributes.keys + ['name', 'primary_ext', 'blurb']).include? key }
      # update relationship category - we don't have to update if nothing has changed
      r.get_category.update(new_category_attr) unless r.category_attributes == new_category_attr
    end
    @new_relationships << r.as_json(:url => true, :name => true)
  end

  # <Entity>, <Entity>, Hash -> Hash
  def relationship_attributes(entity1, entity2, relationship)
    r = {
      entity1_id: entity1.id,
      entity2_id: entity2.id,
      category_id: params.require(:category_id),
      description1: relationship.fetch('description1', nil),
      description2: relationship.fetch('description2', nil),
      start_date: relationship.fetch('start_date', nil),
      end_date: relationship.fetch('end_date', nil),
      goods: relationship.fetch('goods', nil),
      amount: relationship.fetch('amount', nil),
      is_current: relationship.fetch('is_current', nil),
      last_user_id: current_user.sf_guard_user_id
    }

    if r[:category_id].to_i == 1 && entity1.org? && entity2.person?
      r[:entity1_id] = entity2.id
      r[:entity2_id] = entity1.id
    end

    # 50 & 51 represent special donation categories
    # see helpers/tools_helper.rb
    if r[:category_id].to_i == 50 || r[:category_id].to_i == 51
      if r[:category_id].to_i == 50
        r[:entity1_id] = entity2.id
        r[:entity2_id] = entity1.id  
      end
      r[:category_id] = 5
    end

    prepare_update_params(r)
  end

  def bulk_json_response
    { errors: @errors, relationships: @new_relationships }
  end

  def bulk_relationships_params
    return params[:relationships].map { |x| blank_to_nil(x) } if params[:relationships].is_a?(Array)
    params[:relationships].to_a.map { |x| x[1] }.map { |x| blank_to_nil(x) }
  end

  #################
  # Other Helpres #
  #################

  def extension?
    [1, 2, 3, 10].include? params.require(:category_id).to_i
  end

  def set_relationship
    @relationship = Relationship.find(params[:id])
  end

  def update_entity_last_user
    @relationship.entity.update(last_user_id: current_user.sf_guard_user_id)
    @relationship.related.update(last_user_id: current_user.sf_guard_user_id)
  end

  def relationship_params
    prepare_update_params(params.require(:relationship).permit(:entity1_id, :entity2_id, :category_id, :is_current, :description1, :description2))
  end

  def reference_params
    params.require(:reference).permit(:name, :source, :source_detail, :publication_date, :ref_type)
  end

  def existing_reference_params
    params.require(:reference).permit(:just_cleaning_up, :reference_id)
  end

  # whitelists relationship params and associated nested attributes
  # if the relationship category requires them
  def update_params
    relationship_fields = @relationship.attribute_names.map(&:to_sym)
    if Relationship.all_category_ids_with_fields.include? @relationship.category_id
      category_fields = @relationship.get_category.attribute_names.map(&:to_sym)
      relationship_fields.push("#{@relationship.category_name.downcase}_attributes".to_sym => category_fields)
    end
    params.require(:relationship).permit(*relationship_fields)
  end

  def similar_relationships_params
    params.permit(:entity1_id, :entity2_id, :category_id)
  end

  def has_required_find_similar_params?
    p = similar_relationships_params
    return true if p.has_key?(:entity1_id) && p.has_key?(:entity2_id) && p.has_key?(:category_id)
    return false
  end
  
end
