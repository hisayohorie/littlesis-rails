class GovernmentBody < ActiveRecord::Base
  include SingularTable

  belongs_to :entity, inverse_of: :government_body
end