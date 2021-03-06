module EntitiesHelper
  def entity_hash_link(entity, name=nil, action=nil)
    name ||= entity['name']
    link_to name, Entity.legacy_url(entity['primary_ext'], entity['id'], name, action)
  end

  def tiny_entity_image(entity)
    content_tag('div', nil, class: "entity_tiny_image", style: "background-image: url('#{image_path(entity.featured_image_url('small'))}');")
  end

  def legacy_user_path(user)
    '/user/' + user.username
  end

  def active_tab?(tab_name, active_tab)
    if active_tab == tab_name
      return 'active'
    else
      return 'inactive'
    end
  end

  # Relationships display

  def section_heading(links)
    content_tag(:div, links.heading, class: "subsection") if links.count > 0
  end

  # input: <Entity>, <LinksGroup>
  def link_to_all(entity, links)
    content_tag :div, class: 'section_meta' do
      content_tag(:span, "Showing 1-10 of #{links.count} :: ") + link_to('see all', entity_url(entity, :relationships => links.keyword))
    end if links.count > 10
  end

  def section_order(entity)
    section_order_person = [
      'business_positions',
      'government_positions',
      'in_the_office_positions',
      'other_positions_and_memberships',
      'schools',
      'holdings',
      'services_transactions',
      'family',
      'professional_relationships',
      'friendships',
      'donors',
      'donation_recipients',
      'staff',
      #  'political_fundraising_committees',
      'lobbies',
      'lobbied_by',
      'miscellaneous'
    ]

    section_order_org = [
      'parents',
      'children',
      'holdings',
      'other_positions_and_memberships',
      'owners',
      'members',
      'staff',
      'donation_recipients',
      'donors',
      'services_transactions',
      'students',
      'lobbies',
      'lobbied_by',
      'miscellaneous'
    ]

    entity.person? ? section_order_person : section_order_org
  end

  def extra_links_count(links)
    return '' if links.count <= 1
    "[+#{links.count - 1}]"
  end

  def type_select_boxes_person(entity = @entity)
    boxes_to_html(checkboxes(entity, ExtensionDefinition.person_types))
  end

  def org_boxes_tier2(entity = @entity)
    boxes_to_html(checkboxes(entity, ExtensionDefinition.org_types_tier2), 4)
  end

  def org_boxes_tier3(entity = @entity)
    boxes_to_html(checkboxes(entity, ExtensionDefinition.org_types_tier3), 6)
  end

  # [ content_tag ] => html
  def boxes_to_html(boxes, slice = 5)
    boxes.each_slice(slice).reduce('') do |x, box_group|
      x + content_tag(:div, box_group.reduce(:+), class: 'col-sm-4')
    end.html_safe
  end

  def checkboxes(entity, definitions)
    checked_def_ids = entity.extension_records.map(&:definition_id)
    definitions.collect do |ed|
      is_checked = checked_def_ids.include?(ed.id)
      content_tag(:span, class: 'entity-type-checkbox-wrapper') do
        glyph_checkbox(is_checked, ed.id) + content_tag(:span, " #{ed.display_name}", class: 'entity-type-name') + tag(:br)
      end
    end
  end

  # boolean, [] -> content_tag
  def glyph_checkbox(checked, def_id)
    glyphicon_class = ['glyphicon']
    glyphicon_class.append(if checked then 'glyphicon-check' else 'glyphicon-unchecked' end)
    content_tag(:span, nil, class: glyphicon_class, aria_hidden: 'true', data: { definition_id: def_id })
  end

  # <FormBuilder Thingy> -> [options for select]
  def gender_select_options(person_form)
    person = person_form.instance_variable_get("@object")
    selected = person.gender_id.nil? ? 'nil' : person.gender_id
    options_for_select([['', ''], ['Female', 1], ['Male', 2], ['Other', 3]], selected)
  end

  def profile_image
    image_tag(@entity.featured_image_url, alt: @entity.name, class: 'img-rounded')
  end

  def sidebar_title(title, pointer = nil)
    title = content_tag(:div, content_tag(:span, title, class: 'lead sidebar-title-text'), class: 'sidebar-title-container thin-grey-bottom-border')
    return title if pointer.nil?
    title + content_tag(:div, pointer, class: 'section-pointer')
  end

  def sidebar_industry_links(os_categories)
    os_categories.to_a
      .delete_if { |cat| cat.ignore_me_in_view }
      .collect {  |cat| link_to(cat.category_name, cat.legacy_path) } 
      .join(', ')
  end

  # To eager load list and list_entities: Entity.includes(list_entities: [:lists])
  def sidebar_lists(list_entities)
    list_entities.collect do |list_entity|
      if show_list(list_entity)
        content_tag(:li, sidebar_list_link(list_entity), class: 'sidebar-list')
      else
        "".html_safe
      end
    end.reduce(:+)
  end

  def sidebar_list_link(list_entity)
    link = link_to list_entity.list.name , list_path(list_entity.list), class: 'link-blue'
    link += content_tag(:samp, "[\##{list_entity.rank}]") if list_entity.list.is_ranked? && list_entity.rank.present?
    link
  end

  def sidebar_similar_entities(similar_entities)
    similar_entities
      .collect { |e| link_to(e.name, e.legacy_url) }
      .collect { |link| content_tag(:li, link) }
      .reduce(&:+)
  end

  def get_form_id(f)
    f.instance_variable_get('@options')[:html][:id]
  end

  # <User> -> Boolean
  def show_add_bulk_button(user)
    return true if user.admin? || user.bulker?
    return true if user.created_at < 2.weeks.ago && user.sign_in_count > 2
    false
  end

  private

  # Filters refereces to uniq url/name
  def filter_and_limit_references(refs)
    refs.uniq { |ref| "#{ref.name}#{ref.source}" }.take(10)
  end

  # skip deleted lists, private lists (unless current_user has access), and skip lists that are networks
  def show_list(list_entity)
    list = list_entity.list
    return false if list.nil? || list.is_network?
    list.user_can_access?(current_user)
  end

  def political_tab_col_left
    content_tag(:div, class: 'col-md-8 col-sm-8 nopadding') { yield }
  end

  def political_tab_col_right
    content_tag(:div, class: 'col-md-4 col-sm-4 double-left-padding') { yield }
  end
end
