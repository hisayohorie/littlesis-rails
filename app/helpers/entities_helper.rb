module EntitiesHelper
	def entity_link(entity, name=nil)
		name ||= entity.name
		link_to name, entity
	end
end
