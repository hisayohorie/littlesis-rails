class EntityMerger
  def self.merge_basic(e1, e2, excludes = [])
    ActiveRecord::Base.transaction do
      # have to have the same primary extension
      raise "can't merge entities with different primary extensions" unless e1.primary_ext == e2.primary_ext

      # add new extensions, if any, to e1, with attributes
      exts1 = e1.extension_names
      exts2 = e2.extension_names

      (exts1 - exts2).each do |ext|
        e1.add_extension(ext)
      end

      # set values based on merge rules defined in merge_field
      excludes = (excludes + ['id', 'created_at', 'updated_at']).uniq
      attrs1 = e1.all_attributes
      attrs2 = e2.all_attributes
      attrs2.each do |key, value|
        next if excludes.include?(key)
        e1.set_attribute(key, merge_attribute(key, attrs1[key], attrs2[key]))
      end
    end

    e1
  end

  def self.merge_attribute(key, old, nu)
    return nu if old.nil?
    return old if nu.nil?
    return old if old == nu

    append_with_new_line_fields = ['summary', 'notes']
    append_with_space_fields = ['name_suffix', 'name_prefix']
    date_fields = ['start_date', 'end_date']
    name_fields = ['name_first', 'name_middle']
    number_fields = ['employees', 'revenue', 'endowment', 'net_worth']

    return old + "\n\n" + nu if append_with_new_line_fields.include?(key)
    return old + " " + nu if append_with_space_fields.include?(key)

    if date_fields.include?(key)
      old_date = Date.new(old)
      nu_date = Date.new(nu)

      return old_date.format if old_date.how_specific > nu_date.how_specific
      return nu_date.format if old_date_how_specific < nu_date.how_specific

      return (Date.less_or_equal(old_date, nu_date) ? old_date : nu_date) if old_date.how_specific == Date::YEAR_SPECIFIC
      return old_date
    end

    return ((old.length >= nu.length or old.length != 1) ? old : nu) if name_fields.include?(key)
    return (old == 0 ? nu : old) if number_fields.include?(key)

    old
  end

  def self.merge_all(e1, e2)
    ActiveRecord::Base.transaction do
      e1 = merge_basic(e1, e2)

      # CONTACT INFO
      e2.phones.each do |phone|
        phone.update(entity_id: e1.id) unless e1.phones.where(number: phone.number).exists?        
      end
      e2.emails.each do |email|
        email.update(entity_id: e1.id) unless e1.emails.where(address: email.address).exists?
      end
      e2.addresses.each do |address|
        address.update(entity_id: e1.id) unless e1.addresses.find { |a| a.same_as?(address) }
      end
      
      # RELATIONSHIPS
      e2.relationships.each do |rel|
        if rel.entity1_id == e2.id
          rel.update(entity1_id: e1.id)
          rel.links.where(is_reverse: false).update_all(entity1_id: e1.id)
          rel.links.where(is_reverse: true).update_all(entity2_id: e1.id)
        elsif rel.entity2_id = e2.id
          rel.update(entity2_id: e1.id)
          rel.links.where(is_reverse: false).update_all(entity2_id: e1.id)
          rel.links.where(is_reverse: true).update_all(entity1_id: e1.id)
        end
      end

      # LISTS
      e2.list_entities.active.each do |le|
        le.update(entity_id: e1.id) unless e1.list_entities.active.map(&:list_id).include?(le.list_id)        
      end

      # IMAGES
      e2.images.update_all(entity_id: e1.id)

      # ALIASES
      e2.aliases.each do |a|
        next if e1.aliases.where(name: a.name, context: a.context).exists?
        a.update(entity_id: e1.id, is_primary: false)
      end

      # IGNORE CUSTOM FIELDS B/C THEY'RE NOT USED

      # IGNORE MODIFICATIONS IN RAILS

      # IGNORE TAGS B/C THEY'RE NOT USED

      # REFERENCES
      e2.references.each do |ref|
        ref.update(object_id: e1.id) unless e1.references.find { |r| r.source == ref.source }
      end

      e2.update(merged_id: e1.id)

      # CHILD ENTITIES
      e2.children.update_all(parent_id: e1.id)

      # PARTY MEMBERS
      e2.party_members.each do |pm|
        pm.person.update(party_id: e1.id)
      end

      # IGNORE BUSINESS INDUSTRIES B/C THEY'RE NOT USED

      # IGNORE BUNDLERS B/C THEY'RE NOT USED

      # LOBBY FILING LOBBYISTS    
      ActiveRecord::Base.connection.execute("UPDATE lobby_filing_lobbyist SET lobbyist_id = #{e1.id} WHERE lobbyist_id = #{e2.id}")

      # TRANSACTION CONTACTS
      ActiveRecord::Base.connection.execute("UPDATE transaction SET contact1_id = #{e1.id} WHERE contact1_id = #{e2.id}")
      ActiveRecord::Base.connection.execute("UPDATE transaction SET contact2_id = #{e1.id} WHERE contact2_id = #{e2.id}")

      # NOTES
      e2.note_entities.each do |ne|
        ne.update(entity_id: e1.id) unless e1.note_entities.where(note_id: ne.note_id).exists?
      end

      # DONATION MATCHES
      e2.os_entity_transactions.each do |et2|
        if et1 = e1.os_entity_transactions.where(cycle: et2.cycle, transaction_id: et2.transaction_id).first
          # only merge in verified matches
          if et2.is_verified
            et1.update(is_verified: true, is_processed: false, is_synced: false)
          end

          et2.destroy
        else
          et2.update(entity_id: e1.id, is_processed: false, is_synced: false)
        end
      end
      # remove and rebuild relationships with fec filings based on donation matches
      e1.relationships.joins(:fec_filings).where(category_id: 5).each { |r| r.soft_delete }
      e1.os_entity_transactions.where(is_verified: true).update_all(is_processed: false, is_synced: false)

      # DONATION MATCHING PREPROCESS LOG
      e2.os_entity_preprocesses.each do |ep2|
        if e1.os_entity_preprocesses.find { |ep1| ep1.cycle == ep2.cycle }
          ep2.destroy
        else
          ep2.update(entity_id: e1.id)
        end
      end

      # EXTERNAL KEYS
      e2.external_keys.each do |key|
        key.update(entity_id: e1.id) unless e1.external_keys.find { |k| k.domain_id == key.domain_id }
      end

      # OPENSECRETS CATEGORIES
      e2.os_entity_categories.each do |ec2|
        ec2.update(entity_id: e1.id) unless e1.os_entity_categories.where(category_id: ec2.category_id).exists?
      end

      # FIELDS
      e2.entity_fields.each do |ef2|
        ef2.update(entity_id: e1.id) unless e1.entity_fields.where(field_id: ef2.field_id).exists?
      end

      # ARTICLES
      e2.article_entities.each do |ae2|
        ae2.update(entity_id: e1.id) unless e1.article_entities.where(article_id: ae2.article_id).exists?
      end

      # QUEUES
      e2.queue_entities.each do |qe2|
        qe2.update(entity_id: e1.id) unless e1.queue_entities.where(queue: ae2.queue).exists?
      end

      e1
    end
  end
end