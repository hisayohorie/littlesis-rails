class Ownership < ActiveRecord::Base
  include SingularTable

  belongs_to :relationship, inverse_of: :ownership

  has_paper_trail on: [:update, :destroy]
end
